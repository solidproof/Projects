import { pegSwaps } from "./list.js";

export const EIP712Domain = (chain) => {
  return {
    name: "InpulseX PegSwap Router",
    version: "1",
    chainId: chain,
    verifyingContract: pegSwaps[chain],
  };
};

export const SwapRequestTypes = {
  SwapRequest: [
    { name: "fromChain", type: "uint256" },
    { name: "toChain", type: "uint256" },
    { name: "operator", type: "address" },
    { name: "recipient", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "nonce", type: "uint256" },
  ],
};
