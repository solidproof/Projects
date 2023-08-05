// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Address Helper Library
 * @author Trader Joe
 * @notice This library contains functions to check if an address is a contract and
 * catch low level calls errors
 */
library AddressHelper {
    error AddressHelper__NonContract();
    error AddressHelper__CallFailed();

    /**
     * @notice Private view function to perform a low level call on `target`
     * @dev Revert if the call doesn't succeed
     * @param target The address of the account
     * @param data The data to execute on `target`
     * @return returnData The data returned by the call
     */
    function callAndCatch(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = target.call(data);

        if (success) {
            if (returnData.length == 0 && !isContract(target)) revert AddressHelper__NonContract();
        } else {
            if (returnData.length == 0) {
                revert AddressHelper__CallFailed();
            } else {
                // Look for revert reason and bubble it up if present
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            }
        }

        return returnData;
    }

    /**
     * @notice Private view function to return if an address is a contract
     * @dev It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * @param account The address of the account
     * @return Whether the account is a contract (true) or not (false)
     */
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
