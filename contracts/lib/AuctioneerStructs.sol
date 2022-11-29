pragma solidity ^0.8.13;

/// @notice : Auction bid Info
struct bidInfo {
  mapping(address => uint) bids;
  address seller;
  address highestBidder;
  address winner;
  uint highestBid;
  uint winnings;
  uint startAt;
  uint endAt;
  bool started;
  bool ended;
  bool isDutch;
  bool isForfeited;
}

/// @notice : Fixed price marketListing
struct Listing {
  uint256 price;
  address seller;
}
