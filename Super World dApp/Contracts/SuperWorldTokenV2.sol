pragma solidity 0.8.10;   

// 10 percentage cut
// 1000000000000000 baseprice (test 0.001 MATIC)
// 100000000000000000000 baseprice (mainnet 100 MATIC)
// https://geo.superworldapp.com/api/json/metadata/get/80001/ metaUrl (test)
// https://geo.superworldapp.com/api/json/metadata/get/137/ metaUrl (mainnet)


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.8/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.8/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.8/contracts/security/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.8/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// SuperWorldToken contract inherits ERC721 and ownable contracts
contract SuperWorldToken is ERC721Enumerable, Ownable, ReentrancyGuard {
    // address public owner;
    address public coinAddress;
    ERC20Interface public superWorldCoin;

    uint256 public percentageCut;
    uint256 public basePrice;
    uint256 public buyId = 0;
    uint256 public listId = 0;
    string public metaUrl;

    // tokenId => base price in wei
	mapping(uint => uint) public basePrices;

    // tokenId => bought price in wei
    mapping(uint256 => uint256) public boughtPrices;

    // tokenId => sell price in wei
    mapping(uint256 => uint256) public sellPrices;
    
    // tokenId => is selling
    mapping(uint256 => bool) public isListeds;

    // tokenId => buyId
    mapping(uint256 => uint256) public buyIds;
    
    //THE EVENTS ARE EMBEDDED IN FUNCTIONS, AND ALWAYS LOG TO THE BLOCKCHAIN USING THE PARAMS SENT IN
    
    // @dev logs and saves the params EventBuyToken to the blockchain on a block
    // @param takes in a buyId, the geolocation, the address of the buyer and the seller, the price bought at,
    //        the time bought, and id of the property bought.
    event EventBuyToken(
        uint256 buyId,
        string lon,
        string lat,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 timestamp,
        bytes32 indexed tokenId
    );
    
    // @dev lists the token on the blockchain and saves/logs the params of the token.
    // @param takes in the id of the list, the id of the buy, the geolocation, seller address, the price selling/sold at,
    //        whether it is up for a listing or not, when it was sold, and the tokenId.
    event EventListToken(
        uint256 listId,
        uint256 buyId,
        string lon,
        string lat,
        address indexed seller,
        uint256 price,
        bool isListed,
        uint256 timestamp,
        bytes32 indexed tokenId
    );
    
    constructor(
        address _coinAddress,
        uint256 _percentageCut,
        uint256 _basePrice,
        string memory _metaUrl
    ) public ERC721("SuperWorld", "SUPERWORLD") {
        coinAddress = _coinAddress;
        superWorldCoin = ERC20Interface(coinAddress);
        percentageCut = _percentageCut;
        basePrice = _basePrice;
        metaUrl = _metaUrl;
        buyId = 0;
        listId = 0;
    }
    
    // @dev creates a base price that has to be greater than zero for the token
    // @param takes in a uint that represents the baseprice you want.
    // @return no return, mutator
    function setBasePrice(uint256 _basePrice) public onlyOwner() {
        require(_basePrice > 0);
        basePrice = _basePrice;
    }

    // @dev creates a base price that has to be greater than zero for the specified plot 
    // @param takes in a uint that represents the baseprice and the lat,lon for that plot 
    // @return no return, mutator
    function setBasePrice(string memory lat, string memory lon, uint _basePrice) public onlyOwner() {
		require(_basePrice > 0);
		uint256 tokenId = uint256(getTokenId(lat, lon));
		basePrices[tokenId] = _basePrice;
	}

    // @dev sets the percentage cut of the token for the contract variable
    // @param takes in a uint representing the percentageCut
    // @return no return, mutator
    function setPercentageCut(uint256 _percentageCut) public onlyOwner() {
        require(_percentageCut > 0 && _percentageCut < 100);
        percentageCut = _percentageCut;
    }

    // @dev generates a new token, using recordTransactions directly below, private method
    // @param takes in a buyer address, the id of the token, and the price of the token
    // @return returns nothing, creates a token 
    function createToken(
        address buyer,
        uint256 tokenId,
        uint256 price
    ) private {
        _mint(buyer, tokenId);
        recordTransaction(tokenId, price);
    }

    // @dev used by createToken, adds to the array at the token id spot, the price of the token based on its id
    // @param takes the token's id and the price of the tokenId
    // @return returns nothing
    function recordTransaction(uint256 tokenId, uint256 price) private {
        boughtPrices[tokenId] = price;
    }

    // @dev returns all info on the token using lat and lon
    // @param takes in two strings, latitude and longitude.
    // @return the token id, the address of the token owner, if it is owned, if it is up for sale, and the selling price
    function getInfo(string memory lat, string memory lon)
        public
        view
        returns (
            bytes32 tokenId,
            address tokenOwner,
            bool isOwned,
            bool isListed,
            uint256 price
        )
    {
        tokenId = getTokenId(lat, lon);
        uint256 intTokenId = uint256(tokenId);
        tokenOwner = _ownerOf(intTokenId);
        isOwned = _exists(intTokenId);
        isListed = isListeds[intTokenId];
        price = getPrice(intTokenId);
    }
    
    // Bulk Gifting
    // @dev gift tokens to users
    // @param string of latitudes and longitudes, formatted "lat1,lon1;lat2,lon2;...;latn,lonn",
    //        array [address1, address2, ..., addressn]
    function giftTokens(
        string memory geoIds,
        address[] memory buyers
    ) public onlyOwner() {
        require(bytes(geoIds).length != 0);
        uint256 n = 1;
        for (uint256 pos = indexOfChar(geoIds, bytes1(";"), 0); pos != 0; pos = indexOfChar(geoIds, bytes1(";"), pos + 1)) {
            n++;
        }
        require(n == buyers.length);
        
        _giftTokens(geoIds, buyers, n);
    }
    
    // @dev private helper function for giftTokens
    // @param string of latitudes and longitudes, formatted "lat1,lon1;lat2,lon2;...;latn,lonn",
    //        array [address1, address2, ..., addressn],
    //        number of tokens in the above lists
    // @return none
    function _giftTokens(
        string memory geoIds,
        address[] memory buyers,
        uint256 numTokens
    ) private {
        string[] memory lat = new string[](numTokens);
        string[] memory lon = new string[](numTokens);

        uint256 pos = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 delim = indexOfChar(geoIds, bytes1(";"), pos);
            string memory geoId = substring(geoIds, pos, delim);
            lat[i] = getLat(geoId);
            lon[i] = getLon(geoId);
            pos = delim + 1;
        }

        for (uint256 i = 0; i < numTokens; i++) {
            _giftToken(lat[i], lon[i], buyers[i]);
        }
    }
    
    // @dev private function using lat and lon to transfer a plot to user
    // @param takes in a geo location(lat and lon), as well as a user's address price they bought at (in old contract)
    // @return returns nothing, but logs to the transaction logs of the even Buy Token
    function _giftToken(
        string memory lat,
        string memory lon,
        address buyer
    ) private {
        uint256 tokenId = uint256(getTokenId(lat, lon));
        createToken(buyer, tokenId, basePrice);
        emitBuyTokenEvents(
            tokenId,
            lon,
            lat,
            buyer,
            address(0),
            basePrice,
            block.timestamp
        );
    }

    // @dev Indicates the status of transfer (false if it didnt go through)
    // @param takes in the buyer address, the coins spent approved by buyer, and the geolocation of the token
    // @return returns the status of the transfer of coins for the token
    function buyTokenWithCoins(
        address buyer,
        uint256 coins,
        string memory lat,
        string memory lon
    ) public returns (bool) {
        uint256 tokenId = uint256(getTokenId(lat, lon));

        if (!_exists(tokenId)) {
            // not owned
            uint256 _basePrice = getPrice(tokenId);
            require(coins >= _basePrice);
            require(superWorldCoin.balanceOf(buyer) >= _basePrice);
            if (!superWorldCoin.transferFrom(buyer, address(this), _basePrice)) {
                return false;
            }
            createToken(buyer, tokenId, _basePrice);
            emitBuyTokenEvents(
                tokenId,
                lon,
                lat,
                buyer,
                address(0),
                _basePrice,
                block.timestamp
            );
            return true;
        }
        return false;
    }
    
    // @dev Buy multiple tokens at once. Note that if the request is invalid or not enough gas is paid,
    //      no tokens will be bought
    // @param string of latitudes and longitudes, formatted "lat1,lon1;lat2,lon2;...;latn,lonn"
    // @return whether buying was successful
    function buyTokens(string memory geoIds) public payable returns (bool) {
        require(bytes(geoIds).length != 0);
        uint256 n = 1;
        for (uint256 pos = indexOfChar(geoIds, bytes1(";"), 0); pos != 0; pos = indexOfChar(geoIds, bytes1(";"), pos + 1)) {
            n++;
        }
        
        return _buyTokens(geoIds, msg.value, n);
    }
    
    // @dev private helper function for bulkBuy
    // @param string "lat1,lon1;lat2,lon2;...;latn,lonn", number of tokens to buy, amount paid (in wei)
    //        when calling bulkBuy
    // @return whether buying was successful
    function _buyTokens(
        string memory geoIds,
        uint256 offerPrice,
        uint256 numTokens
    ) private returns (bool) {
        string[] memory lat = new string[](numTokens);
        string[] memory lon = new string[](numTokens);
        uint256[] memory prices = new uint256[](numTokens);
        
        uint256 totalPrice = 0;
        uint256 pos = 0;
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 delim = indexOfChar(geoIds, bytes1(";"), pos);
            string memory geoId = substring(geoIds, pos, delim);
            lat[i] = getLat(geoId);
            lon[i] = getLon(geoId);
            pos = delim + 1;
            
            uint256 tokenId = uint256(getTokenId(lat[i], lon[i]));
            prices[i] = getPrice(tokenId);
            totalPrice = SafeMath.add(totalPrice, prices[i]);
        }
        require(offerPrice >= totalPrice);
        bool isBulkFailed;
        for (uint256 i = 0; i < numTokens; i++) {
            if (!_buyToken(lat[i], lon[i], prices[i])) {
                isBulkFailed = true;
            }
        }
        return !isBulkFailed;
    }

    // @dev private helper function for buyToken
    // @param geoId, amount paid (in wei) when calling buyToken
    // @return whether buying was successful
    function buyToken(string memory lat, string memory lon)
        public payable
        returns (bool)
    {
        return _buyToken(lat, lon, msg.value);
    }

    // @dev private helper function for buyToken
    // @param geoId, amount paid (in wei) when calling buyToken
    // @return whether buying was successful
    function _buyToken(string memory lat, string memory lon, uint256 offerPrice)
        private
        returns (bool)
    {
        uint256 tokenId = uint256(getTokenId(lat, lon));
        
        // unique token not bought yet
        if (!_exists(tokenId)) {
            require(offerPrice >= getPrice(tokenId));
            createToken(msg.sender, tokenId, offerPrice);
            emitBuyTokenEvents(
                tokenId,
                lon,
                lat,
                msg.sender,
                address(0),
                offerPrice,
                block.timestamp
            );
            return true;
        }

        address seller = ownerOf(tokenId);

        // check seller != buyer
        require(msg.sender != seller);
        // check selling
        require(isListeds[tokenId] == true);
        // check sell price > 0
        require(sellPrices[tokenId] > 0);
        // check offer price >= sell price
        require(offerPrice >= sellPrices[tokenId]);

        // send percentage of cut to contract owner
        uint256 fee = SafeMath.div(
            SafeMath.mul(offerPrice, percentageCut),
            100
        );
        uint256 priceAfterFee = SafeMath.sub(offerPrice, fee);

        // send payment to seller
        address payable _seller = payable(seller);
        (bool success, ) = _seller.call{value: priceAfterFee}("");
        if (!success) {
            return false;
        }

        // transfer token
        _transfer(seller, msg.sender, tokenId);
        return true;
    }
    
    // @dev Updates contract state before transferring a token.
    // @param addresses of transfer, tokenId of token to be transferred
    // @return none
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal override{
        super._beforeTokenTransfer(from, to, tokenId, batchSize = 1);
        isListeds[tokenId] = false;
        uint256 price = getPrice(tokenId);
        recordTransaction(tokenId, price);
        sellPrices[tokenId] = price;
    }

    // @dev allows the processing of buying a token using event emitting
    // @param takes in the token id, the geolocation, the address of the buyer and seller, the price of the offer and when it was bought.
    // @return returns nothing, but creates an event emitter that logs the buying of
    function emitBuyTokenEvents(
        uint256 tokenId,
        string memory lon,
        string memory lat,
        address buyer,
        address seller,
        uint256 offerPrice,
        uint256 timestamp
    ) private {
        buyId++;
        buyIds[tokenId] = buyId;
        emit EventBuyToken(
            buyId,
            lon,
            lat,
            buyer,
            seller,
            offerPrice,
            timestamp,
            bytes32(tokenId)
        );
    }

    // list / delist
    // @dev list/delist the token on the superworld market, for a certain price user wants to sell at
    // @param takes in the geolocation of the token, the price it is selling at, and whether to list or delist
    // @return returns nothing, emits a ListToken event logging it to transactions.
    function listToken(
        string memory lat,
        string memory lon,
        uint256 sellPrice,
        bool isListed
    ) public {
        uint256 tokenId = uint256(getTokenId(lat, lon));
        require(_exists(tokenId));
        require(msg.sender == _ownerOf(tokenId));
        isListeds[tokenId] = isListed;
        sellPrices[tokenId] = sellPrice;
        emitListTokenEvents(
            buyIds[tokenId],
            lon,
            lat,
            msg.sender,
            sellPrice,
            isListed,
            block.timestamp
        );
    }

    // @dev does the list token event, used by many previous functions
    // @param takes in the buyerid, the geolocation, the seller address and price selling at, as well as whether it is listed or not, and when it sold
    // @return returns nothing, but emits the event List token to log to the transactions on the blockchain
    function emitListTokenEvents(
        uint256 _buyId,
        string memory lon,
        string memory lat,
        address seller,
        uint256 sellPrice,
        bool isListed,
        uint256 timestamp
    ) private {
        listId++;
        bytes32 tokenId = getTokenId(lat, lon);
        emit EventListToken(
            listId,
            _buyId,
            lon,
            lat,
            seller,
            sellPrice,
            isListed,
            timestamp,
            tokenId
        );
    }
     
    // @dev provides the price for the tokenId
    // @param takes in the tokenId as a uint parameter
    // @return a uint of the price returned
    function getPrice(uint256 tokenId) public view returns (uint256) {
        if (_ownerOf(tokenId) == address(0)) {
            // not owned
        	uint _basePrice = basePrices[tokenId];
			if (_basePrice == 0) {
				return basePrice;
			}
			else {
				return _basePrice;
			}
        } else {
            // owned
            return isListeds[tokenId] ? sellPrices[tokenId] : boughtPrices[tokenId];
        }
        
    }

    // @devs: withdraws a certain amount from the owner
    // @param no params taken in
    // @return doesn't return anything, but transfers the balance from the message sender to the address intended.
    function withdrawBalance(uint balance) public payable nonReentrant onlyOwner() returns(bool) {
        require(balance <= address(this).balance);
        (bool success, ) = _msgSender().call{value: balance}("");
        return success;
    }
    
    //  @dev Base URI for computing {tokenURI}.
    //  @return metaUrl
    function _baseURI() internal view virtual override returns (string memory) {
        return metaUrl;
    }

    // @dev provides the token id based on the coordinates(longitude and latitude) of the property
    // @param a longitude string and a latitude string
    // @return returns the token id as a 32 bit object, otherwise it returns a 0 as a hex if the lat and lon are empty
    function getTokenId(string memory lat, string memory lon)
        public
        pure
        returns (bytes32 tokenId)
    {
        if (bytes(lat).length == 0 || bytes(lon).length == 0) {
            return 0x0;
        }
        
        string memory geo = string(abi.encodePacked(lat, ",", lon));
        assembly {
            tokenId := mload(add(geo, 32))
        }
    }
    
    // @dev the opposite of the getTokenId, gives the lat and lon using tokenId
    // @param takes in a 32 bit tokenId object.
    // @return returns the latitude and longitude of a location
    function getGeoFromTokenId(bytes32 tokenId)
        public
        pure
        returns (
            string memory lat,
            string memory lon
        )
    {
        uint256 n = 32;
        while (n > 0 && tokenId[n-1] == 0) {
            n--;
        }
        bytes memory bytesArray = new bytes(n);
        for (uint256 i = 0; i < n; i++) {
            bytesArray[i] = tokenId[i];
        }
        string memory geoId = string(bytesArray);
        lat = getLat(geoId);
        lon = getLon(geoId);
    }
    
    // @dev gets the latitude of the token from a geoId
    // @param takes in a string of form "Lat,Lon" as a parameter
    // @return returns the str of the latitude
    function getLat(string memory str) public pure returns (string memory) {
        uint256 index = indexOfChar(str, bytes1(","), 0);
        return substring(str, 0, index);
    }

    // @dev gets the longitude of the token from a geoId
    // @param takes in a string of form "Lat,Lon" as a parameter
    // @return returns the str of the longitude
    function getLon(string memory str) public pure returns (string memory) {
        uint256 index = indexOfChar(str, bytes1(","), 0);
        return substring(str, index + 1, 0);
    }

        // @dev trims the decimals to a certain substring and gives it back
    // @param takes in the string, and trims based on the decimal integer
    // @return returns the substring based on the decimal values.
    function truncateDecimals(string memory str, uint256 decimal)
        public
        pure
        returns (string memory)
    {
        uint256 decimalIndex = indexOfChar(str, bytes1("."), 0);
        bytes memory strBytes = bytes(str);
        uint256 length = strBytes.length;
        return (decimalIndex + decimal + 1 > length) ? substring(str, 0, length) : substring(str, 0, decimalIndex + decimal + 1);
    }

    // @dev standard substring method. Note that endIndex == 0 indicates the substring should be taken to the end of the string.
    // @param takes in a string, and a starting (included) and ending index (not included in substring).
    // @return substring
    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (endIndex == 0) {
            endIndex = strBytes.length;
        }
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    // @dev gets the index of a certain character inside of a string; helper method
    // @param requires a string, a certain character, and the index to start checking from
    // @return returns the index of the character in the string
    function indexOfChar(string memory str, bytes1 char, uint256 startIndex) public pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        uint256 length = strBytes.length;
        for (uint256 i = startIndex; i < length; i++) {
            if (strBytes[i] == char) {
                return i;
            }
        }
        return 0;
    }
}   

abstract contract ERC20Interface {
    // @dev checks whether the transaction between the two addresses of the token went through
    // @param takes in two addresses, and a single uint as a token number
    // @return returns a boolean, true is successful and false if not
    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) public virtual returns (bool success);

    // @dev checks the balance of the inputted address
    // @param the address you are checking the balance of
    // @return returns the balance as a uint
    function balanceOf(address tokenOwner)
        public
        virtual
        view
        returns (uint256 balance);
}
