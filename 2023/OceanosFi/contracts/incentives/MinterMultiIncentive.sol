// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IController.sol";
import "../interfaces/IIssuedPoolBase.sol";
import "../interfaces/IMinterIncentive.sol";

contract MinterMultiIncentive is IMinterIncentive, Initializable {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    mapping(address => Reward) public rewardData;
    address[] public rewardTokens;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    bool private _lock;

    IController private controller;
    IIssuedPoolBase private issuedPool;

    modifier onlyIncentiveAdmin() {
        require(
            msg.sender == controller.getIncentiveAdmin(),
            "Only incentive admin can call this function"
        );
        _;
    }
    modifier lock() {
        require(!_lock, "reentry");
        _lock = true;
        _;
        _lock = false;
    }

    /* ========== INITIALIZER ========== */

    function initialize(
        IController _controller,
        IIssuedPoolBase _issuedPool
    ) public initializer {
        controller = _controller;
        issuedPool = _issuedPool;
    }

    function addReward(
        address _rewardsToken,
        address _rewardsDistributor,
        uint256 _rewardsDuration
    ) public onlyIncentiveAdmin {
        require(rewardData[_rewardsToken].rewardsDuration == 0);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
    }

    /* ========== VIEWS ========== */

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) public view returns (uint256) {
        return
            Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(
        address _rewardsToken
    ) public view returns (uint256) {
        if (getTotalMintedAmount() == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(_rewardsToken) -
                (rewardData[_rewardsToken].lastUpdateTime)) *
                (rewardData[_rewardsToken].rewardRate) *
                (1e18)) / (getTotalMintedAmount()));
    }

    function earned(
        address account,
        address _rewardsToken
    ) public view returns (uint256) {
        return
            (getMintedAmount(account) *
                (rewardPerToken(_rewardsToken) -
                    (userRewardPerTokenPaid[account][_rewardsToken]))) /
            (1e18) +
            (rewards[account][_rewardsToken]);
    }

    function getRewardForDuration(
        address _rewardsToken
    ) external view returns (uint256) {
        return
            rewardData[_rewardsToken].rewardRate *
            (rewardData[_rewardsToken].rewardsDuration);
    }

    function getMintedAmount(address account) public view returns (uint256) {
        return issuedPool.borrowedPrincipalAmount(account);
    }

    function getTotalMintedAmount() public view returns (uint256) {
        return issuedPool.poolIssuedOcUSD();
    }

    function rewardLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function getRewardRate(
        address _rewardToken
    ) external view returns (uint256) {
        return rewardData[_rewardToken].rewardRate;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function setRewardsDistributor(
        address _rewardsToken,
        address _rewardsDistributor
    ) external onlyIncentiveAdmin {
        rewardData[_rewardsToken].rewardsDistributor = _rewardsDistributor;
    }

    function getReward() public lock updateReward(msg.sender) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, _rewardsToken, reward);
            }
        }
    }

    function refreshReward(address account) external updateReward(account) {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(
        address _rewardsToken,
        uint256 reward
    ) external updateReward(address(0)) {
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the reward amount
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            reward
        );

        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate =
                reward /
                (rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish -
                (block.timestamp);
            uint256 leftover = remaining *
                (rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate =
                (reward + leftover) /
                (rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish =
            block.timestamp +
            (rewardData[_rewardsToken].rewardsDuration);
        emit RewardAdded(reward);
    }

    function setRewardsDuration(
        address _rewardsToken,
        uint256 _rewardsDuration
    ) external {
        require(
            block.timestamp > rewardData[_rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(rewardData[_rewardsToken].rewardsDistributor == msg.sender);
        require(_rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(
            _rewardsToken,
            rewardData[_rewardsToken].rewardsDuration
        );
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        for (uint i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token]
                    .rewardPerTokenStored;
            }
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(
        address indexed user,
        address indexed rewardsToken,
        uint256 reward
    );
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
}
