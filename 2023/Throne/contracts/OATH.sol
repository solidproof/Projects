// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "contracts/interfaces/IOATH.sol";

/*
 * OATH is Throne's native ERC20 token.
 * It has an hard cap and manages its own emissions and allocations.
 */
contract OATH is Ownable, ERC20("Throne", "OATH"), IOATH {
    using SafeMath for uint256;

    uint256 public constant MAX_EMISSION_RATE = 1 ether;
    uint256 public constant MAX_SUPPLY_LIMIT = 20_000_000 ether;
    uint256 public elasticMaxSupply; // Once deployed, controlled through governance only
    uint256 public emissionRate; // Token emission per second

    uint256 public override lastEmissionTime;
    uint256 public masterV2Reserve; // Pending rewards for the master V2
    uint256 public masterV3Reserve; // Pending rewards for the master V3

    uint256 public constant ALLOCATION_PRECISION = 100;
    // Allocations emitted over time. When < 100%, the rest is minted into the treasury (default 15%)
    uint256 public masterV2Allocation = 0; // = 48%
    uint256 public masterV3Allocation = 96;

    address public masterV2Address;
    address public masterV3Address;
    address public treasuryAddress;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    mapping(address => bool) public isExcludedFromMaxWallet;
    uint256 public maxWallet;
    bool public isMaxWalletEnabled = true;
    uint256 public constant MAX_WALLET_PRECISION = 10000;

    constructor(
        uint256 maxSupply_,
        uint256 initialSupply,
        uint256 initialEmissionRate,
        uint256 maxWallet_,
        address treasuryAddress_
    ) {
        require(initialEmissionRate <= MAX_EMISSION_RATE, "OATH: invalid emission rate");
        require(maxSupply_ <= MAX_SUPPLY_LIMIT, "OATH: invalid initial maxSupply");
        require(maxWallet_ <= MAX_WALLET_PRECISION, "OATH: invalid maxWallet");
        require(initialSupply < maxSupply_, "OATH: invalid initial supply");
        require(treasuryAddress_ != address(0), "OATH: invalid treasury address");

        elasticMaxSupply = maxSupply_;
        emissionRate = initialEmissionRate;
        treasuryAddress = treasuryAddress_;

        maxWallet = maxWallet_;
        isExcludedFromMaxWallet[address(this)] = true;
        isExcludedFromMaxWallet[msg.sender] = true;
        isExcludedFromMaxWallet[treasuryAddress] = true;
        isExcludedFromMaxWallet[BURN_ADDRESS] = true;

        _mint(msg.sender, initialSupply);
    }

    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event ClaimMasterV2Rewards(uint256 amount);
    event ClaimMasterV3Rewards(uint256 amount);
    event AllocationsDistributed(uint256 masterV2Share, uint256 masterV3Share, uint256 treasuryShare);
    event InitializeMasterAddress(address masterV2Address, address masterV3Address);
    event InitializeEmissionStart(uint256 startTime);
    event UpdateAllocations(uint256 v2FarmingAllocation, uint256 v3FarmingAllocation, uint256 treasuryAllocation);
    event UpdateEmissionRate(uint256 previousEmissionRate, uint256 newEmissionRate);
    event UpdateMaxSupply(uint256 previousMaxSupply, uint256 newMaxSupply);
    event UpdateMaxWallet(uint256 previousMaxWallet, uint256 newMaxWallet);
    event UpdateTreasuryAddress(address previousTreasuryAddress, address newTreasuryAddress);
    event SetExcludeMaxWallet(address account, bool excluded);
    event MaxWalletDisabled();

    /***********************************************/
    /****************** MODIFIERS ******************/
    /***********************************************/

    /*
     * @dev Throws error if called by any account other than the master
     */
    modifier onlyMasterV2() {
        require(msg.sender == masterV2Address, "OATH: caller is not the master");
        _;
    }

    /*
     * @dev Throws error if called by any account other than the master
     */
    modifier onlyMasterV3() {
        require(msg.sender == masterV3Address, "OATH: caller is not the master");
        _;
    }

    /**************************************************/
    /****************** OVERRIDES *********************/
    /**************************************************/

    /**
     * @dev ensures max wallet
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        if (isMaxWalletEnabled && !isExcludedFromMaxWallet[recipient]) {
            uint256 maxWalletTokens = maxWallet.mul(totalSupply()).div(MAX_WALLET_PRECISION);
            require(balanceOf(recipient).add(amount) <= maxWalletTokens, "OATH: wallet balance limit exceeded");
        }
        super._transfer(sender, recipient, amount);
    }

    /**************************************************/
    /****************** PUBLIC VIEWS ******************/
    /**************************************************/

    /**
     * @dev Returns master v2 emission rate
     */
    function masterV2EmissionRate() public view override returns (uint256) {
        return emissionRate.mul(masterV2Allocation).div(ALLOCATION_PRECISION);
    }

    /**
     * @dev Returns master v3 emission rate
     */
    function masterV3EmissionRate() public view override returns (uint256) {
        return emissionRate.mul(masterV3Allocation).div(ALLOCATION_PRECISION);
    }

    /**
     * @dev Returns treasury allocation
     */
    function treasuryAllocation() public view returns (uint256) {
        return uint256(ALLOCATION_PRECISION).sub(masterV2Allocation).sub(masterV3Allocation);
    }

    /*****************************************************************/
    /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
    /*****************************************************************/

    /**
     * @dev Mint rewards and distribute it between master and treasury
     *
     * Treasury share is directly minted to the treasury address
     * Master incentives are minted into this contract and claimed later by the master contract
     */
    function emitAllocations() public {
        uint256 circulatingSupply = totalSupply();
        uint256 currentBlockTimestamp = _currentBlockTimestamp();

        uint256 _lastEmissionTime = lastEmissionTime; // gas saving
        uint256 _maxSupply = elasticMaxSupply; // gas saving

        // if already up to date or not started
        if (currentBlockTimestamp <= _lastEmissionTime || _lastEmissionTime == 0) {
            return;
        }

        // if max supply is already reached or emissions deactivated
        if (_maxSupply <= circulatingSupply || emissionRate == 0) {
            lastEmissionTime = currentBlockTimestamp;
            return;
        }

        uint256 newEmissions = currentBlockTimestamp.sub(_lastEmissionTime).mul(emissionRate);

        // cap new emissions if exceeding max supply
        if (_maxSupply < circulatingSupply.add(newEmissions)) {
            newEmissions = _maxSupply.sub(circulatingSupply);
        }

        // calculate master and treasury shares from new emissions
        uint256 masterV2Share = newEmissions.mul(masterV2Allocation).div(ALLOCATION_PRECISION);

        uint256 masterV3Share = newEmissions.mul(masterV3Allocation).div(ALLOCATION_PRECISION);

        // sub to avoid rounding errors
        uint256 treasuryShare = newEmissions.sub(masterV2Share).sub(masterV3Share);

        lastEmissionTime = currentBlockTimestamp;

        // add master shares to its claimable reserve
        masterV2Reserve = masterV2Reserve.add(masterV2Share);
        masterV3Reserve = masterV3Reserve.add(masterV3Share);
        // mint shares
        _mint(address(this), masterV2Share);
        _mint(address(this), masterV3Share);
        _mint(treasuryAddress, treasuryShare);

        emit AllocationsDistributed(masterV2Share, masterV3Share, treasuryShare);
    }

    /**
     * @dev Sends to Master contract the asked "amount" from masterReserve
     *
     * Can only be called by the MasterContract
     */
    function claimMasterV2Rewards(uint256 amount) external override onlyMasterV2 returns (uint256 effectiveAmount) {
        // update emissions
        emitAllocations();

        // cap asked amount with available reserve
        effectiveAmount = Math.min(masterV2Reserve, amount);

        // if no rewards to transfer
        if (effectiveAmount == 0) {
            return effectiveAmount;
        }

        // remove claimed rewards from reserve and transfer to master
        masterV2Reserve = masterV2Reserve.sub(effectiveAmount);
        _transfer(address(this), masterV2Address, effectiveAmount);
        emit ClaimMasterV2Rewards(effectiveAmount);
    }

    /**
     * @dev Sends to Master contract the asked "amount" from masterReserve
     *
     * Can only be called by the MasterContract
     */
    function claimMasterV3Rewards(uint256 amount) external override onlyMasterV3 returns (uint256 effectiveAmount) {
        // update emissions
        emitAllocations();

        // cap asked amount with available reserve
        effectiveAmount = Math.min(masterV3Reserve, amount);

        // if no rewards to transfer
        if (effectiveAmount == 0) {
            return effectiveAmount;
        }

        // remove claimed rewards from reserve and transfer to master
        masterV3Reserve = masterV3Reserve.sub(effectiveAmount);
        _transfer(address(this), masterV3Address, effectiveAmount);
        emit ClaimMasterV2Rewards(effectiveAmount);
    }

    /**
     * @dev Burns "amount" of OATH by sending it to BURN_ADDRESS
     */
    function burn(uint256 amount) external override {
        _transfer(msg.sender, BURN_ADDRESS, amount);
    }

    /*****************************************************************/
    /****************** EXTERNAL OWNABLE FUNCTIONS  ******************/
    /*****************************************************************/

    /**
     * @dev Setup Master v3 contract address
     *
     * Must only be called by the owner
     */
    function updateMasterV3Addresses(address masterV3Address_) external onlyOwner {
        require(masterV3Address_ != address(0), "OATH:initializeMasterAddresses: master initialized to zero addresses");

        isExcludedFromMaxWallet[masterV3Address_] = true;

        masterV3Address = masterV3Address_;
        emit InitializeMasterAddress(address(0), masterV3Address_);
    }

    /**
     * @dev Setup Master v2 contract address
     *
     * Must only be called by the owner
     */
    function updateMasterV2Addresses(address masterV2Address_) external onlyOwner {
        require(masterV2Address_ != address(0), "OATH:initializeMasterAddresses: master initialized to zero addresses");

        isExcludedFromMaxWallet[masterV2Address_] = true;

        masterV2Address = masterV2Address_;
        emit InitializeMasterAddress(masterV2Address_, address(0));
    }

    /**
     * @dev Set emission start time
     *
     * Can only be initialized once
     * Must only be called by the owner
     */
    function initializeEmissionStart(uint256 startTime) external onlyOwner {
        require(lastEmissionTime == 0, "OATH:initializeEmissionStart: emission start already initialized");
        require(_currentBlockTimestamp() < startTime, "OATH:initializeEmissionStart: invalid");

        lastEmissionTime = startTime;
        emit InitializeEmissionStart(startTime);
    }

    /**
     * @dev Updates emission allocations between farming incentives, legacy holders and treasury (remaining share)
     *
     * Must only be called by the owner
     */
    function updateAllocations(uint256 masterV2Allocation_, uint256 masterV3Allocation_) external onlyOwner {
        // apply emissions before changes
        emitAllocations();

        // total sum of allocations can't be > 100%
        uint256 totalAllocationsSet = masterV2Allocation_.add(masterV3Allocation_);
        require(totalAllocationsSet <= 100, "OATH:updateAllocations: total allocation is too high");

        // set new allocations
        masterV2Allocation = masterV2Allocation_;
        masterV3Allocation = masterV3Allocation_;

        emit UpdateAllocations(masterV2Allocation_, masterV3Allocation_, treasuryAllocation());
    }

    /**
     * @dev Updates OATH emission rate per second
     *
     * Must only be called by the owner
     */
    function updateEmissionRate(uint256 emissionRate_) external onlyOwner {
        require(emissionRate_ <= MAX_EMISSION_RATE, "OATH:updateEmissionRate: can't exceed maximum");

        // apply emissions before changes
        emitAllocations();

        emit UpdateEmissionRate(emissionRate, emissionRate_);
        emissionRate = emissionRate_;
    }

    /**
     * @dev Updates OATH max supply
     *
     * Must only be called by the owner
     */
    function updateMaxSupply(uint256 maxSupply_) external onlyOwner {
        require(maxSupply_ >= totalSupply(), "OATH:updateMaxSupply: can't be lower than current circulating supply");
        require(maxSupply_ <= MAX_SUPPLY_LIMIT, "OATH:updateMaxSupply: invalid maxSupply");

        emit UpdateMaxSupply(elasticMaxSupply, maxSupply_);
        elasticMaxSupply = maxSupply_;
    }

    /**
     * @dev Updates OATH max wallet
     *
     * Must only be called by the owner
     */
    function updateMaxWallet(uint256 maxWallet_) external onlyOwner {
        require(maxWallet_ >= maxWallet, "OATH:updateMaxWallet: can't be lower than current max wallet");
        require(maxWallet_ <= MAX_WALLET_PRECISION, "OATH:updateMaxWallet: invalid maxWallet");

        emit UpdateMaxWallet(maxWallet, maxWallet_);
        maxWallet = maxWallet_;
    }

    /**
     * @dev Updates treasury address
     *
     * Must only be called by owner
     */
    function updateTreasuryAddress(address treasuryAddress_) external onlyOwner {
        require(treasuryAddress_ != address(0), "OATH:updateTreasuryAddress: invalid address");

        emit UpdateTreasuryAddress(treasuryAddress, treasuryAddress_);
        treasuryAddress = treasuryAddress_;
    }

    /**
     * @dev disable max wallet
     *
     * Must only be called by owner
     */
    function disableMaxWallet() external onlyOwner {
        require(isMaxWalletEnabled, "OATH:disableMaxWallet: already disabled");

        emit MaxWalletDisabled();
        isMaxWalletEnabled = false;
    }

    /**
     * @dev excludes from max wallet
     *
     * Must only be called by owner
     */
    function setExcludeMaxWallet(address for_, bool exclude_) external onlyOwner {
        isExcludedFromMaxWallet[for_] = exclude_;
        emit SetExcludeMaxWallet(for_, exclude_);
    }

    /********************************************************/
    /****************** INTERNAL FUNCTIONS ******************/
    /********************************************************/

    /**
     * @dev Utility function to get the current block timestamp
     */
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        /* solhint-disable not-rely-on-time */
        return block.timestamp;
    }
}