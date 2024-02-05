// File: @openzeppelin/contracts/utils/Context.sol

// SPDX-License-Identifier: MIT
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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
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
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


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
abstract contract ReentrancyGuard {
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

    constructor() {
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

// File: contracts/library/CompactArray.sol


pragma solidity ^0.8.0;

library CompactArray {
    function removeByValue(uint[] storage array, uint value) internal {
        uint index = 0;
        while (index < array.length && array[index] != value) {
            index++;
        }
        if (index == array.length) {
            return;
        }
        for (uint i = index; i < array.length - 1; i++){
            array[i] = array[i + 1];
        }
        delete array[array.length - 1];
        array.pop();
    }
}

// File: contracts/PlaceOfferERC1155.sol


pragma solidity ^0.8.0;
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/access/Ownable.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";





contract PlaceOfferERC1155 is Ownable, ReentrancyGuard {
    using CompactArray for uint[];

    struct Offer {
        uint price;
        address maker;
    }

    uint public percentageCut;
    uint public contractBalance;
    uint public offerCounter = 1;
    mapping(address => mapping(uint => mapping(address => uint))) public offerIds; //contractAddr -> (tokenId -> (offerMaker -> offerIds))
    mapping(address => mapping(uint => uint[])) public tokenOfferIds; //contractAddr -> (tokenId -> [offerIds])
    mapping(uint => Offer) public offers; //offerId => Offer details

    event OfferAdded(
        uint indexed tokenId,
        address indexed contractAddr,
        uint offerId,
        address offerMaker,
        uint offerPrice
    );
    event OfferUpdated(
        uint indexed tokenId,
        address indexed contractAddr,
        uint offerId,
        address offerMaker,
        uint offerPrice
    );
    event OfferAccepted(
        uint indexed tokenId,
        address indexed contractAddr,
        uint offerId,
        address offerMaker,
        address offerAcceptor,
        uint offerPrice
    );

    constructor(uint percent) {
        percentageCut = percent;
    }

    modifier isTokenOwner(uint tokenId, address contractAddr) {
        require(IERC1155(contractAddr).balanceOf(msg.sender, tokenId) != 0, "Only token owner allowed");
        _;
    }

    function setPercentageCut(uint percent) public onlyOwner {
        percentageCut = percent;
    }

    function addOffer(uint tokenId, address contractAddr) public payable nonReentrant {
        require(offerIds[contractAddr][tokenId][msg.sender] == 0, "An offer is already made by the given address");
        offerIds[contractAddr][tokenId][msg.sender] = offerCounter;
        (tokenOfferIds[contractAddr][tokenId]).push(offerCounter);
        offers[offerCounter] = Offer(msg.value, msg.sender);
        emit OfferAdded(tokenId, contractAddr, offerCounter, msg.sender, msg.value);
        offerCounter++;
    }

    function changeOffer(
        uint tokenId,
        address contractAddr,
        uint newPrice
    ) public payable nonReentrant {
        uint offerId = offerIds[contractAddr][tokenId][msg.sender];
        require(offerId > 0, "No offerId found");
        Offer storage offer = offers[offerId];
        require(offer.price != newPrice && newPrice > 0, "No change in offer");

        uint priceDiff;
        if (offer.price > newPrice) {
            //offer price reduced
            priceDiff = offer.price - newPrice;
            offer.price = newPrice;
            (bool sent, ) = msg.sender.call{value: priceDiff}("");
            emit OfferUpdated(tokenId, contractAddr, offerId, msg.sender, newPrice);
        } else {
            //offer price is increased
            priceDiff = newPrice - offer.price;
            require(msg.value >= priceDiff, "Incorrect amount specified");
            offer.price = newPrice;
            emit OfferUpdated(tokenId, contractAddr, offerId, msg.sender, newPrice);
        }
    }

    function withdrawOffer(uint tokenId, address contractAddr) public nonReentrant {
        uint offerId = offerIds[contractAddr][tokenId][msg.sender];
        require(offerId > 0, "No offerId found");
        Offer storage offer = offers[offerId];

        require(offer.price > 0, "No offer");
        uint withdrawAmount = offer.price;
        offer.maker = address(0);
        offer.price = 0;
        tokenOfferIds[contractAddr][tokenId].removeByValue(offerId);
        offerIds[contractAddr][tokenId][msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: withdrawAmount}("");
        emit OfferUpdated(tokenId, contractAddr, offerId, msg.sender, 0);
    }

    function acceptOffer(
        uint tokenId,
        address contractAddr,
        address offerMaker
    ) public nonReentrant isTokenOwner(tokenId, contractAddr) {
        uint offerId = offerIds[contractAddr][tokenId][offerMaker];
        require(offerId > 0, "No offerId found");

        Offer storage offer = offers[offerId];
        IERC1155(contractAddr).safeTransferFrom(msg.sender, offer.maker, tokenId, 1, "");
        uint fee = (offer.price * percentageCut) / 100;
        uint offerAfterCut = offer.price - fee;
        contractBalance += fee;
        (bool sent, ) = (msg.sender).call{value: offerAfterCut}("");
        uint[] storage ids = tokenOfferIds[contractAddr][tokenId];
        uint tokenOfferId;
        for (uint i = 0; i < ids.length; i++) {
            tokenOfferId = ids[i];
            Offer storage currentOffer = offers[tokenOfferId];
            if (tokenOfferId != offerId && currentOffer.maker != address(0) && currentOffer.price != 0) {
                (sent, ) = (currentOffer.maker).call{value: currentOffer.price}("");
                currentOffer.maker = address(0);
                currentOffer.price = 0;
            }
        }
        tokenOfferIds[contractAddr][tokenId] = new uint[](0);
        offerIds[contractAddr][tokenId][offerMaker] = 0;

        emit OfferAccepted(tokenId, contractAddr, offerId, offer.maker, msg.sender, offer.price);

        offer.maker = address(0);
        offer.price = 0;
    }

    function getOfferIDsForToken(uint tokenId, address contractAddr) public view returns (uint[] memory) {
        return tokenOfferIds[contractAddr][tokenId];
    }

    function withdrawOwner(uint fundAmount) public onlyOwner nonReentrant {
        require(fundAmount <= contractBalance, "Incorrect amount is specified");
        contractBalance -= fundAmount;
        (bool sent, ) = (msg.sender).call{value: fundAmount}("");
        if (!sent) {
            contractBalance += fundAmount;
        }
    }
}
