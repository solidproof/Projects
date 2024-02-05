// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Counters.sol";
import "./IERC721Enumerable.sol";
import "./IERC721A.sol";
import "./IERC721Receiver.sol";
import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
contract NFTMarketplace is IERC721Receiver, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    struct MarketItem {
        uint256 itemID;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) public idToMarketItem;
    uint256[] public ItemIndex;
    uint256 public ItemId;

    address[] public nftContracts;
    uint256 public nftContractId;
    address public feeReceiver;
    address public teamWallet;
    uint256 public saleTax;
    uint256 public saleTaxDenominator;
    mapping(address=>uint256)public royalty;
    mapping(address=>address)public royaltyReceiver;
    event MarketItemCreated(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event SaleCancelled(uint256 indexed itemID);

    constructor(
        address _feeReceiver,
        address _teamWallet,
        uint256 _saleTax,
        uint256 _saleTaxDenominator
    ) {
        feeReceiver = _feeReceiver;
        teamWallet = _teamWallet;
        saleTax = _saleTax;
        saleTaxDenominator = _saleTaxDenominator;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function addNftContract(address nftContractaddress) external onlyOwner {
        nftContracts.push(nftContractaddress);
        nftContractId++;
    }

    function deleteNftContract() external onlyOwner {
        nftContracts.pop();
        nftContractId--;
    }

    function setSaleTax(uint256 _saleTax, uint256 _saleTaxDenominator) external onlyOwner {
        require(_saleTax <= _saleTaxDenominator / 5, "Sale tax cannot exceed 20%!!");
        saleTax = _saleTax;
        saleTaxDenominator = _saleTaxDenominator;
    }
    function setRoyalty(address nftcontracts, uint256 _royalty) external onlyOwner {
        royalty[nftcontracts]=_royalty;
    }
    function setRoyaltyReceiver(address nftcontracts, address _royaltyReceiver) external onlyOwner {
        royaltyReceiver[nftcontracts]=_royaltyReceiver;
    }

    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        require(price > 0, "Price must be greater than zero");
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "You do not own this token"
        );

        IERC721(nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );

        MarketItem memory newItem = MarketItem(
            ItemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            price,
            false
        );
        idToMarketItem[ItemId] = newItem;
        emit MarketItemCreated(nftContract, tokenId, msg.sender, price);
        ItemIndex.push(ItemId);
        ItemId++;
    }

    function cancelSale(uint256 itemId) external nonReentrant {
        MarketItem storage item = idToMarketItem[itemId];

        require(item.sold == false, "This item is not for sale.");
        require(item.seller == msg.sender, "You are not the seller.");

        IERC721 tokenContract = IERC721(item.nftContract);

        tokenContract.transferFrom(address(this), msg.sender, item.tokenId);

        item.sold = true;

        item.price = 0;

        emit SaleCancelled(itemId);
    }

    function buyNFT(uint256 itemId) external payable nonReentrant {
        MarketItem storage item = idToMarketItem[itemId];
        require(msg.value >= item.price, "Incorrect price");
        require(item.sold == false, "Item is already sold");

        item.sold = true;
        item.price = msg.value;
        IERC721(item.nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );

        uint256 _tax = (msg.value * saleTax) / saleTaxDenominator;
        payable(feeReceiver).transfer((_tax*40)/100);
        payable(teamWallet).transfer((_tax*60)/100);
        if(royaltyReceiver[item.nftContract]!=address(0)){
          payable(royaltyReceiver[item.nftContract]).transfer((msg.value*royalty[item.nftContract])/100);
        }
        
        item.seller.transfer(address(this).balance);
    }

    function getAllMarketItems() external view returns (MarketItem[] memory) {
        MarketItem[] memory filtereditems = new MarketItem[](ItemIndex.length);
        uint256 counter = 0;
        for (uint256 i = 0; i < ItemIndex.length; i++) {
            if (idToMarketItem[i].sold == false) {
                filtereditems[counter] = idToMarketItem[i];
                counter++;
            }
        }
        MarketItem[] memory items = new MarketItem[](counter);
        for (uint256 i = 0; i < counter; i++) {
            items[i] = filtereditems[i];
        }
        return items;
    }

    function getMyMarketItems() external view returns (MarketItem[] memory) {
        MarketItem[] memory filtereditems = new MarketItem[](ItemIndex.length);
        uint256 counter = 0;
        for (uint256 i = 0; i < ItemIndex.length; i++) {
            if (
                (idToMarketItem[i].sold == false) &&
                (idToMarketItem[i].seller == msg.sender)
            ) {
                filtereditems[counter] = idToMarketItem[i];
                counter++;
            }
        }
        MarketItem[] memory items = new MarketItem[](counter);
        for (uint256 i = 0; i < counter; i++) {
            items[i] = filtereditems[i];
        }
        return items;
    }

    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 amoumt;
        uint256 conter;
        uint256 sum;
        for (uint256 i = 0; i < nftContracts.length; i++)
            amoumt =amoumt+IERC721Enumerable(nftContracts[i]).balanceOf(msg.sender);

        MarketItem[] memory items = new MarketItem[](amoumt);
        for (uint256 i = 0; i < nftContracts.length; i++) {
            conter = IERC721Enumerable(nftContracts[i]).balanceOf(msg.sender);
            for (uint256 j = 0; j < conter; j++) {
                items[sum].itemID=0;
                items[sum].nftContract=nftContracts[i];
                items[sum].tokenId=IERC721Enumerable(nftContracts[i]).tokenOfOwnerByIndex(msg.sender,j);
                items[sum].seller=payable(msg.sender);
                items[sum].price=0;
                items[sum].sold=false;
                sum++;
            }
        }
        return items;
    }

   

    /**
     * @dev Function to allow owner to withdraw native token in smart contract.
     */
    function withdrawNative(address payable beneficiary) public onlyOwner {
        beneficiary.transfer(address(this).balance);
    } 

    function withdrawTokens(IERC20 _token, address beneficiary) public onlyOwner {
        require(IERC20(_token).transfer(beneficiary, IERC20(_token).balanceOf(address(this))));
    }

    /**
     * @dev Function to allow owner to withdraw native token in smart contract.
     */
    function withdrawWrong(address nftcontracts,uint tokenId) public onlyOwner {
        IERC721(nftcontracts).transferFrom(address(this), msg.sender, tokenId);
    } 

    receive() external payable {}
}
