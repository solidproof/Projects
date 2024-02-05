// File: @openzeppelin/contracts/security/ReentrancyGuard.sol
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

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/access/Ownable.sol


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

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: Lottery-token.sol

// SPDX-// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;




contract LotteryContract is Ownable, ReentrancyGuard{

    IERC20 private _token; 
    IERC20 private _busd;
    address[] public players;
    address[] public  winner;  // for testing purpose checking the winner address getting the busd
    uint256[] public rewardAmount;


    uint256 public ticketPriceInToken;
    uint256 public currentLotteryId;
    uint256 public ticketLimit;
    address private deadAddress= 0x000000000000000000000000000000000000dEaD;
    


    enum Status {
        Open,
        Closed
    }
    
    struct Lottery {
        uint256 lotteryId;
        Status status;
        uint256 startTime;
        uint256 endTime;
    }
  
    mapping(uint256=>Lottery) public _lottery; 
    
    constructor(IERC20 _tokenContract, IERC20 _busdToken,uint256 _lotteryEndTime){
        _token=_tokenContract;
        _busd= _busdToken;
        ticketPriceInToken= 5*10**18;    // 1 ticket == 5 _token
        ticketLimit= 20;
        startLottery(_lotteryEndTime);
    }
    // onlyOwner
    // This function is used to start the lottery.
    function startLottery(uint256 _loteryEndTime) public onlyOwner returns(bool){
        currentLotteryId++;
        Lottery storage s = _lottery[currentLotteryId];
        s.lotteryId=currentLotteryId;
        s.status=Status.Open;
        s.startTime= block.timestamp;
        s.endTime= _loteryEndTime;
        return true;
    }

    function drawLottery(uint256 _lotteryId,uint256 _loteryEndTime) external onlyOwner returns(bool){
        Lottery storage s = _lottery[_lotteryId];
        require(s.status==Status.Open,"Already closed");
        s.status=Status.Closed;
        winner = new address[](0);
        rewardAmount = new uint256[](0);
        rewardDistributation();
        startLottery(_loteryEndTime);
        return true;
    }
   
    function ran() internal view returns (uint256[] memory expandedValues) {
        expandedValues = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            expandedValues[i] = (uint256(keccak256(abi.encode(players.length,block.timestamp, i))))%players.length;
        }
        return expandedValues;
    }

    function rewardDistributation() internal {
        uint256 contractBusdBal= _busd.balanceOf(address(this));
        uint256 prizeAmount= (contractBusdBal*40)/100;
        require(_busd.balanceOf(address(this))>prizeAmount,"less busd");
        uint256[] memory ranIndex= ran();

        address firAdd= players[ranIndex[0]];
        winner.push(firAdd);
        rewardAmount.push((prizeAmount*50)/100);
        _busd.transfer(firAdd, (prizeAmount*50)/100);

        address secAdd= players[ranIndex[1]];
        winner.push(secAdd);
        rewardAmount.push((prizeAmount*30)/100);
        _busd.transfer(secAdd, (prizeAmount*30)/100);

        address thicAdd= players[ranIndex[2]];
        winner.push(thicAdd);
        rewardAmount.push((prizeAmount*10)/100);
        _busd.transfer(thicAdd, (prizeAmount*10)/100);
        
        address fourAdd= players[ranIndex[3]];
        winner.push(fourAdd);
        rewardAmount.push((prizeAmount*5)/100);
        _busd.transfer(fourAdd, (prizeAmount*5)/100);

        address fifthAdd= players[ranIndex[4]];
        winner.push(fifthAdd);
        rewardAmount.push((prizeAmount*3)/100);
         _busd.transfer(fifthAdd, (prizeAmount*3)/100);

        address sixthAdd= players[ranIndex[5]];
        winner.push(sixthAdd);
        rewardAmount.push((prizeAmount*2)/100);
        _busd.transfer(sixthAdd, (prizeAmount*2)/100);
         
         players = new address[](0);



    }

    function updateTicketPriceInToken(uint256 _price) external onlyOwner returns(bool){
        require(_price >= 1, 'Ticket Price should be minimum of 1');
        ticketPriceInToken=_price;
        return true;
    }
    
    // public 
    function buyTicket(uint256 _numberOfTicket) external nonReentrant  returns(bool){
        require(_numberOfTicket <=ticketLimit, "ticket limit is less");
        uint256 amount= estimatePrice(_numberOfTicket);

        require(_token.balanceOf(msg.sender)>=amount,"less bal.");
        Lottery storage s = _lottery[currentLotteryId];
        require(s.status == Status.Open,"Lottery closed.");
        for (uint256 i=0; i < _numberOfTicket; i++) 
        {
            players.push(msg.sender);
        }
        
        _token.transferFrom(msg.sender,deadAddress, amount);
        return true;
    }

    function getPlayersLength() external view  returns(uint256){
        return players.length;
    }

    function getBusdFromContract(uint256 _amount) external onlyOwner{
        _busd.transfer(owner(),_amount);

    }
    function updateTicketLimit(uint256 _newLimit) external onlyOwner returns(bool){
        ticketLimit= _newLimit;
        return true;
    }

    function estimatePrice(uint256 _ticket) public view returns(uint256){
        return ticketPriceInToken*_ticket;
    }

}