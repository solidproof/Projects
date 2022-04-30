// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TokenSplitter
 * @notice It splits HLM to team/treasury/trading volume reward accounts based on shares.
 */
contract TokenSplitter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct AccountInfo {
        uint256 shares;
        uint256 tokensDistributedToAccount;
    }

    uint256 public immutable TOTAL_SHARES;

    IERC20 public immutable helixmetaToken;

    // Total HLM tokens distributed across all accounts
    uint256 public totalTokensDistributed;

    mapping(address => AccountInfo) public accountInfo;

    event NewSharesOwner(address indexed oldRecipient, address indexed newRecipient);
    event TokensTransferred(address indexed account, uint256 amount);

    /**
     * @notice Constructor
     * @param _accounts array of accounts addresses
     * @param _shares array of shares per account
     * @param _helixmetaToken address of the HLM token
     */
    constructor(
        address[] memory _accounts,
        uint256[] memory _shares,
        address _helixmetaToken
    ) {
        require(_accounts.length == _shares.length, "Splitter: Length differ");
        require(_accounts.length > 0, "Splitter: Length must be > 0");

        uint256 currentShares;

        for (uint256 i = 0; i < _accounts.length; i++) {
            require(_shares[i] > 0, "Splitter: Shares are 0");

            currentShares += _shares[i];
            accountInfo[_accounts[i]].shares = _shares[i];
        }

        TOTAL_SHARES = currentShares;
        helixmetaToken = IERC20(_helixmetaToken);
    }

    /**
     * @notice Release HLM tokens to the account
     * @param account address of the account
     */
    function releaseTokens(address account) external nonReentrant {
        require(accountInfo[account].shares > 0, "Splitter: Account has no share");

        // Calculate amount to transfer to the account
        uint256 totalTokensReceived = helixmetaToken.balanceOf(address(this)) + totalTokensDistributed;
        uint256 pendingRewards = ((totalTokensReceived * accountInfo[account].shares) / TOTAL_SHARES) -
            accountInfo[account].tokensDistributedToAccount;

        // Revert if equal to 0
        require(pendingRewards != 0, "Splitter: Nothing to transfer");

        accountInfo[account].tokensDistributedToAccount += pendingRewards;
        totalTokensDistributed += pendingRewards;

        // Transfer funds to account
        helixmetaToken.safeTransfer(account, pendingRewards);

        emit TokensTransferred(account, pendingRewards);
    }

    /**
     * @notice Update share recipient
     * @param _newRecipient address of the new recipient
     * @param _currentRecipient address of the current recipient
     */
    function updateSharesOwner(address _newRecipient, address _currentRecipient) external onlyOwner {
        require(accountInfo[_currentRecipient].shares > 0, "Owner: Current recipient has no shares");
        require(accountInfo[_newRecipient].shares == 0, "Owner: New recipient has existing shares");

        // Copy shares to new recipient
        accountInfo[_newRecipient].shares = accountInfo[_currentRecipient].shares;
        accountInfo[_newRecipient].tokensDistributedToAccount = accountInfo[_currentRecipient]
            .tokensDistributedToAccount;

        // Reset existing shares
        accountInfo[_currentRecipient].shares = 0;
        accountInfo[_currentRecipient].tokensDistributedToAccount = 0;

        emit NewSharesOwner(_currentRecipient, _newRecipient);
    }

    /**
     * @notice Retrieve amount of HLM tokens that can be transferred
     * @param account address of the account
     */
    function calculatePendingRewards(address account) external view returns (uint256) {
        if (accountInfo[account].shares == 0) {
            return 0;
        }

        uint256 totalTokensReceived = helixmetaToken.balanceOf(address(this)) + totalTokensDistributed;
        uint256 pendingRewards = ((totalTokensReceived * accountInfo[account].shares) / TOTAL_SHARES) -
            accountInfo[account].tokensDistributedToAccount;

        return pendingRewards;
    }
}