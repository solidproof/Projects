import { getSecrets } from "../secrets.js";

const privateRpcEndpoints = await getSecrets("secrets/inpulsex/rpc");
const pegSwapAddresses = await getSecrets("secrets/inpulsex/swaps");

export const rpcList = {
  "binance-mainnet": privateRpcEndpoints.BINANCE_MAINNET,
  "binance-testnet": privateRpcEndpoints.BINANCE_TESTNET,
  "polygon-mainnet": privateRpcEndpoints.POLYGON_MAINNET,
  "polygon-mumbai": privateRpcEndpoints.POLYGON_MUMBAI,
  "ethereum-mainnet": privateRpcEndpoints.ETHEREUM_MAINNET,
  "ethereum-goerli": privateRpcEndpoints.ETHEREUM_GOERLI,
  "avalanche-mainnet": privateRpcEndpoints.AVALANCHE_MAINNET,
  "avalanche-fuji": privateRpcEndpoints.AVALANCHE_FUJI,
};

export const blockchains = Object.keys(rpcList);

export const pegSwaps = {
  "0x38": pegSwapAddresses.BINANCE_MAINNET,
  "0x61": pegSwapAddresses.BINANCE_TESTNET,
  "0x89": pegSwapAddresses.POLYGON_MAINNET,
  "0x13881": pegSwapAddresses.POLYGON_MUMBAI,
  "0x01": pegSwapAddresses.ETHEREUM_MAINNET,
  "0x05": pegSwapAddresses.ETHEREUM_GOERLI,
  "0xa86a": pegSwapAddresses.AVALANCHE_MAINNET,
  "0xa869": pegSwapAddresses.AVALANCHE_FUJI,
};

export const chainIds = {
  "binance-mainnet": "0x38",
  "binance-testnet": "0x61",
  "polygon-mainnet": "0x89",
  "polygon-mumbai": "0x13881",
  "ethereum-mainnet": "0x01",
  "ethereum-goerli": "0x05",
  "avalanche-mainnet": "0xa86a",
  "avalanche-fuji": "0xa869",
};
