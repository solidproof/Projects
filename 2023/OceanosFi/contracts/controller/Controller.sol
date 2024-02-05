// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IMinterIncentive.sol";
import "../interfaces/IController.sol";
import "../interfaces/IYieldAdapterIssuedPool.sol";

contract Controller is IController, Initializable {
    // call by usd
    mapping(address => bool) public mintAllowed;
    mapping(address => bool) public burnAllowed;

    // poolConfig
    mapping(address => PoolConfig) public poolConfig;

    // address provider
    mapping(bytes32 => address) public addresses;

    bytes32 public constant GOVERNANCE = "GOVERNANCE";

    bytes32 public constant OC_USD = "OC_USD";

    bytes32 public constant INCENTIVE_ADMIN = "INCENTIVE_ADMIN";

    bytes32 public constant PRICE_CALCULATOR = "PRICE_CALCULATOR";

    bytes32 public constant SAVING_POOL = "SAVING_POOL";

    function initialize() public initializer {
        _setAddress(GOVERNANCE, msg.sender);
        _setAddress(INCENTIVE_ADMIN, msg.sender);
    }

    modifier onlyGovernance() {
        require(
            msg.sender == addresses[GOVERNANCE],
            "Only governance can call this function"
        );
        _;
    }

    modifier onlyIncentiveAdmin() {
        require(
            msg.sender == addresses[INCENTIVE_ADMIN],
            "Only incentive admin can call this function"
        );
        _;
    }

    function setMintAllowed(
        address _pool,
        bool _allowed
    ) external onlyGovernance {
        mintAllowed[_pool] = _allowed;
    }

    function setBurnAllowed(
        address _pool,
        bool _allowed
    ) external onlyGovernance {
        burnAllowed[_pool] = _allowed;
    }

    function getPoolConfig(
        address _pool
    ) external view returns (PoolConfig memory) {
        return poolConfig[_pool];
    }

    function setPoolConfig(
        address _issuedPool,
        uint256 _minimumCollateralAmount,
        uint256 _maximumMintAmount,
        uint256 _mintFeeApy, // 10000 = 100%
        uint256 _safeCollateralRatio,
        uint256 _liquidationCollateralRatio,
        uint256 _liquidationPenalty,
        uint256 _liquidatorReward,
        address _mintIncentivePool,
        address _collateralAsset
    ) external onlyGovernance {
        poolConfig[_issuedPool] = PoolConfig({
            minimumCollateralAmount: _minimumCollateralAmount,
            maximumMintAmount: _maximumMintAmount,
            mintFeeApy: _mintFeeApy,
            safeCollateralRatio: _safeCollateralRatio,
            liquidationCollateralRatio: _liquidationCollateralRatio,
            liquidationPenalty: _liquidationPenalty,
            liquidatorReward: _liquidatorReward,
            mintIncentivePool: _mintIncentivePool,
            collateralAsset: _collateralAsset
        });
        emit PoolConfigSet(_issuedPool, poolConfig[_issuedPool]);
    }

    function getGovernance() public view returns (address) {
        return getAddress(GOVERNANCE);
    }

    function getPriceCalculator() public view returns (address) {
        return getAddress(PRICE_CALCULATOR);
    }

    function getIncentiveAdmin() public view returns (address) {
        return getAddress(INCENTIVE_ADMIN);
    }

    function getSavingPool() public view returns (address) {
        return getAddress(SAVING_POOL);
    }

    function getAddress(bytes32 _key) public view returns (address) {
        return addresses[_key];
    }

    function setAddress(bytes32 _key, address _value) external onlyGovernance {
        _setAddress(_key, _value);
    }

    function setPriceCalculator(address _value) external onlyGovernance {
        _setAddress(PRICE_CALCULATOR, _value);
    }

    function setIncentiveAdmin(address _value) external onlyGovernance {
        _setAddress(INCENTIVE_ADMIN, _value);
    }

    function setSavingPool(address _value) external onlyGovernance {
        _setAddress(SAVING_POOL, _value);
    }

    function _setAddress(bytes32 _key, address _value) internal {
        addresses[_key] = _value;
        emit AddressSet(_key, _value);
    }

    function refreshMintReward(address account) external {
        address incentivePool = poolConfig[msg.sender].mintIncentivePool;
        if (incentivePool != address(0)) {
            IMinterIncentive(incentivePool).refreshReward(account);
        }
    }

    function notifyYieldReward(address _token, uint256 _yield) external {
        address incentivePool = poolConfig[msg.sender].mintIncentivePool;
        if (incentivePool != address(0)) {
            IERC20(_token).approve(incentivePool, _yield);
            IMinterIncentive(incentivePool).notifyRewardAmount(_token, _yield);
        }
    }

    function processYields(
        address[] calldata _yieldPools
    ) external onlyIncentiveAdmin {
        uint256 length = _yieldPools.length;
        for (uint256 i = 0; i < length; ) {
            IYieldAdapterIssuedPool(_yieldPools[i]).processYield();
            unchecked {
                i++;
            }
        }
    }

    receive() external payable {}
}
