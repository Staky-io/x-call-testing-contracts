import 'dotenv/config';
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-gas-reporter';

const privateKey = process.env.EVM_PRIVATE_KEY || '0x0000000000000000000000000000000000000000000000000000000000000000';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.4',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY || '',
      bscTestnet: process.env.BSCSCAN_API_KEY || '',
    },
  },
  gasReporter: {
    currency: 'USD',
    enabled: false, // set to true for gas reporting
    token: 'ETH'
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://sepolia.infura.io/v3/9c3444fd560e48a8939fb881df433c64",
      }
    },
    sepolia: {
      url: 'https://sepolia.infura.io/v3/9c3444fd560e48a8939fb881df433c64',
      accounts: [privateKey],
      chainId: 11155111,
    },
    bsc_testnet: {
      url: 'https://data-seed-prebsc-2-s3.binance.org:8545',
      accounts: [privateKey],
      chainId: 97,
    }
  },
};

export default config;
