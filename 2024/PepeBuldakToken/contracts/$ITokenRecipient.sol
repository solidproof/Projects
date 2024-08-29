// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../contracts/GenericToken.sol";

abstract contract $ITokenRecipient is ITokenRecipient {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

contract $GenericToken is GenericToken {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor(string memory name, string memory symbol, uint256 initialSupply) GenericToken(name, symbol, initialSupply) {}

    function $_beforeTokenTransfer(address from,address to,uint256 amount) external {
        return super._beforeTokenTransfer(from,to,amount);
    }

    function $_requireNotPaused() external view {
        return super._requireNotPaused();
    }

    function $_requirePaused() external view {
        return super._requirePaused();
    }

    function $_pause() external {
        return super._pause();
    }

    function $_unpause() external {
        return super._unpause();
    }

    function $_checkOwner() external view {
        return super._checkOwner();
    }

    function $_transferOwnership(address newOwner) external {
        return super._transferOwnership(newOwner);
    }

    function $_transfer(address from,address to,uint256 amount) external {
        return super._transfer(from,to,amount);
    }

    function $_mint(address account,uint256 amount) external {
        return super._mint(account,amount);
    }

    function $_burn(address account,uint256 amount) external {
        return super._burn(account,amount);
    }

    function $_approve(address owner,address spender,uint256 amount) external {
        return super._approve(owner,spender,amount);
    }

    function $_spendAllowance(address owner,address spender,uint256 amount) external {
        return super._spendAllowance(owner,spender,amount);
    }

    function $_afterTokenTransfer(address from,address to,uint256 amount) external {
        return super._afterTokenTransfer(from,to,amount);
    }

    function $_msgSender() external view returns (address) {
        return super._msgSender();
    }

    function $_msgData() external view returns (bytes memory) {
        return super._msgData();
    }

    receive() external payable {}
}