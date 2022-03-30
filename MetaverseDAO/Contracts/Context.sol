// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

abstract contract Context {
    function _msgSender() internal view virtual returns(address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns(bytes memory){
        this;   // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}