// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MechaniumVesting.sol";

/**
 * @title MechaniumTeamDistribution - Vesting and distribution smart contract for the MechaChain team
 * @notice Can manage multiple allocations with a specific schedule to each
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumTeamDistribution is MechaniumVesting {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    /**
     * ========================
     *  Constants & Immutables
     * ========================
     */

    /// Number of seconds to wait between allocation and the start of the schedule
    uint256 private immutable _timeBeforeStarting;

    /**
     * ========================
     *         Storage
     * ========================
     */

    /// Counter for allocation id
    Counters.Counter internal _allocationIdCounter;

    /// Mapping of allocationId/allocated tokens
    mapping(uint256 => uint256) internal _tokensPerAllocation;

    /// Mapping of allocationId/wallet tokens
    mapping(uint256 => address) internal _walletPerAllocation;

    /// Mapping of startingTime/allocationId tokens
    mapping(uint256 => uint256) internal _startingTimePerAllocation;

    /// Mapping of wallet/array of allocationId tokens
    mapping(address => uint256[]) internal _ownedAllocation;

    /**
     * ========================
     *     Public Functions
     * ========================
     */
    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     * @param timeBeforeStarting_ Number of seconds to wait between allocation and the start of the schedule
     * @param vestingPerClock_ Percentage of unlocked tokens per _vestingClockTime once the vesting schedule has started
     * @param vestingClockTime_ Number of seconds between two _vestingPerClock
     */
    constructor(
        IERC20 token_,
        uint256 timeBeforeStarting_,
        uint256 vestingPerClock_,
        uint256 vestingClockTime_
    ) MechaniumVesting(token_, vestingPerClock_, vestingClockTime_) {
        _timeBeforeStarting = timeBeforeStarting_;
    }

    /**
     * @notice Allocate `amount` token `to` address
     * @param to Address of the beneficiary
     * @param amount Total token to be allocated
     */
    function allocateTokens(address to, uint256 amount)
        public
        override
        onlyRole(ALLOCATOR_ROLE)
        tokensAvailable(amount)
        returns (bool)
    {
        require(amount > 0, "Amount must be superior to 0");
        require(to != address(0), "Address must not be address(0)");
        require(to != address(this), "Address must not be contract address");

        if (_ownedAllocation[to].length == 0) {
            /// first allocation
            _beneficiaryList.push(to);
        }
        uint256 allocationId = _allocationIdCounter.current();
        _allocationIdCounter.increment();

        _tokensPerAllocation[allocationId] = amount;
        _walletPerAllocation[allocationId] = to;
        _startingTimePerAllocation[allocationId] = block.timestamp.add(
            _timeBeforeStarting
        );
        _ownedAllocation[to].push(allocationId);

        _totalAllocatedTokens = _totalAllocatedTokens.add(amount);

        emit Allocated(to, amount);
        if (isSoldOut()) {
            emit SoldOut(totalAllocatedTokens());
        }
        return true;
    }

    /**
     * ========================
     *          Views
     * ========================
     */

    /**
     * @dev Return the amount of allocated tokens for `account` from the beginning
     */
    function allocatedTokensOf(address account)
        public
        view
        override
        returns (uint256)
    {
        uint256 allocatedTokens = 0;
        for (uint256 i = 0; i < _ownedAllocation[account].length; i++) {
            uint256 allocationId = _ownedAllocation[account][i];
            allocatedTokens = allocatedTokens.add(
                _tokensPerAllocation[allocationId]
            );
        }
        return allocatedTokens;
    }

    /**
     * @dev Return the amount of tokens that the `account` can unlock in real time
     */
    function pendingTokensOf(address account)
        public
        view
        override
        returns (uint256)
    {
        uint256 pendingTokens = 0;
        for (uint256 i = 0; i < _ownedAllocation[account].length; i++) {
            uint256 allocId = _ownedAllocation[account][i];
            uint256 allocTokens = allocationTokens(allocId);
            uint256 allocStartingTime = allocationStartingTime(allocId);

            uint256 allocPendingTokens = _pendingTokensCalc(
                allocStartingTime,
                allocTokens
            );
            pendingTokens = pendingTokens.add(allocPendingTokens);
        }
        return pendingTokens.sub(releasedTokensOf(account));
    }

    /**
     * @dev Return the amount of tokens that the `account` can unlock per month
     */
    function unlockableTokens(address account)
        public
        view
        override
        returns (uint256)
    {
        uint256 unlockTokens = 0;
        for (uint256 i = 0; i < _ownedAllocation[account].length; i++) {
            uint256 allocId = _ownedAllocation[account][i];
            uint256 allocTokens = allocationTokens(allocId);
            uint256 allocStartingTime = allocationStartingTime(allocId);

            uint256 allocUnlockTokens = _unlockTokensCalc(
                allocStartingTime,
                allocTokens
            );
            unlockTokens = unlockTokens.add(allocUnlockTokens);
        }
        return unlockTokens.sub(releasedTokensOf(account));
    }

    /**
     * @dev Return the amount of tokens of the allocation
     */
    function allocationCount() public view returns (uint256) {
        return _allocationIdCounter.current();
    }

    /**
     * @dev Return the amount of tokens of the allocation
     */
    function allocationTokens(uint256 allocationId)
        public
        view
        returns (uint256)
    {
        require(
            allocationId < _allocationIdCounter.current(),
            "No allocation at this index"
        );
        return _tokensPerAllocation[allocationId];
    }

    /**
     * @dev Return the address of the allocation owner
     */
    function allocationOwner(uint256 allocationId)
        public
        view
        returns (address)
    {
        require(
            allocationId < allocationCount(),
            "No allocation at this index"
        );
        return _walletPerAllocation[allocationId];
    }

    /**
     * @dev Return the starting time of the allocation
     */
    function allocationStartingTime(uint256 allocationId)
        public
        view
        returns (uint256)
    {
        require(
            allocationId < _allocationIdCounter.current(),
            "No allocation at this index"
        );
        return _startingTimePerAllocation[allocationId];
    }

    /**
     * @dev Return the array of allocationId owned by `wallet`
     */
    function allocationsOf(address wallet)
        public
        view
        returns (uint256[] memory)
    {
        return _ownedAllocation[wallet];
    }

    /**
     * @dev Return the number of seconds to wait between allocation and the start of the schedule
     */
    function timeBeforeStarting() public view returns (uint256) {
        return _timeBeforeStarting;
    }
}
