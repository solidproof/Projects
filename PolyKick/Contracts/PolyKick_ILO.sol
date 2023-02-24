// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PolyKick_ILO{
using SafeMath for uint256;

    address public factory;
    address public constant burn = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public tokenAmount;
    IERC20 public currency;
    uint8 public currencyDecimals;
    uint256 public price;
    uint256 public discount;
    uint256 public target;
    uint256 public duration;
    uint256 public maxAmount;
    uint256 public minAmount;
    uint256 public maxC;
    uint256 public minC;
    uint256 public salesCount;
    uint256 public buyersCount;

    address public seller;
    address public polyWallet;
    address public polyKickDAO;

    uint256 public sellerVault;
    uint256 public soldAmounts;
    uint256 public notSold;

    uint256 private pkPercentage;
    uint256 private toPolykick;
    uint256 private toExchange;
    
    bool public success = false;
    bool public fundsReturn = false;
    bool public isDiscount = false;

    struct buyerVault{
        uint256 tokenAmount;
        uint256 currencyPaid;
    }

    mapping(address => bool) public isWhitelisted;
    mapping(address => buyerVault) public buyer;
    mapping(address => bool) public isBuyer;
    mapping(address => bool) public isAdmin;

    event approveILO(string Result);
    event tokenSale(uint256 CurrencyAmount, uint256 TokenAmount);
    event tokenWithdraw(address Buyer, uint256 Amount);
    event CurrencyReturned(address Buyer, uint256 Amount);
    event discountSet(uint256 Discount, bool Status);
    event whiteList(address Buyer, bool Status);

/* @dev: Check if Admin */
    modifier onlyAdmin (){
        require(isAdmin[msg.sender] == true, "Not Admin!");
        _;
    }
