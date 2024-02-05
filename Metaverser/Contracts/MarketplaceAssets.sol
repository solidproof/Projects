// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MetaverserNFT.sol";
import "./interfaces/IMarketplaceAssets.sol" ;

contract  MarketplaceAssets is IMarketplaceAssets,Ownable  {
  
   MetaverserNFT private nftContract  ;
   mapping(uint256 =>  MainAssets ) private MarketGameAssets; 
   mapping(uint256 => uint256) private MarketGameAssetsType;
   mapping(address => bool) private AccessList;
   bool PauseMarket;
   bool BNBMarket;
   address DAOAddress;
   address MinnersAddress;
   uint256 DAOPercent ;
   uint256 minnersPercent;
   ERC20 MTVTToken;

   uint256 public MarketTokenCounter;

   modifier tokenOwnerAccess(uint256 tokenId) {
       require(MarketGameAssets[tokenId].owner == msg.sender ,'You are not owner' );
       _;
   }
   
   modifier notPause() {
       require(!PauseMarket , "Market is paused");
       _;
   }
   modifier OnlyAccessList() {
       require(AccessList[msg.sender],"You do not have access");
       _;
   }
    constructor(address _Token,address _nftContract)  {
        nftContract= MetaverserNFT(_nftContract);
        MTVTToken = ERC20(_Token);
        PauseMarket = false;
        BNBMarket=true;
        DAOAddress = msg.sender;
        DAOPercent = 5;
        MinnersAddress = msg.sender;
        minnersPercent = 5; 
        MarketTokenCounter= nftContract.TokenIdCounter();
        AccessList[msg.sender]= true;
    }
    function deposit() public payable {}
    function withdraw() public onlyOwner {
         payable(owner()).transfer( address(this).balance ) ;
    }

    //admin Operator functions

    function addNewAssets(address owner, string memory _assetName, string memory _assetId, uint256 _assetType) OnlyAccessList public{

        //require not exist
        require(!getExistsAssetId(_assetId), "AssetId already exist");
        uint256 newItemId = nftContract.createToken(owner, _assetId,_assetName,_assetType,createTokenURI(_assetId));
        MarketGameAssets[newItemId] = nftContract.getGameAssetByTokenId(newItemId);
        MarketTokenCounter++;

    }

    function addBatchAssets(MainAssetsInput[] memory assets)  public   {
        for(uint256 i=0;i<assets.length ; i++ ) {
            addNewAssets(owner(),assets[i].asset_name,assets[i].assetId,assets[i].asset_type);
        }
    }
    
    function replacementAssets(uint256[] memory tokenIds,string memory _assetName, string memory _assetId, uint256 _assetType ) public onlyOwner   {
        address oldOwner= MarketGameAssets[tokenIds[0]].owner;
        for(uint256 i=0;i<tokenIds.length ; i++ ) {
            require(oldOwner == MarketGameAssets[tokenIds[i]].owner , "All Tokens owner must be one");
            BurnNFT(tokenIds[i] ) ;
        }
        addNewAssets(oldOwner , _assetName, _assetId, _assetType);
    }
    function BurnNFT(uint256 _tokenId) public onlyOwner{
            nftContract.burnNFT( _tokenId) ;
            delete MarketGameAssets[_tokenId]  ;
            delete MarketGameAssetsType[_tokenId]  ;
    }
    function syncContractData(uint256 _from, uint256 _to) public onlyOwner   {
        
        uint256 _totalSupply = MarketTokenCounter;
        if(_to > _totalSupply ) {
            _to = _totalSupply;
        }

        for(uint256 i=_from;i<=_to ; i++) {
            MarketGameAssets[i] = nftContract.getGameAssetByTokenId(i);
        }

        //change owner from old contract 


    }
    function syncContractSellType(uint256 _from,uint256 _to,address _oldContract )public onlyOwner   {
        uint256 _totalSupply =MarketTokenCounter;
        if(_to > _totalSupply ) {
            _to = _totalSupply;
        }
        for(uint256 i=_from;i<=_to ; i++) {
            MarketGameAssetsType[i] = MarketplaceAssets(_oldContract).getSellType(i);
        }
        //change owner from old contract 
    }
    
    function transferToNewContract(address _newContract) public onlyOwner {
        //
        for(uint256 i=1;i<=MarketTokenCounter ; i++) {
            if(nftContract.getGameAssetByTokenId(i).tokenId != 0  ) {
                if(nftContract.ownerOf(i) == address(this) ) {
                    nftContract.transferFrom(address(this),_newContract,i); 
                } 
            }

        }

    }

    function returningToken(uint256 _from, uint256 _to,uint256 _type) public onlyOwner {
        uint256 _totalSupply = MarketTokenCounter ;
        if(_to > _totalSupply ) {
            _to = _totalSupply;
        }

        //set seleable in GameAssets
        for(uint256 i=_from;i<= _to ; i++) {
            if(   MarketGameAssets[i].saleable && MarketGameAssetsType[i] == _type ){
                uint256 _tokenId= MarketGameAssets[i].tokenId ;
                nftContract.setTokenSeleable(_tokenId , false ); 
                nftContract.transferFrom( address(this) ,MarketGameAssets[i].owner, _tokenId);
                MarketGameAssets[_tokenId].saleable= false ;
                MarketGameAssetsType[_tokenId] = 0;
            }
        }

    }
    
    function transferTokenByOwner(uint256 tokenId,address to) public onlyOwner tokenOwnerAccess(tokenId) {

        nftContract.transferFrom(msg.sender , to, tokenId);
        nftContract.setTokenOwner(tokenId, to);
        MarketGameAssets[tokenId].owner = to ;
    }
    //Operator user function
    function buyAssetWithMTVT(uint256 tokenId,string memory _name) public{
        require(MarketGameAssetsType[tokenId] == 1 ,'Wrong Method Payment (Use `buyAssetWithBNB` method)' );
        (uint256 price,uint256 DAOTax,uint256 MinnersTax,bool contractOwnerIsOwner) = _beforePayment(tokenId);
        if(!contractOwnerIsOwner) {
            MTVTToken.transferFrom(msg.sender, DAOAddress, DAOTax);
            MTVTToken.transferFrom(msg.sender, MinnersAddress, MinnersTax);
        }

        MTVTToken.transferFrom(msg.sender, MarketGameAssets[tokenId].owner, price);
        _afterPayment(tokenId,price,(DAOTax + MinnersTax),_name);
    }
    function buyAssetWithBNB(uint256 tokenId,string memory _name) public payable {
        require(BNBMarket ,'BNB Payment disabled by owner' );
        require(MarketGameAssetsType[tokenId] == 0  ,'Wrong Method Payment (Use `buyAssetWithMTVT` method)' );
        require( getPayablePrice(tokenId) == msg.value , 'Insufficient funds for this action');
        deposit();
        (uint256 price,uint256 DAOTax,uint256 MinnersTax,bool contractOwnerIsOwner) = _beforePayment(tokenId);
        payable(MarketGameAssets[tokenId].owner).transfer(price);
        //transfer DAO and Minners levy
        
        if(!contractOwnerIsOwner) {
            payable(DAOAddress).transfer(DAOTax);
            payable(MinnersAddress).transfer(MinnersTax);
        }
        _afterPayment(tokenId,price,(DAOTax + MinnersTax),_name);
    }


    function addAssetToMarket(uint256 tokenId,  uint256 price , uint256 _type ) public tokenOwnerAccess(tokenId) notPause{
        //_type = 0 (BNB) 
        //_type = 1 (MTVT)
        
        //when we want to disable bnb method 
        if(_type == 0) {
            require(BNBMarket ,"BNB is disabled use just MTVT ");
        }
        //user must enter 0 or 1 
        require(_type <= 1 ,'Type of Market must be smaller than 1');

        require(tokenId > 0 , 'TokenId cannot be zero' ) ;
        require(price > 0 , 'Price cannot be zero' ) ;

        //transfer token to Marketplace
        nftContract.transferFrom(msg.sender , address(this), tokenId);
        
        //set sellable and price

        MarketGameAssets[tokenId].saleable= true ;
        MarketGameAssets[tokenId].price = price ;

        //setTokenSeleable and setTokenPrice can call when contract is owner

        //set seleable in GameAssets
        nftContract.setTokenSeleable(tokenId , true ); 
        //set price in GameAssets
        nftContract.setTokenPrice(tokenId , price ); 
        MarketGameAssetsType[tokenId] = _type;
        emit  addAssetToMarketEvent(msg.sender,tokenId,price);

    }

    function removeAssetFromMarket(uint256 tokenId) public tokenOwnerAccess(tokenId){
        require(!PauseMarket , "Market is paused by owner");
        nftContract.setTokenSeleable(tokenId , false ); 
        nftContract.transferFrom( address(this) ,msg.sender, tokenId);
        MarketGameAssets[tokenId].saleable= false ;
        //set seleable in GameAssets
        emit  removeAssetFromEvent(msg.sender,tokenId);

    }
    function transferTokenBNB(uint256 tokenId,address to) public payable {
        (uint256 DAOTax,uint256 MinnersTax) = _beforeTransfer(tokenId);
        require( DAOTax +MinnersTax  == msg.value ,'Insufficient funds for this action');
        require(BNBMarket ,'BNB method disabled' );
        require(MarketGameAssetsType[tokenId] == 0  ,'Wrong Method Payment (Use `transferTokenByMTVT` Method)' );
        deposit();
        payable( DAOAddress ).transfer(DAOTax);
        payable( MinnersAddress ).transfer(MinnersTax);
        _afterTransfer(tokenId,to);
    }

    function transferTokenMTVT(uint256 tokenId,address to) public  {
        require(MarketGameAssetsType[tokenId] == 1 ,'Wrong Method Payment (Use `transferTokenByBNB` Method)' );
       (uint256 DAOTax,uint256 MinnersTax) = _beforeTransfer(tokenId);
        MTVTToken.transferFrom(msg.sender, DAOAddress, DAOTax );
        MTVTToken.transferFrom(msg.sender, MinnersAddress, MinnersTax );
       _afterTransfer(tokenId,to);
    }

    //_helper function

    function createTokenURI(string memory _assetId) private pure returns (string memory) {
        string memory tokenURI = string.concat('https://lands.metaverser.me/lands/', _assetId,'.json');
        return tokenURI;
    }
    
    function _beforePayment(uint256 tokenId) private view notPause returns(uint256,uint256,uint256,bool) {

        require(MarketGameAssets[tokenId].saleable  ,'Asset not for sale');
        require(getPrice(tokenId) > 0  ,'Asset Has not price');
        //require(payable(MarketGameAssets[tokenId].owner) != address(0) ,'Zero address cannot buy');
                
        uint256 price = getPrice(tokenId);
        uint256 DAOTax = ((price * (DAOPercent  ))  /100 );
        uint256 MinnersTax = ((price * (  minnersPercent))  /100 );
        bool contractOwnerIsOwner = (MarketGameAssets[tokenId].owner == owner() );
        return(price,DAOTax,MinnersTax,contractOwnerIsOwner);
 
    }
    function _afterPayment(uint256 tokenId,uint256 price , uint256 tax,string memory _name) private {
        nftContract.setTokenSeleable(tokenId , false ); 
        nftContract.setTokenName(tokenId , _name );

        nftContract.transferFrom(address(this), msg.sender, tokenId);

        //set token Onwer on GameAssets
        nftContract.setTokenOwner(tokenId , msg.sender );

        MarketGameAssets[tokenId].saleable = false;
        MarketGameAssets[tokenId].asset_name =_name;
        MarketGameAssets[tokenId].owner = msg.sender;

        emit buyAssetEvent(msg.sender,MarketGameAssets[tokenId].owner,getPrice(tokenId), tokenId,price,tax);
    }

    

    
    function _beforeTransfer(uint256 tokenId) private view tokenOwnerAccess(tokenId) returns(uint256,uint256)  {
        require(getPrice(tokenId) > 0  ,'Asset Has not price');
        //require(MarketGameAssets[tokenId].owner != address(0) ,'Zero address cannot buy');
        uint256 price = getPrice(tokenId);
        uint256 DAOTax = ((price * (DAOPercent  ))  /100 );
        uint256 MinnersTax = ((price * (  minnersPercent))  /100 );
        return(DAOTax,MinnersTax);
    }
    function _afterTransfer(uint256 tokenId,address to) private {
        require(to != address(0) ,'Receiver cannot be zero address');
        nftContract.transferFrom(msg.sender , to, tokenId);
        MarketGameAssets[tokenId].owner = to ;
        nftContract.setTokenOwner(tokenId, to);
    }


    
    //Setter Function for Owner
    function setPause(bool _pause) public onlyOwner {
        PauseMarket = _pause;
    }
    function setDAOAddress(address _address) public onlyOwner {
        DAOAddress = _address;
    }
    function setMinnersAddress(address _address) public onlyOwner {
        MinnersAddress = _address;
    }
    function setAccessList(address _address,bool act) public onlyOwner {
        AccessList[_address] = act ;
    }
    function setBNBMarketAct(bool _act) public onlyOwner {
        BNBMarket = _act;
    }
    function setTokenAssetType(uint256 tokenId,uint256 _assetType) public  onlyOwner{
        MarketGameAssets[tokenId].asset_type = _assetType;
        nftContract.setTokenAssetType(tokenId,_assetType);
        emit setTokenAssetTypeEvent(msg.sender,tokenId, _assetType);
    }
    function setTokenOwner(uint256 tokenId,address newOwner) public  onlyOwner{
        //just for trace and debug (not use ) ;
        require(nftContract.ownerOf(tokenId) == newOwner , "new Owner is not correct in main nft contract; Use ownerOf Method for get correct owner" );
        MarketGameAssets[tokenId].owner = newOwner;
        //emit event in nft contract
        //emit setTokenOwnerEvent(msg.sender,tokenId, newOwner);
    }
    function setTokenURI(uint256 tokenId,string memory newURI) public  onlyOwner{
        //just for trace and debug (not use ) ;
        nftContract.setTokenURI(tokenId,newURI);
        MarketGameAssets[tokenId].uri = newURI;

    }

    //Setter Function for users
    function setTokenName(uint256 tokenId,string memory _name) public tokenOwnerAccess(tokenId) {
        MarketGameAssets[tokenId].asset_name = _name;
        nftContract.setTokenName(tokenId,_name);
    }

 
    //getter 
    function getFullDataByTokenIdNew(uint256 tokenId ) public view returns(MainAssetsNew memory) {
        
        return MainAssetsNew(
                MarketGameAssets[tokenId].tokenId,
                MarketGameAssets[tokenId].assetId,
                MarketGameAssets[tokenId].owner,
                MarketGameAssets[tokenId].asset_name,
                MarketGameAssets[tokenId].asset_type,
                MarketGameAssets[tokenId].price,
                MarketGameAssets[tokenId].saleable,
                MarketGameAssetsType[tokenId]
        ) ;

    }
    
    function getSupplyByType(uint256 _type ) public  view returns (uint256 ){
        uint256 counter=0;
        for(uint256 i=1;i<= MarketTokenCounter ; i++) {
            if(    MarketGameAssets[i].asset_type   == _type  ){
                counter++;
            }
        }
        return counter;
    }
    function getSupplyByOwner(address _address) public  view returns (uint256 ){
        uint256 counter=0;
        for(uint256 i=1;i<= MarketTokenCounter ; i++) {
            if(   MarketGameAssets[i].owner   == _address  ){
                counter++;
            }
        }
        return counter;
    }

    function getExistsAssetId(string memory _assetId) public view returns (bool){
        bool result = false;
        for(uint256 i=1;i<= MarketTokenCounter  ; i++) {
            if(  keccak256(bytes(MarketGameAssets[i].assetId) )  == keccak256( bytes(_assetId) )  ){
                return  true;
            }
        }
        return result;
    }

    function getSellType(uint256 tokenId) public view returns(uint256){
        return MarketGameAssetsType[tokenId]  ;
    }

    function getNFTTotalSupply() public view returns(uint256){
        return nftContract.totalSupply();
    }

    function getPrice(uint256 tokenId) public view returns(uint256){
        return MarketGameAssets[tokenId].price  ;
    }

    function getNFTContract() public view returns(address ){
        return address(nftContract);
    }

    function getPayablePrice(uint256 tokenId) public view returns(uint256){
        bool contractOwnerIsOwner = (MarketGameAssets[tokenId].owner == owner() );
        uint256 price=0;
        if( contractOwnerIsOwner  ) {
            price= getPrice(tokenId);
        }else{
            price =  getPrice(tokenId) +  ((getPrice(tokenId) * (DAOPercent + minnersPercent ))  /100 )  ;
        }
        return price;
    }
}


