// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev Determine whether or not this contract supports a given interface, as defined by ERC165.
 */
interface IERC165 {
    /**
     * @notice Determine whether or not this contract supports a given interface.
     *
     * @dev [ERC165] Implements the ERC165 API.
     * 
     * @param interfaceId The result of xor-ing together the function selectors of all functions in the interface
     * of interest.
     * @return implementsInterface `true` if this contract implements the requested interface.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

