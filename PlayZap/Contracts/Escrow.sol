// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Escrow is Ownable{

    uint256 public _totalGameFees;

    mapping (address => uint256) public _balances;
    mapping (address => bool) public _tokenExpired;
    mapping (address => bool) public blacklist;
    mapping (address => bool) public lock;

    event SetBlacklist(address user,bool isBlacklist);
    event TokenReceived(address _from, uint256 _amount);
    event PrizeCollected(address _from, uint256 _amount);

    IERC20 private token;

    constructor(){
        //token contract SC address
         token = IERC20(0x91bdff829265f5BdbCF1946329FAF43e9F418e6C);
    }

    //owner can set new address as owner
    function setOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    //Buy tickets by paying in PZP tokens
    function PurchaseTickets(uint256 tokens_) external {

        require (!lock[msg.sender]);
        lock[msg.sender] = true;

        require(tokens_>=1  ,"Price cannot be less than 1");
        require(token.balanceOf(msg.sender) >= tokens_* 10 ** 18 , "Not Enough PlayZap Tokens In Wallet") ;
        require (!blacklist[msg.sender],"Address is black listed");

        token.transferFrom(msg.sender,address(this), tokens_ * 10 ** 18);


        lock[msg.sender] = false;
        emit TokenReceived(msg.sender,tokens_);
    }


    //Player can collect the winning tokens from this
    function CollectPrize() public {
        require (!lock[msg.sender]);
        lock[msg.sender] = true;

        require(_balances[msg.sender] > 0,"No Token Left To Collect");

        token.transfer(msg.sender,_balances[msg.sender]);
        _balances[msg.sender] = 0;

        lock[msg.sender] = false;
        emit PrizeCollected(msg.sender,_balances[msg.sender]);
    }

    //PlayZap prize distribution
    function PrizeTokenDistribution(IERC20 _token, address[] memory _addresses, uint256[] memory prizes,uint256 fees,address treasure) external onlyOwner{
        uint length = _addresses.length;
        require (length != 0,"Address array can't be empty");

        for(uint256 i=0; i<length; ++i)
        {
            require (!blacklist[_addresses[i]],"Address is black listed") ;
           _balances[_addresses[i]] += prizes[i] * 10 ** 18;
        }
        //add all playzap fees in another SC/Wallet
         _token.transfer(treasure,fees);

    }

    //blacklist addresses
    function setBlacklist(address _user,bool _isBlacklist) public onlyOwner{
        blacklist[_user] = _isBlacklist;
        emit SetBlacklist(_user,_isBlacklist);
    }

}