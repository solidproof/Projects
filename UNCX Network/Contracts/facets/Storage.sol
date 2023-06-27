// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "../interfaces/ILosslessController.sol";

struct Storage {

    uint256 CONTRACT_VERSION;


    TaxSettings taxSettings;
    TaxSettings isLocked;
    Fees fees;
    CustomTax[] customTaxes;

    address transactionTaxWallet;
    uint256 customTaxLength;
    uint256 MaxTax;
    uint8 MaxCustom;

    uint256 DENOMINATOR;

    mapping (address => uint256) _rOwned;
    mapping (address => uint256) _tOwned;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) _isExcluded;
    address[] _excluded;
   
    uint256 MAX;
    uint256 _tTotal;
    uint256 _rTotal;
    uint256 _tFeeTotal;

    mapping (address => bool) lpTokens;
    
    string _name;
    string _symbol;
    uint8 _decimals;
    address _creator;

    address factory;

    address buyBackWallet;
    address lpWallet;

    bool isPaused;

    bool isTaxed;
    
    mapping(address => bool) blacklist;
    mapping(address => bool) swapWhitelist;
    mapping(address => bool) maxBalanceWhitelist;
    mapping(address => bool) taxWhitelist;

    address pairAddress;

    uint256 taxHelperIndex;

    // AntiBot Variables

    bool marketInit;
    uint256 marketInitBlockTime;

    AntiBotSettings antiBotSettings;

    mapping (address => uint256) antiBotBalanceTracker;

    uint256 maxBalanceAfterBuy;
    
    SwapWhitelistingSettings swapWhitelistingSettings;

    // Lossless data and events

    address recoveryAdmin;
    address recoveryAdminCandidate;
    bytes32 recoveryAdminKeyHash;
    address admin;
    uint256 timelockPeriod;
    uint256 losslessTurnOffTimestamp;
    bool isLosslessTurnOffProposed;
    bool isLosslessOn;
}

struct TaxSettings {
    bool transactionTax;
    bool buyBackTax;
    bool holderTax;
    bool lpTax;
    bool canBlacklist;
    bool canMint;
    bool canPause;
    bool maxBalanceAfterBuy;
}

struct Fee {
    uint256 buy;
    uint256 sell;
}

struct Fees {
    Fee transactionTax;
    uint256 buyBackTax;
    uint256 holderTax;
    uint256 lpTax;
}

struct CustomTax {
    string name;
    Fee fee;
    address wallet;
    bool withdrawAsGas;
}

struct AntiBotSettings {
    uint256 startBlock;
    uint256 endDate;
    uint256 increment;
    uint256 initialMaxHold;
    bool isActive;
}

struct SwapWhitelistingSettings {
    uint256 endDate;
    bool isActive;
}