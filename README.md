# Project

1. Relative Stability: Anchored or Pegged -> $1.00
   1. Chainlink Price feed.
   2. Set a function to exchange ETH & BTC -> $$$
2. Stability Mechanism (Minting): Algorithmic (Decentralized)
   1. People can only mint the stablecoinds with enough collateral
3. Collateral: Exogenous (Crypto)
   1. wETH
   2. wBTC

## Test

Some basic commands:

```sh
forge test -m testGetUsdValue
```

```sh
forge coverage
forge coverage --report debug
```

# Security

1. What are our invariants/properties?

Usefull command:

```sh
forge inspect DSCEngine methods
```

It will print out the different functions and their selectors

Can be used as a checklist of all the different functions to call on a contract

We can use this to check our view functions and do invariant getters

```sh

  "burnDsc(uint256)": "f6876608",
  "calculateHealthFactor(uint256,uint256)": "01f72884",
  "depositCollateral(address,uint256)": "a5d5db0c",
  "depositCollateralAndMintDsc(address,uint256,uint256)": "e90db8a3",
  "getAccountCollateralValue(address)": "7d1a4450",
  "getAccountInformation(address)": "7be564fc",
  "getAdditionalFeedPrecision()": "8f63d667",
  "getCollateralBalanceOfUser(address,address)": "31e92b83",
  "getCollateralTokenPriceFeed(address)": "1c08adda",
  "getCollateralTokens()": "b58eb63f",
  "getDsc()": "deb8e018",
  "getHealthFactor(address)": "fe6bcd7c",
  "getLiquidationBonus()": "59aa9e72",
  "getLiquidationThreshold()": "4ae9b8bc",
  "getMinHealthFactor()": "8c1ae6c8",
  "getPrecision()": "9670c0bc",
  "getTokenAmountFromUsd(address,uint256)": "afea2e48",
  "getUsdValue(address,uint256)": "c660d112",
  "liquidate(address,address,uint256)": "26c01303",
  "mintDsc(uint256)": "c9b7c327",
  "redeemCollateral(address,uint256)": "9acd81b3",
  "redeemCollateralForDsc(address,uint256,uint256)": "f419ea9c"
}
```

# End

1. Some proper oracle use
2. Write more tests (challenge)
3. Smart contract Audit Preparation
