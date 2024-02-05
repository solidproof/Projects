// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is are multiple accounts that can be granted exclusive access to
 * specific functions.
 */
contract Operatable is Context, Ownable {
    mapping(address => bool) private _operators;

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        address msgSender = _msgSender();
        _operators[msgSender] = true;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function isOperator(address addr) public view returns (bool) {
        return _operators[addr];
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function setIsOperator(address addr, bool state) public onlyOwner {
        _operators[addr] = state;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOperators() {
        require(
            isOperator(_msgSender()),
            "Operatable: caller is not an operator"
        );
        _;
    }
}
