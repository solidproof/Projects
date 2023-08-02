pragma solidity ^0.8.10;

import "./EIP20Interface.sol";
import "./SafeMath.sol";
import "./CErc20.sol";
import "./BasePriceOracle.sol";

interface IAggregatorV2V3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract ChainlinkPriceOracle is BasePriceOracle {
    using SafeMath for uint;

    mapping(address => IAggregatorV2V3Interface) public feeds;
    event FeedSet(address ctoken, address token, address feed);

    constructor() {
		provider = msg.sender;
    }

    function getUnderlyingPrice(CToken cToken) external override view returns (uint price) {
        address token = _getUnderlyingAddress(cToken);

        if (prices[token] != 0) {
            price = prices[token];
        } else {
            price = _getChainlinkPrice(feeds[address(cToken)]);
        }

        uint decimalDelta = 0;
        if (token != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            decimalDelta = uint(18).sub(uint(EIP20Interface(token).decimals()));
        }

        // Ensure that we don't multiply the result by 0
        if (decimalDelta > 0) {
            return price.mul(10 ** decimalDelta);
        } else {
            return price;
        }
    }

    function _getChainlinkPrice(IAggregatorV2V3Interface feed) internal view returns (uint) {
        uint decimalDelta = uint(18).sub(feed.decimals());

        (, int256 answer, , , ) = feed.latestRoundData();
        if (decimalDelta > 0) {
            return uint(answer).mul(10 ** decimalDelta);
        } else {
            return uint(answer);
        }
    }

    function getChainlinkPrice(address cToken) external view returns (uint price) {
        price = _getChainlinkPrice(feeds[address(cToken)]);
    }

    function setFeed(CToken cToken, address feed) external onlyProvider {
        require(feed != address(0) && feed != address(this), "invalid feed address");
        address token = _getUnderlyingAddress(cToken);
        emit FeedSet(address(cToken), token, feed);
        feeds[address(cToken)] = IAggregatorV2V3Interface(feed);
    }
}