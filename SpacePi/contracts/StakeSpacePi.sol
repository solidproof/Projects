// Sources flattened with hardhat v2.12.7 https://hardhat.org

// File @openzeppelin/contracts/utils/Context.sol@v4.8.1


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


// File @openzeppelin/contracts/access/Ownable.sol@v4.8.1


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File @openzeppelin/contracts/security/ReentrancyGuard.sol@v4.8.1


// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v4.8.1


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


// File @openzeppelin/contracts/utils/math/SafeMath.sol@v4.8.1


// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}


// File contracts/interfaces/IRelationship.sol


pragma solidity ^0.8.0;
pragma abicoder v2;

interface IRelationship {
    // Invitee is the address of the person being invited
    struct Invitee {
        address invitee;
        uint256 timestamp;
    }

    // User is the address of the person who is inviting
    struct User {
        Invitee[] inviteeList;
        address inviter;
        bytes code;
        mapping(address => uint256) indexes;
    }

    function binding(bytes memory c) external;

    function isInvited(address player) external view returns (bool);

    function getInviteeList(address player) external view returns (Invitee[] memory);

    function getParent(address player) external view returns (address);

    function getInviteCode(address player) external view returns (bytes memory);

    function getPlayerByCode(bytes memory code) external view returns (address);
}


// File contracts/Relationship.sol

pragma solidity ^0.8.0;


/* @title Relationship
 * @author jonescyna@gmail.com
 * @dev This contract is used to manage the invitation relationship.
 *
 * @rules can't invite someone who has already invited you
 * @rules can't invite someone who has already been invited
 * @rules maximum of invitees is limited by gas
*/
contract Relationship is Ownable,IRelationship {

    bytes public defaultCode = "space0";
    uint256 public beginsTime;
    uint256 public endsTime;
    // User is the address of the person who is invited
    mapping(address => User) private _relations;
    // code used to invite
    mapping(bytes => address) private _codeUsed;

    event Binding(address indexed inviter, address indexed invitee, bytes code);

    constructor(uint256 begins, uint256 ends) {
        beginsTime = begins;
        endsTime = ends;
        _relations[msg.sender].code = defaultCode;
        _relations[msg.sender].inviter = msg.sender;
        _codeUsed[defaultCode] = msg.sender;
    }

    modifier inDuration {
        require(block.timestamp < endsTime);
        _;
    }
    function setEnds(uint256 _end) public onlyOwner{
        endsTime = _end;
    }
    function setStart(uint256 _start) public onlyOwner{
        beginsTime = _start;
    }
    // @param inviter address of the person who is inviting
    function binding(bytes memory c) public override inDuration {
        address sender = msg.sender;
        address inviter = _codeUsed[c];
        require(inviter != address(0), "code not found");
        require(inviter != sender, "Not allow inviter by self");
        // invitee address info
        User storage self = _relations[sender];
        // inviter address info
        User storage parent = _relations[inviter];

        require(parent.indexes[sender] == 0, "Can not accept child invitation");
        require(self.inviter == address(0), "Already bond invite");
        parent.inviteeList.push(Invitee(sender, block.timestamp));
        parent.indexes[sender] = self.inviteeList.length;

        self.inviter = inviter;
        bytes memory code = _genCode(sender);
        require(_codeUsed[code] == address(0), "please try again");
        self.code = code;

        _codeUsed[code] = sender;
        emit Binding(inviter, sender, code);
    }

    // @param player address if not invited
    function isInvited(address player) public view override returns (bool){
        if (_relations[player].inviter != address(0)) return true;
        return false;
    }

    // @param get player address invitee list
    function getInviteeList(address player) public view override returns (Invitee[] memory){
        return _relations[player].inviteeList;
    }

    // @param get player address inviter
    function getParent(address player) public view override returns (address){
        return _relations[player].inviter;
    }

    // @param get player address invitation code
    function getInviteCode(address player) public view override returns (bytes memory){
        return _relations[player].code;
    }

    // @param get player address by invitation code
    function getPlayerByCode(bytes memory code) public view override returns (address){
        return _codeUsed[code];
    }

    function _genCode(address player) private view  returns (bytes memory){
        bytes32 hash = keccak256(abi.encode(player, block.number));
        bytes memory code = new bytes(6);
        for (uint256 i = 0; i < code.length; i++) {
            code[i] = hash[i];
        }
        return code;
    }
}


// File contracts/FixedDeposit.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;




