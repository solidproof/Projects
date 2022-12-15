// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "../interfaces/ILosslessController.sol";

contract Storage {

    uint256 public CONTRACT_VERSION = 1;

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
    }

    TaxSettings public taxSettings;
    TaxSettings public isLocked;
    Fees public fees;
    CustomTax[] public customTaxes;

    address public transactionTaxWallet;
    uint256 public customTaxLength = 0;
    uint256 public MaxTax = 3000;
    uint8 public MaxCustom = 10;

    uint256 internal DENOMINATOR;

    mapping (address => uint256) internal _rOwned;
    mapping (address => uint256) internal _tOwned;
    mapping (address => mapping (address => uint256)) public _allowances;

    mapping (address => bool) public _isExcluded;
    address[] internal _excluded;
   
    uint256 constant MAX = ~uint256(0);
    uint256 internal _tTotal;
    uint256 internal _rTotal;
    uint256 public _tFeeTotal;

    mapping (address => bool) public lpTokens;
    
    string internal _name;
    string internal _symbol;
    uint8 internal _decimals;
    address internal _creator;

    address public factory;

    address public buyBackWallet;
    address public lpWallet;

    bool internal isPaused = false;

    bool internal isTaxed = false;
    
    mapping(address => bool) internal blacklist;
    mapping(address => bool) internal swapWhitelist;
    mapping(address => bool) internal maxBalanceWhitelist;

    address public pairAddress;

    uint256 public taxHelperIndex;

    // AntiBot Variables

    bool public marketInit = false;
    uint256 public marketInitBlockTime;

    struct AntiBotSettings {
        uint256 startBlock;
        uint256 endDate;
        uint256 increment;
        uint256 initialMaxHold;
        bool isActive;
    }

    AntiBotSettings public antiBotSettings;

    mapping (address => uint256) internal antiBotBalanceTracker;

    uint256 public maxBalanceAfterBuy;

    struct SwapWhitelistingSettings {
        uint256 endDate;
        bool isActive;
    }
    
    SwapWhitelistingSettings public swapWhitelistingSettings;

    // Lossless data and events

    address public recoveryAdmin;
    address internal recoveryAdminCandidate;
    bytes32 internal recoveryAdminKeyHash;
    address public admin;
    uint256 public timelockPeriod;
    uint256 public losslessTurnOffTimestamp;
    bool public isLosslessTurnOffProposed;
    bool public isLosslessOn;
    ILosslessController public lossless;

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event RecoveryAdminChangeProposed(address indexed candidate);
    event RecoveryAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event LosslessTurnOffProposed(uint256 turnOffDate);
    event LosslessTurnedOff();
    event LosslessTurnedOn();

    // Events 

    event TokenCreated(string name, string symbol, uint8 decimals, uint256 totalSupply, uint256 reflectionTotalSupply);

    event AddedBlacklistAddress(address _address);
    event RemovedBlacklistAddress(address _address);
    event ToggledPause(bool _isPaused);
    event AddedLPToken(address _newLPToken);
    event RemovedLPToken(address _lpToken);
    event CreatedBuyBackWallet(address _wallet);
    event CreatedLPWallet(address _wallet);
    event UpdatedBuyBackWalletThreshold(uint256 _newThreshold);
    event UpdatedLPWalletThreshold(uint256 _newThreshold);

    event MarketInit(uint256 timestamp, uint256 blockNumber);

    event BuyBackTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event TransactionTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event LPTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event CustomTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);

    event UpdatedCustomTaxes(CustomTax[] _customTaxes);
    event UpdatedTaxFees(Fees _updatedFees);
    event UpdatedTransactionTaxAddress(address _newAddress);
    event UpdatedLockedSettings(TaxSettings _updatedLocks);
    event UpdatedSettings(TaxSettings _updatedSettings);
    event UpdatedPairAddress(address _newPairAddress);
    event UpdatedTaxHelperIndex(uint _newIndex);

    event Reflect(uint256 tAmount, uint256 rAmount, uint256 rTotal_, uint256 teeTotal_);
    event ExcludedAccount(address account);
    event IncludedAccount(address account);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // AntiBot

    event UpdatedAntiBotSettings(AntiBotSettings _antiBotSettings);
    event UpdatedSwapWhitelistingSettings(SwapWhitelistingSettings _swapWhitelistingSettings);

    event UpdatedAntiBotIncrement(uint256 _updatedIncrement);
    event UpdatedAntiBotEndDate(uint256 _updatedEndDate);
    event UpdatedAntiBotInitialMaxHold(uint256 _updatedInitialMaxHold);
    event UpdatedAntiBotActiveStatus(bool _isActive);
    event UpdatedSwapWhitelistingEndDate(uint256 _updatedEndDate);
    event UpdatedSwapWhitelistingActiveStatus(bool _isActive);
    event UpdatedMaxBalanceAfterBuy(uint256 _newMaxBalance);

    event AddedMaxBalanceWhitelistAddress(address _address);   
    event RemovedMaxBalanceWhitelistAddress(address _address);        
    event AddedSwapWhitelistAddress(address _address);
    event RemovedSwapWhitelistAddress(address _address);
}