import { time } from '@nomicfoundation/hardhat-network-helpers';
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
      addr1: any,
      addr2: any;
    beforeEach(async () => {
      Auctioneer = await ethers.getContractFactory('Auctioneer');
      let MyNFT = await ethers.getContractFactory('GoldGeregeExample');
      [owner, addr1, addr2] = await ethers.getSigners();
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
      });
    });

    describe('[2] : Start Auction', () => {
      it('Simple Auction Happy path', async () => {
        let nftId = 1;
        let startingBid = ethers.utils.parseEther('0.005');
        let period = 7;

        // Deposit to platform
        await auctioneer
          .connect(owner)
          .deposit({ value: ethers.utils.parseEther('0.05') });
        await auctioneer
          .connect(addr1)
          .deposit({ value: ethers.utils.parseEther('0.05') });
        await auctioneer
          .connect(addr2)
          .deposit({ value: ethers.utils.parseEther('0.05') });

        // nftId:1 start auction
        await auctioneer.connect(owner).start(nftId, startingBid, period);
        expect((await auctioneer.nftStatus(nftId)).started).to.equal(true);

        // addr1 bids for 0.01 eth
        await auctioneer
          .connect(addr1)
          .bid(nftId, { value: ethers.utils.parseEther('0.01') });

        // addr2 bids for 0.02 eth
        let bid = await auctioneer
          .connect(addr2)
          .bid(nftId, { value: ethers.utils.parseEther('0.02') });

        expect(bid).to.emit(auctioneer, 'Withdraw');

        const bidInfo = await auctioneer.nftStatus(nftId);
        expect(bidInfo.highestBidder).to.equal(addr2.address);
        expect(bidInfo.highestBid).to.equal(ethers.utils.parseEther('0.02'));

        // time manipulation
        await time.increase(300000000000);

        await auctioneer.connect(addr2).end(nftId);
        await auctioneer.connect(addr2).claimWinner(nftId);
        await auctioneer.connect(owner).claimSeller(nftId);

        expect(await nft.connect(owner).ownerOf(nftId)).to.equal(addr2.address);
        expect(await auctioneer.didSellerClaimed(nftId)).to.equal(true);
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
