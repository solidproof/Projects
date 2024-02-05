// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Internal Wallets contract
 * @dev This contract will handle the internal wallets to manage the token
 */
contract Wallets is Ownable {

    address internal _developmentWallet;
    address internal _foundersWallet;
    address internal _preSaleWallet;
    address internal _marketingWallet;
    address internal _nonProfitAssociations;

    event WalletTransferred(
        address indexed previousAddress,
        address indexed newAddress
    );

    /**
     * @dev Set internal wallets to initial addresses. They can be updated later via their transfer function.
     */
    constructor(
        address development,
        address founders,
        address preSale,
        address marketing,
        address nonProfitAssociations
    ) {
        _developmentWallet = development;
        _foundersWallet = founders;
        _preSaleWallet = preSale;
        _marketingWallet = marketing;
        _nonProfitAssociations = nonProfitAssociations;
    }

    function getDevelopmentWallet() external view returns (address) {
        return _developmentWallet;
    }

    function getFoundersWallet() external view returns (address) {
        return _foundersWallet;
    }

    function getPreSaleWallet() external view returns (address) {
        return _preSaleWallet;
    }

    function getMarketingWallet() external view returns (address) {
        return _marketingWallet;
    }

    function getNonProfitAssociationsWallet() external view returns (address) {
        return _nonProfitAssociations;
    }

    /**
     * @dev Transfers development wallet to a new address. Must be called from non-zero address.
     */
    function transferDevelopment(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Wallet: new address of Wallet is the zero address."
        );
        address oldOwner = _developmentWallet;
        _developmentWallet = newOwner;
        emit WalletTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Transfers founders wallet to a new address. Must be called from non-zero address.
     */
    function transferFounders(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Wallet: new address of Wallet is the zero address."
        );
        address oldOwner = _foundersWallet;
        _foundersWallet = newOwner;
        emit WalletTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Transfers presale wallet to w new address. Must be called from non-zero address.
     */
    function transferPreSale(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Wallet: new address of Wallet is the zero address."
        );
        address oldOwner = _preSaleWallet;
        _preSaleWallet = newOwner;
        emit WalletTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Transfers marketing wallet to a new address. Must be called from non-zero address.
     */
    function transferMarketing(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Wallet: new address of Wallet is the zero address."
        );
        address oldOwner = _marketingWallet;
        _marketingWallet = newOwner;
        emit WalletTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Transfers non-profit associations wallet to a new address. Must be called from non-zero address.
     */
    function transferNonProfitAssociations(address newOwner)
        public
        virtual
        onlyOwner
    {
        require(
            newOwner != address(0),
            "Wallet: new address of Wallet is the zero address."
        );
        address oldOwner = _nonProfitAssociations;
        _nonProfitAssociations = newOwner;
        emit WalletTransferred(oldOwner, newOwner);
    }

    /**
     * @dev Returns if the wallet is an internal wallet.
     */
    function _isInternalWallet(address wallet) internal view returns (bool) {
        return
            wallet == _developmentWallet ||
            wallet == _foundersWallet ||
            wallet == _preSaleWallet ||
            wallet == _marketingWallet;
    }
}
