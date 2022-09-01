// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "./LandSalesData.sol"; 
import "./MarketplaceAssets.sol" ;

contract LandSale2 is Ownable,ERC721Holder  {

    struct LandsInput{
        string assetId;
        uint256 assetType;
    }
    struct BuyerStruct{
        uint256 round;

    }
   MarketplaceAssets public MarketAddress  ;
   LandSalesData public LandDataAddress;

   mapping(address => bool) private WhiteList;
   mapping(uint256 => uint256) private AssetTypePrice;
   mapping(uint256 => uint256[] ) private RoundByAssetTypePrices;
   mapping(address => uint256 ) private BuyerRound1;
   mapping(address => uint256 ) private BuyerRound2;
   mapping(address => uint256 ) private BuyerRound3;
   
   bool PauseMarket;

   address sellerWallet;
   uint256 private totalSupply;

   uint256 public Round1Time;
   uint256 public Round2Time;
   uint256 public Round3Time;
   uint256 public Round4Time;
   bool StartRound3 = false;


    event MintByUser(address sender,string assetId,uint256 _value,uint256 _price) ;

    modifier firstRound() {
        require(!PauseMarket , "Market is paused");
        _;
    }
    modifier secendRound() {
        require(!PauseMarket , "Market is paused");
        _;
    }
    constructor(address _dataCotract, address _MarketAddress)  {
        MarketAddress=   MarketplaceAssets(_MarketAddress) ;
        LandDataAddress= LandSalesData(_dataCotract);
        PauseMarket = false;
        sellerWallet = owner();
        mainInit();
    }
    function deposit() public payable {}
    function withdraw() public onlyOwner{
         payable(owner()).transfer( address(this).balance ) ;
    }
    //override function
    //operat
    function mainInit() private {
        RoundByAssetTypePrices[1]= new uint256[](8);
        RoundByAssetTypePrices[2]= new uint256[](8);
        RoundByAssetTypePrices[3]= new uint256[](8);
        RoundByAssetTypePrices[4]= new uint256[](8);

        RoundByAssetTypePrices[1] =  [10,17,20,20,31,46,99,122];
        RoundByAssetTypePrices[2] =  [10,17,20,20,31,46,99,122];
        RoundByAssetTypePrices[3] =  [20,33,39,39,59,88,189,234];
        RoundByAssetTypePrices[4] =  [30,50,60,60,90,135,290,360];

        //time changed after 
        Round1Time = 1662138000;
        Round2Time = 1662224400;
        Round3Time = 1662228000;
        Round4Time = 1662235200;
    }


    function UserMint(string memory _assetId,string memory _assetName) payable public {
        uint round = getWichRound(); 
        require( round > 0 , "Lands sale does not start." );
        if(round == 1 ) {
            require( getWhiteList(msg.sender) , "Your are not in our whitelist" );
            require(BuyerRound1[msg.sender] == 0  ,"every body can buy one peace in this round" );
            BuyerRound1[msg.sender] ++;
            
        }else if(round == 2) {
            require( getWhiteList(msg.sender) , "Your are not in our whitelist" );
            require(BuyerRound2[msg.sender]  < 2 , "every body can buy 3 peace in this round" );
            BuyerRound2[msg.sender]++;
        }
        else if(round == 3) {
            require( getWhiteList2(msg.sender) || getWhiteList(msg.sender) , "Your are not in our whitelist" );
            require( BuyerRound3[msg.sender]  == 0 , "every body can buy one peace in this round" );
            BuyerRound3[msg.sender]++;
        }
        else {
            //require( Buyer[msg.sender][round] == 0 , "every body can buy one peace in this round" );
        }
       
        uint assetType  = getAssetType(_assetId);
        require(assetType != 128 , 'Asset type does not defined');
        uint256 assetPrice = getPrice(_assetId );
        require(assetPrice >0 , 'Asset does not have price');
        require(msg.value == assetPrice ,'Price is incorrect' );
        deposit();
        payable(sellerWallet).transfer(assetPrice);
        
        MarketAddress.addNewAssets(msg.sender, _assetName, _assetId, assetType );
        emit MintByUser(msg.sender,_assetId,msg.value,assetPrice);
       
        
    }

    //set
    function setRound1Time (uint256 _time) public onlyOwner {
        require( _time < Round2Time  , '_time must be smaller than Round2Time');
        Round1Time = _time;
    }
    function setRound2Time (uint256 _time) public onlyOwner {
        require( _time < Round3Time  , '_time must be smaller than Round3Time');
        Round2Time = _time;
    }
    function setRound3Time (uint256 _time) public onlyOwner {
        require( _time < Round4Time  , '_time must be smaller than Round4Time');
        Round3Time = _time;
    }
    function setRound4Time (uint256 _time) public onlyOwner {
        Round4Time = _time;
    }

    //get 
    function getPrice(string memory assetId ) public view returns(uint256) {
        return  getPriceByType(getAssetType(assetId));
    }


    function getPriceByType(uint256 assetType ) public view returns(uint256) {
        uint256 round = getWichRound();
       if(round == 0 ) { return 0;} 
       else return getPriceByRoundType(round,assetType) ;
    }
    function getPreviewPrice(string memory assetId ) public view returns(uint256){
       uint256 round = getWichRound();
       if(round == 0 ) { round = 1 ;} 
       
       return getPriceByRoundType(round,getAssetType(assetId)) ;
    }
    function getPriceByRoundType(uint256 _round,uint256 _assetType ) public view returns(uint256) {
        if(_round ==0 ) {return 0;}
       else { return RoundByAssetTypePrices[_round][_assetType] * (10 ** 17) ;}
    }
    function getAssetType(string memory assetId) public view returns(uint256) {
        uint256 _type = 128;
         uint256 total =LandDataAddress.getMainDataLength();
        for(uint256 i=0;i < total ; i++  ) {
            if(  keccak256(bytes( LandDataAddress.getAssetIdIndex(i))) ==  keccak256(bytes( assetId)) ) {
                _type = LandDataAddress.getAssetTypeIndex(i);
            }
        }
        return _type;
    }
    function getCountOfBuy(address _user ) public view returns(uint256,uint256,uint256){
        return (BuyerRound1[_user] , BuyerRound2[_user] , BuyerRound2[_user] );
    }
    function getFullMainData(uint256 _from,uint256 _to) public view  returns (LandsInput[] memory) {
        require(_from < _to , "_to must be bigger than _from");
        uint256 totalCount = getMainDataLength();
        
        if(_to >  totalCount ) {
            _to = totalCount;
        }
        uint256 count = _from;
        uint ArraySize = _to - _from; 
        LandsInput[] memory maindata = new LandsInput[](ArraySize);

        for(uint256 i =0;i<(ArraySize);i++) {

            maindata[i] = LandsInput(LandDataAddress.getAssetIdIndex(count),LandDataAddress.getAssetTypeIndex(count)) ;
            count++;
        }

        return maindata;
    }
    function getAssetType2(uint256 index) public view returns(string memory) {
        return LandDataAddress.getAssetIdIndex(index) ;
    }
    function getMainDataLength() public view returns(uint256) {
        return LandDataAddress.getMainDataLength() ;
    }
    function getTimestamp() public  view returns (uint256) {
        return block.timestamp;
    }
    function getWhiteList(address _user) public view returns(bool){
        return LandDataAddress.getWhitelist(_user);
    }
     function getWhiteList2(address _user) public view returns(bool){
        return LandDataAddress.getWhitelist2(_user);
    }
    function getWichRound() public view returns(uint256){
        
        if(block.timestamp >= Round4Time ) {
            return 4;
        }else if (block.timestamp >= Round3Time ) {
            return 3;
        }else if (block.timestamp >= Round2Time ) {
            return 2;
        }else if (block.timestamp >= Round1Time ) {
            return 1;
        }else{
            return 0;
        }
 
    }
}


