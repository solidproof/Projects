// SPDX-License-Identifier: MIT
// https://ains.domains
pragma solidity ^0.8.20;

// Importing OpenZeppelin's standard implementations for ERC721, Ownable, and ERC2981
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import {StringUtils} from "./libraries/StringUtils.sol";
import {Base64} from "./libraries/Base64.sol";

// AINS contract declaration inheriting ERC721 for NFTs, Ownable for ownership, and ERC2981 for royalties
contract AINS is ERC721URIStorage, Ownable, ERC2981 {
    using Counters for Counters.Counter; // Counter utility for token IDs
    Counters.Counter private _tokenIds; // Internal counter for token IDs
    string public tld; // Top-level domain (TLD) managed by the contract

    // SVG parts for the NFT image, to be combined with domain names
    string svgPartOne = '<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg"> <defs> <linearGradient id="customGradient" x1="0%" y1="0%" x2="100%" y2="100%"> <stop offset="0%" style="stop-color:#FFA2FF; stop-opacity:1" /> <stop offset="50%" style="stop-color:#AE6CFF; stop-opacity:1" /> <stop offset="100%" style="stop-color:#8852FF; stop-opacity:1" /> </linearGradient> </defs> <rect width="300" height="300" fill="url(#customGradient)" /> <text x="50%" y="50%" fill="black" font-family="Arial" font-size="25" font-weight="bold" text-anchor="middle" dominant-baseline="middle">';
    string svgPartTwo = "</text></svg>";

    // Mappings for domain management
    mapping(string => address) public domains; // Domain name to owner address
    mapping(string => string) public records; // Domain name to additional records
    mapping(uint256 => string) public names; // Token ID to domain name
    mapping(address => string[]) private _ownedNames; // Owner address to list of owned domain names
    mapping(address => string) private _primaryDomain; // Owner address to primary domain name

    // Events for logging changes
    event DomainRegistered(address indexed owner, string name, uint256 tokenId);
    event PriceChanged(uint256 newPriceOneChar, uint256 newPriceTwoChar, uint256 newPriceThreeChar, uint256 newPriceFourSixChar, uint256 newPriceOthers);
    event RecordUpdated(string indexed name, string record);

    // Pricing based on the length of domain names
    uint256 public priceOneChar = 0; // Price for one-character domains
    uint256 public priceTwoChar = 0; // Price for two-character domains
    uint256 public priceThreeChar = 0; // Price for three-character domains
    uint256 public priceFourChar = 0; // Price for four-character domains
    uint256 public priceOthers = 0; // Price for all other domains


    // Constructor to initialize the contract with the specified top-level domain
    constructor(string memory _tld) payable ERC721("AI Name Service", "AINS") {
        tld = _tld; // Setting the top-level domain
        _setDefaultRoyalty(owner(), 500); // Setting a default royalty of 5%
    }

    // Function to allow domain owners to set their primary domain
    function setPrimaryDomain(string calldata name) external {
        require(domains[name] == msg.sender, "You do not own this domain");
        require(_ownedNames[msg.sender].length > 0, "You do not own any domains");
        _primaryDomain[msg.sender] = name;
    }

    // Function to get the primary domain of an owner
    function getPrimaryDomain(address _owner) external view returns (string memory) {
        return _primaryDomain[_owner];
    }

    // Override of ERC165's supportsInterface to include ERC2981
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to allow the contract owner to withdraw ETH
    function withdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance in contract");
        payable(owner()).transfer(amount);
    }

    // Function to set pricing for domain registration
    function setPrices(uint256 _priceOneChar, uint256 _priceTwoChar, uint256 _priceThreeChar, uint256 _priceFourChar, uint256 _priceOthers) external onlyOwner {
        priceOneChar = _priceOneChar;
        priceTwoChar = _priceTwoChar;
        priceThreeChar = _priceThreeChar;
        priceFourChar = _priceFourChar;
        priceOthers = _priceOthers;
        emit PriceChanged(_priceOneChar, _priceTwoChar, _priceThreeChar, _priceFourChar, _priceOthers);
    }
   

    // Function for registering a new domain
    function register(string calldata name) external payable {
        require(domains[name] == address(0), "Domain already registered");
        require(valid(name), "Invalid name");
        require(check(name), "Invalid characters in name");

        uint256 _price = price(name);
        require(msg.value >= _price, "Not enough ETH paid");

        string memory _name = string(abi.encodePacked(name, ".", tld));
        string memory finalSvg = string(abi.encodePacked(svgPartOne, _name, svgPartTwo));
        uint256 newRecordId = _tokenIds.current();
        string memory strLen = Strings.toString(bytes(name).length);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        _name,
                        '", "description": "AI Name Service - .ai Web3 Domains", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(finalSvg)),
                        '","length":"',
                        strLen,
                        '"}'
                    )
                )
            )
        );

        string memory finalTokenUri = string(abi.encodePacked("data:application/json;base64,", json));

        _safeMint(msg.sender, newRecordId);
        _setTokenURI(newRecordId, finalTokenUri);
        domains[name] = msg.sender;
        names[newRecordId] = name;
        _ownedNames[msg.sender].push(name);

        _tokenIds.increment();
        emit DomainRegistered(msg.sender, name, newRecordId);
    }



     // Function to calculate the price of a domain based on its length
     function price(string calldata name) public view returns (uint256) {
        uint256 len = StringUtils.strlen(name);
        require(len > 0 && len <= 50, "Invalid name length");
        if (len == 1) {
            return priceOneChar;
        } else if (len == 2) {
            return priceTwoChar;
        } else if (len == 3) {
            return priceThreeChar;
        } else if (len >= 4 && len <= 6) {
            return priceFourChar;
        } else {
            return priceOthers;
        }
    }
    
    // Function to allow a domain owner to set a record for their domain.
    function setRecord(string calldata name, string calldata record) external {
        require(domains[name] == msg.sender, "You do not own this domain");
        records[name] = record;
        emit RecordUpdated(name, record);
    }

    // Public function to reset the record of a domain.
    function resetRecord(string memory name) public {
    require(domains[name] == msg.sender, "Only domain owner can reset record");
    _resetRecord(name);
    }

    // External function to get the record associated with a domain name.
    function getRecord(string calldata name) external view returns (string memory) {
        return records[name];
    }

    // External function to get the count of domains owned by an address.
    function getOwnedDomainsCount(address _owner) external view returns (uint256) {
        return _ownedNames[_owner].length;
    }

    // External function to get a domain by the owner's address and an index.
    function getDomainByOwnerAndIndex(address _owner, uint256 index) external view returns (string memory) {
        require(index < _ownedNames[_owner].length, "Index out of bounds");
        return _ownedNames[_owner][index];
    }

    // Internal function to check the validity of a domain name.
    function valid(string calldata name) public pure returns (bool) {
        // Domain name must be between 1 and 50 characters.
        return StringUtils.strlen(name) >= 1 && StringUtils.strlen(name) <= 50;
    }

    // Internal function to check for invalid characters in a domain name.
    function check(string memory str) public pure returns (bool) {
        if (bytes(str).length > 50) return false;

        bytes memory strBytes = bytes(str);
        for (uint i = 0; i < strBytes.length; i++) {
            bytes1 charByte = strBytes[i];

            // Reject uppercase letters and ensure only alphanumeric and certain special characters are used.
            if (charByte >= 0x41 && charByte <= 0x5A) return false;
            if (!((charByte >= 0x61 && charByte <= 0x7A) || 
                  (charByte >= 0x30 && charByte <= 0x39) || 
                  (charByte == 0x24) || (charByte > 0x7F))) {
                return false;
            }
        }
        return true;
    }
        //override function
        function transferFrom(address from, address to, uint256 tokenId) public override {
            super.transferFrom(from, to, tokenId);
            _updateOwnedNames(from, to, tokenId);
            _resetPrimaryDomainIfTransferred(from, names[tokenId]);
            _resetRecord(names[tokenId]);
            string memory domainName = names[tokenId];
            domains[domainName] = to; // Update the domain's owner in the mapping
        }

        //override function
        function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
            super.safeTransferFrom(from, to, tokenId, _data);
            _updateOwnedNames(from, to, tokenId);
            _resetPrimaryDomainIfTransferred(from, names[tokenId]);
            _resetRecord(names[tokenId]);
            string memory domainName = names[tokenId];
            domains[domainName] = to; // Update the domain's owner in the mapping
        }

        function _resetRecord(string memory name) internal {
            if (domains[name] != address(0)) {
                records[name] = "";
                emit RecordUpdated(name, "");
            }
        }


    function _updateOwnedNames(address from, address to, uint256 tokenId) private {
    _removeName(from, names[tokenId]);
    _ownedNames[to].push(names[tokenId]);
    }

    //update owner
    function _removeName(address _owner, string memory nameToRemove) private {
        uint256 length = _ownedNames[_owner].length;
        for (uint256 i = 0; i < length; i++) {
            if (keccak256(bytes(_ownedNames[_owner][i])) == keccak256(bytes(nameToRemove))) {
                _ownedNames[_owner][i] = _ownedNames[_owner][length - 1];
                _ownedNames[_owner].pop();
                break;
            }
        }
    }
  
    //reset primary domain when transferred
    function _resetPrimaryDomainIfTransferred(address from, string memory name) private {
        if (keccak256(bytes(_primaryDomain[from])) == keccak256(bytes(name))) {
            _primaryDomain[from] = "";
        }
    }
    
    //fetch names by owner
    function getNamesByOwner(address _owner) public view returns (string[] memory) {
    return _ownedNames[_owner];
    }

    //fetch address with name
    function getAddress(string calldata name) public view returns (address) {
        return domains[name];
    }

    //fetch all names
    function getAllNames() public view returns (string[] memory) {
        string[] memory allNames = new string[](_tokenIds.current());
        for (uint256 i = 0; i < _tokenIds.current(); i++) {
            allNames[i] = names[i];
        }
        return allNames;
    }


    //check if name exists
    function nameExists(string calldata name) public view returns (bool) {
        return domains[name] != address(0);
    }




}