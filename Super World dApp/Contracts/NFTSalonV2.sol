// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol


// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;


/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;



/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
    uint256[49] private __gap;
}


// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;


/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// OpenZeppelin Contracts v4.4.1 (interfaces/IERC165.sol)

pragma solidity ^0.8.0;

// File: @openzeppelin/contracts/interfaces/IERC2981.sol


// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;


/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be payed in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

// File: @openzeppelin/contracts/utils/Strings.sol


// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// File: @openzeppelin/contracts/utils/cryptography/ECDSA.sol


// OpenZeppelin Contracts (last updated v4.5.0-rc.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;


/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// File: contracts/library/SignatureValidator.sol


pragma solidity ^0.8.0;


library SignatureValidator {
    using ECDSA for bytes32;

    function verifySignature(
        address _signer,
        bytes32 _hash,
        bytes memory _signature
    ) internal pure {
        bytes32 ethSignedMessageHash = _hash.toEthSignedMessageHash();
        address recoveredAddress = ethSignedMessageHash.recover(_signature);

        require(recoveredAddress == _signer, "Signer and recovered addresses do not match");
    }
}

// File: contracts/structs/TokenMintData.sol


pragma solidity ^0.8.0;

struct TokenMintData {
    uint tokenId;
    uint batchId;
    uint price;
    address payable creator;
    address payable buyer;
    // JSON metadata with userId, name, fileUrl, thumbnailUrl information
    string metadata;
    string secretUrl;
}

// File: contracts/interfaces/ISuperAssetV2.sol


pragma solidity ^0.8.0;



interface ISuperAssetV2 is IERC165 {
    function setMarketplaceAddress(address marketplaceAddress) external;

    function setSignerAddress(address signerAddress) external;

    function setMetaUrl(string memory url) external;

    function mintTokenBatch(
        uint _amountToMint,
        uint _price,
        uint _batchId,
        address payable _creator,
        address payable _buyer,
        string memory _metadata,
        string memory _secretUrl,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) external payable;

    function mintToken(
        TokenMintData memory tokenData,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) external payable returns (uint);

    function getTokenData(uint tokenId)
        external
        view
        returns (
            uint _batchId,
            uint _price,
            address _creator,
            address _buyer,
            string memory _metadata,
            string memory _location
        );

    function setTokenLocation(uint _tokenId, string memory _location) external;

    function setTokenRoyalties(
        uint256 _tokenId,
        address payable[] memory _royaltyAddresses,
        uint256[] memory _royaltyPercentages
    ) external;

    function getOwnedNFTs(address _owner) external view returns (string memory);

    function exists(uint tokenId) external view returns (bool);
}

// File: contracts/interfaces/IMultiRoyalty.sol



pragma solidity ^0.8.0;


/**
 * @dev Interface for the NFT Royalty Standard for NFTSalonV2
 */
interface IMultiRoyalty is IERC2981 {
    /**
     * @dev Called with the sale price to determine how much royalty is owed and to whom.
     * @param tokenId - the NFT asset queried for royalty information
     * @param salePrice - the sale price of the NFT asset specified by `tokenId`
     * @return receivers - addresses of who should be sent the royalty payment
     * @return royaltyAmounts - the royalty payment amounts for `salePrice`
     */
    function royaltiesInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address[] memory receivers, uint256[] memory royaltyAmounts);
}

// File: contracts/library/TokenType.sol


pragma solidity ^0.8.0;






library TokenType {
    function isSuperAssetV2(address _tokenAddress) internal view returns (bool) {
        return ISuperAssetV2(_tokenAddress).supportsInterface(type(ISuperAssetV2).interfaceId);
    }

    function isERC721(address _tokenAddress) internal view returns (bool) {
        return IERC721(_tokenAddress).supportsInterface(type(IERC721).interfaceId);
    }

    function isERC1155(address _tokenAddress) internal view returns (bool) {
        return IERC1155(_tokenAddress).supportsInterface(type(IERC1155).interfaceId);
    }

    function supportsMultiRoyalty(address _tokenAddress) internal view returns (bool) {
        return IMultiRoyalty(_tokenAddress).supportsInterface(type(IMultiRoyalty).interfaceId);
    }

    function supportsSingleRoyalty(address _tokenAddress) internal view returns (bool) {
        return IERC2981(_tokenAddress).supportsInterface(type(IERC2981).interfaceId);
    }
}

// File: contracts/NFTSalonV2.sol


pragma solidity ^0.8.0;










