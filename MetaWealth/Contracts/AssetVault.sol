// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IMetaWealthModerator.sol";
import "./interfaces/IAssetVault.sol";

contract AssetVault is ERC20, Ownable, IAssetVault {
    /// @notice MetaWealth moderator contract for currency and whitelist checks
    IMetaWealthModerator public metawealthMod;

    /// @notice Maintain list of all share holders
    address[] public shareholders;

    /// @notice Mapping to eliminate for-loops for above array where possible
    mapping(address => uint256) shareholderIndex;

    /// @notice Asset activity metadata
    bool active = false;

    /// @notice Asset-specific currency attached
    address tradingCurrency;

    /// @notice Timestamp for when the defractionalization is enabled
    uint64 unlockTimestamp;

    /// @notice Starts the contract but puts it in stale mode until instantiate() called
    /// @dev todo Instantiate ERC20 with a prefixed name and symbol
    /// @param owner_ is going to be the AssetVault contract owner
    /// @param totalShares_ is the number of shares to start this asset from
    /// @param metawealthMod_ is the moderator contract of MetaWealth platform
    constructor(
        address owner_,
        uint256 totalShares_,
        IMetaWealthModerator metawealthMod_
    ) ERC20("MetaWealthAsset", "MWA") {
        /// @dev Push a 0-address so that reverse-mapping of shareholderIndex can start from 1
        shareholders.push(address(0));
        shareholderIndex[address(0)] = 0;

        transferOwnership(owner_);
        _mint(owner_, totalShares_);
        metawealthMod = metawealthMod_;
        unlockTimestamp = uint64(block.timestamp + metawealthMod.getDefaultUnlockPeriod());
        tradingCurrency = metawealthMod.getDefaultCurrency();

        emit CurrencyChanged(address(0), tradingCurrency);
    }

    /// @dev To keep shares simple and different than fungible tokens, we set decimals to 0
    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function isActive() external view override returns (bool active_) {
        return active;
    }

    function getTradingCurrency()
        external
        view
        override
        returns (address currency)
    {
        return tradingCurrency;
    }

    function setTradingCurrency(address newCurrency)
        external
        override
        onlyOwner
    {
        require(
            metawealthMod.isSupportedCurrency(newCurrency),
            "MetaWealthCurrencies: New currency not supported"
        );
        emit CurrencyChanged(tradingCurrency, newCurrency);
        tradingCurrency = newCurrency;
    }

    function toggleStatus()
        external
        override
        onlyOwner
        returns (bool newStatus)
    {
        require(
            totalSupply() > 0,
            "AssetVault: Asset not instantiated"
        );
        active = !active;
        emit StatusChanged(active);
        return active;
    }

    function deposit(uint256 amount) external override {
        require(
            _msgSender() == metawealthMod.getAdmin(),
            "MetaWealthAccessControl: Resctricted to Admins"
        );

        for (uint256 i = 1; i < shareholders.length; i++) {
            if (
                shareholders[i] == address(0) || balanceOf(shareholders[i]) == 0
            ) continue;

            /// @dev share basis point precision dictated by decimals in `amount` variable
            uint256 shareAmount = (amount * balanceOf(shareholders[i])) /
                totalSupply();
            IERC20(tradingCurrency).transferFrom(
                _msgSender(),
                shareholders[i],
                shareAmount
            );
        }

        emit FundsDeposited(tradingCurrency, amount);
    }

    function burn(uint256 amount) external override onlyOwner {
        require(block.timestamp >= unlockTimestamp, "AssetVault: Defractionalization not permitted yet");
        _burn(_msgSender(), amount);
    }

    /// @notice Using OpenZeppelin's internal hook to maintain a list of all shareholders
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        /// @dev case where an existing shareholder exits the position
        if (
            from != address(0) &&
            balanceOf(from) == 0 &&
            shareholderIndex[from] != 0
        ) {
            shareholders[shareholderIndex[from]] = shareholders[
                shareholders.length - 1
            ];
            shareholders.pop();
            delete shareholderIndex[from];
        }

        /// @dev case where a new shareholder starts the position
        if (
            to != address(0) &&
            balanceOf(to) == amount &&
            shareholderIndex[to] == 0
        ) {
            shareholderIndex[to] = shareholders.length;
            shareholders.push(to);
        }
    }
}
