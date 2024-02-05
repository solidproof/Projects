// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IRewardTracker.sol";

contract MlpRewardTracker is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    IERC20Upgradeable,
    IRewardTracker
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    IRewardDistributor public distributor;
    mapping(address => bool) public isDepositToken;
    mapping(address => mapping(address => uint256)) public override depositBalances;
    mapping(address => uint256) public totalDepositSupply;

    uint256 public override totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    uint256 public cumulativeRewardPerToken;
    mapping(address => uint256) public override stakedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulatedRewardPerToken;
    mapping(address => uint256) public override cumulativeRewards;
    mapping(address => uint256) public override averageStakedAmounts;

    bool public inPrivateTransferMode;
    bool public inPrivateStakingMode;
    bool public inPrivateClaimingMode;
    mapping(address => bool) public isHandler;

    uint256 public lastRewardBalance;

    event Claim(address receiver, uint256 amount);

    // deposit mlp
    function initialize(
        string memory _name,
        string memory _symbol,
        address[] memory _depositTokens,
        address _distributor
    ) external initializer {
        __Ownable_init();

        name = _name;
        symbol = _symbol;
        for (uint256 i = 0; i < _depositTokens.length; i++) {
            address depositToken = _depositTokens[i];
            isDepositToken[depositToken] = true;
        }
        distributor = IRewardDistributor(_distributor);
    }

    function setDepositToken(address _depositToken, bool _isDepositToken) external onlyOwner {
        isDepositToken[_depositToken] = _isDepositToken;
    }

    function setInPrivateTransferMode(bool _inPrivateTransferMode) external onlyOwner {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    function setInPrivateStakingMode(bool _inPrivateStakingMode) external onlyOwner {
        inPrivateStakingMode = _inPrivateStakingMode;
    }

    function setInPrivateClaimingMode(bool _inPrivateClaimingMode) external onlyOwner {
        inPrivateClaimingMode = _inPrivateClaimingMode;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    function stake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _stake(msg.sender, msg.sender, _depositToken, _amount);
    }

    function stakeForAccount(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) external override nonReentrant {
        _validateHandler();
        _stake(_fundingAccount, _account, _depositToken, _amount);
    }

    function unstake(address _depositToken, uint256 _amount) external override nonReentrant {
        if (inPrivateStakingMode) {
            revert("RewardTracker: action not enabled");
        }
        _unstake(msg.sender, _depositToken, _amount, msg.sender);
    }

    function unstakeForAccount(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) external override nonReentrant {
        _validateHandler();
        _unstake(_account, _depositToken, _amount, _receiver);
    }

    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }

        uint256 nextAllowance = allowances[_sender][msg.sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds allowance"
        );
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function updateRewards() external override nonReentrant {
        _updateRewards(address(0));
    }

    function claim(address _receiver) external override nonReentrant returns (uint256) {
        if (inPrivateClaimingMode) {
            revert("RewardTracker: action not enabled");
        }
        return _claim(msg.sender, _receiver);
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _claim(_account, _receiver);
    }

    function claimable(address _account) public override returns (uint256) {
        _updateRewards(_account);

        uint256 stakedAmount = stakedAmounts[_account];
        if (stakedAmount == 0) {
            return claimableReward[_account];
        }
        uint256 supply = totalSupply;
        uint256 pendingRewards = distributor.pendingMlpRewards();
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken.add(
            pendingRewards.mul(1e18).div(supply)
        );
        return
            claimableReward[_account].add(
                stakedAmount
                    .mul(
                        nextCumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])
                    )
                    .div(1e18)
            );
    }

    function rewardToken() public view returns (address) {
        return distributor.rewardToken();
    }

    function _claim(address _account, address _receiver) private returns (uint256) {
        _updateRewards(_account);

        uint256 tokenAmount = claimableReward[_account];
        claimableReward[_account] = 0;

        if (tokenAmount > 0) {
            lastRewardBalance -= tokenAmount;
            IERC20Upgradeable(rewardToken()).safeTransfer(_receiver, tokenAmount);
            emit Claim(_account, tokenAmount);
        }

        return tokenAmount;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: mint to the zero address");

        totalSupply = totalSupply.add(_amount);
        balances[_account] = balances[_account].add(_amount);

        emit Transfer(address(0), _account, _amount);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "RewardTracker: burn from the zero address");

        balances[_account] = balances[_account].sub(
            _amount,
            "RewardTracker: burn amount exceeds balance"
        );
        totalSupply = totalSupply.sub(_amount);

        emit Transfer(_account, address(0), _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "RewardTracker: transfer from the zero address");
        require(_recipient != address(0), "RewardTracker: transfer to the zero address");

        if (inPrivateTransferMode) {
            _validateHandler();
        }

        balances[_sender] = balances[_sender].sub(
            _amount,
            "RewardTracker: transfer amount exceeds balance"
        );
        balances[_recipient] = balances[_recipient].add(_amount);

        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "RewardTracker: approve from the zero address");
        require(_spender != address(0), "RewardTracker: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "RewardTracker: forbidden");
    }

    function _stake(
        address _fundingAccount,
        address _account,
        address _depositToken,
        uint256 _amount
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");

        IERC20Upgradeable(_depositToken).safeTransferFrom(_fundingAccount, address(this), _amount);

        _updateRewards(_account);

        stakedAmounts[_account] = stakedAmounts[_account].add(_amount);
        depositBalances[_account][_depositToken] = depositBalances[_account][_depositToken].add(
            _amount
        );
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken].add(_amount);

        _mint(_account, _amount);
    }

    function _unstake(
        address _account,
        address _depositToken,
        uint256 _amount,
        address _receiver
    ) private {
        require(_amount > 0, "RewardTracker: invalid _amount");
        require(isDepositToken[_depositToken], "RewardTracker: invalid _depositToken");
        _updateRewards(_account);
        uint256 stakedAmount = stakedAmounts[_account];
        require(stakedAmounts[_account] >= _amount, "RewardTracker: _amount exceeds stakedAmount");

        stakedAmounts[_account] = stakedAmount.sub(_amount);
        uint256 depositBalance = depositBalances[_account][_depositToken];
        require(depositBalance >= _amount, "RewardTracker: _amount exceeds depositBalance");
        depositBalances[_account][_depositToken] = depositBalance.sub(_amount);
        totalDepositSupply[_depositToken] = totalDepositSupply[_depositToken].sub(_amount);

        _burn(_account, _amount);
        IERC20Upgradeable(_depositToken).safeTransfer(_receiver, _amount);
    }

    function _updateRewards(address _account) private {
        // distribute pending rewards and update reward to release
        distributor.distribute();

        uint256 balance = IERC20Upgradeable(rewardToken()).balanceOf(address(this));
        uint256 reward = balance - lastRewardBalance;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        lastRewardBalance = balance;

        if (totalSupply > 0 && reward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(
                reward.mul(1e18).div(totalSupply)
            );
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint256 accountReward = stakedAmounts[_account]
                .mul(_cumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account]))
                .div(1e18);
            uint256 _claimableReward = claimableReward[_account].add(accountReward);

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && stakedAmounts[_account] > 0) {
                uint256 currentCumulativeReward = cumulativeRewards[_account].add(accountReward);

                averageStakedAmounts[_account] = averageStakedAmounts[_account]
                    .mul(cumulativeRewards[_account])
                    .div(currentCumulativeReward)
                    .add(stakedAmounts[_account].mul(accountReward).div(currentCumulativeReward));
                cumulativeRewards[_account] = currentCumulativeReward;
            }
        }
    }
}
