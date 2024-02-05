// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @author Brewlabs
 * This contract has been developed by brewlabs.info
 */
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721, ERC721Enumerable, IERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DefaultOperatorFilterer} from "operator-filter-registry/src/DefaultOperatorFilterer.sol";

contract HoichiNft is Ownable, ERC721Enumerable, ReentrancyGuard, DefaultOperatorFilterer {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 369;
    bool public mintAllowed = false;

    string private _tokenBaseURI = "";
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public whitelist;

    uint256 public mintPrice = 0.1 ether;
    address public feeWallet = 0x441c0bC6A842E8F9f2d7B669E2cB5aBC70BA0933;

    event MintEnabled();
    event Mint(address indexed user, uint256 tokenId);
    event BaseURIUpdated(string uri);

    event SetFeeWallet(address wallet);
    event SetMintPrice(uint256 price);
    event SetWhiteList(address addr, bool enabled);
    event AdminTokenRecovered(address tokenRecovered, uint256 amount);

    modifier onlyMintable() {
        require(mintAllowed && totalSupply() < MAX_SUPPLY, "cannot mint");
        _;
    }

    constructor() ERC721("Hoichi", "HOICHI") {
        whitelist[address(0xdead)] = true;
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override (ERC721, IERC721)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override (ERC721, IERC721)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(whitelist[to] || balanceOf(to) == 0, "Receiver already hold token");
        super._transfer(from, to, tokenId);
    }

    function mint() external payable onlyMintable nonReentrant {
        require(balanceOf(msg.sender) == 0, "cannot mint more items");
        require(mintPrice <= msg.value, "insufficient mint fee");

        payable(feeWallet).transfer(mintPrice);
        if(msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }

        uint256 tokenId = totalSupply() + 1;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenId.toString());
        emit Mint(msg.sender, tokenId);

        if (totalSupply() == MAX_SUPPLY) mintAllowed = false;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Hoichi: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_baseURI(), _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function enableMint() external onlyOwner {
        require(!mintAllowed, "already enabled");

        mintAllowed = true;
        emit MintEnabled();
    }

    function setMintPrice(uint256 _price) external onlyOwner {
        mintPrice = _price;
        emit SetMintPrice(_price);
    }

    function setAdminWallet(address _wallet) external onlyOwner {
        require(_wallet != address(0x0), "invalid address");
        feeWallet = _wallet;
        emit SetFeeWallet(_wallet);
    }

    function setTokenBaseUri(string memory _uri) external onlyOwner {
        _tokenBaseURI = _uri;
        emit BaseURIUpdated(_uri);
    }

    function addToWhitelist(address _addr) external onlyOwner {
        require(_addr != address(0x0), "invalid address");
        whitelist[_addr] = true;
        emit SetWhiteList(_addr, true);
    }

    function removeFromWhitelist(address _addr) external onlyOwner {
        require(_addr != address(0x0), "invalid address");
        whitelist[_addr] = false;
        emit SetWhiteList(_addr, false);
    }

    function rescueTokens(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0x0)) {
            payable(msg.sender).transfer(_amount);
        } else {
            IERC20(_token).transfer(address(msg.sender), _amount);
        }

        emit AdminTokenRecovered(_token, _amount);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "BlocVest: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    receive() external payable {}
}