# Auctionner

Customized auction contract supporting dutch auction and fixed-price marketplace

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
   * English auction
   * Fixed-price listing
   * Dutch auction


