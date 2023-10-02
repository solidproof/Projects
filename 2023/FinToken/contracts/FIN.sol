//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IFactoryHelperUniswapV2} from "./interfaces/IFactoryHelperUniswapV2.sol";
import {IRouterHelperUniswapV2} from "./interfaces/IRouterHelperUniswapV2.sol";

/**
 * @title FIN contract
 */
contract FIN is ERC20, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    IRouterHelperUniswapV2 public immutable uniswapRouter;
    address public immutable pairAddress;
    uint256 private immutable _purchaseLiquidityPeriodLockEnd;
    uint256 private immutable _purchaseWhitelistPeriodLockEnd;
    address private immutable _marketingWallet;

    uint256 private _sellFee;
    uint256 private _buyFee;

    EnumerableSet.AddressSet private _whitelist;

    /**
        @notice Return sell fee
    */
    function sellFee() external view returns (uint256) {
        return _sellFee;
    }

    /**
        @notice Return buy fee
    */
    function buyFee() external view returns (uint256) {
        return _buyFee;
    }

    /**
        @notice Return purchase liquidity period lock end
    */
    function purchaseLiquidityPeriodLockEnd() external view returns (uint256) {
        return _purchaseLiquidityPeriodLockEnd;
    }

    /**
        @notice Return purchase whitelist period lock end
    */
    function purchaseWhitelistPeriodLockEnd() external view returns (uint256) {
        return _purchaseWhitelistPeriodLockEnd;
    }

    /**
        @notice Return narketing wallet
    */
    function marketingWallet() external view returns (address) {
        return _marketingWallet;
    }

    /**
        @notice Return bool status, that says that the user in whitelist
        @param wallet address for check
    */
    function checkWhitelist(address wallet) external view returns (bool) {
        return _whitelist.contains(wallet);
    }

    /**
        @notice Return whitelist count
    */
    function whitelistCount() external view returns (uint256) {
        return _whitelist.length();
    }

    /**
        @notice Return user by userId from whitelist
        @param userId userId waller in whitelist
    */
    function userByIdInWhitelist(
        uint256 userId
    ) external view returns (address) {
        require(userId < _whitelist.length(), "FIN: Invalid user id");
        return _whitelist.at(userId);
    }

    /**
        @notice Returns array address from whitelist
        @param offset number from which the output will be
        @param limit the number of addresses to be taken
    */
    function whitelist(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory whitelistAddresses) {
        uint256 whitelistLength = _whitelist.length();
        if (offset >= whitelistLength) return new address[](0);
        uint256 to = offset + limit;
        if (whitelistLength < to) to = whitelistLength;
        whitelistAddresses = new address[](to - offset);
        for (uint256 i; i < whitelistAddresses.length; i++)
            whitelistAddresses[i] = _whitelist.at(offset + i);
    }

    /**
        @notice Update fee for selling event
        @param newSellFee new sell fee
    */
    event SellFeeUpdated(uint256 newSellFee);

    /**
        @notice Update fee for buing event
        @param newBuyFee new buy fee
    */
    event BuyFeeUpdated(uint256 newBuyFee);

    /**
        @notice Whitelist changed event
        @param wallet wallet in which changed
        @param status status changed
    */
    event WhitelistChanged(address wallet, bool status);

    /**
     * @notice Initializes token
     * @dev Initializes a new Token instance
     * For success works:
     * - Purchase liquidity period lock should be positive
     * - Purchase whitelist period lock should be positive
     * - Sell fee should be lt 10%, percentage is multiplied by 100 for accuracy, 10% = 1000
     * - Buy fee should be lt 5%, percentage is multiplied by 100 for accuracy, 5% = 500
     * - Marketing wallet must not be zero address
     * - Uniswap router address must not be zero address
     * @param purchaseLiquidityPeriodLock_  Purchase lockout period for those who don't owner
     * @param purchaseWhitelistPeriodLock_ Purchases lock period for those who are not on the whitelist
     * @param sellFee_ Sell fee
     * @param buyFee_ Buy fee
     * @param marketingWallet_ Marketing wallet for collect fee
     * @param whitelist_ whitelist for buying and selling in purchase period lock
     * @param uniswapRouter_ uniswap router address
     */
    constructor(
        uint256 purchaseLiquidityPeriodLock_,
        uint256 purchaseWhitelistPeriodLock_,
        uint256 sellFee_,
        uint256 buyFee_,
        address marketingWallet_,
        address[] memory whitelist_,
        address uniswapRouter_
    ) ERC20("FIN", "FIN") {
        require(
            purchaseLiquidityPeriodLock_ > 0,
            "FIN: Purchase liquidity lockout period eq 0"
        );
        require(
            purchaseWhitelistPeriodLock_ > 0,
            "FIN: Purchase whitelist lockout period eq 0"
        );
        require(sellFee_ <= 1000, "FIN: Sell fee must be lt 10%");
        require(buyFee_ <= 500, "FIN: Buy fee must be lt 5%");
        require(
            marketingWallet_ != address(0),
            "FIN: Marketing wallet must not be zero"
        );
        require(
            uniswapRouter_ != address(0),
            "FIN: Uniswap router must not be zero"
        );
        _purchaseLiquidityPeriodLockEnd =
            block.timestamp +
            purchaseLiquidityPeriodLock_;
        _purchaseWhitelistPeriodLockEnd =
            _purchaseLiquidityPeriodLockEnd +
            purchaseWhitelistPeriodLock_;
        _sellFee = sellFee_;
        _buyFee = buyFee_;
        _marketingWallet = marketingWallet_;
        uint256 whitelistArrayLength = whitelist_.length;
        for (uint i; i < whitelistArrayLength; ) {
            _whitelist.add(whitelist_[i]);
            unchecked {
                ++i;
            }
        }
        _whitelist.add(uniswapRouter_);

        uniswapRouter = IRouterHelperUniswapV2(uniswapRouter_);
        pairAddress = IFactoryHelperUniswapV2(uniswapRouter.factory())
            .createPair(address(this), uniswapRouter.WETH());

        _mint(msg.sender, 100_000_000 * 1e18);
    }

    /**
        @notice Method for update sell fee
        @dev
        For success works:
        - The callers must be an owner
        - Sell fee must be lt 10%
        Emits a {SellFeeUpdated} event
        @param newSellFee new sell fee
    */
    function setSellFee(uint256 newSellFee) external onlyOwner returns (bool) {
        require(newSellFee <= 1000, "FIN: Sell fee must be lt 10%");
        _sellFee = newSellFee;
        emit SellFeeUpdated(newSellFee);
        return true;
    }

    /**
        @notice Method for update buy fee
        @dev
        For success works:
        - The callers must be an owner
        - Sell fee must be lt 5%
        Emits a {BuyFeeUpdated} event
        @param newBuyFee new buy fee
    */
    function setBuyFee(uint256 newBuyFee) external onlyOwner returns (bool) {
        require(newBuyFee <= 500, "FIN: Sell fee must be lt 5%");
        _buyFee = newBuyFee;
        emit BuyFeeUpdated(newBuyFee);
        return true;
    }

    /**
        @notice Method for set status for wallet
        @dev
        For success works:
        - The callers must be an owner
        - Wallet must not be zero
        If you pass true to status, it will add the wallet to the whitelist, if false, it will delete it
        Emits a {WhitelistChanged} event
        @param wallet wallet for set status
        @param status status for wallet
    */
    function setWhitelistStatus(
        address wallet,
        bool status
    ) external onlyOwner returns (bool) {
        require(wallet != address(0), "FIN: wallet must not be zero");
        status ? _whitelist.add(wallet) : _whitelist.remove(wallet);
        emit WhitelistChanged(wallet, status);
        return true;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        require(_from != address(0), "FIN: Transfer from address zero");
        require(_to != address(0), "FIN: Transfer to address zero");
        require(_amount > 0, "FIN: Transfer amount must be greater than zero");
        if (_from != pairAddress && _to != pairAddress) {
            super._transfer(_from, _to, _amount);
        } else if (
            block.timestamp < _purchaseLiquidityPeriodLockEnd &&
            _from == pairAddress
        ) {
            require(_to == owner(), "FIN: Wallet should be owner");
            super._transfer(_from, _to, _amount);
        } else if (
            block.timestamp < _purchaseLiquidityPeriodLockEnd &&
            _to == pairAddress
        ) {
            require(_from == owner(), "FIN: Wallet should be owner");
            super._transfer(_from, _to, _amount);
        } else if (
            block.timestamp < _purchaseWhitelistPeriodLockEnd &&
            _from == pairAddress
        ) {
            require(
                _whitelist.contains(_to),
                "FIN: Wallet should be in whitelist"
            );
            uint256 toTransfer = _takeFee(_from, _amount, _buyFee);
            super._transfer(_from, _to, toTransfer);
        } else if (
            block.timestamp < _purchaseWhitelistPeriodLockEnd &&
            _to == pairAddress
        ) {
            require(
                _whitelist.contains(_from),
                "FIN: Wallet should be in whitelist"
            );
            uint256 toTransfer = _takeFee(_from, _amount, _sellFee);
            super._transfer(_from, _to, toTransfer);
        } else if (_from == pairAddress) {
            uint256 toTransfer = _takeFee(_from, _amount, _buyFee);
            super._transfer(_from, _to, toTransfer);
        } else if (_to == pairAddress) {
            uint256 toTransfer = _takeFee(_from, _amount, _sellFee);
            super._transfer(_from, _to, toTransfer);
        }
    }

    function _takeFee(
        address _from,
        uint256 _amount,
        uint256 _fee
    ) internal returns (uint256) {
        uint256 fee = (_amount * _fee) / 10000;
        super._transfer(_from, _marketingWallet, fee);
        return (_amount - fee);
    }
}