// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {MathConstants} from './libraries/MathConstants.sol';
import {IFactory} from './interfaces/IFactory.sol';
import {Pool} from './Pool.sol';

/// @title KyberSwap v2 factory
/// @notice Deploys KyberSwap v2 pools and manages control over government fees
contract Factory is IFactory {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Parameters {
        address factory;
        address poolOracle;
        address token0;
        address token1;
        uint24 swapFeeUnits;
        int24 tickDistance;
    }

    /// @inheritdoc IFactory
    Parameters public override parameters;

    /// @inheritdoc IFactory
    bytes32 public immutable override poolInitHash;
    address public immutable override poolOracle;
    address public override configMaster;
    bool public override whitelistDisabled;

    address private feeTo;
    uint24 private governmentFeeUnits;
    uint32 public override vestingPeriod;

    /// @inheritdoc IFactory
    mapping(uint24 => int24) public override feeAmountTickDistance;
    /// @inheritdoc IFactory
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    // list of whitelisted NFT position manager(s)
    // that are allowed to burn liquidity tokens on behalf of users
    EnumerableSet.AddressSet internal whitelistedNFTManagers;

    event NFTManagerAdded(address _nftManager, bool added);
    event NFTManagerRemoved(address _nftManager, bool removed);

    modifier onlyConfigMaster() {
        require(msg.sender == configMaster, 'forbidden');
        _;
    }

    constructor(uint32 _vestingPeriod, address _poolOracle, bytes32 poolBytecodeHash) {
        poolInitHash = poolBytecodeHash;

        require(_poolOracle != address(0), 'invalid pool oracle');
        poolOracle = _poolOracle;

        vestingPeriod = _vestingPeriod;
        emit VestingPeriodUpdated(_vestingPeriod);

        configMaster = msg.sender;
        emit ConfigMasterUpdated(address(0), configMaster);

        feeAmountTickDistance[8] = 1;
        //emit SwapFeeEnabled(8, 1);

        //feeAmountTickDistance[10] = 1;
        //emit SwapFeeEnabled(10, 1);

        //feeAmountTickDistance[40] = 8;
        //emit SwapFeeEnabled(40, 8);

        feeAmountTickDistance[300] = 60;
        //emit SwapFeeEnabled(300, 60);

        //feeAmountTickDistance[1000] = 200;
        //emit SwapFeeEnabled(1000, 200);
    }

    /// @inheritdoc IFactory
    function createPool(
        address tokenA,
        address tokenB,
        uint24 swapFeeUnits
    ) external override returns (address pool) {
        require(tokenA != tokenB, 'identical tokens');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'null address');
        int24 tickDistance = feeAmountTickDistance[swapFeeUnits];
        require(tickDistance != 0, 'invalid fee');
        require(getPool[token0][token1][swapFeeUnits] == address(0), 'pool exists');

        parameters.factory = address(this);
        parameters.poolOracle = poolOracle;
        parameters.token0 = token0;
        parameters.token1 = token1;
        parameters.swapFeeUnits = swapFeeUnits;
        parameters.tickDistance = tickDistance;

        pool = address(new Pool{salt: keccak256(abi.encode(token0, token1, swapFeeUnits))}());
        getPool[token0][token1][swapFeeUnits] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][swapFeeUnits] = pool;
        emit PoolCreated(token0, token1, swapFeeUnits, tickDistance, pool);
    }

    /// @inheritdoc IFactory
    function updateConfigMaster(address _configMaster) external override onlyConfigMaster {
        emit ConfigMasterUpdated(configMaster, _configMaster);
        configMaster = _configMaster;
    }

    /// @inheritdoc IFactory
    function enableWhitelist() external override onlyConfigMaster {
        whitelistDisabled = false;
        emit WhitelistEnabled();
    }

    /// @inheritdoc IFactory
    function disableWhitelist() external override onlyConfigMaster {
        whitelistDisabled = true;
        emit WhitelistDisabled();
    }

    // Whitelists an NFT manager
    // Returns true if addition was successful, that is if it was not already present
    function addNFTManager(address _nftManager) external onlyConfigMaster returns (bool added) {
        added = whitelistedNFTManagers.add(_nftManager);
        emit NFTManagerAdded(_nftManager, added);
    }

    // Removes a whitelisted NFT manager
    // Returns true if removal was successful, that is if it was not already present
    function removeNFTManager(address _nftManager) external onlyConfigMaster returns (bool removed) {
        removed = whitelistedNFTManagers.remove(_nftManager);
        emit NFTManagerRemoved(_nftManager, removed);
    }

    /// @inheritdoc IFactory
    function updateVestingPeriod(uint32 _vestingPeriod) external override onlyConfigMaster {
        vestingPeriod = _vestingPeriod;
        emit VestingPeriodUpdated(_vestingPeriod);
    }

    /// @inheritdoc IFactory
    function enableSwapFee(uint24 swapFeeUnits, int24 tickDistance)
    public
    override
    onlyConfigMaster
    {
        require(swapFeeUnits < MathConstants.FEE_UNITS, 'invalid fee');
        // tick distance is capped at 16384 to prevent the situation where tickDistance is so large that
        // 16384 ticks represents a >5x price change with ticks of 1 bips
        require(tickDistance > 0 && tickDistance < 16384, 'invalid tickDistance');
        require(feeAmountTickDistance[swapFeeUnits] == 0, 'existing tickDistance');
        feeAmountTickDistance[swapFeeUnits] = tickDistance;
        emit SwapFeeEnabled(swapFeeUnits, tickDistance);
    }

    /// @inheritdoc IFactory
    function updateFeeConfiguration(address _feeTo, uint24 _governmentFeeUnits)
    external
    override
    onlyConfigMaster
    {
        require(_governmentFeeUnits <= MathConstants.FEE_UNITS, 'invalid fee');
        require(
            (_feeTo == address(0) && _governmentFeeUnits == 0) ||
            (_feeTo != address(0) && _governmentFeeUnits != 0),
            'bad config'
        );
        feeTo = _feeTo;
        governmentFeeUnits = _governmentFeeUnits;
        emit FeeConfigurationUpdated(_feeTo, _governmentFeeUnits);
    }

    /// @inheritdoc IFactory
    function feeConfiguration()
    external
    view
    override
    returns (address _feeTo, uint24 _governmentFeeUnits)
    {
        _feeTo = feeTo;
        _governmentFeeUnits = governmentFeeUnits;
    }

    /// @inheritdoc IFactory
    function isWhitelistedNFTManager(address sender) external view override returns (bool) {
        if (whitelistDisabled) return true;
        return whitelistedNFTManagers.contains(sender);
    }

    /// @inheritdoc IFactory
    function getWhitelistedNFTManagers() external view override returns (address[] memory) {
        return whitelistedNFTManagers.values();
    }
}
