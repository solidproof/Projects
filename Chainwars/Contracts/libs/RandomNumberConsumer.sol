// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
 * PLEASE DO NOT USE THIS CODE IN PRODUCTION.
 */

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

contract RandomNumberConsumer is VRFConsumerBase, Ownable {
    bytes32 internal keyHash;
    uint256 internal fee;

    mapping(bytes32 => uint256) internal requestIdToRandomNumber;
    mapping(address => bytes32) internal addressToRequestId;

    event RandomnessInitiated(address sender, bytes32 requestId);
    event RandomnessFulfilled(bytes32 requestId);

    /**
     * Constructor inherits VRFConsumerBase
     */
    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _linkFee)
    VRFConsumerBase(_vrfCoordinator, _link) {
        keyHash = _keyHash;
        fee = _linkFee;
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() external returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requestId = requestRandomness(keyHash, fee);
        addressToRequestId[msg.sender] = requestId;
        emit RandomnessInitiated(msg.sender, requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        requestIdToRandomNumber[requestId] = randomness;
        emit RandomnessFulfilled(requestId);
    }

    function withdrawLink(uint256 amount) external onlyOwner {
        LINK.transfer(msg.sender, amount);
    }
}
