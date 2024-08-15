/**
 *Submitted for verification at BscScan.com on 2024-08-12
 */

// SPDX-License-Identifier: MIT

//A project of Coinadzz Team for Coidadzz Community
//Check future projects @ https://coinadzz.com/ est 2021

pragma solidity 0.8.24;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract UltimateBakedBeans is Ownable, ReentrancyGuard {
    uint256 private constant BEANS_TO_HATCH_1BEAN = 1080000;
    uint256 private constant PSN = 10000;
    uint256 private constant PSNH = 5000;
    uint256 private constant FEE_PERCENT = 10;
    uint256 private constant SELL_FEES = 10;
    uint256 private constant MAX_WITHDRAW_MULTIPLIER = 2;
    uint256 private constant WEEK_DURATION = 259200;
    uint256[4] private refLevelRewards = [500, 300, 200, 100];
    uint256[4] private weeklyTopPercentages = [400, 300, 200, 100];
    uint256 private weekRewardPercentage = 10;
    bool private initialized = false;
    address payable private marketingAddress;
    address payable private teamAddress;
    mapping(address => uint256) public userClaims;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) private hatcheryMiners;
    mapping(address => uint256) private claimedEggs;
    mapping(address => uint256) public lastHatch;
    mapping(address => uint256) public lastDeposit;
    mapping(address => uint256) public userPendings;
    uint256 private marketEggs;
    uint256 public totalDeposits;

    struct DepositInfo {
        address user;
        uint256 amount;
        uint256 rewardAmount;
    }

    uint256 public weekStartTime;
    uint256 public weekCount;

    mapping(uint256 => mapping(address => uint256)) public userWeeklyDeposits;
    mapping(uint => DepositInfo[4]) public weeklyWinners;
    mapping(uint => uint) public weeklyInvestment;

    struct Account {
        address referrer;
        uint256 reward;
        uint256 referredCount;
        uint256[4] levelRefCount;
    }
    mapping(address => Account) public accounts;

    event ClaimedTopReward(address user, uint256 amount, uint256 time);
    event RegisteredReferrer(address referee, address referrer);
    event RegisteredReferrerFailed(
        address referee,
        address referrer,
        string reason
    );
    event PaidReferral(address from, address to, uint256 amount);
    event EggsHatched(
        address indexed user,
        address indexed referrer,
        uint256 eggsUsed,
        uint256 eggValue,
        uint256 newMiners
    );
    event EggsSold(
        address indexed user,
        uint256 eggsSold,
        uint256 eggValue,
        uint256 newMiners,
        uint256 timestamp
    );
    event EggsBought(
        address indexed user,
        address indexed referrer,
        uint256 amountSpent,
        uint256 eggsBought,
        uint256 newMiners,
        uint256 timestamp
    );
    event MarketSeeded(
        address indexed marketingAddress,
        address indexed teamAddress,
        uint256 marketEggs,
        uint256 timestamp
    );

    receive() external payable {}

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function hatchEggs(address ref) public nonReentrant {
        require(initialized, "Contract not initialized");
        require(block.timestamp > lastHatch[msg.sender] + 3600, "Please wait");

        if (!hasReferrer(msg.sender) && userDeposits[ref] > 0) {
            addReferrer(ref);
        }

        address referrer = accounts[msg.sender].referrer;
        uint256 eggsUsed = getMyEggs(msg.sender);
        uint256 eggValue = calculateEggSell(eggsUsed);

        uint256 marketingFee = (eggValue * 2) / 100;
        (bool success, ) = marketingAddress.call{value: marketingFee}("");
        require(success, "Transfer failed");

        uint256 newMiners = eggsUsed / BEANS_TO_HATCH_1BEAN;
        hatcheryMiners[msg.sender] += newMiners;
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        userDeposits[msg.sender] += eggValue;

        claimedEggs[referrer] += eggsUsed / 100;
        marketEggs += eggsUsed / 5;

        emit EggsHatched(msg.sender, referrer, eggsUsed, eggValue, newMiners);
    }

    function sellEggs() public nonReentrant {
        require(initialized, "Contract not initialized");

        uint256 hasEggs = getMyEggs(msg.sender);
        uint256 eggValue = calculateEggSell(hasEggs);
        uint256 maxLimit = userDeposits[msg.sender] * MAX_WITHDRAW_MULTIPLIER;

        if (userClaims[msg.sender] + eggValue >= maxLimit) {
            eggValue = maxLimit > userClaims[msg.sender]
                ? maxLimit - userClaims[msg.sender]
                : 0;
        }

        require(eggValue > 0, "No withdrawal amount available");

        userClaims[msg.sender] += eggValue;
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs += hasEggs;

        uint256 newMiners = hasEggs / BEANS_TO_HATCH_1BEAN;
        uint256 feesBeans = (newMiners * SELL_FEES) / 100;
        hatcheryMiners[msg.sender] -= feesBeans;

        (bool success, ) = msg.sender.call{value: eggValue}("");
        require(success, "Transfer failed");

        emit EggsSold(
            msg.sender,
            hasEggs,
            eggValue,
            newMiners,
            block.timestamp
        );
    }

    function buyEggs(address ref) public payable nonReentrant {
        require(initialized, "Contract not initialized");
        require(block.timestamp > lastDeposit[msg.sender] + 60, "Please wait");

        uint amount = msg.value;
        require(amount > 0, "Amount must be greater than zero");

        uint cbalance = address(this).balance;
        require(
            amount < (cbalance * 15) / 100,
            "Exceeds 15% of contract balance"
        );

        distributeWeeklyRewards();

        totalDeposits += amount;
        userDeposits[msg.sender] += amount;

        uint256 eggsBought = calculateEggBuy(amount, cbalance - amount);
        eggsBought -= devFee(eggsBought);

        teamAddress.transfer((amount * 5) / 100);
        marketingAddress.transfer((amount * 5) / 100);

        claimedEggs[msg.sender] += eggsBought;

        uint256 eggsUsed = getMyEggs(msg.sender);
        uint256 newMiners = eggsUsed / BEANS_TO_HATCH_1BEAN;

        hatcheryMiners[msg.sender] += newMiners;
        claimedEggs[msg.sender] = 0;
        lastDeposit[msg.sender] = block.timestamp;
        lastHatch[msg.sender] = block.timestamp;

        if (!hasReferrer(msg.sender)) {
            addReferrer(ref);
        }

        payReferral(eggsBought, amount);
        addWeeklyDeposits(msg.sender, amount);
        weeklyInvestment[weekCount] += amount;

        marketEggs += eggsUsed / 5;

        emit EggsBought(
            msg.sender,
            ref,
            amount,
            eggsBought,
            newMiners,
            block.timestamp
        );
    }

    function payReferral(uint256 value, uint256 _amount) internal {
        Account memory userAccount = accounts[msg.sender];

        for (uint256 i = 0; i < 4; i++) {
            address parent = userAccount.referrer;
            Account storage parentAccount = accounts[parent];

            if (parent == address(0)) {
                break;
            }

            uint256 c = (value * refLevelRewards[i]) / 10000;

            parentAccount.reward += c;
            accounts[parent].levelRefCount[i] += 1;
            claimedEggs[parent] += c;

            emit PaidReferral(msg.sender, parent, c);

            userAccount = parentAccount;

            if (i == 0) addWeeklyDeposits(parent, _amount);
        }
    }

    function beanRewards(address adr) public view returns (uint256) {
        uint256 hasEggs = getMyEggs(adr);
        if (hasEggs == 0) {
            return 0;
        }
        uint256 eggValue = calculateEggSell(hasEggs);
        return eggValue;
    }

    function getBNBDeposited(address adr) public view returns (uint256) {
        return userDeposits[adr];
    }

    function getBNBClaimed(address adr) public view returns (uint256) {
        return userClaims[adr];
    }

    function calculateTrade(
        uint256 rt,
        uint256 rs,
        uint256 bs
    ) private pure returns (uint256) {
        uint256 numerator = PSN * bs;
        uint256 denominator = PSNH + ((PSN * rs) + (PSNH * rt)) / rt;
        return numerator / denominator;
    }

    function calculateEggSell(uint256 eggs) public view returns (uint256) {
        return calculateTrade(eggs, marketEggs, address(this).balance);
    }

    function calculateEggBuy(
        uint256 eth,
        uint256 contractBalance
    ) public view returns (uint256) {
        return calculateTrade(eth, contractBalance, marketEggs);
    }

    function calculateEggBuySimple(uint256 eth) public view returns (uint256) {
        return calculateEggBuy(eth, address(this).balance);
    }

    function devFee(uint256 amount) private pure returns (uint256) {
        return (amount * FEE_PERCENT) / 100;
    }

    function seedMarket(
        address payable _marketingAddress,
        address payable _teamAddress
    ) public payable onlyOwner {
        require(marketEggs == 0, "Market already seeded");
        require(
            !isContract(_marketingAddress) && !isContract(_teamAddress),
            "Marketing and Team address cannot be a contract"
        );
        require(
            _marketingAddress != address(0) && _teamAddress != address(0),
            "Invalid addresses"
        );
        initialized = true;
        marketEggs = 108000000000;
        teamAddress = payable(_teamAddress);
        marketingAddress = payable(_marketingAddress);
        weekStartTime = block.timestamp;
        weekCount = 1;
        emit MarketSeeded(
            _marketingAddress,
            _teamAddress,
            marketEggs,
            block.timestamp
        );
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getMyMiners(address adr) public view returns (uint256) {
        return hatcheryMiners[adr];
    }

    function getMyEggs(address adr) public view returns (uint256) {
        return claimedEggs[adr] + getEggsSinceLastHatch(adr);
    }

    function getEggsSinceLastHatch(address adr) public view returns (uint256) {
        uint256 secondsPassed = min(
            BEANS_TO_HATCH_1BEAN,
            block.timestamp - lastHatch[adr]
        );
        return secondsPassed * hatcheryMiners[adr];
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function addWeeklyDeposits(address _user, uint _amount) internal {
        // Update the deposit amount for the user
        userWeeklyDeposits[weekCount][_user] += _amount;

        // Check if the new total deposit is among the top 4 for the week
        DepositInfo[4] storage topDepositors = weeklyWinners[weekCount];
        uint256 newAmount = userWeeklyDeposits[weekCount][_user];

        // Check if the user is already in the top 4
        bool updated = false;
        for (uint256 i = 0; i < topDepositors.length; i++) {
            if (topDepositors[i].user == _user) {
                // Update the amount
                topDepositors[i].amount = newAmount;
                updated = true;
                break;
            }
        }

        // If not updated, check if it should be inserted
        if (!updated) {
            for (uint256 i = 0; i < topDepositors.length; i++) {
                if (newAmount > topDepositors[i].amount) {
                    // Shift down the lower depositors
                    for (uint256 j = topDepositors.length - 1; j > i; j--) {
                        topDepositors[j] = topDepositors[j - 1];
                    }
                    // Insert the new depositor
                    topDepositors[i] = DepositInfo(_user, newAmount, 0);
                    break;
                }
            }
        }

        // Ensure the top 4 list is sorted by amount in descending order
        sortTopDepositors(topDepositors);
    }

    // Helper function to sort the top 4 depositors in descending order
    function sortTopDepositors(DepositInfo[4] storage topDepositors) internal {
        for (uint256 i = 0; i < topDepositors.length - 1; i++) {
            for (uint256 j = 0; j < topDepositors.length - i - 1; j++) {
                if (topDepositors[j].amount < topDepositors[j + 1].amount) {
                    DepositInfo memory temp = topDepositors[j];
                    topDepositors[j] = topDepositors[j + 1];
                    topDepositors[j + 1] = temp;
                }
            }
        }
    }

    function distributeWeeklyRewards() internal {
        if (block.timestamp >= weekStartTime + WEEK_DURATION) {
            uint256 currentWeek = weekCount;
            uint256 reward = (weeklyInvestment[currentWeek] *
                weekRewardPercentage) / 1000;

            for (uint256 i = 0; i < 4; i++) {
                if (weeklyWinners[currentWeek][i].user != address(0)) {
                    uint256 individualReward = (reward *
                        weeklyTopPercentages[i]) / 1000;
                    weeklyWinners[currentWeek][i]
                        .rewardAmount += individualReward;
                    userPendings[
                        weeklyWinners[currentWeek][i].user
                    ] += individualReward;
                }
            }

            weekStartTime = block.timestamp;
            weekCount += 1;
            weeklyInvestment[weekCount] = 0;
        }
    }

    function WeeklyTopUser(
        uint _weekNo
    ) public view returns (DepositInfo[4] memory) {
        return weeklyWinners[_weekNo];
    }

    function getLevelRefCount(
        address _user
    ) public view returns (uint256[4] memory) {
        return accounts[_user].levelRefCount;
    }

    function claimTopReward() public nonReentrant {
        uint256 pendingReward = userPendings[msg.sender];
        require(pendingReward > 0, "No reward to claim");
        require(
            userDeposits[msg.sender] * MAX_WITHDRAW_MULTIPLIER >
                userClaims[msg.sender],
            "User reached max withdraw limit"
        );

        userPendings[msg.sender] = 0;
        userClaims[msg.sender] += pendingReward;

        (bool success, ) = msg.sender.call{value: pendingReward}("");
        require(success, "Transfer failed");

        emit ClaimedTopReward(msg.sender, pendingReward, block.timestamp);
    }

    function hasReferrer(address addr) public view returns (bool) {
        return accounts[addr].referrer != address(0);
    }

    function isCircularReference(
        address referrer,
        address referee
    ) internal view returns (bool) {
        address parent = referrer;

        for (uint256 i; i < 4; i++) {
            if (parent == address(0)) {
                break;
            }

            if (parent == referee) {
                return true;
            }

            parent = accounts[parent].referrer;
        }

        return false;
    }

    function addReferrer(address referrer) internal returns (bool) {
        if (referrer == address(0)) {
            emit RegisteredReferrerFailed(
                msg.sender,
                referrer,
                "Referrer cannot be 0x0 address"
            );
            return false;
        } else if (isCircularReference(referrer, msg.sender)) {
            emit RegisteredReferrerFailed(
                msg.sender,
                referrer,
                "Referee cannot be one of referrer uplines"
            );
            return false;
        } else if (accounts[msg.sender].referrer != address(0)) {
            emit RegisteredReferrerFailed(
                msg.sender,
                referrer,
                "Address already has referrer"
            );
            return false;
        } else if (userDeposits[referrer] == 0) {
            emit RegisteredReferrerFailed(
                msg.sender,
                referrer,
                "Referrer must have a non-zero deposit"
            );
            return false;
        }

        Account storage userAccount = accounts[msg.sender];
        Account storage parentAccount = accounts[referrer];

        userAccount.referrer = referrer;
        parentAccount.referredCount += 1;

        emit RegisteredReferrer(msg.sender, referrer);
        return true;
    }

    // Safe Math Functions
    function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }

    function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
}
