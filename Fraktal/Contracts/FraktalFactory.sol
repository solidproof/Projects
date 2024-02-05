//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './FraktalNFT.sol';
import '@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol';
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FraktalFactory is Initializable,OwnableUpgradeable, ERC1155HolderUpgradeable, ERC721HolderUpgradeable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    address public Fraktalimplementation;
    address public revenueChannelImplementation;
    EnumerableMap.UintToAddressMap private fraktalNFTs;
    struct ERC721Imported {
      address tokenAddress;
      uint256 tokenIndex;
    }
    struct ERC1155Imported {
      address tokenAddress;
      uint256 tokenIndex;
    }
    mapping(address => ERC721Imported) public lockedERC721s;
    mapping(address => ERC1155Imported) public lockedERC1155s;

    event Minted(address creator,string urlIpfs,address tokenAddress,uint256 nftId);
    event ERC721Locked(address locker, address tokenAddress, address fraktal, uint256 tokenId);
    event ERC721UnLocked(address owner, uint256 tokenId, address collateralNft, uint256 index);
    event ERC1155Locked(address locker, address tokenAddress, address fraktal, uint256 tokenId);
    event ERC1155UnLocked(address owner, address tokenAddress, address collateralNft, uint256 index);
    event RevenuesProtocolUpgraded(address _newAddress);
    event FraktalProtocolUpgraded(address _newAddress);

    // constructor(address _implementation, address _revenueChannelImplementation) {
    //     Fraktalimplementation = _implementation;
    //     revenueChannelImplementation = _revenueChannelImplementation;
    // }

    function initialize(address _implementation, address _revenueChannelImplementation) public initializer {
        Fraktalimplementation = _implementation;
        revenueChannelImplementation = _revenueChannelImplementation;
    }

// Admin Functions
//////////////////////////////////
    function setFraktalImplementation(address _newAddress) external onlyOwner {
      Fraktalimplementation = _newAddress;
      emit FraktalProtocolUpgraded(_newAddress);
    }
    function setRevenueImplementation(address _newAddress) external onlyOwner {
      revenueChannelImplementation = _newAddress;
      emit RevenuesProtocolUpgraded(_newAddress);
    }

// Users Functions
//////////////////////////////////
    function mint(string memory urlIpfs, uint16 majority, string memory _name, string memory _symbol) public returns (address _clone) {
      _clone = ClonesUpgradeable.clone(Fraktalimplementation);
      FraktalNFT(_clone).init(_msgSender(), revenueChannelImplementation, urlIpfs, majority,_name,_symbol);
      uint256 index = fraktalNFTs.length();
      fraktalNFTs.set(index, _clone);
      emit Minted(_msgSender(), urlIpfs, _clone,index);
    }

    function importERC721(address _tokenAddress, uint256 _tokenId, uint16 majority) external returns (address _clone) {
      string memory uri = ERC721Upgradeable(_tokenAddress).tokenURI(_tokenId);
      string memory name = ERC721Upgradeable(_tokenAddress).name();
      string memory symbol = ERC721Upgradeable(_tokenAddress).symbol();
      name = string(abi.encodePacked("FraktalNFT(",name,")"));
      symbol = string(abi.encodePacked("F",symbol,"#",uint2str(_tokenId)));
      _clone = this.mint(uri, majority, name, symbol);
      ERC721Imported memory nft = ERC721Imported({
        tokenAddress: _tokenAddress,
        tokenIndex: _tokenId
        });
      ERC721Upgradeable(_tokenAddress).transferFrom(_msgSender(), _clone, _tokenId);
      // ERC721Upgradeable(_tokenAddress).transferFrom(_msgSender(), address(this), _tokenId);
      FraktalNFT(_clone).setCollateral(_tokenAddress);
      lockedERC721s[_clone] = nft;
      FraktalNFT(_clone).safeTransferFrom(address(this), _msgSender(), 0, 1, '');
      emit ERC721Locked(_msgSender(), _tokenAddress, _clone, _tokenId);
    }
    function importERC1155(address _tokenAddress, uint256 _tokenId, uint16 majority) external returns (address _clone) {
      string memory uri = ERC1155Upgradeable(_tokenAddress).uri(_tokenId);
      _clone = this.mint(uri, majority,"","");
      ERC1155Imported memory nft = ERC1155Imported({
        tokenAddress: _tokenAddress,
        tokenIndex: _tokenId
        });
      ERC1155Upgradeable(_tokenAddress).safeTransferFrom(_msgSender(), _clone, _tokenId, 1, '');
      // ERC1155Upgradeable(_tokenAddress).safeTransferFrom(_msgSender(), address(this), _tokenId, 1, '');
      FraktalNFT(_clone).setCollateral(_tokenAddress);
      lockedERC1155s[_clone] = nft;
      FraktalNFT(_clone).safeTransferFrom(address(this), _msgSender(), 0, 1, '');
      emit ERC1155Locked(_msgSender(), _tokenAddress, _clone, _tokenId);
    }
    function claimERC721(uint256 _tokenId) external {
      address fraktalAddress = fraktalNFTs.get(_tokenId);
      ERC721Imported storage collateralNft = lockedERC721s[fraktalAddress];
      address abandonedFraktal = collateralNft.tokenAddress;
      uint256 abandonedIndex = collateralNft.tokenIndex;
      FraktalNFT(fraktalAddress).safeTransferFrom(_msgSender(), address(this),0,1,'');
      FraktalNFT(fraktalAddress).claimContainedERC721(abandonedFraktal,abandonedIndex);
      ERC721Upgradeable(collateralNft.tokenAddress).transferFrom(address(this), _msgSender(), collateralNft.tokenIndex);
      fraktalNFTs.set(_tokenId, address(0));
      lockedERC721s[fraktalAddress] = ERC721Imported(address(0),0);
      emit ERC721UnLocked(_msgSender(), _tokenId, abandonedFraktal, abandonedIndex);
    }
    function claimERC1155(uint256 _tokenId) external {
      address fraktalAddress = fraktalNFTs.get(_tokenId);
      ERC1155Imported storage collateralNft = lockedERC1155s[fraktalAddress];
      address abandonedFraktal = collateralNft.tokenAddress;
      uint256 abandonedIndex = collateralNft.tokenIndex;
      FraktalNFT(fraktalAddress).safeTransferFrom(_msgSender(), address(this),0,1,'');
      uint256 balance = ERC1155Upgradeable(collateralNft.tokenAddress).balanceOf(fraktalAddress, abandonedIndex);
      FraktalNFT(fraktalAddress).claimContainedERC1155(abandonedFraktal,abandonedIndex,balance);
      ERC1155Upgradeable(collateralNft.tokenAddress).safeTransferFrom(address(this), _msgSender(), collateralNft.tokenIndex,balance,'');
      fraktalNFTs.set(_tokenId, address(0));
      lockedERC1155s[fraktalAddress] = ERC1155Imported(address(0),0);
      emit ERC1155UnLocked(_msgSender(), fraktalAddress, abandonedFraktal, abandonedIndex);
    }

// GETTERS
//////////////////////////////////
    function getFraktalAddress(uint256 _tokenId) public view returns(address){
      return address(fraktalNFTs.get(_tokenId));
    }
    function getERC721Collateral(address fraktalAddress) public view returns(address){
      return(lockedERC721s[fraktalAddress].tokenAddress);
    }
    function getERC1155Collateral(address fraktalAddress) public view returns(address){
      return(lockedERC1155s[fraktalAddress].tokenAddress);
    }
    function getFraktalsLength() public view returns(uint256){
      return(fraktalNFTs.length());
    }


    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

// Helpers
//////////////////////////
