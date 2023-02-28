require('@nomiclabs/hardhat-etherscan');
require('@openzeppelin/hardhat-defender');
require('@nomiclabs/hardhat-waffle');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-gas-reporter');
require('solidity-coverage');

const {
  RPC_NODE,
  WALLET_PK,
  BLOCK_EXPLORER_KEY,
  DEFENDER_TEAM_API_KEY,
  DEFENDER_TEAM_API_SECRET_KEY,
  COINMARKETCAP_API_KEY,
} = process.env;

module.exports = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defender: {
    apiKey: DEFENDER_TEAM_API_KEY,
    apiSecret: DEFENDER_TEAM_API_SECRET_KEY,
  },
  networks: {
    bsc: {
      url: `${RPC_NODE}`,
      accounts: [`${WALLET_PK}`],
    },
    polygon: {
      url: `${RPC_NODE}`,
      accounts: [`${WALLET_PK}`],
    },
    rinkeby: {
      url: `${RPC_NODE}`,
      accounts: [`${WALLET_PK}`],
    },
    bsc_testnet: {
      url: `${RPC_NODE}`,
      accounts: [`${WALLET_PK}`],
    },
    goerli: {
      url: `${RPC_NODE}`,
      accounts: [`${WALLET_PK}`],
      timeout: 80000,
      gasMultiplier: 2,
    },
  },
  etherscan: {
    apiKey: BLOCK_EXPLORER_KEY,
  },
  gasReporter: {
    currency: 'USD',
    outputFile: 'gas-report.txt',
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
};
