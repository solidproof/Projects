// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../common/Ownable.sol";

contract MasterChefInfoStruct {
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardSTARLDebt; // Reward debt in STARL.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
        uint256 accSTARLPerShare; // Accumulated STARLs per share, times 1e12. See below.
        uint256 lastTotalSTARLReward; // last total rewards
        uint256 lastSTARLRewardBalance; // last STARL rewards tokens
        uint256 totalSTARLReward; // total STARL rewards tokens
    }
}

interface IMasterChef {
    function userInfo(uint256 _pid, address _user) external view returns (MasterChefInfoStruct.UserInfo memory);
    function poolInfo(uint256 _pid) external view returns (MasterChefInfoStruct.PoolInfo memory);
    function deposit(address _user, uint256 _amount) external;
}

contract LiquidityPool is Ownable {
    using SafeMath for uint256;

    // Info of each user.
    struct WithdrawInfo {
        uint256 amount;     // How many LP tokens the user has withdraw.
        bool withdrawStatus; // withdraw done or not
    }

    // Info of each user.
    struct UserLockInfo {
        uint256 amount;     // How many LP tokens the user has withdraw.
        uint256 lockTime; // lockTime of VEMP
    }

    IERC20 public xVEMP;
    IERC20 public VEMP;
    mapping(address => bool) public masterChefStatus;
    uint256 public vempBurnPercent;
    uint256 public xVempHoldPercent;
    uint256 public vempLockPercent;
    uint256 public lockPeriod;
    mapping (address => mapping (address => WithdrawInfo)) public withdrawInfo;
    mapping (address => mapping (address => UserLockInfo)) public userLockInfo;
    mapping (address => address) public chef;

    event UpdateVempBurnPercent(uint256 _oldBurnPercent, uint256 _newBurnPercent);
    event UpdatexVempHoldPercent(uint256 _oldxVEMPHodlPercent, uint256 _newxVEMPHodlPercent);
    event UpdateVempLockPercent(uint256 _oldVempLockPercent, uint256 _newVempLockPercent);
    event UpdateLockPeriod(uint256 _oldLockPeriod, uint256 _newLockPeriod);

    function initialize(address owner_, address _vemp, address _xvemp, uint256 _vempBurnPercent, uint256 _xVempHoldPercent, uint256 _lockPeriod, uint256 _vempLockPercent) public initializer {
        require(owner_ != address(0), "Invalid owner address");
        require(_vemp != address(0), "Invalid vemp address");
        require(_xvemp != address(0), "Invalid xvemp address");

        Ownable.init(owner_);
        VEMP = IERC20(_vemp);
        xVEMP = IERC20(_xvemp);
        vempBurnPercent = _vempBurnPercent;
        xVempHoldPercent = _xVempHoldPercent;
        lockPeriod = _lockPeriod;
        vempLockPercent = _vempLockPercent;
    }

    function whiteListMasterChef(address _masterChef, bool _status) public onlyOwner {
        require(masterChefStatus[_masterChef] != _status, "Already in same status");
        require(address(_masterChef) != address(0), "Invalid address");
        masterChefStatus[_masterChef] = _status;
    }

    function addNewMasterChef(address _oldMasterChef, address _newMasterChef) public onlyOwner {
        require(address(_oldMasterChef) != address(0), "Invalid address");
        require(address(_newMasterChef) != address(0), "Invalid new masterchef address");
        chef[_oldMasterChef] = _newMasterChef;
    }

    function updateVempBurnPercent(uint256 _vempBurnPercent) public onlyOwner {
        emit UpdateVempBurnPercent(vempBurnPercent, _vempBurnPercent);
        vempBurnPercent = _vempBurnPercent;
    }

    function updatexVempHoldPercent(uint256 _xVempHoldPercent) public onlyOwner {
        emit UpdatexVempHoldPercent(xVempHoldPercent, _xVempHoldPercent);
        xVempHoldPercent = _xVempHoldPercent;
    }

    function updateVempLockPercent(uint256 _vempLockPercent) public onlyOwner {
        emit UpdateVempLockPercent(vempLockPercent, _vempLockPercent);
        vempLockPercent = _vempLockPercent;
    }

    function updateLockPeriod(uint256 _lockPeriod) public onlyOwner {
        emit UpdateLockPeriod(lockPeriod, _lockPeriod);
        lockPeriod = _lockPeriod;
    }

    function lock(address _masterChef, uint256 _amount) public {
        require(_masterChef != address(0), "Invalid masterChef Address.");
        require(masterChefStatus[_masterChef] != false, "MasterChef not whiteListed.");

        MasterChefInfoStruct.UserInfo memory userInfo = IMasterChef(_masterChef).userInfo(0, msg.sender);
        UserLockInfo storage user = userLockInfo[_masterChef][msg.sender];
        WithdrawInfo storage   userWithdraw = withdrawInfo[_masterChef][msg.sender];
        require(userInfo.amount.sub(userWithdraw.amount).mul(vempLockPercent).div(1000) <= user.amount.add(_amount), "Insufficient VEMP Locked.");

        VEMP.transferFrom(msg.sender, address(this), _amount);
        user.amount = user.amount.add(_amount);
        if(user.lockTime <= 0)
        user.lockTime = block.timestamp;
    }

    // Unstake the pool. Claim back your staked tokens.
    function unstake(address _masterChef, bool _directStatus, bool _migrate) public {
        require(_masterChef != address(0), "Invalid masterChef Address");
        require(masterChefStatus[_masterChef] != false, "MasterChef not whiteListed");

        MasterChefInfoStruct.UserInfo memory userInfo = IMasterChef(_masterChef).userInfo(0, msg.sender);
        WithdrawInfo storage user = withdrawInfo[_masterChef][msg.sender];
        UserLockInfo storage userLock = userLockInfo[_masterChef][msg.sender];

        require(userInfo.amount > 0, "Not Staked");
        require(userInfo.amount.sub(user.amount) > 0, "Can not withdraw");

        MasterChefInfoStruct.PoolInfo memory poolInfo = IMasterChef(_masterChef).poolInfo(0);
        if(_directStatus) {
            uint256 vempAmount = VEMP.balanceOf(msg.sender);
            uint256 burnAmount = userInfo.amount.sub(user.amount).mul(vempBurnPercent).div(1000);
            if((userLock.amount > 0 && userLock.lockTime.add(lockPeriod) <= block.timestamp) || _migrate) {
                burnAmount = 0;
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount > 0 && userLock.lockTime.add(lockPeriod.div(2)) <= block.timestamp) {
                burnAmount = burnAmount.div(2);
                require(burnAmount <= userLock.amount, "Insufficient VEMP Burn Amount");
                VEMP.transfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount == 0) {
                require(burnAmount <= vempAmount, "Insufficient VEMP Burn Amount");
                VEMP.transferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), burnAmount);
            }
            if(_migrate) {
                IERC20(poolInfo.lpToken).approve(chef[_masterChef], userInfo.amount.sub(user.amount));
                IMasterChef(chef[_masterChef]).deposit(msg.sender, userInfo.amount.sub(user.amount));
            } else {
                poolInfo.lpToken.transfer(msg.sender, userInfo.amount.sub(user.amount));
            }
        } else {
            uint256 xVempAmount = xVEMP.balanceOf(msg.sender);
            require(userInfo.amount.sub(user.amount).mul(xVempHoldPercent).div(1000) <= xVempAmount || _migrate, "Insufficient xVEMP Hold Amount");
            require(userInfo.amount.sub(user.amount).mul(vempLockPercent).div(1000) <= userLock.amount || _migrate, "Insufficient VEMP Locked");
            require(userLock.lockTime.add(lockPeriod) <= block.timestamp  || _migrate, "Lock period not complete.");
            if(_migrate) {
                IERC20(poolInfo.lpToken).approve(chef[_masterChef], userInfo.amount.sub(user.amount));
                IMasterChef(chef[_masterChef]).deposit(msg.sender, userInfo.amount.sub(user.amount));
            } else {
                poolInfo.lpToken.transfer(msg.sender, userInfo.amount.sub(user.amount));
            }
            VEMP.transfer(msg.sender, userLock.amount);
        }
        userLock.amount = 0;
        userLock.lockTime = 0;
        user.amount = user.amount.add(userInfo.amount.sub(user.amount));
        user.withdrawStatus = true;
    }

    /**
     * @dev Used only by admin or owner, used to withdraw locked tokens in emergency
     *
     * @param _token address of erc20 token contract
     * @param _to address of tokens receiver
     * @param _amount amount of token and must be less than total locked amount
     */
    function emergencyWithdrawTokens(address _token, address _to, uint256 _amount)
        public
        onlyOwner
    {
        require(_to != address(0), "Invalid _to address");
        require(_token != address(0), "Invalid _to address");
        uint256 tokenBal = IERC20(_token).balanceOf(address(this));
        require(tokenBal >= _amount, "Insufficiently amount");
        bool status = IERC20(_token).transfer(_to, _amount);
        require(status, "Token transfer failed");
    }
}