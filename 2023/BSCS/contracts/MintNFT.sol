// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BSCSNFT is
    ERC721,
    Pausable,
    Ownable,
    ERC721Burnable,
    ReentrancyGuard,
    ERC721Enumerable,
    ERC721URIStorage
{
    using SafeERC20 for IERC20;

    uint256 public mintFee = 5000 * 1e18;
    IERC20 public mintFeeToken;

    address public feeRecipient;
    uint256 totalFee;

    string public baseURI;
    string private _uriSuffix = ".json";

    mapping(uint256 => address) public nftToCreators;

    constructor(
        address owner,
        address _feeRecipient,
        address _mintFeeToken
    ) ERC721("BSCS NFT", "BSCSNFT") {
        super._transferOwnership(owner);
        mintFeeToken = IERC20(_mintFeeToken);
        feeRecipient = _feeRecipient;
        baseURI = "https://nft.bscs.finance/json/";
    }
    

    function setMintFee(uint256 _mintFee) public onlyOwner {
        mintFee = _mintFee;
    }

    function setmintFeeToken(address _mintFeeToken) public onlyOwner {
        mintFeeToken = IERC20(_mintFeeToken);
    }

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function contractURI() public view returns (string memory) {
        return "https://nft.bscs.finance/json/nftcollection.json";
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMintMany(
        address to,
        uint256 amount,
        uint256[] memory _tokenId
    ) public payable {
        uint256 feeRequire = amount * mintFee;

        require(
            amount == _tokenId.length,
            "Amount and amount of token id not match"
        );

        if (address(mintFeeToken) == address(0)) {
            require(msg.value == feeRequire, "Insufficient");
            (bool success, ) = payable(feeRecipient).call{ value: feeRequire }("");
            require(success, "Transfer failed");
        } else {
             require(
                mintFeeToken.balanceOf(_msgSender()) >= feeRequire,
                "Insufficient Balance"
            );
            require(
                mintFeeToken.allowance(_msgSender(), address(this)) >= feeRequire,
                "Insufficient Allowance"
            );
            require(
                mintFeeToken.transferFrom(_msgSender(), address(this), feeRequire),
                "transfer failed"
            );
        }
       
        totalFee += feeRequire;
        uint256 tokenId;
        string memory uri;
        for (uint8 i = 0; i < amount; i++) {
            tokenId = _tokenId[i];
            uri = string(
                abi.encodePacked(Strings.toString(_tokenId[i]), _uriSuffix)
            );
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uri);
            nftToCreators[tokenId] =  to;
        }
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function withdraw() public nonReentrant onlyOwner {
        mintFeeToken.safeTransfer(feeRecipient, totalFee);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
