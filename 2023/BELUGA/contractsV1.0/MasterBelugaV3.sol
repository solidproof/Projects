// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '../contracts-upgradeable/security/PausableUpgradeable.sol';
import '../contracts-upgradeable/proxy/utils/Initializable.sol';
import '../contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import './libraries/Math.sol';
import './interfaces/IAsset.sol';
import './interfaces/IVeBela.sol';
import './interfaces/IBela.sol';
import './interfaces/IMasterBelugaV2.sol';
import './interfaces/IRewarder.sol';
import './interfaces/IPermit.sol';

/// MasterBeluga is a boss. He says "go f your blocks maki boy, I'm gonna use timestamp instead"
/// In addition, he feeds himself from Venom. So, veBela holders boost their (non-dialuting) emissions.
/// This contract rewards users in function of their amount of lp staked (dialuting pool) factor (non-dialuting pool)
/// Factor and sumOfFactors are updated by contract VeBela.sol after any veBela minting/burning (veERC20Upgradeable hook).
/// Note that it's ownable and the owner wields tremendous power. The ownership
/// will be transferred to a governance smart contract once Beluga is sufficiently
/// distributed and the community can show to govern itself.
contract MasterBelugaV3 is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IMasterBelugaV2
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IAsset;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 factor; // non-dialuting factor = sqrt (lpAmount * veBela.balanceOf())
        //
        // We do some fancy math here. Basically, any point in time, the amount of BELAs
        // entitled to a user but is pending to be distributed is:
        //
        //   ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12) -
        //        user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accBelaPerShare`, `accBelaPerFactorShare` (and `lastRewardTimestamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IAsset lpToken; // Address of LP token contract.
        uint256 amount; // Amount of LP token contract.
        uint256 baseAllocPoint; // How many base allocation points assigned to this pool
        uint256 lastRewardTimestamp; // Last timestamp that BELAs distribution occurs.
        uint256 accBelaPerShare; // Accumulated BELAs per share, times 1e12.
        IRewarder rewarder;
        uint256 sumOfFactors; // the sum of all non dialuting factors by all of the users in the pool
        uint256 accBelaPerFactorShare; // accumulated bela per factor share
        uint256 adjustedAllocPoint; // Adjusted allocation points for this pool. BELAs to distribute per second.
    }

    // The strongest beluga out there (bela token).
    IERC20 public bela;
    // Venom does not seem to hurt the Beluga, it only makes it stronger.
    IVeBela public veBela;
    // BELA tokens created per second.
    uint256 public belaPerSec;
    // Emissions: both must add to 1000 => 100%
    // Dialuting emissions repartition (e.g. 300 for 30%)
    uint256 public dialutingRepartition;
    // Non-dialuting emissions repartition (e.g. 500 for 50%)
    uint256 public nonDialutingRepartition;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalBaseAllocPoint;
    // The timestamp when BELA mining starts.
    uint256 public startTimestamp;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Set of all LP tokens that have been added as pools
    EnumerableSet.AddressSet private lpTokens;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Amount of claimable bela the user has
    mapping(uint256 => mapping(address => uint256)) public claimableBela;
    // Total adjusted allocation points. Must be the sum of adjusted allocation points in all pools.
    uint256 public totalAdjustedAllocPoint;
    // The maximum number of pools, in case updateFactor() exceeds block gas limit
    uint256 public maxPoolLength;

    event Add(uint256 indexed pid, uint256 baseAllocPoint, IAsset indexed lpToken, IRewarder indexed rewarder);
    event Set(uint256 indexed pid, uint256 baseAllocPoint, IRewarder indexed rewarder, bool overwrite);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event DepositFor(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(uint256 indexed pid, uint256 lastRewardTimestamp, uint256 lpSupply, uint256 accBelaPerShare);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateEmissionRate(address indexed user, uint256 belaPerSec);
    event UpdateEmissionRepartition(
        address indexed user,
        uint256 dialutingRepartition,
        uint256 nonDialutingRepartition
    );
    event UpdateVeBELA(address indexed user, address oldVeBELA, address newVeBELA);

    /// @dev Modifier ensuring that certain function can only be called by VeBela
    modifier onlyVeBela() {
        require(address(veBela) == msg.sender, 'notVeBela: wut?');
        _;
    }

    function initialize(
        IERC20 _bela,
        IVeBela _veBela,
        uint256 _belaPerSec,
        uint256 _dialutingRepartition,
        uint256 _startTimestamp
    ) public initializer {
        require(address(_bela) != address(0), 'bela address cannot be zero');
        require(address(_veBela) != address(0), 'veBela address cannot be zero');
        require(_belaPerSec != 0, 'bela per sec cannot be zero');
        require(_dialutingRepartition <= 1000, 'dialuting repartition must be in range 0, 1000');

        __Ownable_init();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        bela = _bela;
        veBela = _veBela;
        belaPerSec = _belaPerSec;
        dialutingRepartition = _dialutingRepartition;
        nonDialutingRepartition = 1000 - _dialutingRepartition;
        startTimestamp = _startTimestamp;
        maxPoolLength = 50;
    }

    /**
     * @dev pause pool, restricting certain operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause pool, enabling certain operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function setMaxPoolLength(uint256 _maxPoolLength) external onlyOwner {
        require(poolInfo.length <= _maxPoolLength);
        maxPoolLength = _maxPoolLength;
    }

    /// @notice returns pool length
    function poolLength() external view override returns (uint256) {
        return poolInfo.length;
    }

    /// @notice Add a new lp to the pool. Can only be called by the owner.
    /// @dev Reverts if the same LP token is added more than once.
    /// @param _baseAllocPoint allocation points for this LP
    /// @param _lpToken the corresponding lp token
    /// @param _rewarder the rewarder
    function add(
        uint256 _baseAllocPoint,
        IAsset _lpToken,
        IRewarder _rewarder
    ) public onlyOwner {
        require(Address.isContract(address(_lpToken)), 'add: LP token must be a valid contract');
        require(
            Address.isContract(address(_rewarder)) || address(_rewarder) == address(0),
            'add: rewarder must be contract or zero'
        );
        require(!lpTokens.contains(address(_lpToken)), 'add: LP already added');
        require(poolInfo.length < maxPoolLength, 'add: exceed max pool');

        // update all pools
        massUpdatePools();

        // update last time rewards were calculated to now
        uint256 lastRewardTimestamp = block.timestamp > startTimestamp ? block.timestamp : startTimestamp;

        // update alloc point
        uint256 adjustedAllocPoint = _baseAllocPoint * _assetAdjustFactor(_lpToken);
        totalBaseAllocPoint += _baseAllocPoint;
        totalAdjustedAllocPoint += adjustedAllocPoint;

        // update PoolInfo with the new LP
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                amount: 0,
                baseAllocPoint: _baseAllocPoint,
                lastRewardTimestamp: lastRewardTimestamp,
                accBelaPerShare: 0,
                rewarder: _rewarder,
                sumOfFactors: 0,
                accBelaPerFactorShare: 0,
                adjustedAllocPoint: adjustedAllocPoint
            })
        );

        // add lpToken to the lpTokens enumerable set
        lpTokens.add(address(_lpToken));
        emit Add(poolInfo.length - 1, _baseAllocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's BELA allocation point. Can only be called by the owner.
    /// @param _pid the pool id
    /// @param _baseAllocPoint allocation points
    /// @param _rewarder the rewarder
    /// @param overwrite overwrite rewarder?
    function set(
        uint256 _pid,
        uint256 _baseAllocPoint,
        IRewarder _rewarder,
        bool overwrite
    ) public onlyOwner {
        require(
            Address.isContract(address(_rewarder)) || address(_rewarder) == address(0),
            'set: rewarder must be contract or zero'
        );
        massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];

        totalBaseAllocPoint = totalBaseAllocPoint - pool.baseAllocPoint + _baseAllocPoint;
        pool.baseAllocPoint = _baseAllocPoint;
        // update adjustedAllocPoint point after baseAllocPoint
        _updateAdjustedAllocPoint(pool);

        if (overwrite) {
            pool.rewarder = _rewarder;
        }
        emit Set(_pid, _baseAllocPoint, overwrite ? _rewarder : pool.rewarder, overwrite);
    }

    /// @notice View function to see pending BELAs on frontend.
    /// @param _pid the pool id
    /// @param _user the user address
    /// TODO include factor operations
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        override
        returns (
            uint256 pendingBela,
            address bonusTokenAddress,
            string memory bonusTokenSymbol,
            uint256 pendingBonusToken
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBelaPerShare = pool.accBelaPerShare;
        uint256 accBelaPerFactorShare = pool.accBelaPerFactorShare;
        uint256 lpSupply = pool.amount;
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 belaReward = (secondsElapsed * belaPerSec * pool.adjustedAllocPoint) / totalAdjustedAllocPoint;
            accBelaPerShare += (belaReward * 1e12 * dialutingRepartition) / (lpSupply * 1000);
            if (pool.sumOfFactors != 0) {
                accBelaPerFactorShare += (belaReward * 1e12 * nonDialutingRepartition) / (pool.sumOfFactors * 1000);
            }
        }
        pendingBela =
            ((user.amount * accBelaPerShare + user.factor * accBelaPerFactorShare) / 1e12) +
            claimableBela[_pid][_user] -
            user.rewardDebt;
        // If it's a double reward farm, we return info about the bonus token
        if (address(pool.rewarder) != address(0)) {
            (bonusTokenAddress, bonusTokenSymbol) = rewarderBonusTokenInfo(_pid);
            pendingBonusToken = pool.rewarder.pendingTokens(_user);
        }
    }

    /// @notice Get bonus token info from the rewarder contract for a given pool, if it is a double reward farm
    /// @param _pid the pool id
    function rewarderBonusTokenInfo(uint256 _pid)
        public
        view
        override
        returns (address bonusTokenAddress, string memory bonusTokenSymbol)
    {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.rewarder) != address(0)) {
            bonusTokenAddress = address(pool.rewarder.rewardToken());
            bonusTokenSymbol = IERC20Metadata(pool.rewarder.rewardToken()).symbol();
        }
    }

    /// @notice Update reward variables for all pools.
    /// @dev Be careful of gas spending!
    function massUpdatePools() public override {
        uint256 length = poolInfo.length;
        for (uint256 pid; pid < length; ++pid) {
            _updatePool(pid);
        }
    }

    /// @notice Update reward variables of the given pool to be up-to-date.
    /// @param _pid the pool id
    function updatePool(uint256 _pid) external override {
        _updatePool(_pid);
    }

    function _updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        // update only if now > last time we updated rewards
        if (block.timestamp > pool.lastRewardTimestamp) {
            uint256 lpSupply = pool.amount;

            // if balance of lp supply is 0, update lastRewardTime and quit function
            if (lpSupply == 0) {
                pool.lastRewardTimestamp = block.timestamp;
                return;
            }
            // calculate seconds elapsed since last update
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;

            // calculate bela reward
            uint256 belaReward = (secondsElapsed * belaPerSec * pool.adjustedAllocPoint) / totalAdjustedAllocPoint;
            // update accBelaPerShare to reflect dialuting rewards
            pool.accBelaPerShare += (belaReward * 1e12 * dialutingRepartition) / (lpSupply * 1000);

            // update accBelaPerFactorShare to reflect non-dialuting rewards
            if (pool.sumOfFactors == 0) {
                pool.accBelaPerFactorShare = 0;
            } else {
                pool.accBelaPerFactorShare += (belaReward * 1e12 * nonDialutingRepartition) / (pool.sumOfFactors * 1000);
            }

            // update allocation point
            _updateAdjustedAllocPoint(pool);

            // update lastRewardTimestamp to now
            pool.lastRewardTimestamp = block.timestamp;
            emit UpdatePool(_pid, pool.lastRewardTimestamp, lpSupply, pool.accBelaPerShare);
        }
    }

    /// @notice Deposit LP tokens to MasterChef for BELA allocation on behalf of user
    /// @dev user must initiate transaction from masterchef
    /// @param _pid the pool id
    /// @param _amount amount to deposit
    /// @param _user the user being represented
    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) external override nonReentrant whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        // update pool in case user has deposited
        _updatePool(_pid);
        if (user.amount > 0) {
            // Harvest BELA
            uint256 pending = ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12) +
                claimableBela[_pid][_user] -
                user.rewardDebt;
            claimableBela[_pid][_user] = 0;

            pending = safeBelaTransfer(payable(_user), pending);
            emit Harvest(_user, _pid, pending);
        }

        // update amount of lp staked by user
        user.amount += _amount;
        pool.amount += _amount;

        // update non-dialuting factor
        uint256 oldFactor = user.factor;
        user.factor = Math.sqrt(user.amount * veBela.balanceOf(_user));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt = (user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        if (address(rewarder) != address(0)) {
            rewarder.onBelaReward(_user, user.amount);
        }

        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit DepositFor(_user, _pid, _amount);
    }

    /// @notice update adjusted allocation point for the corresponding pool
    /// @param pool the pool to update
    function _updateAdjustedAllocPoint(PoolInfo storage pool) internal {
        uint256 latestAdjustedAllocPoint = pool.baseAllocPoint * _assetAdjustFactor(pool.lpToken);
        totalAdjustedAllocPoint = totalAdjustedAllocPoint + latestAdjustedAllocPoint - pool.adjustedAllocPoint;
        pool.adjustedAllocPoint = latestAdjustedAllocPoint;
    }

    /// @notice get the interest adjust factor for the pool
    /// @param pid the pool id to query
    function poolAdjustFactor(uint256 pid) external view override returns (uint256) {
        PoolInfo memory pool = poolInfo[pid];
        return _assetAdjustFactor(pool.lpToken);
    }

    /// @notice Get the interest adjust factor for an asset
    /// @param asset the address of asset
    function _assetAdjustFactor(IAsset asset) internal view returns (uint256) {
        uint256 liability = asset.liability();
        // if liability is 0, the default adjust factor is 0
        uint256 r = liability == 0 ? 1 ether : (1 ether * asset.cash()) / liability;
        return _adjustFactor(r);
    }

    /// @notice Get the interest adjust factor by coverage ratio
    /// @param r coverage ratio
    function _adjustFactor(uint256 r) internal pure returns (uint256) {
        if (r == 0) {
            // return an infinite small number in case of division of 0;
            return 1;
        }
        return Math.wdiv(1 ether, 0.2 ether + Math.wdiv(1 ether, r));
    }

    /// @notice Deposit LP tokens to MasterChef for BELA allocation.
    /// @dev it is possible to call this function with _amount == 0 to claim current rewards
    /// @param _pid the pool id
    /// @param _amount amount to deposit
    function deposit(uint256 _pid, uint256 _amount)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        _updatePool(_pid);
        uint256 pending;
        if (user.amount > 0) {
            // Harvest BELA
            pending =
                ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12) +
                claimableBela[_pid][msg.sender] -
                user.rewardDebt;
            claimableBela[_pid][msg.sender] = 0;

            pending = safeBelaTransfer(payable(msg.sender), pending);
            emit Harvest(msg.sender, _pid, pending);
        }

        // update amount of lp staked by user
        user.amount += _amount;
        pool.amount += _amount;

        // update non-dialuting factor
        uint256 oldFactor = user.factor;
        user.factor = Math.sqrt(user.amount * veBela.balanceOf(msg.sender));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt = (user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        uint256 additionalRewards;
        if (address(rewarder) != address(0)) {
            additionalRewards = rewarder.onBelaReward(msg.sender, user.amount);
        }

        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit Deposit(msg.sender, _pid, _amount);
        return (pending, additionalRewards);
    }

    function depositWithPermit(uint256 _pid, uint256 _amount, bytes memory signature) external{
        PoolInfo storage pool = poolInfo[_pid];
        _permit(address(pool.lpToken), msg.sender, signature);
        deposit(_pid,_amount);
    }


    /// @notice claims rewards for multiple pids
    /// @param _pids array pids, pools to claim
    function multiClaim(uint256[] memory _pids)
        external
        override
        nonReentrant
        whenNotPaused
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        return _multiClaim(_pids);
    }

    /// @notice private function to claim rewards for multiple pids
    /// @param _pids array pids, pools to claim
    function _multiClaim(uint256[] memory _pids)
        private
        returns (
            uint256,
            uint256[] memory,
            uint256[] memory
        )
    {
        // accumulate rewards for each one of the pids in pending
        uint256 pending;
        uint256[] memory amounts = new uint256[](_pids.length);
        uint256[] memory additionalRewards = new uint256[](_pids.length);
        for (uint256 i; i < _pids.length; ++i) {
            _updatePool(_pids[i]);
            PoolInfo storage pool = poolInfo[_pids[i]];
            UserInfo storage user = userInfo[_pids[i]][msg.sender];
            if (user.amount > 0) {
                // increase pending to send all rewards once
                uint256 poolRewards = ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) /
                    1e12) +
                    claimableBela[_pids[i]][msg.sender] -
                    user.rewardDebt;

                claimableBela[_pids[i]][msg.sender] = 0;

                // update reward debt
                user.rewardDebt = (user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12;

                // increase pending
                pending += poolRewards;

                amounts[i] = poolRewards;
                // if existant, get external rewarder rewards for pool
                IRewarder rewarder = pool.rewarder;
                if (address(rewarder) != address(0)) {
                    additionalRewards[i] = rewarder.onBelaReward(msg.sender, user.amount);
                }
            }
        }
        // transfer all remaining rewards
        uint256 transfered = safeBelaTransfer(payable(msg.sender), pending);
        if (transfered != pending) {
            for (uint256 i; i < _pids.length; ++i) {
                amounts[i] = (transfered * amounts[i]) / pending;
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        } else {
            for (uint256 i; i < _pids.length; ++i) {
                // emit event for pool
                emit Harvest(msg.sender, _pids[i], amounts[i]);
            }
        }

        return (transfered, amounts, additionalRewards);
    }

    /// @notice Withdraw LP tokens from MasterBeluga.
    /// @notice Automatically harvest pending rewards and sends to user
    /// @param _pid the pool id
    /// @param _amount the amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount)
        external
        override
        nonReentrant
        whenNotPaused
        returns (uint256, uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, 'withdraw: not good');

        _updatePool(_pid);

        // Harvest BELA
        uint256 pending = ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12) +
            claimableBela[_pid][msg.sender] -
            user.rewardDebt;
        claimableBela[_pid][msg.sender] = 0;

        pending = safeBelaTransfer(payable(msg.sender), pending);
        emit Harvest(msg.sender, _pid, pending);

        // for non-dialuting factor
        uint256 oldFactor = user.factor;

        // update amount of lp staked
        user.amount = user.amount - _amount;
        pool.amount -= _amount;

        // update non-dialuting factor
        user.factor = Math.sqrt(user.amount * veBela.balanceOf(msg.sender));
        pool.sumOfFactors = pool.sumOfFactors + user.factor - oldFactor;

        // update reward debt
        user.rewardDebt = (user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12;

        IRewarder rewarder = poolInfo[_pid].rewarder;
        uint256 additionalRewards;
        if (address(rewarder) != address(0)) {
            additionalRewards = rewarder.onBelaReward(msg.sender, user.amount);
        }

        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
        return (pending, additionalRewards);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param _pid the pool id
    function emergencyWithdraw(uint256 _pid) internal nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);

        // update non-dialuting factor
        pool.sumOfFactors = pool.sumOfFactors - user.factor;
        user.factor = 0;

        // update dialuting factors
        user.amount = 0;
        user.rewardDebt = 0;

        // reset rewarder
        IRewarder rewarder = pool.rewarder;
        if (address(rewarder) != address(0)) {
            rewarder.onBelaReward(msg.sender, 0);
        }

        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    /// @notice Safe bela transfer function, just in case if rounding error causes pool to not have enough BELAs.
    /// @param _to beneficiary
    /// @param _amount the amount to transfer
    function safeBelaTransfer(address payable _to, uint256 _amount) internal returns (uint256) {
        uint256 belaBal = bela.balanceOf(address(this));

        // perform additional check in case there are no more bela tokens to distribute.
        // emergency withdraw would be necessary
        require(belaBal > 0, 'No tokens to distribute');

        if (_amount > belaBal) {
            bela.transfer(_to, belaBal);
            return belaBal;
        } else {
            bela.transfer(_to, _amount);
            return _amount;
        }
    }

    /// @notice updates emission rate
    /// @param _belaPerSec bela amount to be updated
    /// @dev Pancake has to add hidden dummy pools inorder to alter the emission,
    /// @dev here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _belaPerSec) external onlyOwner {
        massUpdatePools();
        belaPerSec = _belaPerSec;
        emit UpdateEmissionRate(msg.sender, _belaPerSec);
    }

    /// @notice updates emission repartition
    /// @param _dialutingRepartition the future dialuting repartition
    function updateEmissionRepartition(uint256 _dialutingRepartition) external onlyOwner {
        require(_dialutingRepartition <= 1000);
        massUpdatePools();
        dialutingRepartition = _dialutingRepartition;
        nonDialutingRepartition = 1000 - _dialutingRepartition;
        emit UpdateEmissionRepartition(msg.sender, _dialutingRepartition, 1000 - _dialutingRepartition);
    }

    /// @notice updates veBela address
    /// @param _newVeBela the new VeBela address
    function setVeBela(IVeBela _newVeBela) external onlyOwner {
        require(address(_newVeBela) != address(0));
        massUpdatePools();
        IVeBela oldVeBela = veBela;
        veBela = _newVeBela;
        emit UpdateVeBELA(msg.sender, address(oldVeBela), address(_newVeBela));
    }

    /// @notice updates factor after any veBela token operation (minting/burning)
    /// @param _user the user to update
    /// @param _newVeBelaBalance the amount of veBELA
    /// @dev can only be called by veBela
    function updateFactor(address _user, uint256 _newVeBelaBalance) external override onlyVeBela {
        // loop over each pool : beware gas cost!
        uint256 length = poolInfo.length;

        for (uint256 pid = 0; pid < length; ++pid) {
            UserInfo storage user = userInfo[pid][_user];

            // skip if user doesn't have any deposit in the pool
            if (user.amount == 0) {
                continue;
            }

            PoolInfo storage pool = poolInfo[pid];

            // first, update pool
            _updatePool(pid);
            // calculate pending
            uint256 pending = ((user.amount * pool.accBelaPerShare + user.factor * pool.accBelaPerFactorShare) / 1e12) -
                user.rewardDebt;
            // increase claimableBela
            claimableBela[pid][_user] += pending;
            // get oldFactor
            uint256 oldFactor = user.factor; // get old factor
            // calculate newFactor using
            uint256 newFactor = Math.sqrt(_newVeBelaBalance * user.amount);
            // update user factor
            user.factor = newFactor;
            // update reward debt, take into account newFactor
            user.rewardDebt = (user.amount * pool.accBelaPerShare + newFactor * pool.accBelaPerFactorShare) / 1e12;
            // also, update sumOfFactors
            pool.sumOfFactors = pool.sumOfFactors + newFactor - oldFactor;
        }
    }

    function version() external pure returns (uint256) {
        return 3;
    }

  function _permit(address token, address owner, bytes memory signature) internal {
      (uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(signature,(uint256,uint256,uint8,bytes32,bytes32));
      IPermit(token).permit(owner, address(this), value, deadline, v, r, s);
  }
}