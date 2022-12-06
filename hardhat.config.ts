import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-web3';
import 'dotenv/config';
import 'hardhat-typechain';
import { HardhatUserConfig } from 'hardhat/types';
import '@nomiclabs/hardhat-etherscan';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.6',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      accounts: {
        count: 10,
      },
    },
    matic_testnet: {
      url: 'https://rpc-mumbai.maticvigil.com',
      accounts: [process.env.TESTNET_PRIVATEKEY || ''],
      chainId: 80001,
    },
    matic_mainnet: {
      url: 'https://polygon-rpc.com',
      accounts: [process.env.MAINNET_PRIVATEKEY || ''],
      chainId: 137,
    },
    matic_qa: {
      url: 'https://polygon-rpc.com',
      accounts: [process.env.TESTNET_PRIVATEKEY || ''],
      chainId: 137,
    },
  },
  mocha: {
    timeout: 400000,
  },
  etherscan: {
    apiKey: 'UMGWVAX629D4J5BZNHX75AF84STA4FUV32',
  },
};

export default config;
