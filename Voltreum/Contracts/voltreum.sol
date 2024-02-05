// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title Volt Token Contract
contract Volt is ERC20, ERC20Burnable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Token transfer fee status
    bool public feeActive;
    /// @notice Token transfer fee percentage
    uint256 public feePercent;
    /// @notice Token max supply
    uint256 public constant MAXSUPPLY = 1400000000 * 1e18;
    /// @notice Wallet receiving the fee on transactions
    address public feeWallet;

    /// @dev Constructor assigning fee wallet and token name and symbol
    /// @param _feeWallet Wallet receiving the fee on transactions
    constructor(address _feeWallet) ERC20("Volt", "VOLT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        feeWallet = _feeWallet;
    }

    /// @dev Function to mint token
    /// @param to Address in which token will be minted
    /// @param amount amount of token to be minted
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply().add(amount) <= MAXSUPPLY,"Reached Max supply");
        _mint(to, amount);
    }

    /// @dev Function to change fee on token transfers
    /// @param status bool highlighting the transfer fee status
    /// @param _feePercent transfer fee percentage
    function changeFeeStatus(bool status, uint256 _feePercent)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_feePercent <= 5);
        feeActive = status;
        feePercent = _feePercent;
    }

    /// @dev Overriding transfer From function to add transaction fee
    /// @param to To wallet
    /// @param amount Amount to be transferred
    /// @return bool confirmation
    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        address spender = _msgSender();
        if (feeActive) {
            uint256 fee;
            fee = amount.mul(feePercent).div(100);
            _transfer(spender, feeWallet, fee);
            amount = amount.sub(fee);
        }
        _transfer(spender, to, amount);
        return true;
    }

    /// @dev Overriding transfer From function to add transaction fee
    /// @param from From wallet
    /// @param to To wallet
    /// @param amount Amount to be transferred
    /// @return bool confirmation
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        if (feeActive) {
            uint256 fee;
            fee = amount.mul(feePercent).div(100);
            _transfer(from, feeWallet, fee);
            amount = amount.sub(fee);
        }
        _transfer(from, to, amount);
        return true;
    }
}