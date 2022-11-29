pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

import {bidInfo, Listing} from "./lib/AuctioneerStructs.sol";
import {IERC721} from "./lib/AuctioneerInterface.sol";

/**
 * @title  Auctioneer
 * @author Sidney Seo (sidneys.btc)
 * @notice Auctioneer contract for customized English auction 
 *
 */

contract Auctioneer is Ownable, ReentrancyGuard {

  /// @notice Configurable initial deposit value
  uint public DEPOSIT_VALUE;

  /// @notice Discount rate for duth auction, set on deployment stage
  uint public immutable discountRate; 

  /// @notice Unique treasury address to reserve platform fee
  address payable public treasury; 

  /// @notice Emit event of Start
  event Start(uint nftId);

  /// @notice Emit event of Start dutch auction
  event StartDutch(uint nftId);

  /// @notice Emit event of Buy Dutch auction
  event BuyDutch(uint nftId);

  /// @notice Emit event of Bid
  event Bid(uint nftId, address indexed sender, uint amount);

  /// @notice Emit event of Withdraw
  event Withdraw(uint nftId, address indexed bidder, uint amount);

  /// @notice Emit event of End
  event End(uint nftId, address winner, uint amount);

  /// @notice Emit event of SetOwner
  event SetOwner(address indexed owner);

  /// @notice Emit event of SetTreasury
  event SetTreasury(address indexed treasury);

  /// @notice Emit event of ClaimWinner
  event ClaimWinner(address indexed winner, uint nftId);

  /// @notice Emit event of ClaimSeller
  event ClaimSeller(address indexed seller, uint nftId);

  /// @notice Emit event of Item listed
  event ItemListed(
    address indexed seller,
    address nftAddress,
    uint nftId,
    uint price
  );

  /// @notice Emit event of Item Cancelled
  event ItemCanceled(address indexed seller, address nftAddress, uint nftId);

  /// @notice Emit event of ItemBought
  event ItemBought(
    address indexed seller,
    address nftAddress,
    uint nftId,
    uint price
  );

  /// @notice Emit event of deposit
  event Deposited(address indexed payee, uint256 weiAmount);

  /// @notice Emit event of withdraw
  event Withdrawn(address indexed payee);

  /// @notice Listed NFT in Auction initially
  IERC721 public immutable nft; 

  /// @notice Track the if winner claimed
  mapping(uint => bool) public didWinnerClaimed; 

  /// @notice Track the if seller claimed
  mapping(uint => bool) public didSellerClaimed; 

  /// @notice Track the list of approved token for ERC20
  mapping(address => bool) public approvedToken; 

  /// @notice Track the nft auction status
  mapping(uint => bidInfo) public nftStatus;

  /// @notice Track the fixed-price market listing status
  mapping(address => mapping(uint256 => Listing)) public salesListing;

  /// @notice Track the proceeded sales list 
  mapping(address => uint256) private salesProceeds;

  /// @notice Track deposits
  mapping(address => bool) public depositCheck;

  /// @notice Check if nft is listed or not
  modifier notListed(
    address nftAddress,
    uint256 _nftId,
    address owner
  ) {
    Listing memory listing = salesListing[nftAddress][_nftId];
    require(listing.price <= 0, "[INFO] : Already Listed");
    _;
  }

  /// @notice Check if user deposited deposit on platform
  modifier didDeposit(address senderAddress) {
    bool _didDeposit = depositCheck[senderAddress];
    require(_didDeposit == true, "[INFO] : Sender did not deposit");
    _;
  }

  /// @notice Check if nft is on fixed-price market platform
  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listing = salesListing[nftAddress][tokenId];
    require(listing.price > 0, "[INFO] : Not listed");
    _;
  }

  /// @notice Check if user is nft's owner
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

   /**
     * @notice Constructor for the contract deployment.
     */
  constructor(address _nft) {
    nft = IERC721(_nft); 
    _transferOwnership(msg.sender); 
    DEPOSIT_VALUE = 50000000000000000; // 0.05 ETH
    discountRate = 10000000000000000; // discout rate is configurable for dutch auction
  }

  function onERC721Received(
    address,
    address,
    uint256,
    bytes calldata
  ) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

    /**
     * @notice Start NFT Auction
     *
     * @param _nftId      The nft id of designated NFT.
     * @param reservePrice     Reserved price for nft.
     * @param period    Auction period in days. 
     */
  function start(
    uint _nftId,
    uint reservePrice,
    uint period
  ) external isOwner(address(nft), _nftId, msg.sender) didDeposit(msg.sender) {
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

    /**
     * @notice Start Bidding
     *
     * @param _nftId      The nft id of designated NFT.
     */
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

    /**
     * @notice Withdraw highestbid if someone outbids.
     *
     * @param _nftId      The nft id of designated NFT.
     * @param account      Withdraw bids of bidder.
     */
  function _withdraw(uint _nftId, address account) public {
    uint bal = nftStatus[_nftId].bids[account];
    nftStatus[_nftId].bids[account] = 0;
    payable(account).transfer(bal);

    emit Withdraw(_nftId, account, bal);
  }
    /**
     * @notice Set treasury account for auction.
     *
     * @param account      Treasury account.
     */
  function setTreasury(address account) external {
    require(msg.sender == owner(), "[INFO] msg.sender is not owner");
    treasury = payable(account);

    emit SetTreasury(treasury);
  }

    /**
     * @notice End NFT Auction
     *
     * @param _nftId      The nft id of designated NFT.
     */
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

    /**
     * @notice Claim NFT after NFT Auction
     *
     * @param _nftId      The nft id of designated NFT.
     */
  function claimWinner(uint _nftId) external {
    require(
      msg.sender == nftStatus[_nftId].winner,
      "[INFO] msg.sender is not winner"
    );
    require(!didWinnerClaimed[_nftId], "[INFO] winner already claimed NFT");
    require(nftStatus[_nftId].ended, "[INFO] Auction not ended yet");

    address winner = nftStatus[_nftId].winner;
    nft.safeTransferFrom(address(this), winner, _nftId);
    didWinnerClaimed[_nftId] = true;
    uint platformFee = calculatePlatformFee(nftStatus[_nftId].winnings);
    (address royaltyreceiver, uint royaltyFee) = nft.royaltyInfo(
      _nftId,
      nftStatus[_nftId].winnings
    );

    treasury.transfer(platformFee); // pay 1% of platform fee
    payable(royaltyreceiver).transfer(royaltyFee); // pay royalty fee

    withdrawDeposit(msg.sender); // Return Deposit
    emit ClaimWinner(winner, _nftId);
  }

    /**
     * @notice Claim ETH after NFT Auction
     *
     * @param _nftId      The nft id of designated NFT.
     */
  function claimSeller(uint _nftId) external {
    require(
      msg.sender == nftStatus[_nftId].seller,
      "[INFO] msg.sender is not seller"
    );
    require(!didSellerClaimed[_nftId], "[INFO] seller already claimed rewards");
    require(nftStatus[_nftId].ended, "[INFO] Auction not ended yet");

    uint platformFee = calculatePlatformFee(nftStatus[_nftId].winnings);
    (, uint royaltyFee) = nft.royaltyInfo(_nftId, nftStatus[_nftId].winnings);
    uint deductedFee = nftStatus[_nftId].winnings - (platformFee + royaltyFee);
    (bool success, ) = payable(nftStatus[_nftId].seller).call{
      value: deductedFee
    }("");
    require(success, "[INFO] Transfer failed");

    didSellerClaimed[_nftId] = true;

    withdrawDeposit(msg.sender); // Return Deposit
    emit ClaimSeller(nftStatus[_nftId].seller, _nftId);
  }

    /**
     * @notice Calculate platform fee, set to 1 percent.
     */
  function calculatePlatformFee(
    uint256 _bidAmount
  ) public pure returns (uint256) {
    return (_bidAmount / 10000) * 100; // 1 percent
  }

    /**
     * @notice Start listing item for fixed price market.
     *
     * @param _nftId      The nft id of designated NFT.
     * @param nftAddress     NFT address to be listed.
     * @param askPrice    Price to be asked by seller.
     */
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

    salesListing[nftAddress][_nftId] = Listing(askPrice, msg.sender);

    _nft.safeTransferFrom(msg.sender, address(this), _nftId); // Transfer nft from sender to contract

    emit ItemListed(msg.sender, nftAddress, _nftId, askPrice);
  }

    /**
     * @notice Cancel listing item for fixed price market.
     *
     * @param _nftId      The nft id of designated NFT.
     * @param nftAddress     NFT address to be listed.
     */
  function cancelListing(
    address nftAddress,
    uint256 _nftId
  ) external isListed(nftAddress, _nftId) {
    require(
      msg.sender == salesListing[nftAddress][_nftId].seller,
      "[INFO]: msg.sender is not seller"
    );
    nft.safeTransferFrom(address(this), msg.sender, _nftId); // Refund
    delete (salesListing[nftAddress][_nftId]);
    emit ItemCanceled(msg.sender, nftAddress, _nftId);
  }

    /**
     * @notice Buy listing item for fixed price market.
     *
     * @param _nftId      The nft id of designated NFT.
     * @param nftAddress     NFT address to be listed.
     */
  function buyItem(
    address nftAddress,
    uint256 _nftId
  ) external payable isListed(nftAddress, _nftId) nonReentrant {
    Listing memory listedItem = salesListing[nftAddress][_nftId];
    require(msg.value >= listedItem.price, "[INFO] : Price not met");

    IERC721 _nft = IERC721(nftAddress);
    delete (salesListing[nftAddress][_nftId]);
    salesProceeds[listedItem.seller] += msg.value;

    uint platformFee = calculatePlatformFee(msg.value);
    treasury.transfer(platformFee); // pay 1% of platform fee
    (address royaltyreceiver, uint royaltyFee) = _nft.royaltyInfo(
      _nftId,
      msg.value
    );

    payable(royaltyreceiver).transfer(royaltyFee); // pay royalty fee

    uint deductedFee = msg.value - (platformFee + royaltyFee);
    (bool success, ) = payable(msg.sender).call{value: deductedFee}(""); // TODO : CHeck
    require(success, "[INFO] : Transfer failed");
    IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, _nftId);

    withdrawDeposit(msg.sender); // Return Deposit
    emit ItemBought(msg.sender, nftAddress, _nftId, listedItem.price);
  }

    /**
     * @notice Get listing item for fixed price market.
     *
     * @param _nftId      The nft id of designated NFT.
     * @param nftAddress     NFT address to be listed.
     */
  function getListing(
    address nftAddress,
    uint256 _nftId
  ) external view returns (Listing memory) {
    return salesListing[nftAddress][_nftId];
  }

    /**
     * @notice Deposit tokens to use platform
     */
  function deposit() public payable {
    require(
      msg.value == DEPOSIT_VALUE,
      "[INFO] : Need to deposit exact amount of 0.05 ETH"
    );
    depositCheck[msg.sender] = true;
    emit Deposited(msg.sender, msg.value);
  }

    /**
     * @notice Withdraw deposits
     *
     * @param _account      Account to withdraw deposit.
     */
  function withdrawDeposit(address _account) public {
    require(depositCheck[_account] == true, "[INFO] : No deposit found");
    depositCheck[_account] = false;
    payable(_account).transfer(DEPOSIT_VALUE);
    emit Withdrawn(_account);
  }

    /**
     * @notice Start Dutch auction
     *
     * @param _nftId      The nft id of designated NFT.
     * @param _initialPrice     Initial price of dutch auction.
     * @param period    Dutch auction period in days.
     */
  function startDutch(
    uint _nftId,
    uint _initialPrice,
    uint period
  ) external isOwner(address(nft), _nftId, msg.sender) didDeposit(msg.sender) {
    require(
      !nftStatus[_nftId].started,
      "[INFO] Auctionner has already started"
    );
    require(period <= 30, "[INFO] Maximum allowable auction is 30 days");
    require(
      _initialPrice >= discountRate * period,
      "[INFO] starting price < min"
    );

    nft.safeTransferFrom(msg.sender, address(this), _nftId); // Transfer nft from sender to contract

    nftStatus[_nftId].seller = msg.sender;
    nftStatus[_nftId].highestBid = _initialPrice;
    nftStatus[_nftId].startAt = block.timestamp;
    nftStatus[_nftId].started = true;
    nftStatus[_nftId].isDutch = true;
    nftStatus[_nftId].endAt = block.timestamp + uint(period) * 1 days; // Auction ends in 7 days

    emit StartDutch(_nftId);
  }

    /**
     * @notice get current price of dutch auction listing
     *
     * @param _nftId      The nft id of designated NFT.
     */
  function getPriceDutch(uint _nftId) public view returns (uint) {
    require(nftStatus[_nftId].isDutch, "[INFO] : This is not dutch auction");

    uint timeElapsed = block.timestamp - nftStatus[_nftId].startAt;
    uint discount = discountRate * timeElapsed;
    uint startedPrice = nftStatus[_nftId].highestBid;
    require(startedPrice > discount, "[INFO] Too much discount");
    return startedPrice - discount;
  }

   /**
     * @notice Buy dutch auction listing
     *
     * @param _nftId      The nft id of designated NFT.
     */
  function buyDutch(uint _nftId) external payable {
    require(block.timestamp < nftStatus[_nftId].endAt, "[INFO] auction expired");

    uint price = getPriceDutch(_nftId);
    require(price == msg.value, "[INFO] price does not match");
    nftStatus[_nftId].winnings = price;
    nftStatus[_nftId].winner = msg.sender;

    uint platformFee = calculatePlatformFee(nftStatus[_nftId].winnings);
    (address royaltyreceiver, uint royaltyFee) = nft.royaltyInfo(
      _nftId,
      nftStatus[_nftId].winnings
    );
    uint fee = royaltyFee + platformFee;

    treasury.transfer(platformFee); // pay 1% of platform fee
    payable(royaltyreceiver).transfer(royaltyFee); // pay royalty fee

    nft.safeTransferFrom(address(this), msg.sender, _nftId); 

    payable(nftStatus[_nftId].seller).transfer(price-fee); 
 

    didWinnerClaimed[_nftId] = true;
    didSellerClaimed[_nftId] = true;

    nftStatus[_nftId].ended = true;
    emit BuyDutch(_nftId);
  }
}
