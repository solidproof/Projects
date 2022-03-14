// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./ZenCats.sol";


contract ZenCatsEvolve is Ownable {
    using Strings for string;
    address public nftAddress;
    struct NFTInfo{
        uint tokenId;
        uint256  time;
        uint baseLevel;
    }

    struct _NFTInfo{
        uint tokenId;
        bool isStaked;
        uint256  time;
        uint256  xp;
        uint baseLevel;
        uint levelAfterEvolve;
        bool canLevelUp;
    }
    constructor(address _nftAddress) {
        nftAddress = _nftAddress;
    }
    event Staked(address _owner,  uint _tokenId);
    event UnStaked(address _owner,  uint _tokenId);
    event Evolve(address _owner,  uint _tokenId);
    mapping(address => NFTInfo[]) stakedNFT;

    function getTime() internal virtual view returns (uint256) {
        return block.timestamp;
    }

    function isStaked(uint _tokenId) public view returns (bool)
    {
        NFTInfo[] memory nfts = stakedNFT[msg.sender];
        for (uint256 index = 0; index < nfts.length; index++) {
            if (nfts[index].tokenId == _tokenId)
                return true;
        }
        return false;
    }
    function canStake(uint _tokenId) view public returns(bool)
    {
        ZenCats zencatContract = ZenCats(nftAddress);
        bool cond1 = zencatContract.ownerOf(_tokenId) == msg.sender;
        bool cond2 = isStaked(_tokenId) == false;
        uint tokenLevel = zencatContract.tokenLevel(_tokenId);
        bool cond3 = tokenLevel < 2;
        return cond1 && cond2 && cond3;
    }
    function canStakeMultiple(uint[] calldata _tokenIds) view public returns(bool[] memory)
    {
        bool[] memory values = new bool[](_tokenIds.length);
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            values[index] = canStake(_tokenIds[index]);
        }
        return values;
    }
    function stake(uint _tokenId)  public {
        ZenCats zencatContract = ZenCats(nftAddress);
        require(zencatContract.ownerOf(_tokenId) == msg.sender,"You Are Not The Owner");
        require(isStaked(_tokenId) == false,"You Can not Re-Stake");
        uint tokenLevel = zencatContract.tokenLevel(_tokenId);
        require(tokenLevel < 2 ,"You Can not stake a level 3");
        stakedNFT[msg.sender].push(NFTInfo(_tokenId,getTime(),tokenLevel));
        emit Staked(msg.sender,_tokenId);
    }
    
    function stakeMultiple(uint[] calldata _tokenIds)  public {
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            stake(_tokenIds[index]);
        }
    }


    function unstake(uint _tokenId) public 
    {
        ZenCats zencatContract = ZenCats(nftAddress);
        require(zencatContract.ownerOf(_tokenId) == msg.sender,"You Are Not The Owner");

        NFTInfo[] storage nfts = stakedNFT[msg.sender];
        for (uint256 index = 0; index < nfts.length; index++) {
            if (nfts[index].tokenId == _tokenId)
            {
                nfts[index] = nfts[nfts.length-1];
                nfts.pop();
                emit UnStaked(msg.sender,_tokenId);
                return;
            }
        }
    }
    function evolveMultiple(uint[] calldata _tokenIds)  public {
        for (uint256 index = 0; index < _tokenIds.length; index++) {
            evolve(_tokenIds[index]);
        }
    }
    function canEvolve(uint _tokenId) public view returns(bool,uint)
    {
        ZenCats zencatContract = ZenCats(nftAddress);
        uint xp = getNFTXP(_tokenId);
        uint levelUp = xp/5;
        uint tokenLevel = zencatContract.tokenLevel(_tokenId);
        return (levelUp > 0 && tokenLevel + levelUp <= 2 , Math.min(2,tokenLevel + levelUp) );
    }
    function evolve(uint _tokenId) public{
        ZenCats zencatContract = ZenCats(nftAddress);
        require(zencatContract.ownerOf(_tokenId) == msg.sender,"You Are Not The Owner");
        uint xp = getNFTXP(_tokenId);
        uint levelUp = xp/5;
        uint tokenLevel = zencatContract.tokenLevel(_tokenId);
        if(levelUp > 0 && tokenLevel + levelUp <= 2)
        {

            zencatContract.mintTo(msg.sender,tokenLevel + levelUp);
            unstake(_tokenId);
            zencatContract.burn(_tokenId);
            emit Evolve(msg.sender,_tokenId);
        }
    }
    function evolveZenMasterMultiple(uint[] calldata _tokenIds)  public {
        require(_tokenIds.length % 2 == 0,"Size need to be multiples of 2");
        for (uint256 index = 0; index < _tokenIds.length; index+=2) {
            evolveZenMaster(_tokenIds[index],_tokenIds[index+1]);
        }
    }
    function evolveZenMaster(uint _tokenId1,uint _tokenId2) public{
        ZenCats zencatContract = ZenCats(nftAddress);
        require(zencatContract.ownerOf(_tokenId1) == msg.sender,"You Are Not The Owner");
        require(zencatContract.ownerOf(_tokenId2) == msg.sender,"You Are Not The Owner");
        uint xp1 = getNFTXP(_tokenId1);
        uint levelUp1 = xp1/5;
        uint token1Level = zencatContract.tokenLevel(_tokenId1) + levelUp1;
        uint xp2 = getNFTXP(_tokenId2);
        uint levelUp2 = xp2/5;
        uint token2Level = zencatContract.tokenLevel(_tokenId1) + levelUp2;
        if(token1Level >= 2 && token2Level >= 2)
        {
            zencatContract.mintTo(msg.sender,3);
            unstake(_tokenId1);
            zencatContract.burn(_tokenId1);
            unstake(_tokenId2);
            zencatContract.burn(_tokenId2);
            emit Evolve(msg.sender,_tokenId1);
            emit Evolve(msg.sender,_tokenId2);
        }
    }


    function getNFTInfo(uint _tokenId) public  view returns (_NFTInfo memory){
        ZenCats zencatContract = ZenCats(nftAddress);
        NFTInfo[] memory nfts = stakedNFT[msg.sender];
        NFTInfo memory info;
        for (uint256 index = 0; index < nfts.length; index++) {
            if (nfts[index].tokenId == _tokenId)
            {
                info = nfts[index];
                bool _canEvolve;
                uint _evolveLevel;  
                (_canEvolve, _evolveLevel) = canEvolve(info.tokenId);
                return _NFTInfo(info.tokenId,true,info.time,(getTime() - info.time) / 1 days ,info.baseLevel,_evolveLevel,_canEvolve );
            }
                
        }
        return _NFTInfo(_tokenId,false,0,0,zencatContract.tokenLevel(_tokenId),0,false);
    }
    function getNFTXP(uint _tokenId) public  view returns (uint){
        NFTInfo[] memory nfts = stakedNFT[msg.sender];
        NFTInfo memory info;
        for (uint256 index = 0; index < nfts.length; index++) {
            if (nfts[index].tokenId == _tokenId)
            {
                info = nfts[index];
                return (getTime() - info.time) / 1 days;
            }
                
        }
        return 0;
    }
    function getAllNFTStatus() public  view returns (_NFTInfo[] memory){
        ZenCats zencatContract = ZenCats(nftAddress);
        uint balance  = zencatContract.balanceOf(msg.sender);
        _NFTInfo[] memory _nfts = new _NFTInfo[](balance);
        
        for (uint256 index = 0; index < balance; index++) {
            uint token = zencatContract.tokenOfOwnerByIndex(msg.sender, index);
            _nfts[index] = getNFTInfo(token); 
        }
        return _nfts;
    }
}