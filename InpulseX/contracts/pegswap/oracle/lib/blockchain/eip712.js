import { EIP712Domain, SwapRequestTypes } from "./abi.js";
import { chainIds } from "./list.js";
import { getWallet } from "./wallet.js";

export const sign = async (request) => {
  const wallet = await getWallet(request.blockchain);
  const domain = EIP712Domain(request.entry.event.args.toChain);

  const SwapRequestValues = {
    fromChain: chainIds[request.blockchain],
    toChain: request.entry.event.args.toChain,
    operator: wallet.address,
    recipient: request.entry.event.args.toAddress,
    amount: request.entry.event.args.amount,
    nonce: request.entry.event.args.nonce,
  };

  const signature = await wallet._signTypedData(
    domain,
    SwapRequestTypes,
    SwapRequestValues
  );

  return { signature, request: SwapRequestValues };
};
