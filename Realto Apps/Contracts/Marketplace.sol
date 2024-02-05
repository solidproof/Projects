// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./DealToken.sol";
import "./DividendVault.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Issuer.sol";

/// @title Marketplace - Allows creation and listing of custom tokens.

contract Marketplace is Ownable, Issuer {
    address private Erc20PaymentAddress;
    address private AggregatorInterface;

    constructor(address _erc20PaymentAddress, address _aggregatorAddress) {
        require(_erc20PaymentAddress != address(0));
        require(_aggregatorAddress != address(0));
        Erc20PaymentAddress = _erc20PaymentAddress;
        AggregatorInterface = _aggregatorAddress;
    }

    /*
     * Settings Function
     */

    /// @dev Change Price feed contract address.
    /// @param _interfaceAddress Address of investor.
    function changeAggregatorInterface(address _interfaceAddress)
        external
        onlyOwner
    {
        require(_interfaceAddress != address(0));
        AggregatorInterface = _interfaceAddress;
    }

    /// @dev Change ERC Payment contract address.
    /// @param _contractAddress Address of investor.
    function changeErcPaymentAddress(address _contractAddress)
        external
        onlyOwner
    {
        require(_contractAddress != address(0));
        Erc20PaymentAddress = _contractAddress;
    }

    /// @dev Add address to whitelist.
    /// @param _userAddress Address of investor.
    function addToWhitelist(address _userAddress) external onlyOwner {
        _addToWhitelist(_userAddress);
    }

    /// @dev Add address to blacklist.
    /// @param _userAddress Address of investor.
    function addToBlacklist(address _userAddress) external onlyOwner {
        _addToBlacklist(_userAddress);
    }

    /*
     * Public functions
     */
    /// @dev Allows verified creation of custom token.
    /// @param _name String for token name.
    /// @param _symbol String for token symbol.
    /// @param _initial_supply uint256 for inital supply.
    /// @param _tokenPrice uint256 for token price.
    /// @param _fees uint256 for fees on each token.
    /// @return tokenAddress Returns token contract address.
    function create(
        string memory _name,
        string memory _symbol,
        uint256 _initial_supply,
        uint256 _tokenPrice,
        uint256 _fees,
        uint256 _dealId
    ) external returns (address tokenAddress, address dividendVaultAddress) {
        require(!blackListUsers[msg.sender], "Address blacklisted");
        tokenAddress = address(
            new DealToken(
                _name,
                _symbol,
                _initial_supply,
                _tokenPrice,
                _fees,
                payable(msg.sender),
                Erc20PaymentAddress,
                AggregatorInterface
            )
        );
        dividendVaultAddress = address(
            new DividendVault(tokenAddress, msg.sender)
        );
        _register(tokenAddress, _dealId, dividendVaultAddress);
        return (tokenAddress, dividendVaultAddress);
    }
}
