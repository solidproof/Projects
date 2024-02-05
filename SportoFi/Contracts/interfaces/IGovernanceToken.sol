//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./ITreasury.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IWrappedNative is IERC20Upgradeable {
    function deposit() external payable;
}

interface IGovernanceToken {
    event TaxStatusSet(bool indexed status);
    event StatusSet(address indexed account, bool indexed status);
    event PoolSet(IUniswapV2Pair indexed from, IUniswapV2Pair indexed to);

    function initialize(
        address admin_,
        string calldata name_,
        string calldata symbol_,
        ITreasury treasury_,
        IWrappedNative wrappedNative_,
        AggregatorV3Interface priceFeed_
    ) external;

    function transferFromWithTaxes(
        address from_,
        address to_,
        uint256 amount_
    ) external payable returns (bool);

    function transferWithTaxes(
        address to_,
        uint256 amount_
    ) external payable returns (bool);

    function toggleTaxes() external;

    function setPool(IUniswapV2Pair pool_) external;

    function setUserStatus(address account_, bool status_) external;

    function nativeTax(uint256 amount_) external view returns (uint256);

    function isBlacklisted(address account_) external view returns (bool);
}