// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./StableSwapLP.sol";

contract StableSwapLPFactory is Ownable {
    event NewStableSwapLP(address indexed swapLPContract, address tokenA, address tokenB, address tokenC);

    constructor() {}

    /**
     * @notice createSwapLP
     * @param tokenA: Addresses of ERC20 conracts .
     * @param tokenB: Addresses of ERC20 conracts .
     * @param tokenC: Addresses of ERC20 conracts .
     * @param minter: Minter address
     */
    function createSwapLP(
        address tokenA,
        address tokenB,
        address tokenC,
        address minter
    ) external onlyOwner returns (address) {
        // create LP token
        require(tokenA != address(0) && tokenB != address(0) && tokenC != address(0), "Illegal token addresses");

        bytes memory bytecode = type(StableSwapLP).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(tokenA, tokenB, tokenC, msg.sender, block.timestamp, block.chainid)
        );
        address lpToken;
        assembly {
            lpToken := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        StableSwapLP(lpToken).setMinter(minter);
        emit NewStableSwapLP(lpToken, tokenA, tokenB, tokenC);
        return lpToken;
    }
}