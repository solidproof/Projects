// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ZoomToken.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ZoombiesUniverse is ERC721Enumerable, Ownable, Pausable {

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    struct CardType {
        uint16 cardTypeId;
        string name;
        string set;
        uint8 assetType; //1=human,2=animal,3=plant, 4=thing
        uint8 notStoreOrBonus; //0 =inStore, 1 = pack, 2= bonus
        uint8 rarity; //1 = diamond,6 = common
        uint16 totalAvailable;
        uint256 weiCost;
        uint256 buyZoom;
        uint256 sacrificeZoom;
        uint256 unlockZoom;
        uint8 cardLevel;
    }

    struct NFTdata {
        uint16 cardTypeId;
        uint256 editionNumber;
        bool isFoil;
    }

    address public zoomTokenContract;

    mapping(uint16 => CardType) public allCardTypes;        // All card type definitions
    //where we hold inventory of the  booster packs
    mapping(uint8 => uint16[]) public allBoosterCardIds;   // [rarityId][]
    uint16 public totalCardTypes = 0;
    mapping(uint16 => uint256) public storeReleaseTime;

    //Track all tokens by rarity
    uint[7] public tokensByRarity = [0, 0, 0, 0, 0, 0, 0]; //[rarity] = total
    // Track ownership of Card Type purchases from store to enforce 1 type per person
    mapping (address => mapping(uint16 => bool)) public cardTypesOwned; //    [address][CardTypeId] = bool
    //track editionNumberTotal, always increments, starts at 1
    mapping(uint16 => uint256) public cardTypeToEdition;
    mapping(uint256 => NFTdata) public nfts;

    event LogCardTypeLoaded(uint32 indexed cardTypeId, string cardName, uint editionTotal);

    function loadNewCardType(
    uint16 _cardTypeId,
    string memory _name,
    string memory _set,
    uint8 _assetType,        // 1 = human, 2 = animal, 3 = plant, 4 = thing
    uint8 _notStoreOrBonus,  // 0 = inStore, 1 = booster, 2 = bonus
    uint8 _rarity,           // 1 = diamond, 6 = common
    uint16 _totalAvailable,
    uint256 _weiCost,
    uint256 _buyZoom,
    uint256 _sacrificeZoom,
    uint256 _unlockZoom,
    uint8 _cardLevel
    ) external onlyOwner {

        require(allCardTypes[_cardTypeId].cardTypeId == 0, "Not allowed to update an existing cardType definiton");

        if (_notStoreOrBonus == 0 && _totalAvailable < 1) {
            revert("In store types must be limited edition");
        }

        if (_notStoreOrBonus == 0 && _buyZoom == 0) {
            revert("In store types must have buyZoom value");
        }

        if (_notStoreOrBonus == 0 && _unlockZoom == 0) {
            revert("In store types must have UnlockZoom value");
        }

        if (_notStoreOrBonus > 0 && _weiCost > 0) {
            revert("Booster/Bonus may NOT have a cost");
        }

        allCardTypes[_cardTypeId].cardTypeId = _cardTypeId;
        allCardTypes[_cardTypeId].name = _name;
        allCardTypes[_cardTypeId].set = _set;
        allCardTypes[_cardTypeId].assetType = _assetType;
        allCardTypes[_cardTypeId].notStoreOrBonus = _notStoreOrBonus;
        allCardTypes[_cardTypeId].rarity = _rarity;
        allCardTypes[_cardTypeId].totalAvailable = _totalAvailable;
        allCardTypes[_cardTypeId].weiCost = _weiCost;
        allCardTypes[_cardTypeId].buyZoom = _buyZoom;
        allCardTypes[_cardTypeId].sacrificeZoom = _sacrificeZoom;
        allCardTypes[_cardTypeId].unlockZoom = _unlockZoom;
        allCardTypes[_cardTypeId].cardLevel = _cardLevel;

        //Track total card types
        totalCardTypes++;

        if (_notStoreOrBonus > 0) {
            allBoosterCardIds[_rarity].push(_cardTypeId);
            storeReleaseTime[_cardTypeId] = block.timestamp;
        }

        if (_notStoreOrBonus == 0) {  //store only
            storeReleaseTime[_cardTypeId] = block.timestamp + 10 minutes;
        }

        emit LogCardTypeLoaded(_cardTypeId, _name, _totalAvailable);
    }

    function setStoreRelease(uint16 _cardTypeId, uint _hoursFromNow) external onlyOwner {
        require(allCardTypes[_cardTypeId].cardTypeId == _cardTypeId, "This cardTypeId is not defined yet");
        require(_hoursFromNow >= 0 && _hoursFromNow <= 2190,
        "hoursFromNow must be a positive number and less than 2190");
        require(storeReleaseTime[_cardTypeId] >= block.timestamp, "Can only change release times on Unreleased cards");
        storeReleaseTime[_cardTypeId] = block.timestamp + (_hoursFromNow * 1 hours);
    }

    //Get total tokens by rarity. diamond,platinum,epic,rare,uncommon,common
    function getTokensByRarity() external view returns(uint, uint, uint, uint, uint, uint) {
        return(
           tokensByRarity[1], tokensByRarity[2], tokensByRarity[3], tokensByRarity[4], tokensByRarity[5], tokensByRarity[6]
        );
    }

     //Get the info about the NFT
    function getNFTData(uint256 _tokenId) public view returns(uint16, uint, bool) {
        require(_exists(_tokenId));
        return (nfts[_tokenId].cardTypeId, nfts[_tokenId].editionNumber, nfts[_tokenId].isFoil);
    }

