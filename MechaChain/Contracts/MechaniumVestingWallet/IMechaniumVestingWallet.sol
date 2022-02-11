// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @dev Mechanim vesting wallet smart contract interface
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
interface IMechaniumVestingWallet {
    
    /**
     * @notice Transfer `amount` unlocked tokens `to` address
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Return the number of tokens that can be unlock
     */
    function unlockableTokens() external view returns (uint256);

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
     * @dev Return the total tokens that have been transferred
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
     * @dev Return the percentage of unlocked tokens at the beginning of the vesting schedule
     */
    function initialVesting() external view returns (uint256);

    /**
     * @dev Return vesting schedule start time
     */
    function startTime() external view returns (uint256);
}
