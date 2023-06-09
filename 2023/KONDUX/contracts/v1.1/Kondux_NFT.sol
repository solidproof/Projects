// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


// Import OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Kondux contract inherits from various OpenZeppelin contracts
contract Kondux is ERC721, ERC721Enumerable, Pausable, ERC721Burnable, ERC721Royalty, AccessControl {
    // Use Counters library for managing token IDs
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Events emitted by the contract
    event BaseURIChanged(string baseURI);
    event DnaChanged(uint256 indexed tokenID, uint256 dna);
    event DenominatorChanged(uint96 denominator);
    event DnaModified(uint256 indexed tokenID, uint256 dna, uint256 inputValue, uint8 startIndex, uint8 endIndex);
    event RoleChanged(address indexed addr, bytes32 role, bool enabled);

    // Role definitions
    bytes32 public MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public DNA_MODIFIER_ROLE = keccak256("DNA_MODIFIER_ROLE");

    // Contract state variables
    string public baseURI;
    uint96 public denominator;

    mapping (uint256 => uint256) public indexDna; // Maps token IDs to DNA values
    
    mapping (uint256 => uint256) public transferDates; // Maps token IDs to the timestamp of receiving the token

    /**
     * @dev Initializes the Kondux contract with the given name and symbol.
     * Grants the DEFAULT_ADMIN_ROLE, MINTER_ROLE, and DNA_MODIFIER_ROLE to the contract creator.
     * Inherits the ERC721 constructor to set the token name and symbol.
     *
     * @param _name The name of the token.
     * @param _symbol The symbol of the token.
     */
    constructor(string memory _name, string memory _symbol) 
        ERC721(_name, _symbol) {
            _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
            _setupRole(MINTER_ROLE, msg.sender);
            _setupRole(DNA_MODIFIER_ROLE, msg.sender);
    }


    /**
     * @dev Modifier that requires the caller to have the DEFAULT_ADMIN_ROLE.
     * Reverts with an error message if the caller does not have the required role.
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "kNFT Access Control: only admin");
        _;
    }

    /**
     * @dev Modifier that requires the caller to have the MINTER_ROLE.
     * Reverts with an error message if the caller does not have the required role.
     */
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "kNFT Access Control: only minter");
        _;
    }

    /**
     * @dev Modifier that requires the caller to have the DNA_MODIFIER_ROLE.
     * Reverts with an error message if the caller does not have the required role.
     */
    modifier onlyDnaModifier() {
        require(hasRole(DNA_MODIFIER_ROLE, msg.sender), "kNFT Access Control: only dna modifier");
        _;
    }


    /**
     * @dev Changes the denominator value.
     * Emits a DenominatorChanged event with the new denominator value.
     *
     * @param _denominator The new denominator value.
     * @return The updated denominator value.
     */
    function changeDenominator(uint96 _denominator) public onlyAdmin returns (uint96) { 
        denominator = _denominator;
        emit DenominatorChanged(denominator);
        return denominator;
    }

    /**
     * @dev Sets the default royalty for the contract.
     *
     * @param receiver The address that will receive the royalty fees.
     * @param feeNumerator The numerator of the royalty fee.
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyAdmin {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Sets the royalty for a specific token.
     *
     * @param tokenId The ID of the token for which the royalty will be set.
     * @param receiver The address that will receive the royalty fees.
     * @param feeNumerator The numerator of the royalty fee.
     */
    function setTokenRoyalty(uint256 tokenId,address receiver,uint96 feeNumerator) public onlyAdmin {
        _setTokenRoyalty(tokenId, receiver, feeNumerator); 
    }

    /**
     * @dev Sets the base URI for token metadata.
     * Emits a BaseURIChanged event with the new base URI.
     *
     * @param _newURI The new base URI.
     * @return The updated base URI.
     */
    function setBaseURI(string memory _newURI) external onlyAdmin returns (string memory) {
        baseURI = _newURI;
        emit BaseURIChanged(baseURI);
        return baseURI;
    }

    /**
     * @dev Returns the token URI for a given token ID.
     * Reverts if the token ID does not exist.
     *
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    /**
     * @dev Pauses the contract, preventing further token transfers.
     */
    function pause() public onlyAdmin {
        _pause();
    }

    /**
     * @dev Unpauses the contract, allowing token transfers.
     */
    function unpause() public onlyAdmin {
        _unpause();
    }


    /**
     * @dev Safely mints a new token with a specified DNA value for the recipient.
     * Increments the token ID counter.
     *
     * @param to The address of the recipient.
     * @param dna The DNA value of the new token.
     * @return The new token ID.
     */
    function safeMint(address to, uint256 dna) public onlyMinter returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _setDna(tokenId, dna);
        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Sets the DNA value for a given token ID.
     *
     * @param _tokenID The ID of the token for which the DNA value will be set.
     * @param _dna The new DNA value.
     */
    function setDna(uint256 _tokenID, uint256 _dna) public onlyDnaModifier {
        _setDna(_tokenID, _dna);
    }

    /**
     * @dev Returns the DNA value for a given token ID.
     * Reverts if the token ID does not exist.
     *
     * @param _tokenID The ID of the token.
     * @return The DNA value of the token.
     */
    function getDna (uint256 _tokenID) public view returns (uint256) {
        require(_exists(_tokenID), "ERC721Metadata: URI query for nonexistent token");
        return indexDna[_tokenID];
    }

    /**
     * @dev Reads a range of bytes from the DNA value of a given token ID.
     * Reverts if the specified range is invalid.
     *
     * @param _tokenID The ID of the token.
     * @param startIndex The starting index of the byte range.
     * @param endIndex The ending index of the byte range.
     * @return The extracted value from the specified byte range.
     */
    function readGen(uint256 _tokenID, uint8 startIndex, uint8 endIndex) public view returns (int256) {
        require(startIndex < endIndex && endIndex <= 32, "Invalid range");

        uint256 originalValue = indexDna[_tokenID];
        uint256 extractedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            assembly {
                let bytePos := sub(31, i) // Reverse the index since bytes are stored in big-endian
                let shiftAmount := mul(8, bytePos)

                // Extract the byte from the original value at the current position
                let extractedByte := and(shr(shiftAmount, originalValue), 0xff)

                // Shift the extracted byte to the left by the number of positions
                // from the start of the requested range
                let adjustedShiftAmount := mul(8, sub(i, startIndex))

                // Combine the shifted byte with the previously extracted bytes
                extractedValue := or(extractedValue, shl(adjustedShiftAmount, extractedByte))
            }
        }

        return int256(extractedValue);
    }

    /**
     * @dev Writes a range of bytes to the DNA value of a given token ID.
     * @param _tokenID The ID of the token.
     * @param inputValue The value to be written to the specified byte range.
     * @param startIndex The starting index of the byte range.
     * @param endIndex The ending index of the byte range.
     */ 
    function writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex) public onlyDnaModifier {
        _writeGen(_tokenID, inputValue, startIndex, endIndex); 
    }

    /**
     * @dev Writes a range of bytes to the DNA value of a given token ID.
     * Reverts if the specified range is invalid or the input value is too large.
     *
     * @param _tokenID The ID of the token.
     * @param inputValue The value to be written to the specified byte range.
     * @param startIndex The starting index of the byte range.
     * @param endIndex The ending index of the byte range.
     */
    function _writeGen(uint256 _tokenID, uint256 inputValue, uint8 startIndex, uint8 endIndex) internal {
        require(startIndex < endIndex && endIndex <= 32, "Invalid range");
        require(inputValue >= 0, "Only positive values are supported");

        uint256 maxInputValue = (1 << ((endIndex - startIndex) * 8)) - 1;
        require(uint256(inputValue) <= maxInputValue, "Input value is too large for the specified range");

        uint256 originalValue = indexDna[_tokenID];
        uint256 mask;
        uint256 updatedValue;

        for (uint8 i = startIndex; i < endIndex; i++) {
            assembly {
                let bytePos := sub(31, i) // Reverse the index since bytes are stored in big-endian
                let shiftAmount := mul(8, bytePos)

                // Prepare the mask for the current byte
                mask := or(mask, shl(shiftAmount, 0xff))

                // Prepare the updated value
                updatedValue := or(updatedValue, shl(shiftAmount, and(shr(mul(8, sub(i, startIndex)), inputValue), 0xff)))
            }
        }

        // Clear the bytes in the specified range of the original value, then store the updated value
        indexDna[_tokenID] = (originalValue & ~mask) | (updatedValue & mask);

        // Emit the BytesRangeModified event
        emit DnaModified(_tokenID, indexDna[_tokenID], inputValue, startIndex, endIndex);
    }

    /**
     * @dev Add or remove a role from an address.
     * @param role The role identifier (keccak256 hash of the role name).
     * @param addr The address for which the role will be granted or revoked.
     * @param enabled Flag to indicate if the role should be granted (true) or revoked (false).
     */
    function setRole(bytes32 role, address addr, bool enabled) public onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
        emit RoleChanged(addr, role, enabled);
    }

    /**
     * @dev Returns the timestamp of the last transfer for a given token ID.
     * Reverts if the token ID does not exist.
     *
     * @param tokenId The ID of the token.
     * @return The timestamp of the last transfer.
     */
    function getTransferDate(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return transferDates[tokenId];
    }
  
    // Internal functions //

    /**
     * @dev Returns the base URI for constructing token URIs.
     * @return The base URI.
     */
    function _baseURI() internal view override returns (string memory) { 
        return baseURI;
    }

    /**
     * @dev Internal function to set the DNA value for a given token ID.
     * @param _tokenID The ID of the token.
     * @param _dna The DNA value to be set.
     */
    function _setDna(uint256 _tokenID, uint256 _dna) internal {
        indexDna[_tokenID] = _dna;
        emit DnaChanged(_tokenID, _dna);
    }

    /**
     * @dev Hook that is called before any token transfer.
     * This includes minting and burning.
     * @param from The address tokens are being transferred from.
     * @param to The address tokens are being transferred to.
     * @param tokenId The ID of the token being transferred.
     * @param batchSize The number of tokens being transferred in a single batch.
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Hook that is called after any token transfer.
     * This includes minting and burning.
     * @param from The address tokens are being transferred from.
     * @param to The address tokens are being transferred to.
     * @param tokenId The ID of the token being transferred.
     * @param batchSize The number of tokens being transferred in a single batch.
     */
    function _afterTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721)
    {
        transferDates[tokenId] = block.timestamp;        

        super._afterTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Internal function to burn a specific token.
     * Reverts if the token does not exist.
     * @param tokenId The ID of the token being burned.
     */
    function _burn(uint256 tokenId) internal override (ERC721Royalty, ERC721) {
        super._burn(tokenId);
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding Solidity interface to learn more
     * about how these IDs are created.
     * @param interfaceId The interface identifier.
     * @return Whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721Royalty, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
