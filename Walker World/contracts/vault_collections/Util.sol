// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * @dev ASM Genome Mining - Utility contract
 */
contract Util {
    error InvalidInput(string errMsg);
    error ContractError(string errMsg);

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string constant ALREADY_INITIALIZED = "Already initialized";
    string constant INVALID_MULTISIG = "Invalid multisig";
    string constant INVALID_DAO = "Invalid DAO";
    string constant INVALID_CONTROLLER = "Invalid Controller";
    string constant INVALID_STAKING_LOGIC = "Invalid Staking Logic";
    string constant INVALID_STAKING_STORAGE = "Invalid Staking Storage";
    string constant INVALID_CONVERTER_LOGIC = "Invalid Converter Logic";
    string constant INVALID_ENERGY_STORAGE = "Invalid Energy Storage";
    string constant INVALID_LBA_ENERGY_STORAGE = "Invalid LBA Energy Storage";
    string constant INVALID_ASTO_CONTRACT = "Invalid ASTO";
    string constant INVALID_LP_CONTRACT = "Invalid LP";
    string constant INVALID_LBA_CONTRACT = "Invalid LBA";
    string constant WRONG_ADDRESS = "Wrong or missed wallet address";
    string constant WRONG_AMOUNT = "Wrong or missed amount";
    string constant WRONG_PERIOD_ID = "Wrong periodId";
    string constant WRONG_TOKEN = "Token not allowed for staking";
    string constant INSUFFICIENT_BALANCE = "Insufficient balance";
    string constant INSUFFICIENT_STAKED_AMOUNT =
        "Requested amount is greater than a stake";
    string constant NO_STAKES = "No stakes yet";

    /**
     * @notice Among others, `isContract` will return false for the following
     * @notice types of addresses:
     * @notice  - an externally-owned account
     * @notice  - a contract in construction
     * @notice  - an address where a contract will be created
     * @notice  - an address where a contract lived, but was destroyed
     *
     * @dev Attention!
     * @dev if _isContract() called from the constructor,
     * @dev addr.code.length will be equal to 0, and
     * @dev this function will return false.
     *
     */
    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }
}
