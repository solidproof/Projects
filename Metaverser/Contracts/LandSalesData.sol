// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.12;
contract LandSalesData is Ownable {
    struct LandsInput{
        string assetId;
        uint8 assetType;
    }
    mapping(address => bool) private WhiteList;
    mapping(address => bool) private WhiteListRound2;
    mapping(string => bool ) private LandData ;
    LandsInput[] private MintData;
    
    constructor(){ }
    
    function addToWhiteList(address[] memory _whiteList,bool status) onlyOwner public {
        for(uint8 i;i < _whiteList.length;i++) {
            WhiteList[_whiteList[i]] = status ; 
        }
    }
    function addToWhiteList2(address[] memory _whiteList,bool status) onlyOwner public {
        for(uint8 i;i < _whiteList.length;i++) {
            WhiteListRound2[_whiteList[i]] = status ; 
        }
    }

    function addLands(LandsInput[] memory _data) public onlyOwner {
        for(uint256 i=0;i < _data.length ; i++  ) {
            if(!LandData[_data[i].assetId]){
                MintData.push(LandsInput(_data[i].assetId  , _data[i].assetType)) ;
                LandData[_data[i].assetId] = true;
            }
        }
    }
    function addLandsMethod2(string[] memory _data,uint8 _type) public onlyOwner {
        for(uint256 i=0;i < _data.length ; i++  ) {
            if(!LandData[_data[i]]){
                MintData.push(LandsInput(_data[i]  , _type)) ;
                LandData[_data[i]] = true;
            }
        }
    }
    function getAssetType(string memory assetId) public view returns(uint8) {
        uint8 _type = 128;
        for(uint256 i=0;i < MintData.length ; i++  ) {
            if(  keccak256(bytes( MintData[i].assetId)) ==  keccak256(bytes( assetId)) ) {
                _type = MintData[i].assetType;
            }
        }
        return _type;
    }

    function getWhitelist(address _user) public view returns(bool){
        return WhiteList[_user];
    }
    function getWhitelist2(address _user) public view returns(bool){
        return WhiteListRound2[_user];
    }

    function getFullMainData() public view  returns (LandsInput[] memory) {
        return MintData;
    }
    function getLandByIndex(uint256 index) public view  returns (LandsInput memory) {
        return MintData[index];
    }
    function getAssetIdIndex(uint256 index) public view  returns (string memory) {
        return MintData[index].assetId;
    }
    function getAssetTypeIndex(uint256 index) public view  returns (uint8) {
        return MintData[index].assetType;
    }

    function getMainDataLength() public view  returns(uint256) {
        return MintData.length;
    }
}
