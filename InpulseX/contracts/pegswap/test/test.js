const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PegSwap", function () {
  it("Should verify signed messages", async function () {
    const Swap = await ethers.getContractFactory("Swap");
    const swap = await Swap.deploy();
    await swap.deployed();

    const [_owner, addr1, addr2] = await ethers.getSigners();

    const chainId = await swap.getChainId();

    const EIP712Domain = {
      name: "InpulseX PegSwap Router",
      version: "1",
      chainId: chainId,
      verifyingContract: swap.address,
    };

    const SwapRequestTypes = {
      SwapRequest: [
        { name: "fromChain", type: "uint256" },
        { name: "toChain", type: "uint256" },
        { name: "operator", type: "address" },
        { name: "recipient", type: "address" },
        { name: "amount", type: "uint256" },
        { name: "nonce", type: "uint256" },
      ],
    };

    const SwapRequestValues = {
      fromChain: 22,
      toChain: 10,
      operator: addr1.address, // Our oracle
      recipient: addr2.address, // User
      amount: "10000000000000000000000000000",
      nonce: 4,
    };

    /*
      struct SwapRequest {
        uint8 fromChain;
        uint8 toChain;
        address operator;
        address recipient;
        uint256 amount;
        uint256 nonce;
      }
    */

    const signed = await addr1._signTypedData(
      EIP712Domain,
      SwapRequestTypes,
      SwapRequestValues
    );

    const { r, s, v } = ethers.utils.splitSignature(signed);

    const isVerified = await swap
      .connect(addr2)
      .verify(SwapRequestValues, v, r, s);

    expect(isVerified).to.be.true;
  });
});
