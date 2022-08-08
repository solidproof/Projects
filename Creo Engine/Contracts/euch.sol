// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";




contract EUCH is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(address => bool) public isGovernance;
    uint public GatchaMinLevel=0;
    uint public GatchaFee=0;
    string GlobalUri;
    address ChestAddress;



    mapping(uint256 => mapping(address => bool)) private _isNftExempt;

    modifier onlyAdmin() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(isGovernance[msg.sender] == true, "Caller is not governance");
        _;
    }


    constructor() ERC721("EK Origin UN Character", "EUCH") {
        isGovernance[msg.sender]=true;
        GlobalUri="https://www.creoplay/nft/1/";
    }

    function isNftExempt(uint256 tokenId, address wallet) public view returns (bool) {
        return _isNftExempt[tokenId][wallet];
    }

    function setNFTExempt(uint256 tokenId, address wallet, bool status) public onlyOwner{
        require(_isNftExempt[tokenId][wallet] != status, "NFT and wallet already in status");
        _isNftExempt[tokenId][wallet]=status;
    }

    function addGovernance(address addr) public onlyOwner{
        isGovernance[addr]=true;
    }
    function removeGovernance(address addr) public onlyOwner{
        isGovernance[addr]=false;
    }

    function isAdmin(address addr) public view returns (bool){
        return isGovernance[addr];
    }

    function bulkMint(address to, uint amount) public onlyAdmin{
        for(uint i=0; i<amount; i++){
            uint256 tokenId = _tokenIdCounter.current()+1;
            string memory tid=Strings.toString(tokenId);
            string memory urii=string(abi.encodePacked(GlobalUri,tid));

            _safeMint(to, tokenId);
            _setTokenURI(tokenId, urii);
            _tokenIdCounter.increment();
        }
    }

    function bulkTransfer(uint256[] memory tokenIds, address _to) public {
        // uint256 length = tokenIds.length;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _transfer(msg.sender, _to, tokenIds[i]);
        }
    }

    function safeMint(address to, uint tipe) public {
        IERC1155 ChestToken=IERC1155(ChestAddress);
        require(ChestToken.balanceOf(to,tipe)>0,"No Key Available");

        ChestToken.safeTransferFrom(msg.sender, address(this),tipe, 1, "0x00");

        uint256 tokenId = _tokenIdCounter.current()+1;
        string memory tid=Strings.toString(tokenId);
        string memory urii=string(abi.encodePacked(GlobalUri,tid));
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, urii);
        _tokenIdCounter.increment();
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )external returns(bytes4){
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        // if(_owner != _msgSender()){

        // }
        // require(_isNftExempt[tokenId][from],"Not Allowed To Transfer");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function setChestAddress(address addr)public onlyAdmin{
        ChestAddress=addr;
    }

    function setGlobalURI(string memory uri) public onlyAdmin{
        GlobalUri=uri;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }


    function withdrawLeftOverBalance() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }
}