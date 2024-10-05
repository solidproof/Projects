// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract BYD_NFT is Ownable, ERC721Enumerable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    string public baseURI;
    mapping (address => bool) private operator;

    modifier onlyOperator {
        require(isOperator(msg.sender), "Only operator can perform this action");
        _;
    }

    constructor(string memory _name, string memory _symbol, string memory _newBaseURI) ERC721(_name, _symbol) {
        baseURI = _newBaseURI;
        operator[msg.sender] = true;
    }

    function airdrop(address _userAddress, uint _amount) external onlyOperator {
        require(_userAddress != address(0), "userAddress zero");
        require(_amount > 0, "empty amount");

        for(uint i=0; i<_amount; i++) {
            _mint(_userAddress, _tokenIdTracker.current()+1);   
            _tokenIdTracker.increment();
        }

        emit Airdrop(_userAddress, _amount);
    }

    function batchAirdrop(address[] memory _userAddressList, uint[] memory _amount) external onlyOperator {
        require(_userAddressList.length > 0, "empty userAddressList");
        require(_amount.length > 0, "empty amount");
        require(_userAddressList.length == _amount.length, "userAddressList and amount size mismatch");

        for(uint i=0; i<_userAddressList.length; i++) {
            for(uint j=0; j<_amount[i]; j++) {
                _mint(_userAddressList[i], _tokenIdTracker.current()+1);   
                _tokenIdTracker.increment();
            }
        }
        
        emit BatchAirdrop(_userAddressList, _amount);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;

        emit SetBaseURI(_newBaseURI);
    }

    function isOperator(address _userAddress) public view returns(bool) {
        return operator[_userAddress];
    }

    function setOperator(address _userAddress, bool _boolValue) external onlyOwner {
        require(_userAddress != address(0), "Address zero");
        operator[_userAddress] = _boolValue;

        emit SetOperator(_userAddress, _boolValue);
    }

    event Airdrop(address userAddressList, uint amount);
    event BatchAirdrop(address[] userAddressList, uint[] amount);
    event SetBaseURI(string newBaseURI);
    event SetOperator(address userAddress, bool boolValue);
}