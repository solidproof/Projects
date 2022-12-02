//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    IERC20Upgradeable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

import "./internal-upgradeable/FundForwarderUpgradeable.sol";

import {
    IWrappedNative,
    IUniswapV2Pair,
    IGovernanceToken,
    AggregatorV3Interface
} from "./interfaces/IGovernanceToken.sol";

import "./libraries/FixedPointMathLib.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";

contract GovernanceToken is
    IGovernanceToken,
    UUPSUpgradeable,
    ERC20PermitUpgradeable,
    ERC20PausableUpgradeable,
    ERC20BurnableUpgradeable,
    FundForwarderUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using FixedPointMathLib for uint256;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev value is equal to keccak256("GovernanceToken_v1")
    bytes32 public constant VERSION =
        0x9cb06d563b13cc55e25c1634b97935e3c39864e26c64c7995e81366244104777;

    /// @dev value is equal to keccak256("PAUSER_ROLE")
    bytes32 public constant PAUSER_ROLE =
        0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a;
    /// @dev value is equal to keccak256("OPERATOR_ROLE")
    bytes32 public constant OPERATOR_ROLE =
        0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929;
    /// @dev value is equal to keccak256("UPGRADER_ROLE")
    bytes32 public constant UPGRADER_ROLE =
        0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3;

    uint256 public constant ERC20_TAX_FRACTION = 250;
    uint256 public constant NATIVE_TAX_FRACTION = 250;
    uint256 public constant PERCENTAGE_FRACTION = 10_000;
    uint256 public constant TAX_ENABLED_DURATION = 20 minutes;

    bool public taxesEnabled; // deprecated
    IUniswapV2Pair public pool;
    IWrappedNative public wrappedNative;
    AggregatorV3Interface public priceFeed;

    BitMapsUpgradeable.BitMap private __isBlacklisted;

    uint256 public taxEnabledTimestamp;

    modifier whenTaxEnabled() {
        require(__isTaxEnabled(), "ERC20: TAXES_DISABLED");
        _;
    }

    function initialize(
        address admin_,
        string calldata name_,
        string calldata symbol_,
        ITreasury treasury_,
        IWrappedNative wrappedNative_,
        AggregatorV3Interface priceFeed_
    ) external initializer {
        priceFeed = priceFeed_;

        priceFeed = priceFeed_;
        wrappedNative = wrappedNative_;

        __Pausable_init_unchained();
        __UUPSUpgradeable_init_unchained();
        __EIP712_init_unchained(name_, "1");
        __ERC20_init_unchained(name_, symbol_);
        __FundForwarder_init_unchained(treasury_);

        _grantRole(PAUSER_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        _setRoleAdmin(PAUSER_ROLE, OPERATOR_ROLE);
        _setRoleAdmin(UPGRADER_ROLE, OPERATOR_ROLE);

        _mint(admin_, 2_000_000_000 * 10 ** decimals());
    }

    function transferFromWithTaxes(
        address from_,
        address to_,
        uint256 amount_
    ) external payable whenTaxEnabled returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from_, spender, amount_);

        uint256 erc20Tax = amount_.mulDivUp(
            ERC20_TAX_FRACTION,
            PERCENTAGE_FRACTION
        );

        _transfer(from_, to_, amount_ - erc20Tax);

        address _treasury = address(treasury());
        // send erc20 tax to treasury
        _transfer(from_, _treasury, erc20Tax);

        uint256 _nativeTax = __nativeTax(msg.value, pool);
        IWrappedNative _wrappedNative = wrappedNative;
        _wrappedNative.deposit{value: _nativeTax}();

        // refund
        _safeNativeTransfer(spender, msg.value - _nativeTax);
        // send native tax to treasury
        _safeERC20TransferFrom(_wrappedNative, spender, _treasury, _nativeTax);

        return true;
    }

    function transferWithTaxes(
        address to_,
        uint256 amount_
    ) external payable whenTaxEnabled returns (bool) {
        uint256 _nativeTax = __nativeTax(msg.value, pool);
        IWrappedNative _wrappedNative = wrappedNative;
        _wrappedNative.deposit{value: _nativeTax}();

        address owner = _msgSender();
        // refund
        _safeNativeTransfer(owner, msg.value - _nativeTax);

        uint256 erc20Tax = amount_.mulDivUp(
            ERC20_TAX_FRACTION,
            PERCENTAGE_FRACTION
        );

        _transfer(owner, to_, amount_ - erc20Tax);
        address _treasury = address(treasury());
        // send erc20 tax to treasury
        _transfer(owner, _treasury, erc20Tax);
        // send native tax to treasury
        _safeERC20TransferFrom(_wrappedNative, owner, _treasury, _nativeTax);

        return true;
    }

    function toggleTaxes() external onlyRole(OPERATOR_ROLE) {
        require(taxEnabledTimestamp == 0, "ERC20: ENABLED_BEFORE");
        taxEnabledTimestamp = block.timestamp;
    }

    function setPool(IUniswapV2Pair pool_) external onlyRole(OPERATOR_ROLE) {
        require(address(pool_) != address(0), "ERC20: NON_ZERO_ADDRESS");

        emit PoolSet(pool, pool_);

        pool = pool_;
    }

    function setUserStatus(
        address account_,
        bool status_
    ) external onlyRole(OPERATOR_ROLE) {
        uint256 account;
        assembly {
            account := account_
        }
        __isBlacklisted.setTo(account, status_);

        emit StatusSet(account_, status_);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function updateTreasury(
        ITreasury treasury_
    ) external override onlyRole(OPERATOR_ROLE) {
        require(address(treasury_) != address(0), "ERC20: ZERO_ADDRESS");

        emit TreasuryUpdated(treasury(), treasury_);

        _updateTreasury(treasury_);
    }

    function nativeTax(uint256 amount_) external view returns (uint256) {
        return __nativeTax(amount_, pool);
    }

    function __nativeTax(
        uint256 amount_,
        IUniswapV2Pair pool_
    ) private view returns (uint256) {
        (uint256 res0, uint256 res1, ) = pool_.getReserves();

        // amount token => amount native
        uint256 amtNative = amount_.mulDivUp(res0, res1);
        AggregatorV3Interface _priceFeed = priceFeed;
        (, int256 usd, , , ) = _priceFeed.latestRoundData();
        // amount native => amount usd
        uint256 amtUSD = amtNative.mulDivUp(
            uint256(usd),
            10 ** priceFeed.decimals()
        );

        // usd tax amount
        uint256 usdTax = amtUSD.mulDivUp(
            NATIVE_TAX_FRACTION,
            PERCENTAGE_FRACTION
        );
        // native tax amount
        return usdTax.mulDivUp(1 ether, uint256(usd));
    }

    function isBlacklisted(address account_) external view returns (bool) {
        uint256 account;
        assembly {
            account := account_
        }

        return __isBlacklisted.get(account);
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 amount_
    ) public override returns (bool) {
        bool isTaxEnabled = __isTaxEnabled();

        uint256 erc20Tax = amount_.mulDivUp(
            ERC20_TAX_FRACTION,
            PERCENTAGE_FRACTION
        );

        address spender = _msgSender();
        _spendAllowance(from_, spender, amount_);
        _transfer(from_, to_, isTaxEnabled ? amount_ - erc20Tax : amount_);

        if (!isTaxEnabled) return true;

        address _treasury = address(treasury());
        _transfer(from_, _treasury, erc20Tax);

        _safeERC20TransferFrom(
            wrappedNative,
            spender,
            _treasury,
            __nativeTax(amount_, pool)
        );

        return true;
    }

    function transfer(
        address to_,
        uint256 amount_
    ) public override returns (bool) {
        bool isTaxEnabled = __isTaxEnabled();

        uint256 erc20Tax = amount_.mulDivUp(
            ERC20_TAX_FRACTION,
            PERCENTAGE_FRACTION
        );

        address owner = _msgSender();
        _transfer(owner, to_, isTaxEnabled ? amount_ - erc20Tax : amount_);

        if (!isTaxEnabled) return true;

        address _treasury = address(treasury());
        _transfer(owner, _treasury, erc20Tax);

        _safeERC20TransferFrom(
            wrappedNative,
            owner,
            _treasury,
            __nativeTax(amount_, pool)
        );

        return true;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        __checkBlacklist(to);
        __checkBlacklist(from);
        __checkBlacklist(_msgSender());

        ERC20PausableUpgradeable._beforeTokenTransfer(from, to, amount);
    }

    function __checkBlacklist(address account_) private view {
        uint256 account;
        assembly {
            account := account_
        }

        require(!__isBlacklisted.get(account), "ERC20: BLACKLISTED");
    }

    function __isTaxEnabled() private view returns (bool) {
        return taxEnabledTimestamp + TAX_ENABLED_DURATION > block.timestamp;
    }

    function _authorizeUpgrade(
        address implement_
    ) internal virtual override onlyRole(UPGRADER_ROLE) {}

    uint256[44] private __gap;
}