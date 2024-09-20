// SPDX-License-Identifier: GPL-3.0

/**
Geggtoken.sol
*/

pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { LibCommon } from "./lib/LibCommon.sol";
import { ReflectiveV3ERC20 } from "./ReflectiveV3ERC20.sol";

/// @title A Defi Token implementation with extended functionalities
/// @notice Implements ERC20 standards with additional features like tax and deflation
contract Geggtoken is ReflectiveV3ERC20, Ownable {
  // Constants
  uint256 private constant MAX_BPS_AMOUNT = 10_000;
  uint256 private constant MAX_ALLOWED_BPS = 2_000;
  uint256 public constant MAX_EXCLUSION_LIMIT = 100;
  string public constant VERSION = "defi_v_1_fixed_supply";
  string public constant CONTRACT_NAME = "Geggtoken";
  bytes32 public constant CONTRACT_HASH = 0x367fbb50ab88562f9f9ace2ee6a0b36b67cced3d60f050af26b6778db6866803;

  // State Variables
  string public initialDocumentUri;
  string public documentUri;
  uint256 public immutable initialSupply;
  uint256 public immutable initialMaxTokenAmountPerAddress;
  uint256 public maxTokenAmountPerAddress;

  mapping(address => bool) public isFeesAndLimitsExcluded;
  address[] public feesAndLimitsExcluded;

  /// @notice Configuration properties for the ERC20 token
  struct ERC20ConfigProps {
    bool _isBurnable;
    bool _isDocumentAllowed;
    bool _isMaxAmountOfTokensSet;
    bool _isTaxable;
    bool _isDeflationary;
    bool _isReflective;
  }
  ERC20ConfigProps private configProps;

  address public immutable initialTokenOwner;
  uint8 private immutable _decimals;
  address public taxAddress;
  uint256 public taxBPS;
  uint256 public deflationBPS;

  // Events
  event DocumentUriSet(string newDocUri);
  event MaxTokenAmountPerSet(uint256 newMaxTokenAmount);
  event TaxConfigSet(address indexed _taxAddress, uint256 indexed _taxBPS);
  event DeflationConfigSet(uint256 indexed _deflationBPS);
  event ReflectionConfigSet(uint256 indexed _feeBPS);
  event ExcludeFromFeesAndLimits(address indexed account);
  event IncludedInFeesAndLimits(address indexed account);

  // Custom Errors
  error InvalidMaxTokenAmount(uint256 maxTokenAmount);
  error InvalidDecimals(uint8 decimals);
  error MaxTokenAmountPerAddrLtPrevious();
  error DestBalanceExceedsMaxAllowed(address addr);
  error DocumentUriNotAllowed();
  error MaxTokenAmountNotAllowed();
  error TokenIsNotTaxable();
  error TokenIsNotDeflationary();
  error InvalidTotalBPS(uint256 bps);
  error InvalidReflectiveConfig();
  error AlreadyExcludedFromFeesAndLimits();
  error AlreadyIncludedInFeesAndLimits();
  error ReachedMaxExclusionLimit();

  /// @notice Constructor to initialize the DeFi token
  /// @param name_ Name of the token
  /// @param symbol_ Symbol of the token
  /// @param initialSupplyToSet Initial supply of tokens
  /// @param decimalsToSet Number of decimals for the token
  /// @param tokenOwner Address of the initial token owner
  /// @param customConfigProps Configuration properties for the token
  /// @param newDocumentUri URI for the document associated with the token
  /// @param _taxAddress Address where tax will be sent
  /// @param bpsParams array of BPS values in this order:
  ///           taxBPS = bpsParams[0],
  ///           deflationBPS = bpsParams[1],
  ///           rewardFeeBPS = bpsParams[2],
  /// @param amountParams array of amounts for amount specific config:
  ///           maxTokenAmount = amountParams[0], Maximum token amount per address

  constructor(
    string memory name_,
    string memory symbol_,
    uint256 initialSupplyToSet,
    uint8 decimalsToSet,
    address tokenOwner,
    ERC20ConfigProps memory customConfigProps,
    string memory newDocumentUri,
    address _taxAddress,
    uint256[3] memory bpsParams,
    uint256[1] memory amountParams
  )
    ReflectiveV3ERC20(
      name_,
      symbol_,
      tokenOwner,
      initialSupplyToSet,
      decimalsToSet,
      initialSupplyToSet != 0 ? bpsParams[2] : 0,
      customConfigProps._isReflective
    )
  {
    // reflection feature can't be used in combination with burning/deflation
    // or reflection config is invalid if no reflection BPS amount is provided
    if (
      (customConfigProps._isReflective &&
        (customConfigProps._isBurnable ||
          customConfigProps._isDeflationary)) ||
      (!customConfigProps._isReflective && bpsParams[2] != 0)
    ) {
      revert InvalidReflectiveConfig();
    }

    if (customConfigProps._isMaxAmountOfTokensSet) {
      if (amountParams[0] == 0) {
        revert InvalidMaxTokenAmount(amountParams[0]);
      }
    }
    if (decimalsToSet > 18) {
      revert InvalidDecimals(decimalsToSet);
    }

    bpsInitChecks(customConfigProps, bpsParams, _taxAddress);

    LibCommon.validateAddress(tokenOwner);

    taxAddress = _taxAddress;

    taxBPS = bpsParams[0];
    deflationBPS = bpsParams[1];
    initialSupply = initialSupplyToSet;
    initialMaxTokenAmountPerAddress = amountParams[0];
    initialDocumentUri = newDocumentUri;
    initialTokenOwner = tokenOwner;
    _decimals = decimalsToSet;
    configProps = customConfigProps;
    documentUri = newDocumentUri;
    maxTokenAmountPerAddress = amountParams[0];

    if (tokenOwner != msg.sender) {
      transferOwnership(tokenOwner);
    }
  }

  function bpsInitChecks(
    ERC20ConfigProps memory customConfigProps,
    uint256[3] memory bpsParams,
    address _taxAddress
  ) private pure {
    uint256 totalBPS = 0;
    if (customConfigProps._isTaxable) {
      LibCommon.validateAddress(_taxAddress);

      totalBPS += bpsParams[0];
    }
    if (customConfigProps._isDeflationary) {
      totalBPS += bpsParams[1];
    }
    if (customConfigProps._isReflective) {
      totalBPS += bpsParams[2];
    }
    if (totalBPS > MAX_ALLOWED_BPS) {
      revert InvalidTotalBPS(totalBPS);
    }
  }

  // Public and External Functions

  function getFeesAndLimitsExclusionList() external view returns (address[] memory) {
    return feesAndLimitsExcluded;
  }

  /// @notice Checks if the token is burnable
  /// @return True if the token can be burned
  function isBurnable() public view returns (bool) {
    return configProps._isBurnable;
  }

  function getRewardsExclusionList() public view returns (address[] memory) {
    return rewardsExcluded;
  }

  /// @notice Checks if the maximum amount of tokens per address is set
  /// @return True if there is a maximum limit for token amount per address
  function isMaxAmountOfTokensSet() public view returns (bool) {
    return configProps._isMaxAmountOfTokensSet;
  }

  /// @notice Checks if setting a document URI is allowed
  /// @return True if setting a document URI is allowed
  function isDocumentUriAllowed() public view returns (bool) {
    return configProps._isDocumentAllowed;
  }

  /// @notice Returns the number of decimals used for the token
  /// @return The number of decimals
  function decimals() public view virtual override returns (uint8) {
    return _decimals;
  }

  /// @notice Checks if the token is taxable
  /// @return True if the token has tax applied on transfers
  function isTaxable() public view returns (bool) {
    return configProps._isTaxable;
  }

  /// @notice Checks if the token is deflationary
  /// @return True if the token has deflation applied on transfers
  function isDeflationary() public view returns (bool) {
    return configProps._isDeflationary;
  }

  /// @notice Checks if the token is reflective
  /// @return True if the token has reflection (ie. holder rewards) applied on transfers
  function isReflective() public view returns (bool) {
    return configProps._isReflective;
  }

  /// @notice Sets a new document URI
  /// @dev Can only be called by the contract owner
  /// @param newDocumentUri The new URI to be set
  function setDocumentUri(string memory newDocumentUri) external onlyOwner {
    if (!isDocumentUriAllowed()) {
      revert DocumentUriNotAllowed();
    }
    documentUri = newDocumentUri;
    emit DocumentUriSet(newDocumentUri);
  }

  /// @notice Sets a new maximum token amount per address
  /// @dev Can only be called by the contract owner
  /// @param newMaxTokenAmount The new maximum token amount per address
  function setMaxTokenAmountPerAddress(
    uint256 newMaxTokenAmount
  ) external onlyOwner {
    if (!isMaxAmountOfTokensSet()) {
      revert MaxTokenAmountNotAllowed();
    }
    if (newMaxTokenAmount <= maxTokenAmountPerAddress) {
      revert MaxTokenAmountPerAddrLtPrevious();
    }

    maxTokenAmountPerAddress = newMaxTokenAmount;
    emit MaxTokenAmountPerSet(newMaxTokenAmount);
  }

  /// @notice Sets a new reflection fee
  /// @dev Can only be called by the contract owner
  /// @param _feeBPS The reflection fee in basis points
  function setReflectionConfig(uint256 _feeBPS) external onlyOwner {
    if (!isReflective()) {
      revert TokenIsNotReflective();
    }
    super._setReflectionFee(_feeBPS);

    emit ReflectionConfigSet(_feeBPS);
  }

  /// @notice Sets a new tax configuration
  /// @dev Can only be called by the contract owner
  /// @param _taxAddress The address where tax will be sent
  /// @param _taxBPS The tax rate in basis points
  function setTaxConfig(
    address _taxAddress,
    uint256 _taxBPS
  ) external onlyOwner {
    if (!isTaxable()) {
      revert TokenIsNotTaxable();
    }

    uint256 totalBPS = deflationBPS + tFeeBPS + _taxBPS;
    if (totalBPS > MAX_ALLOWED_BPS) {
      revert InvalidTotalBPS(totalBPS);
    }
    LibCommon.validateAddress(_taxAddress);
    taxAddress = _taxAddress;
    taxBPS = _taxBPS;
    emit TaxConfigSet(_taxAddress, _taxBPS);
  }

  /// @notice Sets a new deflation configuration
  /// @dev Can only be called by the contract owner
  /// @param _deflationBPS The deflation rate in basis points
  function setDeflationConfig(uint256 _deflationBPS) external onlyOwner {
    if (!isDeflationary()) {
      revert TokenIsNotDeflationary();
    }
    uint256 totalBPS = deflationBPS + tFeeBPS + _deflationBPS;
    if (totalBPS > MAX_ALLOWED_BPS) {
      revert InvalidTotalBPS(totalBPS);
    }
    deflationBPS = _deflationBPS;
    emit DeflationConfigSet(_deflationBPS);
  }

  /// @notice Transfers tokens to a specified address
  /// @dev Overrides the ERC20 transfer function with added tax and deflation logic
  /// @param to The address to transfer tokens to
  /// @param amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function transfer(
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    uint256 taxAmount = _taxAmount(msg.sender, to, amount);
    uint256 deflationAmount = _deflationAmount(msg.sender, to, amount);
    uint256 amountToTransfer = amount - taxAmount - deflationAmount;

    if (isMaxAmountOfTokensSet() && !isFeesAndLimitsExcluded[to]) {
      if (balanceOf(to) + amountToTransfer > maxTokenAmountPerAddress) {
        revert DestBalanceExceedsMaxAllowed(to);
      }
    }

    if (taxAmount != 0) {
      _transferNonReflectedTax(msg.sender, taxAddress, taxAmount);
    }
    if (deflationAmount != 0) {
      _burn(msg.sender, deflationAmount);
    }
    return super.transfer(to, amountToTransfer);
  }

  /// @notice Transfers tokens from one address to another
  /// @dev Overrides the ERC20 transferFrom function with added tax and deflation logic
  /// @param from The address which you want to send tokens from
  /// @param to The address which you want to transfer to
  /// @param amount The amount of tokens to be transferred
  /// @return True if the transfer was successful
  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    uint256 taxAmount = _taxAmount(from, to, amount);
    uint256 deflationAmount = _deflationAmount(from, to, amount);
    uint256 amountToTransfer = amount - taxAmount - deflationAmount;

    if (isMaxAmountOfTokensSet() && !isFeesAndLimitsExcluded[to]) {
      if (balanceOf(to) + amountToTransfer > maxTokenAmountPerAddress) {
        revert DestBalanceExceedsMaxAllowed(to);
      }
    }

    if (taxAmount != 0) {
      _transferNonReflectedTax(from, taxAddress, taxAmount);
    }
    if (deflationAmount != 0) {
      _burn(from, deflationAmount);
    }

    return super.transferFrom(from, to, amountToTransfer);
  }

  /// @notice Burns a specific amount of tokens
  /// @dev Can only be called by the contract owner and if burning is enabled
  /// @param amount The amount of tokens to be burned
  function burn(uint256 amount) external onlyOwner {
    if (!isBurnable()) {
      revert BurningNotEnabled();
    }
    _burn(msg.sender, amount);
  }

  /// @notice Renounces ownership of the contract
  /// @dev Leaves the contract without an owner, disabling any functions that require the owner's authorization
  function renounceOwnership() public override onlyOwner {
    super.renounceOwnership();
  }

  /// @notice Transfers ownership of the contract to a new account
  /// @dev Can only be called by the current owner
  /// @param newOwner The address of the new owner
  function transferOwnership(address newOwner) public override onlyOwner {
    super.transferOwnership(newOwner);
  }

  /// @notice method for adding a new account to the exclusion list
  /// @param account account to add to the exclusion list
  /// @dev only callable by owner
  function excludeFromFeesAndLimits(
    address account
  ) external onlyOwner {
    if (isFeesAndLimitsExcluded[account]) {
      revert AlreadyExcludedFromFeesAndLimits();
    }
    if (feesAndLimitsExcluded.length >= MAX_EXCLUSION_LIMIT) {
      revert ReachedMaxExclusionLimit();
    }

    isFeesAndLimitsExcluded[account] = true;
    feesAndLimitsExcluded.push(account);

    emit ExcludeFromFeesAndLimits(account);
  }

  /// @notice method for adding a new account to the reflection exclusion list
  /// @param account account to add to the exclusion list
  /// @dev only callable by owner
  function excludeFromRewards(address account) external onlyOwner {
    super._excludeFromRewards(account);
  }

  /// @notice method for removing an account from the fees exclusion list
  /// @param account account to remove from the exclusion list
  /// @dev only callable by owner
  function includeInFeesAndLimits(address account) external onlyOwner() {
    if (!isFeesAndLimitsExcluded[account]) {
      revert AlreadyIncludedInFeesAndLimits();
    }

    for (uint256 i = 0; i < feesAndLimitsExcluded.length; i++) {
      if (feesAndLimitsExcluded[i] == account) {
        feesAndLimitsExcluded[i] = feesAndLimitsExcluded[feesAndLimitsExcluded.length - 1];
        isFeesAndLimitsExcluded[account] = false;
        feesAndLimitsExcluded.pop();
        emit IncludedInFeesAndLimits(account);

        break;
      }
    }
  }

  /// @notice method for removing an account from the reflection exclusion list
  /// @param account account to remove from the exclusion list
  /// @dev only callable by owner
  function includeInRewards(address account) external onlyOwner() {
    super._includeInRewards(account);
  }

  // Internal Functions

  /// @notice Calculates the tax amount for a transfer
  /// @param sender The address initiating the transfer
  /// @param recipient The address receiving the transfer
  /// @param amount The amount of tokens being transferred
  /// @return taxAmount The calculated tax amount
  function _taxAmount(
    address sender,
    address recipient,
    uint256 amount
  ) internal view returns (uint256 taxAmount) {
    taxAmount = 0;
    if (taxBPS != 0 && sender != taxAddress && !isFeesAndLimitsExcluded[sender] && !isFeesAndLimitsExcluded[recipient]) {
      taxAmount = (amount * taxBPS) / MAX_BPS_AMOUNT;
    }
  }

  /// @notice Calculates the deflation amount for a transfer
  /// @param sender The address initiating the transfer
  /// @param recipient The address receiving the transfer
  /// @param amount The amount of tokens being transferred
  /// @return deflationAmount The calculated deflation amount
  function _deflationAmount(
    address sender,
    address recipient,
    uint256 amount
  ) internal view returns (uint256 deflationAmount) {
    deflationAmount = 0;
    if (deflationBPS != 0 && !isFeesAndLimitsExcluded[sender] && !isFeesAndLimitsExcluded[recipient]) {
      deflationAmount = (amount * deflationBPS) / MAX_BPS_AMOUNT;
    }
  }
}