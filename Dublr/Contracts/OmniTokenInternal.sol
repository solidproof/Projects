// SPDX-License-Identifier: MIT

// The OmniToken Ethereum token contract library, supporting multiple token standards.
// By Hiroshi Yamamoto.
// 虎穴に入らずんば虎子を得ず。
//
// Officially hosted at: https://github.com/dublr/dublr

pragma solidity ^0.8.15;

import "./interfaces/IERC165.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Optional.sol";
import "./interfaces/IERC20Burn.sol";
import "./interfaces/IERC20SafeApproval.sol";
import "./interfaces/IERC20IncreaseDecreaseAllowance.sol";
import "./interfaces/IERC20TimeLimitedTokenAllowances.sol";
import "./interfaces/IERC777.sol";
import "./interfaces/IERC1363.sol";
import "./interfaces/IERC4524.sol";
import "./interfaces/IEIP2612.sol";

/**
 * @title OmniTokenInternal
 * @dev Utility functions for the OmniToken Ethereum token contract library.
 * @author Hiroshi Yamamoto
 */
abstract contract OmniTokenInternal is 
                      IERC20, IERC20Optional, IERC20Burn,
                      IERC20SafeApproval, IERC20IncreaseDecreaseAllowance, IERC20TimeLimitedTokenAllowances,
                      IERC777, IERC1363, IERC4524, IEIP2612 {

    /** @dev Creator/owner of the contract. */
    address internal _owner;

    /** @notice EIP712 domain separator for EIP2612 permits. */
    bytes32 public override(IEIP2612) DOMAIN_SEPARATOR;

    /**
     * @dev Constructor.
     *
     * @param tokenName the name of the token.
     * @param tokenSymbol the ticker symbol for the token.
     * @param tokenVersion the version number string for the token.
     */
    constructor(string memory tokenName, string memory tokenSymbol, string memory tokenVersion) {
        // Remember creator of contract as owner
        _owner = msg.sender;

        name = tokenName;
        symbol = tokenSymbol;
        version = tokenVersion;

        // Initialize EIP712 domain separator for EIP2612 permit API
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                // The value of
                // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)));

        // There must be an ERC1820 registry deployed on the network
        require(isContract(ERC1820_REGISTRY_ADDRESS), "No ERC1820 registry");

        // Enable and register interfaces
        _owner_enableERC20(true);
        _owner_enableERC777(true);
        _owner_enableERC1363(true);
        _owner_enableERC4524(true);
        _owner_enableEIP2612(true);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Functions common to multiple interfaces

    /** @notice The number of tokens owned by a given address. */
    mapping(address => uint256) public override(IERC20, IERC777) balanceOf;

    /** @notice The total supply of tokens. */
    uint256 public override(IERC20, IERC777) totalSupply;

    /** @notice The name of the token. */
    string public override(IERC20Optional, IERC777) name;

    /** @notice The token symbol. */
    string public override(IERC20Optional, IERC777) symbol;

    /** @notice The token version. (Optional but supported in some token implementations.) */
    string public version;

    /**
     * @notice The number of decimal places used to display token balances.
     * (Hardcoded to the ETH-standard value of 18, as required by ERC777.)
     */
    uint8 public constant override(IERC20Optional) decimals = 18;

    /** @notice The ERC777 granularity. (Hardcoded to 1, for maximum compatibility with ERC20.) */
    uint256 public constant override(IERC777) granularity = 1;

    // -----------------------------------------------------------------------------------------------------------------
    // Function modifiers

    /** @dev The number of functions on the stack that call external contracts. */
    uint256 private _extCallerDepth;

    /** @dev The number of functions on the stack that deny calling of contracts modified with `extCaller`. */
    uint256 private _extCallerDeniedDepth;

    /**
     * @dev Reentrancy protection for functions that modify account state. Don't allow a state-modifying function
     * (stateUpdater) to be called deeper in the callstack than a function that calls an external contract
     ( (modified by `extCaller`).
     */
    modifier stateUpdater() {
        require(_extCallerDepth == 0, "Reentrance denied");
        _;
    }

    /** @dev Marks a function that calls an external contract. */
    modifier extCaller() {
        require(_extCallerDeniedDepth == 0, "extCaller denied");
        // slither-disable-next-line reentrancy-eth
        unchecked { ++_extCallerDepth; }
        _;
        // slither-disable-next-line reentrancy-eth
        unchecked { --_extCallerDepth; }
    }

    /**
     * @dev Marks a function that is disallowed from calling an external contract (because it is called
     * by another function before the other function has finished updating contract state).
     * Functions modified by `extCaller` and `extCallerDenied` cannot both be on the call stack at the
     * same time.
     */
    modifier extCallerDenied() {
        require(_extCallerDepth == 0, "extCaller denied");
        // slither-disable-next-line reentrancy-eth
        unchecked { ++_extCallerDeniedDepth; }
        _;
        // slither-disable-next-line reentrancy-eth
        unchecked { --_extCallerDeniedDepth; }
    }

    // --------------

    /** @dev Limit access to a function to the owner of the contract. */
    modifier ownerOnly() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // API enablement (needed in case a security issue is discovered with one of the APIs after the contract is created)

    /** @dev true if the ERC20 API is enabled. */
    bool internal _ERC20Enabled;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable or disable ERC20 support in the API.
     * If disabled, also disables other token APIs that are a superset of ERC20, since these depend
     * upon the ERC20 API. However disabling ERC20 does not disable the ERC777 API.
     */
    function _owner_enableERC20(bool enable) public ownerOnly {
        _ERC20Enabled = enable;

        // ERC20
        registerInterfaceViaERC165(type(IERC20).interfaceId, enable);
        registerInterfaceViaERC165(type(IERC20).interfaceId ^ type(IERC20Optional).interfaceId, enable);

        // ERC20 increase/decrease allowance extension
        registerInterfaceViaERC165(type(IERC20IncreaseDecreaseAllowance).interfaceId, enable);
        registerInterfaceViaERC165(type(IERC20).interfaceId ^ type(IERC20IncreaseDecreaseAllowance).interfaceId,
                enable);
                
        // ERC20 safe approval extension
        registerInterfaceViaERC165(type(IERC20SafeApproval).interfaceId, enable);
        registerInterfaceViaERC165(type(IERC20).interfaceId ^ type(IERC20SafeApproval).interfaceId, enable);

        // Don't register time-limited token allowance extension, because the OmniToken version uses seconds rather
        // than blocks for expiration, but the method type signature is the same

        registerInterfaceViaERC1820("ERC20Token", enable);
    }

    /** @dev Require ERC20 to be enabled. */
    modifier erc20() {
        require(_ERC20Enabled, "Disabled");
        _;
    }

    // --------------

    /** @dev true if the ERC777 API is enabled. */
    bool internal _ERC777Enabled;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable or disable ERC777 support in the API.
     */
    function _owner_enableERC777(bool enable) public ownerOnly {
        _ERC777Enabled = enable;
        
        registerInterfaceViaERC165(type(IERC777).interfaceId, enable);
        
        registerInterfaceViaERC1820("ERC777Token", enable);
    }

    /** The number of function calls in the stack for functions marked with the erc777 modifier. */
    uint256 internal _erc777CallDepth;

    /** @dev Require ERC777 to be enabled, and mark the ERC777 API as active. */
    modifier erc777() {
        require(_ERC777Enabled, "Disabled");
        unchecked { ++_erc777CallDepth; }
        _;
        unchecked { --_erc777CallDepth; }
    }

    /**
     * @dev Require ERC777 to be enabled, without marking the ERC777 API as active (needed for `view` functions,
     * of which there is one in the ERC777 API -- can't just remove `view` modifier since that function may be
     * called statically by a caller).
     */
    modifier erc777View() {
        require(_ERC777Enabled, "Disabled");
        _;
    }

    // --------------

    /** @dev true if the ERC1363 API is enabled. */
    bool internal _ERC1363Enabled;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable or disable ERC1363 support in the API.
     */
    function _owner_enableERC1363(bool enable) public ownerOnly {
        _ERC1363Enabled = enable;

        registerInterfaceViaERC165(type(IERC1363).interfaceId, enable);
        registerInterfaceViaERC165(type(IERC1363).interfaceId ^ type(IERC20).interfaceId ^ type(IERC165).interfaceId,
                enable);

        registerInterfaceViaERC1820("ERC1363Token", enable);
    }

    /** The number of function calls in the stack for functions marked with the erc1363 modifier. */
    uint256 internal _erc1363CallDepth;

    /** @dev Require ERC1363 to be enabled, and mark the ERC1363 API as active. */
    modifier erc1363() {
        require(_ERC1363Enabled, "Disabled");
        unchecked { ++_erc1363CallDepth; }
        _;
        unchecked { --_erc1363CallDepth; }
    }

    // --------------

    /** @dev true if the ERC4524 API is enabled. */
    bool internal _ERC4524Enabled;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable or disable ERC4524 support in the API (may only be called by the contract creator).
     */
    function _owner_enableERC4524(bool enable) public ownerOnly {
        _ERC4524Enabled = enable;
        
        registerInterfaceViaERC165(type(IERC4524).interfaceId, enable);
        registerInterfaceViaERC165(type(IERC4524).interfaceId ^ type(IERC20).interfaceId ^ type(IERC165).interfaceId,
                enable);
        
        registerInterfaceViaERC1820("ERC4524Token", enable);
    }

    /** The number of function calls in the stack for functions marked with the erc4524 modifier. */
    uint256 internal _erc4524CallDepth;

    /** @dev Require ERC4524 to be enabled, and mark the ERC4524 API as active. */
    modifier erc4524() {
        require(_ERC4524Enabled, "Disabled");
        unchecked { ++_erc4524CallDepth; }
        _;
        unchecked { --_erc4524CallDepth; }
    }

    // --------------

    /** @dev true if the EIP2612 permit API is enabled. */
    bool internal _EIP2612Enabled;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable or disable EIP2612 permit support in the API.
     */
    function _owner_enableEIP2612(bool enable) public ownerOnly {
        _EIP2612Enabled = enable;

        registerInterfaceViaERC165(type(IEIP2612).interfaceId, enable);
        registerInterfaceViaERC165(type(IEIP2612).interfaceId ^ type(IERC20).interfaceId, enable);

        // Not sure what to register EIP2612 support under
        registerInterfaceViaERC1820("ERC2612Token", enable);
        registerInterfaceViaERC1820("EIP2612Token", enable);
        registerInterfaceViaERC1820("ERC2612Permit", enable);
        registerInterfaceViaERC1820("EIP2612Permit", enable);
    }

    /** @dev Require EIP2612 permit support to be enabled. */
    modifier eip2612() {
        require(_EIP2612Enabled, "Disabled");
        _;
    }

    // --------------

    /** @dev true if unlimited allowance is enabled. (Disabled by default for security reasons.) */
    bool internal _unlimitedAllowancesEnabled = false;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable/disable unlimited allowances.
     * Note that enabling this can be dangerous, $120M was stolen in the BADGER frontend injection attack
     * due to unlimited allowances. Consequently, this is disabled by default.
     * 
     * See: https://kalis.me/unlimited-erc20-allowances/
     *      https://rekt.news/badger-rekt/
     */
    function _owner_enableUnlimitedAllowances(bool enable) external ownerOnly {
        _unlimitedAllowancesEnabled = enable;
    }

    // --------------

    /** @dev true if ERC20 transfer to smart contracts is enabled. (Disabled by default for security reasons.) */
    bool internal _transferToContractsEnabled = false;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     * @dev Enable/disable ERC20 transfer to smart contracts. Note that enabling this can be dangerous:
     * millions have been lost in the Ethereum ecosystem due to users accidentally transferring tokens
     * to a smart contract rather than an EOA wallet, since smart contracts generally aren't
     * set up to function as wallets, and contract code generally can't be changed to recover
     * lost tokens. Consequently, transfers to contracts are disabled by default. This is not ERC20
     * compatible, but it's much safer).
     * 
     * See: https://101blockchains.com/erc20-vs-erc223-vs-erc777/
     */
    function _owner_enableTransferToContracts(bool enable) external ownerOnly {
        _transferToContractsEnabled = enable;
    }

    // --------------

    /**
     * @dev true if ERC20 allows setting allowances from a non-zero value to another non-zero value.
     * (Disabled by default for security reasons.)
     */
    bool internal _changingAllowanceWithoutZeroingEnabled = false;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Enable/disable the ability of the ERC20 `approve` function to approve a non-zero allowance when the
     * allowance is already non-zero. This is disabled by default, to prevent the well-known allowance race
     * condition vulnerability in ERC20. This default is not ERC20-compatible, but it's much safer.
     *
     * See: https://github.com/guylando/KnowledgeLists/blob/master/EthereumSmartContracts.md
     *
     * @param enable Whether to enable changing allowances without first setting them to zero.
     */
    function _owner_enableChangingAllowanceWithoutZeroing(bool enable) external ownerOnly {
        _transferToContractsEnabled = enable;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Contract utility functions

    /**
     * @dev Test whether `account` is a contract.
     *
     * May return false negatives: during the execution of a contract's constructor, its address will be reported as not
     * containing a contract. Therefore, it is not safe to assume that an address for which this function returns `false`
     * is an externally-owned account (EOA) and not a contract.
     *
     * @param account The account.
     * @return Whether `account` is a contract (`true`) or is an externally-owned account (EOA) (`false`). Note that
     *         a return value of `true` is reliable, but a return value of `false` is not reliable.
     */
    function isContract(address account) internal view returns (bool) {
        // This relies on extcodesize, which returns 0 for contracts in construction, since the code is
        // only stored at the end of the constructor execution.
        return account != address(0) && account.code.length > 0;
    }

    /**
     * @dev Call a function in another contract, reverting with the other contract's revert message if the call fails.
     *
     * @param contractAddress The contract to call the function on.
     * @param valueETH The amount of ETH to send with the function call, or 0 for none.
     * @param abiEncoding The ABI encoding of the function call.
     * @param errorMessageOnFailure The error message to revert with. If the contract function reverts with
     *              its own message, it is appended to the end of `errorMessageOnFailure`. If empty, do not revert
     *              if the call does not succeed, but instead just return whether the call succeeded.
     * @return success `true` if the call was successful. `false` if `errorMessageOnFailure` was empty and the call
     *              failed.
     * @return returnData the return data from a successful call.
     */
    function callContractFunction(address contractAddress, uint256 valueETH, bytes memory abiEncoding,
            string memory errorMessageOnFailure) internal extCaller
            returns (bool success, bytes memory returnData) {
        
        // `.call` will succeed if contract doesn't exist:
        // https://docs.soliditylang.org/en/develop/control-structures.html
        // (URL continued => ) #error-handling-assert-require-revert-and-exceptions
        // Therefore require that contractAddress is a contract, unless the payload is empty
        // (an empty payload is used to send ETH to an address, so it doesn't have to be a contract)
        require(abiEncoding.length == 0 || isContract(contractAddress), "Addr is not a contract");
        
        (success, returnData) = contractAddress.call{value: valueETH}(abiEncoding);
        if (!success && bytes(errorMessageOnFailure).length > 0) {
            // Minimum size of return data for a non-empty revert message
            if (returnData.length > 4 + 32 + 32) {
                // If there is a non-empty revert message in the return data, revert with the same message.
                // The return data of a reverted call includes the following in ABI encoding format:
                // - bytes4: function selector with value: 0x08c379a0 == bytes4(keccak256("Error(string)"))
                // - uint256: offset of string parameter (should be 0x20)
                // - uint256: string length (should be 1 or more for non-empty revert message)
                // - string: value of revert message
                bytes4 selector;
                uint256 offset;
                string memory revertMsg;
                uint256 len;
                assembly {
                    selector := mload(add(returnData, 32))  // returnData.length is first 32 bytes
                    offset := mload(add(returnData, 36))
                    revertMsg := add(returnData, 68)        // revertMsg start addr, starting with revertMsg.length
                    len := mload(revertMsg)
                }
                if (selector == 0x08c379a0 && offset == 0x20 && len > 0) {
                    // Concatenate the error message prefix and the revert message, then revert
                    revert(string(abi.encodePacked(errorMessageOnFailure, ": ", revertMsg)));
                }
            }
            // Otherwise revert with just the provided error message
            revert(errorMessageOnFailure);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC165 support for testing whether a given interface is supported

    /** @dev Supported interfaces (for ERC165 support). */
    mapping(bytes4 => bool) internal _supportedInterfaces;
    
    /**
     * @notice Determine whether or not this contract supports a given interface.
     *
     * @dev [ERC165] Implements the ERC165 API.
     * 
     * @param interfaceId The result of xor-ing together the function selectors of all functions in the interface
     * of interest.
     * @return implementsInterface `true` if this contract implements the requested interface.
     */
    function supportsInterface(bytes4 interfaceId) external view override(IERC165) returns (bool implementsInterface) {
        return interfaceId == 0x01ffc9a7 ? true // Required by ERC165 (the ERC165 interfaceId itself)
        : interfaceId == 0xffffffff ? false  // Required by ERC165
        : _supportedInterfaces[interfaceId];
    }

    /** @dev Register a supported interface via ERC165. */
    function registerInterfaceViaERC165(bytes4 interfaceId, bool supported) internal {
        require(interfaceId != 0x01ffc9a7 && interfaceId != 0xffffffff, "Bad interfaceId"); // Reserved by ERC165
        _supportedInterfaces[interfaceId] = supported;
    }

    /**
     * @dev Ensure another contract supports a given interface (reverts transaction if not).
     *
     * @param contractAddr The contract address.
     * @param abiEncoding The ABI encoding of a function call to the contract address.
     * @param errMsg The string to revert with if the function cannot be called.
     * @return success `true` unless reverting.
     */
    function callERC165Contract(address contractAddr, bytes memory abiEncoding, string memory errMsg)
            internal extCaller returns (bool success) {
        // Get function selector from the ABI encoding
        require(abiEncoding.length >= 4);  // Sanity check
        bytes4 functionSelector;
        assembly {
            // functionSelector is first 4 bytes after 32-byte length field
            functionSelector := mload(add(abiEncoding, 32))
        }
        
        {
            // Check whether contractAddr implements the required interface (consisting of the
            // single function with the selector `functionSelector`), using ERC165.
            // Technically ERC165 requires two preliminary calls to supportsInterface, with param
            // 0x01ffc9a7 (returning true), then 0xffffffff (returning false), then a third call
            // to query whether the desired function is supported. We skip the first and second
            // calls to save gas, at the cost of strictness.
            (, bytes memory returnData) = callContractFunction(
                    contractAddr,
                    /* valueETH = */ 0,
                    abi.encodeWithSignature("supportsInterface(bytes4)", functionSelector),
                    "supportsInterface failed");
            bool interfaceSupported;
            if (returnData.length >= 1) {
                assembly {
                    // Return data (bool) starts after bytes length field
                    interfaceSupported := mload(add(returnData, 32))
                }
            } else {
                interfaceSupported = false;
            }
            require(interfaceSupported, "Ext contract doesn't impl reqd fn");
        }
        
        {
            // callContractFunction below will only revert on failure if errMsg is not empty
            require(bytes(errMsg).length > 0);
            
            // Call function with the requested functionSelector in the contract at contractAddr,
            // using the given ABI encoding of the functionSelector and the arguments
            (, bytes memory returnData) = callContractFunction(
                    contractAddr,
                    /* valueETH = */ 0,
                    abiEncoding,
                    errMsg);
            // Decode the return data
            bytes4 returnedBytes4;
            if (returnData.length >= 4) {
                assembly {
                    // Return data starts after bytes length field
                    returnedBytes4 := mload(add(returnData, 32))
                }
            } else {
                returnedBytes4 = 0;
            }
            // Require the implemented interface function to return its own selector (this is used by
            // ERC1363 and ERC4524 for spender/receiver interfaces).
            require(returnedBytes4 == functionSelector, "Wrong ext fn ret val");
        }
        
        return true;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC1820 support for registering and finding the implementer of an interface

    /** @dev The ERC1820 registry address. */
    address internal constant ERC1820_REGISTRY_ADDRESS = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    /** @dev Register an interface in the ERC1820 registry. */
    function registerInterfaceViaERC1820(address account, string memory interfaceName, address implementer) internal {
        (bool success,) =
                ERC1820_REGISTRY_ADDRESS.call(abi.encodeWithSignature(
                        "setInterfaceImplementer(address,bytes32,address)",
                        /* addr = */ account,
                        /* interfaceHash = */ keccak256(abi.encodePacked(interfaceName)),
                        /* implementer = */ implementer));
        require(success, "setInterfaceImplementer failed");
    }

    /**
     * @dev Register or unregister an interface in the ERC1820 registry, with this address as the account
     * and implementer.
     */
    function registerInterfaceViaERC1820(string memory interfaceName, bool enable) internal {
        registerInterfaceViaERC1820(address(this), interfaceName, enable ? address(this) : address(0));
    }

    /**
     * @dev Look up an interface in the ERC1820 registry.
     *
     * @param addrToQuery Address being queried for the implementer of an interface.
     * @param interfaceHash keccak256 hash of the name of the interface as a string.
     * @return interfaceAddr The address of the contract which implements the interface `hash` for `addr`, 
     *         or `address(0)` if `addr` did not register an implementer for this interface (or if the
     *         registry could not be called).
     */
    function lookUpInterfaceViaERC1820(address addrToQuery, bytes32 interfaceHash)
                internal view returns(address interfaceAddr) {
        (bool success, bytes memory returnBytes) =
                // Use staticcall since getInterfaceImplementer is a view function
                ERC1820_REGISTRY_ADDRESS.staticcall(abi.encodeWithSignature(
                        "getInterfaceImplementer(address,bytes32)",
                        addrToQuery, interfaceHash));
        require(success, "No ERC1820 registry");
        
        // If there is no registered implementer, the returned bytes will have zero length.
        // If there is a registered implementer, the returned bytes will have length 32,
        // with the 160-bit implementer address ABI-encoded into one 256-bit word.
        uint256 lenBytes;
        assembly { lenBytes := mload(returnBytes) }
        if (lenBytes == 32) {
            // There is a registered implementer
            address implementerAddr;
            assembly {
                implementerAddr := mload(add(returnBytes, 32))
            }
            return implementerAddr;
        } else {
            return address(0);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Functions for interacting with other contracts (modified with `extCaller` for reentrancy protection)

    /**
     * @dev Call the ERC777 sender's `tokensToSend` function. Should be called before any account state changes.
     *
     * @param sender The address holding the tokens being sent
     * @param recipient The address of the recipient
     * @param amount The amount of tokens to be sent
     * @param data Data generated by the user to be passed to the recipient
     * @param operatorData Data generated by the operator to be passed to the recipient
     * @return success `true` if `sender` is an ERC777 contract, and the call to `from.tokensToSend` succeeded.
     */
    function call_ERC777TokensSender_tokensToSend(
            address operator, address sender, address recipient, uint256 amount,
            bytes memory data, bytes memory operatorData) internal extCaller returns (bool success) {
        address senderImplementation = lookUpInterfaceViaERC1820(
                sender,
                // keccak256(abi.encodePacked("ERC777TokensSender"))
                0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895);
        if (isContract(senderImplementation)) {
            (success,) = senderImplementation.call(
                    abi.encodeWithSignature(
                            "tokensToSend(address,address,address,uint256,bytes,bytes)",
                            operator, sender, recipient, amount, data, operatorData));
        }
        // Don't fail if sender couldn't be called (it is optional for sender to implement ERC777 sender interface)
    }

    /**
     * @dev Call the ERC777 recipient's `tokensReceived` function. Should be called after account state is updated.
     *
     * @param operator The address performing the send or mint.
     * @param sender The address holding the tokens being sent.
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     * @param data Data generated by the user to be passed to the recipient.
     * @param operatorData Data generated by the operator to be passed to the recipient.
     * @return success `true` if `recipient` is an ERC777 contract, and the call to
     *             `recipient.tokensReceived` succeeded, or `recipient` is an EOA.
     */
    function call_ERC777TokensRecipient_tokensReceived(
            address operator, address sender, address recipient, uint256 amount,
            bytes memory data, bytes memory operatorData) internal extCaller returns (bool success) {
        address recipientImpl = lookUpInterfaceViaERC1820(
                recipient,
                // keccak256(abi.encodePacked("ERC777TokensRecipient"))
                0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b);
        if (recipientImpl != address(0)) {
            callContractFunction(
                    recipientImpl,
                    /* valueETH = */ 0,
                    abi.encodeWithSignature(
                            "tokensReceived(address,address,address,uint256,bytes,bytes)",
                            operator, sender, recipient, amount, data, operatorData),
                    "tokensReceived failed");
        } else {
            // The ERC777 spec specifies that sending to a non-ERC777 contract must revert, while sending to a
            // non-contract address (an EOA) must silently continue.
            // https://eips.ethereum.org/EIPS/eip-777#backward-compatibility
            // Note that `isContract` will return a false negative if the contract's constructor has not completed,
            // and in this case the transaction will silently succeed when sending to a contract that does not
            // implement the ERC777 receiver function. However, the reference implementation of ERC777 has this
            // same problem, and there's no solution for this currently for Ethereum contracts.
            require(!isContract(recipient), "Not ERC777 recipient");
        }
        return true;
    }

    /**
     * @dev Call the ERC1363 spender's `onApprovalReceived` function. Should be called after account state is updated.
     *
     * @param holder The address holding the tokens being spent.
     * @param spender The address spending the tokens.
     * @param amount The number of tokens to be spent.
     * @param data Data generated by the user to be passed to the recipient.
     * @return success `true` if `recipient` is an ERC1363 contract, and the call to
     *             `spender.onApprovalReceived` succeeded.
     */
    function call_ERC1363Spender_onApprovalReceived(
            address holder, address spender, uint256 amount, bytes memory data)
            internal extCaller returns (bool success) {
        // Recipient must declare it implements ERC1363 spender interface via ERC165
        return callERC165Contract(
                spender,
                abi.encodeWithSignature("onApprovalReceived(address,uint256,bytes)", holder, amount, data),
                "onApprovalReceived failed");
    }

    /**
     * @dev Call the ERC1363 receiver's `onTransferReceived` function. Should be called after account state is updated.
     *
     * @param operator address The address which called `transferAndCall` or `transferFromAndCall` function.
     * @param sender address The address which are token transferred from.
     * @param recipient address The address which are token transferred to.
     * @param amount uint256 The amount of tokens transferred.
     * @param data bytes Additional data with no specified format.
     * @return success `true` if `recipient` is an ERC1363 contract, and the call to
     *             `recipient.onApprovalReceived` succeeded.
     */
    function call_ERC1363Receiver_onTransferReceived(
            address operator, address sender, address recipient, uint256 amount, bytes memory data)
            internal extCaller returns (bool success) {
        // Recipient must declare it implements ERC1363 receiver interface via ERC165
        return callERC165Contract(
                recipient,
                abi.encodeWithSignature("onTransferReceived(address,address,uint256,bytes)",
                        operator, sender, amount, data),
                "onTransferReceived failed");
    }

    /**
     * @dev Call the ERC4524 recipient's `onERC20Received` function. Should be called after account state is updated.
     *
     * @param operator The address performing the send or mint.
     * @param sender The address holding the tokens being sent.
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     * @param data Data generated by the user to be passed to the recipient.
     * @return success `true` if `recipient` is an ERC4524 contract, and the call to
     *             `recipient.tokensReceived` succeeded.
     */
    function call_ERC4524TokensRecipient_onERC20Received(
            address operator, address sender, address recipient, uint256 amount, bytes memory data)
            internal extCaller returns (bool success) {
        // Sending to an EOA always succeeds, by falling through to the return statement
        if (isContract(recipient)) {
            // Recipient must declare it implements ERC4524 receiver interface via ERC165
            callERC165Contract(recipient,
                    abi.encodeWithSignature("onERC20Received(address,address,uint256,bytes)",
                            operator, sender, amount, data),
                    "onERC20Received failed");
        }
        // Either recipient is an EOA, or receiver's onERC20Received function was successfully called
        // and the function returned the correct value.
        return true;
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // Permitting
    
    /**
     * @dev Check permit certificate. Reverts if certificate is not valid.
     *
     * @param deadline The block timestamp after which the certificate is invalid.
     * @param keccak256ABIEncoding The result of calling `keccak256(abi.encode(...))` with the `Permit` call typehash.
     * @param v The ECDSA `v` value.
     * @param r The ECDSA `r` value.
     * @param s The ECDSA `s` value.
     * @param requiredSigner The required value of the address recovered from the signature.
     */
    function checkPermit(uint256 deadline, bytes32 keccak256ABIEncoding,
            uint8 v, bytes32 r, bytes32 s, address requiredSigner) internal view {
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "Cert expired");

        // From:
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol
        //
        // See https://eips.ethereum.org/EIPS/eip-1271 :
        //
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Bad sig s val");
        require(v == 27 || v == 28, "Bad sig v val");

        // Recover address of signer from digest, and check it matches the required signer (the token holder)
        // The \x19 prefix is part of the Recursive Length Prefix (RLP) encoding:
        // https://blog.ricmoo.com/verifying-messages-in-solidity-50a94f82b2ca
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, keccak256ABIEncoding));
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == requiredSigner, "Invalid sig");
    }
}

