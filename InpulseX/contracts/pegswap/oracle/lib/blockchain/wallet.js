import { ethers } from "ethers";
import { rpcList } from "./list.js";
import { getSecrets } from "../secrets.js";
import { getProvider as getCachedProvider } from "./providers.js";

export const getProvider = (chain) => {
  return getCachedProvider(rpcList[chain]);
};

export const getWallet = async (chain) => {
  const { PRIVATE_KEY } = await getSecrets("secrets/inpulsex/wallets");
  const provider = getProvider(chain);
  return new ethers.Wallet(PRIVATE_KEY, provider);
};
