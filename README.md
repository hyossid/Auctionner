# Auctionner

Customized auction contract supporting dutch auction and fixed-price marketplace

Currently supports ETH for trading

--- 

### yarn

we are using yarn as our package manager.

```shell
yarn install
```

### compile 

```shell
yarn build
```

### run test with gas report

```shell
yarn test:auctioneer
```

### deploy

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


