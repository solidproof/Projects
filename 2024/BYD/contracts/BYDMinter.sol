/**
 *Submitted for verification at Arbiscan.io on 2024-10-12
*/

/**
 *Submitted for verification at arbiscan.io on 2024-10-04
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
/*Math operations with safety checks */
contract SafeMath {
    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return a/b;
    }
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c>=a && c>=b);
        return c;
    }
    function safePower(uint a, uint b) internal pure returns (uint256) {
        uint256 c = a**b;
        return c;
    }
}

interface IToken {
    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address _to, uint256 _value) external;
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
    /**
     * @dev mint the token, `amount` is the new mint quantities.
     */
    function mint(address _to, uint256 _amount) external;
}

contract BYDMinter is SafeMath{
    uint8 constant DECIMAL_PLACES = 6;
    /**
     * @dev When there are more than 1,700,000,000,000 coins in the staking contract（PLEDGE_ADD）, the community can mint new coins
     */
    uint256 constant PLEDGE_START = 1700000000000 * (10 ** DECIMAL_PLACES);
    /**
     * @dev The base quantities of the 'BYD',
     */
    uint256 constant PREMINT_BALANCE = 2000000000000 * (10 ** DECIMAL_PLACES);

    /**
     * @dev the contract address of 'BYD'
     */
    address public BYD_ADD = 0x65FA064E808B33462A214DeE8b8B715C3424FDDA;

    /**
     * @dev the contract Staking address of 'BYD'
     */
    address public PLEDGE_ADD = 0xF794875aa1f9B0DdC5B922c94F9Af64b1a7Bb9A4;

    address payable public owner;
    address payable public ownerTemp;
    uint256 blocknumberLastAcceptOwner;


    /**
     * @dev Emitted when the BYD is staked in the pledge_add is set by
     * a call to {approve}. `amount` is the new mint quantities.
     */
    event AutoMint(address indexed to, uint256 amount);
    event SetOwner(address user);
    event AcceptOwner(address user);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        owner = payable(msg.sender);
    }

    function autoMint() public returns (bool success){
        //Obtain the current total number of BYDs
        uint256 total_supply = IToken(BYD_ADD).totalSupply();
        //Obtain the current staking number of BYDs
        uint256 pledge_balance = IToken(BYD_ADD).balanceOf(PLEDGE_ADD);

        require (pledge_balance >  PLEDGE_START && (pledge_balance - PLEDGE_START)*2 > total_supply - PREMINT_BALANCE);

        //If the staked amount exceeds 1.7 trillion, each staker, staking one coin, gets two more coins.
        //minus the coins that have been newly minted due to the pledge
        uint256 mintAmount = (pledge_balance - PLEDGE_START)*2 - (total_supply - PREMINT_BALANCE);
        IToken(BYD_ADD).mint(owner,mintAmount);

        emit AutoMint(owner,  mintAmount);                   // Notify anyone listening that this mint took place
        return true;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`_add`).
     */
    function setOwner(address payable _add) public{
        require (msg.sender == owner && _add != address(0x0)) ;
        ownerTemp = _add ;
        blocknumberLastAcceptOwner = block.number + 201600;
        emit SetOwner(_add);
    }

    /**
     * @dev The new owner must accept, and get the ownership .
     */
    function acceptOwner()public{
        require (msg.sender == ownerTemp && block.number < blocknumberLastAcceptOwner && block.number > blocknumberLastAcceptOwner - 172800) ;
        owner = ownerTemp ;
        emit AcceptOwner(owner);
    }

    /**
    * @dev Leaves the contract without owner. It will not be possible to call
    * `onlyOwner` functions anymore. Can only be called by the current owner.
    *
    * NOTE: Renouncing ownership will leave the contract without an owner,
    * thereby removing any functionality that is only available to the owner.
    */
    function renounceOwnership() public {
        require (msg.sender == owner);
        emit OwnershipTransferred(owner, address(0));
        owner = payable(address(0));
    }

    // transfer balance to owner
    function withdrawToken(address token, uint amount) public{
        require(msg.sender == owner);
        if (token == address(0x0))
            owner.transfer(amount);
        else
            IToken(token).transfer(owner, amount);
    }

    receive() external payable {}/* can accept ether */
}