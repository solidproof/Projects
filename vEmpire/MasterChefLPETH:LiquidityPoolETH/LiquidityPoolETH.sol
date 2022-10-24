// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../common/Ownable.sol";
import "../common/ReentrancyGuard.sol";

contract MasterChefInfoStruct {
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardETHDebt; // Reward debt in ETH.
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 allocPoint;       // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
        uint256 accETHPerShare; // Accumulated ETHs per share, times 1e12. See below.
        uint256 lastTotalETHReward; // last total rewards
        uint256 lastETHRewardBalance; // last ETH rewards tokens
        uint256 totalETHReward; // total ETH rewards tokens
    }
}

interface IMasterChef {
    function userInfo(address _user) external view returns (MasterChefInfoStruct.UserInfo memory);
    function poolInfo() external view returns (MasterChefInfoStruct.PoolInfo memory);
    function deposit(address _user, uint256 _amount) external payable;
}

contract LiquidityETHPool is Ownable, ReentrancyGuard {
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

    IERC20 public VEMP;
    mapping(address => bool) public masterChefStatus;
    uint256 public vempLockAmount;
    uint256 public lockPeriod;
    mapping (address => mapping (address => WithdrawInfo)) public withdrawInfo;
    mapping (address => mapping (address => UserLockInfo)) public userLockInfo;
    mapping (address => address) public chef;
    mapping (address => mapping( address => bool)) public blackListUser;

    event UpdateVempLockAmount(uint256 _oldLockAmount, uint256 _newLockAmount);
    event UpdateLockPeriod(uint256 _oldLockPeriod, uint256 _newLockPeriod);

    // to recieve ETH from admin
    receive() external payable {}

    function initialize(address owner_, address _vemp, uint256 _vempLockAmount, uint256 _lockPeriod) public initializer {
        require(owner_ != address(0), "Invalid owner address");
        require(_vemp != address(0), "Invalid vemp address");

        Ownable.init(owner_);
        VEMP = IERC20(_vemp);
        vempLockAmount = _vempLockAmount;
        lockPeriod = _lockPeriod;
    }

    function whiteListMasterChef(address _masterChef, bool _status) public onlyOwner {
        require(masterChefStatus[_masterChef] != _status, "Already in same status");
        require(address(_masterChef) != address(0), "Invalid address");
        masterChefStatus[_masterChef] = _status;
    }

    function blackListUsers(address _masterChef, address _user, bool _status) public onlyOwner {
        require(blackListUser[_masterChef][_user] != _status, "Already in same status");
        require(address(_masterChef) != address(0), "Invalid address");
        blackListUser[_masterChef][_user] = _status;
    }

    function addNewMasterChef(address _oldMasterChef, address _newMasterChef) public onlyOwner {
        require(address(_oldMasterChef) != address(0), "Invalid address");
        require(address(_newMasterChef) != address(0), "Invalid new masterchef address");
        chef[_oldMasterChef] = _newMasterChef;
    }

    function updateVempLockAmount(uint256 _vempLockAmount) public onlyOwner {
        emit UpdateVempLockAmount(vempLockAmount, _vempLockAmount);
        vempLockAmount = _vempLockAmount;
    }

    function updateLockPeriod(uint256 _lockPeriod) public onlyOwner {
        emit UpdateLockPeriod(lockPeriod, _lockPeriod);
        lockPeriod = _lockPeriod;
    }

    function lock(address _masterChef) public {
        require(blackListUser[_masterChef][msg.sender] != true, "Not allowed");
        require(_masterChef != address(0), "Invalid masterChef Address.");
        require(masterChefStatus[_masterChef] != false, "MasterChef not whiteListed.");

        MasterChefInfoStruct.UserInfo memory userInfo = IMasterChef(_masterChef).userInfo(msg.sender);
        UserLockInfo storage user = userLockInfo[_masterChef][msg.sender];
        WithdrawInfo storage userWithdraw = withdrawInfo[_masterChef][msg.sender];

        require(userInfo.amount.sub(userWithdraw.amount) > 0, "Not staked amount");
        require(VEMP.balanceOf(msg.sender) >= vempLockAmount, "Insufficient VEMP for Lock.");

        VEMP.transferFrom(msg.sender, address(this), vempLockAmount);
        user.amount = user.amount.add(vempLockAmount);
        if(user.lockTime <= 0)
        user.lockTime = block.timestamp;
    }

    // Unstake the pool. Claim back your staked tokens.
    function unstake(address _masterChef, bool _directStatus, bool _migrate) public nonReentrant {
        require(blackListUser[_masterChef][msg.sender] != true, "Not allowed");
        require(_masterChef != address(0), "Invalid masterChef Address");
        require(masterChefStatus[_masterChef] != false, "MasterChef not whiteListed");

        MasterChefInfoStruct.UserInfo memory userInfo = IMasterChef(_masterChef).userInfo(msg.sender);
        WithdrawInfo storage user = withdrawInfo[_masterChef][msg.sender];
        UserLockInfo storage userLock = userLockInfo[_masterChef][msg.sender];

        require(userInfo.amount > 0, "Not Staked");
        require(userInfo.amount.sub(user.amount) > 0, "Can not withdraw");

        if(_directStatus) {
            uint256 vempAmount = VEMP.balanceOf(msg.sender);
            uint256 burnAmount = vempLockAmount;
            if((userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod) <= block.timestamp) || _migrate) {
                burnAmount = 0;
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod.div(2)) <= block.timestamp) {
                burnAmount = vempLockAmount.div(2);
                require(burnAmount <= userLock.amount, "Insufficient VEMP Burn Amount");
                VEMP.transfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod.div(2)) >= block.timestamp) {
                burnAmount = vempLockAmount;
                require(burnAmount <= userLock.amount, "Insufficient VEMP Burn Amount");
                VEMP.transfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount == 0) {
                require(vempLockAmount <= vempAmount, "Insufficient VEMP Burn Amount");
                VEMP.transferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), vempLockAmount);
            }
            if(_migrate) {
                IMasterChef(chef[_masterChef]).deposit{value:userInfo.amount.sub(user.amount)}(msg.sender, userInfo.amount.sub(user.amount));
            } else {
                payable(msg.sender).transfer(userInfo.amount.sub(user.amount));
            }
        } else {
            require(vempLockAmount <= userLock.amount || _migrate, "Insufficient VEMP Locked");
            require(userLock.lockTime.add(lockPeriod) <= block.timestamp  || _migrate, "Lock period not complete.");
            if(_migrate) {
                IMasterChef(chef[_masterChef]).deposit{value:userInfo.amount.sub(user.amount)}(msg.sender, userInfo.amount.sub(user.amount));
            } else {
                payable(msg.sender).transfer(userInfo.amount.sub(user.amount));
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
     * @param _to address of tokens receiver
     * @param _amount amount of token and must be less than total locked amount
     */
    function emergencyWithdrawTokens(address payable _to, uint256 _amount)
        public
        onlyOwner
        nonReentrant
    {
        require(_to != address(0), "Invalid _to address");
        uint256 tokenBal = address(this).balance;
        require(tokenBal >= _amount, "Insufficiently amount");
        _to.transfer(_amount);
    }
}
