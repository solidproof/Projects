// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {Pausable} from "openzeppelin-contracts/contracts/security/Pausable.sol";
import {IPyth} from "pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "pyth-sdk-solidity/PythStructs.sol";

contract CochilliGameBetaETH is AccessControl, Pausable {
    bytes32 public constant LP_ROLE = keccak256("LP_ROLE");

    IPyth public immutable pyth;

    struct BetDetails {
        uint256 amount;
        uint256 payout;
        uint64 startTime;
        uint64 endTime;
        int64 openPrice;
        int64 closePrice;
        address user;
        bytes8 pair;
        bool isLong;
        bool active;
    }

    uint256 public lockedLiquidity;
    uint256 public nextBetId;
    uint256 public minBet = 1e15;
    uint256 public maxBet = 100e15;
    uint256 public maxUtilizedLiquidity = 510e15;
    uint16 public minInterval = 1 minutes;
    uint16 public maxInterval = 10 minutes;
    uint16 public cancelBuffer = 5 minutes;
    uint16 public leverage = 17e2;

    mapping(uint256 => BetDetails) public betIds;
    mapping(address => uint256[]) public userBetIds;
    mapping(bytes8 => bytes32) public pairIds;

    event BetPlaced(
        uint256 indexed betId,
        address indexed user,
        bytes8 indexed pair,
        uint256 startTime,
        uint256 endTime,
        uint256 runTime
    );
    event BetExecuted(
        uint256 indexed betId,
        address indexed user,
        bool indexed won,
        uint256 payout
    );
    event BetCancelled(
        uint256 indexed betId,
        address indexed user
    );
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event UpdatedLeverage(uint16 leverage);
    event UpdatedAmounts(uint256 minAmount, uint256 maxAmount, uint256 maxUtilizedLiquidity);
    event UpdatedIntervals(uint16 minInterval, uint16 maxInterval);
    event PairsAdded(bytes8[] pairs, bytes32[] ids);
    event PairsDeleted(bytes8[] pairs);

    error InvalidInterval();
    error InvalidAmount();
    error InvalidLeverage();
    error InvalidPair(bytes8 pair);
    error DuplicatePair(bytes8 pair);
    error InvalidPrice();
    error InvalidFee();
    error InsufficientLiquidity();
    error InsufficientBalance();
    error InactiveBet();
    error UnelapsedBet();
    error Unauthorized();
    error TransferFailed();
    error PayoutFailed();
    error DepositFailed();
    error WithdrawalFailed();

    constructor(address _pyth) {
        pyth = IPyth(_pyth);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LP_ROLE, msg.sender);
    }

    /// @notice Create a new bet
    /// @param pair Pair name e.g. BTCUSD
    /// @param interval Bet's duration in seconds
    /// @param isLong Bet's direction
    function placeBet(
        bytes8 pair,
        uint256 interval,
        bool isLong
    ) external payable whenNotPaused returns (uint256 betId) {
        if (msg.value < minBet || msg.value > maxBet) revert InvalidAmount(); // todo dynamic maxbet
        if (interval < minInterval || interval > maxInterval) revert InvalidInterval();
        if (pairIds[pair] == 0) revert InvalidPair(pair);

        uint256 payout = (msg.value * leverage) / 10e2;
        if (payout > availableLiquidity()) revert InsufficientLiquidity();
        lockedLiquidity += payout;

        betId = nextBetId;
        ++nextBetId;

        betIds[betId] = BetDetails({
            user: msg.sender,
            amount: msg.value,
            payout: payout,
            isLong: isLong,
            pair: pair,
            openPrice: 0,
            closePrice: 0,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + interval),
            active: true
        });
        userBetIds[msg.sender].push(betId);

        emit BetPlaced(betId, msg.sender, pair, block.timestamp, block.timestamp + interval, interval); // todo
    }

    /// @notice Function called by a keeper to execute the bet
    /// @param betId ID of the bet to execute
    /// @param openPriceVaa Open price data obtained from Pyth
    /// @param closePriceVaa Close price data obtained from Pyth
    function executeBet(
        uint256 betId,
        bytes calldata openPriceVaa,
        bytes calldata closePriceVaa
    ) external payable whenNotPaused {
        BetDetails memory closeBetDetails = betIds[betId];

        if (closeBetDetails.endTime >= block.timestamp) revert UnelapsedBet();
        if (!closeBetDetails.active) revert InactiveBet();

        bytes32 pairId = pairIds[closeBetDetails.pair];
        (int64 openPrice, uint256 openFee) = getPrice(
            pairId,
            openPriceVaa,
            closeBetDetails.startTime
        );
        (int64 closePrice, uint256 closeFee) = getPrice(
            pairId,
            closePriceVaa,
            closeBetDetails.endTime
        );

        if (openFee + closeFee != msg.value) revert InvalidFee();

        betIds[betId].active = false;
        betIds[betId].openPrice = openPrice;
        betIds[betId].closePrice = closePrice;

        uint256 payout = closeBetDetails.payout;
        lockedLiquidity -= payout;

        if ((closeBetDetails.isLong && closePrice >= openPrice) || 
           (!closeBetDetails.isLong && closePrice <= openPrice)) {
            
            (bool success, ) = closeBetDetails.user.call{value: payout}("");
            if (!success) revert PayoutFailed();

            emit BetExecuted(betId, closeBetDetails.user, true, payout);
            return;
        }
        betIds[betId].payout = 0;
        emit BetExecuted(betId, closeBetDetails.user, false, 0);
    }

    /// @notice Cancel a pending bet
    /// @dev If a bet doesn't get executed for a certain amount of time user can withdraw their deposit
    /// @param betId ID of the bet to be cancelled
    function cancelBet(uint256 betId) external {
        BetDetails memory closeBetDetails = betIds[betId];

        if (closeBetDetails.user != msg.sender) revert Unauthorized();
        if (closeBetDetails.endTime + cancelBuffer >= block.timestamp) revert UnelapsedBet(); 
        if (!closeBetDetails.active) revert InactiveBet();

        uint256 amount = closeBetDetails.amount;
        betIds[betId].active = false;
        lockedLiquidity -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert PayoutFailed();
        emit BetCancelled(betId, closeBetDetails.user);
    }

    function getPrice(
        bytes32 pairId,
        bytes memory priceData,
        uint64 timestamp
    ) internal returns (int64, uint256) {
        bytes32[] memory pythPair = new bytes32[](1);
        bytes[] memory pythData = new bytes[](1);
        pythPair[0] = pairId;
        pythData[0] = priceData;

        uint256 fee = pyth.getUpdateFee(pythData);

        PythStructs.PriceFeed memory pythPrice = pyth.parsePriceFeedUpdates{ value: fee }(
            pythData,
            pythPair,
            timestamp,
            timestamp + 5
        )[0];

        if (pythPrice.id != pairId) revert InvalidPrice();
        return (pythPrice.price.price, fee);
    }

    function deposit() external payable whenNotPaused onlyRole(LP_ROLE) {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyRole(LP_ROLE) {
        uint256 unlockedLiquidity = address(this).balance - lockedLiquidity;
        if (amount > unlockedLiquidity) revert InsufficientLiquidity();

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit Withdrawal(msg.sender, amount);
    }

    function availableLiquidity() public view returns (uint256) {
        return maxUtilizedLiquidity - lockedLiquidity;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setAmounts(uint256 _minAmount, uint256 _maxAmount, uint256 _maxUtilzedAmount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_minAmount == 0 || _maxAmount == 0 || _minAmount >= _maxAmount) revert InvalidAmount();
        minBet = _minAmount;
        maxBet = _maxAmount;

        emit UpdatedAmounts(_minAmount, _maxAmount, _maxUtilzedAmount);
    }

    function setIntervals(uint16 _minInterval, uint16 _maxInterval) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_minInterval == 0 || _maxInterval == 0 || _minInterval >= _maxInterval) revert InvalidInterval();
        minInterval = _minInterval;
        maxInterval = _maxInterval;

        emit UpdatedIntervals(minInterval, maxInterval);
    }

    function setLeverage(uint16 _leverage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_leverage == 0) revert InvalidLeverage();
        leverage = _leverage;

        emit UpdatedLeverage(leverage);
    }

    function addPairs(bytes8[] calldata pairs, bytes32[] calldata ids) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 l = pairs.length;
        for (uint256 i; i < l; ++i) {
            if (pairIds[pairs[i]] != 0) revert DuplicatePair(pairs[i]);
            pairIds[pairs[i]] = ids[i];
        }
        emit PairsAdded(pairs, ids);
    }

    function deletePairs(bytes8[] calldata pairs) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 l = pairs.length;
        for (uint256 i; i < l; ++i) {
            pairIds[pairs[i]] = 0;
        }
        emit PairsDeleted(pairs);
    }
}