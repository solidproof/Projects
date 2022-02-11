// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @dev Mechanim distribution smart contract interface
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
interface IMechaniumVesting {
    /**
     * @dev Allocate an amount of tokens to an address ( only allocator role )
     */
    function allocateTokens(address to, uint256 amount) external returns (bool);

    /**
     * @dev Transfers the allocated tokens to an address ( once the distribution has started )
     */
    function claimTokens(address account) external returns (bool);

    /**
     * @dev Transfers the allocated tokens to the sender ( once the distribution has started )
     */
    function claimTokens() external returns (bool);

    /**
     * @dev Transfers the all the allocated tokens to the respective addresses ( once the distribution has started and only by DEFAULT_ADMIN_ROLE)
     */
    function claimTokensForAll() external returns (bool);

    /**
     * @dev Get balance of allocated tokens of an address
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Return the amount of allocated tokens for `account` from the beginning
     */
    function allocatedTokensOf(address account) external view returns (uint256);

    /**
     * @dev Get pending tokens of an account ( amont / time )
     */
    function pendingTokensOf(address account) external view returns (uint256);

    /**
     * @dev Get unlockable tokens of an address
     */
    function unlockableTokens(address account) external view returns (uint256);

    /**
     * @dev Get released tokens of an address
     */
    function releasedTokensOf(address account) external view returns (uint256);

    /**
     * @dev Return the token IERC20
     */
    function token() external view returns (address);

    /**
     * @dev Return the total token hold by the contract
     */
    function tokenBalance() external view returns (uint256);

    /**
     * @dev Get total tokens supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Get total unallocated tokens
     */
    function totalUnallocatedTokens() external view returns (uint256);

    /**
     * @dev Return the total allocated tokens for all the addresses
     */
    function totalAllocatedTokens() external view returns (uint256);

    /**
     * @dev Return the total tokens that have been transferred among all the addresses
     */
    function totalReleasedTokens() external view returns (uint256);

    /**
     * @dev Return the percentage of unlocked tokens per `vestingClockTime()` once the vesting schedule has started
     */
    function vestingPerClock() external view returns (uint256);

    /**
     * @dev Return the number of seconds between two `vestingPerClock()`
     */
    function vestingClockTime() external view returns (uint256);

    /**
     * @dev Return true if all tokens have been allocated
     */
    function isSoldOut() external view returns (bool);
}