//All the internal calls
   /**
    *  Internal function called from Zoombies once all the checks are done
    */
    function awardZoom(address _beneficiary, uint _zoomReward) internal {
        //Give the zoom tokens
      
        ZoomToken(zoomTokenContract).awardZoom(_beneficiary, _zoomReward * 1e18);
    }

    function burnZoom(address _spender, uint _zoomCost) internal {
        //Burn the zoom tokens     
        ZoomToken(zoomTokenContract).burnZoom(_spender, _zoomCost * 1e18);
    }

    function isZoomScoreUnder(address _player, uint256 _zoomValue) internal returns(bool) {
        _zoomValue = _zoomValue * 1e18;//convert to wei
        if(_zoomValue > ZoomToken(zoomTokenContract).zoomScore(_player)) {
            return true;
        }
        return false;
    }

    function isZoomBalanceUnder(address _player, uint256 _zoomValue) internal returns(bool) {
        _zoomValue = _zoomValue * 1e18;//convert to wei
        if(_zoomValue > ZoomToken(zoomTokenContract).balanceOf(_player)) {
            return true;
        }
        return false;
    }


   /**
    * Random as it gets for now. Return a val between 1-10000
    */
    uint256 private nonce = 5;

    function selectRandom(uint256 range) internal returns (uint) {
        uint randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, _msgSender(), nonce))) % range;
        nonce++;
        return randomnumber;
    }

    function getRarity(uint zoomWager) internal returns(uint8) {

        //Check if below upper limit
        require(zoomWager <= 20000000, "You must wager less than the upper limit of 20M");

        zoomWager = zoomWager * 1e18;
        //FIRST ensure, player can back their wager
        uint _playerZOOMBalance = ZoomToken(zoomTokenContract).balanceOf(_msgSender());
        require(_playerZOOMBalance >= zoomWager, "You do Not have enough ZOOM for this wager");

        //Check effects - Take their zoom
        if (zoomWager > 0) {
            ZoomToken(zoomTokenContract).burnZoom(_msgSender(), zoomWager);
        }

        //ALL CLEAR - grab a random number
        uint rand = selectRandom(10000);

        //get our probabilty distribution
        uint[7] memory probs = burnAndBoost(zoomWager);

        //Get the rarity for this pull from the probs
        // 3=epic, 4=rare, 5=uncommon, 6=commmon
        for (uint8 i=2; i < probs.length; i++) {
            if (rand <= probs[i]) {
                return i;
            }
        }
        return 6;
    }


    uint[7] public baseProbability = [0, 0, 0, 1, 500, 3500, 10000];

    event Probs(uint epic, uint rare, uint uncommon, uint common);

    function getProbs(uint wager) public returns (uint c, uint u, uint r, uint e) {

      wager = wager / 1e18;
       e = baseProbability[3] + (wager / 20000);
       r = e + baseProbability[4] + (wager / 5500);
       u = r + baseProbability[5] + (wager / 8000);
       c = u + 10000;

      emit Probs(e, r, u, c);
      return (c, u, r, e);
    }


    function burnAndBoost(uint zoomWager) public returns(uint[7] memory) {

       //buyBoosterCardAndOpen will pass a zero, return default
        if (zoomWager == 0) {
            return baseProbability; //[0, 0, 0, 1, 500, 3500, 10000];
        }

        (uint c, uint u, uint r, uint e) = getProbs(zoomWager);

        //default distribution is 1,500,3500,10000
        uint[7] memory probs = [0, 0, 0, e, r, u, c];

        return probs;
    }
}
