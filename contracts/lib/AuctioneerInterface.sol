pragma solidity ^0.8.13;

/// @notice Interface to transfer NFT
interface IERC721 {
  function safeTransferFrom(address from, address to, uint tokenId) external;

  function ownerOf(uint) external returns (address);

  function getApproved(uint) external returns (address);

  function royaltyInfo(
    uint256 tokenId,
    uint256 salePrice
  ) external returns (address, uint256);
}
