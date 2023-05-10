// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./ZoombiesUniverse.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Zoombies is ERC721, ERC721Burnable, ZoombiesUniverse {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string private _baseTokenURI;

    //Tracking affiliate sponsors
    mapping(address => address) public sponsors; // 1 sponsor have many affiliates, but only 1 sponsor, returns sponsor

    //Track the timestamps for users to get their daily pull
    mapping(address => uint256) private timeToCardsPull; //address to timestamp

    //Tracking booster pack count ownership. These are NOT tokens, Player can mint a random NFT
    mapping (address => uint256) public boosterCreditsOwned;
    mapping (address => bool) public authorizedContracts; // external service contracts to manage Diamond Mint
    mapping (address => uint256) public totalSacrificed; // total NFTs sacrificed by address
    uint public weiCostOfBooster = 1000000000000000000; //1 GLMR
    uint256 public zoomValuePerBoosterCredit = 500; // for mint, and reward
    uint16 public totalBoostersRewarded = 0;

    //Event Logs
    event LogCardMinted(address indexed buyer, uint tokenId, uint8 rarity, uint32 indexed cardTypeId, uint editionNumber, bool isFoil);
    event LogPackOpened(address indexed buyer, uint8 rarity);
    event LogSponsorLinked(address sponsor, address affiliate);
    event LogSponsorReward(address sponsor, address affiliate, uint zoomReward);
    event LogDailyReward(address player, uint newBoosterBalance);
    event LogRewardBoosters(address winner, uint boostersAwarded);
    event LogSacrificeNFT(address owner, uint256 tokenId, uint16 cardTypeId, uint256 zoomGained, uint256 totalSacrificed);
    event LogContractAuthorized(address newZoombiesService, bool isApproved);
    event LogCostOfBoosterUpdated(uint newCost);

    constructor(address _zoomTokenContract)
    ERC721("Zoombies", "Zoombie") {
        require(_zoomTokenContract != address(0x0));
        _baseTokenURI = "https://zoombies.world/nft/moonbeam/";
        zoomTokenContract = _zoomTokenContract;
    }

    function buyCard(uint16 _cardTypeId) external payable {
        require(allCardTypes[_cardTypeId].cardTypeId != 0, "Card type ID does not exist");
        require(allCardTypes[_cardTypeId].notStoreOrBonus == 0, "Only cards from store can be minted");
        require(block.timestamp >= storeReleaseTime[_cardTypeId], "Card not released from shop");
        require(allCardTypes[_cardTypeId].totalAvailable >= (cardTypeToEdition[_cardTypeId]+1),
        "All of these cards have been minted");
        require(msg.value >= allCardTypes[_cardTypeId].weiCost, "You have not paid enough GLMR to mint this type");

        if(msg.value < allCardTypes[_cardTypeId].weiCost*3) {
            require(cardTypesOwned[_msgSender()][_cardTypeId] == false, "You have already minted this type");
            if(isZoomScoreUnder(_msgSender(), allCardTypes[_cardTypeId].unlockZoom)) {
                revert("ZoomScore not enough to unlock price, use 3x FastPass");
            }
        } //they fast passed this block

        //Let the world award our friend
        awardZoom(_msgSender(), allCardTypes[_cardTypeId].buyZoom);
        //reward the sponsor
        rewardAffiliate(allCardTypes[_cardTypeId].buyZoom);

        //ALL CLEAR ???????? mint new card
        mintZoombieNFT(_cardTypeId);
    }

    function getFreeCard(uint16 _cardTypeId) external payable {
        require(allCardTypes[_cardTypeId].cardTypeId != 0, "Card type ID does not exist");
        require(allCardTypes[_cardTypeId].weiCost == 0, "You are attempting to mint a paid type");
        require(allCardTypes[_cardTypeId].notStoreOrBonus == 0, "Only cards from store can be minted");
        require(block.timestamp >= storeReleaseTime[_cardTypeId], "Card not released from shop");
        require(cardTypesOwned[_msgSender()][_cardTypeId] == false, "You have already minted this type");
        require(allCardTypes[_cardTypeId].totalAvailable >= (cardTypeToEdition[_cardTypeId]+1),
        "All of these cards have been minted");

        //Fast pass OR ZoomScore + Zoom burn to mint
        uint zoomCost = 3 * allCardTypes[_cardTypeId].unlockZoom * 1e18;
        zoomCost = zoomCost/100000;
         if(msg.value < zoomCost) { // fast pass check
            if(isZoomScoreUnder(_msgSender(), allCardTypes[_cardTypeId].unlockZoom)) {
                revert("ZoomScore too low");
            }else{                  // they unlocked by ZoomScore
                if(isZoomBalanceUnder(_msgSender(), allCardTypes[_cardTypeId].buyZoom)){                  
                    revert("Not enough ZOOM in wallet");
                }else{              // burn zoom to mint NFT
                    burnZoom(_msgSender(), allCardTypes[_cardTypeId].buyZoom);
                }
             }
        } // they fast passed this block

        //ALL CLEAR ???????? claim and mint new card
        mintZoombieNFT(_cardTypeId);       
    }

    function sacrificeNFTs(uint256[] memory _tokenIds) external {

        require(_tokenIds.length <= 256, "List of tokens to sacrifice must be less than 257 at a time");
        
        uint256 sacZoom = 0;
        for (uint i=0; i < _tokenIds.length; i++) {
            burn(_tokenIds[i]); //ensure owner before we roll other data

            uint16 _tempCTiD = nfts[_tokenIds[i]].cardTypeId;
            tokensByRarity[allCardTypes[_tempCTiD].rarity] -= 1;
            sacZoom += allCardTypes[_tempCTiD].sacrificeZoom;
            delete (nfts[_tokenIds[i]]);
            totalSacrificed[_msgSender()] += 1;
            emit LogSacrificeNFT(_msgSender(), _tokenIds[i], _tempCTiD, allCardTypes[_tempCTiD].sacrificeZoom, totalSacrificed[_msgSender()]);
        }
        awardZoom(_msgSender(), sacZoom);
        rewardAffiliate(sacZoom);
    }

    //every 8 hours, the address can get 1 free booster credit
    function getBonusBoosters() external {
        //require(block.timestamp >= getTimeToDailyBonus(_player), "Can't claim before time to claim next bonus");
        if(block.timestamp < getTimeToDailyBonus(_msgSender())){
            revert("Too early to claim next bonus");
        }

        //Stop re-entrancy, update the lastpull value
        timeToCardsPull[_msgSender()] = block.timestamp + 8 hours;

        // add the boosters and emit event
        boosterCreditsOwned[_msgSender()] += 1;
        emit LogDailyReward(_msgSender(), boosterCreditsOwned[_msgSender()]);
    }

    function linkMySponsor(address _mySponsor) external {
        //All clear?  stop re-entrancy, set the association
        sponsors[_msgSender()] = _mySponsor;

        //Mint the Platinum Sponsor Card
        bool tryAgain = true;
        uint256 _newTokenID;
        while (tryAgain) {
            _newTokenID = pullCard(2);
            if (_newTokenID > 0) { //got a card
                 tryAgain = false;
             }
        }

        emit LogSponsorLinked(_mySponsor, _msgSender());
    }

    function buyBoosterCredits(uint _amount) external payable returns(bool) {
        require(msg.value == (weiCostOfBooster * _amount), "Not enough GLMR to buy this many Booster Credits");

        //All good increase the number owned
        boosterCreditsOwned[_msgSender()] += _amount;


        //Award zoom for booster
        uint256 zoomBonus = zoomValuePerBoosterCredit + 200; //bonus for buying a booster
        awardZoom(_msgSender(), (zoomBonus * _amount));
        rewardAffiliate(zoomBonus * _amount);

        return true;
    }

    function buyBoosterAndMintNFT() external payable returns(bool) {
        require(msg.value == weiCostOfBooster, "Cost to buy and mint a Booster NFT is 0.1");

        //Award zoom per pack
        awardZoom(_msgSender(), zoomValuePerBoosterCredit + 200);   //bonus for buying a booster
        rewardAffiliate(zoomValuePerBoosterCredit + 200);           //bonus for buying a booster

        //Pull the card
        uint8 rarity = getRarity(0);
        bool tryAgain = true;
        uint256 _newTokenID;
        while (tryAgain) {
            _newTokenID = pullCard(rarity);
            if (_newTokenID > 0) { //got a card
                tryAgain = false;
            }
        }

        //Send a log event
        emit LogPackOpened(_msgSender(), rarity);
        return true;
    }

    function mintBoosterNFT(uint zoomWager) external returns(bool) {
        require(boosterCreditsOwned[_msgSender()] > 0, "No Booster credits owned");
        require(zoomWager == 0 || zoomWager >= 1000000 && zoomWager <= 20000000, "Wager must be 0 or between than 1-20M");
        //STOP re-entrancy , decrement number of credits
        boosterCreditsOwned[_msgSender()] -= 1;

        // we don't check above here for balance, this will die if no ZOOM
        burnZoom(_msgSender(), zoomValuePerBoosterCredit); //ether units

        //Pull the card
        uint8 rarity = getRarity(zoomWager);
        bool tryAgain = true;
        uint256 _newTokenID;
        while (tryAgain) {
            _newTokenID = pullCard(rarity);
            if (_newTokenID > 0) { //got a card
                tryAgain = false;
            }
        }
        //Send a log event
        emit LogPackOpened(_msgSender(), rarity);
        return true;
    }

    function awardBoosterCredits(address _winner, uint8 _amount) external onlyOwner returns(bool) {

        totalBoostersRewarded += _amount;
        boosterCreditsOwned[_winner] += _amount;
        emit LogRewardBoosters(_winner, _amount);
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getTimeToDailyBonus(address _player) public view returns(uint256 timeStamp) {

        //check if address exists
        if (timeToCardsPull[_player] == 0) {
            return block.timestamp - 2 seconds;
        }else {
            return timeToCardsPull[_player];
        }
    }

    function mintDiamond(address _receiverWallet) external {
        require(authorizedContracts[_msgSender()] == true, "Not authorized to mint");    
         bool tryAgain = true;
         uint256 _newTokenID;
         while (tryAgain) {
             _newTokenID = pullCard(1);
             if (_newTokenID > 0) { //got a card
                 tryAgain = false;
             }
         }       
         //give to the player
         _transfer(_msgSender(), _receiverWallet, _newTokenID);
         emit LogPackOpened(_receiverWallet, 1);
    }

    /**
     * Withdraw balance to wallet
     */
    function withdraw() public onlyOwner returns(bool) {
        payable(_msgSender()).transfer(address(this).balance);
        return true;
    }
    
    function setAuthorizedContract(address _newZoombiesService, bool _isAuthorized) external onlyOwner {
        require(_newZoombiesService != address(0x0));
        authorizedContracts[_newZoombiesService] = _isAuthorized;
        emit LogContractAuthorized(_newZoombiesService, _isAuthorized);
    }

    function updateCostOfBooster(uint _newWeiCost) external onlyOwner {
        require(_newWeiCost > 0);
        weiCostOfBooster = _newWeiCost;
        emit LogCostOfBoosterUpdated(_newWeiCost);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

//Private

    // balance is lower than test, return true
    function isZoomBalanceNotEnough(uint256 _valueToTest) private returns (bool) {
        if(ZoomToken(zoomTokenContract).balanceOf(_msgSender()) < _valueToTest){
            return true;
        }
        return false;
    }

    function pullCard(uint8 _rarity) private returns (uint256 newTokenId) { 
        //Get a random number for the card to pull
        uint256 rand = selectRandom(allBoosterCardIds[_rarity].length); 
        //hit up the cardTypes
        uint16 _pulledId = allBoosterCardIds[_rarity][rand];
        if
            (allCardTypes[_pulledId].totalAvailable > 0 && //test for limited edition boosters
            (cardTypeToEdition[_pulledId]+1) > allCardTypes[_pulledId].totalAvailable) {
                return 0;
            }

        //Give the player this cardType
        uint256 _newTokenID = mintZoombieNFT(_pulledId);
        return _newTokenID;
    }

    function mintZoombieNFT(uint16 _cardTypeId) private returns(uint256 newTokenId){
        //Stop re-entrancy, Track the type of card puchased for this owner, so they cant buy again
        cardTypesOwned[_msgSender()][_cardTypeId] = true;

        cardTypeToEdition[_cardTypeId] += 1;

        _tokenIdCounter.increment();
        uint256 _newTokenId = _tokenIdCounter.current();

        //now mint the NFT
        _safeMint(_msgSender(), _newTokenId);

        bool isThisFoil = false;
        uint256 rand = selectRandom(12);
        if(rand == 1) {
            isThisFoil = true;
        }

        //Create the NFT data on chain!
        NFTdata memory _tempCard = NFTdata({
            cardTypeId:_cardTypeId,
            editionNumber:cardTypeToEdition[_cardTypeId],
            isFoil:isThisFoil
        });
        nfts[_newTokenId] = _tempCard;

        tokensByRarity[allCardTypes[_cardTypeId].rarity] += 1;

        emit LogCardMinted(_msgSender(), _newTokenId, allCardTypes[_cardTypeId].rarity, _tempCard.cardTypeId, _tempCard.editionNumber, isThisFoil);
        return _newTokenId;
    }

    /**
     * We always pay our affiliates 20% of the zoom commission
     */
    function rewardAffiliate(uint _totalZoom) private {
        //first check if the caller has a sponsor
        if (sponsors[_msgSender()] != address(0)) {
            uint reward = _totalZoom / 5;
            if (reward == 0) {
                reward = 1;
            }
            awardZoom(sponsors[_msgSender()], reward);
            emit LogSponsorReward(sponsors[_msgSender()], _msgSender(), reward);
        }
    }
}
