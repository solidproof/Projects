// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        (bool success, ) = recipient.call{value: amount}('');
        require(success, 'Address: unable to send value, recipient may have reverted');
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, 'Address: low-level call failed');
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, 'Address: low-level call with value failed');
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, 'Address: insufficient balance for call');
        require(isContract(target), 'Address: call to non-contract');

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, 'Address: low-level static call failed');
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), 'Address: static call to non-contract');

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'SafeMath: addition overflow');

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, 'SafeMath: subtraction overflow');
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'SafeMath: multiplication overflow');

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, 'SafeMath: division by zero');
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, 'SafeMath: modulo by zero');
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    constructor() {
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), 'Ownable: caller is not the owner');
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    using SafeMath for uint256;
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
            'SafeERC20: approve from non-zero to non-zero allowance'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            'SafeERC20: decreased allowance below zero'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data, 'SafeERC20: low-level call failed');
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), 'SafeERC20: ERC20 operation did not succeed');
        }
    }
}

contract Staking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Deposit {
        uint8 plan;
        uint256 amount;
        uint256 start;
        bool withdrawn;
    }

    struct UserInfo {
        Deposit[] deposits;
        uint256 amount;
        uint256 pendingReward;
        uint256 rewardDebt;
    }

    mapping(address => mapping(uint256 => UserInfo)) public userInfo;

    IERC20 Token;
    mapping(uint256 => uint256) public rewardPerSec;
    mapping(uint256 => uint256) public accPerShare;
    mapping(uint256 => uint256) public totalStaked;
    mapping(uint256 => uint256) public lastRewardTime;
    uint256 public lockingTime = 15552000;

    constructor(IERC20 _Token) {
        Token = _Token;
    }

    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    function updateRate(uint256 _pid) internal {
        if (block.timestamp <= lastRewardTime[_pid]) {
            return;
        }
        if (totalStaked[_pid] == 0) {
            lastRewardTime[_pid] = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(lastRewardTime[_pid], block.timestamp);
        accPerShare[_pid] = accPerShare[_pid].add(multiplier.mul(rewardPerSec[_pid]).mul(1e12).div(totalStaked[_pid]));
        lastRewardTime[_pid] = block.timestamp;
    }

    function deposit(uint256 _amount, uint256 _pid) public nonReentrant {
        updateRate(_pid);
        UserInfo storage user = userInfo[msg.sender][_pid];
        if(_pid == 1){
            user.deposits.push(Deposit(1, _amount, block.timestamp, false));
        }
        
        if (user.amount > 0) {
            user.pendingReward = user.pendingReward.add(user.amount.mul(accPerShare[_pid]).div(1e12).sub(user.rewardDebt));
        }
        if (_amount > 0) {
            Token.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(accPerShare[_pid]).div(1e12);
        totalStaked[_pid] = totalStaked[_pid].add(_amount);
    }

    function withdrawAll(uint256 _pid) public nonReentrant {
        updateRate(_pid);
        UserInfo storage user = userInfo[msg.sender][_pid];
        uint256 totalAmount;
        if(_pid == 1)
        {
            for (uint256 i = 0; i < user.deposits.length; i++) {
                uint256 finish = user.deposits[i].start.add(
                    lockingTime
                );
                if (block.timestamp > finish && user.deposits[i].withdrawn == false) {
                    totalAmount = totalAmount.add(user.deposits[i].amount);
                    user.deposits[i].withdrawn = true;
                }
            }
            require(totalAmount > 0, "You need to wait more");
        }else{
            totalAmount = user.amount;
        }
        
        user.pendingReward = user.pendingReward.add(user.amount.mul(accPerShare[_pid]).div(1e12).sub(user.rewardDebt));
        totalAmount = totalAmount.add(user.pendingReward);
        if (totalAmount > 0) {
            user.amount = 0;
            Token.safeTransfer(address(msg.sender), totalAmount);
        }
        user.rewardDebt = user.amount.mul(accPerShare[_pid]).div(1e12);
        user.pendingReward = 0;
        totalStaked[_pid] = totalStaked[_pid].sub(user.amount);
    }

    function claim(uint256 _pid) public nonReentrant{
        updateRate(_pid);
        UserInfo storage user = userInfo[msg.sender][_pid];
        uint256 amount;
        uint256 bal = Token.balanceOf(address(this));
        amount = user.pendingReward.add(user.amount.mul(accPerShare[_pid]).div(1e12).sub(user.rewardDebt));
        if(amount > 0)
        {
            if (amount > bal) {
                amount = bal;
                rewardPerSec[_pid] = 0;
            }
            Token.safeTransfer(address(msg.sender), amount);
        }
        user.rewardDebt = user.amount.mul(accPerShare[_pid]).div(1e12);
        user.pendingReward = 0;
    }

    function updateReward(uint256 _rewardAmount, uint256 _pid) public onlyOwner {
        updateRate(_pid);
        rewardPerSec[_pid] = _rewardAmount;
    }

    function pendingReward(address _user, uint256 _pid) public view returns (uint256) {
        UserInfo storage user = userInfo[_user][_pid];
        uint256 _accPerShare = accPerShare[_pid];
        if (block.timestamp > lastRewardTime[_pid] && totalStaked[_pid] != 0) {
            uint256 multiplier = getMultiplier(lastRewardTime[_pid], block.timestamp);
            _accPerShare = _accPerShare.add(multiplier.mul(rewardPerSec[_pid]).mul(1e12).div(totalStaked[_pid]));
        }
        return user.amount.mul(_accPerShare).div(1e12).sub(user.rewardDebt);
    }

    function lockingEnabled(address _user) public view returns(bool) {
        UserInfo storage user = userInfo[_user][1];
        uint256 totalAmount;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            uint256 finish = user.deposits[i].start.add(
                lockingTime
            );
            if (block.timestamp > finish && user.deposits[i].withdrawn == false) {
                totalAmount = totalAmount.add(user.deposits[i].amount);
            }
        }
        if(totalAmount > 0){
            return true;
        }else{
            return false;
        }
    }

    function totalInfo(address _user, uint256 _pid) external view returns (uint256, uint256, uint256, uint256, bool) {
        return (totalStaked[_pid], rewardPerSec[_pid], userInfo[_user][_pid].amount, pendingReward(_user, _pid), lockingEnabled(_user));
    }

    function stakingInfo(uint256 _pid) external view returns (uint256, uint256) {
        return (totalStaked[_pid], rewardPerSec[_pid]);
    }
}