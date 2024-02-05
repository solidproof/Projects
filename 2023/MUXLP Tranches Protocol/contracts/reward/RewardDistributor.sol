// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../interfaces/IRewardController.sol";

contract RewardDistributor is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 constant ONE = 1e18;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public referenceToken;
    address rewardToken;
    uint256 lastRewardBalance;
    uint256 cumulativeRewardPerToken;
    mapping(address => uint256) claimableReward;
    mapping(address => uint256) previousCumulatedRewardPerToken;
    mapping(address => bool) public isHandler;

    event Claim(address receiver, uint256 amount);

    modifier onlyHandler() {
        require(isHandler[msg.sender], "RewardDistributor::HANDLER");
        _;
    }

    // deposit mlp
    function initialize(
        string memory name_,
        string memory symbol_,
        address rewardToken_,
        address referenceToken_
    ) external initializer {
        __Ownable_init();

        name = name_;
        symbol = symbol_;
        rewardToken = rewardToken_;
        referenceToken = referenceToken_;
    }

    function setHandler(address handler_, bool enable_) external onlyOwner {
        isHandler[handler_] = enable_;
    }

    function balanceOf(address account) public view returns (uint256) {
        return IERC20Upgradeable(referenceToken).balanceOf(account);
    }

    function totalSupply() public view returns (uint256) {
        return IERC20Upgradeable(referenceToken).totalSupply();
    }

    function updateRewards(address account) external nonReentrant {
        _updateRewards(account);
    }

    function claim(address _receiver) external nonReentrant returns (uint256) {
        return _claim(msg.sender, _receiver);
    }

    function claimFor(
        address account,
        address _receiver
    ) external onlyHandler nonReentrant returns (uint256) {
        return _claim(account, _receiver);
    }

    function _claim(address account, address receiver) private returns (uint256) {
        _updateRewards(account);
        uint256 tokenAmount = claimableReward[account];
        claimableReward[account] = 0;
        if (tokenAmount > 0) {
            lastRewardBalance -= tokenAmount;
            IERC20Upgradeable(rewardToken).safeTransfer(receiver, tokenAmount);
            emit Claim(account, tokenAmount);
        }
        return tokenAmount;
    }

    function claimable(address account) public returns (uint256) {
        _updateRewards(account);
        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return claimableReward[account];
        }
        return
            claimableReward[account] +
            ((balance * (cumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) /
                ONE);
    }

    // account can be 0
    function _updateRewards(address account) private {
        // update new rewards
        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        uint256 reward = balance - lastRewardBalance;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        lastRewardBalance = balance;

        uint256 supply = totalSupply();
        if (supply > 0 && reward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken + ((reward * ONE) / supply);
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }
        if (_cumulativeRewardPerToken == 0) {
            return;
        }
        if (account != address(0)) {
            uint256 accountReward = (balanceOf(account) *
                (_cumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) / ONE;
            uint256 rewards = claimableReward[account] + accountReward;
            claimableReward[account] = rewards;
            previousCumulatedRewardPerToken[account] = _cumulativeRewardPerToken;
        }
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}
