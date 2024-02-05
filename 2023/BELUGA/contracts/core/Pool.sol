// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

import '../libraries/DSMath.sol';
import '../interfaces/IPriceOracleGetter.sol';
import '../asset/Asset.sol';
import './Core.sol';

/**
 * @title Pool
 * @notice Manages deposits, withdrawals and swaps. Holds a mapping of assets and parameters.
 * @dev The main entry-point of Beluga protocol
 *
 * Note The Pool is ownable and the owner wields power.
 * Note The ownership will be transferred to a governance contract once Beluga community can show to govern itself.
 *
 * The unique features of the Beluga make it an important subject in the study of evolutionary biology.
 */
contract Pool is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable, Core {
    using DSMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice Asset Map struct holds assets
    struct AssetMap {
        address[] keys;
        mapping(address => Asset) values;
        mapping(address => uint256) indexOf;
        mapping(address => bool) inserted;
    }

    /// @notice Wei in 1 ether
    uint256 private constant ETH_UNIT = 10**18;

    /// @notice Slippage parameters K, N, C1 and xThreshold
    uint256 private _slippageParamK;
    uint256 private _slippageParamN;
    uint256 private _c1;
    uint256 private _xThreshold;

    /// @notice Haircut rate
    uint256 private _haircutRate;

    /// @notice Retention ratio
    uint256 private _retentionRatio;

    /// @notice Maximum price deviation
    /// @dev states the maximum price deviation allowed between assets
    uint256 private _maxPriceDeviation;

    /// @notice Dev address
    address private _dev;

    /// @notice The price oracle interface used in swaps
    IPriceOracleGetter private _priceOracle;

    /// @notice A record of assets inside Pool
    AssetMap private _assets;

    /// @notice An event emitted when an asset is added to Pool
    event AssetAdded(address indexed token, address indexed asset);

    /// @notice An event emitted when a deposit is made to Pool
    event Deposit(address indexed sender, address token, uint256 amount, uint256 liquidity, address indexed to);

    /// @notice An event emitted when a withdrawal is made from Pool
    event Withdraw(address indexed sender, address token, uint256 amount, uint256 liquidity, address indexed to);

    /// @notice An event emitted when dev is updated
    event DevUpdated(address indexed previousDev, address indexed newDev);

    /// @notice An event emitted when oracle is updated
    event OracleUpdated(address indexed previousOracle, address indexed newOracle);

    /// @notice An event emitted when price deviation is updated
    event PriceDeviationUpdated(uint256 previousPriceDeviation, uint256 newPriceDeviation);

    /// @notice An event emitted when slippage params are updated
    event SlippageParamsUpdated(
        uint256 previousK,
        uint256 newK,
        uint256 previousN,
        uint256 newN,
        uint256 previousC1,
        uint256 newC1,
        uint256 previousXThreshold,
        uint256 newXThreshold
    );

    /// @notice An event emitted when haircut is updated
    event HaircutRateUpdated(uint256 previousHaircut, uint256 newHaircut);

    /// @notice An event emitted when retention ratio is updated
    event RetentionRatioUpdated(uint256 previousRetentionRatio, uint256 newRetentionRatio);

    /// @notice An event emitted when a swap is made in Pool
    event Swap(
        address indexed sender,
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 toAmount,
        address indexed to
    );

    /// @dev Modifier ensuring that certain function can only be called by developer
    modifier onlyDev() {
        require(_dev == msg.sender, 'FORBIDDEN');
        _;
    }

    /// @dev Modifier ensuring a certain deadline for a function to complete execution
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    /**
     * @notice Initializes pool. Dev is set to be the account calling this function.
     */
    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init_unchained();
        __Pausable_init_unchained();

        // set variables
        _slippageParamK = 0.00002e18; //2 * 10**13 == 0.00002 * WETH
        _slippageParamN = 7; // 7
        _c1 = 376927610599998308; // ((k**(1/(n+1))) / (n**((n)/(n+1)))) + (k*n)**(1/(n+1))
        _xThreshold = 329811659274998519; // (k*n)**(1/(n+1))
        _haircutRate = 0.0004e18; // 4 * 10**14 == 0.0004 == 0.04% for intra-aggregate account swap
        _retentionRatio = ETH_UNIT; // 1
        _maxPriceDeviation = 0.02e18; // 2 * 10**16 == 2% = 0.02 in ETH_UNIT.

        // set dev
        _dev = msg.sender;
    }

    // Getters //

    /**
     * @notice Gets current Dev address
     * @return The current Dev address for Pool
     */
    function getDev() external view returns (address) {
        return _dev;
    }

    /**
     * @notice Gets current Price Oracle address
     * @return The current Price Oracle address for Pool
     */
    function getPriceOracle() external view returns (address) {
        return address(_priceOracle);
    }

    /**
     * @notice Gets current C1 slippage parameter
     * @return The current C1 slippage parameter in Pool
     */
    function getC1() external view returns (uint256) {
        return _c1;
    }

    /**
     * @notice Gets current XThreshold slippage parameter
     * @return The current XThreshold slippage parameter in Pool
     */
    function getXThreshold() external view returns (uint256) {
        return _xThreshold;
    }

    /**
     * @notice Gets current K slippage parameter
     * @return The current K slippage parameter in Pool
     */
    function getSlippageParamK() external view returns (uint256) {
        return _slippageParamK;
    }

    /**
     * @notice Gets current N slippage parameter
     * @return The current N slippage parameter in Pool
     */
    function getSlippageParamN() external view returns (uint256) {
        return _slippageParamN;
    }

    /**
     * @notice Gets current Haircut parameter
     * @return The current Haircut parameter in Pool
     */
    function getHaircutRate() external view returns (uint256) {
        return _haircutRate;
    }

    /**
     * @notice Gets current retention ratio parameter
     * @return The current retention ratio parameter in Pool
     */
    function getRetentionRatio() external view returns (uint256) {
        return _retentionRatio;
    }

    /**
     * @notice Gets current maxPriceDeviation parameter
     * @return The current _maxPriceDeviation parameter in Pool
     */
    function getMaxPriceDeviation() external view returns (uint256) {
        return _maxPriceDeviation;
    }

    /**
     * @dev pause pool, restricting certain operations
     */
    function pause() external onlyDev {
        _pause();
    }

    /**
     * @dev unpause pool, enabling certain operations
     */
    function unpause() external onlyDev {
        _unpause();
    }

    // Setters //
    /**
     * @notice Changes the contract dev. Can only be set by the contract owner.
     * @param dev new contract dev address
     */
    function setDev(address dev) external onlyOwner {
        require(dev != address(0), 'ZERO');
        emit DevUpdated(_dev, dev);
        _dev = dev;
    }

    /**
     * @notice Changes the pools slippage params. Can only be set by the contract owner.
     * @param k_ new pool's slippage param K
     * @param n_ new pool's slippage param N
     * @param c1_ new pool's slippage param C1
     * @param xThreshold_ new pool's slippage param xThreshold
     */
    function setSlippageParams(
        uint256 k_,
        uint256 n_,
        uint256 c1_,
        uint256 xThreshold_
    ) external onlyOwner {
        require(k_ <= ETH_UNIT); // k should not be set bigger than 1
        require(n_ > 0); // n should be bigger than 0

        emit SlippageParamsUpdated(_slippageParamK, k_, _slippageParamN, n_, _c1, c1_, _xThreshold, xThreshold_);

        _slippageParamK = k_;
        _slippageParamN = n_;
        _c1 = c1_;
        _xThreshold = xThreshold_;
    }

    /**
     * @notice Changes the pools haircutRate. Can only be set by the contract owner.
     * @param haircutRate_ new pool's haircutRate_
     */
    function setHaircutRate(uint256 haircutRate_) external onlyOwner {
        require(haircutRate_ <= ETH_UNIT); // haircutRate_ should not be set bigger than 1
        emit HaircutRateUpdated(_haircutRate, haircutRate_);
        _haircutRate = haircutRate_;
    }

    /**
     * @notice Changes the pools retentionRatio. Can only be set by the contract owner.
     * @param retentionRatio_ new pool's retentionRatio
     */
    function setRetentionRatio(uint256 retentionRatio_) external onlyOwner {
        require(retentionRatio_ <= ETH_UNIT); // retentionRatio_ should not be set bigger than 1
        emit RetentionRatioUpdated(_retentionRatio, retentionRatio_);
        _retentionRatio = retentionRatio_;
    }

    /**
     * @notice Changes the pools maxPriceDeviation. Can only be set by the contract owner.
     * @param maxPriceDeviation_ new pool's maxPriceDeviation
     */
    function setMaxPriceDeviation(uint256 maxPriceDeviation_) external onlyOwner {
        require(maxPriceDeviation_ <= ETH_UNIT); // maxPriceDeviation_ should not be set bigger than 1
        emit PriceDeviationUpdated(_maxPriceDeviation, maxPriceDeviation_);
        _maxPriceDeviation = maxPriceDeviation_;
    }

    /**
     * @notice Changes the pools priceOracle. Can only be set by the contract owner.
     * @param priceOracle new pool's priceOracle addres
     */
    function setPriceOracle(address priceOracle) external onlyOwner {
        require(priceOracle != address(0), 'ZERO');
        emit OracleUpdated(address(_priceOracle), priceOracle);
        _priceOracle = IPriceOracleGetter(priceOracle);
    }

    // Asset struct functions //

    /**
     * @notice Gets asset with token address key
     * @param key The address of token
     * @return the corresponding asset in state
     */
    function _getAsset(address key) private view returns (Asset) {
        return _assets.values[key];
    }

    /**
     * @notice Gets key (address) at index
     * @param index the index
     * @return the key of index
     */
    function _getKeyAtIndex(uint256 index) private view returns (address) {
        return _assets.keys[index];
    }

    /**
     * @notice get length of asset list
     * @return the size of the asset list
     */
    function _sizeOfAssetList() private view returns (uint256) {
        return _assets.keys.length;
    }

    /**
     * @notice Looks if the asset is contained by the list
     * @param key The address of token to look for
     * @return bool true if the asset is in asset list, false otherwise
     */
    function _containsAsset(address key) private view returns (bool) {
        return _assets.inserted[key];
    }

    /**
     * @notice Adds asset to the list
     * @param key The address of token to look for
     * @param val The asset to add
     */
    function _addAsset(address key, Asset val) private {
        if (_assets.inserted[key]) {
            _assets.values[key] = val;
        } else {
            _assets.inserted[key] = true;
            _assets.values[key] = val;
            _assets.indexOf[key] = _assets.keys.length;
            _assets.keys.push(key);
        }
    }

    /**
     * @notice Removes asset from asset struct
     * @dev Can only be called by owner
     * @param key The address of token to remove
     */
    function removeAsset(address key) external onlyOwner {
        if (!_assets.inserted[key]) {
            return;
        }

        delete _assets.inserted[key];
        delete _assets.values[key];

        uint256 index = _assets.indexOf[key];
        uint256 lastIndex = _assets.keys.length - 1;
        address lastKey = _assets.keys[lastIndex];

        _assets.indexOf[lastKey] = index;
        delete _assets.indexOf[key];

        _assets.keys[index] = lastKey;
        _assets.keys.pop();
    }

    // Pool Functions //
    /**
     * @notice Checks deviation is not higher than specified amount
     * @dev Reverts if deviation is higher than _maxPriceDeviation
     * @param tokenA First token
     * @param tokenB Second token
     */
    function _checkPriceDeviation(address tokenA, address tokenB) private view {
        uint256 tokenAPrice = _priceOracle.getAssetPrice(tokenA);
        uint256 tokenBPrice = _priceOracle.getAssetPrice(tokenB);

        // check if prices respect their maximum deviation for a > b : (a - b) / a < maxDeviation
        if (tokenBPrice > tokenAPrice) {
            require((((tokenBPrice - tokenAPrice) * ETH_UNIT) / tokenBPrice) <= _maxPriceDeviation, 'PRICE_DEV');
        } else {
            require((((tokenAPrice - tokenBPrice) * ETH_UNIT) / tokenAPrice) <= _maxPriceDeviation, 'PRICE_DEV');
        }
    }

    /**
     * @notice gets system equilibrium coverage ratio
     * @dev [ sum of Ai * fi / sum Li * fi ]
     * @return equilibriumCoverageRatio system equilibrium coverage ratio
     */
    function getEquilibriumCoverageRatio() private view returns (uint256) {
        uint256 totalCash = 0;
        uint256 totalLiability = 0;

        // loop on assets
        for (uint256 i = 0; i < _sizeOfAssetList(); i++) {
            // get token address
            address assetAddress = _getKeyAtIndex(i);

            // get token oracle price
            // uint256 tokenPrice = _priceOracle.getAssetPrice(assetAddress);
            uint256 tokenPrice = 1;
            // used to convert cash and liabilities into ETH_UNIT to have equal decimals accross all assets
            uint256 offset = 10**(18 - _getAsset(assetAddress).decimals());

            totalCash += (_getAsset(assetAddress).cash() * offset * tokenPrice);
            totalLiability += (_getAsset(assetAddress).liability() * offset * tokenPrice);
        }
        // if there are no liabilities or no assets in the pool, return equilibrium state = 1
        if (totalLiability == 0 || totalCash == 0) {
            return ETH_UNIT;
        }

        return totalCash.wdiv(totalLiability);
    }

    /**
     * @notice Adds asset to pool, reverts if asset already exists in pool
     * @param token The address of token
     * @param asset The address of the beluga Asset contract
     */
    function addAsset(address token, address asset) external onlyOwner {
        require(token != address(0), 'ZERO');
        require(asset != address(0), 'ZERO');
        require(!_containsAsset(token), 'ASSET_EXISTS');

        _addAsset(token, Asset(asset));

        emit AssetAdded(token, asset);
    }

    /**
     * @notice Gets Asset corresponding to ERC20 token. Reverts if asset does not exists in Pool.
     * @param token The address of ERC20 token
     */
    function _assetOf(address token) internal view returns (Asset) {
        require(_containsAsset(token), 'ASSET_NOT_EXIST');
        return _getAsset(token);
    }

    /**
     * @notice Gets Asset corresponding to ERC20 token. Reverts if asset does not exists in Pool.
     * @dev to be used externally
     * @param token The address of ERC20 token
     */
    function assetOf(address token) external view returns (address) {
        return address(_assetOf(token));
    }

    /**
     * @notice Deposits asset in Pool
     * @param asset The asset to be deposited
     * @param amount The amount to be deposited
     * @param to The user accountable for deposit, receiving the beluga assets (lp)
     * @return liquidity Total asset liquidity minted
     */
    function _deposit(
        Asset asset,
        uint256 amount,
        address to
    ) private returns (uint256 liquidity) {
        uint256 totalSupply = asset.totalSupply();
        uint256 liability = asset.liability();

        uint256 fee = _depositFee(_slippageParamK, _slippageParamN, _c1, _xThreshold, asset.cash(), liability, amount);

        // Calculate amount of LP to mint : ( deposit - fee ) * TotalAssetSupply / Liability
        if (liability == 0) {
            liquidity = amount - fee;
        } else {
            liquidity = ((amount - fee) * totalSupply) / liability;
        }
        // get equilibrium coverage ratio
        uint256 eqCov = getEquilibriumCoverageRatio();
        
        // apply impairment gain if eqCov < 1
        if (eqCov < ETH_UNIT) {
            liquidity = liquidity.wdiv(eqCov);
        }

        require(liquidity > 0, 'INSUFFICIENT_LIQ_MINT');

        asset.addCash(amount);
        asset.addLiability(amount - fee);
        asset.mint(to, liquidity);
    }

    /**
     * @notice Deposits amount of tokens into pool ensuring deadline
     * @dev Asset needs to be created and added to pool before any operation
     * @param token The token address to be deposited
     * @param amount The amount to be deposited
     * @param to The user accountable for deposit, receiving the beluga assets (lp)
     * @param deadline The deadline to be respected
     * @return liquidity Total asset liquidity minted
     */
    function deposit(
        address token,
        uint256 amount,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (uint256 liquidity) {
        require(amount > 0, 'ZERO_AMOUNT');
        require(token != address(0), 'ZERO');
        require(to != address(0), 'ZERO');

        IERC20 erc20 = IERC20(token);
        Asset asset = _assetOf(token);
        erc20.safeTransferFrom(address(msg.sender), address(asset), amount);
        liquidity = _deposit(asset, amount, to);

        emit Deposit(msg.sender, token, amount, liquidity, to);
    }

    /**
     * @notice Calculates fee and liability to burn in case of withdrawal
     * @param asset The asset willing to be withdrawn
     * @param liquidity The liquidity willing to be withdrawn
     * @return amount Total amount to be withdrawn from Pool
     * @return liabilityToBurn Total liability to be burned by Pool
     * @return fee The fee of the withdraw operation
     */
    function _withdrawFrom(Asset asset, uint256 liquidity)
        private
        view
        returns (
            uint256 amount,
            uint256 liabilityToBurn,
            uint256 fee,
            bool enoughCash
        )
    {
        liabilityToBurn = (asset.liability() * liquidity) / asset.totalSupply();
        require(liabilityToBurn > 0, 'INSUFFICIENT_LIQ_BURN');

        fee = _withdrawalFee(
            _slippageParamK,
            _slippageParamN,
            _c1,
            _xThreshold,
            asset.cash(),
            asset.liability(),
            liabilityToBurn
        );

        // Get equilibrium coverage ratio before withdraw
        uint256 eqCov = getEquilibriumCoverageRatio();

        // Init enoughCash to true
        enoughCash = true;

        // Apply impairment in the case eqCov < 1
        uint256 amountAfterImpairment;
        if (eqCov < ETH_UNIT) {
            amountAfterImpairment = (liabilityToBurn).wmul(eqCov);
        } else {
            amountAfterImpairment = liabilityToBurn;
        }

        // Prevent underflow in case withdrawal fees >= liabilityToBurn, user would only burn his underlying liability
        if (amountAfterImpairment > fee) {
            amount = amountAfterImpairment - fee;

            // If not enough cash
            if (asset.cash() < amount) {
                amount = asset.cash(); // When asset does not contain enough cash, just withdraw the remaining cash
                fee = 0;
                enoughCash = false;
            }
        } else {
            fee = amountAfterImpairment; // fee overcomes the amount to withdraw. User would be just burning liability
            amount = 0;
            enoughCash = false;
        }
    }

    /**
     * @notice Withdraws liquidity amount of asset to `to` address ensuring minimum amount required
     * @param asset The asset to be withdrawn
     * @param liquidity The liquidity to be withdrawn
     * @param minimumAmount The minimum amount that will be accepted by user
     * @param to The user receiving the withdrawal
     * @return amount The total amount withdrawn
     */
    function _withdraw(
        Asset asset,
        uint256 liquidity,
        uint256 minimumAmount,
        address to
    ) private returns (uint256 amount) {
        // request lp token from user
        IERC20Upgradeable(asset).safeTransferFrom(address(msg.sender), address(asset), liquidity);

        // calculate liabilityToBurn and Fee
        uint256 liabilityToBurn;
        (amount, liabilityToBurn, , ) = _withdrawFrom(asset, liquidity);

        require(minimumAmount <= amount, 'AMOUNT_TOO_LOW');

        asset.burn(address(asset), liquidity);
        asset.removeCash(amount);
        asset.removeLiability(liabilityToBurn);
        asset.transferUnderlyingToken(to, amount);
    }

    /**
     * @notice Withdraws liquidity amount of asset to `to` address ensuring minimum amount required
     * @param token The token to be withdrawn
     * @param liquidity The liquidity to be withdrawn
     * @param minimumAmount The minimum amount that will be accepted by user
     * @param to The user receiving the withdrawal
     * @param deadline The deadline to be respected
     * @return amount The total amount withdrawn
     */
    function withdraw(
        address token,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant whenNotPaused returns (uint256 amount) {
        require(liquidity > 0, 'ZERO_ASSET_AMOUNT');
        require(token != address(0), 'ZERO');
        require(to != address(0), 'ZERO');

        Asset asset = _assetOf(token);

        amount = _withdraw(asset, liquidity, minimumAmount, to);

        emit Withdraw(msg.sender, token, amount, liquidity, to);
    }

    /**
     * @notice Enables withdrawing liquidity from an asset using LP from a different asset in the same aggregate
     * @param initialToken The corresponding token user holds the LP (Asset) from
     * @param wantedToken The token wanting to be withdrawn (needs to be well covered)
     * @param liquidity The liquidity to be withdrawn (in wanted token d.p.)
     * @param minimumAmount The minimum amount that will be accepted by user
     * @param to The user receiving the withdrawal
     * @param deadline The deadline to be respected
     * @dev initialToken and wantedToken assets' must be in the same aggregate
     * @dev Also, cov of wantedAsset must be higher than 1 after withdrawal for this to be accepted
     * @return amount The total amount withdrawn
     */
    function withdrawFromOtherAsset(
        address initialToken,
        address wantedToken,
        uint256 liquidity,
        uint256 minimumAmount,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant whenNotPaused returns (uint256 amount) {
        require(liquidity > 0, 'ZERO_ASSET_AMOUNT');
        require(wantedToken != address(0), 'ZERO');
        require(initialToken != address(0), 'ZERO');
        require(to != address(0), 'ZERO');

        // get corresponding assets
        Asset initialAsset = _assetOf(initialToken);
        Asset wantedAsset = _assetOf(wantedToken);

        // assets need to be in the same aggregate in order to allow for withdrawing other assets
        require(wantedAsset.aggregateAccount() == initialAsset.aggregateAccount(), 'DIFF_AGG_ACC');

        // check if price deviation is OK between assets
        _checkPriceDeviation(initialToken, wantedToken);

        // Convert liquidity to d.p of initial asset
        uint256 liquidityInInitialAssetDP = (liquidity * 10**initialAsset.decimals()) / (10**wantedAsset.decimals());

        // require liquidity in initial asset dp to be > 0
        require(liquidityInInitialAssetDP > 0, 'DUST?');

        // request lp token from user
        IERC20Upgradeable(initialAsset).safeTransferFrom(
            address(msg.sender),
            address(initialAsset),
            liquidityInInitialAssetDP
        );

        // calculate liabilityToBurn and amount
        bool enoughCash;
        (amount, , , enoughCash) = _withdrawFrom(wantedAsset, liquidity);

        // If not enough cash in wanted asset, revert
        require(enoughCash, 'NOT_ENOUGH_CASH');

        // require after withdrawal coverage to >= 1
        require((wantedAsset.cash() - amount).wdiv(wantedAsset.liability()) >= ETH_UNIT, 'COV_RATIO_LOW');

        // require amount to be higher than the amount specified
        require(minimumAmount <= amount, 'AMOUNT_TOO_LOW');

        // calculate liability to burn in initialAsset
        uint256 liabilityToBurn = (initialAsset.liability() * liquidityInInitialAssetDP) / initialAsset.totalSupply();

        // burn initial asset recovered liquidity
        initialAsset.burn(address(initialAsset), liquidityInInitialAssetDP);
        initialAsset.removeLiability(liabilityToBurn); // remove liability from initial asset
        wantedAsset.removeCash(amount); // remove cash from wanted asset
        wantedAsset.transferUnderlyingToken(to, amount); // transfer wanted token to user

        emit Withdraw(msg.sender, wantedToken, amount, liquidityInInitialAssetDP, to);
    }

    /**
     * @notice Swap fromToken for toToken, ensures deadline and minimumToAmount and sends quoted amount to `to` address
     * @param fromToken The token being inserted into Pool by user for swap
     * @param toToken The token wanted by user, leaving the Pool
     * @param fromAmount The amount of from token inserted
     * @param minimumToAmount The minimum amount that will be accepted by user as result
     * @param to The user receiving the result of swap
     * @param deadline The deadline to be respected
     * @return actualToAmount The actual amount user receive
     * @return haircut The haircut that would be applied
     */
    function swap(
        address fromToken,
        address toToken,
        uint256 fromAmount,
        uint256 minimumToAmount,
        address to,
        uint256 deadline
    ) external ensure(deadline) nonReentrant whenNotPaused returns (uint256 actualToAmount, uint256 haircut) {
        require(fromToken != address(0), 'ZERO');
        require(toToken != address(0), 'ZERO');
        require(fromToken != toToken, 'SAME_ADDRESS');
        require(fromAmount > 0, 'ZERO_FROM_AMOUNT');
        require(to != address(0), 'ZERO');

        IERC20 fromERC20 = IERC20(fromToken);
        Asset fromAsset = _assetOf(fromToken);
        Asset toAsset = _assetOf(toToken);

        // Intrapool swapping only
        require(toAsset.aggregateAccount() == fromAsset.aggregateAccount(), 'DIFF_AGG_ACC');
        (actualToAmount, haircut) = _quoteFrom(fromAsset, toAsset, fromAmount);
        require(minimumToAmount <= actualToAmount, 'AMOUNT_TOO_LOW');

        fromERC20.safeTransferFrom(address(msg.sender), address(fromAsset), fromAmount);
        fromAsset.addCash(fromAmount);
        toAsset.removeCash(actualToAmount);
        toAsset.addLiability(_dividend(haircut, _retentionRatio));
        toAsset.transferUnderlyingToken(to, actualToAmount);

        emit Swap(msg.sender, fromToken, toToken, fromAmount, actualToAmount, to);
    }

    /**
     * @notice Quotes the actual amount user would receive in a swap, taking in account slippage and haircut
     * @param fromAsset The initial asset
     * @param toAsset The asset wanted by user
     * @param fromAmount The amount to quote
     * @return actualToAmount The actual amount user would receive
     * @return haircut The haircut that will be applied
     */
    function _quoteFrom(
        Asset fromAsset,
        Asset toAsset,
        uint256 fromAmount
    ) private view returns (uint256 actualToAmount, uint256 haircut) {
        uint256 idealToAmount = _quoteIdealToAmount(fromAsset, toAsset, fromAmount);
        require(toAsset.cash() >= idealToAmount, 'INSUFFICIENT_CASH');
        
        uint256 slippageFrom = _slippage(
            _slippageParamK,
            _slippageParamN,
            _c1,
            _xThreshold,
            fromAsset.cash(),
            fromAsset.liability(),
            fromAmount,
            true
        );
        uint256 slippageTo = _slippage(
            _slippageParamK,
            _slippageParamN,
            _c1,
            _xThreshold,
            toAsset.cash(),
            toAsset.liability(),
            idealToAmount,
            false
        );
        uint256 swappingSlippage = _swappingSlippage(slippageFrom, slippageTo);
        uint256 toAmount = idealToAmount.wmul(swappingSlippage);
        haircut = _haircut(toAmount, _haircutRate);
        actualToAmount = toAmount - haircut;
    }

    /**
     * @notice Quotes the ideal amount in case of swap
     * @dev Does not take into account slippage parameters nor haircut
     * @param fromAsset The initial asset
     * @param toAsset The asset wanted by user
     * @param fromAmount The amount to quote
     * @return idealToAmount The ideal amount user would receive
     */
    function _quoteIdealToAmount(
        Asset fromAsset,
        Asset toAsset,
        uint256 fromAmount
    ) private view returns (uint256 idealToAmount) {
        // check deviation is not higher than specified amount
        _checkPriceDeviation(fromAsset.underlyingToken(), toAsset.underlyingToken());

        // assume perfect peg between assets
        idealToAmount = ((fromAmount * 10**toAsset.decimals()) / 10**fromAsset.decimals());
    }

    /**
     * @notice Quotes potential outcome of a swap given current state, taking in account slippage and haircut
     * @dev To be used by frontend
     * @param fromToken The initial ERC20 token
     * @param toToken The token wanted by user
     * @param fromAmount The amount to quote
     * @return potentialOutcome The potential amount user would receive
     * @return haircut The haircut that would be applied
     */
    function quotePotentialSwap(
        address fromToken,
        address toToken,
        uint256 fromAmount
    ) external view whenNotPaused returns (uint256 potentialOutcome, uint256 haircut) {
        require(fromToken != address(0), 'ZERO');
        require(toToken != address(0), 'ZERO');
        require(fromToken != toToken, 'SAME_ADDRESS');
        require(fromAmount > 0, 'ZERO_FROM_AMOUNT');

        Asset fromAsset = _assetOf(fromToken);
        Asset toAsset = _assetOf(toToken);

        // Intrapool swapping only
        require(toAsset.aggregateAccount() == fromAsset.aggregateAccount(), 'DIFF_AGG_ACC');

        (potentialOutcome, haircut) = _quoteFrom(fromAsset, toAsset, fromAmount);
    }

    /**
     * @notice Quotes potential withdrawal from pool
     * @dev To be used by frontend
     * @param token The token to be withdrawn by user
     * @param liquidity The liquidity (amount of lp assets) to be withdrawn
     * @return amount The potential amount user would receive
     * @return fee The fee that would be applied
     * @return enoughCash does the pool have enough cash? (cash >= liabilityToBurn - fee)
     */
    function quotePotentialWithdraw(address token, uint256 liquidity)
        external
        view
        whenNotPaused
        returns (
            uint256 amount,
            uint256 fee,
            bool enoughCash
        )
    {
        require(token != address(0), 'ZERO');
        require(liquidity > 0, 'LIQ=0');

        Asset asset = _assetOf(token);
        (amount, , fee, enoughCash) = _withdrawFrom(asset, liquidity);
    }

    /**
     * @notice Quotes potential withdrawal from other asset in the same aggregate
     * @dev To be used by frontend. Reverts if not possible
     * @param initialToken The users holds LP corresponding to this initial token
     * @param wantedToken The token to be withdrawn by user
     * @param liquidity The liquidity (amount of lp assets) to be withdrawn (in wanted token dp).
     * @return amount The potential amount user would receive
     * @return fee The fee that would be applied
     */
    function quotePotentialWithdrawFromOtherAsset(
        address initialToken,
        address wantedToken,
        uint256 liquidity
    ) external view whenNotPaused returns (uint256 amount, uint256 fee) {
        require(initialToken != address(0), 'ZERO');
        require(wantedToken != address(0), 'ZERO');
        require(liquidity > 0, 'LIQ=0');

        Asset initialAsset = _assetOf(initialToken);
        Asset wantedAsset = _assetOf(wantedToken);

        require(wantedAsset.aggregateAccount() == initialAsset.aggregateAccount(), 'DIFF_AGG_ACC');

        bool enoughCash;
        (amount, , fee, enoughCash) = _withdrawFrom(wantedAsset, liquidity);

        require(enoughCash, 'NOT_ENOUGH_CASH');

        // require after withdrawal coverage to >= 1
        require((wantedAsset.cash() - amount).wdiv(wantedAsset.liability()) >= ETH_UNIT, 'COV_RATIO_LOW');
    }

    /// @notice Gets max withdrawable amount in initial token
    /// @notice Taking into account that coverage must be over > 1 in wantedAsset
    /// @param initialToken the initial token to be evaluated
    /// @param wantedToken the wanted token to withdraw in
    /// @return maxInitialAssetAmount the maximum amount of initial asset that can be used to withdraw
    function quoteMaxInitialAssetWithdrawable(address initialToken, address wantedToken)
        external
        view
        whenNotPaused
        returns (uint256 maxInitialAssetAmount)
    {
        _checkPriceDeviation(initialToken, wantedToken);

        Asset initialAsset = _assetOf(initialToken);
        Asset wantedAsset = _assetOf(wantedToken);

        uint256 wantedAssetCov = (wantedAsset.cash()).wdiv(wantedAsset.liability());

        if (wantedAssetCov > ETH_UNIT) {
            maxInitialAssetAmount =
                ((wantedAssetCov - ETH_UNIT).wmul(wantedAsset.totalSupply()) * 10**initialAsset.decimals()) /
                10**wantedAsset.decimals();
        } else {
            maxInitialAssetAmount = 0;
        }
    }

    /**
     * @notice Gets addresses of underlying token in pool
     * @dev To be used externally
     * @return addresses of assets in the pool
     */
    function getTokenAddresses() external view returns (address[] memory) {
        return _assets.keys;
    }
}