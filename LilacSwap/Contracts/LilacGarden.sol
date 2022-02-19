// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    function verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
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

abstract contract Initializable {
    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");
        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !Address.isContract(address(this));
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender() || owner() == address(0), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract DevController is Context {
    address private _dev;
    event DevTransferred(address indexed previousDev, address indexed newDev);
    function dev() public view virtual returns (address) {
        return _dev;
    }
    modifier onlyDev() {
        require(dev() == _msgSender() || dev() == address(0), "DevController: caller is not the dev");
        _;
    }
    function renounceDev() public virtual onlyDev {
        _transferDev(address(0));
    }
    function transferDev(address newDev) public virtual onlyDev {
        require(newDev != address(0), "DevController: new dev is the zero address");
        _transferDev(newDev);
    }
    function _transferDev(address newDev) internal virtual {
        address oldDev = _dev;
        _dev = newDev;
        emit DevTransferred(oldDev, newDev);
    }
}

abstract contract ReentrancyGuardUpgradeable is Initializable {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

library SafeMath {
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

interface LilacToken is IERC20 {
    function mint(address _to, uint256 _amount) external;
}

interface IVault is IERC20 {
    function deposit(uint256) external;
    function withdrawAll() external;
}

contract LilacGarden is Ownable, DevController, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 releasePeriod;
        uint256 lockedRewards;
        address referral;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accLilacPerShare;
        uint16 depositFeeBP;
        uint256 stakedBalance;
        IVault vaultToken;
    }

    struct ReferralInfo {
        uint256 userCount;
        uint256 totalReward;
    }

    LilacToken public lilac;
    uint256 public lilacPerBlock;
    uint256 public maxLilacPerBlock;
    uint256 public constant BONUS_MULTIPLIER = 1;

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => ReferralInfo) public referralInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startTime;
    uint256 public lockTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdateEmissionRate(uint256 previousRewardPerBlock, uint256 currentRewardPerBlock);

    function initialize(LilacToken _lilac, uint256 _lilacPerBlock, uint256 _maxLilacPerBlock) public initializer {
        lilac = _lilac;
        lilacPerBlock = _lilacPerBlock;
        maxLilacPerBlock = _maxLilacPerBlock;
        _transferOwnership(_msgSender());
        _transferDev(_msgSender());
        __ReentrancyGuard_init();
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    function add(uint256 _allocPoint, IERC20 _lpToken, uint16 _depositFeeBP) public onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeeBP <= 1000, "add: deposit fee can't be more than 10%");
        massUpdatePools();
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        poolInfo.push(PoolInfo({
            lpToken : _lpToken,
            allocPoint : _allocPoint,
            lastRewardBlock : lastRewardBlock,
            accLilacPerShare : 0,
            depositFeeBP : _depositFeeBP,
            stakedBalance: 0,
            vaultToken: IVault(address(0))
        }));
    }

    function setStartTime(uint256 _newStartTime) public onlyDev {
        startTime = _newStartTime;
    }

    function setHarvestLockup(uint256 _newLockTime) public onlyDev {
        lockTime = _newLockTime;
    }

    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP) public onlyDev {
        require(_depositFeeBP <= 1000, "add: deposit fee can't be more than 10%");
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    function setVault(uint256 _pid, IVault _newVault) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.lpToken.safeApprove(address(_newVault), type(uint).max);
        pool.vaultToken = _newVault;
    }

    function removeVault(uint256 _pid) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.lpToken.safeApprove(address(pool.vaultToken), 0);
        pool.vaultToken = IVault(address(0));
    }

    function enterVault(uint256 _pid, uint256 _amount) public nonReentrant onlyDev {
        PoolInfo storage pool = poolInfo[_pid];
        pool.vaultToken.deposit(_amount);
    }

    function exitVault(uint256 _pid) public nonReentrant onlyDev {
        _exitVault(_pid);
    }

    function _exitVault(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        pool.vaultToken.withdrawAll();
        uint256 totalBalanceWithInterest = pool.lpToken.balanceOf(address(this));
        uint256 interest = totalBalanceWithInterest.sub(pool.stakedBalance);
        pool.lpToken.safeTransfer(dev(), interest);
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function pendingLilac(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accLilacPerShare = pool.accLilacPerShare;
        uint256 lpSupply = pool.stakedBalance;
        if (block.timestamp > startTime && block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 lilacReward = multiplier.mul(lilacPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accLilacPerShare = accLilacPerShare.add(lilacReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accLilacPerShare).div(1e12).sub(user.rewardDebt).add(user.lockedRewards);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= startTime) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 lpSupply = pool.stakedBalance;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 lilacReward = multiplier.mul(lilacPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accLilacPerShare = pool.accLilacPerShare.add(lilacReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount, address _referral) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accLilacPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0 && block.timestamp > user.releasePeriod) {
                pending = pending.add(user.lockedRewards);
                if (user.referral != address(0)) {
                    ReferralInfo storage referral = referralInfo[user.referral];
                    lilac.mint(user.referral, pending.div(50));
                    lilac.mint(_msgSender(), pending.div(50));
                    referral.totalReward = referral.totalReward.add(pending.div(50));
                }
                lilac.mint(_msgSender(), pending);
                lilac.mint(dev(), pending.div(10));
                user.lockedRewards = 0;
                user.releasePeriod = block.timestamp.add(lockTime);
            } else if (pending > 0 && block.timestamp <= user.releasePeriod) {
                user.lockedRewards = user.lockedRewards.add(pending);
            }
        }
        if (_amount > 0) {
            uint256 _before = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
            uint256 _after = pool.lpToken.balanceOf(address(this));
            _amount = _after.sub(_before);
            if (user.releasePeriod == 0) {
                user.releasePeriod = block.timestamp.add(lockTime);
            }
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(dev(), depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
                pool.stakedBalance = pool.stakedBalance.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
                pool.stakedBalance = pool.stakedBalance.add(_amount);
            }
            if (_referral != address(0) && user.referral == address(0)) {
                ReferralInfo storage referral = referralInfo[_referral];
                referral.userCount = referral.userCount.add(1);
                user.referral = _referral;
            }
        }
        user.rewardDebt = user.amount.mul(pool.accLilacPerShare).div(1e12);
        emit Deposit(_msgSender(), _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accLilacPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 && block.timestamp > user.releasePeriod) {
            // Add lockup rewards for payout as well
            pending = pending.add(user.lockedRewards);
            if (user.referral != address(0)) {
                ReferralInfo storage referral = referralInfo[user.referral];
                lilac.mint(user.referral, pending.div(50));
                lilac.mint(_msgSender(), pending.div(50));
                referral.totalReward = referral.totalReward.add(pending.div(50));
            }
            lilac.mint(_msgSender(), pending);
            lilac.mint(dev(), pending.div(10));
            user.lockedRewards = 0;
            user.releasePeriod = block.timestamp.add(lockTime);
        } else if (pending > 0 && block.timestamp <= user.releasePeriod) {
            user.lockedRewards = user.lockedRewards.add(pending);
        }
        if (_amount > 0) {
            uint256 currentBalance = pool.lpToken.balanceOf(address(this));
            if (currentBalance < _amount && address(pool.vaultToken) != address(0)) {
                _exitVault(_pid);
            }
            user.amount = user.amount.sub(_amount);
            pool.stakedBalance = pool.stakedBalance.sub(_amount);
            pool.lpToken.safeTransfer(_msgSender(), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accLilacPerShare).div(1e12);
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        uint256 amount = user.amount;
        uint256 currentBalance = pool.lpToken.balanceOf(address(this));
        user.amount = 0;
        user.rewardDebt = 0;
        if (currentBalance < amount && address(pool.vaultToken) != address(0)) {
            _exitVault(_pid);
        }
        pool.stakedBalance = pool.stakedBalance.sub(amount);
        pool.lpToken.safeTransfer(_msgSender(), amount);
        emit EmergencyWithdraw(_msgSender(), _pid, amount);
    }

    function updateEmissionRate(uint256 _lilacPerBlock) public onlyDev {
        require(_lilacPerBlock <= maxLilacPerBlock, "lilacPerBlock should be lower than maxLilacPerBlock");
        massUpdatePools();
        emit UpdateEmissionRate(lilacPerBlock, _lilacPerBlock);
        lilacPerBlock = _lilacPerBlock;
    }

    function updateMaxEmissionRate(uint256 _maxLilacPerBlock) public onlyOwner {
        maxLilacPerBlock = _maxLilacPerBlock;
    }
}
