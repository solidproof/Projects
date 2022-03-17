// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

library LowGasSafeMath {
    /// @notice Returns x + y, reverts if sum overflows uint256
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    function add32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        require((z = x + y) >= x);
    }

    /// @notice Returns x - y, reverts if underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    function sub32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        require((z = x - y) <= x);
    }

    /// @notice Returns x * y, reverts if overflows
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return z The product of x and y
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    function mul32(uint32 x, uint32 y) internal pure returns (uint32 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice Returns x + y, reverts if overflows or underflows
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice Returns x - y, reverts if overflows or underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }

    function div(uint256 x, uint256 y) internal pure returns(uint256 z){
        require(y > 0);
        z=x/y;
    }
}

library Address {

  function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function burn(uint256 amount) external;

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    using LowGasSafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

interface IDistributor {
    function distribute() external returns ( bool );
}

// 7.97%
contract ConsensusPool {

    using LowGasSafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 power;
        uint256 number;
        uint256 reward;
        uint256 totalReward;
        uint256 rewardCounter;
        uint256 claimCounter;
        uint256 burnAmount;
        uint256 totalBurnAmount;
        uint256 inviteeCounter;
        address inviter;
    }

    struct InviteeInfo {
        uint256 power;
        uint256 claimCounterSnapshot;
    }

    struct Epoch {
        uint256 length;
        uint256 number;
        uint256 endBlock;
        uint256 distribute;
    }

    struct EpochInfo {
        uint256 rewardPerPower;
        uint256 rewardPerPowerStoredSnapshot;
    }

    address public SYNASSETS;
    address public sSYNASSETS;

    uint256 public totalPower;
    uint256 public rewardPerPowerStored;
    uint256 public totalRewardReserves;
    mapping(address => UserInfo) public userInfos;
    mapping(address => mapping(address => InviteeInfo)) public inviteeInfos;

    mapping(uint256 => EpochInfo) public epochInfos;

    Epoch public epoch;
    address public distributor;
    address public stakingContract;

    uint256 public constant REWARD_LIMIT = 9;
    uint256 public constant RATIO_DECAY = 797;   // in(1/10000)
    uint256 public constant RATIO_DECAY_T10 = 5642;

    event Invited(address indexed inviter, address user);
    event RewardAdded(uint256 reward);
    event RewardBurn(address indexed account, uint256 reward);
    event Staked(address indexed staker, address indexed inviter, uint256 amount);
    event Unstaked(address indexed unstaker, address indexed inviter, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    function initialize (
        address _SYNASSETS,
        address _sSYNASSETS,
        uint256 _epochLength,
        uint256 _firstEpochNumber,
        uint256 _firstEpochBlock,
        address _stakingContract,
        address _distributor
    ) external {
        require( SYNASSETS == address(0), 'AI' );

        require( _SYNASSETS != address(0) );
        SYNASSETS = _SYNASSETS;

        require( _sSYNASSETS != address(0) );
        sSYNASSETS = _sSYNASSETS;

        epoch = Epoch({
            length: _epochLength,
            number: _firstEpochNumber,
            endBlock: _firstEpochBlock,
            distribute: 0
            });

        stakingContract = _stakingContract;
        distributor = _distributor;
    }

    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, 'OSC');
        _;
    }

    /* ====== PUBLIC FUNCTIONS ====== */

    function stake(address _staker, address _inviter, uint256 _amount) external onlyStakingContract() {
        if (userInfos[_staker].inviter == address(0)) {
            userInfos[_staker].inviter = _inviter;
            userInfos[_inviter].inviteeCounter ++;
            emit Invited(_inviter, _staker);
        }
        _inviter = userInfos[_staker].inviter;
        require(_inviter != address(0), 'IA');

        _notifyRewardAmount();
        _updateReward(_inviter);

        totalPower = totalPower.add(_amount);
        userInfos[_inviter].power = userInfos[_inviter].power.add(_amount);

        uint256 _powerBefore = _calcPower(_inviter, _staker);
        inviteeInfos[_inviter][_staker].power = _powerBefore.add(_amount);
        inviteeInfos[_inviter][_staker].claimCounterSnapshot = userInfos[_inviter].claimCounter;

        emit Staked(_staker, _inviter, _amount);
    }

    function unstake(address _unstaker, uint256 _amount) external onlyStakingContract() {
        address _inviter = userInfos[_unstaker].inviter;

        _updateReward(_inviter);

        uint256 _powerBefore = _calcPower(_inviter, _unstaker);
        uint256 _powerAfter = _powerBefore.sub(_powerBefore.mul(_amount).div(_amount.add(IERC20(sSYNASSETS).balanceOf(_unstaker))));

        totalPower = totalPower.add(_powerAfter).sub(_powerBefore);
        userInfos[_inviter].power = userInfos[_inviter].power.add(_powerAfter).sub(_powerBefore);

        inviteeInfos[_inviter][_unstaker].power = _powerAfter;
        inviteeInfos[_inviter][_unstaker].claimCounterSnapshot = userInfos[_inviter].claimCounter;

        emit Unstaked(_unstaker, _inviter, _amount);
    }

    function claimReward() external {
        _updateReward(msg.sender);

        uint256 _reward = userInfos[msg.sender].reward;
        if (_reward > 0) {
            userInfos[msg.sender].reward = 0;
            userInfos[msg.sender].claimCounter = userInfos[msg.sender].claimCounter.add(userInfos[msg.sender].rewardCounter);
            userInfos[msg.sender].rewardCounter = 0;
            IERC20(SYNASSETS).safeTransfer(msg.sender, _reward);

            uint256 _burnAmount = userInfos[msg.sender].burnAmount;
            if (_burnAmount > 0) {
                IERC20(SYNASSETS).burn(_burnAmount);
                emit RewardBurn(msg.sender, _burnAmount);

                userInfos[msg.sender].burnAmount = 0;
            }

            totalRewardReserves = totalRewardReserves.sub(_reward.add(_burnAmount));

            emit RewardPaid(msg.sender, _reward);
        }
    }

    /* ====== INTERNAL FUNCTIONS ====== */

    function _updateReward(address _account) internal {
        UserInfo memory _userInfo = userInfos[_account];
        if (_userInfo.power > 0) {
            (uint256 _reward, uint256 _number, uint256 _power, uint256 _rewardCounter) = _calcReward(_userInfo);

            if (_rewardCounter > 0) {
                userInfos[_account].power = _power;
                totalPower = totalPower.add(_power).sub(_userInfo.power);

                userInfos[_account].reward = _userInfo.reward.add(_reward);
                userInfos[_account].totalReward = _userInfo.totalReward.add(_reward);
                userInfos[_account].rewardCounter = _userInfo.rewardCounter.add(_rewardCounter);
            }

            if (_number < epoch.number) {
                uint256 burnAmountPerPower = rewardPerPowerStored.sub(epochInfos[_number].rewardPerPowerStoredSnapshot);
                if (burnAmountPerPower > 0) {
                    uint256 burnAmount = _userInfo.power.mul(burnAmountPerPower).div(1 ether);

                    userInfos[_account].burnAmount = _userInfo.burnAmount.add(burnAmount);
                    userInfos[_account].totalBurnAmount = _userInfo.totalBurnAmount.add(burnAmount);
                }
            }
        }

        userInfos[_account].number = epoch.number;
    }

    function _notifyRewardAmount() internal {
        if (epoch.endBlock <= block.number) {
            uint256 distribute = epoch.distribute;
            if (distribute > 0) {
                emit RewardAdded(distribute);

                if (totalPower == 0) {
                    IERC20(SYNASSETS).burn(distribute);
                    emit RewardBurn(address(0), distribute);

                    totalRewardReserves = totalRewardReserves.sub(distribute);
                } else {
                    uint256 _rewardPerPower = distribute.mul(1 ether).div(totalPower);
                    rewardPerPowerStored = rewardPerPowerStored.add(_rewardPerPower);
                    uint256 number = epoch.number;
                    epochInfos[number].rewardPerPower = _rewardPerPower;
                    epochInfos[number].rewardPerPowerStoredSnapshot = rewardPerPowerStored;
                }
            }

            epoch.endBlock = epoch.endBlock.add(epoch.length);
            epoch.number++;

            if (distributor != address(0)) {
                IDistributor(distributor).distribute();
            }

            uint256 balance = IERC20(SYNASSETS).balanceOf(address(this));
            if (balance <= totalRewardReserves)
                epoch.distribute = 0;
            else
                epoch.distribute = balance.sub(totalRewardReserves);

            totalRewardReserves = balance;
        }
    }

    /* ====== VIEW FUNCTIONS ====== */

    function getInfo(address _account) public view returns (uint256 claimableAmount, uint256 totalReward, uint256 power, uint256 inviteNum, uint256 burnAmount) {
        UserInfo memory _userInfo = userInfos[_account];
        (uint256 _reward, , uint256 _power,) = _calcReward(_userInfo);

        return (_reward.add(_userInfo.reward), _reward.add(_userInfo.totalReward), _power, _userInfo.inviteeCounter, _userInfo.totalBurnAmount);
    }

    function _calcPower(address _account, address _invitee) internal view returns (uint256) {
        uint256 _claimCounter = userInfos[_account].claimCounter;
        InviteeInfo memory _info = inviteeInfos[_account][_invitee];

        if (_claimCounter <= _info.claimCounterSnapshot) return _info.power;

        uint256 _t = _claimCounter - _info.claimCounterSnapshot;
        if (_t >= 100) return 0;

        uint256 _powerDecay = _info.power;
        uint256 _t10 = _t / 10;
        if (_t10 > 0) _powerDecay = _powerDecay.mul((10000 - RATIO_DECAY_T10) ** _t10).div(10000 ** _t10);
        uint256 _t1 = _t % 10;
        if (_t1 > 0) _powerDecay = _powerDecay.mul((10000 - RATIO_DECAY) ** _t1).div(10000 ** _t1);

        return _powerDecay;
    }

    function _calcReward(UserInfo memory _userInfo) internal view returns (uint256 reward_, uint256 number_, uint256 power_, uint256 rewardCounter_) {
        uint256 _number = epoch.number;

        reward_ = 0;
        number_ = _userInfo.number;
        power_ = _userInfo.power;
        rewardCounter_ = 0;
        for (; number_ < _number && _userInfo.rewardCounter.add(rewardCounter_) < REWARD_LIMIT; number_ = number_.add(1)) {
            reward_ = reward_.add(epochInfos[number_].rewardPerPower.mul(power_).div(1 ether));
            power_ = power_.mul((10000 - RATIO_DECAY)).div(10000);
            rewardCounter_ ++;
        }

        number_ = number_.sub(1);
    }

}