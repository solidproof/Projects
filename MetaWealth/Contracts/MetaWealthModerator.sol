/// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IMetaWealthModerator.sol";
import "./MetaWealthAccessControlled.sol";

contract MetaWealthModerator is
    IMetaWealthModerator,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    MetaWealthAccessControlled
{
    /// @notice List of supported currencies (name => address)
    mapping(address => bool) supportedCurrencies;

    /// @notice MetaWealth platform's default currency
    address defaultCurrency;

    /// @notice Active whitelist merkle root
    bytes32 whitelistRoot;

    /// @notice Sets the default timestamp for when the assets can be defractionalized
    uint64 defaultUnlockPeriod; // 3-months

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize exchange contract with necessary factories
    function initialize(address defaultCurrency_, bytes32 _initialRoot)
        public
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();
        initializeMetaWealthAccessControl();
        defaultCurrency = defaultCurrency_;
        whitelistRoot = _initialRoot;
        defaultUnlockPeriod = 7884000; // 3 months

        emit CurrencySupportToggled(defaultCurrency, true, true);
        emit WhitelistRootUpdated("", whitelistRoot);
        emit UnlockPeriodChanged(0, defaultUnlockPeriod);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function isSupportedCurrency(address token)
        external
        view
        override
        returns (bool)
    {
        return supportedCurrencies[token];
    }

    function getDefaultCurrency() external view override returns (address) {
        return defaultCurrency;
    }

    function setDefaultCurrency(address newCurrency)
        external
        override
        onlyAdmin
    {
        emit CurrencySupportToggled(defaultCurrency, false, true);
        defaultCurrency = newCurrency;
        emit CurrencySupportToggled(defaultCurrency, true, true);
    }

    function toggleSupportedCurrency(address token)
        external
        override
        onlyAdmin
        returns (bool newState)
    {
        supportedCurrencies[token] = !supportedCurrencies[token];
        newState = supportedCurrencies[token];
        emit CurrencySupportToggled(token, newState, false);
    }

    function updateWhitelistRoot(bytes32 _newRoot) external override onlyAdmin {
        emit WhitelistRootUpdated(whitelistRoot, _newRoot);
        whitelistRoot = _newRoot;
    }

    function checkWhitelist(bytes32[] calldata _merkleProof, address wallet)
        public
        view
        override
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(wallet));
        return MerkleProof.verify(_merkleProof, whitelistRoot, leaf);
    }

    function getDefaultUnlockPeriod() external view override returns (uint64) {
        return defaultUnlockPeriod;
    }

    function setDefaultUnlockPeriod(uint64 newPeriod)
        external
        override
        onlyAdmin
    {
        emit UnlockPeriodChanged(defaultUnlockPeriod, newPeriod);
        defaultUnlockPeriod = newPeriod;
    }

    function _msgSender()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(Context, ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    function version() public pure returns (string memory _version) {
        return "V2";
    }
}
