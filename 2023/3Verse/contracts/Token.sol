// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

/// @title 3Verse Token contract
contract Token is ERC20, ERC20Burnable, ERC20Permit, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FEE_EXEMPTER_ROLE = keccak256("FEE_EXEMPTER_ROLE");
    ///@dev "ether" is used here to get 18 decimals
    uint public constant MAX_SUPPLY = 100_000_000 ether;
    ///@notice These are the amounts ear marked for the different type of accounts
    uint256 public constant DEVELOPMENT_FUND = 15_000_000 ether;
    uint256 public constant TEAM_RESERVE = 6_000_000 ether;
    uint256 public constant PARTNERS_ADVISORS = 3_000_000 ether;
    uint256 public constant PRESALES = 4_000_000 ether;
    uint256 public constant PUBLICSALE = 24_000_000 ether;
    uint256 public constant LIQUIDTY = 2_000_000 ether;

    ///@notice This is the tax percentage to start
    uint8 public percentage = 15;
    uint8 public constant MAX_TAX_PERCENTAGE = 25;
    bool public taxable;
    // Addresses not subject to transfer fees
    mapping (address => bool) private _transferFeeExempt;

    ///@notice These are the safe mutlisig addresses that will receive the tokens 
    address public constant DEVELOPMENT_FUND_ADDRESS = address(0xCbe17f635E37E78D8a2d8baBD1569f1DeD3D4f87);
    address public constant TEAM_RESERVE_ADDRESS = address(0xe9A65Ad2D1e8D8f8dF26E27D7Fb03CEB7E6ae61E);
    address public constant PARTNERS_ADVISORS_ADDRESS = address(0xdf9dB68648103A17b32AaFce79A78c1A8d6b2483);
    address public constant PRESALES_ADDRESS = address(0xE4581C15e5EcBb9fe054F01979c4b9Ab4e81A0fc);
    address public constant PUBLICSALE_ADDRESS = address(0x49e792d6a5CeeBf7A14FB521Af44750167804038);
    address public constant LIQUIDTY_ADDRESS = address(0xF8B2ac3462738FFDEB21cE64B4d25772c3643111);
    address public constant FEE_ADDRESS = address(0xdEFaE8a08FD0E3023eF7E14c08C622Ad4F22aC9A);
    
    ///@notice This is the anti-snipe contract address from gotbit
    IAntisnipe public antisnipe;
    bool public antisnipeDisable;
    
    ///@param owner is the address that will be granted the DEFAULT_ADMIN_ROLE
    constructor(address owner) ERC20("3VERSE", "VERS") ERC20Permit("3VERSE") {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINTER_ROLE, owner);
        _grantRole(FEE_EXEMPTER_ROLE, owner);

        _mint(DEVELOPMENT_FUND_ADDRESS, DEVELOPMENT_FUND);
        _mint(TEAM_RESERVE_ADDRESS, TEAM_RESERVE);
        _mint(PARTNERS_ADVISORS_ADDRESS, PARTNERS_ADVISORS);
        _mint(PRESALES_ADDRESS, PRESALES);
        _mint(PUBLICSALE_ADDRESS, PUBLICSALE);
        _mint(LIQUIDTY_ADDRESS, LIQUIDTY);
    }

    /// @dev allow minting of tokens upto the MAX SUPPLY by MINTER_ROLE
    /// @param to is the address that will receive the minted tokens
    /// @param amount is the amount of tokens to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply reached");
        _mint(to, amount);
    }

    /// @dev override the default transfer function to add tax if applicable
    /// @param from is the address that will send the tokens
    /// @param to is the address that will receive the tokens
    /// @param amount is the amount of tokens to transfer
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (taxable && !isTransferFeeExempt(from)) {
            _transferWithFees(from, to, amount);
        } else {
            super._transfer(from, to, amount);
        }
    }

    /// @dev The function to transfer the fees applicable only if taxable is true
    /// @param from is the address that will send the tokens
    /// @param to is the address that will receive the tokens
    /// @param amount is the amount of tokens to transfer
    function _transferWithFees(
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 tax = (amount * percentage) / 100;
        uint256 netAmount = amount - tax;
        super._transfer(from, to, netAmount);
        super._transfer(from, FEE_ADDRESS, tax);
    }   

    /// @dev allow taxation of tokens by the owner
    /// @param _taxable is the boolean to set if the token is taxable or not
    /// @param _percentage is the percentage of tax to apply
    function setTaxable(bool _taxable, uint8 _percentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_percentage <= MAX_TAX_PERCENTAGE, "Tax exceeds max!");
        taxable = _taxable;
        percentage = _percentage;
    }

    /// @dev allow disabling of the transfer fee for certain contracts using a fee exempter role
    function setTransferFeeExempt(address account) external onlyRole(FEE_EXEMPTER_ROLE) {
        _transferFeeExempt[account] = true;
    }

    /// @dev Check if the address given is exempt from transfer fees
    /// @param account The address to check
    /// @return A boolean if the address passed is exempt from transfer fees
    function isTransferFeeExempt(address account) public view returns(bool) {
        return _transferFeeExempt[account];
    }

    
    /// @dev calling the token transfer hook for anti snipe
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from == address(0) || to == address(0)) return;
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);
    }

    function setAntisnipeDisable() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!antisnipeDisable);
        antisnipeDisable = true;
    }

    function setAntisnipeAddress(address addr) external onlyRole(DEFAULT_ADMIN_ROLE) {
        antisnipe = IAntisnipe(addr);
    }
}
