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
      let MyNFT = await ethers.getContractFactory('GoldGeregeExample');
      [owner, royaltyAddress, addr1] = await ethers.getSigners();
      nft = await MyNFT.connect(owner).deploy();
      auctioneer = await Auctioneer.connect(owner).deploy(nft.address);
      // const ownerBalance = await ethers.provider.getBalance(owner.address);
      // console.log(ownerBalance);

      // NFT Mint
      nft.connect(owner).mint(owner.address, 1);
      nft.connect(owner).mint(owner.address, 2);
      nft.connect(owner).mint(owner.address, 3);
      nft.connect(owner).setApprovalForAll(owner.address, true);
      nft.connect(owner).setApprovalForAll(auctioneer.address, true);
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
        let nftId = 1;
        let startingBid = 10000000;
        let period = 7;
        await auctioneer.connect(owner).start(nftId, startingBid, period);
        expect((await auctioneer.nftStatus(nftId)).started).to.equal(true);
      });
    });

    describe('[3] : Deposit', () => {
      it('Deposit and withdraw', async () => {
        await auctioneer
          .connect(addr1)
          .deposit({ value: ethers.utils.parseEther('0.05') });

        expect(await auctioneer.depositCheck(addr1.address)).to.equal(true);
        await auctioneer.connect(addr1).withdraw(addr1.address);
        expect(await auctioneer.depositCheck(addr1.address)).to.equal(false);
      });
    });
  });
});
