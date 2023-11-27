// if vault generate yield, this contract manage it

pragma solidity ^0.8.17;

import "./IssuedPoolBase.sol";

abstract contract YieldAdapterIssuedPool is IssuedPoolBase {
    function _initialize(
        IOcUSD _ocUsd,
        IERC20 _collateral,
        IController _controller
    ) internal virtual override {
        super._initialize(_ocUsd, _collateral, _controller);
        isYieldAdapter = true;
    }

    function processYield() external virtual {
        _claimYield();
    }

    function _claimYield() internal virtual {}

    function _depositToYieldPool(uint256 amount) internal virtual {}

    function _withdrawFromYieldPool(uint256 amount) internal virtual {}

    uint256[50] private __gap;
}
