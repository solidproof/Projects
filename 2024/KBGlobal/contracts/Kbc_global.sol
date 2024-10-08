// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address _owner,
        address spender
    ) external view returns (uint256);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function freezeToken(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function unfreezeToken(address account) external returns (bool);

    function mint(address _to, uint256 amount) external returns (bool);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Unfreeze(
        address indexed _unfreezer,
        address indexed _to,
        uint256 _amount
    );
}

contract KBC_GLOBAL {
    address public ownerWallet;
    uint public currUserID = 0;
    uint public currRound = 0;
    address public roundCloser;
    uint public currRoundStartTime = 0;
    uint public startTime = 0;
    uint public level_income = 0;
    uint public globalPool = 0;
    uint public insurancePool = 0;
    //uint public KbcPrice;
    bool public InsurancePoolActive;
    address public pricePool;
    //
    struct UserStruct {
        bool isExist;
        uint id;
        uint referrerID;
        uint stakedKBC;
        uint atPrice;
        uint referredUsers;
        uint income;
        uint rootBalance;
        uint capping;
        uint levelIncomeReceived;
        uint takenROI;
        uint256 stakeTimes;
        mapping(uint => uint) levelExpired;
        uint incomeMissed;
    }

    struct RankStruct {
        uint starOne;
        uint starTwo;
        uint starThree;
        uint starFour;
        uint starFive;
        uint starSix;
        uint starSeven;
        bool starOnePaid;
        bool starTwoPaid;
        bool starThreePaid;
        bool starFourPaid;
        bool starFivePaid;
        bool starSixPaid;
        bool starSevenPaid;
    }

    struct LevelStruct {
        uint two;
        uint three;
        uint four;
        uint five;
        uint six;
        uint seven;
        uint eight;
        uint nine;
        uint ten;
        uint eleven;
        uint twelve;
        uint thirteen;
        uint forteen;
        uint fifteen;
    }

    struct LevelIncomeStruct {
        uint two;
        uint three;
        uint four;
        uint five;
        uint six;
        uint seven;
        uint eight;
        uint nine;
        uint ten;
        uint eleven;
        uint twelve;
        uint thirteen;
        uint forteen;
        uint fifteen;
    }

    struct IncomeStruct {
        uint directIncome;
        uint onTeamROI;
        uint top4Income;
        uint totalIncome;
        uint takenIncome;
        uint balanceIncome;
    }

    struct TurnOverStruct {
        uint two;
        uint three;
        uint four;
        uint five;
        uint six;
        uint seven;
        uint eight;
        uint nine;
        uint ten;
        uint eleven;
        uint twelve;
        uint thirteen;
        uint forteen;
        uint fifteen;
    }
    struct ReportStructUSDT {
        uint firstTOUSDT;
        uint secondTOUSDT;
        uint thirdTOUSDT;
        uint fourthTOUSDT;
        address firstUSDT;
        address secondUSDT;
        address thirdUSDT;
        address fourthUSDT;
        uint top4PoolForwardedUSDT;
        uint top4PoolUSDT;
        uint top4Pool2DistributeUSDT;
        uint actualTOUSDT;
        uint atPrice;
    }

    struct DailyStruct {
        uint time;
        uint myTO;
        uint winAmount;
    }
    // USERS
    mapping(address => UserStruct) public users;
    mapping(address => IncomeStruct) public income;
    mapping(address => uint256) public directROIIncome;
    //mapping(uint => ReportStruct) public reports;
    mapping(uint => ReportStructUSDT) public reportsUSDT;

    mapping(uint => address) public userList;
    mapping(uint => uint) public LEVEL_PRICE;
    mapping(address => LevelStruct) public levels;
    mapping(address => LevelIncomeStruct) public levelsIncome;
    mapping(address => uint256) public stakedUSDT;
    mapping(address => uint256) public regTime;
    mapping(address => uint256) public missedIncomeAmount;
    mapping(address => uint256) public userTeamSize;
    mapping(address => uint256) public totalTaken;
    mapping(address => RankStruct) public ranks;
    mapping(address => uint256) public totalDeposit;
    mapping(address => uint256) public userTurnOver;
    mapping(address => uint256) public topUpTime;
    mapping(uint256 => mapping(address => DailyStruct)) public dailyUserTO;
    mapping(address => uint256) public lastTopup;
    mapping(address => TurnOverStruct) public turnOver;
    IBEP20 token;
    IBEP20 public stableCoin;
    IBEP20 public wBNB;

    bool ownerPaid;
    // Events
    event SponsorIncome(
        address indexed _user,
        address indexed _referrer,
        uint _time
    );
    event toInsurancePool(address indexed _user, uint _amount, uint _time);
    event toGlobalPool(address indexed _user, uint _amount, uint _time);
    event toAdmin(address indexed _user, uint _amount, uint _time);
    event WithdrawROI(address indexed user, uint256 reward);
    event WithdrawStable(address sender, address _to, uint256 amount);
    event SendBalance(address indexed user, uint256 amount);
    event LevelsIncome(
        address indexed _user,
        address indexed _referral,
        uint indexed _level,
        uint _amount,
        uint _time
    );
    event WithdrawalCoin(
        address sender,
        address _to,
        uint256 amount,
        string widrwalType
    );
    event DepositKBC(address _user, uint _amount, uint _time);
    event fundGlobal(address _user, uint _amount, uint _time);
    event WithdrawReward(address indexed user, uint256 reward);
    event fundInsurance(address _user, uint _amount, uint _time);
    event top4winners(
        uint Round,
        uint first,
        uint second,
        uint third,
        uint fourth
    );
    event IncomeWithdrawn(address indexed sender, uint256 amount, uint256 now);
    event LevelsIncome(
        address indexed _user,
        address indexed _referral,
        uint indexed _level,
        uint _time
    );
    event TopUp(address indexed sender, uint256 amount, uint256 now);

    UserStruct[] private requests;

    constructor(address _usdt, address _wbnb, address _liqPool) {
        ownerWallet = msg.sender;
        currUserID++;
        currRound++;
        users[ownerWallet].isExist = true;
        users[ownerWallet].id = currUserID;
        regTime[ownerWallet] = block.timestamp;
        startTime = block.timestamp;
        currRoundStartTime = block.timestamp;
        userList[currUserID] = ownerWallet;
        roundCloser = ownerWallet;
        stableCoin = IBEP20(_usdt);
        wBNB = IBEP20(_wbnb);
        pricePool = _liqPool;
    }

    modifier onlyOwner() {
        require(
            msg.sender == ownerWallet,
            "Only Owner can access this function."
        );
        _;
    }

    function Registration(uint _referrerID) public payable {
        require(!users[msg.sender].isExist, "User Exists");
        require(
            _referrerID > 0 && _referrerID <= currUserID,
            "Incorrect referral ID"
        );
        require(InsurancePoolActive == false, "Project closed");

        uint usdtPrice = ((wBNB.balanceOf(pricePool) * 1e18) /
            stableCoin.balanceOf(pricePool));
        require(
            msg.value >= usdtPrice * 100,
            "Value must be Greater then 100 USDT"
        );

        uint _amount = ((msg.value * 1e18) / usdtPrice);

        currUserID++;
        users[msg.sender].isExist = true;
        users[msg.sender].id = currUserID;
        users[msg.sender].referrerID = _referrerID;
        users[msg.sender].stakedKBC = msg.value;
        lastTopup[msg.sender] = _amount;
        userList[currUserID] = msg.sender;
        regTime[msg.sender] = block.timestamp;
        topUpTime[msg.sender] = block.timestamp;
        stakedUSDT[msg.sender] = _amount;
        totalDeposit[msg.sender] = _amount;

        income[userList[_referrerID]].directIncome += _amount / 20;
        income[userList[_referrerID]].totalIncome += _amount / 20;
        income[userList[_referrerID]].balanceIncome += _amount / 20;
        payable(ownerWallet).transfer(msg.value / 50);

        globalPool += (msg.value * 93) / 100;
        insurancePool += (msg.value * 5) / 100;

        reportsUSDT[currRound].actualTOUSDT += _amount;
        reportsUSDT[currRound].top4PoolUSDT += (_amount * 3) / 100;

        users[msg.sender].stakeTimes = block.timestamp;
        users[userList[users[msg.sender].referrerID]].referredUsers =
            users[userList[users[msg.sender].referrerID]].referredUsers +
            1;
        users[msg.sender].atPrice = usdtPrice;
        users[msg.sender].rootBalance += _amount * 3;
        users[msg.sender].capping += _amount * 3;

        addTeam(1, msg.sender, _amount);

        emit SponsorIncome(msg.sender, userList[_referrerID], block.timestamp);
        //emit toInsurancePool(msg.sender, msg.value / 10, block.timestamp);
        //emit toGlobalPool(msg.sender, (msg.value * 80) / 100, block.timestamp);
        //emit toAdmin(msg.sender, msg.value / 50, block.timestamp);

        top4PoolDistribution(_referrerID, _amount);
    }

    function addTeam(uint _level, address _user, uint _amount) internal {
        address referer;
        referer = userList[users[_user].referrerID];
        //bool sent = false;
        //uint level_price_local = 0;
        // Condition of level from 1- 1o and number of reffered user

        if (_level == 2) {
            levels[referer].two += 1;
            turnOver[referer].two += _amount;
        } else if (_level == 3) {
            levels[referer].three += 1;
            turnOver[referer].three += _amount;
        } else if (_level == 4) {
            levels[referer].four += 1;
            turnOver[referer].four += _amount;
        } else if (_level == 5) {
            levels[referer].five += 1;
            turnOver[referer].five += _amount;
        } else if (_level == 6) {
            levels[referer].six += 1;
            turnOver[referer].six += _amount;
        } else if (_level == 7) {
            levels[referer].seven += 1;
            turnOver[referer].seven += _amount;
        } else if (_level == 8) {
            levels[referer].eight += 1;
            turnOver[referer].eight += _amount;
        } else if (_level == 9) {
            levels[referer].nine += 1;
            turnOver[referer].nine += _amount;
        } else if (_level == 10) {
            levels[referer].ten += 1;
            turnOver[referer].ten += _amount;
        } else if (_level == 11) {
            levels[referer].eleven += 1;
            turnOver[referer].eleven += _amount;
        } else if (_level == 12) {
            levels[referer].twelve += 1;
            turnOver[referer].twelve += _amount;
        } else if (_level == 13) {
            levels[referer].thirteen += 1;
            turnOver[referer].thirteen += _amount;
        } else if (_level == 14) {
            levels[referer].forteen += 1;
            turnOver[referer].forteen += _amount;
        } else if (_level == 15) {
            levels[referer].fifteen += 1;
            turnOver[referer].fifteen += _amount;
        }
        userTurnOver[referer] += _amount;
        userTeamSize[referer] += 1;
        //(bool sent, ) = payable(referer).call{value: level_price_local}("");
        //globalPool -= level_price_local;
        //sent = stableCoin.transfer(address(uint160(referer)),level_price_local);

        //if (sent) {
        //emit LevelsIncome(referer, msg.sender, _level, block.timestamp);
        if (_level < 15 && users[referer].referrerID >= 1) {
            addTeam(_level + 1, referer, _amount);
            // } else {}
        }
        //if (!sent) {
        //payReferral(_level, referer, _value);
        //}
    }

    function payReferral(uint _level, address _user, uint reward) internal {
        address referer;
        referer = userList[users[_user].referrerID];
        //bool sent = false;
        uint level_price_local = 0;
        // Condition of level from 1- 1o and number of reffered user
        if (_level == 1 && users[referer].referredUsers >= 1) {
            level_price_local = (reward * 30) / 100;
            directROIIncome[referer] += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 2 && users[referer].referredUsers >= 2) {
            level_price_local = (reward * 10) / 100;
            levelsIncome[referer].two += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 3 && users[referer].referredUsers >= 3) {
            level_price_local = (reward * 8) / 100;
            levelsIncome[referer].three += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 4 && users[referer].referredUsers >= 4) {
            level_price_local = (reward * 6) / 100;
            levelsIncome[referer].four += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 5 && users[referer].referredUsers >= 5) {
            level_price_local = (reward * 6) / 100;
            levelsIncome[referer].five += level_price_local;
        } else if (_level == 6 && users[referer].referredUsers >= 6) {
            level_price_local = (reward * 5) / 100;
            levelsIncome[referer].six += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 7 && users[referer].referredUsers >= 7) {
            level_price_local = (reward * 5) / 100;
            levelsIncome[referer].seven += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 8 && users[referer].referredUsers >= 8) {
            level_price_local = (reward * 4) / 100;
            levelsIncome[referer].eight += level_price_local;
        } else if (_level == 9 && users[referer].referredUsers >= 9) {
            level_price_local = (reward * 4) / 100;
            levelsIncome[referer].nine += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 10 && users[referer].referredUsers >= 10) {
            level_price_local = (reward * 3) / 100;
            levelsIncome[referer].ten += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 11 && users[referer].referredUsers >= 11) {
            level_price_local = (reward * 3) / 100;
            levelsIncome[referer].eleven += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 12 && users[referer].referredUsers >= 12) {
            level_price_local = (reward * 2) / 100;
            levelsIncome[referer].twelve += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 13 && users[referer].referredUsers >= 13) {
            level_price_local = (reward * 2) / 100;
            levelsIncome[referer].thirteen += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else if (_level == 14 && users[referer].referredUsers >= 14) {
            level_price_local = reward / 100;
            levelsIncome[referer].forteen += level_price_local;
        } else if (_level == 15 && users[referer].referredUsers >= 15) {
            level_price_local = reward / 100;
            levelsIncome[referer].fifteen += level_price_local;
            //income[referer].onTeamROI += level_price_local;
        } else {
            users[referer].incomeMissed++;
            //level_price_local = (reward * 2) / 100;
            missedIncomeAmount[referer] += level_price_local;
        }

        //(bool sent, ) = payable(referer).call{value: level_price_local}("");
        //globalPool -= level_price_local;
        //sent = stableCoin.transfer(address(uint160(referer)),level_price_local);

        users[referer].levelIncomeReceived =
            users[referer].levelIncomeReceived +
            1;
        users[userList[users[_user].referrerID]].income += level_price_local;
        income[userList[users[_user].referrerID]]
            .onTeamROI += level_price_local;
        income[userList[users[_user].referrerID]]
            .totalIncome += level_price_local;
        income[userList[users[_user].referrerID]]
            .balanceIncome += level_price_local;

        //if (sent) {
        emit LevelsIncome(referer, msg.sender, _level, block.timestamp);
        if (_level < 15 && users[referer].referrerID >= 1) {
            payReferral(_level + 1, referer, reward);
            // } else {}
        }
        //if (!sent) {
        //payReferral(_level, referer, _value);
        //}
    }

    function topUp() public payable {
        require(users[msg.sender].isExist, "User not Exists");
        uint usdtPrice = ((wBNB.balanceOf(pricePool) * 1e18) /
            stableCoin.balanceOf(pricePool));
        uint Kbc_Price = ((stableCoin.balanceOf(pricePool) * 1e18) /
            wBNB.balanceOf(pricePool));
        require(
            msg.value >= (lastTopup[msg.sender] * 1e18) / Kbc_Price,
            "Value must be Greater then last topup"
        );
        uint _amount = ((msg.value * 1e18) / usdtPrice);
        require(stakedUSDT[msg.sender] == 0, "first withdraw your ROI");
        require(InsurancePoolActive == false, "Project closed");

        lastTopup[msg.sender] = _amount;
        stakedUSDT[msg.sender] = _amount;
        totalDeposit[msg.sender] += _amount;
        users[msg.sender].capping += _amount * 3;
        users[msg.sender].rootBalance += _amount * 3;
        users[msg.sender].stakeTimes = block.timestamp;
        users[msg.sender].atPrice = Kbc_Price;

        users[msg.sender].stakedKBC += msg.value;

        //payable(userList[_referrerID]).transfer(msg.value / 20);
        income[userList[users[msg.sender].referrerID]].directIncome +=
            _amount /
            20;
        income[userList[users[msg.sender].referrerID]].totalIncome +=
            _amount /
            20;
        income[userList[users[msg.sender].referrerID]].balanceIncome +=
            _amount /
            20;

        payable(ownerWallet).transfer(msg.value / 50);
        globalPool += (msg.value * 93) / 100;
        insurancePool += (msg.value * 5) / 100;

        reportsUSDT[currRound].actualTOUSDT += _amount;
        reportsUSDT[currRound].top4PoolUSDT += (_amount * 3) / 100;
        //reportsUSDT[currRound].top4Pool2DistributeUSDT = reportsUSDT[currRound].top4PoolUSDT / 4;

        //send reward to admin till the time of new user registration

        //payReferral(1, msg.sender, _amount);

        //emit toInsurancePool(msg.sender, msg.value / 10, block.timestamp);
        //emit toGlobalPool(msg.sender, msg.value * 88 / 100, block.timestamp);
        emit toAdmin(msg.sender, msg.value / 50, block.timestamp);
        uint _referrerID = users[msg.sender].referrerID;
        top4PoolDistribution(_referrerID, _amount);
        addTO(1, msg.sender, _amount);
        //emit TopUp(msg.sender, _amount, block.timestamp);
    }

    function addTO(uint _level, address _user, uint _amount) internal {
        address referer;
        referer = userList[users[_user].referrerID];
        //bool sent = false;
        //uint level_price_local = 0;
        // Condition of level from 1- 1o and number of reffered user

       
            //levels[referer].fifteen += 1;
         
        userTurnOver[referer] += _amount;
        //userTeamSize[referer] += 1;
        //(bool sent, ) = payable(referer).call{value: level_price_local}("");
        //globalPool -= level_price_local;
        //sent = stableCoin.transfer(address(uint160(referer)),level_price_local);

        //if (sent) {
        //emit LevelsIncome(referer, msg.sender, _level, block.timestamp);
        if (_level < 15 && users[referer].referrerID >= 1) {
            addTO(_level + 1, referer, _amount);
            // } else {}
        }
        //if (!sent) {
        //payReferral(_level, referer, _value);
        //}
    }

    /**
     */
    function withdrawableROI(
        address _address
    ) public view returns (uint reward) {
        uint256 numDays = (block.timestamp - users[_address].stakeTimes) /
            86400;
        if (numDays > 0) {
            return (((stakedUSDT[_address] * 6) / 1000) * numDays);
            //return (users[_address].stakedKBC * 547945205479452000 * numDays) / 1000;
        } else {
            return (0);
        }
    }

        function top4PoolDistribution(
        uint256 _referrerID,
        uint256 _amount
    ) internal {
        uint256 replaceTo;
        address currentRunner;
        dailyUserTO[currRound][userList[_referrerID]].myTO += _amount;
        dailyUserTO[currRound][userList[_referrerID]].time = block.timestamp;

        if (reportsUSDT[currRound].fourthUSDT == userList[_referrerID]) {
            reportsUSDT[currRound].fourthTOUSDT += _amount;
        } else if (reportsUSDT[currRound].thirdUSDT == userList[_referrerID]) {
            reportsUSDT[currRound].thirdTOUSDT += _amount;
        } else if (reportsUSDT[currRound].secondUSDT == userList[_referrerID]) {
            reportsUSDT[currRound].secondTOUSDT += _amount;
        } else if (reportsUSDT[currRound].firstUSDT == userList[_referrerID]) {
            reportsUSDT[currRound].firstTOUSDT += _amount;
        } else {
            if (reportsUSDT[currRound].firstTOUSDT == 0) {
                reportsUSDT[currRound].firstTOUSDT = _amount;
                reportsUSDT[currRound].firstUSDT = userList[_referrerID];
            } else if (reportsUSDT[currRound].secondTOUSDT == 0) {
                reportsUSDT[currRound].secondTOUSDT = _amount;
                reportsUSDT[currRound].secondUSDT = userList[_referrerID];
            } else if (reportsUSDT[currRound].thirdTOUSDT == 0) {
                reportsUSDT[currRound].thirdTOUSDT = _amount;
                reportsUSDT[currRound].thirdUSDT = userList[_referrerID];
            } else if (reportsUSDT[currRound].fourthTOUSDT == 0) {
                reportsUSDT[currRound].fourthTOUSDT = _amount;
                reportsUSDT[currRound].fourthUSDT = userList[_referrerID];
            } else if (
                reportsUSDT[currRound].fourthTOUSDT <
                dailyUserTO[currRound][userList[_referrerID]].myTO
            ) {
                reportsUSDT[currRound].fourthTOUSDT = dailyUserTO[currRound][
                    userList[_referrerID]
                ].myTO;
                reportsUSDT[currRound].fourthUSDT = userList[_referrerID];
            }
        }

        if (
            reportsUSDT[currRound].thirdTOUSDT <
            reportsUSDT[currRound].fourthTOUSDT
        ) {
            replaceTo = reportsUSDT[currRound].thirdTOUSDT;
            currentRunner = reportsUSDT[currRound].thirdUSDT;

            reportsUSDT[currRound].thirdTOUSDT = reportsUSDT[currRound]
                .fourthTOUSDT;
            reportsUSDT[currRound].thirdUSDT = reportsUSDT[currRound]
                .fourthUSDT;
            reportsUSDT[currRound].fourthTOUSDT = replaceTo;
            reportsUSDT[currRound].fourthUSDT = currentRunner;
        }

        if (
            reportsUSDT[currRound].secondTOUSDT <
            reportsUSDT[currRound].thirdTOUSDT
        ) {
            replaceTo = reportsUSDT[currRound].secondTOUSDT;
            currentRunner = reportsUSDT[currRound].secondUSDT;

            reportsUSDT[currRound].secondTOUSDT = reportsUSDT[currRound]
                .thirdTOUSDT;
            reportsUSDT[currRound].secondUSDT = reportsUSDT[currRound]
                .thirdUSDT;
            reportsUSDT[currRound].thirdTOUSDT = replaceTo;
            reportsUSDT[currRound].thirdUSDT = currentRunner;
        }

        if (
            reportsUSDT[currRound].firstTOUSDT <
            reportsUSDT[currRound].secondTOUSDT
        ) {
            replaceTo = reportsUSDT[currRound].firstTOUSDT;
            currentRunner = reportsUSDT[currRound].firstUSDT;

            reportsUSDT[currRound].firstTOUSDT = reportsUSDT[currRound]
                .secondTOUSDT;
            reportsUSDT[currRound].firstUSDT = reportsUSDT[currRound]
                .secondUSDT;
            reportsUSDT[currRound].secondTOUSDT = replaceTo;
            reportsUSDT[currRound].secondUSDT = currentRunner;
        }
    }

    function closeRound() public {
        require(msg.sender == roundCloser, "you are not round closer");
        uint Kbc_Price = (stableCoin.balanceOf(pricePool) * 1e18 / wBNB.balanceOf(pricePool));
        if (block.timestamp - currRoundStartTime >= 86400) {
            //reports[currDay].top4Pool2Distribute = reports[currDay].top4Pool / 2;

            if (reportsUSDT[currRound].firstTOUSDT > 0){
                //payable(reportsUSDT[currRound].firstUSDT).transfer
                //(((reportsUSDT[currRound].top4Pool2DistributeUSDT * 40) / 100) / KbcPrice);
            income[reportsUSDT[currRound].firstUSDT].top4Income +=
             ((reportsUSDT[currRound].top4PoolUSDT * 10) / 100);
             income[reportsUSDT[currRound].firstUSDT].totalIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 10) / 100);
             income[reportsUSDT[currRound].firstUSDT].balanceIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 10) / 100); 
             (reportsUSDT[currRound].top4Pool2DistributeUSDT) +=
              ((reportsUSDT[currRound].top4PoolUSDT * 10) / 100);
            }
            if (reportsUSDT[currRound].secondTOUSDT > 0){
            income[reportsUSDT[currRound].secondUSDT].top4Income +=
             ((reportsUSDT[currRound].top4PoolUSDT * 75) / 1000);
             income[reportsUSDT[currRound].secondUSDT].totalIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 75) / 1000);
             income[reportsUSDT[currRound].secondUSDT].balanceIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 75) / 1000);
            (reportsUSDT[currRound].top4Pool2DistributeUSDT) +=
             ((reportsUSDT[currRound].top4PoolUSDT * 75) / 1000);  
            }
            if (reportsUSDT[currRound].thirdTOUSDT > 0){
            income[reportsUSDT[currRound].thirdUSDT].top4Income +=
             ((reportsUSDT[currRound].top4PoolUSDT * 5) / 100);
             income[reportsUSDT[currRound].thirdUSDT].totalIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 5) / 100);
             income[reportsUSDT[currRound].thirdUSDT].balanceIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 5) / 100);
             (reportsUSDT[currRound].top4Pool2DistributeUSDT) +=
              ((reportsUSDT[currRound].top4PoolUSDT * 5) / 100);
            }
            if (reportsUSDT[currRound].fourthTOUSDT > 0){
            income[reportsUSDT[currRound].fourthUSDT].top4Income +=
             ((reportsUSDT[currRound].top4PoolUSDT * 25) / 1000);
             income[reportsUSDT[currRound].fourthUSDT].totalIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 25) / 1000);
             income[reportsUSDT[currRound].fourthUSDT].balanceIncome +=
             ((reportsUSDT[currRound].top4PoolUSDT * 25) / 1000);
             (reportsUSDT[currRound].top4Pool2DistributeUSDT) +=
              ((reportsUSDT[currRound].top4PoolUSDT * 25) / 1000);
            }
            //reportsUSDT[currRound].top4PoolUSDT = reportsUSDT[currRound].top4PoolUSDT - reportsUSDT[currRound].top4Pool2DistributeUSDT;
            reportsUSDT[currRound + 1].top4PoolUSDT = 
            reportsUSDT[currRound].top4PoolUSDT - reportsUSDT[currRound].top4Pool2DistributeUSDT;
            reportsUSDT[currRound + 1].top4PoolForwardedUSDT  =
             reportsUSDT[currRound].top4PoolUSDT - reportsUSDT[currRound].top4Pool2DistributeUSDT;

            reportsUSDT[currRound].atPrice = Kbc_Price;

             emit top4winners (currRound,users[reportsUSDT[currRound].firstUSDT].id, users[reportsUSDT[currRound].secondUSDT].id,
                   users[reportsUSDT[currRound].thirdUSDT].id, users[reportsUSDT[currRound].fourthUSDT].id);

            currRound++;
            currRoundStartTime = block.timestamp;
            }
            }

         
           /*function setGlobalPool(uint256 _set) public onlyOwner {
    
            globalPool = _set;
           }*/

           function fundGlobalPool() public payable {
            require(msg.value >= 0, "VALUE_SHOULD_NOT_ZERO");
            globalPool += msg.value;

           // emit fundGlobal(msg.sender, msg.value, block.timestamp);
            }

            function fundInsurancePool() public payable {
            require(msg.value >= 0, "VALUE_SHOULD_NOT_ZERO");
            insurancePool += msg.value;

           // emit fundInsurance(msg.sender, msg.value, block.timestamp);
            }

    
     function withdrawROI() public  {
        require(msg.sender != ownerWallet, "Only user allowed");
        uint256 reward = withdrawableROI(msg.sender);
        //require(reward > 0, "No any withdrawableROI Found");
        uint Kbc_Price = (stableCoin.balanceOf(pricePool) * 1e18 / wBNB.balanceOf(pricePool));
        if (((reward * 1e18) / Kbc_Price) > globalPool){
            require(totalTaken[msg.sender] < totalDeposit[msg.sender], "you taken principal amount");
            InsurancePoolActive = true;
            insurancePool += globalPool;
            globalPool = 0;
            //insurancePool += reportsUSDT[currRound].top4PoolUSDT;
            reportsUSDT[currRound].top4PoolUSDT = 0;
            //require(totalTaken[msg.sender] < totalDeposit[msg.sender], "you taken principal amount");
            //uint inctosend = totalTaken[msg.sender] + reward - stakedUSDT[msg.sender];
            uint inctosend = withdrawableROI(msg.sender);
        if (inctosend >= totalDeposit[msg.sender] - totalTaken[msg.sender]) {
            inctosend = totalDeposit[msg.sender] - totalTaken[msg.sender];
            stakedUSDT[msg.sender] = 0;
        }
            uint tosend = (inctosend * 95) /100;
            //uint Kbc_Price = (stableCoin.balanceOf(pricePool) * 1e18 / wBNB.balanceOf(pricePool));
            payable(msg.sender).transfer((tosend * 1e18) / Kbc_Price);
            totalTaken[msg.sender] += inctosend;
        users[msg.sender].rootBalance -= inctosend;
        users[msg.sender].takenROI += inctosend;
        totalTaken[msg.sender] += inctosend;
        insurancePool -= (tosend * 1e18) / Kbc_Price;
        uint adjust = (block.timestamp - users[msg.sender].stakeTimes) % 86400;
        users[msg.sender].stakeTimes = block.timestamp - adjust;
        emit WithdrawROI(msg.sender, inctosend);
        //payReferral(1, msg.sender, inctosend);
        } else {

         if (reward >= users[msg.sender].capping - totalTaken[msg.sender]) {
            reward = users[msg.sender].capping - totalTaken[msg.sender];
            stakedUSDT[msg.sender] = 0;
        }
        users[msg.sender].rootBalance -= reward;
        users[msg.sender].takenROI += reward;
        uint tosend = reward * 95 /100;
        uint toadd = reward * 5 /100;
        //uint Kbc_Price = (stableCoin.balanceOf(pricePool) * 1e18 / wBNB.balanceOf(pricePool));
        payable(msg.sender).transfer((tosend * 1e18) / Kbc_Price);
        insurancePool += (toadd * 1e18) / Kbc_Price;
        totalTaken[msg.sender] += reward;
        globalPool -= (reward * 1e18) / Kbc_Price;
        uint adjust = (block.timestamp - users[msg.sender].stakeTimes) % 86400;
        users[msg.sender].stakeTimes = block.timestamp - adjust;
        emit WithdrawROI(msg.sender, reward);
        payReferral(1, msg.sender, reward);
    }
    }
    
    function withdrawIncome() public {
        require(users[msg.sender].isExist, "User not Exists");
        require(msg.sender != ownerWallet, "owner can not withdraw");
        uint256 reward = income[msg.sender].balanceIncome;

        uint Kbc_Price = ((stableCoin.balanceOf(pricePool) * 1e18) /
            wBNB.balanceOf(pricePool));

        if (((reward * 1e18) / Kbc_Price) > globalPool) {
            require(
                totalTaken[msg.sender] < totalDeposit[msg.sender],
                "you taken principal amount"
            );
            InsurancePoolActive = true;
            insurancePool += globalPool;
            globalPool = 0;
            reportsUSDT[currRound].top4PoolUSDT = 0;
            uint inctosend = income[msg.sender].balanceIncome;
            if (
                inctosend >= totalDeposit[msg.sender] - totalTaken[msg.sender]
            ) {
                inctosend = totalDeposit[msg.sender] - totalTaken[msg.sender];
            }
            uint tosend = (inctosend * 95) / 100;
            payable(msg.sender).transfer((tosend * 1e18) / Kbc_Price);
            totalTaken[msg.sender] += inctosend;
            income[msg.sender].takenIncome += inctosend;
            income[msg.sender].balanceIncome -= inctosend;
            insurancePool -= (tosend * 1e18) / Kbc_Price;
            emit IncomeWithdrawn(msg.sender, inctosend, block.timestamp);
        } else {
            uint inctosend = income[msg.sender].balanceIncome;
            if (
                inctosend >= users[msg.sender].capping - totalTaken[msg.sender]
            ) {
                inctosend = users[msg.sender].capping - totalTaken[msg.sender];
                //stakedUSDT[msg.sender] = 0;
            }
            uint tosend = (inctosend * 95) / 100;
            uint toadd = (inctosend * 5) / 100;
            //uint Kbc_Price = (stableCoin.balanceOf(pricePool) * 1e18 / wBNB.balanceOf(pricePool));
            payable(msg.sender).transfer((tosend * 1e18) / Kbc_Price);
            insurancePool += (toadd * 1e18) / Kbc_Price;
            totalTaken[msg.sender] += inctosend;
            globalPool -= (inctosend * 1e18) / Kbc_Price;
            income[msg.sender].takenIncome += inctosend;
            income[msg.sender].balanceIncome -= inctosend;
            emit IncomeWithdrawn(msg.sender, inctosend, block.timestamp);
        }
    }

    function withdrawReward(uint _star) public {
        require(users[msg.sender].isExist, "User Not Registered");
        //uint Kbc_Price = ((stableCoin.balanceOf(pricePool) * 1e18) /wBNB.balanceOf(pricePool));
        if (_star == 1) {
            require(
                ranks[msg.sender].starOnePaid == false,
                "already paid for starOne"
            );
            require(
                users[msg.sender].referredUsers >= 5,
                "refer 5 users first"
            );
            //require(users[msg.sender].levelIncomeReceived >= 15, "team size is less then 15");
            require(
                userTeamSize[msg.sender] >= 15,
                "team size is less then 15"
            );
            require(
                userTurnOver[msg.sender] >= 3100e18,
                "turnover is less then 3100"
            );
            require(
                totalDeposit[msg.sender] >= 100e18,
                "self deposit is below 100"
            );
            //payable(msg.sender).transfer((190e18 * 1e18) / Kbc_Price);
            //globalPool -= ((190e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 200e18;
            income[msg.sender].balanceIncome += 200e18;
            ranks[msg.sender].starOnePaid = true;
            ranks[userList[users[msg.sender].referrerID]].starOne += 1;

            //emit WithdrawReward(msg.sender, 200e18);
        }

        if (_star == 2) {
            require(
                ranks[msg.sender].starTwoPaid == false,
                "already paid for starTwo"
            );
            require(
                users[msg.sender].referredUsers >= 7,
                "refer 5 users first"
            );
            //require(users[msg.sender].levelIncomeReceived >= 25, "team size is less then 25");
            require(
                userTeamSize[msg.sender] >= 30,
                "team size is less then 30"
            );
            require(
                userTurnOver[msg.sender] >= 10300e18,
                "turnover is less then 10300"
            );
            require(
                totalDeposit[msg.sender] >= 300e18,
                "self deposit is below 300"
            );
            require(ranks[msg.sender].starOne >= 2);
            //payable(msg.sender).transfer((665e18 * 1e18) / Kbc_Price);
            //globalPool -= ((665e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 700e18;
            income[msg.sender].balanceIncome += 700e18;
            ranks[msg.sender].starTwoPaid = true;
            ranks[userList[users[msg.sender].referrerID]].starTwo += 1;

            //emit WithdrawReward(msg.sender, 700e18);
        }

        if (_star == 3) {
            require(
                ranks[msg.sender].starThreePaid == false,
                "already paid for starThree"
            );
            require(
                users[msg.sender].referredUsers >= 8,
                "refer 8 users first"
            );
            //require(users[msg.sender].levelIncomeReceived >= 50, "team size is less then 50");
            require(
                userTeamSize[msg.sender] >= 50,
                "team size is less then 50"
            );
            require(
                userTurnOver[msg.sender] >= 30500e18,
                "turnover is less then 30500"
            );
            require(
                totalDeposit[msg.sender] >= 500e18,
                "self deposit is below 300"
            );
            require(ranks[msg.sender].starTwo >= 2);
            //payable(msg.sender).transfer((1900e18 * 1e18) / Kbc_Price);
            //globalPool -= ((1900e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 2000e18;
            income[msg.sender].balanceIncome += 2000e18;
            ranks[msg.sender].starThreePaid = true;
            ranks[userList[users[msg.sender].referrerID]].starThree += 1;

            //emit WithdrawReward(msg.sender, 2000e18);
        }

        if (_star == 4) {
            require(
                ranks[msg.sender].starFourPaid == false,
                "already paid for starTwo"
            );
            require(
                users[msg.sender].referredUsers >= 10,
                "refer 10 users first"
            );
            //require(users[msg.sender].levelIncomeReceived >= 100, "team size is less then 10");
            require(
                userTeamSize[msg.sender] >= 100,
                "team size is less then 100"
            );
            require(
                userTurnOver[msg.sender] >= 101000e18,
                "turnover is less then 101000"
            );
            require(
                totalDeposit[msg.sender] >= 1000e18,
                "self deposit is below 1000"
            );
            require(ranks[msg.sender].starThree >= 2);
            //payable(msg.sender).transfer((6650e18 * 1e18) / Kbc_Price);
            //globalPool -= ((6650e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 7000e18;
            income[msg.sender].balanceIncome += 7000e18;
            ranks[msg.sender].starFourPaid = true;
            ranks[userList[users[msg.sender].referrerID]].starFour += 1;

            //emit WithdrawReward(msg.sender, 7000e18);
        }

        if (_star == 5) {
            require(
                ranks[msg.sender].starFivePaid == false,
                "already paid for starFive"
            );
            require(
                users[msg.sender].referredUsers >= 12,
                "refer 12 users first"
            );
            //require(users[msg.sender].levelIncomeReceived >= 200, "team size is less then 10");
            require(
                userTeamSize[msg.sender] >= 200,
                "team size is less then 200"
            );
            require(
                userTurnOver[msg.sender] >= 1000000e18,
                "turnover is less then ten lac"
            );
            require(
                totalDeposit[msg.sender] >= 5000e18,
                "self deposit is below 5000"
            );
            require(ranks[msg.sender].starFour >= 2);
            //payable(msg.sender).transfer((66500e18 * 1e18) / Kbc_Price);
            //globalPool -= ((66500e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 70000e18;
            income[msg.sender].balanceIncome += 70000e18;
            ranks[msg.sender].starFivePaid = true;
            ranks[userList[users[msg.sender].referrerID]].starFive += 1;

            //emit WithdrawReward(msg.sender, 70000e18);
        }

        if (_star == 6) {
            require(
                ranks[msg.sender].starSixPaid == false,
                "already paid for starSix"
            );
            require(users[msg.sender].referredUsers >= 14, "refer 14 users");
            //require(users[msg.sender].levelIncomeReceived >= 500, "team size is less then 500");
            require(
                userTeamSize[msg.sender] >= 500,
                "team size is less then 500"
            );
            require(
                userTurnOver[msg.sender] >= 5000000e18,
                "turnover is less then fifty lac"
            );
            require(
                totalDeposit[msg.sender] >= 10000e18,
                "self deposit is below 10000"
            );
            require(ranks[msg.sender].starFive >= 2);
            //payable(msg.sender).transfer((285000e18 * 1e18) / Kbc_Price);
            //globalPool -= ((285000e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 300000e18;
            income[msg.sender].balanceIncome += 300000e18;
            ranks[msg.sender].starSixPaid = true;
            ranks[userList[users[msg.sender].referrerID]].starSix += 1;

            //emit WithdrawReward(msg.sender, 300000e18);
        }
        if (_star == 7) {
            require(
                ranks[msg.sender].starSevenPaid == false,
                "already paid for starSeven"
            );
            require(users[msg.sender].referredUsers >= 15, "refer 15 users");
            //require(users[msg.sender].levelIncomeReceived >= 1000, "team size is less then 10");
            require(
                userTeamSize[msg.sender] >= 1000,
                "team size is less then 1000"
            );
            require(
                userTurnOver[msg.sender] >= 20000000e18,
                "turnover is less then 2 Cr"
            );
            require(
                totalDeposit[msg.sender] >= 25000e18,
                "self deposit is below 25k"
            );
            require(ranks[msg.sender].starSix >= 2);
            //payable(msg.sender).transfer((950000e18 * 1e18) / Kbc_Price);
            //globalPool -= ((950000e18 * 1e18) / Kbc_Price);
            income[msg.sender].totalIncome += 1000000e18;
            income[msg.sender].balanceIncome += 1000000e18;
            ranks[msg.sender].starSevenPaid = true;
            ranks[userList[users[msg.sender].referrerID]].starSeven += 1;

            // emit WithdrawReward(msg.sender, 1000000e18);
        }
    }

    function setRoundCloserAddress(address _address) public onlyOwner {
        roundCloser = _address;
    }
}