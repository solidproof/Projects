// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMechaniumVesting.sol";
import "../MechaniumUtils/MechaniumCanReleaseUnintented.sol";

/**
 * @title MechaniumVesting - Abstract class for vesting and distribution smart contract
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
abstract contract MechaniumVesting is
    AccessControl,
    IMechaniumVesting,
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
     * @notice Event emitted when `amount` tokens have been allocated for `to` address
     */
    event Allocated(address indexed to, uint256 amount);

    /**
     * @notice Event emitted when `caller` claimed `amount` tokens for `to` address
     */
    event ClaimedTokens(
        address indexed caller,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Event emitted when `caller` claimed the tokens for all beneficiary address
     */
    event ClaimedTokensToAll(
        address indexed caller,
        uint256 beneficiariesNb,
        uint256 tokensUnlockNb
    );

    /**
     * @notice Event emitted when all tokens have been allocated
     */
    event SoldOut(uint256 totalAllocated);

    /**
     * @notice Event emitted when the last tokens have been claimed
     */
    event ReleasedLastTokens(uint256 totalReleased);

    /**
     * ========================
     *  Constants & Immutables
     * ========================
     */

    /// Role who can call allocate function
    bytes32 public constant ALLOCATOR_ROLE = keccak256("ALLOCATOR_ROLE");

    /// ERC20 basic token contract being held
    IERC20 internal immutable _token;

    /// Percentage of unlocked tokens per _vestingClockTime once the vesting schedule has started
    uint256 internal immutable _vestingPerClock;

    /// Number of seconds between two _vestingPerClock
    uint256 internal immutable _vestingClockTime;

    /**
     * ========================
     *         Storage
     * ========================
     */

    /// Mapping of address/amount of transfered tokens
    mapping(address => uint256) internal _releasedTokens;

    /// List of all the addresses that have allocations
    address[] internal _beneficiaryList;

    /// Total allocated tokens for all the addresses
    uint256 internal _totalAllocatedTokens = 0;

    /// Total transfered tokens for all the addresses
    uint256 internal _totalReleasedTokens = 0;

    /**
     * ========================
     *         Modifiers
     * ========================
     */

    /**
     * @dev Check if the contract has the amount of tokens to allocate
     * @param amount The amount of tokens to allocate
     */
    modifier tokensAvailable(uint256 amount) {
        require(
            _totalAllocatedTokens.add(amount) <= totalSupply(),
            "The contract does not have enough available token to allocate"
        );
        _;
    }

    /**
     * ========================
     *     Public Functions
     * ========================
     */

    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     * @param vestingPerClock_ Percentage of unlocked tokens per _vestingClockTime once the vesting schedule has started
     * @param vestingClockTime_ Number of seconds between two _vestingPerClock
     */
    constructor(
        IERC20 token_,
        uint256 vestingPerClock_,
        uint256 vestingClockTime_
    ) {
        require(vestingPerClock_ <= 100, "Vesting can be greater than 100%");
        _token = token_;
        _vestingPerClock = vestingPerClock_;
        _vestingClockTime = vestingClockTime_;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ALLOCATOR_ROLE, msg.sender);

        _addLockedToken(address(token_));
    }

    /**
     * @notice Allocate `amount` token `to` address
     * @param to Address of the beneficiary
     * @param amount Total token to be allocated
     */
    function allocateTokens(address to, uint256 amount)
        public
        virtual
        override
        returns (bool);

    /**
     * @notice Claim the account's token
     * @param account the account to claim tokens
     */
    function claimTokens(address account) public override returns (bool) {
        uint256 pendingTokens = unlockableTokens(account);
        require(pendingTokens > 0, "No token can be unlocked for this account");

        _releaseTokens(account, pendingTokens);

        emit ClaimedTokens(msg.sender, account, pendingTokens);
        return true;
    }

    /**
     * @notice Claim the account's token
     */
    function claimTokens() public override returns (bool) {
        return claimTokens(msg.sender);
    }

    /**
     * @notice Claim all the accounts tokens (Only by DEFAULT_ADMIN_ROLE)
     */
    function claimTokensForAll()
        public
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        uint256 beneficiariesNb = 0;
        uint256 tokensUnlockNb = 0;
        for (uint256 i = 0; i < _beneficiaryList.length; i++) {
            address beneficiary = _beneficiaryList[i];
            uint256 pendingTokens = unlockableTokens(beneficiary);
            if (pendingTokens > 0) {
                _releaseTokens(beneficiary, pendingTokens);
                beneficiariesNb = beneficiariesNb.add(1);
                tokensUnlockNb = tokensUnlockNb.add(pendingTokens);
            }
        }
        require(tokensUnlockNb > 0, "No token can be unlocked");
        emit ClaimedTokensToAll(msg.sender, beneficiariesNb, tokensUnlockNb);
        return true;
    }

    /**
     * ========================
     *    Internal functions
     * ========================
     */

    /**
     * @notice Send `amount` token `to` address
     * @dev `amount` must imperatively be less or equal to the number of allocated tokens, throw an assert (loss of transaction fees)
     * @param to Address of the beneficiary
     * @param amount Total token to send
     */
    function _releaseTokens(address to, uint256 amount) internal {
        assert(releasedTokensOf(to).add(amount) <= allocatedTokensOf(to));

        _token.safeTransfer(to, amount);

        _releasedTokens[to] = releasedTokensOf(to).add(amount);
        _totalReleasedTokens = _totalReleasedTokens.add(amount);

        if (tokenBalance() == 0) {
            emit ReleasedLastTokens(totalReleasedTokens());
        }
    }

    /**
     * ========================
     *          Views
     * ========================
     */

    /**
     * @dev Return the number of tokens that can be unlock since startTime
     */
    function _unlockTokensCalc(uint256 startTime, uint256 allocation)
        internal
        view
        returns (uint256)
    {
        if (startTime > block.timestamp) {
            return 0;
        }
        uint256 diff = block.timestamp.sub(startTime); // number of seconds since vesting has started
        uint256 clockNumber = diff.div(_vestingClockTime).add(1); // number of clock since vesting has started + 1
        uint256 percentage = clockNumber.mul(_vestingPerClock); // percentage
        if (percentage > 100) {
            // percentage has to be <= to 100%
            percentage = 100;
        }
        return allocation.mul(percentage).div(100);
    }

    /**
     * @dev Return the number of tokens that can be unlock in real time since startTime
     */
    function _pendingTokensCalc(uint256 startTime, uint256 allocation)
        internal
        view
        returns (uint256)
    {
        if (startTime > block.timestamp) {
            return 0;
        }
        uint256 decimals = 18; // decimals to add to the percentage calc
        uint256 diff = block.timestamp.sub(startTime).mul(10**decimals); // number of seconds since vesting has started ** decimals
        uint256 clockNumber = diff.div(_vestingClockTime); // number of clock since vesting has started ** decimals
        uint256 percentage = clockNumber.mul(_vestingPerClock).add(
            _vestingPerClock.mul(10**decimals) // + vesting of the clock 0
        ); // percentage
        if (percentage > 10**(decimals + 2)) {
            // percentage has to be <= to 100%
            percentage = 10**(decimals + 2);
        }
        return allocation.mul(percentage).div(10**(decimals + 2));
    }

    /**
     * @dev Return the amount of tokens locked for `account`
     */
    function balanceOf(address account) public view override returns (uint256) {
        return allocatedTokensOf(account).sub(releasedTokensOf(account));
    }

    /**
     * @dev Return the amount of allocated tokens for `account` from the beginning
     */
    function allocatedTokensOf(address account)
        public
        view
        virtual
        override
        returns (uint256);

    /**
     * @dev Return the amount of tokens that the `account` can unlock in real time
     */
    function pendingTokensOf(address account)
        public
        view
        virtual
        override
        returns (uint256);

    /**
     * @dev Return the amount of tokens that the `account` can unlock per month
     */
    function unlockableTokens(address account)
        public
        view
        virtual
        override
        returns (uint256);

    /**
     * @dev Get released tokens of an address
     */
    function releasedTokensOf(address account)
        public
        view
        override
        returns (uint256)
    {
        return _releasedTokens[account];
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
     * @dev Return the total token unallocated by the contract
     */
    function totalUnallocatedTokens() public view override returns (uint256) {
        return totalSupply().sub(_totalAllocatedTokens);
    }

    /**
     * @dev Return the total allocated tokens for all the addresses
     */
    function totalAllocatedTokens() public view override returns (uint256) {
        return _totalAllocatedTokens;
    }

    /**
     * @dev Return the total tokens that have been transferred among all the addresses
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
     * @dev Return true if all tokens have been allocated
     */
    function isSoldOut() public view override returns (bool) {
        return totalSupply() == totalAllocatedTokens();
    }
}