/* @dev: Check if contract owner */
    modifier onlyOwner (){
        require(msg.sender == polyWallet, "Not Owner!");
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
    constructor(
           address _seller,
           address _polyKick,
           IERC20 _token,
           uint8 _tokenDecimals,
           uint256 _tokenAmount,
           IERC20 _currency,
           uint256 _price,
           uint256 _target, 
           uint256 _duration,
           uint256 _pkPercentage,
           uint256 _toPolykick,
           uint256 _toExchange
           ){
        factory = msg.sender;
        seller = _seller;
        polyWallet = _polyKick;
        polyKickDAO = _polyKick;
        token = _token;
        tokenDecimals = _tokenDecimals;
        tokenAmount = _tokenAmount;
        currency = _currency;
        price = _price;
        target = _target;
        duration = _duration;
        pkPercentage = _pkPercentage;
        toPolykick = _toPolykick;
        toExchange = _toExchange;
        minBuyMax(100, 10000, _price, 6); //minAmount = tokenAmount.mul(1).div(1000);
        maxAmount = tokenAmount.mul(1).div(100);
        _status = _NOT_ENTERED;
        notSold = _tokenAmount;
        discount = price.mul(80).div(100); //20% discount price
        isAdmin[polyWallet] = true;
    }
    function addAdmin(address _newAdmin) external onlyOwner{
        require(_newAdmin != address(0), "Address zero!");
        isAdmin[_newAdmin] = true;
    }
    function removeAdmin (address _admin) external onlyOwner{
        isAdmin[_admin] = false;
    }
    function setPolyDAO(address _DAO) external onlyOwner{
        require(_DAO != address(0), "Address 0");
        polyKickDAO = _DAO;
    }
    function minBuyMax(uint256 minAmt, uint256 maxAmt, uint256 _price, uint8 _dcml) internal{
        uint256 min = minAmt * 10 ** _dcml;
        uint256 max = maxAmt * 10 ** _dcml;
        minAmount = (min.div(_price)) * 10 ** tokenDecimals;
        maxAmount = (max.div(_price)) * 10 ** tokenDecimals;
        minC = minAmt;
        maxC = maxAmt;
    }
    function setCurrencyDecimals(uint8 _dcml) external onlyOwner{
        require(_dcml != 0, "Zero not allowed");
        currencyDecimals = _dcml;
    }
    function iloInfo() public view 
             returns
                (
                  uint256 tokensSold,
                   uint256 tokensRemaining,
                    uint256 Price,
                     uint256 Sales,
                      uint256 Buyers,
                       uint256 USDcollected
                      )
                      {
                          return(soldAmounts, notSold, price, salesCount, buyersCount, sellerVault);
    }
    function setDiscount(uint256 _discount, bool _isDiscount) external onlyOwner{
        require(_discount < 99 && _discount > 0, "discount error");
        uint256 dis = 100 - _discount;
        discount = price.mul(dis).div(100);
        isDiscount = _isDiscount;
        emit discountSet(discount, _isDiscount);
    }
    function addToWhiteListBulk(address[] memory _allowed) external onlyAdmin{
        for(uint i=0; i<_allowed.length; i++){
            require(_allowed[i] != address(0x0), "Zero aadress!");
            isWhitelisted[_allowed[i]] = true;
        }
    }
    function addToWhiteList(address _allowed) external onlyAdmin{
        require(_allowed != address(0x0), "Zero aadress!");
        isWhitelisted[_allowed] = true;
        emit whiteList(_allowed, isWhitelisted[_allowed]);
    }
    function extendILO(uint256 _duration) external onlyAdmin{
        fundsReturn = true;
        duration = _duration.add(block.timestamp);
    }
    function buyTokens(uint256 _amountToPay) external nonReentrant{
        require(isWhitelisted[msg.sender] == true, "You need to be whitelisted for this ILO");
        require(block.timestamp < duration,"ILO Ended!");
        uint256 amount = _amountToPay * 10 ** tokenDecimals;
        uint256 finalAmount;
        if(isDiscount == true){
            finalAmount = amount.div(discount); //pricePerToken;
        }
        else{
            finalAmount = amount.div(price); //pricePerToken;
        }
        require(buyer[msg.sender].tokenAmount.add(finalAmount) <= maxAmount,"Limit reached");
        require(finalAmount >= minAmount, "Amount is under minimum allocation");
        require(finalAmount <= maxAmount, "Amount is over maximum allocation");
        emit tokenSale(_amountToPay, finalAmount);
        //The transfer requires approval from currency smart contract
        currency.transferFrom(msg.sender, address(this), _amountToPay);
        sellerVault += _amountToPay;
        buyer[msg.sender].tokenAmount += finalAmount;
        buyer[msg.sender].currencyPaid += _amountToPay;
        soldAmounts += finalAmount;
        notSold -= finalAmount;
        if(isBuyer[msg.sender] != true){
            isBuyer[msg.sender] = true;
            buyersCount++;
        }
        salesCount++;
    }
    function iloApproval() external onlyAdmin{
        require(block.timestamp > duration, "ILO has not ended yet!");
        if(soldAmounts >= target){
            success = true;
            token.transfer(burn, notSold);
            emit approveILO("ILO Succeed");
        }
        else{
            success = false;
            fundsReturn = true;
            sellerVault = 0;
            emit approveILO("ILO Failed");
        }
    }
    function setMinMax(uint256 _minAmount, uint256 _maxAmount) external onlyAdmin{
        require(currencyDecimals != 0, "please set decimals for currency");
        minBuyMax(_minAmount, _maxAmount, price, currencyDecimals);
    }
    function withdrawTokens() external nonReentrant{
        require(block.timestamp > duration, "ILO has not ended yet!");
        require(isBuyer[msg.sender] == true,"Not a Buyer");
        require(success == true, "ILO Failed");
        uint256 buyerAmount = buyer[msg.sender].tokenAmount;
        emit tokenWithdraw(msg.sender, buyerAmount);
        token.transfer(msg.sender, buyerAmount);
        soldAmounts -= buyerAmount;
        buyer[msg.sender].tokenAmount -= buyerAmount;
        isBuyer[msg.sender] = false;
    }
    function returnFunds() external nonReentrant{
        //require(block.timestamp > duration, "ILO has not ended yet!");
        require(isBuyer[msg.sender] == true,"Not a Buyer");
        require(success == false && fundsReturn == true, "ILO Succeed try withdrawTokens");
        uint256 buyerAmount = buyer[msg.sender].currencyPaid;
        emit CurrencyReturned(msg.sender, buyerAmount);
        currency.transfer(msg.sender, buyerAmount);
        buyer[msg.sender].currencyPaid -= buyerAmount;
        isBuyer[msg.sender] = false;
    }
    function sellerWithdraw() external nonReentrant{
        require(msg.sender == seller,"Not official seller");
        require(block.timestamp > duration, "ILO has not ended yet!");
        if(success == true){
            uint256 polyKickAmount = sellerVault.mul(pkPercentage).div(100);
            uint256 totalPolykick = polyKickAmount.add(toPolykick);
            uint256 sellerAmount = sellerVault.sub(totalPolykick).sub(toExchange);
            if(toExchange > 0){
                currency.transfer(polyWallet, toExchange);
            }
            currency.transfer(polyKickDAO, totalPolykick);
            currency.transfer(seller, sellerAmount);
        }
        else if(success == false){
            token.transfer(seller, token.balanceOf(address(this)));
        }
    }

    function emergencyRefund(uint256 _confirm) external onlyAdmin{
        require(success != true, "ILO is successful");
        require(duration < block.timestamp, "ILO has ended use approveILO");
        require(_confirm == 369, "Wrong confirmation code");
            success = false;
            fundsReturn = true;
            sellerVault = 0;
            emit approveILO("ILO Failed");
    }
/*
   @dev: people who send Matic by mistake to the contract can withdraw them
*/
    mapping(address => uint256) public balanceReceived;

    function receiveMoney() public payable {
        assert(balanceReceived[msg.sender] + msg.value >= balanceReceived[msg.sender]);
        balanceReceived[msg.sender] += msg.value;
    }

    function withdrawWrongTransaction(address payable _to, uint256 _amount) public {
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
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
               **********************************************************/
    

