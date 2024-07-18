// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {OFT} from "lz-oft/oapp/contracts/oft/OFT.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WrappedRUNILz is Ownable, OFT {
    uint256 public chainId;
    uint256 public mainChain;

    constructor(
        address _lzEndpoint,
        address _delegate,
        address _supplyOwner,
        uint256 _mainChain
    ) OFT("Wrapped RUNI", "wRUNI", _lzEndpoint, _delegate) Ownable(_delegate) {
        chainId = block.chainid;
        mainChain = _mainChain;
        if (block.chainid == _mainChain) {
            _mint(_supplyOwner, 21_000_000_000_000);
        }
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function transferDelegateAndOwnership(
        address _newDelegate,
        address _newOwner
    ) external onlyOwner {
        setDelegate(_newDelegate);
        transferOwnership(_newOwner);
    }

    // array of endpoint ids to the same contract address
    function initPeerOnEids(uint32[] calldata _eids) external onlyOwner {
        for (uint256 i = 0; i < _eids.length; i++) {
            setPeer(_eids[i], bytes32(uint256(uint160(address(this)))));
        }
    }
}