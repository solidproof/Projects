//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract ProfitParadox {
    IERC20 public usdt;

    struct Player {
        uint256 deposit;
        uint256 earnings;
        uint256 lastUpdated;
        uint256 lastReferred;
        uint256 referrals;
        uint256 referredAmount;
        uint256 totalAirdrops;
        uint256 lastClaimed;
        uint256 maxPayout;
        uint256 totalClaimed;
        address team;
    }

    struct Contest {
        address topDepositor;
        uint256 maxDeposit;
        uint256 reward;
        bool claimed;
    }

    struct Team {
        string name;
        address creator;
        address[] members;
    }

    mapping(address => Team) public teams;
    mapping(uint256 => Contest) public contests;
    mapping(address => Player) public players;
    mapping(address => bool) public hasDeposited;
    mapping(address => bool) public votes;
    address[] public waitlist;
    address[] public teamList;
    address[] public playerList;
    address payable marketing;
    uint256 public numVotes;
    uint256 public depositCount;
    uint256 public contractLaunchTime;
    uint256 public rebalanceRewardPool;
    uint256 public rebalanceCooldown;
    uint256 public contractBalance;
    uint256 public totalInvested;
    uint256 public totalReferralCount;
    uint256 public lastDepositTimestamp;
    uint256 public globalPenalties;
    uint256 public globalReversals;
    uint256 public playerCount;
    uint256 public titansPool;
    uint256 public giantsPool;
    uint256 public elitesPool;
    uint256 public titansTotalEarned;
    uint256 public giantsTotalEarned;
    uint256 public elitesTotalEarned;
    uint256 public rebalanceCooldownInterval = 2 days; // Base cooldown for rebalance is 2 days, increases with each rebalance
    uint256 public earningsRate = 300; // Base earnings rate is 3% until someone pays to change it
    uint256 constant CLAIM_DURATION = 1 days; // Claims are open for 24 hours 
    uint256 constant CLAIM_INTERVAL = 7 days; // Claims are every 7 days 
    uint256 constant MULTIPLIER = 10000; // For math
    uint256 constant REFERRAL_REWARD = 500; // 5% referral reward
    uint256 constant MAX_PAYOUT = 12500; // 125% max payout that increases 5% for every referral
    uint256 constant REBALANCE_REWARD = 500; // 5% goes to rebalance rewards pool
    uint256 constant REWARD_INTERVAL = 1 days; // Earnings are daily 
    enum TeamAction {RemoveMember, TransferOwnership, RenameTeam}
    
    constructor(
        address payable _marketingAddress, 
        address _usdtAddress
    ) {
        marketing = _marketingAddress;
        usdt = IERC20(_usdtAddress);
        contractLaunchTime = block.timestamp;
    }

    // Function to deposit an amount, optionally with a referrer and option to create a team.
    function deposit(uint256 _amount, address _referrer, bool createTeam, string memory teamName) external payable {
        // Ensure the deposit is above the minimum required deposit of $10
        require(_amount >= 10 ether && block.timestamp > 1689800400 && msg.sender == tx.origin, "Minimum deposit is $10");  

        // Transfer the deposit from the sender to this contract
        usdt.transferFrom(msg.sender, address(this), _amount); 

        // Calculate a portion of the deposit for the marketing fund
        uint256 marketingFund = _amount * 1000 / MULTIPLIER;

        // Transfer the calculated amount to the marketing fund
        usdt.transfer(marketing, marketingFund); 

        // If it's a claim day and there is some total invested,
        // Check if the amount deposited is greater than the current max deposit for the day.
        // If so, update max deposit and top depositor for the day.
        if (isClaimDay() && totalInvested > 0) { 
            uint256 currentDay = (block.timestamp - contractLaunchTime) / CLAIM_INTERVAL;
            if (_amount > contests[currentDay].maxDeposit) {
                contests[currentDay].maxDeposit = _amount;
                contests[currentDay].topDepositor = msg.sender;
            }
        }

        // Update penalty information
        (uint256 hoursPassed, uint256 penalties, uint256 reversals) = calculateHoursPenaltiesReversals();
        globalPenalties = penalties;
        globalReversals = reversals;
        lastDepositTimestamp = block.timestamp;

        // Add the deposited amount to the total invested and to the rebalance reward pool
        totalInvested += _amount;
        rebalanceRewardPool += (_amount * REBALANCE_REWARD) / MULTIPLIER;

        // Player and team actions start here
        Player storage player = players[msg.sender];
        if (createTeam) {
            if (player.team != msg.sender){
                if (player.team != address(0)){
                    // Remove player from the old team if they were in one
                    Team storage team = teams[player.team];
                    for (uint i = 0; i < team.members.length; i++) {
                        if (team.members[i] == msg.sender) {
                            team.members[i] = team.members[team.members.length - 1];
                            team.members.pop();
                            break;
                        }
                    }
                }
                // Add player to the new team
                player.team = msg.sender;
                Team storage newTeam = teams[msg.sender];
                newTeam.creator = msg.sender;
                newTeam.name = teamName;
                newTeam.members.push(msg.sender);

                // Add the new team to the team list
                teamList.push(msg.sender);
                
                // Check if player is in the waitlist and remove them if found
                for (uint j = 0; j < waitlist.length; j++) {
                    if (waitlist[j] == msg.sender) {
                        waitlist[j] = waitlist[waitlist.length - 1];
                        waitlist.pop();
                        break;
                    }
                }
            }
        }
        // If the player is referred by someone else and they're not already in a team,
        // Then either add them to the referrer's team or to the global waitlist.
        else if (_referrer != address(0) && _referrer != msg.sender) {
            if (player.team == address(0)) {
                if (teams[_referrer].members.length >= 20) {
                     bool isFound = false;
                    for (uint i = 0; i < waitlist.length; i++) {
                        if (waitlist[i] == msg.sender) {
                            isFound = true;
                            break;
                        }
                    }
                    if (!isFound) {
                        waitlist.push(msg.sender);
                    }
                } else {
                    player.team = _referrer;
                    teams[_referrer].members.push(msg.sender);
                    
                    // Check if player is in the waitlist and remove them if found
                    for (uint j = 0; j < waitlist.length; j++) {
                        if (waitlist[j] == msg.sender) {
                            waitlist[j] = waitlist[waitlist.length - 1];
                            waitlist.pop();
                            break;
                        }
                    }
                }
            }
        } 
        else {
            waitlist.push(msg.sender);
        }


        // If the player is referred by someone else,
        // Update the referrer's stats and transfer them the referral reward.
        if (_referrer != address(0) && _referrer != msg.sender) {
            Player storage referrer = players[_referrer];
            referrer.lastReferred = block.timestamp;
            referrer.referrals += 1;
            referrer.referredAmount += _amount;
            referrer.maxPayout = (referrer.deposit * (MAX_PAYOUT + (referrer.referrals * REFERRAL_REWARD))) / (MULTIPLIER);
            uint256 airdropAmount = (_amount * REFERRAL_REWARD) / MULTIPLIER;
            usdt.transfer(_referrer, airdropAmount);
            
            // If the referrer is also part of a team, transfer half the referral reward to the team owner.
            if (referrer.team != _referrer) {
                Player storage teamOwner = players[referrer.team];
                usdt.transfer(referrer.team, airdropAmount / 2);
                teamOwner.totalAirdrops += airdropAmount / 2;
            }
            
            referrer.totalAirdrops += airdropAmount;
            _amount = (_amount * 110) / 100;
            totalReferralCount += 1;
        } 

        // If the player is depositing for the first time,
        // Add a bonus to their deposit and add them to the player list.
        if (!hasDeposited[msg.sender]) {
            _amount = (_amount * 110) / 100;
            playerList.push(msg.sender);
            hasDeposited[msg.sender] = true;
            playerCount +=1;
        }

        // If the player has deposited before,
        // Calculate and update their earnings and principal.
        if (player.deposit > 0) {
            (uint256 playersEarnings, uint256 principal) = calculateRewards(msg.sender);
            player.lastUpdated = block.timestamp;
            player.earnings += playersEarnings;
            player.deposit = principal;
        }

        // Calculate the portions of the deposit for the different pools
        uint256 titansAmount = (_amount * 5) / 100;
        uint256 giantsAmount = (_amount * 3) / 100;
        uint256 elitesAmount = _amount / 100;

        // Add the portions to the pools
        titansPool += titansAmount;
        giantsPool += giantsAmount;
        elitesPool += elitesAmount;

        // Update the player's deposit and max payout
        player.lastUpdated = block.timestamp;
        player.deposit += _amount;
        player.maxPayout = (player.deposit * (MAX_PAYOUT + (player.referrals * REFERRAL_REWARD))) / (MULTIPLIER);
        
        // Update global stats
        depositCount += 1;
        updateContractBalance();
    }

    function updateContractBalance() internal {
        contractBalance = usdt.balanceOf(address(this));
    }

    // Determine THE TIMER's length based on deposits, referrals, total invested
     function calculateInterval() public view returns (uint256) {
        uint256 baseInterval = 1 days; // Upper bound
        uint256 lowerInterval = 1 hours; // Lower bound

        uint256 interval = baseInterval;

        // Decrease interval based on depositCount
        for(uint i = 0; i < depositCount; i++){
            interval = (interval * 80) / 100; // reduce by 20% compounded
        }

        // Increase interval based on totalReferralCount
        for(uint i = 0; i < totalReferralCount; i++){
            interval = (interval * 120) / 100;  // increase by 20% compounded
        }

        // Adjust interval based on difference between totalInvested and contractBalance
        if (totalInvested != 0) { // Only execute if totalInvested is not 0 to avoid division by zero
            uint256 diff = totalInvested > contractBalance ? totalInvested - contractBalance : 0;
            uint256 diffPercent = (diff * 100) / totalInvested;
            for(uint i = 0; i < diffPercent; i++){
                interval = (interval * 103) / 100; // slightly increase interval
            }
        }

        // If contractBalance is less than 20% of totalInvested, set interval to lowerInterval
        if (contractBalance * 5 < totalInvested) {
            interval = lowerInterval;
        }

        // Ensure the interval is within boundaries
        interval = interval < lowerInterval ? lowerInterval : interval > baseInterval ? baseInterval : interval;

        return interval;
    }


    // Function to determine the number of decays and recoveries to users deposits & earnings based on THE TIMER.
    function calculateHoursPenaltiesReversals() public view returns (uint256, uint256, uint256) {
        // Define a variable to hold the count of inactive periods
        uint256 inactivityCount;
        
        // Calculate the current interval length
        uint256 interval = calculateInterval();
        
        // Assign the global penalties count to a local variable
        uint256 penalties = globalPenalties;
        
        // Assign the global reversals count to a local variable
        uint256 reversals = globalReversals;

        // If there is any investment, calculate the inactivity count based on the time passed since the last deposit
        if (totalInvested > 0) {
            inactivityCount = (block.timestamp - lastDepositTimestamp) / interval;
        }
        
        
        
        
        // If there is at least one interval of inactivity, increment the penalties count
        if (inactivityCount >= 1) {
            penalties += inactivityCount;
        } 
        // If the penalties count is greater than the reversals count, increment the reversals count
        else if (penalties > reversals) {
            reversals += 1;
        }
        
        // Return the inactivity count, penalties count, and reversals count
        return (inactivityCount, penalties, reversals);
    }

    // Calculates the reward for a player based on their deposit and the elapsed time since their last update, accounting for penalties and reversals.
    function calculateRewards(address _playerAddress) public view returns (uint256 rewards, uint256 principal) {
        // Access the player's information
        Player storage player = players[_playerAddress];

        // Ensure the player's maximum payout is not exceeded
        require(player.maxPayout - player.totalClaimed > 0, "error");

        // Calculate the player's expected rewards based on their deposit, earnings rate, and time since last update
        uint256 expectedRewards = ((block.timestamp - player.lastUpdated) * player.deposit * earningsRate) / (MULTIPLIER * REWARD_INTERVAL);

        // Calculate the penalties and reversals based on the player's inactivity
        (uint256 hoursPassed, uint256 currentPenalties, uint256 currentReversals) = calculateHoursPenaltiesReversals();
        uint256 penalties = currentPenalties > currentReversals ? currentPenalties - currentReversals : 0;

        // Apply penalties to the player's deposit and expected rewards
        uint256 adjustedPrincipal = player.deposit;
        uint256 adjustedRewards = player.earnings + expectedRewards;

        for (uint256 i = 0; i < penalties; i++) {
            adjustedPrincipal = (adjustedPrincipal * 9900) / 10000;
            adjustedRewards = (adjustedRewards * 8000) / 10000;
        }

        // Ensure the player's deposit does not fall below a certain minimum
        adjustedPrincipal = adjustedPrincipal < 50 ether ? 50 ether : adjustedPrincipal;

        // Return the adjusted or expected rewards, along with the adjusted principal
        return (penalties > 0 ? adjustedRewards : expectedRewards, adjustedPrincipal);
    }

    // Allows a player to redeem their initial deposit if certain conditions are met, specifically if their referred amount is at least five times their deposit.
    function redeemInitial() external {
        // Access the player's information
        Player storage player = players[msg.sender];

        // Ensure the player has referred enough to redeem their initial deposit
        require(player.referredAmount >= player.deposit * 5, "error");

        // Calculate the amount to be paid to the player
        uint256 payment = ((player.deposit * 80) / 100) - player.totalClaimed;

        // Transfer the payment to the player and update their claimed amount
        usdt.transfer(msg.sender, payment);
        player.totalClaimed += payment;

        // Update the time of the player's last update and claim
        player.lastUpdated = block.timestamp;
        player.lastClaimed = block.timestamp;

        // Reset the player's earnings
        player.earnings = 0;

        // Update the contract's balance
        updateContractBalance();
    }

    // Updates player earnings and triggers a cooldown period for rebalancing, rewarding the caller with a portion of the rebalance reward pool.
    function rebalance() external returns(uint256 awardedAmount){
        // Calculate the reward to be distributed from the rebalance reward pool
        uint256 reward = rebalanceRewardPool / 2; 
        updateContractBalance();

        // Ensure rebalancing is allowed and there are sufficient funds for the reward
        require(block.timestamp >= rebalanceCooldown && !isClaimDay() && reward <= contractBalance, "error");

        // Increase the rebalance cooldown interval and set the new cooldown time
        rebalanceCooldownInterval = (rebalanceCooldownInterval * 120) / 100;
        rebalanceCooldown = block.timestamp + rebalanceCooldownInterval;

        // Reset the rebalance reward pool
        rebalanceRewardPool = 0; 

        // Reset the earnings of players who have not referred anyone in the past 2 days
        for (uint256 i = 0; i < playerList.length; i++) {
            Player storage player = players[playerList[i]];
            if (block.timestamp - player.lastReferred >= 2 days) {
                player.earnings = 0;
                player.lastUpdated = block.timestamp; 
            }
        }

        // Distribute the reward and update the contract's balance
        usdt.transfer(msg.sender, reward);
        usdt.transfer(marketing, reward/2);
        updateContractBalance();

        // Return the amount of the reward
        return reward;
    }

   // Allows users to increase or decrease the Return on Investment (ROI) for all players by 20%. The cost of this operation can be paid from the user's wallet or deposit.
    function adjustEarningsRate(bool _increase, bool _wallet) external returns(uint256 newRate, uint256 previousDeposit, uint256 currentDeposit){
        // Access the player's information
        Player storage player = players[msg.sender];
        updateContractBalance();
        // Calculate the fee for adjusting the earnings rate, depending on whether the earnings rate is to be increased or decreased
        (uint256 feeDeposit, uint256 feeWallet) = getAdjustEarningsRateFee(_increase);
        uint256 fee = _wallet ? feeWallet : feeDeposit;

        // Check if the player has sufficient funds to pay the fee
        uint256 previousBalance = _wallet ? contractBalance : player.deposit;
        require((_wallet && contractBalance >= fee) || (!_wallet && player.deposit - player.totalClaimed >= fee), "error");

        // If the fee is to be paid from the player's wallet, transfer the fee from their wallet to the contract
        if (_wallet) {
            require(usdt.balanceOf(msg.sender) >= fee, "error");
            usdt.transferFrom(msg.sender, address(this), fee);
        } 
        // If the fee is to be paid from the player's deposit, reduce their deposit by the fee amount and update their earnings and last updated time
        else {
            require(player.deposit - player.totalClaimed >= fee, "error");
            (uint256 playersEarnings,) = calculateRewards(msg.sender);
            player.lastUpdated = block.timestamp;
            player.deposit -= fee;
            player.earnings += playersEarnings;
        }
        
        // Update the player's balance
        uint256 newBalance = _wallet ? contractBalance : player.deposit;

        // Transfer part of the fee to the marketing wallet
        usdt.transfer(marketing, fee / 5);

        // Update the earnings and deposit for all players
        for (uint256 i = 0; i < playerList.length; i++) {
            Player storage currentPlayer = players[playerList[i]];
            (uint256 playersEarnings, uint256 principal) = calculateRewards(playerList[i]);
            currentPlayer.lastUpdated = block.timestamp;
            currentPlayer.deposit = principal;
            currentPlayer.earnings += playersEarnings;
        }

        // Adjust the earnings rate, either increasing it or decreasing it by 20%
        earningsRate = _increase ? (earningsRate * 120) / 100 : (earningsRate * 80) / 100;

        // Update the total invested amount and the contract balance
        totalInvested += fee - fee / 5;
        updateContractBalance();

        return (earningsRate, previousBalance, newBalance);
    }

    // Checks whether it's claim day, which is a 24-hour period that occurs every 7 days
    function isClaimDay() public view returns (bool) {
        uint256 timeSinceLaunch = block.timestamp - contractLaunchTime;
        return timeSinceLaunch >= CLAIM_INTERVAL && timeSinceLaunch % CLAIM_INTERVAL < CLAIM_DURATION;
    }

    // Allows a player to claim their earnings as a reward, with an option to tip the developer a percentage of the earnings
    function claimRewards(bool _tip) external returns ( uint256 paidRewards, uint256 principalBal, uint256 claimed ){
        // Access the player's information
        Player storage player = players[msg.sender];

        // Calculate the player's earnings and principal
        (uint256 playersEarnings, uint256 principal) = calculateRewards(msg.sender);
        player.deposit = principal;

        // Ensure it's claim day and the player has earnings to claim
        require(isClaimDay() && playersEarnings > 0, "error");

        // Reset the player's earnings and update the time of their last update and claim
        player.earnings = 0;
        player.lastUpdated = block.timestamp;
        player.lastClaimed = block.timestamp;

        // If the player has chosen to tip the developer, calculate the tip amount and transfer it to the marketing wallet
        if (_tip) {
            uint256 tipAmount = (playersEarnings * 5) / 100;
            playersEarnings -= tipAmount;
            usdt.transfer(marketing, tipAmount);
        }

        // Ensure the player's total claimed amount does not exceed their maximum payout
        if (player.totalClaimed + playersEarnings >= player.maxPayout) {
            playersEarnings = player.maxPayout - player.totalClaimed;
        }
        
        // Update the player's total claimed amount
        player.totalClaimed += playersEarnings;

        // If it's the end of the current claim day, move the rebalance reward pool to the contest reward for the current day
        uint256 currentDay = (block.timestamp - contractLaunchTime) / CLAIM_INTERVAL;
        if (block.timestamp >= contractLaunchTime + (currentDay + 1) * CLAIM_INTERVAL) {
            contests[currentDay].reward = rebalanceRewardPool;
            rebalanceRewardPool = 0;
        }

        // Transfer the player's earnings to them and update the contract balance
        usdt.transfer(msg.sender, playersEarnings); 
        updateContractBalance();

        return (playersEarnings, player.deposit, player.totalClaimed);
    }

    // Allows the top depositor of a day to claim their prize, if it has not been claimed already. This can only be done on claim day.
    function claimPrize(uint256 day) external { 
        // Access the contest information for the specified day
        Contest storage contest = contests[day];
        
        // Calculate the current day
        uint256 currentDay = (block.timestamp - contractLaunchTime) / CLAIM_INTERVAL;
        
        // Ensure the caller was the top depositor for the specified day, the prize has not already been claimed, and the day is in the past
        require(msg.sender == contest.topDepositor && !contest.claimed && day < currentDay, "error");
        
        // Mark the prize as claimed and calculate the reward amount
        contest.claimed = true;
        contest.reward = rebalanceRewardPool / 2;
        
        // Transfer the reward to the top depositor
        usdt.transfer(contest.topDepositor, contest.reward);
    }

    // Returns the remaining time of the current claim day in seconds
    function claimDayTimeRemaining() public view returns (uint) {
        uint256 timeSinceLaunch = block.timestamp - contractLaunchTime;
        if (timeSinceLaunch >= CLAIM_INTERVAL && timeSinceLaunch % CLAIM_INTERVAL < CLAIM_DURATION) {
            return CLAIM_DURATION - (timeSinceLaunch % CLAIM_INTERVAL);
        } else {
            return 0;
        }
    }

    function returnList(uint256 num) public view returns (address[] memory) {
        return (num == 1) ? waitlist : ((num == 2) ? teamList : playerList);
    }
   
    // Calculates the net worth of a team by summing the deposits of all its members.
    function calculateTeamNetWorth(address _teamCreator) public view returns (uint256) {
        uint256 netWorth = 0;
        Team storage team = teams[_teamCreator];
        for (uint i = 0; i < team.members.length; i++) {
            netWorth += players[team.members[i]].deposit;
        }
        return netWorth;
    }

    // Returns the teams with the top three highest net worth.
    function getTopTeams() public view returns (address, address, address) {
        address top1;
        address top2;
        address top3;
        uint256 highestNetWorth1 = 0;
        uint256 highestNetWorth2 = 0;
        uint256 highestNetWorth3 = 0;

        // Iterate through all players
        for (uint i = 0; i < teamList.length; i++) {
            // We get the player's team
            address teamAddress = teamList[i];
            // Skip if player is not part of a team
            if(teamAddress == address(0)) continue;

            // We get the team's net worth
            uint256 netWorth = calculateTeamNetWorth(teamAddress);


            // Check if this team's net worth is higher than the highest so far
            if (netWorth > highestNetWorth1) {
                // Shift down the top 2 and 3 teams
                top3 = top2;
                highestNetWorth3 = highestNetWorth2;

                top2 = top1;
                highestNetWorth2 = highestNetWorth1;

                // New top 1 team
                top1 = teamAddress;
                highestNetWorth1 = netWorth;
            } 
            // Check if this team's net worth is higher than the second highest
            else if (netWorth > highestNetWorth2) {
                // Shift down the top 3 team
                top3 = top2;
                highestNetWorth3 = highestNetWorth2;

                // New top 2 team
                top2 = teamAddress;
                highestNetWorth2 = netWorth;
            } 
            // Check if this team's net worth is higher than the third highest
            else if (netWorth > highestNetWorth3) {
                // New top 3 team
                top3 = teamAddress;
                highestNetWorth3 = netWorth;
            }
        }

        return (top1, top2, top3);
    }

    // Allows players to vote for a reset of the game. If a majority of players vote for a reset, all player data is deleted and the game is restarted.
    function greatReset() public {
        Player storage player = players[msg.sender];
        require(block.timestamp >= contractLaunchTime + 30 days && !votes[msg.sender] && player.deposit > 10, "error");
        votes[msg.sender] = true;
        numVotes++;
        if (numVotes * 2 > playerList.length) {
            for (uint i=0; i<playerList.length; i++) {
                delete players[playerList[i]];
            }
            delete playerList; // Clears the entire array
            numVotes = 0; // Reset vote count
            for (uint i=0; i<playerList.length; i++) { // Reset votes mapping
                delete votes[playerList[i]];
            }
        }
        contractLaunchTime = block.timestamp;
        lastDepositTimestamp = block.timestamp;
        rebalanceRewardPool = 0;
        totalInvested = 0;
        globalPenalties = 0;
        globalReversals = 0;
        earningsRate = 300;
    }

    // Returns the timestamp of the next claim day.
    function getNextClaimDay() public view returns (uint256 nextClaimDay) {
        uint256 weeksSinceLaunch = (block.timestamp - contractLaunchTime) / CLAIM_INTERVAL;
        return contractLaunchTime + (weeksSinceLaunch + 1) * CLAIM_INTERVAL;
    }

    // Function to calculate the fee required to adjust the earnings rate
    function getAdjustEarningsRateFee(bool _increase) public view returns (uint256 priceDeposit, uint256 priceWallet){

        // Gets the current balance of the contract
        uint256 currentBalance = usdt.balanceOf(address(this));
        
        // Calculates the ratio of the current balance to the total invested, using basis points (0.01% increments)
        uint256 balanceRatio = (currentBalance * 10000) / totalInvested;
        
        uint256 fee; // Variable to hold the computed fee
        
        // Base fee is set to $100 in ether
        uint256 baseFee = 100 ether;

        // Checks if the earnings rate is being increased
        if (_increase) {
            // Fee is calculated as the base fee plus an additional variable portion. 
            // This portion is a function of the current balance, the earnings rate, and the balance to total invested ratio.
            fee = baseFee + ((currentBalance * (earningsRate + 10) * balanceRatio) /(10000 * 10000));
        } else {
            // If earnings rate is being decreased, the fee calculation changes.
            // The difference here is that the fee decreases with the balance ratio, unlike the increase scenario above.
            fee = baseFee + ((currentBalance *(earningsRate - 10) *(10000 - balanceRatio)) / (10000 * 10000));
        }
        
        // Returns the computed fee as the priceDeposit and 80% of the computed fee as the priceWallet
        return (fee, (fee * 80) / 100 );
    }

    // Check if the caller is part of one of the top three teams
    function isCallerFromTopTeam() public view returns(bool) {
        address top1;
        address top2;
        address top3;
        (top1, top2, top3) = getTopTeams();
        address callerTeam = players[msg.sender].team;
        return (callerTeam == top1 || callerTeam == top2 || callerTeam == top3);
    }

    // Top 3 teams are considered owners. Any member of any team can call this function to proportionately distribute rewards to team.
    function distributeOwnerProfits() public {
        require(!isClaimDay() && isCallerFromTopTeam(), "error");

        address callerTeam = players[msg.sender].team;
        uint256 poolToDistribute;

        (address top1, address top2, address top3) = getTopTeams();
        
        if (callerTeam == top1) {
            poolToDistribute = titansPool;
            titansTotalEarned += titansPool;
            titansPool = 0;
        } else if (callerTeam == top2) {
            poolToDistribute = giantsPool;
            giantsTotalEarned += giantsPool;
            giantsPool = 0;
        } else if (callerTeam == top3) {
            poolToDistribute = elitesPool;
            elitesTotalEarned += elitesPool;
            elitesPool = 0;
        }

        Team storage team = teams[callerTeam];
        uint256 totalNetWorth = calculateTeamNetWorth(callerTeam);
        for (uint i = 0; i < team.members.length; i++) {
            address member = team.members[i];
            uint256 memberDeposit = players[member].deposit;
            uint256 memberShare = (poolToDistribute * memberDeposit) / totalNetWorth;
            usdt.transfer(member, memberShare); 
        }
    }

   function addToMyTeam(address playerAddress) public {
        Player storage player = players[playerAddress];

        // Check the player is not already a member of another team
        require(player.team == address(0) && teams[msg.sender].members.length < 20, "error");

        // Check if player is in the waitlist
        uint256 waitlistLength = waitlist.length;
        for (uint i = 0; i < waitlistLength; i++) {
            if (waitlist[i] == playerAddress) {
                // Swap player with the last element and remove it
                waitlist[i] = waitlist[waitlistLength - 1];
                waitlist.pop();

                // Add player to team
                teams[msg.sender].members.push(playerAddress);
                player.team = msg.sender;
                return;
            }
        }
        revert("Player is not in the waitlist.");
    }


    // Helper function
    function findMemberIndex(address target, Team storage team) internal view returns (bool, uint) {
        for (uint i = 0; i < team.members.length; i++) {
            if (team.members[i] == target) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    // Allow team creators to remove team members, transfer ownership of teams, rename teams.
    function teamOperation(TeamAction action, address target, string memory newName) public {
        Player storage player = players[msg.sender];
        require(player.team == msg.sender && bytes(newName).length > 0, "error");

        Team storage team = teams[player.team];
        bool isMember;
        uint256 memberIndex;

        if (action == TeamAction.RemoveMember) {
            (isMember, memberIndex) = findMemberIndex(target, team);
            require(target != msg.sender && isMember, "error");
            
            players[target].team = address(0);
            
            team.members[memberIndex] = team.members[team.members.length - 1];
            team.members.pop();
        } 
        else if (action == TeamAction.TransferOwnership) {
            (isMember, ) = findMemberIndex(target, team);
            require(target != msg.sender && isMember, "error");
            
            // Transfer ownership
            team.creator = target;
        } 
        else if (action == TeamAction.RenameTeam) {
            // Change the team name
            team.name = newName;
        }
    }

}
