// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

import "../../interfaces/IGmxRouter.sol";

import "../../interfaces/IWETH.sol";
import "../../components/ImplementationGuard.sol";
import "./Storage.sol";
import "./Config.sol";
import "./Position.sol";

contract GMXAdapter is Position, Config, ImplementationGuard, ReentrancyGuardUpgradeable{
    using MathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.Bytes32ToBytes32Map;

    address internal immutable _WETH;

    event Withdraw(
        address collateralAddress,
        address account,
        uint256 balance
    );

    constructor(address weth) ImplementationGuard() {
        _WETH = weth;
    }

    receive() external payable {}

    modifier onlyTraderOrFactory() {
        require(msg.sender == _account.account || msg.sender == _factory, "OnlyTraderOrFactory");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == _factory, "onlyFactory");
        _;
    }

    function initialize(
        uint256 exchangeId,
        address account,
        address collateralToken,
        address assetToken,
        bool isLong
    ) external initializer onlyDelegateCall {
        require(exchangeId == EXCHANGE_ID, "Invalidexchange");

        _factory = msg.sender;
        _gmxPositionKey = keccak256(abi.encodePacked(address(this), collateralToken, assetToken, isLong));

        _account.account = account;
        _account.collateralToken = collateralToken;
        _account.indexToken = assetToken;
        _account.isLong = isLong;
        _account.collateralDecimals = IERC20MetadataUpgradeable(collateralToken).decimals();
        _updateConfigs();
    }

    function accountState() external view returns (AccountState memory) {
        return _account;
    }

    function getPendingOrderKeys() external view returns (bytes32[] memory) {
        return _getPendingOrders();
    }

    function getPositionKey() external view returns(bytes32){
        return _gmxPositionKey;
    }

    function getOrder(bytes32 orderKey) external view returns(bool isFilled, LibGmx.OrderHistory memory history){
        (isFilled, history) = LibGmx.getOrder(_exchangeConfigs, orderKey);
    }

    function _tryApprovePlugins() internal {
        IGmxRouter(_exchangeConfigs.router).approvePlugin(_exchangeConfigs.orderBook);
        IGmxRouter(_exchangeConfigs.router).approvePlugin(_exchangeConfigs.positionRouter);
    }

    function _isMarketOrder(uint8 flags) internal pure returns (bool) {
        return (flags & POSITION_MARKET_ORDER) != 0;
    }

    function openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd,
        uint96 slPriceUsd,
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _tryApprovePlugins();
        _cleanOrders();

        bytes32 orderKey;
        orderKey = _openPosition(
            swapInToken,
            swapInAmount, // tokenIn.decimals
            minSwapOut, // collateral.decimals
            sizeUsd, // 1e18
            priceUsd, // 1e18
            flags // MARKET, TRIGGER
        );

        if (flags & POSITION_TPSL_ORDER > 0) {
            bytes32 tpOrderKey;
            bytes32 slOrderKey;
            if (tpPriceUsd > 0) {
                tpOrderKey = _closePosition(0, sizeUsd, tpPriceUsd, 0);
            }
            if (slPriceUsd > 0) {
                slOrderKey = _closePosition(0, sizeUsd, slPriceUsd, 0);
            }
            _openTpslOrderIndexes.set(orderKey, LibGmx.encodeTpslIndex(tpOrderKey, slOrderKey));
        }
    }

    function _openPosition(
        address swapInToken,
        uint256 swapInAmount, // tokenIn.decimals
        uint256 minSwapOut, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) internal returns(bytes32 orderKey){

        _updateConfigs();
        _tryApprovePlugins();
        _cleanOrders();

        OpenPositionContext memory context = OpenPositionContext({
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            fee: 0,
            amountIn: 0,
            amountOut: 0,
            gmxOrderIndex: 0,
            executionFee: msg.value
        });
        if (swapInToken == _WETH) {
            IWETH(_WETH).deposit{ value: swapInAmount }();
            context.executionFee = msg.value - swapInAmount;
        }
        if (swapInToken != _account.collateralToken) {
            context.amountOut = LibGmx.swap(
                _exchangeConfigs,
                swapInToken,
                _account.collateralToken,
                swapInAmount,
                minSwapOut
            );
        } else {
            context.amountOut = swapInAmount;
        }
        context.amountIn = context.amountOut;
        IERC20Upgradeable(_account.collateralToken).approve(_exchangeConfigs.router, context.amountIn);

        return _openPosition(context);
    }

    /// @notice Place a closing request on GMX.
    function closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint96 tpPriceUsd, // 1e18
        uint96 slPriceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) external payable onlyTraderOrFactory nonReentrant {

        _updateConfigs();
        _cleanOrders();

        if (flags & POSITION_TPSL_ORDER > 0) {
            if (_account.isLong) {
                require(tpPriceUsd >= slPriceUsd, "WrongPrice");
            } else {
                require(tpPriceUsd <= slPriceUsd, "WrongPrice");
            }
            bytes32 tpOrderKey = _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                tpPriceUsd, // 1e18
                0 // MARKET, TRIGGER
            );
            _closeTpslOrderIndexes.add(tpOrderKey);
            bytes32 slOrderKey = _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                slPriceUsd, // 1e18
                0 // MARKET, TRIGGER
            );
            _closeTpslOrderIndexes.add(slOrderKey);
        } else {
            _closePosition(
                collateralUsd, // collateral.decimals
                sizeUsd, // 1e18
                priceUsd, // 1e18
                flags // MARKET, TRIGGER
            );
        }
    }

    /// @notice Place a closing request on GMX.
    function _closePosition(
        uint256 collateralUsd, // collateral.decimals
        uint256 sizeUsd, // 1e18
        uint96 priceUsd, // 1e18
        uint8 flags // MARKET, TRIGGER
    ) internal returns (bytes32 orderKey)  {

        _updateConfigs();
        _cleanOrders();

        ClosePositionContext memory context = ClosePositionContext({
            collateralUsd: collateralUsd * GMX_DECIMAL_MULTIPLIER,
            sizeUsd: sizeUsd * GMX_DECIMAL_MULTIPLIER,
            priceUsd: priceUsd * GMX_DECIMAL_MULTIPLIER,
            isMarket: _isMarketOrder(flags),
            gmxOrderIndex: 0,
            executionFee: 0
        });
        return _closePosition(context);
    }

    function updateOrder(
        bytes32 orderKey,
        uint256 collateralDelta,
        uint256 sizeDelta,
        uint256 triggerPrice,
        bool triggerAboveThreshold
    ) external onlyTraderOrFactory nonReentrant {
        _updateConfigs();
        _cleanOrders();

        LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(orderKey);
        if (history.receiver == LibGmx.OrderReceiver.OB_INC) {
            IGmxOrderBook(_exchangeConfigs.orderBook).updateIncreaseOrder(
                history.index,
                sizeDelta * GMX_DECIMAL_MULTIPLIER,
                triggerPrice * GMX_DECIMAL_MULTIPLIER,
                triggerAboveThreshold
            );
        } else if (history.receiver == LibGmx.OrderReceiver.OB_DEC) {
            IGmxOrderBook(_exchangeConfigs.orderBook).updateDecreaseOrder(
                history.index,
                collateralDelta * GMX_DECIMAL_MULTIPLIER,
                sizeDelta * GMX_DECIMAL_MULTIPLIER,
                triggerPrice * GMX_DECIMAL_MULTIPLIER,
                triggerAboveThreshold
            );
        } else {
            revert("InvalidOrderType");
        }
    }

    function withdraw() external nonReentrant {
        _updateConfigs();
        _cleanOrders();

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            if (_account.collateralToken == _WETH) {
                IWETH(_WETH).deposit{ value: ethBalance }();
            } else {
                AddressUpgradeable.sendValue(payable(_account.account), ethBalance);
                emit Withdraw(
                    _account.collateralToken,
                    _account.account,
                    ethBalance
                );
            }
        }

        uint256 balance = IERC20Upgradeable(_account.collateralToken).balanceOf(address(this));
        //ToDo - should we check if margin is safe?
        if (balance > 0) {
            _transferToUser(balance);
                emit Withdraw(
                _account.collateralToken,
                _account.account,
                balance
            );
        }
        // clean tpsl orders
        _cleanTpslOrders();
    }

    function _transferToUser(uint256 amount) internal {
        if (_account.collateralToken == _WETH) {
            IWETH(_WETH).withdraw(amount);
            Address.sendValue(payable(_account.account), amount);
        } else {
            IERC20Upgradeable(_account.collateralToken).safeTransfer(_account.account, amount);
        }
    }

    function cancelOrders(bytes32[] memory keys) external onlyTraderOrFactory nonReentrant {
        _cleanOrders();
        _cancelOrders(keys);
    }

    function _cancelOrders(bytes32[] memory keys) internal {
        for (uint256 i = 0; i < keys.length; i++) {
            bool success = _cancelOrder(keys[i]);
            require(success, "CancelFailed");
        }
    }

    function cancelTimeoutOrders(bytes32[] memory keys) external nonReentrant {
        _cleanOrders();
        _cancelTimeoutOrders(keys);
    }

    function _cancelTimeoutOrders(bytes32[] memory keys) internal {
        uint256 _now = block.timestamp;
        uint256 marketTimeout = _exchangeConfigs.marketOrderTimeoutSeconds;
        uint256 limitTimeout = _exchangeConfigs.limitOrderTimeoutSeconds;
        for (uint256 i = 0; i < keys.length; i++) {
            bytes32 orderKey = keys[i];
            LibGmx.OrderHistory memory history = LibGmx.decodeOrderHistoryKey(orderKey);
            uint256 elapsed = _now - history.timestamp;
            if (
                ((history.receiver == LibGmx.OrderReceiver.PR_INC || history.receiver == LibGmx.OrderReceiver.PR_DEC) &&
                    elapsed >= marketTimeout) ||
                ((history.receiver == LibGmx.OrderReceiver.OB_INC || history.receiver == LibGmx.OrderReceiver.OB_DEC) &&
                    elapsed >= limitTimeout)
            ) {
                if (_cancelOrder(orderKey)) {
                    _cancelTpslOrders(orderKey);
                }
            }
        }
    }

    function _cleanOrders() internal {
        bytes32[] memory pendingKeys = _pendingOrders.values();
        for (uint256 i = 0; i < pendingKeys.length; i++) {
            bytes32 key = pendingKeys[i];
            (bool notExist, ) = LibGmx.getOrder(_exchangeConfigs, key);
            if (notExist) {
                _removePendingOrder(key);
            }
        }
    }

    function _cleanTpslOrders() internal {
        // open tpsl orders
        uint256 openLength = _openTpslOrderIndexes.length();
        bytes32[] memory openKeys = new bytes32[](openLength);
        for (uint256 i = 0; i < openLength; i++) {
            (openKeys[i], ) = _openTpslOrderIndexes.at(i);
        }
        for (uint256 i = 0; i < openLength; i++) {
            // clean all tpsl orders paired with orders that already filled
            if (!_pendingOrders.contains(openKeys[i])) {
                _cancelTpslOrders(openKeys[i]);
            }
        }
        // close tpsl orders
        uint256 closeLength = _closeTpslOrderIndexes.length();
        bytes32[] memory closeKeys = new bytes32[](closeLength);
        for (uint256 i = 0; i < closeLength; i++) {
            closeKeys[i] = _closeTpslOrderIndexes.at(i);
        }
        for (uint256 i = 0; i < closeLength; i++) {
            // clean all tpsl orders paired with orders that already filled
            if (_pendingOrders.contains(closeKeys[i])) {
                _cancelOrder(closeKeys[i]);
            }
        }
    }
}