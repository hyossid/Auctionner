import { ethers } from 'hardhat';

async function main() {
  const Auctioneer = await ethers.getContractFactory('Auctioneer');
  const MyNFT = await ethers.getContractFactory('GoldGeregeExample');
  const nft = await MyNFT.deploy();
  await Auctioneer.deploy(nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
