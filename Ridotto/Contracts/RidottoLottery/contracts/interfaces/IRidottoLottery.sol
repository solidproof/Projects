// SPDX-License-Identifier: Ridotto Core License

/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*#/@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#(#####/&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*##########(*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//###############/,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*####################((@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@(/#########################//@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@*#############PLAY#############(*@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@*(###############################/(@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@&.###########################,@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@%(#####################/(@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@/(#/,@@@@@@@@@@*.#################*@@@@@@@@@@@%(#/(@@@@@@@@@@@@@@
@@@@@@@@@@@@%,#######/@@@@@@@@@@@((###########*#@@@@@@@@@@@/#######*@@@@@@@@@@@@
@@@@@@@@@@,(###########/,@@@@@@@@@@(.#######,&@@@@@@@@@@%(###########/#@@@@@@@@@
@@@@@@@&,################# @@@@@@@@@@@.(#/(@@@@@@@@@@@/#################*@@@@@@@
@@@@@*(#####################*,@@@@@@@@@@@@@@@@@@@@@/(#####################/*@@@@
@@&*##########################(,@@@@@@@@@@@@@@@@@/###########################*@@
.(#############BUILD#############,*@@@@@@@@@@@#(##############EARN#############/
@###############################(/@@@@@@@@@@@@@*################################
@@@/(#########################/@@@@@@@@@@@@@@@@@@//#########################//@@
@@@@@//####################(/@@@@@@@@@@@@@@@@@@@@@@@*##################### @@@@@
@@@@@@@@@(###############*@@@@@@@@@@@@(###(@@@@@@@@@@@/(###############/ @@@@@@@
@@@@@@@@@@%*##########(*%@@@@@@@@@@/########(.@@@@@@@@@@@.###########.@@@@@@@@@@
@@@@@@@@@@@@@&/#####/&@@@@@@@@@@@(#############,(@@@@@@@@@@#*#####((@@@@@@@@@@@@
@@@@@@@@@@@@@@@**(/@@@@@@@@@@@/##################(.@@@@@@@@@@@,(,@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@(#######################,#@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@#############################(.@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@&(#################################,(@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@#######################################(,@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@.###########################################,@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Ridotto Lottery  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

pragma solidity ^0.8.9;

import "./IRidottoLotteryEvents.sol";

interface IRidottoLottery is IRidottoLotteryEvents {
    enum Status {
        Pending,
        Open,
        Close,
        Claimable
    }
    struct Lottery {
        Status status;
        uint256 startTime;
        uint256 endTime;
        uint256 priceTicketInToken;
        uint256 discountDivisor;
        uint256[6] rewardsBreakdown;
        uint256 treasuryFee;
        uint256[6] tokenPerBracket;
        uint256[6] countWinnersPerBracket;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountCollectedInLotteryToken;
        uint32 finalNumber;
        uint256 incentiveRewards;
    }

    function MAX_INCENTIVE_REWARD() external view returns (uint256);

    function MAX_TREASURY_FEE() external view returns (uint256);

    function MIN_DISCOUNT_DIVISOR() external view returns (uint256);

    function OPERATOR_ROLE() external view returns (bytes32);

    function autoInjection() external view returns (bool);

    function buyForOthers(
        uint256 _lotteryId,
        uint256[] memory _numberOfTickets,
        address[] memory _receivers
    ) external;

    function buyTickets(uint256 _lotteryId, uint8 _number) external;

    function calculateTotalPriceForBulkTickets(
        uint256 _discountDivisor,
        uint256 _priceTicket,
        uint256 _numberTickets
    ) external pure returns (uint256);

    function callCount() external view returns (uint256);

    function changeIncentivePercent(uint256 _incentivePercent) external;

    function changeLotteryParams(
        uint256 _startTime,
        uint256 _priceTicketInLotteryToken,
        uint256 _discountDivisor,
        uint256[6] memory _rewardsBreakdown,
        uint256 _treasuryFee
    ) external;

    function changeLotteryPeriodicity(uint256 _lotteryPeriodicity) external;

    function claimTickets(
        uint256 _lotteryId,
        uint256[] memory _ticketIds,
        uint32[] memory _brackets
    ) external;

    function closeLottery(uint256 _lotteryId) external;

    function currentLotteryId() external view returns (uint256);

    function currentTicketId() external view returns (uint256);

    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId
    ) external;

    function gasLimit() external view returns (uint256);

    function getRandomNumbers(
        address _from,
        uint256 _count
    ) external view returns (uint32[] memory);

    function getTime() external view returns (uint256);

    function incentivePercent() external view returns (uint256);

    function init() external;

    function injectFunds(uint256 _lotteryId, uint256 _amount) external;

    function injectorAddress() external view returns (address);

    function keyHash() external view returns (bytes32);

    function lotteryPeriodicity() external view returns (uint256);

    function maxNumberReceiversBuyForOthers() external view returns (uint256);

    function maxNumberTicketsBuyForOthers() external view returns (uint256);

    function maxNumberTicketsPerBuy() external view returns (uint256);

    function maxNumberTicketsPerClaim() external view returns (uint256);

    function maxTicketPrice() external view returns (uint256);

    function minLotteryPeriodicity() external view returns (uint256);

    function minTicketPrice() external view returns (uint256);

    function nextLotteryParamchanged() external view returns (bool);

    function pause() external;

    function pendingInjectionNextLottery() external view returns (uint256);

    function providerCallParam() external view returns (bytes memory);

    function providerId() external view returns (uint256);

    function recoverWrongTokens(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external;

    function reqIds(uint256) external view returns (uint256);

    function setAutoInjection(bool _autoInjection) external;

    function setChainlinkCallParams(
        bytes32 _keyHash,
        uint256 _subId,
        uint256 _minimumRequestConfirmations,
        uint256 _gasLimit,
        uint256 _numWords
    ) external;

    function setLoterryMinPeriodicity(uint256 _minLotteryPeriodicity) external;

    function setMaxBuyForOthers(
        uint256 _maxNumberTicketsBuyForOthers,
        uint256 _maxNumberReceiversBuyForOthers
    ) external;

    function setMaxNumberTicketsPerBuy(
        uint256 _maxNumberTicketsPerBuy
    ) external;

    function setMaxNumberTicketsPerClaim(
        uint256 _maxNumberTicketsPerClaim
    ) external;

    function setMinAndMaxTicketPriceInLotteryToken(
        uint256 _minPriceTicketInLotteryToken,
        uint256 _maxPriceTicketInLotteryToken
    ) external;

    function setRngProvider(address _rng, uint256 _piD) external;

    function setTreasuryAddress(address _treasuryAddress) external;

    function startInitialRound(
        address _TokenAddress,
        uint256 _lotteryPeriodicity,
        uint256 _incentivePercent,
        uint256 _priceTicketInLotteryToken,
        uint256 _discountDivisor,
        uint256[6] memory _rewardsBreakdown,
        uint256 _treasuryFee
    ) external;

    function startLottery() external;

    function subId() external view returns (uint256);

    function treasuryAddress() external view returns (address);

    function unPause() external;

    function viewLottery(
        uint256 _lotteryId
    ) external view returns (Lottery memory);

    function viewNumbersAndStatusesForTicketIds(
        uint256[] memory _ticketIds
    ) external view returns (uint32[] memory, bool[] memory);

    function viewRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) external view returns (uint256);

    function viewUserInfoForLotteryId(
        address _user,
        uint256 _lotteryId,
        uint256 _cursor,
        uint256 _size
    )
        external
        view
        returns (uint256[] memory, uint32[] memory, bool[] memory, uint256);
}
