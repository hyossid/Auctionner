import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('Lock', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  describe('Deployment', function () {
    let Auctioneer,
      nft: any,
      auctioneer: any,
      owner: any,
      royaltyAddress: any,
      addr1: any;

    beforeEach(async () => {
      Auctioneer = await ethers.getContractFactory('Auctioneer');
      let MyNFT = await ethers.getContractFactory('MyNFT');
      [owner, royaltyAddress, addr1] = await ethers.getSigners();
      nft = await MyNFT.deploy();
      auctioneer = await Auctioneer.deploy(nft.address, royaltyAddress.address);
    });

    describe('[1] : Deployment', () => {
      it('Should set the right owner/seller and nft', async () => {
        expect(await auctioneer.owner()).to.equal(owner.address);
        expect(await auctioneer.nft()).to.equal(nft.address);
        expect(await auctioneer.seller()).to.equal(owner.address); // Seller needs to be deployer
      });
    });

    describe('[2] : Start Auction', () => {
      it('Start Auction', async () => {
        let nftId = 11;
        let startingBid = 10000000;
        let period = 7;

        // await auctioneer.start.call(nftId, startingBid, period, {
        //   from: owner.address,
        // });
      });
    });
  });
});
