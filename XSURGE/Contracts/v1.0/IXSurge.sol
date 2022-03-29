//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/IERC20.sol";
/**
    XSurge Interface
        Supports xSwap Protocol
 */
interface IXSurge is IERC20{

    function exchange(address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) external;
    function burn(uint256 amount) external;
    function mintWithNative(address recipient, uint256 minOut) external payable returns (uint256);
    function mintWithBacking(address backingToken, uint256 numTokens, address recipient) external returns (uint256);
    function requestPromiseTokens(address stable, uint256 amount) external returns (uint256);
    function sell(uint256 tokenAmount) external returns (address, uint256);
    function calculatePrice() external view returns (uint256);
    function getValueOfHoldings(address holder) external view returns(uint256);
    function isUnderlyingAsset(address token) external view returns (bool);
    function getUnderlyingAssets() external view returns(address[] memory);
}