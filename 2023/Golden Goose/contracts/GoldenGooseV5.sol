// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract InvestmentContract is AccessControl, Pausable {
    
    using Counters for Counters.Counter;
    Counters.Counter private _requestIds;

    IERC20 public usdtToken;

    struct WithdrawalRequest {
        uint256 id;
        uint256 amount;
        address requester;
        bool processed;
        uint256 timestamp;
    }

    struct UserBalance {
        uint256 deposits;
        uint256 processing;
        uint256 rewards;
        uint256 totalDeposits;
        uint256 totalRewards;
        uint256 totalWithdrawals;
    }

    struct ReferralBalance {
        uint256 rewards;
        uint256 totalRewards;
        uint256 totalWithdrawals;
    }

    struct Injection {
        uint256 amount;
        uint256 timestamp;
    }
    
    struct Transaction {
        uint256 transactionType;
        uint256 amount;
        uint256 timestamp;
    }

    address[] public investors;

    mapping(uint256 => Injection) public _injections;
    uint256 public _injectionCount;

    mapping (address => bool) private _investorExists;
    mapping (address => UserBalance) public userBalanceByAddress;
    mapping (address => ReferralBalance) public referralBalanceByAddress;
    mapping (address => address) public _referrers;
    mapping (address => Transaction[]) public userTransactionsByAddress;
    mapping (address => uint256) public referralAmountByUser;

    mapping(uint256 => WithdrawalRequest) public _withdrawalRequests;
    uint256 public _withdrawalRequestsCount;

    address public teamWallet;
    address public fundsWallet;
    uint256 public fundsAllocation;
    uint256 public tax;
    
    uint256 public totalInvestments;
    uint256 public totalDeposits;
    uint256 public totalAddresses;
    uint256 public totalRewards;
    uint256 public totalWithdrawals;
    uint256 public totalProfits;
    uint256 public totalLoss;

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    // Events
    event Invested(address indexed investor, uint256 amount);
    event FundCollected(address indexed collector, uint256 amount);
    event WithdrawalRequested(address indexed requester, uint256 requestId, uint256 amount);
    event WithdrawalProcessed(address indexed requester, uint256 requestId, uint256 amount);
    event WithdrawalsProcessed(uint256[] requestIds, uint256 amount);
    event RewardsCompounded(address indexed investor, uint256 amount);
    event RewardsDistributed(uint256 totalReward);
    event LossSpread(uint256 amount);
    event ContractPaused();
    event ContractUnpaused();
    event TaxChanged(uint256 amount);
    event MigrationProcessed(address newContract, uint256 balance);
    event WalletsChanged(address teamWallet, address fundsWallet);
    
    constructor(
        address ownerAddress,
        address usdtAddress,
        address teamWalletAddress,
        address fundsWalletAddress,
        uint256 fundsAllocationAmount,
        uint256 taxAmount
        )  {
        _setupRole(DEFAULT_ADMIN_ROLE, ownerAddress);
        _setupRole(OWNER_ROLE, ownerAddress);

        usdtToken = IERC20(usdtAddress);
        teamWallet = teamWalletAddress;
        fundsWallet = fundsWalletAddress;
        fundsAllocation = fundsAllocationAmount;
        tax = taxAmount;
    }

    function invest(uint256 amount, address referral) external whenNotPaused {
        address sender = msg.sender;
        require(usdtToken.balanceOf(sender) >= amount, "!balance");
        require(amount >= 100 * 10 ** 18, "!minAmount");

        uint256 taxAmount = (amount * tax) / 100; 
        uint256 depositAmount = amount - taxAmount;

        totalInvestments += depositAmount;
        totalDeposits += depositAmount;

        usdtToken.transferFrom(sender, fundsWallet, depositAmount);
        usdtToken.transferFrom(sender, teamWallet, taxAmount);

        if (!_investorExists[sender]) {
            totalAddresses += 1;
            _investorExists[sender] = true;
            investors.push(sender);
        }
        
        UserBalance storage user = userBalanceByAddress[sender];
        user.deposits += depositAmount;
        user.totalDeposits += depositAmount;

        if(referral != address(0) && _referrers[sender] == address(0)) {
            _referrers[sender] = referral;
            referralAmountByUser[referral] += 1;
        }

        Transaction memory newTransaction = Transaction({
            transactionType: 1,
            amount: depositAmount,
            timestamp: block.timestamp
        });

        userTransactionsByAddress[sender].push(newTransaction);

        emit Invested(sender, amount);
    }
   
    function requestWithdrawal(uint256 amount) public  {
        address sender = msg.sender;
        UserBalance storage user = userBalanceByAddress[sender];

        require(user.deposits >= amount, "Not enough deposit amount");
        
        uint256 newRequestId = _requestIds.current();
        _requestIds.increment();

        user.deposits -= amount;
        user.processing += amount;

        _withdrawalRequests[newRequestId] = WithdrawalRequest(newRequestId, amount, sender, false, block.timestamp);

        _withdrawalRequestsCount++;
        emit WithdrawalRequested(sender, newRequestId, amount);
    }

    function processWithdrawal(uint256 requestId) public onlyRole(OWNER_ROLE) {
        require(_withdrawalRequests[requestId].requester != address(0), "Invalid request");
        require(_withdrawalRequests[requestId].processed == false, "Request already processed");

        _withdrawalRequests[requestId].processed = true;

        uint256 withdrawalAmount = _withdrawalRequests[requestId].amount;
        address requester = _withdrawalRequests[requestId].requester;
        
        UserBalance storage user = userBalanceByAddress[requester];
        user.processing -= withdrawalAmount;
    
        totalDeposits -= withdrawalAmount;

        usdtToken.transferFrom(msg.sender, requester, withdrawalAmount);
        
        Transaction memory newTransaction = Transaction({
            transactionType: 5,
            amount: withdrawalAmount,
            timestamp: block.timestamp
        });

        userTransactionsByAddress[requester].push(newTransaction);

        emit WithdrawalProcessed(requester, requestId, withdrawalAmount);
    }
    
    function processMultipleWithdrawals(uint256[] memory requestIds) public onlyRole(OWNER_ROLE) {

        uint256 amount = 0; 

        for(uint256 i = 0; i < requestIds.length; i++) {
            require(_withdrawalRequests[requestIds[i]].requester != address(0), "Invalid request");
            require(_withdrawalRequests[requestIds[i]].processed == false, "Request already processed");

            _withdrawalRequests[requestIds[i]].processed = true;

            uint256 withdrawalAmount = _withdrawalRequests[requestIds[i]].amount;
            address requester = _withdrawalRequests[requestIds[i]].requester;
            
            UserBalance storage user = userBalanceByAddress[requester];
            user.processing -= withdrawalAmount;
    
            totalDeposits -= withdrawalAmount;
            amount += withdrawalAmount;

            usdtToken.transferFrom(msg.sender, requester, withdrawalAmount);

            Transaction memory newTransaction = Transaction({
                transactionType: 5,
                amount: withdrawalAmount,
                timestamp: block.timestamp
            });

            userTransactionsByAddress[requester].push(newTransaction);

        } 
        
        emit WithdrawalsProcessed(requestIds, amount);
    }

    function claimRewards() public  {
        address sender = msg.sender;
        UserBalance storage user = userBalanceByAddress[sender];
        uint256 rewards = user.rewards;

        require(rewards > 0, "No rewards to claim");

        user.rewards = 0;

        totalRewards -= rewards;
        totalWithdrawals+= rewards;
        
        user.totalWithdrawals += rewards;

        Transaction memory newTransaction = Transaction({
            transactionType: 2,
            amount: rewards,
            timestamp: block.timestamp
        });

        userTransactionsByAddress[sender].push(newTransaction);

        usdtToken.transfer(sender, rewards);
    }

    function claimReferralRewards() public {
        address sender = msg.sender;
        ReferralBalance storage user = referralBalanceByAddress[sender];
        uint256 rewards = user.rewards;

        require(rewards > 0, "No rewards to claim");

        user.rewards = 0;
        
        user.totalWithdrawals += rewards;

        Transaction memory newTransaction = Transaction({
            transactionType: 4,
            amount: rewards,
            timestamp: block.timestamp
        });

        userTransactionsByAddress[sender].push(newTransaction);

        usdtToken.transfer(sender, rewards);
    }

    function compoundRewards() public whenNotPaused {
        address sender = msg.sender;
        UserBalance storage user = userBalanceByAddress[sender];
        uint256 rewards = user.rewards;
        uint256 taxAmount = (rewards * tax) / 100; 
        uint256 depositAmount = rewards - taxAmount;
        require(rewards > 0, "No rewards to claim");

        user.rewards = 0;
        user.deposits += depositAmount;

        totalRewards -= depositAmount;
        totalDeposits += depositAmount;

        user.totalDeposits += depositAmount;

        usdtToken.transfer(fundsWallet, depositAmount);
        usdtToken.transfer(teamWallet, taxAmount);

        Transaction memory newTransaction = Transaction({
            transactionType: 3,
            amount: rewards,
            timestamp: block.timestamp
        });

        userTransactionsByAddress[sender].push(newTransaction);
        
        emit RewardsCompounded(sender, rewards);
    }

    function distributeRewards(uint256 reward) public onlyRole(OWNER_ROLE) {

        address sender = msg.sender;
        require(usdtToken.balanceOf(sender) >= reward, "!reward");
        require(totalDeposits > 0, "!deposits");

        uint256 totalDistribution = (reward * (100 - fundsAllocation)) / 100;
        uint256 teamDistribution = (reward * fundsAllocation) / 100;
        uint256 referralDistribution = (reward * 1) / 100;

        totalProfits += reward;
        totalRewards += totalDistribution;

        uint256 referralAmount = 0;
        
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 userInvestment = userBalanceByAddress[investor].deposits + userBalanceByAddress[investor].processing;
            address referrer = _referrers[investor];

            //rewadToDistribute is the total amount to distribute - fundsAllocation
            uint256 rewardsToDistribute = totalDistribution * userInvestment / totalDeposits;

            userBalanceByAddress[investor].rewards += rewardsToDistribute;
            userBalanceByAddress[investor].totalRewards += rewardsToDistribute;

            if (referrer != address(0)) { // Check if referrer exists
                uint256 referralRewards = referralDistribution * userInvestment / totalDeposits;
                referralBalanceByAddress[referrer].rewards += referralRewards;
                referralBalanceByAddress[referrer].totalRewards += referralRewards;
                referralAmount += referralRewards;
            }
        }

        usdtToken.transferFrom(sender, teamWallet, teamDistribution - referralAmount); //Transfer to team
        usdtToken.transferFrom(sender, address(this), totalDistribution + referralAmount); //Transfer to contract total to distribute

        Injection storage newInjection = _injections[_injectionCount];
        newInjection.amount = totalDistribution;
        newInjection.timestamp = block.timestamp;
        _injectionCount++;

        emit RewardsDistributed(reward);
    }

    function spreadLoss(uint256 loss) public onlyRole(OWNER_ROLE) {
        
        require(totalDeposits > 0, "!deposits");

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            userBalanceByAddress[investor].deposits -= (userBalanceByAddress[investor].deposits * loss) / totalDeposits;
        }
        
        totalLoss += loss;
        totalDeposits -= loss;
   
        emit LossSpread(loss);
    }


    function setFundsAllocation(uint256 _fundsAllocation) public onlyRole(OWNER_ROLE) {
        require(_fundsAllocation <= 20, "!less_or_equal_20");
        fundsAllocation = _fundsAllocation;
    }

    function getWithdrawalsRequest(uint256 count) external view returns(WithdrawalRequest[] memory) {
        require(count <= _withdrawalRequestsCount, "Not enough Withdrawal Requests.");

        WithdrawalRequest[] memory withdrawals = new WithdrawalRequest[](count);
        for (uint i = 0; i < count; i++) {
            withdrawals[i] = _withdrawalRequests[_withdrawalRequestsCount - i - 1];
        }

        return withdrawals;
    }

    function getLastInjections(uint256 count) public view returns (Injection[] memory) {
        require(count <= _injectionCount, "Not enough injections.");

        Injection[] memory injections = new Injection[](count);
        for (uint i = 0; i < count; i++) {
            injections[i] = _injections[_injectionCount - i - 1];
        }
        return injections;
    }

    
    function getTransactionsByAddress(address _address) public view returns (Transaction[] memory) {
        return userTransactionsByAddress[_address];
    }

    function pause() public onlyRole(OWNER_ROLE) {
        _pause();
        emit ContractPaused();
    }

    function unpause() public onlyRole(OWNER_ROLE) {
        _unpause();
        emit ContractUnpaused();
    }

    function setTax(uint256 _tax) public onlyRole(OWNER_ROLE) {
        tax = _tax;
        emit TaxChanged(_tax);
    }

    function setWallets(address _teamWalletAddress, address _fundsWalletAddress) public onlyRole(OWNER_ROLE) {
        teamWallet = _teamWalletAddress;
        fundsWallet = _fundsWalletAddress;
        emit WalletsChanged(teamWallet, fundsWallet);
    }

    function migrate(address newContract) public onlyRole(OWNER_ROLE) {
        uint256 balance = IERC20(usdtToken).balanceOf(address(this));
        usdtToken.transfer(newContract, balance);
        emit MigrationProcessed(newContract, balance);
    }
}