// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./IJackpotGuard.sol";
import "./Ownable.sol";

abstract contract JackpotToken is Ownable {
    using Address for address;

    // 100%
    uint256 internal constant MAX_PCT = 10000;
    uint256 internal constant BNB_DECIMALS = 18;
    uint256 internal constant USDT_DECIMALS = 18;
    address internal constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address internal constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // PCS takes 0.25% fee on all txs
    uint256 private constant ROUTER_FEE = 25;

    uint256 private constant JACKPOT_TIMESPAN_LIMIT_MIN = 20;

    // Jackpot related variables
    // 55.55% jackpot cashout to last buyer
    uint256 public jackpotCashout = 5555;
    // 90% of jackpot cashout to last buyer
    uint256 public jackpotBuyerShare = 9000;
    // Buys > 0.1 BNB will be eligible for the jackpot
    uint256 public jackpotMinBuy = 1 * 10**(BNB_DECIMALS - 1);
    // Jackpot time span is initially set to 10 mins
    uint256 public jackpotTimespan = 10 * 60;
    // Jackpot hard limit, USD value, $100K
    uint256 public jackpotHardLimit = 100000 * 10**(USDT_DECIMALS);
    // Jackpot hard limit buyback share
    uint256 public jackpotHardBuyback = 5000;

    address payable internal _lastBuyer = payable(address(this));
    uint256 internal _lastBuyTimestamp = 0;

    address internal _lastAwarded = address(0);
    uint256 internal _lastAwardedCash = 0;
    uint256 internal _lastAwardedTokens = 0;
    uint256 internal _lastAwardedTimestamp = 0;

    uint256 internal _lastBigBangCash = 0;
    uint256 internal _lastBigBangTokens = 0;
    uint256 internal _lastBigBangTimestamp = 0;

    // Total BNB/JUNI collected by the jackpot
    uint256 internal _totalJackpotCashedOut = 0;
    uint256 internal _totalJackpotTokensOut = 0;
    uint256 internal _totalJackpotBuyer = 0;
    uint256 internal _totalJackpotBuyback = 0;
    uint256 internal _totalJackpotBuyerTokens = 0;
    uint256 internal _totalJackpotBuybackTokens = 0;

    bool public jackpotEnabled = true;

    address public uniswapV2Pair;
    IUniswapV2Router02 public uniswapV2Router;

    event JackpotAwarded(
        address winner,
        uint256 cashedOut,
        uint256 tokensOut,
        uint256 buyerShare,
        uint256 tokensToBuyer,
        uint256 toBuyback,
        uint256 tokensToBuyback
    );
    event BigBang(uint256 cashedOut, uint256 tokensOut);

    event JackpotMinBuyChanged(uint256 jackpotMinBuy);

    event JackpotFeaturesChanged(
        uint256 jackpotCashout,
        uint256 jackpotBuyerShare
    );

    event JackpotTimespanChanged(uint256 jackpotTimespan);

    event BigBangFeaturesChanged(
        uint256 jackpotHardBuyback,
        uint256 jackpotHardLimit
    );

    event JackpotFund(uint256 bnbSent, uint256 tokenAmount);

    event JackpotStatusChanged(bool status);

    event LiquidityRouterChanged(address router);

    event LiquidityPairChanged(address pair);

    constructor() Ownable(msg.sender) {
        uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E
        );
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
    }

    function setUniswapRouter(address otherRouterAddress) external onlyOwner {
        uniswapV2Router = IUniswapV2Router02(otherRouterAddress);

        emit LiquidityRouterChanged(otherRouterAddress);
    }

    function setUniswapPair(address otherPairAddress) external onlyOwner {
        require(
            otherPairAddress != address(0),
            "You must supply a non-zero address"
        );
        uniswapV2Pair = otherPairAddress;

        emit LiquidityPairChanged(otherPairAddress);
    }

    function awardJackpot() internal virtual;

    function processBigBang() internal virtual;

    function resetJackpot() internal {
        _lastBuyTimestamp = 0;
        _lastBuyer = payable(address(this));
    }

    function setJackpotStatus(bool status) external onlyAuthorized {
        jackpotEnabled = status;
        resetJackpot();
        emit JackpotStatusChanged(status);
    }

    function totalJackpotStats()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _totalJackpotCashedOut,
            _totalJackpotTokensOut,
            _totalJackpotBuyer,
            _totalJackpotBuyerTokens,
            _totalJackpotBuyback,
            _totalJackpotBuybackTokens
        );
    }

    function setJackpotMinBuy(uint256 _jackpotMinBuy) external onlyAuthorized {
        jackpotMinBuy = _jackpotMinBuy;

        resetJackpot();

        emit JackpotMinBuyChanged(jackpotMinBuy);
    }

    function setJackpotFeatures(
        uint256 _jackpotCashout,
        uint256 _jackpotBuyerShare
    ) external onlyAuthorized {
        require(
            _jackpotCashout <= MAX_PCT,
            "Percentage amount needs to be less than or equal 100%"
        );
        require(
            _jackpotBuyerShare <= MAX_PCT,
            "Percentage amount needs to be less than or equal 100%"
        );
        jackpotCashout = _jackpotCashout;
        jackpotBuyerShare = _jackpotBuyerShare;

        emit JackpotFeaturesChanged(jackpotCashout, jackpotBuyerShare);
    }

    function setJackpotHardFeatures(
        uint256 _jackpotHardBuyback,
        uint256 _jackpotHardLimit
    ) external onlyAuthorized {
        require(
            _jackpotHardBuyback <= MAX_PCT,
            "Jackpot hard buyback percentage needs to be between 30% and 70%"
        );
        jackpotHardBuyback = _jackpotHardBuyback;
        jackpotHardLimit = _jackpotHardLimit;

        emit BigBangFeaturesChanged(jackpotHardBuyback, jackpotHardLimit);
    }

    function setJackpotTimespanInSeconds(uint256 _jackpotTimespan)
        external
        onlyAuthorized
    {
        require(
            _jackpotTimespan >= JACKPOT_TIMESPAN_LIMIT_MIN,
            "Jackpot timespan needs to be greater than 20 seconds"
        );
        jackpotTimespan = _jackpotTimespan;
        resetJackpot();

        emit JackpotTimespanChanged(jackpotTimespan);
    }

    function usdEquivalent(uint256 bnbAmount) public view returns (uint256) {
        if (bnbAmount == 0) {
            return 0;
        }
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = USDT;

        return uniswapV2Router.getAmountsOut(bnbAmount, path)[1];
    }

    function getLastBuy() public view returns (address, uint256) {
        return (_lastBuyer, _lastBuyTimestamp);
    }

    function getLastAwarded()
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _lastAwarded,
            _lastAwardedCash,
            _lastAwardedTokens,
            _lastAwardedTimestamp
        );
    }

    function getLastBigBang()
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (_lastBigBangCash, _lastBigBangTokens, _lastBigBangTimestamp);
    }
}
