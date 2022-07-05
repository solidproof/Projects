
/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import "./C250PriceOracle.sol";
import "./TimeProvider.sol";
// import "hardhat/console.sol";

/**
 * @title C250Gold
 */
contract C250Gold is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    uint256 public constant MAX_SUPPLY = 250000000 * 1e18;
    uint256 public constant INITIAL_SUPPLY = 250000 * 1e18;
    uint256 public constant ACTIVATION_FEE = 25 * 1e17; // $2.5
    uint256 public constant UPGRADE_FEE = 20 * 1e18; // $20
    uint256 public constant WITHDRAWAL_FEE = 100; // 10%
    uint256[] public CLASSIC_REFERRAL_PERCENTS = [5, 4];

    struct ClassicConfig {
        uint256 directReferral;
        uint256 exDirectReferral;
        uint256 globalRequirement;
        uint256 dailyEarning;
        uint256 earningDays;
    }

    uint256 public constant PERCENTS_DIVIDER = 1000;
    uint256 public constant ADAY = (1 days);

    address public C250GoldPool;
    C250PriceOracle public priceOracle;
    TimeProvider timeProvider;
    address usdc;
    address treasury;

    struct User {
        uint256 classicIndex;
        uint256 classicCheckpoint;
        uint256 referralID;
        uint256 uplineID;
        uint256 premiumLevel;
        // @dev imported from the web version of the program
        bool imported;
        uint256 importedReferralCount;
        uint256 importClassicLevel;
        uint256 outstandingBalance;
        uint256[] referrals;
        // @dev holds the total number of downlines on each day
        mapping(uint256 => uint256) activeDownlines;
        mapping(uint256 => uint256) classicEarningCount;
    }

    event NewUser(
        address indexed user,
        uint256 indexed id,
        uint256 indexed referrer
    );

    event NewActivation(address indexed by, uint256 indexed id);
    event NewUpgrade(address indexed by, uint256 indexed id);
    event ClassicRefBonus(uint256 user, uint256 upline, uint256 generation);
    event Withdrawal(address indexed user, uint256 amount);

    mapping(uint256 => ClassicConfig) classicConfigurations;
    uint256 public totalPayout;
    uint256 public lastID;
    uint256 public classicIndex;
    uint256[] internal classicActivationDays;
    // @dev holds the total number of global downlines on each day
    mapping(uint256 => uint256) public activeGlobalDownlines;

    // @dev mapping of id to address
    mapping(uint256 => address) public userAddresses;
    // @dev mapping of id to user
    mapping(uint256 => User) public users;
    // @dev list of accounts associated with an address
    mapping(address => uint256[]) public userAccounts;

    constructor(
        address _priceOracle, address _timeProvider, address _treasury
    ) ERC20("C360Gold", "C250G") {
        classicActivationDays.push(getTheDayBefore(block.number));
        priceOracle = C250PriceOracle(_priceOracle);
        timeProvider = TimeProvider(_timeProvider);
        treasury = _treasury;
        mint(msg.sender, INITIAL_SUPPLY);
        buildClassicConfig();
        buildPremiumConfig();
        _register(0, 0, msg.sender);
    }

    function buildClassicConfig() private {
        // @dev lower global requirement for testing
        // classicConfigurations[1] = ClassicConfig(1, 0, 10, 25 * 1e16, 10);
        // classicConfigurations[2] = ClassicConfig(3, 12, 20, 25 * 1e16, 20);
        // classicConfigurations[3] = ClassicConfig(3, 12, 30, 28 * 1e16, 20);

        classicConfigurations[1] = ClassicConfig(1, 0, 1000, 25 * 1e16, 10);
        classicConfigurations[2] = ClassicConfig(3, 12, 4000, 25 * 1e16, 20);
        classicConfigurations[3] = ClassicConfig(6, 15, 9500, 28 * 1e16, 30);
        classicConfigurations[4] = ClassicConfig(10, 18, 20000, 44 * 1e16, 40);
        classicConfigurations[5] = ClassicConfig(15, 21, 45500, 66 * 1e16, 50);
        classicConfigurations[6] = ClassicConfig(21, 24, 96000, 88 * 1e16, 60);
        classicConfigurations[7] = ClassicConfig(28, 27, 196500, 10 * 1e17, 70);
        classicConfigurations[8] = ClassicConfig(36, 30, 447000, 15 * 1e17, 70);
        classicConfigurations[9] = ClassicConfig(45, 33, 947500, 20 * 1e17, 80);
        classicConfigurations[10] = ClassicConfig(55, 36, 1948000, 30 * 1e17, 100);
        classicConfigurations[11] = ClassicConfig(66, 39, 3948500, 40 * 1e17, 100);
        classicConfigurations[12] = ClassicConfig(78, 42, 6949000, 50 * 1e17, 100);
        classicConfigurations[13] = ClassicConfig(91, 45, 10949500, 60 * 1e17, 150);
        classicConfigurations[14] = ClassicConfig(105, 48, 15950000, 70 * 1e17, 150);
        classicConfigurations[15] = ClassicConfig(120, 51, 21950500, 80 * 1e17, 250);
        classicConfigurations[16] = ClassicConfig(136, 54, 29451000, 90 * 1e17, 250);
        classicConfigurations[17] = ClassicConfig(153, 57, 39451500, 11 * 1e17, 700);
        classicConfigurations[18] = ClassicConfig(171, 60, 64450000, 13 * 1e17, 1000);
        classicConfigurations[19] = ClassicConfig(190, 63, 114452500, 16 * 1e17, 1000);
        classicConfigurations[20] = ClassicConfig(210, 67, 214453000, 15 * 1e17, 1000);
    }

    function getClassicConfig(uint256 level)
        external
        view
        returns (
            uint256 directReferral,
            uint256 exDirectReferral,
            uint256 globalRequirement,
            uint256 dailyEarning,
            uint256 earningDays
        )
    {
        directReferral = classicConfigurations[level].directReferral;
        exDirectReferral = classicConfigurations[level].exDirectReferral;
        globalRequirement = classicConfigurations[level].globalRequirement;
        dailyEarning = classicConfigurations[level].dailyEarning;
        earningDays = classicConfigurations[level].earningDays;
    }

    function createUsdcPool(
        address factory,
        address _usdc,
        uint24 fee
    ) external onlyOwner {
        usdc = _usdc;

        address _c250GoldPool = IUniswapV3Factory(factory).createPool(
            usdc,
            address(this),
            fee
        );
        require(_c250GoldPool != address(0), "Cannot create this pool");
        C250GoldPool = _c250GoldPool;
    }

    function setPriceOracle(address oracle) external onlyOwner {
        priceOracle = C250PriceOracle(oracle);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address account, uint256 amount) internal {
        require(totalSupply().add(amount) <= MAX_SUPPLY);
        _mint(account, amount);
    }

    modifier validReferralID(uint256 id) {
        require(id > 0 && id <= lastID, "Invalid referrer ID");
        _;
    }

    function setTreasuryWallet(address addr) external onlyOwner {
        treasury = addr;
    }

    bool public live;

    function launch() external onlyOwner {
        live = true;
    }

    function getTheDayBefore(uint256 timestamp)
        internal
        pure
        returns (uint256)
    {
        return timestamp.sub(timestamp % ADAY);
    }

    // @dev returns the token equivalent of the supplied dollar by getting quote from uniswap
    function amountFromDollar(uint256 dollarAmount)
        public
        view
        returns (uint256 tokenAmount)
    {
        tokenAmount = priceOracle.getQuote(
            usdc,
            address(this),
            C250GoldPool,
            uint128(dollarAmount),
            10
        );
    }

    function getActivationFeeInToken() external view returns (uint256) {
        return amountFromDollar(ACTIVATION_FEE);
    }

    function getUpgradeFeeInToken() external view returns (uint256) {
        return amountFromDollar(UPGRADE_FEE);
    }

    function changeWallet(uint256 userID, address newWallet) public {
        require(userAddresses[userID] == msg.sender, "Not allowed");
        userAddresses[userID] = newWallet;

        emit WalletChanged(userID, newWallet);
    }

    struct ChangeWalletRequest {
        address newWallet;
        uint256[] approvals;
    }

    event ChangeWalletRequestCreated(uint256 indexed userID, address newWallet);

    event ChangeWalletRequestDeleted(uint256 indexed userID);

    event ChangeWalletRequestApproved(
        uint256 indexed userID,
        uint256 indexed approvingUserID
    );

    event WalletChanged(uint256 userID, address newWallet);

    mapping(uint256 => ChangeWalletRequest) public changeWalletRequests;

    // @dev if a user is unable to access his wallet, his upline can make a change request
    // which must be approvef by 10 uplines before the admin can process it
    function creatChangeWalletRequest(uint256 userID, address newWallet) external {
        require(userAddresses[users[userID].referralID] == msg.sender, "Not allowed");
        require(changeWalletRequests[userID].newWallet == address(0), "Request exists");
        changeWalletRequests[userID].newWallet = newWallet;
        changeWalletRequests[userID].approvals.push(users[userID].referralID);

        emit ChangeWalletRequestCreated(userID, newWallet);
        emit ChangeWalletRequestApproved(userID, users[userID].referralID);
    }

    function deleteChangeWalletRequest(uint256 userID) external {
        require( userAddresses[users[userID].referralID] == msg.sender || userAddresses[userID] == msg.sender, "Not allowed" );
        require(changeWalletRequests[userID].newWallet != address(0), "Request not found");

        delete changeWalletRequests[userID];
        emit ChangeWalletRequestDeleted(userID);
    }

    function approveChangeWalletRequest(uint256 userID) external {
        uint256 lastApprovingUserID = changeWalletRequests[userID].approvals[changeWalletRequests[userID].approvals.length - 1];
        uint256 currentApprovingUserID = users[lastApprovingUserID].referralID;
        require(userAddresses[currentApprovingUserID] == msg.sender, "Not allowed");

        changeWalletRequests[userID].approvals.push(currentApprovingUserID);

        emit ChangeWalletRequestApproved(userID, currentApprovingUserID);
    }

    function processChangeWalletRequest(uint256 userID) external onlyOwner {
        require(changeWalletRequests[userID].approvals.length >= 10, "Not allowed");
        userAddresses[userID] = changeWalletRequests[userID].newWallet;

        emit WalletChanged(userID, changeWalletRequests[userID].newWallet);
    }

    function _register(uint256 referralID, uint256 uplineID, address addr) internal {
        lastID++;
        userAddresses[lastID] = addr;
        users[lastID].referralID = referralID;
        // @dev if an upline is supplied, it must be a premium account. ID 1 is premium by default
        if (uplineID > 0) {
            require(
                accountIsInPremium(uplineID),
                "Upline ID not a premium account"
            );
            users[lastID].uplineID = uplineID;
        }
        userAccounts[addr].push(lastID);

        emit NewUser(addr, lastID, referralID);
    }

    function register(uint256 referralID, uint256 uplineID, address addr) public validReferralID(referralID) {
        require(live, "Not started");
        require(
            userAccounts[addr].length == 0,
            "Already registered, user add account"
        );
        _register(referralID, uplineID, addr);
    }

    function addAccount(uint256 referralID, uint256 uplineID, address addr) public validReferralID(referralID) {
        require(live, "Not started");
        require(
            userAccounts[addr].length != 0,
            "Account not found, please register"
        );
        _register(referralID, uplineID, addr);
    }

    function activate(uint256 id) public nonReentrant {
        require(live, "Not started");
        require(userAddresses[id] != address(0), "Account not registered");
        require(users[id].classicIndex == 0, "Already activated");
        uint256 feeAmount = amountFromDollar(ACTIVATION_FEE);
        require(balanceOf(msg.sender) >= feeAmount, "Insufficient balance");
        _burn(msg.sender, feeAmount);
        classicIndex++;
        users[id].classicIndex = classicIndex;
        users[id].classicCheckpoint = timeProvider.currentTime();
        uint256 today = getTheDayBefore(timeProvider.currentTime());

        if (users[id].referralID != 0) {
            users[users[id].referralID].referrals.push(id);
            // @dev daily active downline will the recorded as 0 for imported users until the user
            // refers the number of new accounts required for his imported level
            // this is to the stop the system from paying the users for the days he didn't meetup
            if (
                !users[users[id].referralID].imported ||
                users[users[id].referralID].referrals.length - users[users[id].referralID].importedReferralCount >=
                classicConfigurations[users[users[id].referralID].importClassicLevel - 1].exDirectReferral
            ) {
                users[users[id].referralID].activeDownlines[today] = users[users[id].referralID].referrals.length;
            }

            uint256 upline = users[id].referralID;
            uint256 refTotal;
            for (uint256 i = 0; i < CLASSIC_REFERRAL_PERCENTS.length; i++) {
                if (upline != 0) {
                    if (userAddresses[upline] != address(0)) {
                        uint256 refAmount = feeAmount.mul(CLASSIC_REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER);
                        refTotal = refTotal.add(refAmount);
                        mint(userAddresses[upline], amountFromDollar(refAmount));
                        emit ClassicRefBonus(id, upline, i + 1);
                    }
                    upline = users[upline].referralID;
                } else break;
            }
            if (refTotal > 0) {
                totalPayout = totalPayout.add(refTotal);
            }
        }

        // taking the snapshot of the number of classic accounts
        activeGlobalDownlines[today] = classicIndex;
        if (today != classicActivationDays[classicActivationDays.length - 1]) {
            classicActivationDays.push(today);
        }

        emit NewActivation(msg.sender, id);
    }

    function registerAndActivate(uint256 referralID, uint256 uplineID, address addr) external {
        register(referralID, uplineID, addr);
        activate(lastID);
    }

    function addAndActivateMultipleAccounts(uint256 referralID, uint256 uplineID, address addr, uint256 no) external {
        require(no <= 50, "too many accounts, please enter 50 and below");
        require(balanceOf(msg.sender) >= ACTIVATION_FEE.mul(no), "insufficient balance");

        for (uint256 i = 0; i < no; i++) {
            addAccount(referralID, uplineID, addr);
            activate(lastID);
        }
    }

    function importClassicAccount(address addr, uint256 id, uint256 referralID, uint256 classicLevel, uint256 premiumLevel, uint256 downlinecount, uint256 bal) external onlyOwner {
        require(!live, "not allowed after going live");
        require(id > lastID, "Potential duplicate import");
        lastID = id;
        classicIndex++;
        users[id].imported = true;
        users[id].referralID = referralID;
        users[id].classicIndex = classicIndex;
        users[id].importClassicLevel = classicLevel;
        users[id].premiumLevel = premiumLevel;
        users[id].importedReferralCount = downlinecount;
        users[id].outstandingBalance = bal;
        userAddresses[id] = addr;

        if (referralID > 0) {
            users[referralID].referrals.push(id);
        }
    }

    // @dev returns the current unpaid earnings of the user
    function withdawable(uint256 userID) public view returns (uint256, uint256) {
        User storage user = users[userID];
        uint256 amount = 0;

        // @dev keep track of the number of days that've been considered in the current loop so as to stay within the limit for the level
        uint256 earningCounter;
        uint256 lastLevel;

        uint256 today = getTheDayBefore(timeProvider.currentTime());

        for (
            uint256 day = getTheDayBefore(user.classicCheckpoint);
            day < today;
            day += ADAY
        ) {
            uint256 level = getClassicLevelAt(userID, day);
            if (level == 0 && lastLevel == 0) continue;
            if (level != lastLevel) {
                lastLevel = level;
                earningCounter = 0;
            }

            if (
                user.classicEarningCount[lastLevel].add(earningCounter) <
                classicConfigurations[lastLevel].earningDays
            ) {
                amount = amount.add(classicConfigurations[lastLevel].dailyEarning);
                earningCounter = earningCounter.add(1);
            }
        }

        return (amount, user.classicEarningCount[lastLevel].add(earningCounter));
    }

    function withdraw(uint256 userID) external {
        require(userAddresses[userID] == msg.sender, "Access denied");
        (uint256 dollarAmount, uint256 earningCounter) = withdawable(userID);
        require(dollarAmount > 0, "Nothing to withdraw");
        users[userID].classicCheckpoint = timeProvider.currentTime();
        users[userID].classicEarningCount[getClassicLevelAt(userID, timeProvider.currentTime())] = earningCounter;
        // @dev update the downline count (if empty) at this checkpoint for the next call to getLevelAt
        if (users[userID].activeDownlines[getTheDayBefore(timeProvider.currentTime())] == 0) {
            users[userID].activeDownlines[getTheDayBefore(timeProvider.currentTime())] = users[userID].referrals.length;
        }
        // for imported users, pay 50% of this earning from outstanding balance
        if (users[userID].imported && users[userID].outstandingBalance > 0) {
            uint256 outstandingPayout = dollarAmount.div(2);
            if (outstandingPayout > users[userID].outstandingBalance) {
                outstandingPayout = users[userID].outstandingBalance;
            }
            users[userID].outstandingBalance = users[userID].outstandingBalance.sub(outstandingPayout);
            dollarAmount = dollarAmount.add(outstandingPayout);
        }
        totalPayout = totalPayout.add(dollarAmount);
        sendPayout(msg.sender, dollarAmount);
    }

    function sendPayout(address account, uint256 dollarAmount) internal {
        uint256 tokenAmount = amountFromDollar(dollarAmount);
        uint256 fee = tokenAmount.mul(WITHDRAWAL_FEE).div(PERCENTS_DIVIDER);
        if (treasury != address(0)) {
            mint(treasury, fee);
        }
        mint(account, tokenAmount.sub(fee));
        emit Withdrawal(msg.sender, dollarAmount);
    }

    function getAccounts(address addr) external view returns (uint256[] memory) {
        return userAccounts[addr];
    }

    // @dev returns the classic level in which the user is qaulified to earn at the given timestamp
    function getClassicLevelAt(uint256 userID, uint256 timestamp) internal view returns (uint256) {
        User storage user = users[userID];
        uint256 directDownlineCount = user.referrals.length;
        if (directDownlineCount == 0) return 0;

        uint256 globalIndex = classicIndex;
        if (timestamp != timeProvider.currentTime() && classicActivationDays.length > 0) {
            for (uint256 i = classicActivationDays.length - 1; i >= 0; i--) {
                if (classicActivationDays[i] <= timestamp) {
                    directDownlineCount = user.activeDownlines[classicActivationDays[i]];
                    globalIndex = activeGlobalDownlines[classicActivationDays[i]];
                    break;
                }
            }
        }

        uint256 globalDownlines = globalIndex - user.classicIndex;

        for (uint256 i = 20; i > 0; i--) {
            if (
                classicConfigurations[i].directReferral <=
                directDownlineCount &&
                classicConfigurations[i].globalRequirement <= globalDownlines
            ) {
                return i;
            }
        }
        return 0;
    }

    // @dev returns the current classic level of the user
    function getClassicLevel(uint256 userID) public view returns (uint256) {
        return getClassicLevelAt(userID, timeProvider.currentTime());
    }

    function getImpClassicLevel(uint256 userID) external view returns (uint256) {
        return users[userID].importClassicLevel;
    }

    function activationFeeInToken() external view returns (uint256) {
        return amountFromDollar(ACTIVATION_FEE);
    }

    function getUser(uint256 userID) external  view returns (
            address addr,
            uint256 downlines,
            uint256 userClassicIndex,
            uint256 globalDownlines,
            uint256 classicLevel,
            uint256 classicCheckpoint,
            uint256 referralID,
            uint256 premiumLevel,
            bool imported,
            uint256 importedReferralCount,
            uint256 importClassicLevel,
            uint256 outstandingBalance
        )
    {
        addr = userAddresses[userID];
        downlines = users[userID].referrals.length;
        userClassicIndex = users[userID].classicIndex;
        globalDownlines = classicIndex.sub(users[userID].classicIndex);
        classicLevel = getClassicLevel(userID);
        classicCheckpoint = users[userID].classicCheckpoint;
        referralID = users[userID].referralID;
        premiumLevel = users[userID].premiumLevel;
        imported = users[userID].imported;
        importedReferralCount = users[userID].importedReferralCount;
        importClassicLevel = users[userID].importClassicLevel;
        outstandingBalance = users[userID].outstandingBalance;
    }

    function getReferrals(uint256 userID) external view returns (uint256[] memory) {
        return users[userID].referrals;
    }

    // //////// //////// /* C250 Premuin *\ \\\\\\\\ \\\\\\\\

    struct Matrix {
        bool registered;
        uint256 uplineID;
        uint256 left;
        uint256 right;
    }

    struct LevelConfig {
        uint256 perDropEarning;
        uint256 paymentGeneration;
        uint256 numberOfPayments;
    }

    event PremiumReferralPayout(
        uint256 indexed userID,
        uint256 indexed referralID,
        uint256 amount
    );

    event MatrixPayout(
        uint256 indexed userID,
        uint256 indexed fromID,
        uint256 amount
    );

    event NewLevel(uint256 indexed userID, uint256 indexed level);

    // @dev user's matric for each part
    mapping(uint256 => mapping(uint256 => Matrix)) matrices;

    mapping(uint256 => LevelConfig) levelConfigurations;

    // @dev holds number of payments received by a user in each level
    mapping(uint256 => mapping(uint256 => uint256)) matrixPayoutCount;

    function buildPremiumConfig() private {
        levelConfigurations[1] = LevelConfig(25 * 1e17, 1, 2);
        levelConfigurations[2] = LevelConfig(5 * 1e18, 2, 4);
        levelConfigurations[3] = LevelConfig(10 * 1e18, 1, 2);
        levelConfigurations[4] = LevelConfig(10 * 1e18, 2, 4);
        levelConfigurations[5] = LevelConfig(75 * 1e18, 3, 8);
        levelConfigurations[6] = LevelConfig(300 * 1e18, 1, 2);
        levelConfigurations[7] = LevelConfig(400 * 1e18, 2, 4);
        levelConfigurations[8] = LevelConfig(875 * 1e18, 3, 8);
        levelConfigurations[9] = LevelConfig(7500 * 1e18, 1, 2);
        levelConfigurations[10] = LevelConfig(10000 * 1e18, 2, 4);
        levelConfigurations[11] = LevelConfig(37500 * 1e18, 3, 8);
        levelConfigurations[12] = LevelConfig(200000 * 1e18, 1, 2);
        levelConfigurations[13] = LevelConfig(350000 * 1e18, 2, 4);
        levelConfigurations[14] = LevelConfig(562500 * 1e18, 3, 8);
        levelConfigurations[15] = LevelConfig(1500000 * 1e18, 1, 2);
        levelConfigurations[16] = LevelConfig(2500000 * 1e18, 2, 4);
        levelConfigurations[17] = LevelConfig(37500000 * 1e18, 3, 8);
        levelConfigurations[18] = LevelConfig(18000000 * 1e18, 1, 2);

        // add base account to all matrix
        matrices[1][1].registered = true;
        matrices[1][2].registered = true;
        matrices[1][3].registered = true;

        users[1].premiumLevel = 18;
    }

    function upgradeToPremium(uint256 userID, uint256 random) external {
        require(live, "Not launched yet");
        require(userID > 0 && userID <= lastID, "Invalid ID");
        require(balanceOf(msg.sender) >= amountFromDollar(UPGRADE_FEE), "Insufficient balance");

        require(users[userID].classicIndex > 0, "Classic not activated");

        User storage user = users[userID];

        _burn(msg.sender, amountFromDollar(UPGRADE_FEE));

        uint256 sponsorID = getPremiumSponsor(userID, 0);
        sendPayout(userAddresses[sponsorID], amountFromDollar(UPGRADE_FEE.div(2)));
        emit PremiumReferralPayout(sponsorID, userID, amountFromDollar(UPGRADE_FEE.div(2)));

        uint256 uplineID = sponsorID;
        if (user.uplineID > 0) {
            uplineID = user.uplineID;
        }

        uint256 matrixUpline = getAvailableUplineInMatrix(uplineID, 1, true, random);
        matrices[userID][1].registered = true;
        matrices[userID][1].uplineID = matrixUpline;
        users[userID].premiumLevel = 1;

        sendMatrixPayout(userID, 1);

        if (matrices[matrixUpline][1].left == 0) {
            matrices[matrixUpline][1].left = userID;
        } else {
            matrices[matrixUpline][1].right = userID;
            moveToNextLevel(matrixUpline, random);
        }
    }

    function accountIsInPremium(uint256 userID) public view returns (bool) {
        return userID == 1 || users[userID].premiumLevel > 0;
    }

    function getPremiumSponsor(uint256 userID, uint256 callCount) public view returns (uint256) {
        if (callCount >= 10) {
            return 1;
        }
        if (accountIsInPremium(users[userID].referralID)) {
            return users[userID].referralID;
        }

        return getPremiumSponsor(users[userID].referralID, callCount + 1);
    }

    // @dev returns the upline of the user in the supplied part.
    // part must be 2 and above.
    // part 1 should use the get getPremiumSponsor
    function getUplineInPart(uint256 userID, uint256 part, int256 callDept) private view returns (uint256) {
        require(part > 1, "Invalid part for getUplineInPart");
        if (matrices[userID][part].registered) {
            return matrices[userID][part].uplineID;
        }

        uint256 p1up = matrices[userID][1].uplineID;
        if (matrices[p1up][part].registered) {
            return p1up;
        }

        if (callDept >= 50) {
            return 1;
        }

        return getUplineInPart(p1up, part, callDept + 1);
    }

    // @dev return user ID that has space in the matrix of the supplied upline ID
    // @dev uplineID must be a premium account in the supplied part
    function getAvailableUplineInMatrix(
        uint256 uplineID, uint256 part, bool traverseDown, uint256 random
    ) public view returns (uint256) {
        require(uplineID > 0, "Zero upline");
        require(matrices[uplineID][part].registered, "Upline not in part");

        if (hasEmptyLegs(uplineID, part)) {
            return uplineID;
        }

        uint256 arraySize = 2 * ((2**traversalDept) - 1);
        uint256 previousLineSize = 2 * ((2**(traversalDept - 1)) - 1);
        uint256[] memory referrals = new uint256[](arraySize);
        referrals[0] = matrices[uplineID][part].left;
        referrals[1] = matrices[uplineID][part].right;

        uint256 referrer;

        for (uint256 i = 0; i < arraySize; i++) {
            if (hasEmptyLegs(referrals[i], part)) {
                referrer = referrals[i];
                break;
            }

            if (i < previousLineSize) {
                referrals[(i + 1) * 2] = matrices[referrals[i]][part].left;
                referrals[(i + 1) * 2 + 1] = matrices[referrals[i]][part].right;
            }
        }

        if (referrer == 0 && traverseDown) {
            if (random < previousLineSize) {
                random = random.add(previousLineSize);
            }
            if (random > arraySize) {
                random = arraySize % random;
            }
            referrer = getAvailableUplineInMatrix(referrals[random], part, false, random);

            if (referrer == 0) {
                for (uint256 i = previousLineSize; i < arraySize; i++) {
                    referrer = getAvailableUplineInMatrix(referrals[random], part, false, random);
                    if (referrer != 0) {
                        break;
                    }
                }
                require(referrer > 0, "Referrer not found");
            }
        }

        return referrer;
    }

    function hasEmptyLegs(uint256 userID, uint256 part) private view returns (bool) {
        return matrices[userID][part].left == 0 || matrices[userID][part].right == 0;
    }

    function sendMatrixPayout(uint256 fromID, uint256 level) private returns (uint256) {
        uint256 part = getPartFromLevel(level);
        uint256 beneficiary = getUplineAtBlock(fromID, part, levelConfigurations[level].paymentGeneration);
        // @dev this may happen as the imported data is not trusted to be in the right format
        if (matrixPayoutCount[beneficiary][level] >= levelConfigurations[level].numberOfPayments && beneficiary != 1) {
            return beneficiary;
        }

        matrixPayoutCount[beneficiary][level] = matrixPayoutCount[beneficiary][level].add(1);
        if (users[beneficiary].premiumLevel < level) {
            return beneficiary;
        }

        sendPayout(userAddresses[beneficiary], amountFromDollar(levelConfigurations[level].perDropEarning));
        emit MatrixPayout(beneficiary, fromID, levelConfigurations[level].perDropEarning);

        return beneficiary;
    }

    function getUplineAtBlock(uint256 userID, uint256 part, uint256 depth) private returns (uint256) {
        if (userID == 1) return 1;
        if (depth == 1) {
            return matrices[userID][part].uplineID;
        }

        return getUplineAtBlock(matrices[userID][part].uplineID, part, depth - 1);
    }

    function moveToNextLevel(uint256 userID, uint256 random) private {
        if(userID == 1) return;

        uint256 newLevel = users[userID].premiumLevel + 1;
        // @dev add to matrix if change in level triggers change in part
        if ( getPartFromLevel(newLevel) > getPartFromLevel(users[userID].premiumLevel)) {
            addToMatrix(userID, newLevel, random);
        }
        users[userID].premiumLevel = newLevel;

        emit NewLevel(userID, newLevel);
        // #dev send pending payments in this level
        if (matrixPayoutCount[userID][newLevel] > 0) {
            uint256 pendingAmount = matrixPayoutCount[userID][newLevel].mul(
                levelConfigurations[newLevel].perDropEarning
            );
            sendPayout(userAddresses[userID], amountFromDollar(pendingAmount));
        }


        uint256 benefactor = sendMatrixPayout(userID, newLevel);

        if (levelCompleted(benefactor) && benefactor != 1) {
            moveToNextLevel(benefactor, random);
        }
    }

    uint256 public traversalDept = 10;

    function setMaxtraversalDept(uint256 dept) external onlyOwner {
        traversalDept = dept;
    }

    function addToMatrix(uint256 userID, uint256 level, uint256 random) private {
        uint256 part = getPartFromLevel(level);
        uint256 uplineID = getUplineInPart(userID, part, 0);
        uint256 matrixUpline = getAvailableUplineInMatrix(uplineID, part, true, random);
        matrices[userID][part].registered = true;
        matrices[userID][part].uplineID = matrixUpline;
        if (matrices[matrixUpline][part].left == 0) {
            matrices[matrixUpline][part].left = userID;
        } else {
            matrices[matrixUpline][part].right = userID;
        }
    }

    struct ImportPart1MatrixOptions {
        uint256 userID;
        uint256 part;
        uint256 uplineID;
        uint256 left;
        uint256 right;

        uint256 earningL1;
        uint256 earningL2;
        uint256 earningL3;
        uint256 earningL4;
    }

    function importPart1LagacyMatrix(ImportPart1MatrixOptions calldata options) external onlyOwner {
        require(!live, "Import not allowed after launch");
        require(users[options.userID].classicIndex > 0, "Classic not imported");
        matrices[options.userID][options.part].registered = true;
        matrices[options.userID][options.part].uplineID = options.uplineID;
        matrices[options.userID][options.part].left = options.left;
        matrices[options.userID][options.part].right = options.right;

        if(options.part == 1) {
            matrixPayoutCount[options.userID][1] = options.earningL1;
            matrixPayoutCount[options.userID][2] = options.earningL2;
        } else  if(options.part == 2) {
            matrixPayoutCount[options.userID][3] = options.earningL1;
            matrixPayoutCount[options.userID][4] = options.earningL2;
            matrixPayoutCount[options.userID][5] = options.earningL3;
        } else  if(options.part == 3) {
            matrixPayoutCount[options.userID][6] = options.earningL1;
            matrixPayoutCount[options.userID][7] = options.earningL2;
            matrixPayoutCount[options.userID][8] = options.earningL3;
        } else  if(options.part == 4) {
            matrixPayoutCount[options.userID][9] = options.earningL1;
            matrixPayoutCount[options.userID][10] = options.earningL2;
            matrixPayoutCount[options.userID][11] = options.earningL3;
        } else  if(options.part == 5) {
            matrixPayoutCount[options.userID][12] = options.earningL1;
            matrixPayoutCount[options.userID][13] = options.earningL2;
            matrixPayoutCount[options.userID][14] = options.earningL3;
        } else  if(options.part == 6) {
            matrixPayoutCount[options.userID][15] = options.earningL1;
            matrixPayoutCount[options.userID][16] = options.earningL2;
            matrixPayoutCount[options.userID][17] = options.earningL3;
            matrixPayoutCount[options.userID][18] = options.earningL4;
        }
    }

    function levelCompleted(uint256 userID) private view returns (bool) {
        uint256 lineCount = matrixPayoutCount[userID][
            users[userID].premiumLevel
        ];

        return lineCount == levelConfigurations[users[userID].premiumLevel].numberOfPayments;
    }

    function getPartFromLevel(uint256 level) private pure returns (uint256) {
        require(level > 0 && level <= 18, "Invalid premium level");
        if (level < 3) {
            return 1;
        }
        if (level < 6) {
            return 2;
        }
        if (level < 9) {
            return 3;
        }
        if (level < 12) {
            return 4;
        }
        if (level < 15) {
            return 5;
        }
        return 6;
    }

    function getMatrixUpline(uint256 userID, uint256 part) external view returns (uint256) {
        return matrices[userID][part].uplineID;
    }

    function getDirectLegs(uint256 userID, uint256 level) external  view returns (
            uint256 left, uint256 leftLevel, uint256 right, uint256 rightLevel) {
        require(users[userID].premiumLevel >= level, "Invalid level");
        uint256 part = getPartFromLevel(level);

        left = matrices[userID][part].left;
        leftLevel = users[left].premiumLevel;

        right = matrices[userID][part].right;
        rightLevel = users[right].premiumLevel;
    }
}