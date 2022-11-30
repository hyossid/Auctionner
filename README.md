# Auctionner

 - Auctioneer is customized NFT auction contract supporting dutch auction and fixed-price marketplace. 
 - Initially owned by deployer, owner may start the english auction based auction along with dutch auction and fixed-price listing. 
 - All the entities interacting with this contract needs to deposit designated amount of **ETH** (0.05 ETH as default) before calling functions in the contract. 
 - Auctioneer currently supports ETH for NFT auction, however can be extended to support other ERC20 tokens in future. 
 - All transaction happening in Auctioneer enforces `royaltyInfo` from ERC2981 on trading relevant NFT asset. 

--- 
## Get Started 

### Initializing project

we are using yarn as our package manager.

```shell
yarn install
```

### Compile contract 

compiles solidity contract to artifacts for test codes and deployment scripts.

```shell
yarn build
```

### run test with gas report

runs various test cases with gas report.

```shell
yarn test:auctioneer
```

### deploy

deploy

```shell
yarn hardhat run scripts/deploy.ts
```

### Details

 - User needs to manually call deposit designated amount of ETH to continue call public functions in the contract
 
 - There are 3 main functions in this auction contract.
   * English auction : default auction, can use `start`,`bid`, `end`, `claimWinner`, `claimSeller`
   * Fixed-price listing : listing marketplace, can use `listItem`, `buyItem`, `getPriceListing` , `cancelListing`
   * Dutch auction : dutch auction, can use `startDutch`, `getPriceDutch` , `buyDutch`
   * Deposit and withdraw from platform: Users must perform deposit in order to interact with contract, can use `deposit`, `withdraw` 


### Gas Report

<img width="842" alt="image" src="https://user-images.githubusercontent.com/34973707/204616715-db5c9077-247f-4053-aa71-cd46233eaac7.png">

### Reference

- https://solidity-by-example.org/app/english-auction/
- https://solidity-by-example.org/app/dutch-auction/
