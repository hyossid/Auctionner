pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

// Interface to transfer NFT
interface IERC721 {
  function safeTransferFrom(address from, address to, uint tokenId) external;

  function ownerOf(uint) external returns (address);

  function getApproved(uint) external returns (address);
}

contract Auctioneer is Ownable, ReentrancyGuard {
  // [Common] : Variables
  uint public DEPOSIT_VALUE;
  address payable public treasury; // there is only one unique treasury

  // [Auction] : Events
  event Start(uint nftId);
  event Bid(uint nftId, address indexed sender, uint amount);
  event Withdraw(uint nftId, address indexed bidder, uint amount);
  event End(uint nftId, address winner, uint amount);
  event SetOwner(address indexed owner);
  event SetTreasury(address indexed treasury);
  event ClaimWinner(address indexed winner, uint nftId);
  event ClaimSeller(address indexed seller, uint nftId);

  // [Fixed-Price Market] : Events
  event ItemListed(
    address indexed seller,
    address nftAddress,
    uint nftId,
    uint price
  );
  event ItemCanceled(address indexed seller, address nftAddress, uint nftId);
  event ItemBought(
    address indexed seller,
    address nftAddress,
    uint nftId,
    uint price
  );

  // [Auction] : Variables
  IERC721 public immutable nft; // NFT to be listed in Auction initially
  mapping(uint => bool) public didWinnerClaimed; // Initial Auction
  mapping(uint => bool) public didSellerClaimed; // Initial Auction
  mapping(address => bool) public approvedToken; // Approved Tokens to be traded in auction

  // [Auction] : Bid Info
  struct bidInfo {
    mapping(address => uint) bids;
    address seller;
    address highestBidder;
    address winner;
    uint highestBid;
    uint winnings;
    uint endAt;
    bool started;
    bool ended;
  }

  mapping(uint => bidInfo) public nftStatus;

  // [Fixed-Price Market] : Listing
  struct Listing {
    uint256 price;
    address seller;
  }
  mapping(address => mapping(uint256 => Listing)) private salesListing;
  mapping(address => uint256) private salesProceeds;

  // [Common] : Modifiers
  modifier notListed(
    address nftAddress,
    uint256 _nftId,
    address owner
  ) {
    Listing memory listing = salesListing[nftAddress][_nftId];
    require(listing.price <= 0, "[INFO] : Already Listed");
    _;
  }

  modifier didDeposit(
    address senderAddress
  ) {
    bool _didDeposit = depositCheck[senderAddress];
    require(_didDeposit == true, "[INFO] : Sender did not deposit");
    _;
  }

  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listing = salesListing[nftAddress][tokenId];
    require(listing.price > 0, "[INFO] : Not listed");
    _;
  }

  modifier isOwner(
    address nftAddress,
    uint256 _nftId,
    address spender
  ) {
    IERC721 _nft = IERC721(nftAddress);
    address owner = _nft.ownerOf(_nftId);
    require(spender == owner, "[INFO] : Not owner");
    _;
  }

  constructor(address _nft) {
    nft = IERC721(_nft); //  Gold Gereges NFT
    _transferOwnership(msg.sender); // Deployer is owner of this auction contract
    DEPOSIT_VALUE = 50000000000000000; // 0.05 ETH
  }


   function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

  // need to start respectively for each nft
  function start(uint _nftId, uint reservePrice, uint period) external isOwner(address(nft), _nftId,msg.sender) didDeposit(msg.sender) {
    require(
      !nftStatus[_nftId].started,
      "[INFO] Auctionner has already started"
    );
    require(period <= 30, "[INFO] Maximum allowable auction is 30 days");
    
    nft.safeTransferFrom(msg.sender, address(this), _nftId); // Transfer nft from sender to contract
    
    nftStatus[_nftId].seller = msg.sender;
    nftStatus[_nftId].highestBid = reservePrice;
    nftStatus[_nftId].started = true;
    nftStatus[_nftId].endAt = block.timestamp + uint(period) * 1 days; // Auction ends in 7 days

    emit Start(_nftId);
  }

  function bid(uint _nftId) external payable didDeposit(msg.sender) {
    require(nftStatus[_nftId].started, "[INFO] Auctionner has not started");
    require(
      block.timestamp < nftStatus[_nftId].endAt,
      "[INFO] Auctionner already finished"
    );
    require(
      msg.value > nftStatus[_nftId].highestBid,
      "[INFO] Bidding value is smaller than current highest bid"
    );

    address currentWinner = nftStatus[_nftId].highestBidder;

    if (currentWinner != address(0)) {
      // makesure current Winner is valid.
      nftStatus[_nftId].bids[currentWinner] += nftStatus[_nftId].highestBid;
    }

    _withdraw(_nftId, currentWinner); // Payback ETH to previous winner

    nftStatus[_nftId].highestBidder = msg.sender; // Refresh to new winner
    nftStatus[_nftId].highestBid = msg.value; // Refresh to new winning value

    emit Bid(_nftId, msg.sender, msg.value);
  }

  function _withdraw(uint _nftId, address account) public {
    uint bal = nftStatus[_nftId].bids[account];
    nftStatus[_nftId].bids[account] = 0;
    payable(account).transfer(bal);

    emit Withdraw(_nftId, account, bal);
  }

  function setTreasury(address account) external {
    require(msg.sender == owner(), "[INFO] msg.sender is not owner");
    treasury = payable(account);

    emit SetTreasury(treasury);
  }


  function end(uint _nftId) external didDeposit(msg.sender) {
    require(nftStatus[_nftId].started, "[INFO] Auctionner has not started");
    require(
      block.timestamp >= nftStatus[_nftId].endAt,
      "[INFO] Auctionner is not yet finished"
    );
    require(!nftStatus[_nftId].ended, "[INFO] Auctionner ended");

    nftStatus[_nftId].ended = true;

    if (nftStatus[_nftId].highestBidder != address(0)) {
      nftStatus[_nftId].winner = nftStatus[_nftId].highestBidder;
      nftStatus[_nftId].winnings = nftStatus[_nftId].highestBid;
      didWinnerClaimed[_nftId] = false;
      didSellerClaimed[_nftId] = false;
    } else {
      nft.safeTransferFrom(address(this), nftStatus[_nftId].seller, _nftId); // Return NFT to seller
    }

    emit End(_nftId, nftStatus[_nftId].winner, nftStatus[_nftId].winnings);
  }

  // Claiming Functions
  function claimWinner(uint _nftId) external{
    require(
      msg.sender == nftStatus[_nftId].winner,
      "[INFO] msg.sender is not winner"
    );
    require(!didWinnerClaimed[_nftId], "[INFO] winner already claimed NFT");

    address winner = nftStatus[_nftId].winner;
    nft.safeTransferFrom(address(this), winner, _nftId);
    didWinnerClaimed[_nftId] = true;
    uint platformFee = calculatePlatformFee(nftStatus[_nftId].winnings);
    treasury.transfer(platformFee); // pay 1% of platform fee
    //uint royaltyPrice = royaltyInfo
    // royaltyreceiver.transfer(platformFee); // pay 5% of royalty fee

    emit ClaimWinner(winner, _nftId);
  }

  function claimSeller(uint _nftId) external{
    require(msg.sender == nftStatus[_nftId].seller, "[INFO] msg.sender is not seller");
    require(!didSellerClaimed[_nftId], "[INFO] seller already claimed rewards");

    //seller.transfer(nftStatus[_nftId].winnings);

    (bool success, ) = payable(nftStatus[_nftId].seller).call{value: nftStatus[_nftId].winnings}(
      ""
    );
    require(success, "[INFO] Transfer failed");

    didSellerClaimed[_nftId] = true;

    emit ClaimSeller(nftStatus[_nftId].seller, _nftId);
  }

  function calculatePlatformFee(
    uint256 _bidAmount
  ) public pure returns (uint256) {
    return (_bidAmount / 10000) * 100; // 1 percent
  }

  // [Fixed-Price Market]
  function listItem(
    address nftAddress,
    uint256 _nftId,
    uint256 askPrice
  )
    external
    notListed(nftAddress, _nftId, msg.sender)
    isOwner(nftAddress, _nftId, msg.sender)
  {
    require(askPrice > 0, "[INFO]: Ask price must be above zero");
    IERC721 _nft = IERC721(nftAddress);
    require(
      _nft.getApproved(_nftId) != address(this),
      "[INFO]: Auctioneer is not approved"
    );
    salesListing[nftAddress][_nftId] = Listing(askPrice, msg.sender);

    nft.safeTransferFrom(msg.sender, address(this), _nftId); // Transfer nft from sender to contract

    emit ItemListed(msg.sender, nftAddress, _nftId, askPrice);
  }

  function cancelListing(
    address nftAddress,
    uint256 _nftId
  ) external isListed(nftAddress, _nftId){
    require(
      msg.sender == salesListing[nftAddress][_nftId].seller,
      "[INFO]: msg.sender is not seller"
    );
    nft.safeTransferFrom(address(this), msg.sender, _nftId); // Refund
    delete (salesListing[nftAddress][_nftId]);
    emit ItemCanceled(msg.sender, nftAddress, _nftId);
  }

  function buyItem(
    address nftAddress,
    uint256 _nftId
  ) external payable isListed(nftAddress, _nftId) nonReentrant {
    Listing memory listedItem = salesListing[nftAddress][_nftId];
    require(msg.value >= listedItem.price, "INFO: Price Not Met");

    salesProceeds[listedItem.seller] += msg.value;
    delete (salesListing[nftAddress][_nftId]);
    IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, _nftId);

    uint platformFee = calculatePlatformFee(msg.value);
    treasury.transfer(platformFee); // pay 1% of platform fee
    // uint royaltyPrice = calculateRoyalty(nftStatus[_nftId].winnings);
    // royaltyreceiver.transfer(platformFee); // pay 5% of royalty fee
    // TODO : change below line incorporating royalty fee
    (bool success, ) = payable(msg.sender).call{value: msg.value}("");
    require(success, "Transfer failed");

    emit ItemBought(msg.sender, nftAddress, _nftId, listedItem.price);
  }

  function getListing(
    address nftAddress,
    uint256 _nftId
  ) external view returns (Listing memory) {
    return salesListing[nftAddress][_nftId];
  }

  // Deposit
  event Deposited(address indexed payee, uint256 weiAmount);
  event Withdrawn(address indexed payee);

  mapping(address => bool) public depositCheck;

  function deposit() public payable {
    require(
      msg.value == DEPOSIT_VALUE,
      "[INFO] : Need to deposit exact amount of 0.05 ETH"
    );
    depositCheck[msg.sender] = true;
    emit Deposited(msg.sender, msg.value);
  }

  function withdraw(address _account) public {
    require(depositCheck[_account] == true, "[INFO] : No deposit found");
    depositCheck[_account] = false;
    payable(_account).transfer(DEPOSIT_VALUE);
    emit Withdrawn(_account);
  }

  function checkIfDeposit(address _account) public view returns (bool) {
    return depositCheck[_account];
  }
}
