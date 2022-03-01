// SPDX-License-Identifier: MIT
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

// File: @openzeppelin/contracts/utils/introspection/ERC165.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// File: @openzeppelin/contracts/utils/introspection/ERC165Storage.sol


// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165Storage.sol)

pragma solidity ^0.8.0;


/**
 * @dev Storage based implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165Storage is ERC165 {
    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
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

// File: contracts/PerTokenRoyalties.sol



pragma solidity >=0.8.0 <0.9.0;



abstract contract PerTokenRoyalties is IMultiRoyalty, ERC165Storage {
    struct RoyaltyInfo {
        address receiver;
        uint8 percentage;
    }

    uint256 internal _maxRoyaltyPercentage;
    mapping(uint256 => RoyaltyInfo[]) internal _royalties;

    uint256 constant MAX_ROYALTY_PERCENTAGE = 50;

    constructor() {
        _maxRoyaltyPercentage = MAX_ROYALTY_PERCENTAGE;
    }

    function setMaxRoyaltyPercentage(uint256 percentage) public {
        _maxRoyaltyPercentage = percentage;
    }

    function _setTokenRoyalties(
        uint256 tokenId,
        address payable[] memory royaltyAddresses,
        uint256[] memory royaltyPercentages
    ) internal {
        require(
            royaltyAddresses.length == royaltyPercentages.length,
            "Royalty percentages and addresses count should be the same"
        );

        uint totalRoyaltyPercentage;
        for (uint256 i = 0; i < royaltyAddresses.length; i++) {
            _royalties[tokenId].push(RoyaltyInfo(royaltyAddresses[i], uint8(royaltyPercentages[i])));
            totalRoyaltyPercentage += royaltyPercentages[i];
        }

        require(totalRoyaltyPercentage <= MAX_ROYALTY_PERCENTAGE, "Maximum royalty percentage reached");
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = address(0);
        royaltyAmount = 0;
        RoyaltyInfo[] storage royalties = _royalties[tokenId];
        if (royalties.length > 0) {
            receiver = royalties[0].receiver;
            royaltyAmount = (salePrice * royalties[0].percentage) / 100;
        }
    }

    function royaltiesInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        override
        returns (address[] memory receivers, uint256[] memory royaltyAmounts)
    {
        RoyaltyInfo[] storage royalties = _royalties[tokenId];
        receivers = new address[](royalties.length);
        royaltyAmounts = new uint256[](royalties.length);
        for (uint256 i = 0; i < royalties.length; ++i) {
            receivers[i] = royalties[i].receiver;
            royaltyAmounts[i] = (salePrice * royalties[i].percentage) / 100;
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165Storage) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            interfaceId == type(IMultiRoyalty).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
