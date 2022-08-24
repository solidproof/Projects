// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;
import '../interfaces/AggregatorV3Interface.sol';
import '../interfaces/Factory.sol';
import '../interfaces/LP.sol';

contract priceFeed {
    AggregatorV3Interface internal priceFeeder;
    address public wbnb = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address public usdt = 0x7ef95a0FEE0Dd31b22626fA2e10Ee6A223F8a684;
    Factory public factory = Factory(0xB7926C0430Afb07AA7DEfDE6DA862aE0Bde767bc);

    constructor() {
        // BNB/USD 
        priceFeeder = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
    }

    function getPriceTokenWBNB(address token) public view returns(uint256) {
        LP _lp = LP(factory.getPair(wbnb, token));
        (uint256 res0, uint256 res1,) = _lp.getReserves();
        if(_lp.token0() == wbnb) {
            return ((res0*1e18) / res1);
        } else {
            return ((res1*1e18) / res0);
        }
    }

    /*\
    gets the ratio of usdt and wbnb
    
    function getPriceWBNBUSDT() public view returns (uint256) {
        (, int price,,,) = priceFeeder.latestRoundData();
        return uint256(price);
    }
    \*/

    /*\
    gets the ratio of usdt and wbnb
    \*/
    function getPriceWBNBUSDT() public view returns(uint256) {
        LP _lp = LP(factory.getPair(wbnb, usdt));
        (uint256 res0, uint256 res1,) = _lp.getReserves();
        if(_lp.token0() == wbnb) {
            return ((res1*1e18) / res0);
        } else {
            return ((res0*1e18) / res1);
        }
    }

    /*\
    gets the ratio of the deposit token and usdt
    \*/
    function getPriceTokenUSDT(address token) public view returns(uint256) {
        return((getPriceTokenWBNB(token) * getPriceWBNBUSDT()) / 1e18);
    }
}
//by telegram: solidityX