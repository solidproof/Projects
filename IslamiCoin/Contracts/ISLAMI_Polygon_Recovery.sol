// SPDX-License-Identifier: MIT

/*
@dev: This code is developed by Jaafar Krayem and is free to be used by anyone
Use under your own responsibility!
*/

/*
@dev: Lock your tokens in a safe place use recovery wallet option
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity = 0.8.15;

contract ISLAMIservicePolygon {
    using SafeMath for uint256;

    address public feeReceiver;
    ERC20 public ISLAMI;

/*
@dev: Private values
*/  
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    uint256 private currencyID;

/*
@dev: public values
*/
    uint256 public investorVaultCount;
    uint256 public constant ewFee = 1; //1% of locked amount

/*
@dev: Events
*/
    event InvestorAdded(address Investor, uint256 Amount);
    event tokenAdded(ERC20 Token, string Symbol);
    event tokenClaimed(address Token, address Receiver, uint256 Amount);
    event SelfLockInvestor(address Investor,uint256 vaultID, ERC20 Token, uint256 Amount);
    event EditSelfLock(address Investor, ERC20 Token, uint256 Amount);
    event ExtendSelfLock(address Investor, ERC20 Token, uint256 Time);
    event EmergencyWithdraw(address Investor, address NewWallet, uint256 Amount);
/*
@dev: Investor Vault
*/   
    struct VaultInvestor{
        uint256 vaultID;
        ERC20 tokenAddress;
        uint256 amount;
        address recoveryWallet;
        uint256 lockTime;
        uint256 timeStart;
    }
/*
@dev: Currency Vault
*/   
    struct cryptocurrency{
        uint256 currencyID;
        ERC20 tokenAddress;
        string symbol;
        uint256 fractions;
        uint256 currencyVault;
    }

/*
 @dev: Mappings
*/
    mapping(address => bool) public Investor;
    
    mapping(address => mapping (uint256 => VaultInvestor)) public investor;

    mapping(address => bool) public blackList;

    mapping(ERC20 => cryptocurrency) public crypto;
    mapping(ERC20 => bool) public isCrypto; 


/* @dev: Check if feReceiver */
    modifier onlyISLAMI (){
        require(msg.sender == feeReceiver, "Only ISLAMICOIN owner can add Coins");
        _;
    }
/*
    @dev: check if user is investor
*/
    modifier isInvestor(address _investor){
        require(Investor[_investor] == true, "Not an Investor!");
        _;
    }
/*
    @dev: prevent reentrancy when function is executed
*/
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    constructor(address _feeReceiver, ERC20 _ISLAMI) {
        ISLAMI = _ISLAMI;
        feeReceiver = _feeReceiver;
        investorVaultCount = 0;
        currencyID = 0;
        _status = _NOT_ENTERED;
    }
    function addCrypto(address _token, string memory _symbol, uint256 _fractions) external{
        require(msg.sender == feeReceiver,"only feeReceiver can add coins");
        currencyID++;
        ERC20 token = ERC20(_token);
        crypto[token].currencyID = currencyID;
        crypto[token].tokenAddress = token;
        crypto[token].symbol = _symbol;
        crypto[token].fractions = _fractions;
        isCrypto[token] = true;
        emit tokenAdded(token, _symbol);
    }
/*
    @dev: require approval on spen allowance from token contract
    this function for investors who want to lock their tokens
    usage: 
           1- if usrr want to use recovery wallet service
           2- if user want to vote on projects!
*/
    function selfLock(address _token, uint256 _amount, uint256 _lockTime, address _recoveryWallet) external nonReentrant{
        ERC20 token = ERC20(_token);
        require(isCrypto[token] == true,"Not listed");
        uint256 _vaultID = crypto[token].currencyID;
        require(_vaultID != 0 && _vaultID != investor[msg.sender][_vaultID].vaultID, "can't!");
        require(_recoveryWallet != address(0), "Burn!");
        //require(Investor[msg.sender] != true,"Double locking!");
        uint256 amount = _amount;
        uint256 lockTime = _lockTime.mul(1);//(1 days);
        require(token.balanceOf(msg.sender) >= amount,"Need token!");
        token.transferFrom(msg.sender, address(this), amount);
        emit SelfLockInvestor(msg.sender, _vaultID, token, amount);
        investor[msg.sender][_vaultID].vaultID = _vaultID;
        investor[msg.sender][_vaultID].tokenAddress = token;
        investor[msg.sender][_vaultID].amount = amount; 
        investor[msg.sender][_vaultID].timeStart = block.timestamp;
        investor[msg.sender][_vaultID].lockTime = lockTime.add(block.timestamp);
        investor[msg.sender][_vaultID].recoveryWallet = _recoveryWallet;
        Investor[msg.sender] = true;
        crypto[token].currencyVault += amount;
        investorVaultCount++;
    }
