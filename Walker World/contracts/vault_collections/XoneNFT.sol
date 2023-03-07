// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract XoneNFT is ERC721Enumerable, Ownable, ERC721Burnable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    mapping(uint256 => string) private _tokenURIs;

    string public baseTokenURI;

    event Minted(address sedner, uint256 tokenId);

    struct Plan {
        string name;
        bool isOpen;
        bool isWhiteListSale;
        uint256 createdAt;
        uint256 Max_Amount;
        uint256 minted_amount;
        uint256 whitelist_price;
        uint256 price;
        uint256 Max_Mint_Amount_Per_Address;
        uint256 team_amount;
        uint256 airdrop_amount;
        bool state; //
    }

    uint256 public Minimum_Price = 0.08 ether;
    uint256 public Max_Team_Perc_Every_Plan = 7;
    uint256 public Max_Airdrop_Perc_Every_Plan = 1;
    uint256 public Denominator = 10;

    mapping(string => mapping(address => uint256)) private mint_status;
    mapping(string => mapping(address => bool)) private whitelists;
    mapping(string => Plan) private plans;

    string public Current_Plan;

    address private _wallet1 = 0x9960d00ee6574fEb813f7e958514a3109991224B; // pre-sold 1.
    uint256 private _amount1 = 400;
    address private _wallet2 = 0x6ec95018056ee917ea87D3d2b34ad2348b111195; // pre-sold 2.
    uint256 private _amount2 = 300;
    address private _wallet3 = 0x2a9Da28bCbF97A8C008Fd211f5127b860613922D; // pre-sold 3.
    uint256 private _amount3 = 54;
    address private _teamWallet = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; //Hardhat owner wallet

    event CreatedXoneNFT(address indexed _owner, uint256 indexed _id);

    constructor() ERC721("XONE NFT", "XONE") {
        createPlan(
            "Jan-2022",
            false,
            false,
            2500,
            0.1 ether,
            0.08 ether,
            2,
            200,
            10
        );
    }

    function setWhiteLists(
        address[] memory _addresses,
        string memory _plan,
        bool _isWhiteListed
    ) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelists[_plan][_addresses[i]] = _isWhiteListed;
        }
    }

    function createPlan(
        string memory _plan,
        bool _isOpen,
        bool _isWhiteListSale,
        uint256 _max_amount,
        uint256 _price,
        uint256 _whitelist_price,
        uint256 _max_mint_amount_per_address,
        uint256 _team_amount,
        uint256 _airdrop_amount
    ) public onlyOwner {
        require(plans[_plan].state == false, "XONE: Plan is already existed");
        require(
            _price >= Minimum_Price,
            "XONE: price can't be lower than minimum price"
        );
        require(
            _whitelist_price >= Minimum_Price,
            "XONE: whitelist price can't be lower than minimum price"
        );
        require(_max_amount >= 1);
        require(_max_mint_amount_per_address >= 1);
        require(
            (_team_amount.mul(Denominator)).div(_max_amount) <=
                Max_Team_Perc_Every_Plan,
            "XONE: Limit max team amount error"
        );
        require(
            (_airdrop_amount.mul(Denominator)).div(_max_amount) <=
                Max_Airdrop_Perc_Every_Plan,
            "XONE: Limit max airdrop amount error"
        );

        Plan storage plan = plans[_plan];
        plan.name = _plan;
        plan.isOpen = _isOpen;
        plan.isWhiteListSale = _isWhiteListSale;
        plan.price = _price;
        plan.whitelist_price = _whitelist_price;
        plan.Max_Amount = _max_amount;
        plan.createdAt = block.timestamp;
        plan.state = true;
        plan.team_amount = _team_amount;
        plan.airdrop_amount = _airdrop_amount;
        plan.Max_Mint_Amount_Per_Address = _max_mint_amount_per_address;

        Current_Plan = _plan;
    }

    function updatePlanState(
        string memory _plan,
        bool _isOpen,
        bool _isWhiteListSale,
        uint256 _max_mint_amount_per_address
    ) public onlyOwner {
        require(plans[_plan].state == true, "XONE: Plan is not existed");
        require(_max_mint_amount_per_address >= 1);
        Plan storage plan = plans[_plan];
        if (plan.isOpen != _isOpen) {
            plan.isOpen = _isOpen;
        }
        if (plan.isWhiteListSale != _isWhiteListSale) {
            plan.isWhiteListSale = _isWhiteListSale;
        }
        plan.Max_Mint_Amount_Per_Address = _max_mint_amount_per_address;
    }

    function isWhiteListed(address _address, string memory _plan)
        public
        view
        returns (bool)
    {
        return whitelists[_plan][_address];
    }

    function _totalSupply() internal view returns (uint256) {
        return _tokenIdTracker.current();
    }

    function _mintAnElement(address _to) private returns (uint256) {
        uint256 id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit Minted(_to, id);
        return id;
    }

    function _mintForBulk(address _to) private {
        uint256 id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit Minted(_to, id);
    }

    function mintTeam(uint256 _amount, string memory _plan) external onlyOwner {
        // _amount: because of gasLiimit
        require(_amount > 0);
        require(_amount <= plans[_plan].team_amount);
        require(
            (plans[_plan].minted_amount).add(_amount) <=
                plans[_plan].Max_Amount,
            "XONE: Exceed Plan Max limit"
        );

        Plan storage plan = plans[_plan];
        plan.minted_amount = (plan.minted_amount).add(_amount);
        plan.team_amount = plan.team_amount.sub(_amount);

        for (uint256 i = 0; i < _amount; i++) {
            //_mintForBulk(_teamWallet);
            _mintForBulk(msg.sender);
        }
    }

    function prices(
        uint256 _count,
        string memory _plan,
        bool _isWhiteListSale
    ) internal view returns (uint256) {
        if (_isWhiteListSale)
            return ((plans[_plan].whitelist_price).mul(_count));
        return ((plans[_plan].price).mul(_count));
    }

    function tokenIdsOfOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIds;
    }

    function withdrawETH(address to, uint256 amount) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        if (amount <= balance) {
            _widthdraw(to, amount);
        } else {
            _widthdraw(to, balance);
        }
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721)
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If there is _tokenURI, return the token URI.
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721) {
        super._burn(tokenId);
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function updateCurrentPlan(string memory _plan) public onlyOwner {
        require(plans[_plan].state, "XONE: can't update to invalid plan");
        Current_Plan = _plan;
    }

    function planInfo(string memory _plan) public view returns (Plan memory) {
        return plans[_plan];
    }

    function airdrop(
        string memory _plan,
        uint256 _amount,
        address[] memory _addresses
    ) public onlyOwner {
        require(plans[_plan].state == true, "XONE: Plan is not existed");
        require(_amount > 0);
        require(_addresses.length == _amount);
        require(_amount <= plans[_plan].airdrop_amount);

        Plan storage plan = plans[_plan];
        plan.airdrop_amount = plan.airdrop_amount.sub(_amount);

        for (uint256 i = 0; i < _amount; i++) {
            _mintForBulk(_addresses[i]);
        }
    }

    function airdropGiftMode(
        string memory _plan,
        uint256 _amount,
        address[] memory _addresses,
        string[] memory _tokenUris
    ) public onlyOwner {
        require(plans[_plan].state == true, "XONE: Plan is not existed");
        require(_amount > 0);
        require(_addresses.length == _amount);
        require(_addresses.length == _tokenUris.length);
        require(_amount <= plans[_plan].airdrop_amount);

        Plan storage plan = plans[_plan];
        plan.airdrop_amount = plan.airdrop_amount.sub(_amount);

        for (uint256 i = 0; i < _amount; i++) {
            uint256 id = _totalSupply();
            _tokenIdTracker.increment();
            _safeMint(_addresses[i], id);
            _setTokenURI(id, _tokenUris[i]);
            emit Minted(_addresses[i], id);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }
}
