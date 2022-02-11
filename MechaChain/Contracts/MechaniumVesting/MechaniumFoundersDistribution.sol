// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./MechaniumTeamDistribution.sol";

/**
 * @title MechaniumFoundersDistribution - Vesting and distribution smart contract for the MechaChain founders
 * @notice Administrators have the right to whitdraw all tokens from the contract if the code fails the audit. If the contract is shifted secure, the whitdraw function is permanently blocked.
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
contract MechaniumFoundersDistribution is MechaniumTeamDistribution {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /**
     * ========================
     *          Events
     * ========================
     */

    /**
     * @notice Event emitted when the `caller` administrator withdraw `amount` tokens (only if the code fails the audit)
     */
    event Withdraw(address indexed caller, uint256 amount);

    /**
     * @notice Event emitted when the administrator `caller` lock permanently the withdraw function
     */
    event WithdrawLocked(address indexed caller);

    /**
     * ========================
     *         Storage
     * ========================
     */

    /// Determines if the administrator has the right to withdraw (cannot be changed once at true)
    bool private _lockWithdraw;

    /**
     * ========================
     *     Public Functions
     * ========================
     */
    /**
     * @dev Contract constructor sets the configuration of the vesting schedule
     * @param token_ Address of the ERC20 token contract, this address cannot be changed later
     */
    constructor(IERC20 token_)
        MechaniumTeamDistribution(
            token_,
            360 days, // 1 year after allocation
            20, // unlock 20%
            180 days // and repeat every 6 months
        )
    {
        _lockWithdraw = false;
    }

    /**
     * @notice Lock permanently the withdraw function
     */
    function lockWithdraw()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        require(!_lockWithdraw, "Whitdraw already locked");

        _lockWithdraw = true;

        emit WithdrawLocked(msg.sender);
        return true;
    }

    /**
     * @notice Withdraw all tokens if the code fails the audit
     */
    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(!_lockWithdraw, "Whitdraw function is permanently blocked");
        uint256 amount = tokenBalance();

        _token.safeTransfer(msg.sender, amount);
        _totalAllocatedTokens = _totalReleasedTokens;

        // reset allocations
        for (uint256 i = 0; i < _allocationIdCounter.current(); i++) {
            _tokensPerAllocation[i] = 0;
        }
        _allocationIdCounter.reset();

        // Set releasedTokens as unique allocation for each beneficiary
        for (uint256 i = 0; i < _beneficiaryList.length; i++) {
            uint256 allocationId = _allocationIdCounter.current();
            address beneficiary = _beneficiaryList[i];
            _walletPerAllocation[allocationId] = beneficiary;
            _tokensPerAllocation[allocationId] = _releasedTokens[beneficiary];
            uint256[1] memory newAllocationList;
            newAllocationList[0] = allocationId;
            _ownedAllocation[beneficiary] = newAllocationList;
            _allocationIdCounter.increment();
        }

        emit Withdraw(msg.sender, amount);
        return true;
    }

    /**
     * ========================
     *          Views
     * ========================
     */

    /**
     * @dev Return true if withdraw is permanently locked
     */
    function isWithdrawLocked() external view returns (bool) {
        return _lockWithdraw;
    }
}
