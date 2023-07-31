// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IMlpRewardTracker.sol";
import "./interfaces/IMuxRewardTracker.sol";
import "./interfaces/IVester.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IMintable.sol";
import "./interfaces/IMCB.sol";

contract RewardRouter is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;

    address public weth;
    address public mlp;
    address public mcb;
    address public mux;
    IVotingEscrow public votingEscrow;

    IMlpRewardTracker public mlpFeeTracker; // RewardTracker
    IMlpRewardTracker public mlpMuxTracker; // RewardTracker
    IMuxRewardTracker public veFeeTracker; // VeRewardTracker
    IMuxRewardTracker public veMuxTracker; // VeRewardTracker

    IVester public muxVester;
    IVester public mlpVester;

    bytes32 private _deprecated0;

    IRewardDistributor public mlpDistributor;
    IRewardDistributor public muxDistributor;

    address public protocolLiquidityOwner;
    address public vault;

    address public timelock;

    event StakeMux(address account, address token, uint256 amount, uint256 unlockTime);
    event UnstakeMux(address account, uint256 amount);

    event StakeMlp(address account, uint256 amount);
    event UnstakeMlp(address account, uint256 amount);

    event SetVault(address previousVault, address newVault);
    event SetTimelock(address previousTimelock, address newTimelock);
    event SetProtocolLiquidityOwner(address previousOwner, address newOwner);

    receive() external payable {
        require(msg.sender == weth, "only receive from weth");
    }

    function initialize(
        address[5] memory _tokens,
        address[4] memory _rewardTrackers,
        address[2] memory _vesters,
        address[2] memory _distributors
    ) external initializer {
        __Ownable_init();

        weth = _tokens[0];
        mcb = _tokens[1];
        mux = _tokens[2];
        mlp = _tokens[3];
        votingEscrow = IVotingEscrow(_tokens[4]);

        mlpFeeTracker = IMlpRewardTracker(_rewardTrackers[0]);
        mlpMuxTracker = IMlpRewardTracker(_rewardTrackers[1]);
        veFeeTracker = IMuxRewardTracker(_rewardTrackers[2]);
        veMuxTracker = IMuxRewardTracker(_rewardTrackers[3]);

        mlpVester = IVester(_vesters[0]);
        muxVester = IVester(_vesters[1]);

        mlpDistributor = IRewardDistributor(_distributors[0]);
        muxDistributor = IRewardDistributor(_distributors[1]);
    }

    function setVault(address _vault) external onlyOwner {
        emit SetVault(vault, _vault);
        vault = _vault;
    }

    function setTimelock(address _timelock) external onlyOwner {
        emit SetTimelock(timelock, _timelock);
        timelock = _timelock;
    }

    function setProtocolLiquidityOwner(address _protocolLiquidityOwner) external onlyOwner {
        emit SetProtocolLiquidityOwner(protocolLiquidityOwner, _protocolLiquidityOwner);
        protocolLiquidityOwner = _protocolLiquidityOwner;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    // ========================== aggregated staking interfaces ==========================
    function claimableRewards(
        address account
    )
        external
        returns (
            uint256 mlpFeeAmount,
            uint256 mlpMuxAmount,
            uint256 veFeeAmount,
            uint256 veMuxAmount,
            uint256 mcbAmount
        )
    {
        mlpFeeAmount = mlpFeeTracker.claimable(account);
        mlpMuxAmount = mlpMuxTracker.claimable(account);
        // veFeeAmount = veFeeTracker.claimable(account);
        // veMuxAmount = veMuxTracker.claimable(account);
        mcbAmount = mlpVester.claimable(account);
    }

    function claimAll() external nonReentrant {
        address account = msg.sender;

        mlpFeeTracker.claimForAccount(account, account);
        // veFeeTracker.claimForAccount(account, account);

        // veMuxTracker.claimForAccount(account, account);
        mlpMuxTracker.claimForAccount(account, account);

        // muxVester.claimForAccount(account, account);
        mlpVester.claimForAccount(account, account);
    }

    function claimAllUnwrap() external nonReentrant {
        address account = msg.sender;

        // handle fee
        uint256 feeAmount = mlpFeeTracker.claimForAccount(account, address(this));
        feeAmount += veFeeTracker.claimForAccount(account, address(this));
        if (feeAmount > 0) {
            IWETH(weth).withdraw(feeAmount);
            payable(account).sendValue(feeAmount);
        }

        veMuxTracker.claimForAccount(account, account);
        mlpMuxTracker.claimForAccount(account, account);

        muxVester.claimForAccount(account, account);
        mlpVester.claimForAccount(account, account);
    }

    // ========================== mux & mcb staking interfaces ==========================
    function batchStakeMuxForAccount(
        address[] memory _accounts,
        uint256[] memory _amounts,
        uint256[] memory _unlockTime
    ) external nonReentrant onlyOwner {
        address _mux = mcb;
        for (uint256 i = 0; i < _accounts.length; i++) {
            _stakeForVeToken(msg.sender, _accounts[i], _mux, _amounts[i], _unlockTime[i]);
        }
    }

    function stakeMcbForAccount(address _account, uint256 _amount) external nonReentrant onlyOwner {
        _stakeForVeToken(msg.sender, _account, mcb, _amount, 0);
    }

    function stakeMcb(uint256 _amount, uint256 lockPeriod) external nonReentrant {
        _stakeForVeToken(msg.sender, msg.sender, mcb, _amount, lockPeriod);
    }

    function stakeMux(uint256 _amount, uint256 lockPeriod) external nonReentrant {
        _stakeForVeToken(msg.sender, msg.sender, mux, _amount, lockPeriod);
    }

    function increaseStakeUnlockTime(uint256 lockPeriod) external nonReentrant {
        votingEscrow.increaseUnlockTimeFor(msg.sender, lockPeriod);
        emit StakeMux(msg.sender, msg.sender, 0, lockPeriod);
    }

    function unstakeMcbAndMux() external nonReentrant {
        _unstakeMux(msg.sender);
    }

    function stakeMlp(uint256 _amount) external nonReentrant returns (uint256) {
        require(_amount > 0, "Amount is zero");
        address account = msg.sender;
        mlpFeeTracker.stakeForAccount(account, account, mlp, _amount);
        mlpMuxTracker.stakeForAccount(account, account, address(mlpFeeTracker), _amount);
        emit StakeMlp(account, _amount);
        return _amount;
    }

    function unstakeMlp(uint256 _amount) external nonReentrant returns (uint256) {
        require(_amount > 0, "Amount is zero");
        address account = msg.sender;
        mlpMuxTracker.unstakeForAccount(account, address(mlpFeeTracker), _amount, account);
        mlpFeeTracker.unstakeForAccount(account, mlp, _amount, account);
        emit UnstakeMlp(account, _amount);
        return _amount;
    }

    // ========================== mlp staking interfaces ==========================

    function maxVestableTokenFromMlp(address account) external view returns (uint256) {
        return mlpVester.getMaxVestableAmount(account);
    }

    function totalVestedTokenFromMlp(address account) external view returns (uint256) {
        return mlpVester.getTotalVested(account);
    }

    function claimedVestedTokenFromMlp(address account) external view returns (uint256) {
        return mlpVester.claimedAmounts(account);
    }

    function claimableVestedTokenFromMlp(address account) external view returns (uint256) {
        return mlpVester.claimable(account);
    }

    function depositToMlpVester(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount is zero");
        mlpVester.depositForAccount(msg.sender, amount);
    }

    function withdrawFromMlpVester() external nonReentrant {
        mlpVester.withdrawFor(msg.sender, msg.sender);
    }

    function claimFromMlp() external nonReentrant {
        address account = msg.sender;
        mlpFeeTracker.claimForAccount(account, account);
        mlpMuxTracker.claimForAccount(account, account);
    }

    function claimFromMlpUnwrap() external nonReentrant {
        address account = msg.sender;
        uint256 feeAmount = mlpFeeTracker.claimForAccount(account, address(this));
        if (feeAmount > 0) {
            IWETH(weth).withdraw(feeAmount);
            payable(account).sendValue(feeAmount);
        }
        mlpMuxTracker.claimForAccount(account, account);
    }

    // ========================== ve staking interfaces ==========================

    function maxVestableTokenFromVe(address account) external view returns (uint256) {
        return muxVester.getMaxVestableAmount(account);
    }

    function totalVestedTokenFromVe(address account) external view returns (uint256) {
        return muxVester.getTotalVested(account);
    }

    function claimedVestedTokenFromVe(address account) external view returns (uint256) {
        return muxVester.claimedAmounts(account);
    }

    function claimableVestedTokenFromVe(address account) external view returns (uint256) {
        return muxVester.claimable(account);
    }

    function claimVestedTokenFromVe(address account) external returns (uint256) {
        return muxVester.claimForAccount(account, account);
    }

    function claimFromVe() external nonReentrant {
        address account = msg.sender;
        veFeeTracker.claimForAccount(account, account);
        veMuxTracker.claimForAccount(account, account);
    }

    function claimFromVeUnwrap() external nonReentrant {
        address account = msg.sender;
        uint256 feeAmount = veFeeTracker.claimForAccount(account, address(this));
        if (feeAmount > 0) {
            IWETH(weth).withdraw(feeAmount);
            payable(account).sendValue(feeAmount);
        }
        veMuxTracker.claimForAccount(account, account);
    }

    function depositToVeVester(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount is zero");
        muxVester.depositForAccount(msg.sender, amount);
    }

    function withdrawFromVeVester() external {
        muxVester.withdrawFor(msg.sender, msg.sender);
    }

    // ========================== staking status interfaces ==========================

    function averageStakePeriod() external view returns (uint256) {
        return votingEscrow.averageUnlockTime();
    }

    function unlockTime(address account) external view returns (uint256) {
        return votingEscrow.lockedEnd(account);
    }

    function stakedMlpAmount(address account) external view returns (uint256) {
        return mlpMuxTracker.balanceOf(account);
    }

    function votingEscrowedAmounts(address account) external view returns (uint256, uint256) {
        IVotingEscrow.DepositedBalance memory balances = votingEscrow.depositedBalances(account);
        return (balances.mcbAmount, balances.muxAmount);
    }

    function feeRewardRate() external view returns (uint256) {
        return mlpDistributor.rewardRate();
    }

    function muxRewardRate() external view returns (uint256) {
        return muxDistributor.rewardRate();
    }

    function reservedMlpAmount(address account) external view returns (uint256) {
        return mlpVester.pairAmounts(account);
    }

    function mlpLockAmount(address account, uint256 amount) external view returns (uint256) {
        return mlpVester.getPairAmount(account, amount);
    }

    function poolOwnedRate() public view returns (uint256) {
        uint256 numerator = IERC20Upgradeable(mlp).balanceOf(protocolLiquidityOwner);
        uint256 denominator = numerator + mlpFeeTracker.totalSupply();
        return denominator == 0 ? 0 : (numerator * 1e18) / denominator;
    }

    function votingEscrowedRate() public view returns (uint256) {
        return 0 * 1e17;
    }

    // ========================== reserved interfaces ==========================

    function compound() external nonReentrant {
        _compound(msg.sender);
    }

    function compoundForAccount(address _account) external nonReentrant onlyOwner {
        _compound(_account);
    }

    function batchCompoundForAccounts(address[] memory _accounts) external nonReentrant onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) {
            _compound(_accounts[i]);
        }
    }

    function _compound(address _account) private {
        uint256 muxAmount = veMuxTracker.claimForAccount(_account, _account) +
            mlpMuxTracker.claimForAccount(_account, _account);
        if (muxAmount > 0) {
            _stakeForVeToken(_account, _account, mux, muxAmount, 0);
        }
    }

    function _stakeForVeToken(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _unlockTime
    ) private {
        if (_unlockTime == 0) {
            uint256 lockEnd = votingEscrow.lockedEnd(_account);
            votingEscrow.depositFor(_fundingAccount, _account, _token, _amount, lockEnd);
        } else {
            votingEscrow.depositFor(_fundingAccount, _account, _token, _amount, _unlockTime);
        }
        emit StakeMux(_account, _token, _amount, _unlockTime);
    }

    function _unstakeMux(address _account) private {
        uint256 amount = votingEscrow.lockedAmount(_account);
        votingEscrow.withdrawFor(_account);
        emit UnstakeMux(_account, amount);
    }
}
