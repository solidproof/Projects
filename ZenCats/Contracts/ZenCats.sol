// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 * @title Creature
 * Creature - a contract for my non-fungible creatures.
 */
contract ZenCats is ERC721,ERC721Enumerable,Ownable,AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    bytes32 public constant ASSOCIATE_CONTRACT_ROLE = keccak256("ASSOCIATE_CONTRACT_ROLE");
    Counters.Counter internal _nextTokenIdLevel0;
    Counters.Counter internal _nextTokenIdLevel1;
    Counters.Counter internal _nextTokenIdLevel2;
    Counters.Counter internal _nextTokenIdLevel3;


    uint _baseLevel0 = 0;
    uint _baseLevel1 = 10000;
    uint _baseLevel2 = 20000;
    uint _baseLevel3 = 30000;
    function allow_contract(address addr) public onlyOwner {
        _grantRole(ASSOCIATE_CONTRACT_ROLE,addr);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // function totalSupply() public view returns (uint256) {
    //     return _nextTokenIdLevel0.current() + 
    //     _nextTokenIdLevel1.current() +
    //     _nextTokenIdLevel2.current()  - 3;
    // }

    function tokenLevel(uint _tokenId) public view returns (uint256) 
    {
        if (_tokenId > _baseLevel0 && _tokenId < _baseLevel1)
            return 0; 
        if (_tokenId > _baseLevel1 && _tokenId < _baseLevel2)
            return 1; 
        if (_tokenId > _baseLevel2 && _tokenId < _baseLevel3)
            return 2; 
        return 3;
         
    }
    function mintTo(address _to,uint level) external  {
        require(hasRole(ASSOCIATE_CONTRACT_ROLE,_msgSender()) || owner() == _msgSender() , "DOES_NOT_HAVE_PERMISSION");
        require(0 <= level &&  level <= 3, "invalid level");
        // TODO: check level boundries
        uint256 currentTokenId = 0;
        if (level == 0)
        {
            currentTokenId =_baseLevel0 +  _nextTokenIdLevel0.current();
            _nextTokenIdLevel0.increment();
        } else if(level == 1)
        {
            currentTokenId =_baseLevel1 +  _nextTokenIdLevel1.current();
            _nextTokenIdLevel1.increment();   
        } else if(level == 2)
        {
            currentTokenId = _baseLevel2 + _nextTokenIdLevel2.current();
            _nextTokenIdLevel2.increment();   
        }else if(level == 3)
        {
            currentTokenId = _baseLevel3 + _nextTokenIdLevel3.current();
            _nextTokenIdLevel3.increment();   
        }
        _safeMint(_to, currentTokenId);
    }

    function burn(uint256 tokenId) external
    {
        require(hasRole(ASSOCIATE_CONTRACT_ROLE,_msgSender()) || owner() == _msgSender() , "DOES_NOT_HAVE_PERMISSION");
        _burn(tokenId);
    }


    constructor()
        ERC721("ZenCats", "ZCT")
        
    {
        _nextTokenIdLevel0.increment();
        _nextTokenIdLevel1.increment();
        _nextTokenIdLevel2.increment();
        _nextTokenIdLevel3.increment();
    }
    
    function tokenURI(uint256 _tokenId) override public pure returns (string memory) {
        return string(abi.encodePacked(baseTokenURI(), Strings.toString(_tokenId)));
    }

    function baseTokenURI()  public pure returns (string memory) {
        return "https://dev.zencats.io/api/cats/";
    }


    function contractURI() public pure returns (string memory) {
        return "https://dev.zencats.io/contract/zencats";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721,ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // function _msgSender()
    //     internal
    //     override(Context,ERC721Tradable)
    //     view
    //     returns (address sender)
    // {
    //     return ERC721Tradable._msgSender();
    // }
}