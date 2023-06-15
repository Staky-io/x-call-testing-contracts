# X-Call testing smart contracts

This project demonstrates ICON's X-Call use case.
It comes with a set of two contracts and a script that deploys them.

One of the contracts (`Messenger.sol`) enables users to call external contracts on other blockchains (arbitrary calls) and send text messages from and to another deployment.
And another one (`NFTBridge.sol`), explores the option to bridge NFTs between them but is not ready to be used.

The interesting part of these two contracts, is that they are both extended from a base contract (`utils/XCallBase.sol`) that implements all the X-Call basic functions and a bit of logic to simplify the smart contract development.

## Setup

Install dependencies and copy the .env file, then complete with your own keys.

```shell
# install dependencies
npm install
# create .env file
cp .env.example .env
```

## Compile and deploy

```shell
# compile
npm run compile
# deploy
npm run scripts/deploy-messenger.ts --network <hardhat|sepolia|bsc_testnet>
```

## On-chain setup

Once deployed on both chains, you must call the `authorizeMessenger` function of each Messenger contract to whitelist the address of every other deployed contracts.

The format of the `authorizeMessenger` function parameter is the following: `btp://<chain_id>/<other_deployment_address>`

## Usage

To send a message, you must call the `sendMessage` function of the Messenger contract with the following parameters:

- `address _to`: the address of the other Messenger contract (in BTP format like this: example: `btp://<destination_chain_id>/<destination_deployment_address>`)

- `string _message`: the text to send to the other contract

To receive the sent message, you must follow the instructions on how to execute a call in the [ICON documentation](https://docs.icon.community/cross-chain-communication/xcall/sending-a-message-with-xcall#fetching-event-on-destination-chain)

