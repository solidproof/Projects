const dotenv = require("dotenv");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@matterlabs/hardhat-zksync-verify");
require("@matterlabs/hardhat-zksync-deploy");
require("@matterlabs/hardhat-zksync-solc");
// require("@openzeppelin/hardhat-upgrades");

dotenv.config();
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 500,
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      chainId: 31337, // Chain ID should match the hardhat network's chainid
      forking: {
        url: `https://rpc.ankr.com/eth`,
      },
      loggingEnabled: true,
    },
    hardhat: {
      // zksync: true,
      forking: {
        url: `https://rpc.ankr.com/eth`,
      },
    },
    draculaTest: {
      url: "https://api-dex.draculafi.xyz/rpc",
    },
    zksync: {
      url: "https://mainnet.era.zksync.io/",
      zksync: true,
      ethNetwork: "zksync",
      // Verification endpoint for Mainnet
      verifyURL:
        "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
      // accounts: [process.env.DEPLOYER_PRIVKEY],
    },
    zksyncTestnet: {
      url: "https://testnet.era.zksync.dev",
      zksync: true,
      ethNetwork: "goerli",
      // accounts: [process.env.DEPLOYER_PRIVKEY],
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 21,
    outputFile: "./gasReporting.md",
    noColors: true,
  },
};
