// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMechaniumVestingWallet.sol";
import "../MechaniumUtils/MechaniumCanReleaseUnintented.sol";

/**
 * @title MechaniumVestingWallet - Hold $MECHA allocated for different operations with a vesting schedule
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumVestingWallet is
    IMechaniumVestingWallet,
    AccessControl,
    MechaniumCanReleaseUnintented
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * ========================
     *          Events
     * ========================
     */

    /**
     * @notice Event emitted when `caller` transferred `amount` unlock tokens for `to` address
     */
    event TransferredTokens(
        address indexed caller,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Event emitted when all tokens have been transferred
     */
    event SoldOut(uint256 totalAllocated);

    /**
     * ========================
     *  Constants & Immutables
     * ========================
     */

    /// Role that can transfer the unlock tokens
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /// ERC20 basic token contract being held
    IERC20 internal immutable _token;

    /// Percentage of unlocked tokens per _vestingClockTime once the vesting schedule has started
    uint256 internal immutable _vestingPerClock;

    /// Number of seconds between two _vestingPerClock
    uint256 internal immutable _vestingClockTime;

    /// Percentage of unlocked tokens at the beginning of the vesting schedule
    uint256 internal immutable _initialVesting;

    /// The vesting schedule start time
    uint256 internal immutable _startTime;

    /**
     * ========================
     *         Storage
     * ========================
     */

    /// Total transfered tokens for all the addresses
    uint256 internal _totalReleasedTokens = 0;

    /**
     * ========================
     *     Public Functions
     * ========================
     */

    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     * @param initialVesting_ Percentage of unlocked tokens at the beginning of the vesting schedule
     * @param vestingPerClock_ Percentage of unlocked tokens per _vestingClockTime once the vesting schedule has started
     * @param vestingClockTime_ Number of seconds between two _vestingPerClock
     */
    constructor(
        IERC20 token_,
        uint256 initialVesting_,
        uint256 vestingPerClock_,
        uint256 vestingClockTime_
    ) {
        _token = token_;
        _initialVesting = initialVesting_;
        _vestingPerClock = vestingPerClock_;
        _vestingClockTime = vestingClockTime_;
        _startTime = block.timestamp;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TRANSFER_ROLE, msg.sender);

        _addLockedToken(address(token_));
    }

    /**
     * @notice Transfer `amount` unlocked tokens `to` address
     */
    function transfer(address to, uint256 amount)
        public
        override
        onlyRole(TRANSFER_ROLE)
        returns (bool)
    {
        require(
            amount <= unlockableTokens(),
            "Number of unlocked tokens exceeded"
        );
        assert(amount <= tokenBalance());

        _token.safeTransfer(to, amount);

        _totalReleasedTokens = _totalReleasedTokens.add(amount);

        emit TransferredTokens(msg.sender, to, amount);
        if (tokenBalance() == 0) {
            emit SoldOut(totalReleasedTokens());
        }
        return true;
    }

    /**
     * ========================
     *          Views
     * ========================
     */

    /**
     * @dev Return the number of tokens that can be unlock
     */
    function unlockableTokens() public view override returns (uint256) {
        if (_startTime > block.timestamp) {
            return 0;
        }
        uint256 diff = block.timestamp.sub(_startTime); // number of seconds since vesting has started
        uint256 clockNumber = diff.div(_vestingClockTime); // number of clock since vesting has started
        uint256 percentage = clockNumber.mul(_vestingPerClock).add(
            _initialVesting
        ); // percentage
        if (percentage > 100) {
            // percentage has to be <= to 100%
            percentage = 100;
        }
        return totalSupply().mul(percentage).div(100).sub(_totalReleasedTokens);
    }

    /**
     * @dev Return the token IERC20
     */
    function token() public view override returns (address) {
        return address(_token);
    }

    /**
     * @dev Return the total token hold by the contract
     */
    function tokenBalance() public view override returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @dev Return the total supply of tokens
     */
    function totalSupply() public view override returns (uint256) {
        return tokenBalance().add(_totalReleasedTokens);
    }

    /**
     * @dev Return the total tokens that have been transferred
     */
    function totalReleasedTokens() public view override returns (uint256) {
        return _totalReleasedTokens;
    }

    /**
     * @dev Return the percentage of unlocked tokens per `vestingClockTime()` once the vesting schedule has started
     */
    function vestingPerClock() public view override returns (uint256) {
        return _vestingPerClock;
    }

    /**
     * @dev Return the number of seconds between two `vestingPerClock()`
     */
    function vestingClockTime() public view override returns (uint256) {
        return _vestingClockTime;
    }

    /**
     * @dev Return the percentage of unlocked tokens at the beginning of the vesting schedule
     */
    function initialVesting() public view override returns (uint256) {
        return _initialVesting;
    }

    /**
     * @dev Return vesting schedule start time
     */
    function startTime() public view override returns (uint256) {
        return _startTime;
    }
}