/*
    @dev: require approval on spend allowance from token contract
    this function is to edit the amount locked by user
    usage: if user want to raise his voting power
*/
    function editSelfLock(uint256 _vaultID, uint256 _amount) external isInvestor(msg.sender) nonReentrant{
        uint256 amount = _amount;
        ERC20 token = investor[msg.sender][_vaultID].tokenAddress;
        require(token.balanceOf(msg.sender) >= amount,"ERC20 balance!");
        token.transferFrom(msg.sender, address(this), amount);
        investor[msg.sender][_vaultID].amount += amount;
        crypto[token].currencyVault += amount;
        emit EditSelfLock(msg.sender, token, amount);
    }
/*
    @dev: Extend the period of locking, used if user wants
    to vote and the period is less than 30 days
*/
    function extendSelfLock(uint256 _vaultID, uint256 _lockTime) external isInvestor(msg.sender) nonReentrant{
        uint256 lockTime = _lockTime.mul(1 days);
        ERC20 token = investor[msg.sender][_vaultID].tokenAddress;
        investor[msg.sender][_vaultID].lockTime += lockTime;
        emit ExtendSelfLock(msg.sender, token, lockTime);
    }
/*
    @dev: Investor lost his phone or wallet, or passed away!
    only the wallet registered as recovery can claim tokens after lock is done
*/
    function recoverWallet(uint256 _vaultID, address _investor) external isInvestor(_investor) nonReentrant{
        require(msg.sender == investor[_investor][_vaultID].recoveryWallet &&
        investor[_investor][_vaultID].lockTime < block.timestamp,
        "Not allowed");
        useRecovery(_vaultID, _investor);
    }
/*
    @dev: Unlock locked tokens for user
    only the original sender can call this function
*/
    function selfUnlock(uint256 _vaultID, uint256 _amount) external isInvestor(msg.sender) nonReentrant{
        require(investor[msg.sender][_vaultID].lockTime <= block.timestamp, "Not yet");
        uint256 amount = _amount;
        ERC20 token = investor[msg.sender][_vaultID].tokenAddress;
        require(investor[msg.sender][_vaultID].amount >= amount, "Amount!");
        investor[msg.sender][_vaultID].amount -= amount;
        crypto[token].currencyVault -= amount;
        if(investor[msg.sender][_vaultID].amount == 0){
            delete investor[msg.sender][_vaultID];
            investorVaultCount--;
        }
        emit tokenClaimed(msg.sender, address(token), amount);
        token.transfer(msg.sender, amount);
    }
/*
    @dev: If self lock investor wallet was hacked!
    Warning: this will blacklist the message sender!
*/
    function emergencyWithdrawal(uint256 _vaultID) external isInvestor(msg.sender) nonReentrant{
        useRecovery(_vaultID, msg.sender);
    }
/*
    @dev: Recover Wallet Service, also used by emergencyWithdrawal!
    * Check if statment
    if user didn't add a recovery wallet when locking his tokens
    the recovery wallet is set this contract and tokens are safe 
    and released to the contract itself.
    This contract does not have a function to release the tokens
    in case of emerergency it is only done by the user.
    if(newWallet == address(this))
    Release tokens to smart contract, investor should contact project owner on Telegram @jeffrykr
*/
    function useRecovery(uint256 _vaultID, address _investor) internal {
        require(_vaultID !=0 && investor[_investor][_vaultID].amount > 0, "error");
        ERC20 token = investor[_investor][_vaultID].tokenAddress;
        uint256 feeToPay = investor[_investor][_vaultID].amount.mul(ewFee).div(100);
        address newWallet = investor[_investor][_vaultID].recoveryWallet;
        uint256 fullBalance = investor[_investor][_vaultID].amount.sub(feeToPay);
        crypto[token].currencyVault -= investor[_investor][_vaultID].amount;
        delete investor[_investor][_vaultID];
        emit EmergencyWithdraw(_investor, newWallet, fullBalance);
        if(newWallet == address(this)){  
            return();
        }
        token.transfer(feeReceiver, feeToPay);
        token.transfer(newWallet, fullBalance);
    }


/*
   @dev: people who send Matic by mistake to the contract can withdraw them
*/
    mapping(address => uint) public balanceReceived;

    function receiveMoney() public payable {
        assert(balanceReceived[msg.sender] + msg.value >= balanceReceived[msg.sender]);
        balanceReceived[msg.sender] += msg.value;
    }

    function withdrawMoney(address payable _to, uint256 _amount) public {
        require(_amount <= balanceReceived[msg.sender], "not enough funds.");
        assert(balanceReceived[msg.sender] >= balanceReceived[msg.sender] - _amount);
        balanceReceived[msg.sender] -= _amount;
        _to.transfer(_amount);
    } 

    receive() external payable {
        receiveMoney();
    }
}


               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2022
               **********************************************************/