// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IController.sol";
import "../../interfaces/IIssuedPoolBase.sol";
import "../../interfaces/IOcUSD.sol";
import "../../interfaces/IERC20Detailed.sol";

abstract contract IssuedPoolBase is IIssuedPoolBase {
    IController public controller;

    IOcUSD public ocUsd;
    IERC20 public collateralAsset;

    uint256 public poolIssuedOcUSD; // exclude fee

    mapping(address => uint256) public collateralAmount;
    mapping(address => uint256) public borrowedPrincipalAmount;
    mapping(address => uint256) feeStored;
    mapping(address => uint256) feeUpdatedAt;

    bool public isYieldAdapter;

    function _initialize(
        IOcUSD _ocUsd,
        IERC20 _collateral,
        IController _controller
    ) internal virtual {
        ocUsd = _ocUsd;
        collateralAsset = _collateral;
        controller = _controller;
    }

    function totalCollateralAmount() public view virtual returns (uint256) {
        return
            address(collateralAsset) == address(0)
                ? address(this).balance
                : collateralAsset.balanceOf(address(this));
    }

    function mint(
        uint256 assetAmount,
        uint256 mintAmount
    ) external payable virtual {
        if (assetAmount > 0) {
            _safeTransferIn(msg.sender, assetAmount);
            collateralAmount[msg.sender] += assetAmount;

            emit Deposit(msg.sender, assetAmount, block.timestamp);
        }

        if (mintAmount > 0) {
            uint256 assetPrice = getAssetPrice();
            _mint(msg.sender, mintAmount, assetPrice);
        }

        require(
            collateralAmount[msg.sender] >=
                controller.getPoolConfig(address(this)).minimumCollateralAmount,
            "collateral amount is too small"
        );
    }

    function withdraw(uint256 amount) external virtual {
        require(amount > 0, " > 0 ");
        _withdraw(msg.sender, amount);
    }

    function repay(address onBehalfOf, uint256 amount) external virtual {
        require(onBehalfOf != address(0), " != address(0)");
        require(amount > 0, " > 0 ");
        _repay(msg.sender, onBehalfOf, amount);
    }

    function _mint(
        address _user,
        uint256 _mintAmount,
        uint256 _assetPrice
    ) internal virtual {
        require(
            poolIssuedOcUSD + _mintAmount <=
                controller.getPoolConfig(address(this)).maximumMintAmount,
            "mint amount exceeds maximum mint amount"
        );
        _updateFee(_user);

        try controller.refreshMintReward(_user) {} catch {}

        borrowedPrincipalAmount[_user] += _mintAmount;

        ocUsd.mint(_user, _mintAmount);
        poolIssuedOcUSD += _mintAmount;

        _inSafeZone(_user, _assetPrice);

        emit Mint(_user, _mintAmount, block.timestamp);
    }

    function _repay(
        address _user,
        address _onBehalfOf,
        uint256 _amount
    ) internal virtual {
        try controller.refreshMintReward(_onBehalfOf) {} catch {}

        _updateFee(_onBehalfOf);

        uint256 totalFee = feeStored[_onBehalfOf];

        uint256 amount = borrowedPrincipalAmount[_onBehalfOf] + totalFee >=
            _amount
            ? _amount
            : borrowedPrincipalAmount[_onBehalfOf] + totalFee;

        // Deduct fee first
        if (amount >= totalFee) {
            feeStored[_onBehalfOf] = 0;
            ocUsd.transferFrom(_user, address(controller), amount);
            ocUsd.burn(address(controller), amount - totalFee);
            borrowedPrincipalAmount[_onBehalfOf] -= (amount - totalFee);
            poolIssuedOcUSD -= (amount - totalFee);
        } else {
            feeStored[_onBehalfOf] = totalFee - amount;
            ocUsd.transferFrom(_user, address(controller), amount);
        }

        emit Repay(_user, _onBehalfOf, amount, block.timestamp);
    }

    function _withdraw(address _user, uint256 _amount) internal {
        require(
            collateralAmount[_user] >= _amount,
            "Withdraw amount exceeds deposited amount."
        );

        collateralAmount[_user] -= _amount;
        _safeTransferOut(_user, _amount);

        if (getBorrowedOf(_user) > 0) {
            _inSafeZone(_user, getAssetPrice());
        }
        emit Withdraw(_user, _amount, block.timestamp);
    }

    function liquidation(
        address provider,
        address onBehalfOf,
        uint256 assetAmount
    ) external virtual {
        uint256 assetPrice = getAssetPrice();
        uint256 onBehalfOfCollateralRatio = (collateralAmount[onBehalfOf] *
            assetPrice *
            10000) /
            getBorrowedOf(onBehalfOf) /
            _adjustDecimals();

        IController.PoolConfig memory poolConfig = controller.getPoolConfig(
            address(this)
        );

        require(
            onBehalfOfCollateralRatio < poolConfig.liquidationCollateralRatio,
            "Borrowers collateral ratio should below badCollateralRatio"
        );

        require(
            assetAmount * 2 <= collateralAmount[onBehalfOf],
            "a max of 50% collateral can be liquidated"
        );
        require(
            // allowance ?
            ocUsd.allowance(provider, address(this)) != 0 ||
                msg.sender == provider,
            "provider should authorize to provide liquidation OcUSD"
        );
        uint256 ocUsdAmount = (assetAmount * assetPrice) / 1e18;

        _repay(provider, onBehalfOf, ocUsdAmount);

        uint256 reducedAsset = (assetAmount * poolConfig.liquidationPenalty) /
            10000;

        collateralAmount[onBehalfOf] -= reducedAsset;

        if (provider == msg.sender) {
            _safeTransferOut(msg.sender, reducedAsset);
        } else {
            uint256 liquidationBonus = reducedAsset - assetAmount;
            uint256 toLiquidator = (liquidationBonus *
                poolConfig.liquidatorReward) / 10000;
            _safeTransferOut(msg.sender, toLiquidator);
            _safeTransferOut(provider, reducedAsset - toLiquidator);
        }
        emit Liquidate(
            onBehalfOf,
            msg.sender,
            provider,
            ocUsdAmount,
            reducedAsset,
            0,
            block.timestamp
        );
    }

    function getBorrowedOf(address user) public view returns (uint256) {
        return borrowedPrincipalAmount[user] + feeStored[user] + _newFee(user);
    }

    function getAsset() external view returns (address) {
        return address(collateralAsset);
    }

    // returns price in 18 decimals
    function getAssetPrice() public view virtual returns (uint256);

    // internal functions
    function _safeTransferIn(
        address from,
        uint256 amount
    ) internal virtual returns (bool) {
        if (address(collateralAsset) == address(0)) {
            require(msg.value == amount, "invalid msg.value");
            return true;
        } else {
            uint256 before = collateralAsset.balanceOf(address(this));
            collateralAsset.transferFrom(from, address(this), amount);
            require(
                collateralAsset.balanceOf(address(this)) >= before + amount,
                "transfer in failed"
            );
            return true;
        }
    }

    function _safeTransferOut(
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
        if (address(collateralAsset) == address(0)) {
            (bool suc, ) = payable(to).call{value: amount}("");
            require(suc, "transfer out failed");
            return true;
        } else {
            collateralAsset.transfer(to, amount);
            return true;
        }
    }

    // check after every function that changes user status,  collateral ratio is above safeCollateralRatio
    function _inSafeZone(
        address user,
        uint256 price
    ) internal view virtual returns (bool) {
        require(
            ((collateralAmount[user] * price * 10000) / getBorrowedOf(user)) /
                _adjustDecimals() >=
                controller.getPoolConfig(address(this)).safeCollateralRatio,
            "collateral ratio is Below safeCollateralRatio"
        );

        return true;
    }

    function _updateFee(address user) internal {
        if (block.timestamp > feeUpdatedAt[user]) {
            feeStored[user] += _newFee(user);
            feeUpdatedAt[user] = block.timestamp;
        }
    }

    function _newFee(address user) internal view returns (uint256) {
        return
            (borrowedPrincipalAmount[user] *
                controller.getPoolConfig(address(this)).mintFeeApy *
                (block.timestamp - feeUpdatedAt[user])) /
            (86400 * 365) /
            10000;
    }

    function _adjustDecimals() internal view virtual returns (uint256) {
        uint8 decimals;
        if (address(collateralAsset) == address(0)) {
            decimals = 18;
        } else {
            decimals = IERC20Detailed(address(collateralAsset)).decimals();
        }
        return 10 ** uint256(decimals);
    }

    receive() external payable {}
}
