// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "ERC20PresetMinterBurnableUpgradeable.sol";
import "Utils.sol";

/// @title ERC-20 token that pays for all actions within the project.
/// @dev there is a possibility of minting additional Coins
contract Coin is ERC20PresetMinterBurnableUpgradeable {
    using Utils for address;

    address public treasury;
    address public treasuryLP;
    uint256 constant public DENOMINATOR = 10000;
    uint256 constant public MAX_TAX_NUMERATOR = 500;  // 5%
    uint256 public purchaseDEXTaxNumerator;
    uint256 public saleDEXTaxNumerator;
    uint256 public purchaseDEXTaxForLPNumerator;
    uint256 public saleDEXTaxForLPNumerator;
    uint256 public transferTaxNumerator;
    mapping (address => bool) public isPool;
    mapping (address /*account*/ => bool) public isTaxWhitelisted;  // no transfer tax for outgoing transfers
    mapping (address /*account*/ => bool) public isTaxWhitelistedToReceive;  // no transfer tax for incoming transfers

    event TreasurySet(address indexed treasuryAddress);
    event TreasuryLPSet(address indexed treasuryLPAddress);
    event TransferTaxPaid(address indexed sender, address indexed treasury, uint256 taxAmount);
    event SaleDEXTaxPaid(address indexed pool, address indexed seller, address indexed treasury, uint256 taxAmount);
    event PurchaseDEXTaxPaid(address indexed pool, address indexed purchaser, address indexed treasury, uint256 taxAmount);
    event SaleDEXTaxForLPPaid(address indexed pool, address indexed seller, address indexed treasuryLP, uint256 taxAmount);
    event PurchaseDEXTaxForLPPaid(address indexed pool, address indexed purchaser, address indexed treasuryLP, uint256 taxAmount);
    event PoolAdded(address indexed addr);
    event PoolRemoved(address indexed addr);
    event TaxWhitelistAdded(address indexed addr);
    event TaxWhitelistRemoved(address indexed addr);
    event TaxWhitelistToReceiveAdded(address indexed addr);
    event TaxWhitelistToReceiveRemoved(address indexed addr);
    event TransferTaxNumeratorSet(uint256 indexed value);
    event PurchaseDEXTaxNumeratorSet(uint256 indexed value);
    event SaleDEXTaxNumeratorSet(uint256 indexed value);
    event PurchaseDEXTaxForLPNumeratorSet(uint256 indexed value);
    event SaleDEXTaxForLPNumeratorSet(uint256 indexed value);

    /// @notice Adds new DEX pool (only owner can call)
    /// @param pool pool address
    function addPool(address pool) external onlyOwner {
        isPool[pool] = true;
        emit PoolAdded(pool);
    }

    /// @notice Removes DEX pool (only owner can call)
    /// @param pool pool address
    function removePool(address pool) external onlyOwner {
        isPool[pool] = false;
        emit PoolRemoved(pool);
    }

    /// @notice Adds an address to whitelist to send (only owner can call)
    /// @param addr some address
    function addTaxWhitelist(address addr) external onlyOwner {
        isTaxWhitelisted[addr] = true;
        emit TaxWhitelistAdded(addr);
    }

    /// @notice Removes an address to whitelist to send (only owner can call)
    /// @param addr some address
    function removeTaxWhitelist(address addr) external onlyOwner {
        isTaxWhitelisted[addr] = false;
        emit TaxWhitelistRemoved(addr);
    }

    /// @notice Adds an address to whitelist to receive (only owner can call)
    /// @param addr some address
    function addTaxWhitelistToReceive(address addr) external onlyOwner {
        isTaxWhitelistedToReceive[addr] = true;
        emit TaxWhitelistToReceiveAdded(addr);
    }

    /// @notice Removes an address to whitelist to receive (only owner can call)
    /// @param addr some address
    function removeTaxWhitelistToReceive(address addr) external onlyOwner {
        isTaxWhitelistedToReceive[addr] = false;
        emit TaxWhitelistToReceiveRemoved(addr);
    }

    /// @notice Set new "treasury" setting value (only contract owner may call)
    /// @param treasuryAddress new setting value
    function setTreasury(address treasuryAddress) external onlyOwner {
        treasury = treasuryAddress.ensureNotZero();
        emit TreasurySet(treasuryAddress);
    }

    /// @notice Set new "treasuryLP" setting value (only contract owner may call)
    /// @param treasuryLPAddress new setting value
    function setTreasuryLP(address treasuryLPAddress) external onlyOwner {
        treasuryLP = treasuryLPAddress.ensureNotZero();
        emit TreasuryLPSet(treasuryLPAddress);
    }

    /// @notice Set new "transferTaxNumerator" setting value (only contract owner may call)
    /// @param value new setting value
    function setTransferTaxNumerator(uint256 value) external onlyOwner {
        require(value <= MAX_TAX_NUMERATOR, "TAX_IS_TOO_HIGH");
        transferTaxNumerator = value;
        emit TransferTaxNumeratorSet(value);
    }

    /// @notice Set new "purchaseDEXTaxNumerator" setting value (only contract owner may call)
    /// @param value new setting value
    function setPurchaseDEXTaxNumerator(uint256 value) external onlyOwner {
        require(value <= MAX_TAX_NUMERATOR, "TAX_IS_TOO_HIGH");
        purchaseDEXTaxNumerator = value;
        emit PurchaseDEXTaxNumeratorSet(value);
    }

    /// @notice Set new "saleDEXTaxNumerator" setting value (only contract owner may call)
    /// @param value new setting value
    function setSaleDEXTaxNumerator(uint256 value) external onlyOwner {
        require(value <= MAX_TAX_NUMERATOR, "TAX_IS_TOO_HIGH");
        saleDEXTaxNumerator = value;
        emit SaleDEXTaxNumeratorSet(value);
    }

    /// @notice Set new "purchaseDEXTaxForLPNumerator" setting value (only contract owner may call)
    /// @param value new setting value
    function setPurchaseDEXTaxForLPNumerator(uint256 value) external onlyOwner {
        require(value <= MAX_TAX_NUMERATOR, "TAX_IS_TOO_HIGH");
        purchaseDEXTaxForLPNumerator = value;
        emit PurchaseDEXTaxForLPNumeratorSet(value);
    }

    /// @notice Set new "saleDEXTaxForLPNumerator" setting value (only contract owner may call)
    /// @param value new setting value
    function setSaleDEXTaxForLPNumerator(uint256 value) external onlyOwner {
        require(value <= MAX_TAX_NUMERATOR, "TAX_IS_TOO_HIGH");
        saleDEXTaxForLPNumerator = value;
        emit SaleDEXTaxForLPNumeratorSet(value);
    }

    /// @notice initialize the contract
    /// @param nameValue name
    /// @param symbolValue symbol
    /// @param receiverValue receiver of the initial minting
    /// @param totalSupplyValue total supply of the token on the initial minting
    /// @param treasuryAddressValue treasury to receive fees
    /// @param treasuryLPAddressValue treasuryLP to receive LP fees
    /// @param ownerValue contract owner
    function initialize(
        string memory nameValue,
        string memory symbolValue,
        address receiverValue,
        uint256 totalSupplyValue,
        address treasuryAddressValue,
        address treasuryLPAddressValue,
        address ownerValue
    )
        external
        initializer
    {
        treasury = treasuryAddressValue.ensureNotZero();
        treasuryLP = treasuryLPAddressValue.ensureNotZero();
        __ERC20PresetMinterBurnable_init(nameValue, symbolValue, ownerValue);
        _mint(receiverValue, totalSupplyValue);
    }

    function _transfer(address from, address recipient, uint256 amount) internal virtual override {
        uint256 initialAmount = amount;
        if(isPool[recipient]) {
            if (isPool[from]) {  // isPool[from] && isPool[recipient]
                // swap through 2 pools e.g. path=[USDC, COIN, USDT]
                // no tax for cross pool liquidity moving
            } else {  // !isPool[from] && isPool[recipient]
                // sale
                if (!isTaxWhitelisted[from]) {
                    if (saleDEXTaxNumerator > 0){
                        uint256 tax = initialAmount * saleDEXTaxNumerator / DENOMINATOR;
                        super._transfer(from, treasury, tax);
                        amount -= tax;
                        emit SaleDEXTaxPaid({seller: from, pool: recipient, treasury: treasury, taxAmount: tax});
                    }
                    if(saleDEXTaxForLPNumerator > 0) {
                        uint256 tax = initialAmount * saleDEXTaxForLPNumerator / DENOMINATOR;
                        super._transfer(from, treasuryLP, tax);
                        amount -= tax;
                        emit SaleDEXTaxForLPPaid({seller: from, pool: recipient, treasuryLP: treasuryLP, taxAmount: tax});
                    }
                }
            }
        } else {  // !isPool[recipient]
            if (isPool[from]) {  // isPool[from] && !isPool[recipient]
                // purchase
                if ((!isTaxWhitelisted[recipient]) && (!isTaxWhitelistedToReceive[recipient])) {
                    if (purchaseDEXTaxNumerator > 0) {
                        uint256 tax = initialAmount * purchaseDEXTaxNumerator / DENOMINATOR;
                        super._transfer(from, treasury, tax);
                        amount -= tax;
                        emit PurchaseDEXTaxPaid({purchaser: recipient, pool: from, treasury: treasury, taxAmount: tax});
                    }
                    if (purchaseDEXTaxForLPNumerator > 0) {
                        uint256 tax = initialAmount * purchaseDEXTaxForLPNumerator / DENOMINATOR;
                        super._transfer(from, treasuryLP, tax);
                        amount -= tax;
                        emit PurchaseDEXTaxForLPPaid({purchaser: recipient, pool: from, treasuryLP: treasuryLP, taxAmount: tax});
                    }
                }
            } else {  // !isPool[from] && !isPool[recipient]
                // regular transfer (no dex)
                if (
                    (transferTaxNumerator > 0) &&
                    (!isTaxWhitelisted[from]) &&
                    (!isTaxWhitelistedToReceive[recipient])
                ) {
                    uint256 tax = initialAmount * transferTaxNumerator / DENOMINATOR;
                    super._transfer(from, treasury, tax);
                    amount -= tax;
                    emit TransferTaxPaid({sender: from, treasury: treasury, taxAmount: tax});
                }
            }
        }
        super._transfer(from, recipient, amount);
    }
}