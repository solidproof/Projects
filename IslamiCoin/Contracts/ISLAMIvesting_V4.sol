// SPDX-License-Identifier: MIT

//This is a vesting contract for ISLAMI token, with monthly percentage claims after total locking


import "./importISLAMICOIN.sol";

pragma solidity = 0.8.13;

contract ISLAMIvesting_V4 {
    using SafeMath for uint256;

    address public BaytAlMal = 0xC315A5Ce1e6330db2836BD3Ed1Fa7228C068cE20;
    address constant zeroAddress = address(0x0);
    address constant deadAddress = 0x000000000000000000000000000000000000dEaD;

    ISLAMICOIN public ISLAMI;
    address private owner;
    uint256 Sonbola = 10**7;
    uint256 public constant monthly = 1; //30 days; this should change after testing
    uint256 public investorCount;
    uint256 private IDinvestor;
    uint256 public investorVault;
    uint256 public slinvestorCount;
    uint256 private slIDinvestor;
    uint256 public slInvestorVault;
    uint256 public allVaults;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 constant hPercent = 100; //100%
    uint256 private _status;
    uint256 public mP = 5; /* Monthy percentage */
    uint256 public minLock = 100000 * Sonbola;
    uint256 public ewFee = 1; //1% of locked amount
    uint256 private OneVote = 100000 * Sonbola; /* Each 100K ISLAMI equal One Vote!   */

    event InvestorAdded(address Investor, uint256 Amount);
    event ISLAMIClaimed(address Investor, uint256 Amount);
    event SelfLockInvestor(address Investor, uint256 Amount);
    event SelfISLAMIClaim(address Investor, uint256 Amount);
    event EmergencyWithdraw(address Investor, address NewWallet, uint256 Amount);
    event ChangeOwner(address NewOwner);
    event Voted(address Voter, uint256 voteFee);
    event WithdrawalMatic(uint256 _amount, uint256 decimal, address to);
    event WithdrawalISLAMI(uint256 _amount,uint256 sonbola, address to);
    event WithdrawalERC20(address _tokenAddr, uint256 _amount,uint256 decimals, address to);

    struct VaultInvestor{
        uint256 investorID;
        uint256 falseAmount; //represents the actual amount locked in order to keep track of monthly percentage to unlock
        uint256 amount;
        address recoveryWallet;
        uint256 monthLock;
        uint256 lockTime;
        uint256 timeStart;
    }
    struct SelfLock{
        uint256 slInvestorID;
        uint256 slAmount;
        uint256 slLockTime;
        uint256 slTimeStart;
        address recoveryWallet;
    }
    struct VoteSystem{
        string projectName;
        uint256 voteCount;
    }

    mapping(address => bool) public Investor;
    mapping(uint => address) public InvestorCount;
    mapping(address => VaultInvestor) public investor;

    mapping(address => bool) public slInvestor;
    mapping(uint => address) public slInvestorCount;
    mapping(address => SelfLock) public slinvestor;

    mapping(address => bool) public blackList;
    //mapping(uint => voteSystem) public projectToVote;

    VoteSystem[] public voteSystem;

    modifier onlyOwner (){
        require(msg.sender == owner, "Only ISLAMICOIN owner can add Investors");
        _;
    }

    modifier isInvestor(address _investor){
        require(Investor[_investor] == true, "Not an Investor!");
        _;
    }
    modifier ISslInvestor(address _investor){
        require(slInvestor[_investor] == true, "Not an Investor!");
        _;
    }
    modifier isBlackListed(address _investor){
        require(blackList[_investor] != true, "Your wallet is Blacklisted!");
        _;
    }
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    constructor(ISLAMICOIN _ISLAMI) {
        owner = msg.sender;
        investorCount = 0;
        IDinvestor = 0;
        ISLAMI = _ISLAMI;
        _status = _NOT_ENTERED;
    }
    function transferOwnership(address _newOwner)external onlyOwner{
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    function changeBaytAlMal(address _newBaytAlMal) external onlyOwner{
        BaytAlMal = _newBaytAlMal;
    }
    function setMonthlyPercentage(uint256 _mP) external onlyOwner{
        mP = _mP;
    }
    function setMinLock(uint256 _minLock) external onlyOwner{
        minLock = _minLock;
    }
    function setEmergencyFee(uint256 _eW) external onlyOwner{
        ewFee = _eW; // * Sonbola;
    }
    function setOneVote(uint256 _oneVote) external onlyOwner{
        OneVote = _oneVote;// * Sonbola;
    }
    function addToVote(string memory _projectName) external onlyOwner{
        VoteSystem memory newVoteSystem = VoteSystem({
            projectName: _projectName,
            voteCount: 0
        });
        voteSystem.push(newVoteSystem);
    }
    function newVote(uint256 projectIndex, uint256 _vP) internal{
        voteSystem[projectIndex].voteCount += _vP;
    }
    function deleteVoteProject(uint256 projectIndex) external onlyOwner{
        voteSystem[projectIndex] = voteSystem[voteSystem.length -1];
        voteSystem.pop();
    }
    function totalLocked() internal{
        allVaults = investorVault.add(slInvestorVault);
    }
    function addInvestor(address _investor, uint256 _amount, uint256 _lockTime, address _recoveryWallet) external onlyOwner{
        uint256 amount = _amount.mul(Sonbola);
        totalLocked();
        uint256 availableAmount = ISLAMI.balanceOf(address(this)).sub(allVaults);
        require(availableAmount >= amount,"No ISLAMI");
        uint256 lockTime = _lockTime.mul(1);//(1 days); need to change after testing******
        require(amount > 0, "Amount!");
        if(investor[_investor].amount > 0){
            investor[_investor].amount += amount;
            investor[_investor].falseAmount = investor[_investor].amount;
            //investor[_investor].monthLock += lockTime.add(monthly);
            investorVault += amount;
            return;
        }
        //require(lockTime > monthly.mul(3), "Please set a time in the future more than 90 days!"); need to activate after testing
        emit InvestorAdded(msg.sender, amount);
        IDinvestor++;
        investor[_investor].investorID = IDinvestor;
        investor[_investor].falseAmount = amount;
        investor[_investor].amount = amount;
        investor[_investor].recoveryWallet = _recoveryWallet;
        investor[_investor].lockTime = lockTime.add(block.timestamp);
        investor[_investor].timeStart = block.timestamp;
        investor[_investor].monthLock = lockTime.add(block.timestamp);
        Investor[_investor] = true;
        investorVault += amount;
        totalLocked();
        investorCount++;
    }
    function selfLock(uint256 _amount, uint256 _lockTime, address _recoveryWallet) external isBlackListed(msg.sender) nonReentrant{
        //require approve form ISLAMICOIN contract
        require(_recoveryWallet != deadAddress, "Burn!");
        if(_recoveryWallet == zeroAddress){
            _recoveryWallet = address(this);
        }
        require(slInvestor[msg.sender] != true,"Double locking!");
        uint256 amount = _amount;// * Sonbola;
        require(amount >= minLock, "Amount!");
        uint256 lockTime = _lockTime.mul(1 days);
        require(ISLAMI.balanceOf(msg.sender) >= amount);
        ISLAMI.transferFrom(msg.sender, address(this), amount); //require approve on allawance
        emit SelfLockInvestor(msg.sender, amount);
        slIDinvestor++;
        slinvestor[msg.sender].slInvestorID = slIDinvestor;
        slinvestor[msg.sender].slAmount = amount;
        slinvestor[msg.sender].slTimeStart = block.timestamp;
        slinvestor[msg.sender].slLockTime = lockTime.add(block.timestamp);
        slinvestor[msg.sender].recoveryWallet = _recoveryWallet;
        slInvestor[msg.sender] = true;
        slInvestorVault += amount;
        totalLocked();
        slinvestorCount++;
    }
    function editSelfLock(uint256 _amount) external ISslInvestor(msg.sender) nonReentrant{
        uint256 amount = _amount;// * Sonbola;
        require(ISLAMI.balanceOf(msg.sender) >= amount);
        ISLAMI.transferFrom(msg.sender, address(this), amount); //require approve on allawance
        slinvestor[msg.sender].slAmount += amount;
        slInvestorVault += amount;
        totalLocked();
    }
    function extendSelfLock(uint256 _lockTime) external ISslInvestor(msg.sender) nonReentrant{
        uint256 lockTime = _lockTime.mul(1 days);
        slinvestor[msg.sender].slLockTime += lockTime;
    }
    function recoverWallet(address _investor) external ISslInvestor(_investor) nonReentrant{ //Investor lost his phone or wallet, or passed away!
        require(msg.sender == slinvestor[_investor].recoveryWallet &&
        slinvestor[_investor].slLockTime > block.timestamp,
        "Not allowed"); // only the wallet registered as recovery can claim tokens after lock is done
        useRecovery(_investor);
    }
    function selfUnlock(uint256 _amount) external ISslInvestor(msg.sender) nonReentrant{
        require(slinvestor[msg.sender].slLockTime >= block.timestamp, "Not yet");
        uint256 amount = _amount;// * Sonbola;
        require(slinvestor[msg.sender].slAmount >= amount, "Amount!");
        slinvestor[msg.sender].slAmount -= amount;
        slInvestorVault -= amount;
        if(slinvestor[msg.sender].slAmount == 0){
            slInvestor[msg.sender] = false;
            delete slinvestor[msg.sender];
            delete slInvestorCount[slinvestor[msg.sender].slInvestorID];
            slinvestorCount--;
        }
        totalLocked();
        emit SelfISLAMIClaim(msg.sender, amount);
        ISLAMI.transfer(msg.sender, amount);
    }
    //If self lock investor wallet was hacked!
    function emergencyWithdrawal() external ISslInvestor(msg.sender) nonReentrant{
        useRecovery(msg.sender);
    }
    function useRecovery(address _investor) internal {
        blackList[_investor] = true;
        uint256 feeToPay = slinvestor[_investor].slAmount.mul(ewFee).div(100);
        address newWallet = slinvestor[_investor].recoveryWallet;
        uint256 fullBalance = slinvestor[_investor].slAmount.sub(feeToPay);
        slInvestorVault -= slinvestor[_investor].slAmount;
        slInvestor[_investor] = false;
        delete slinvestor[_investor];
        delete slInvestorCount[slinvestor[_investor].slInvestorID];
        totalLocked();
        slinvestorCount--;
        emit EmergencyWithdraw(_investor, newWallet, fullBalance);
        if(newWallet == address(this)){
            //Release tokens to smart contract, investor should contact project owner on Telegram @jeffrykr
            return();
        }
        ISLAMI.transfer(newWallet, fullBalance);
    }
    function claimMonthlyAmount() external isInvestor(msg.sender) nonReentrant{
        uint256 totalTimeLock = investor[msg.sender].monthLock;
        uint256 mainAmount = investor[msg.sender].falseAmount;
        uint256 remainAmount = investor[msg.sender].amount;
        require(totalTimeLock <= block.timestamp, "Not yet");
        require(remainAmount > 0, "No ISLAMI");
        //uint256 percentage = investor[msg.sender].monthAllow;
        uint256 amountAllowed = mainAmount.mul(mP).div(hPercent);
        uint256 _investorID = investor[msg.sender].investorID;
        investor[msg.sender].amount = remainAmount.sub(amountAllowed);
        investor[msg.sender].monthLock += monthly;
        investorVault -= amountAllowed;
        if(investor[msg.sender].amount == 0){
            Investor[msg.sender] = false;
            delete investor[msg.sender];
            delete InvestorCount[_investorID];
            investorCount--;
        }
        totalLocked();
        emit ISLAMIClaimed(msg.sender, amountAllowed);
        ISLAMI.transfer(msg.sender, amountAllowed);
    }
    function claimRemainings() external isInvestor(msg.sender) nonReentrant{
        uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = investor[msg.sender].lockTime.add(fullTime);
        require(totalTimeLock <= block.timestamp, "Not yet");
        uint256 remainAmount = investor[msg.sender].amount;
        uint256 _investorID = investor[msg.sender].investorID;
        investor[msg.sender].amount = 0;
        investorVault -= remainAmount;
        Investor[msg.sender] = false;
        delete investor[msg.sender];
        delete InvestorCount[_investorID];
        emit ISLAMIClaimed(msg.sender, remainAmount);
        ISLAMI.transfer(msg.sender, remainAmount);
        totalLocked();
        investorCount--;
    }
    function returnInvestorLock(address _investor) public view returns(uint256 _amount, uint256 timeLeft){
        _amount = investor[_investor].amount;
        timeLeft = (investor[_investor].monthLock.sub(block.timestamp)).div(1 days);
        return(_amount, timeLeft);
    }
    function returnSL(address _slInvestor) public view returns(uint256 amount, uint256 timeLeft){
        amount = slinvestor[_slInvestor].slAmount;
        timeLeft = (slinvestor[_slInvestor].slLockTime.sub(block.timestamp)).div(1 days);
        return(amount, timeLeft);
    }
    function voteFor(uint256 projectIndex, uint256 _votingFee) isBlackListed(msg.sender) public nonReentrant{
        require(Investor[msg.sender] == true || slInvestor[msg.sender] == true,"not allowed");

        address voter = msg.sender;
        uint256 votePower;
        uint256 votingFee = _votingFee;// * Sonbola;
        //uint256 basePower = ISLAMI.balanceOf(voter);
        uint256 lockedBasePower;
        uint256 mainPower;
/*
        if(votingFee == 0 && Investor[voter] == true){
            lockedBasePower = investor[voter].amount;
            votePower = lockedBasePower.div(OneVote);
            newVote(projectIndex, votePower);
            emit Voted(msg.sender, 0);
            return();
        }
        if(votingFee == 0 && slInvestor[voter] == true){
            require(slinvestor[msg.sender].slLockTime >= monthly,"Should lock 30 days");
            lockedBasePower = slinvestor[voter].slAmount;
            votePower = lockedBasePower.div(OneVote);
            newVote(projectIndex, votePower);
            emit Voted(msg.sender, 0);
            return();
        }*/

        if(Investor[voter] == true && slInvestor[voter] != true){
            lockedBasePower = investor[voter].amount;
            require(lockedBasePower > votingFee,"Need more ISLAMI");
            investor[voter].amount -= votingFee;
            investorVault -= votingFee;
        }
        if(slInvestor[voter] == true && Investor[voter] != true){
            require(slinvestor[msg.sender].slLockTime >= monthly,"Should lock 30 days");
            lockedBasePower = slinvestor[voter].slAmount;
            require(lockedBasePower > votingFee,"Need more ISLAMI");
            slinvestor[voter].slAmount -= votingFee;
            slInvestorVault -= votingFee;
        }
        if(Investor[voter] == true && slInvestor[voter] == true){
            //require(slinvestor[msg.sender].slLockTime >= monthly,"Should lock 30 days");
            uint256 lockedBasePower1 = investor[voter].amount;
            uint256 lockedBasePower2 = slinvestor[voter].slAmount;
            lockedBasePower = lockedBasePower1.add(lockedBasePower2);
            require(lockedBasePower2 > votingFee,"Need more ISLAMI");
            slinvestor[voter].slAmount -= votingFee;
            slInvestorVault -= votingFee;
        }
        mainPower = lockedBasePower*10**2;
        if(votingFee > 0){
            ISLAMI.transfer(BaytAlMal, votingFee);
        }
        votePower = mainPower.div(OneVote);
        newVote(projectIndex, votePower);
        emit Voted(msg.sender, votingFee);
    }
    //If long term investor wallet was lost!
    function releaseWallet(address _investor) isInvestor(_investor) external nonReentrant{
        uint256 fullTime = hPercent.div(mP).mul(monthly);
        uint256 totalTimeLock = investor[_investor].lockTime.add(fullTime);
        require(msg.sender == investor[_investor].recoveryWallet &&
        totalTimeLock < block.timestamp,"Not yet!");
        blackList[_investor] = true;
        uint256 remainAmount = investor[_investor].amount;
        uint256 _investorID = investor[_investor].investorID;
        investor[_investor].amount = 0;
        investorVault -= remainAmount;
        totalLocked();
        Investor[_investor] = false;
        delete investor[_investor];
        delete InvestorCount[_investorID];
        investorCount--;
        emit EmergencyWithdraw(_investor, msg.sender, remainAmount);
        ISLAMI.transfer(msg.sender, remainAmount);
    }
    function withdrawalISLAMI(uint256 _amount, uint256 sonbola, address to) external onlyOwner() {
        ERC20 _tokenAddr = ISLAMI;
        totalLocked();
        uint256 amount = ISLAMI.balanceOf(address(this)).sub(allVaults);
        require(amount > 0 && amount >= _amount, "No ISLAMI!");// can only withdraw what is not locked for investors.
        uint256 dcml = 10 ** sonbola;
        ERC20 token = _tokenAddr;
        emit WithdrawalISLAMI( _amount, sonbola, to);
        token.transfer(to, _amount*dcml);
    }
    function withdrawalERC20(address _tokenAddr, uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        uint256 dcml = 10 ** decimal;
        ERC20 token = ERC20(_tokenAddr);
        require(token != ISLAMI, "No!"); //Can't withdraw ISLAMI using this function!
        emit WithdrawalERC20(_tokenAddr, _amount, decimal, to);
        token.transfer(to, _amount*dcml);
    }
    function withdrawalMatic(uint256 _amount, uint256 decimal, address to) external onlyOwner() {
        require(address(this).balance >= _amount,"Balanace"); //No matic balance available
        uint256 dcml = 10 ** decimal;
        emit WithdrawalMatic(_amount, decimal, to);
        payable(to).transfer(_amount*dcml);
    }
    receive() external payable {}
}


//********************************************************
// Proudly Developed by MetaIdentity ltd. Copyright 2022
//********************************************************