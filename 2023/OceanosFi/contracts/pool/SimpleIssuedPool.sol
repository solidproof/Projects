// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./base/IssuedPoolBase.sol";
import "../interfaces/IPriceCalculator.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SimpleIssuedPool is Initializable, IssuedPoolBase {
    function initialize(
        IOcUSD _ocUsd,
        IERC20 _collateral,
        IController _controller
    ) external initializer {
        _initialize(_ocUsd, _collateral, _controller);
    }

    function getAssetPrice() public view override returns (uint256) {
        return
            IPriceCalculator(controller.getPriceCalculator()).priceOf(
                address(collateralAsset)
            );
    }
}
