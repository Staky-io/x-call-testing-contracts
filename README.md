# X-Call testing smart contracts

This project demonstrates ICON's X-Call use case.
It comes with a set of contracts, a testsuite for these contracts, and a script that deploys them.

This contract enables users to call external contracts on other blockchains (arbitrary calls) and bridge NFTs between them.

Try running some of the following tasks:

```shell
# test
npx hardhat test
# test with gas report
GAS_REPORT=true npx hardhat test
# compile
npx hardhat compile
# deploy
npx hardhat run scripts/deploy.ts --network <hardhat|sepolia|bsctestnet>
```
