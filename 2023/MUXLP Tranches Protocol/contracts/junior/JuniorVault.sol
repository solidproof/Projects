// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/LibConfigSet.sol";
import "./JuniorVaultStore.sol";
import "./JuniorVaultImp.sol";
import "./StakeHelperImp.sol";

contract JuniorVault is
    JuniorVaultStore,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using JuniorVaultImp for JuniorStateStore;
    using LibConfigSet for LibConfigSet.ConfigSet;

    function initialize(
        string memory name_,
        string memory symbol_,
        address assetToken_,
        address depositToken_
    ) external initializer {
        __AccessControlEnumerable_init();

        _name = name_;
        _symbol = symbol_;
        _store.initialize(assetToken_);
        _store.depositToken = depositToken_;
        _grantRole(DEFAULT_ADMIN, msg.sender);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function assetDecimals() external view returns (uint8) {
        return _store.asset.assetDecimals;
    }

    // =============================================== Configs ===============================================
    function getConfig(bytes32 configKey) external view returns (bytes32) {
        return _store.config.getBytes32(configKey);
    }

    function setConfig(bytes32 configKey, bytes32 value) external {
        require(
            hasRole(CONFIG_ROLE, msg.sender) || hasRole(DEFAULT_ADMIN, msg.sender),
            "JuniorVault::ONLY_AUTHRIZED_ROLE"
        );
        _store.config.setBytes32(configKey, value);
    }

    /**
     *  Returns the address of the asset token.
     */
    function asset() external view returns (address) {
        return _store.asset.asset;
    }

    /**
     * Returns the address of the token used for deposit.
     */
    function depositToken() external view returns (address) {
        return _store.depositToken;
    }

    /**
     * Returns the total amount of assets managed by the vault.
     */
    function totalAssets() external view returns (uint256) {
        return _store.totalAssets();
    }

    /**
     * Returns the total amount of shares.
     */
    function totalSupply() external view returns (uint256) {
        return _store.asset.totalSupply;
    }

    /**
     * Returns the amount of shares owned by `owner`.
     *
     * @param owner the owner of the shares
     */
    function balanceOf(address owner) external view returns (uint256) {
        return _store.balanceOf(owner);
    }

    /**
     * Deposit assets to the vault.
     * The deposit is passive which means the vault only test if there is enought assets in the contracts.
     *
     * @param assets the amount of assets to be deposited, in asset decimals
     * @param receiver the receiver of the shares
     */
    function deposit(
        uint256 assets,
        address receiver
    ) external onlyRole(HANDLER_ROLE) returns (uint256 shares) {
        shares = _store.deposit(assets, receiver);
    }

    /**
     * Withdraw assets from the vault. The assets will be transferred to the receiver.
     * The amount of assets withdrawn per share is determined by the result of totalAssets / totalSupply.
     *
     * @param caller can be owner or someone has been approved by the owner
     * @param owner the owner of the shares
     * @param shares the amount of shares to be withdrawn, in shares decimals (18)
     * @param receiver the receiver of the assets
     */
    function withdraw(
        address caller,
        address owner,
        uint256 shares,
        address receiver
    ) external onlyRole(HANDLER_ROLE) returns (uint256 assets) {
        assets = _store.withdraw(caller, owner, shares, receiver);
    }

    /**
     * Call by the router. Claim the rewards from staking contracts then distribute to junior/senior holders.
     *
     * @param receiver the receiver of the rewards
     */
    function collectRewards(address receiver) external onlyRole(HANDLER_ROLE) {
        _store.collectRewards(receiver);
    }

    function adjustVesting() external onlyRole(HANDLER_ROLE) {
        _store.adjustVesting();
    }

    /**
     * Transfer assets out (to the router).
     *
     * @param assets the amount of assets to be transferred in, in asset decimals
     */
    function transferIn(uint256 assets) external onlyRole(HANDLER_ROLE) {
        _store.transferIn(assets);
    }

    /**
     * Transfer assets in (from the router).
     * @param assets the amount of assets to be transferred out, in asset decimals
     */
    function transferOut(uint256 assets) external onlyRole(HANDLER_ROLE) {
        _store.transferOut(assets, msg.sender);
    }
}
