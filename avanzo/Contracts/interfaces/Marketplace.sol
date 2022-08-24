// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface IERC721 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool _approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferMarketPlace(address _from, uint256 _tokenId, address _to) external returns(bool);
    function KYC() external returns(bool);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IFundFactory {
    function isKYCed(address _of) external view returns(bool);
    function exists(address _add) external view returns(bool);
}

contract MarketPlace {
    uint royalty;
    address rReceiver;
    address owner;
    uint currentId;
    IFundFactory public fundFactory;
    IERC20 token;
    constructor(uint96 _royaltyInBips, address _paymentToken, address _fundFactory) {
        royalty = _royaltyInBips;
        rReceiver = msg.sender;
        owner = msg.sender;
        token = IERC20(_paymentToken);
        fundFactory = IFundFactory(_fundFactory);
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    /*\
    transfer ownership of contract
    \*/
    function transferOwnership(address _to) public onlyOwner {
        owner = _to;
    }

    /*\
    set receiver addresss of royalty
    \*/
    function transferRReceiver(address _to) public onlyOwner {
        rReceiver = _to;
    }

    /*\
    sell nft/property
    \*/
    function setOnSale(address _token, uint _tokenId, uint _price) public returns(uint) {
        require(IERC721(_token).ownerOf(_tokenId) == msg.sender);
        require(fundFactory.exists(_token), "Not Avanzo NFT!");
        sale memory _sale = sale(_token, _tokenId, _price, (_price * royalty / 10000), true, msg.sender);
        idsToSale[currentId] = _sale;
        NFTToSales[_token].push(currentId);
        currentId++;
        return currentId-1;
    }


    /*\
    buy nft/property
    \*/
    function buyNFT(uint _orderId) public{
        uint _price = idsToSale[_orderId].price;
        address _token = idsToSale[_orderId].token;
        uint _tokenId = idsToSale[_orderId].tokenId;
        address _owner = idsToSale[_orderId].owner;
        uint _royalty = idsToSale[_orderId].royalty;

        if(IERC721(_token).KYC()) {
            require(fundFactory.isKYCed(msg.sender), "property requires KYC!");
        }

        require(idsToSale[_orderId].active, "already sold!");
        require(IERC721(_token).ownerOf(_tokenId) == _owner, "owner of nft changed, invalid sale!");
        require(token.transferFrom(msg.sender, rReceiver, _royalty), "Payment failed, royalty!");
        require(token.transferFrom(msg.sender, _owner, _price), "Payment failed, receiver!");

        sale memory _sale = sale(address(0x0), 0, 0, 0, false, address(0x0));
        idsToSale[_orderId] = _sale;
        _remove(_token,  _orderId);
    	require(IERC721(_token).transferMarketPlace(_owner, _tokenId, msg.sender), "transfer failed, NFT!");
    }

    /*\
    revoke any sell if no one has bought it
    \*/
    function revokeSell(uint _orderId) public {
        address _token = idsToSale[_orderId].token;
        uint _tokenId = idsToSale[_orderId].tokenId;
        address _owner = idsToSale[_orderId].owner;
        uint index;
        for(uint i; i < NFTToSales[_token].length; i++) {
            if(NFTToSales[_token][i] == _tokenId)
                index = i;
        }
        require(idsToSale[_orderId].active, "already sold!");
        require(IERC721(_token).ownerOf(_tokenId) == _owner, "owner of nft changed, invalid sale!");

        sale memory _sale = sale(address(0x0), 0, 0, 0, false, address(0x0));
        idsToSale[_orderId] = _sale;
        _remove(_token, index);
    }


    /*\
    removes index of tokenaddress from array and orders it
    \*/
    function _remove(address _token, uint _index) private{
        require(_index < NFTToSales[_token].length, "index out of bound");

        for (uint i = _index; i < NFTToSales[_token].length - 1; i++) {
            NFTToSales[_token][i] = NFTToSales[_token][i + 1];
        }
        NFTToSales[_token].pop();
    }

  



    mapping(address => uint256[]) NFTToSales;
    mapping(uint256 => sale) idsToSale;

    /*\
    gets all sale ids of a token address
    \*/
    function getSaleIdsOfNFT(address _add) public view returns(uint256[] memory){
        return NFTToSales[_add];
    }

    /*\
    struct of a sale
    \*/
    struct sale{
        address token;
        uint tokenId;
        uint price;
        uint royalty;
        bool active;
        address owner;
    }

    /*\
    gets sale info of sale id
    \*/
    function getSaleInfo(uint256 _id) public view returns(address, uint, uint, uint)  {
        return (idsToSale[_id].token, idsToSale[_id].tokenId, idsToSale[_id].price, idsToSale[_id].royalty);
    }
    
    /*\
    latest sale id
    \*/
    function getLatestSaleId() public view returns(uint){
        return currentId-1;
    }

    /*\
    checks if tokenId of tokenaddress is being sold
    \*/
    function isOnSale(address _token, uint _tokenId) public view returns(bool, uint)  {
        for(uint i; i < NFTToSales[_token].length; i++) {
            if(idsToSale[NFTToSales[_token][i]].tokenId == _tokenId)
                return(true, idsToSale[NFTToSales[_token][i]].price);
        }        
        return(false, 0);
    }


}