contract FixedDeposit is ReentrancyGuard, Relationship {
    using SafeMath for uint256;
    struct Pool {
        uint256 apr; // pool apr
        uint256 lockBlocks; // pool lock blocks
        uint256 amount; // pool stake amount
    }

    struct UserInfo {
        uint256 amount; // user deposit amount
        uint256 accReward; // user accumulate reward
        uint256 rewardDebt; // user reward debt
        uint256 enterBlock; // user enter block
        uint256 settledBlock; // user settled block
        bool claimed;
    }

    Pool[] public pools;
    IERC20 public token; // using token
    uint256 public accDeposit; // accumulate all deposit
    uint256 public accReward; // accumulate all reward

    uint256 perBlockTime = 3 seconds; // per block gen time
    uint256 public inviteRewardRate = 10; // invite reward rate

    mapping(address => mapping(uint256 => UserInfo)) public userInfo; // user info

    mapping(address => uint256) public inviteReward; // invite reward amount

    event Deposit(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event InviterReward(address indexed user, uint256 indexed pid, uint256 indexed amount);
    event Reward(address indexed user, uint256 indexed pid, uint256 indexed amount);
//    event Reinvestment(address indexed user, uint256 indexed pid, uint256 indexed amount);

    constructor(IERC20 _token, uint256 start,uint256 end)Relationship(start,end){
//    constructor () Relationship(1678159400,1678764200){
//        token = IERC20(0x97b3d934F051F506a71e56C0233EA344FCdc54d2);
        token = _token;
        // only for test
//        addPool(40, 60 seconds / perBlockTime);
//        addPool(80, 600 seconds / perBlockTime);
        // production
        addPool(7, 30 days);
        addPool(12, 90 days);
        addPool(15, 180 days);
    }
    modifier onlyUnLock(uint256 pid, address play){
        Pool memory pool = pools[pid];
        UserInfo memory user = userInfo[play][pid];
        require(block.number >= pool.lockBlocks.add(user.enterBlock), "onlyUnLock: locked");
        _;
    }

    modifier onlyInvited(address play){
        require(getParent(play) != address(0), "onlyInvited:only invited");
        _;
    }
    function addPool (uint256 apr,uint256 locked) public onlyOwner{
        pools.push(Pool(apr, locked/ perBlockTime, 0));
    }
    function poolLength() external view returns (uint256) {
        return pools.length;
    }
    function setPoolApr(uint256 pid, uint256 apr) public onlyOwner{
        pools[pid].apr = apr;
    }
    function setPoolLocked(uint256 pid, uint256 locked) public onlyOwner{
        pools[pid].lockBlocks = locked / perBlockTime;
    }
    function setPool(uint256 pid, uint256 apr, uint256 locked) public onlyOwner{
        pools[pid].apr = apr;
        pools[pid].lockBlocks = locked;
    }
    // @dev get user pending reward
    function pending(uint256 pid, address play) public view returns (uint256){
        uint256 time = block.number;
        Pool memory pool = pools[pid];
        UserInfo memory user = userInfo[play][pid];
        if (user.amount == 0) return 0;
        uint256 perBlock = user.amount.mul(pool.apr).div(365 days).div(100).mul(perBlockTime);
        if (time >= pool.lockBlocks.add(user.enterBlock)) {
            if (user.settledBlock >= pool.lockBlocks) return 0;
            return perBlock.mul(pool.lockBlocks.sub(user.settledBlock)).add(user.rewardDebt);
        }
        return perBlock.mul(time.sub(user.enterBlock).sub(user.settledBlock)).add(user.rewardDebt);
    }

    // @dev deposit token can repeat, will settle the previous deposit
    // @dev only invited can deposit
    function deposit(uint256 pid, uint256 amount) external nonReentrant onlyInvited(msg.sender) inDuration {
        Pool storage pool = pools[pid];
        UserInfo storage user = userInfo[msg.sender][pid];
        token.transferFrom(msg.sender, address(this), amount);
        uint256 reward = pending(pid, msg.sender);
        uint256 currentBlock = block.number;
        if (user.enterBlock == 0) {
            user.enterBlock = block.number;
        }
        if (currentBlock > user.enterBlock.add(pool.lockBlocks)) {
            if (reward > 0) revert("deposit: reward claim first");
            user.enterBlock = block.number;
        }

        if (user.amount > 0) {
            if (reward > 0) {
                user.rewardDebt = user.rewardDebt.add(reward);
                user.settledBlock = block.number.sub(user.enterBlock);
            }
        }
        pool.amount = pool.amount.add(amount);
        user.amount = user.amount.add(amount);
        accDeposit = accDeposit.add(amount);
        emit Deposit(msg.sender, pid, amount);
    }
    // @dev withdraw deposit token whether unlock
    function withdraw(uint256 pid) external nonReentrant onlyUnLock(pid, msg.sender) {
        UserInfo storage user = userInfo[msg.sender][pid];
        Pool storage pool = pools[pid];
        uint256 amount = user.amount;
        require(user.amount >= 0, "withdraw: Principal is zero");
        user.amount = 0;
        user.enterBlock = 0;
        user.settledBlock = 0;
        user.claimed = false;
        accDeposit = accDeposit.sub(amount);
        pool.amount = pool.amount.sub(amount);
        token.transfer(msg.sender, amount);
        emit Withdraw(msg.sender, pid, amount);
    }

    // @dev claim interest, not locking withdraw
    // @dev inviter will get setting percent of the interest
    function claim(uint256 pid) external nonReentrant{
        UserInfo storage user = userInfo[msg.sender][pid];
        Pool memory pool = pools[pid];
        uint256 reward = pending(pid, msg.sender);
        require(reward > 0, "claim: interest is zero");
        require(!user.claimed, "claim: time ends claimed");
        if (token.balanceOf(address(this)).sub(accDeposit) >= reward&&!user.claimed) {
            address inviter = getParent(msg.sender);

            uint256 userInviteReward = reward.mul(inviteRewardRate).div(100);
            uint256 userReward = reward.sub(userInviteReward);
            token.transfer(inviter, userInviteReward);
            token.transfer(msg.sender, userReward);
            if (user.enterBlock.add(pool.lockBlocks) < block.number) user.claimed = true;
            user.accReward = user.accReward.add(userReward);
            user.settledBlock = block.number.sub(user.enterBlock);
            user.rewardDebt = 0;
            accReward = accReward.add(reward);
            inviteReward[inviter] = inviteReward[inviter].add(userInviteReward);
            emit InviterReward(inviter, pid, userInviteReward);
            emit Reward(msg.sender, pid, userReward);
        }
    }

}
