// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract HLAWPrizePool is Ownable {
    using Address for address;

    struct Sessions {
        uint256 sessionId;
        uint256 startTime;
        uint256 initialLength;
        uint256 lengthIncrement;
        uint256 maxLength;
        uint256 endsAt;
        uint256 numOfWinners;
        uint256[] prizePercents;
        address[] winners;
        uint256[] winnerBuyAmounts;
        uint256[] prizeAmounts;
        uint256 minBuySize;
        bool forceEnd;
        bool ended;
        bool paid;
        bool autoPay;
    }

    struct Buyers {
        uint256 index;
        address buyer;
        uint256 amount;
        uint256 timestamp;
    }

    IERC20 public hlawToken;
    address public hlawExchange;
    address public signer;
    uint256 public rewardsPaid;
    uint256 public lastRewardTime;
    uint256 public maxPayoutPercent = 2000;
    uint256 public sessionIndex;
    uint256 public buyersIndex;
    uint256 private constant denominator = 10000;

    mapping(uint256 => Sessions) public sessions;
    mapping(uint256 => Buyers) public buyers;

    bool public isSessionActive;

    event SessionStarted(uint256 sessionId);
    event SessionEnded(uint256 sessionId);
    event WinnersDistributed(address[] winners, uint256[] amounts, uint256 sessionIndex);
    event SignerUpdated(address signer);
    event DistributeLimitsUpdated(uint256 maxPercent);

    /**
     * @dev Constructor that sets the HLAW token address.
     * @param _hlawToken Address of the HLAW token contract.
     */
    constructor(address _hlawToken, address _hlawExchange) Ownable(msg.sender) {
        hlawToken = IERC20(_hlawToken);
        hlawExchange = _hlawExchange;
        signer = msg.sender;
    }

    /**
     * @dev Starts a new prize session.
     * @param startTime The epoch timestamp the event will start.
     * @param initialLength The initial length of the event in seconds.
     * @param lengthIncrement The amount of seconds to add per buy.
     * @param maxLength The max length remaining allowed.
     * @param numOfWinners The number of winners who will be paid.
     */

    function startSession(
        uint256 startTime,
        uint256 initialLength,
        uint256 lengthIncrement,
        uint256 maxLength,
        uint256 numOfWinners,
        uint256[] memory prizes,
        uint256 minBuySize,
        bool autoPay
    ) external {
        require(msg.sender == signer || msg.sender == owner(), "Only signer or owner can startSession.");
        require(sessions[sessionIndex].startTime == 0, "The current session is not over yet.");
        require(startTime >= block.timestamp, "Event start must be in the future.");
        require(initialLength >= 60, "Minimum 10 minute initial length");
        require(initialLength <= maxLength, "Minimum 10 minute initial length");
        require(numOfWinners <= 10, "Only ten winners max.");
        require(numOfWinners == prizes.length, "Prizes and winners mismatch");

        uint256 totalPrizes = 0;
        for (uint256 i = 0; i < prizes.length; i++) {
            totalPrizes += prizes[i];
        }

        require(totalPrizes <= maxPayoutPercent, "Total prize percents exceed the maximum payout percent allowed.");

        sessions[sessionIndex].startTime = startTime;
        sessions[sessionIndex].initialLength = initialLength;
        sessions[sessionIndex].lengthIncrement = lengthIncrement;
        sessions[sessionIndex].maxLength = maxLength;
        sessions[sessionIndex].endsAt = startTime + initialLength;
        sessions[sessionIndex].numOfWinners = numOfWinners;
        sessions[sessionIndex].minBuySize = minBuySize;
        sessions[sessionIndex].autoPay = autoPay;

        for (uint256 i = 0; i < prizes.length; i++) {
            sessions[sessionIndex].prizePercents.push(prizes[i]);
        }

        isSessionActive = true;

        emit SessionStarted(sessionIndex);
    }

    /**
     * @dev Allows owner to force end a session, forcing it to end after 24 more hours.
     * @param _sessionId The epoch timestamp the event will start.
     * @param _forceEndTime The initial length of the event in seconds.
     */

    function forceEnd(
        uint256 _sessionId,
        uint256 _forceEndTime
    ) external onlyOwner {
        require(_forceEndTime - 86400 >= block.timestamp, "Force end must be atleast 24 hours in the future.");
        sessions[_sessionId].endsAt = _forceEndTime;
        sessions[_sessionId].forceEnd = true;
    }

    /**
     * @dev Distributes HLAW tokens to multiple winners.
     */

    function distributeWinners() external {
        require(msg.sender == signer || msg.sender == owner(), "Only signer or owner can distributeWinners");
        require(sessions[sessionIndex].ended == true || block.timestamp > sessions[sessionIndex].endsAt, "The session has not ended yet.");
        require(sessions[sessionIndex].paid == false, "The session has already been paid.");

        address[] memory winnersSubset = new address[](10);
        uint256[] memory amountsSubset = new uint256[](10);

        for (uint256 k = 0; k < 10; k++) { 
            winnersSubset[k] = (k > sessions[sessionIndex].winners.length - 1) ? address(0) : sessions[sessionIndex].winners[k]; 
            amountsSubset[k] = (k > sessions[sessionIndex].numOfWinners - 1) ? 0 : (sessions[sessionIndex].prizePercents[k] * hlawToken.balanceOf(address(this))) / denominator; 
        }

        for (uint256 i = 0; i < sessions[sessionIndex].numOfWinners; i++) {
            if (amountsSubset[i] == 0 || winnersSubset[i] == address(0)) {
                continue;
            }
            
            hlawToken.transfer(winnersSubset[i], amountsSubset[i]);
            rewardsPaid += amountsSubset[i];
        }

        sessions[sessionIndex].paid = true;
        lastRewardTime = block.timestamp;
        sessionIndex++;

        emit WinnersDistributed(winnersSubset, amountsSubset, sessionIndex - 1);
    }

    /**
     * @dev Sets the signer address.
     * @param _signer Address of the new signer.
     */
    
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid address set.");
        signer = _signer;

        emit SignerUpdated(_signer);
    }

    /**
     * @dev Sets reward distribute limits.
     * @param _newMaxPercent new max percent of contract balance that can be rewarded in one distribution.
     */
    
    function setDistributeLimits(uint256 _newMaxPercent) external onlyOwner {
        maxPayoutPercent = _newMaxPercent;
        require(maxPayoutPercent <= 10000, "Max 10000 maxPayoutPercent for 100 percent.");

        emit DistributeLimitsUpdated(_newMaxPercent);
    }

    /**
     * @dev Deposits HLAW to prize pool contract.
     * @param user The user of the deposit.
     * @param amount The amount being deposited.
     */
    
    function addBuyer(
        address user,
        uint256 amount
    ) external {
        require(msg.sender == hlawExchange, "Only HLAW Exchange can use deposit function.");

        if (sessions[sessionIndex].ended || sessions[sessionIndex].startTime == 0 || sessions[sessionIndex].startTime > block.timestamp) {
            _addBuyer(user, amount);
            return;
        }

        if (block.timestamp >= sessions[sessionIndex].endsAt) {
            sessions[sessionIndex].ended = true;
            isSessionActive = false;
            _selectWinners();
            _calculatePrizeAmounts();

            emit SessionEnded(sessionIndex);

            if (sessions[sessionIndex].autoPay) {
                _autoDistribute();
            }
            _addBuyer(user, amount);

        } else if (amount >= sessions[sessionIndex].minBuySize) {
            if (!sessions[sessionIndex].forceEnd) {
                uint256 initialEndAt = sessions[sessionIndex].startTime + sessions[sessionIndex].initialLength;
                uint256 newEndAt = Math.min(
                    sessions[sessionIndex].endsAt + sessions[sessionIndex].lengthIncrement,
                    block.timestamp + sessions[sessionIndex].maxLength
                );
                sessions[sessionIndex].endsAt = Math.max(initialEndAt, newEndAt);
            }
            _addBuyer(user, amount);
        }
    }

    /**
     * @dev Internal function to add a buyer and increment index.
     */

    function _addBuyer(address user, uint256 amount) internal {
        buyers[buyersIndex] = Buyers({ index: buyersIndex, buyer: user, amount: amount, timestamp: block.timestamp });
        buyersIndex++;
    }

    /**
     * @dev Internal function to select up to 10 winners in reverse order from recent buyers.
     */

    function _selectWinners() internal {
        uint256 startIdx = buyersIndex >= 10 ? buyersIndex - 10 : 0;

        for (uint256 i = buyersIndex - 1; i >= startIdx; i--) {
            if (buyers[i].buyer != address(0)) {
                sessions[sessionIndex].winners.push(buyers[i].buyer);
                sessions[sessionIndex].winnerBuyAmounts.push(buyers[i].amount);
            }
            if (i == startIdx) break;
        }
    }

    /**
     * @dev Internal function to calculate prize amounts for `numOfWinners`.
     */

    function _calculatePrizeAmounts() internal {
        uint256 prizeCount = sessions[sessionIndex].numOfWinners < sessions[sessionIndex].prizePercents.length 
            ? sessions[sessionIndex].numOfWinners 
            : sessions[sessionIndex].prizePercents.length;

        for (uint256 j = 0; j < prizeCount; j++) {
            uint256 prizeAmount = (sessions[sessionIndex].prizePercents[j] * hlawToken.balanceOf(address(this))) / denominator;
            sessions[sessionIndex].prizeAmounts.push(prizeAmount);
        }
    }

    /**
     * @dev Internal function to auto-distribute prizes to the session winners.
     */

    function _autoDistribute() internal {
        address[] memory winnersSubset = new address[](10);
        uint256[] memory amountsSubset = new uint256[](10);

        for (uint256 k = 0; k < 10; k++) { 
            winnersSubset[k] = (k > sessions[sessionIndex].winners.length - 1) ? address(0) : sessions[sessionIndex].winners[k]; 
            amountsSubset[k] = (k > sessions[sessionIndex].numOfWinners - 1) ? 0 : (sessions[sessionIndex].prizePercents[k] * hlawToken.balanceOf(address(this))) / denominator; 
        }

        for (uint256 i = 0; i < sessions[sessionIndex].numOfWinners; i++) {
            if (amountsSubset[i] == 0 || winnersSubset[i] == address(0)) {
                continue;
            }
            
            hlawToken.transfer(winnersSubset[i], amountsSubset[i]);
            rewardsPaid += amountsSubset[i];
        }

        sessions[sessionIndex].paid = true;
        lastRewardTime = block.timestamp;
        sessionIndex++;

        emit WinnersDistributed(winnersSubset, amountsSubset, sessionIndex - 1);
    }

    /**
     * @dev View function to return the most recent numberOfBuyers amount of buyers.
     * @param numberOfBuyers The number of buyers you would like to fetch back and receive.
     */

    function getLastBuyers(uint256 numberOfBuyers) external view returns (address[] memory buyersList, uint256[] memory amountsList) {
        uint256 availableBuyers = buyersIndex > numberOfBuyers ? numberOfBuyers : buyersIndex;

        buyersList = new address[](availableBuyers);
        amountsList = new uint256[](availableBuyers);

        for (uint256 i = 0; i < availableBuyers; i++) {
            uint256 index = buyersIndex - 1 - i;
            buyersList[i] = buyers[index].buyer;
            amountsList[i] = buyers[index].amount;
        }
    }

    /**
     * @dev View function to return the most recent numberOfBuyers amount of buyers.
     * @param from The from index number of buyers you would like to fetch back and receive.
     * @param to The to number of buyers you would like to fetch to and receive.
     */

    function getBuyersInRange(uint256 from, uint256 to) external view returns (uint256[] memory indexList, address[] memory buyersList, uint256[] memory amountsList) {
        require(from <= to, "Invalid index range");
        require(to < buyersIndex, "to out of bounds");

        uint256 range = to - from + 1;

        indexList = new uint256[](range);
        buyersList = new address[](range);
        amountsList = new uint256[](range);

        for (uint256 i = 0; i < range; i++) {
            uint256 index = to - i;
            indexList[i] = buyers[index].index;
            buyersList[i] = buyers[index].buyer;
            amountsList[i] = buyers[index].amount;
        }
    }

    /**
    * @dev View function to return the winners, prize amounts, and prize percents of a specified session.
    * @param _sessionIndex The index of the session you want to retrieve data from.
    */
    function getSessionInfo(uint256 _sessionIndex) external view returns (
        address[] memory winners,
        uint256[] memory winnerBuyAmounts,
        uint256[] memory prizes,
        uint256[] memory prizePercents
    ) {
        require(_sessionIndex <= sessionIndex, "Invalid session index");

        Sessions storage session = sessions[_sessionIndex];
        
        winners = session.winners;
        winnerBuyAmounts = session.winnerBuyAmounts;
        prizes = session.prizeAmounts;
        prizePercents = session.prizePercents;
    }
}