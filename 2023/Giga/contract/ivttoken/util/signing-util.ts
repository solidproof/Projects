import { ethers } from 'ethers'
const { TypedDataUtils } = require('ethers-eip712');

const TYPES = {
  EIP712Domain: [
    {
      name: 'name',
      type: 'string'
    },
    {
      name: 'version',
      type: 'string'
    },
    {
      name: 'chainId',
      type: 'uint256'
    },
    {
      name: 'verifyingContract',
      type: 'address'
    }
  ],
  TxnRequest: [
    {
      name: 'to',
      type: 'address'
    },
    {
      name: 'value',
      type: 'uint256'
    },
    {
      name: 'data',
      type: 'bytes'
    },
    {
      name: 'nonce',
      type: 'bytes32'
    }
  ]
}

const getDomain = (chainId: number, contractAddress: string) => {
  return {
    name: 'MultiSig',
    version: '1.0.0',
    chainId: chainId.toString() || '1',
    verifyingContract: contractAddress || ethers.constants.AddressZero
  }
}

export const EIP712 = (contractAddress: string, chainId = 1, params: Record<any, unknown>) => {
  return {
    types: TYPES,
    domain: getDomain(chainId, contractAddress),
    message: {
      to: params.to,
      value: params.value,
      data: params.data,
      nonce: params.nonce
    },
    primaryType: 'TxnRequest'
  }
}


/**
 * @param  {Signer} signer - account signer
 * @param  {string} contractAddress - multisig contract address
 * @param  {Object} params - unsigned transaction payload of type TxnRequest
 */
export const signMessage = async (signer: ethers.Signer, contractAddress: string, params: Record<any, unknown>): Promise<string> => {

  // @ts-expect-error
  const provider: ethers.providers.JsonRpcProvider = signer.provider
  const { chainId } = await provider.getNetwork()

  const digest = TypedDataUtils.encodeDigest(EIP712(contractAddress, chainId, params));
  const signed = await signer.signMessage(digest);

  return signed

}

export const signMessages = async (signers: ethers.Signer[], contractAddress: string, params: Record<any, unknown>): Promise<string[]> => {
  if (signers.length === 0) {
    throw new Error('Please supply an array of signers')
  }
  
  let signatures: string[] = []

  for(let i = 0; i < signers.length; i++) {
    const signature = await signMessage(signers[i], contractAddress, params)
    signatures.push(signature)
  }

  return signatures
}

export const getEthBalance = async (provider: ethers.providers.JsonRpcProvider, address: string) => {
  return await provider.getBalance(address)
}