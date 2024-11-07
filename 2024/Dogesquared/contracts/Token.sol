// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Token
 * @dev This contract implements an ERC20 token with burnable, permit (gasless approvals), and ownership features.
 * It also implements transfer restrictions, allowing token transfers only to or from whitelisted addresses until trading is fully opened.
 */
contract Token is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    /// @dev Boolean variable to track whether trading is open. Until then, users can only buy, stake and unstake their tokens.
    bool private _tradeIsOpen = false;

    /**
     * @dev Mapping to track whitelisted addresses that are allowed to transfers before trading is fully open.
     * Whitelisted accounts can transfer or receive even when trading is not fully open.
     */
    mapping(address account => bool) private _isWhitelisted;

    /**
     * @dev Event emitted when trading is officially opened.
     * @param timestamp The block timestamp when trading was opened.
     */
    event TradeIsOpen(uint256 timestamp);

    /**
     * @dev Event emitted when an account is added to or removed from the whitelist.
     * @param account The address of the account that was whitelisted or removed from the whitelist.
     * @param status A boolean indicating whether the account was added to (`true`) or removed from (`false`) the whitelist.
     */
    event WhitelistChanged(address indexed account, bool status);

    /**
     * @dev Constructor that initializes the token with a name and symbol, mints the total supply,
     * and sets up the permit (EIP-2612) functionality.
     */
    constructor() ERC20("DOGE SQUARED", "DOGE2") ERC20Permit("DOGE SQUARED") {
        /**
         * DOGE SQUARED (DOGE2) Token Distribution:
         * - totalSupply        = 5,000,000,000 (5.00B) = 100%
         * - presaleReserve     = 2,500,000,000 (2.50B) =  50%
         * - stakingReserve     =   750,000,000 (0.75B) =  15%
         * - marketingReserve   =   750,000,000 (0.75B) =  15%
         * - developmentReserve = 1,000,000,000 (1.00B) =  20%
         */
        uint256 decimalsMultiplier = 10 ** decimals();
        _tradeIsOpen = true;

        uint256 presaleReserve = 2_500_000_000 * decimalsMultiplier;
        address presaleContract = 0x81cdaA8F234132bc8d9048620D7EaDc18fA52562;
        _mint(presaleContract, presaleReserve);
        _isWhitelisted[presaleContract] = true;
        emit WhitelistChanged(presaleContract, true);

        uint256 stakingReserve = 750_000_000 * decimalsMultiplier;
        address stakingContract = 0x9dDcCbACc390A30EA5681c28e0D99f3e16bD5Cb1;
        _mint(stakingContract, stakingReserve);
        _isWhitelisted[stakingContract] = true;
        emit WhitelistChanged(stakingContract, true);

        uint256 marketingReserve = 750_000_000 * decimalsMultiplier;
        address marketingWallet = 0xD99C5E1fc1dc4eBC2a5ec8BA93347e06e3a6E01b;
        _mint(marketingWallet, marketingReserve);

        uint256 developmentReserve = 1_000_000_000 * decimalsMultiplier;
        address developmentWallet = 0x3eb941DBcB7bb65981914BA834ea0B96903c4952;
        _mint(developmentWallet, developmentReserve);

        _tradeIsOpen = false;
    }

    /**
     * @dev Returns the current state of trading.
     * @return Boolean indicating if trading is open.
     */
    function tradeIsOpen() external view returns (bool) {
        return _tradeIsOpen;
    }

    /**
     * @dev Allows the contract owner to open trading for all users. Once trading is open, the restriction for whitelisted addresses is lifted.
     */
    function openTrading() external onlyOwner {
        require(!_tradeIsOpen, "Trading has already started");
        _tradeIsOpen = true;
        emit TradeIsOpen(block.timestamp);
    }

    /**
     * @dev Checks if a specific account is whitelisted.
     * Whitelisted accounts can transfer or receive even when trading is not fully open.
     * @param account The address of the account to check.
     * @return Boolean indicating if the account is whitelisted (`true`) or not (`false`).
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _isWhitelisted[account];
    }

    /**
     * @dev Allows the contract owner to whitelist or remove multiple accounts in one transaction.
     * @param accounts An array of addresses to be added or removed from the whitelist.
     * @param status Boolean indicating whether to whitelist (`true`) or remove from the whitelist (`false`).
     */
    function setWhitelist(
        address[] calldata accounts,
        bool status
    ) external onlyOwner {
        for (uint256 i = 0; i < accountslength; i++) {
            _isWhitelisted[accounts[i]] = status;
            emit WhitelistChanged(accounts[i], status);
        }
    }

    /**
     * @dev Overrides the default ERC20 `_transfer` function to add a restriction that only
     * allows whitelisted addresses to transfer if trading is not yet open.
     * @param from The address sending tokens.
     * @param to The address receiving tokens.
     * @param amount The amount of tokens being transferred.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // If trading is not open, restrict transfers to or from whitelisted addresses only.
        if (!_tradeIsOpen) {
            require(
                _isWhitelisted[from] || _isWhitelisted[to],
                "Trading is not started"
            );
        }
        super._transfer(from, to, amount);
    }
}