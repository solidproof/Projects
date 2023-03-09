import { ethers } from "ethers";

const providerCache = {};

export const getProvider = (rpc) => {
  if (!providerCache[rpc]) {
    providerCache[rpc] = rpc.startsWith("wss")
      ? new ethers.providers.WebSocketProvider(rpc)
      : new ethers.providers.JsonRpcProvider(rpc);
  }
  return providerCache[rpc];
};
