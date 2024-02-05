// SPDX-License-Identifier: Unlicensed
// ZeroSum contract

pragma solidity 0.8.7;
import {Adminable} from "./Adminable.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {ITreasury} from "./interfaces/ITreasury.sol";


contract Treasury is Adminable, ITreasury {
    address public operator;

    constructor(address _operator) {
        operator = _operator;
        _transferOwnership(msg.sender);
    }

    // Must be an ownerOwner because owns tokens
    // Changed only iff Proxy changes
    function setOperator(address newOperator) external override onlyOwner { 
        operator = newOperator;
        emit OperatorUpgraded(operator);
    }

    function withdraw(address token, address to, uint256 amount) external override returns(bool) {
        require(operator == msg.sender, "Treasury: caller is not the operator");
        TransferHelper.safeTransfer(token, to, amount);
        return true;
    }
}