contract NFTSalonV2 is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using TokenType for address;

    struct Auction {
        uint bidPrice;
        uint bidEnd;
        bool isBidding;
        bool isCountdown;
        address payable bidder;
        address seller;
        string metadata;
        string secretUrl;
    }

    address private _signer;
    uint private _systemTotalBalance;
    uint public systemRoyaltyPercentage;

    mapping(address => mapping(uint => Auction)) private _auctions;
    mapping(address => mapping(uint => string)) private _locations;
    mapping(address => uint) private _userBalances;

    event BidStarted(
        uint indexed tokenId,
        address indexed seller,
        bool isBidding,
        uint bidPrice,
        uint endTime,
        bool isClosedBySuperWorld,
        uint timestamp,
        string location
    );
    event TokenBidded(uint indexed tokenId, address indexed bidder, uint bidPrice, uint timestamp);
    event TransferFailed(address indexed receiver, uint amount);

    function initialize(uint percent, address signer) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        systemRoyaltyPercentage = percent;
        _signer = signer;
    }

    function setSignerAddress(address signer) public onlyOwner {
        _signer = signer;
    }

    function setSystemRoyaltyPercentage(uint percentage) public onlyOwner {
        systemRoyaltyPercentage = percentage;
    }

    function buyToken(
        uint _tokenId,
        uint _batchId,
        uint _price,
        address _tokenAddress,
        address payable _seller,
        string memory _metadata,
        string memory _secretUrl,
        string memory _location,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) public payable nonReentrant {
        require(msg.value >= _price, "NFTSalonV2: Incorrect amount specified");

        _mintOrBuyToken(
            _tokenId,
            _batchId,
            _price,
            _tokenAddress,
            _seller,
            payable(_msgSender()),
            _metadata,
            _secretUrl,
            _royaltyAddresses,
            _royaltyPercentages,
            _signature,
            false
        );

        if (_tokenAddress.isSuperAssetV2()) {
            ISuperAssetV2(_tokenAddress).setTokenLocation(_tokenId, _location);
        }
        _locations[_tokenAddress][_tokenId] = _location;
    }

    function _buyToken(
        uint _tokenId,
        uint _amount,
        address _tokenAddress,
        address payable _seller,
        address payable _buyer,
        string memory _location,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bool _isAuction
    ) private {
        if (!_checkSellerValidity(_tokenId, _tokenAddress, _seller, _isAuction)) {
            return;
        }

        if (_tokenAddress.isERC721()) {
            IERC721(_tokenAddress).safeTransferFrom(_seller, _buyer, _tokenId);
        } else if (_tokenAddress.isERC1155()) {
            IERC1155(_tokenAddress).safeTransferFrom(_seller, _buyer, _tokenId, 1, "");
        }

        {
            uint totalAmount = _amount;
            uint systemFee = (_amount * systemRoyaltyPercentage) / 100;

            totalAmount -= systemFee;
            _systemTotalBalance += systemFee;

            totalAmount = _payRoyaltyMembers(
                totalAmount,
                _tokenId,
                _tokenAddress,
                _royaltyAddresses,
                _royaltyPercentages
            );

            require(totalAmount >= 0, "NFTSalonV2: Remained amount should not be negative");

            (bool success, ) = _seller.call{value: totalAmount}("");
            if (success == false) {
                emit TransferFailed(_seller, totalAmount);
            }
        }

        if (_tokenAddress.isSuperAssetV2()) {
            ISuperAssetV2(_tokenAddress).setTokenLocation(_tokenId, _location);
        }
        _locations[_tokenAddress][_tokenId] = _location;
    }

    function addBid(
        uint _tokenId,
        uint _price,
        uint _endTimestamp,
        bool _isCountdown,
        address _tokenAddress,
        address payable _seller,
        string memory _metadata,
        string memory _secretUrl,
        string memory _location,
        bytes memory _signature
    ) public payable nonReentrant {
        require(msg.value >= _price, "NFTSalonV2: Incorrect amount specified");

        SignatureValidator.verifySignature(
            _signer,
            keccak256(abi.encodePacked(_tokenId, _tokenAddress, _price, _seller, _metadata, _secretUrl)),
            _signature
        );

        Auction storage tokenAuctionData = _auctions[_tokenAddress][_tokenId];
        if (tokenAuctionData.bidder == payable(address(0x0))) {
            require(tokenAuctionData.isBidding == false, "NFTSalonV2: Token is already on auction");

            if (_isCountdown == false) {
                require(_endTimestamp > block.timestamp, "NFTSalonV2: Incorrect auction end timestamp specified");
                tokenAuctionData.bidEnd = _endTimestamp;
            } else {
                tokenAuctionData.bidEnd = _endTimestamp + block.timestamp;
            }
            tokenAuctionData.isCountdown = _isCountdown;
            tokenAuctionData.isBidding = true;
            tokenAuctionData.bidPrice = _price;
            tokenAuctionData.seller = _seller;
            tokenAuctionData.bidder = payable(_msgSender());
            tokenAuctionData.metadata = _metadata;
            tokenAuctionData.secretUrl = _secretUrl;

            emit BidStarted(_tokenId, _seller, true, _price, _endTimestamp, false, block.timestamp, _location);
        } else {
            require(_price > tokenAuctionData.bidPrice, "NFTSalonV2: Incorrect bid price is specified");
            require(tokenAuctionData.isBidding, "NFTSalonV2: Auction ended");
            require(tokenAuctionData.bidEnd > block.timestamp, "NFTSalonV2: Auction ended");

            uint oldBidAmount = tokenAuctionData.bidPrice;
            address oldBidder = tokenAuctionData.bidder;

            tokenAuctionData.bidder = payable(_msgSender());
            tokenAuctionData.bidPrice = _price;

            (bool success, ) = oldBidder.call{value: oldBidAmount}("");
            if (success == false) {
                _userBalances[oldBidder] += oldBidAmount;
            }
            emit TokenBidded(_tokenId, _msgSender(), _price, block.timestamp);
        }

        if (_tokenAddress.isSuperAssetV2() && ISuperAssetV2(_tokenAddress).exists(_tokenId)) {
            ISuperAssetV2(_tokenAddress).setTokenLocation(_tokenId, _location);
        }
        _locations[_tokenAddress][_tokenId] = _location;
    }

    function closeBid(
        uint _tokenId,
        uint _batchId,
        address _tokenAddress,
        address payable _seller,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) public onlyOwner nonReentrant {
        Auction storage tokenAuctionData = _auctions[_tokenAddress][_tokenId];

        require(tokenAuctionData.isBidding, "NFTSalonV2: Token is not bidding");
        require(tokenAuctionData.bidEnd < block.timestamp, "NFTSalonV2: The Auction is not ended");

        _mintOrBuyToken(
            _tokenId,
            _batchId,
            tokenAuctionData.bidPrice,
            _tokenAddress,
            _seller,
            tokenAuctionData.bidder,
            tokenAuctionData.metadata,
            tokenAuctionData.secretUrl,
            _royaltyAddresses,
            _royaltyPercentages,
            _signature,
            true
        );

        tokenAuctionData.bidder = payable(address(0x0));
        tokenAuctionData.bidEnd = 0;
        tokenAuctionData.isBidding = false;
        tokenAuctionData.bidPrice = 0;
        tokenAuctionData.seller = address(0x0);
        tokenAuctionData.isCountdown = false;
        tokenAuctionData.metadata = "";
        tokenAuctionData.secretUrl = "";

        emit BidStarted(_tokenId, _seller, false, 0, 0, true, block.timestamp, "");
    }

    function closeBidByOwner(
        uint _tokenId,
        uint _batchId,
        address _tokenAddress,
        address payable _seller,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) public nonReentrant {
        Auction storage tokenAuctionData = _auctions[_tokenAddress][_tokenId];

        require(tokenAuctionData.isBidding, "NFTSalonV2: Token is not bidding");
        require(tokenAuctionData.seller == _msgSender(), "NFTSalonV2: Seller is not the owner");
        require(tokenAuctionData.seller == _seller, "NFTSalonV2: Incorrect seller is specified");
        require(tokenAuctionData.bidEnd < block.timestamp, "NFTSalonV2: Auction is still active");

        _mintOrBuyToken(
            _tokenId,
            _batchId,
            tokenAuctionData.bidPrice,
            _tokenAddress,
            _seller,
            tokenAuctionData.bidder,
            tokenAuctionData.metadata,
            tokenAuctionData.secretUrl,
            _royaltyAddresses,
            _royaltyPercentages,
            _signature,
            true
        );

        tokenAuctionData.bidder = payable(address(0x0));
        tokenAuctionData.bidEnd = 0;
        tokenAuctionData.isBidding = false;
        tokenAuctionData.bidPrice = 0;
        tokenAuctionData.seller = address(0x0);
        tokenAuctionData.isCountdown = false;
        tokenAuctionData.metadata = "";
        tokenAuctionData.secretUrl = "";

        emit BidStarted(_tokenId, _msgSender(), false, 0, 0, false, block.timestamp, "");
    }

    function closeBidByBuyer(
        uint _tokenId,
        uint _batchId,
        address _tokenAddress,
        address payable _seller,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) public nonReentrant {
        Auction storage tokenAuctionData = _auctions[_tokenAddress][_tokenId];

        require(tokenAuctionData.isBidding, "NFTSalonV2: Token is not bidding");
        require(tokenAuctionData.bidder == _msgSender(), "NFTSalonV2: Not Bidder");
        require(tokenAuctionData.bidEnd < block.timestamp, "NFTSalonV2: Auction is still active");

        _mintOrBuyToken(
            _tokenId,
            _batchId,
            tokenAuctionData.bidPrice,
            _tokenAddress,
            _seller,
            tokenAuctionData.bidder,
            tokenAuctionData.metadata,
            tokenAuctionData.secretUrl,
            _royaltyAddresses,
            _royaltyPercentages,
            _signature,
            true
        );

        tokenAuctionData.bidder = payable(address(0x0));
        tokenAuctionData.bidEnd = 0;
        tokenAuctionData.isBidding = false;
        tokenAuctionData.bidPrice = 0;
        tokenAuctionData.seller = address(0x0);
        tokenAuctionData.isCountdown = false;
        tokenAuctionData.metadata = "";
        tokenAuctionData.secretUrl = "";

        emit BidStarted(_tokenId, _seller, false, 0, 0, false, block.timestamp, "");
    }

    function giftToken(
        uint _tokenId,
        address _tokenAddress,
        address _receiver
    ) public {
        require(_auctions[_tokenAddress][_tokenId].isBidding == false, "NFTSalonV2: Token is bidded");

        if (_tokenAddress.isERC721()) {
            require(IERC721(_tokenAddress).ownerOf(_tokenId) == _msgSender(), "NFTSalonV2: Only token owner allowed");
            IERC721(_tokenAddress).safeTransferFrom(_msgSender(), _receiver, _tokenId);
        } else if (_tokenAddress.isERC1155()) {
            require(
                IERC1155(_tokenAddress).balanceOf(_msgSender(), _tokenId) != 0,
                "NFTSalonV2: Only token owner allowed"
            );
            IERC1155(_tokenAddress).safeTransferFrom(_msgSender(), _receiver, _tokenId, 1, "");
        }
    }

    function withdrawSystemBalance() public payable onlyOwner nonReentrant returns (bool) {
        require(_systemTotalBalance > 0, "NFTSalonV2: System balance should be positive");

        (bool success, ) = _msgSender().call{value: _systemTotalBalance}("");
        if (success) {
            _systemTotalBalance = 0;
        } else {
            emit TransferFailed(_msgSender(), _systemTotalBalance);
        }
        return success;
    }

    function withdrawUserBalance() public payable nonReentrant returns (bool) {
        require(_userBalances[_msgSender()] > 0, "NFTSalonV2: System balance should be positive");

        (bool success, ) = _msgSender().call{value: _userBalances[_msgSender()]}("");
        if (success) {
            _userBalances[_msgSender()] = 0;
        } else {
            emit TransferFailed(_msgSender(), _userBalances[_msgSender()]);
        }
        return success;
    }

    function getTokenLocation(uint _tokenId, address _tokenAddress) public view returns (string memory) {
        return _locations[_tokenAddress][_tokenId];
    }

    function getSystemTotalBalance() public view returns (uint) {
        return _systemTotalBalance;
    }

    function getTokenAuctionDetails(uint _tokenId, address _tokenAddress)
        external
        view
        returns (
            uint _bidPrice,
            uint _bidEnd,
            bool _isBidding,
            bool _isCountdown,
            address _bidder,
            address _seller,
            string memory _metadata
        )
    {
        Auction storage tokenAuctionData = _auctions[_tokenAddress][_tokenId];
        _bidPrice = tokenAuctionData.bidPrice;
        _bidEnd = tokenAuctionData.bidEnd;
        _isBidding = tokenAuctionData.isBidding;
        _isCountdown = tokenAuctionData.isCountdown;
        _bidder = tokenAuctionData.bidder;
        _seller = tokenAuctionData.seller;
        _metadata = tokenAuctionData.metadata;
    }

    function _mintOrBuyToken(
        uint _tokenId,
        uint _batchId,
        uint _price,
        address _tokenAddress,
        address payable _seller,
        address payable _buyer,
        string memory _metadata,
        string memory _secretUrl,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature,
        bool _isAuction
    ) private {
        if (_tokenAddress.isSuperAssetV2() && !ISuperAssetV2(_tokenAddress).exists(_tokenId)) {
            uint systemFee = (_price * systemRoyaltyPercentage) / 100;
            _price -= systemFee;
            _systemTotalBalance += systemFee;

            TokenMintData memory tokenData = TokenMintData(
                _tokenId,
                _batchId,
                _price,
                _seller,
                _buyer,
                _metadata,
                _secretUrl
            );

            ISuperAssetV2(_tokenAddress).mintToken{value: _price}(
                tokenData,
                _royaltyAddresses,
                _royaltyPercentages,
                _signature
            );
        } else {
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    _tokenId,
                    _price,
                    _batchId,
                    _seller,
                    _buyer,
                    _metadata,
                    _secretUrl,
                    _royaltyAddresses,
                    _royaltyPercentages
                )
            );
            SignatureValidator.verifySignature(_signer, messageHash, _signature);

            string memory location = _locations[_tokenAddress][_tokenId];
            _buyToken(
                _tokenId,
                _price,
                _tokenAddress,
                _seller,
                _buyer,
                location,
                _royaltyAddresses,
                _royaltyPercentages,
                _isAuction
            );
        }
    }

    function _checkSellerValidity(
        uint _tokenId,
        address _tokenAddress,
        address payable _seller,
        bool _isAuction
    ) private returns (bool) {
        bool isSellerValid = true;
        if (_tokenAddress.isERC721()) {
            isSellerValid = (_seller == payable(IERC721(_tokenAddress).ownerOf(_tokenId)));
        } else if (_tokenAddress.isERC1155()) {
            isSellerValid = (IERC1155(_tokenAddress).balanceOf(_seller, _tokenId) > 0);
        }
        if (_isAuction) {
            if (!isSellerValid) {
                address payable bidder = _auctions[_tokenAddress][_tokenId].bidder;
                uint bidPrice = _auctions[_tokenAddress][_tokenId].bidPrice;
                if (bidder != payable(address(0x0)) && bidPrice != 0) {
                    (bool status, ) = (bidder).call{value: bidPrice}("");
                    if (status == false) {
                        _userBalances[bidder] += bidPrice;
                        emit TransferFailed(bidder, bidPrice);
                    }
                }
                return false;
            }
        } else {
            require(isSellerValid, "NFTSalonV2: Wrong seller address");
        }

        return isSellerValid;
    }

    function _payRoyaltyMembers(
        uint _totalAmount,
        uint _tokenId,
        address _tokenAddress,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages
    ) private returns (uint) {
        if (_tokenAddress.supportsMultiRoyalty()) {
            address[] memory receivers;
            uint[] memory royaltyAmounts;

            (receivers, royaltyAmounts) = IMultiRoyalty(_tokenAddress).royaltiesInfo(_tokenId, _totalAmount);
            if (receivers.length == 0 || royaltyAmounts.length == 0) {
                if (_royaltyAddresses.length > 0 && _royaltyPercentages.length > 0) {
                    (receivers, royaltyAmounts) = _getMembersRoyalty(
                        _totalAmount,
                        _royaltyAddresses,
                        _royaltyPercentages
                    );
                    if (_tokenAddress.isSuperAssetV2()) {
                        ISuperAssetV2(_tokenAddress).setTokenRoyalties(
                            _tokenId,
                            _royaltyAddresses,
                            _royaltyPercentages
                        );
                    }
                }
            }

            for (uint i = 0; i < receivers.length; ++i) {
                address receiver = receivers[i];
                uint royaltyAmount = royaltyAmounts[i];
                _totalAmount -= royaltyAmount;

                (bool sent, ) = receiver.call{value: royaltyAmount}("");
                if (sent == false) {
                    emit TransferFailed(receiver, royaltyAmount);
                }
            }
        } else if (_tokenAddress.supportsSingleRoyalty()) {
            (address receiver, uint royaltyAmount) = IERC2981(_tokenAddress).royaltyInfo(_tokenId, _totalAmount);
            _totalAmount -= royaltyAmount;

            (bool sent, ) = receiver.call{value: royaltyAmount}("");
            if (sent == false) {
                emit TransferFailed(receiver, royaltyAmount);
            }
        }

        return _totalAmount;
    }

    function _getMembersRoyalty(
        uint salePrice,
        address payable[] memory royaltyAddresses,
        uint[] memory royaltyPercentages
    ) public pure returns (address[] memory receivers, uint[] memory royaltyAmounts) {
        receivers = new address[](royaltyAddresses.length);
        royaltyAmounts = new uint[](royaltyPercentages.length);
        for (uint i = 0; i < royaltyAddresses.length; ++i) {
            receivers[i] = royaltyAddresses[i];
            royaltyAmounts[i] = (salePrice * royaltyPercentages[i]) / 100;
        }
    }
}
