// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CryptowalkersWeapons is ERC721, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using MerkleProof for bytes32[];
    enum State {
        Admin,
        Public,
        Paused
    }
    State private activeState;
    string private _baseTokenURI;
    uint256 private constant _reserve = 502;
    uint256 private _vault;
    uint256 public constant freeSupply = 2301;
    uint256 public freeSupplyMinted;
    uint256 public constant mainsaleSupply = 3501;
    uint256 public mainsaleSupplyMinted;
    uint256 public constant collectionSize = 6301;
    bool public freeMintActive;
    uint256 public constant maxMint = 6;
    uint256 public constant maxPerWallet = 11;
    uint256 public constant maxfreeMint = 10;
    uint256 public tokenSupply;
    bytes32 public rootHash;
    uint256 public constant price = 0.03 ether;
    mapping(address => uint256) public mintedTokens;
    mapping(address => bool) public claimedFreeMints;

    constructor() ERC721("CryptowalkersWeapons", "CWW") {
        activeState = State.Admin;
        _baseTokenURI = "https://example.com/";
        _vault = 1;
        freeSupplyMinted = 1;
        mainsaleSupplyMinted = 1;
        freeMintActive = false;
        tokenSupply = 1;
        rootHash = 0xb51882ff364a2e57b69de4c1e74df3af89859a5b3ee1605bedf812871737f0b1;
    }

    function verifyValidity(
        address _addr,
        uint256 _amt,
        bytes32[] memory _proof
    ) public view returns (bool) {
        return
            _proof.verify(
                rootHash,
                keccak256(abi.encodePacked(uint256(uint160(_addr)), _amt))
            );
    }

    function calculateAllocation(uint256 _amt) internal pure returns (uint256) {
        uint256 _rv = 1;
        if (_amt > 19) {
            _rv = _amt / 10;
        }
        return _rv;
    }

    function safeMint(
        address _addr,
        uint256 _amt,
        uint256 _supply
    ) internal {
        tokenSupply += _amt;
        for (uint256 i = 0; i < _amt; i++) {
            _safeMint(_addr, _supply + i);
        }
    }

    function freeMint(uint256 _holdings, bytes32[] memory _proof)
        external
        payable
        nonReentrant
    {
        require(
            activeState == State.Public && freeMintActive,
            "Free mint is not active"
        );
        require(
            _holdings > 0 && verifyValidity(msg.sender, _holdings, _proof),
            "Not authorized"
        );
        uint256 _supply = tokenSupply;
        uint256 _amt = calculateAllocation(_holdings);
        require(
            freeSupplyMinted + _amt < freeSupply &&
                _supply + _amt < collectionSize,
            "Free mint supply has been minted"
        );
        require(_amt < maxfreeMint, "Exceeds max mints per transaction");
        require(!claimedFreeMints[msg.sender], "Already claimed free mints");
        claimedFreeMints[msg.sender] = true;
        freeSupplyMinted += _amt;
        safeMint(msg.sender, _amt, _supply);
    }

    function msMint(
        uint256 _holdings,
        uint256 _amt,
        bytes32[] memory _proof
    ) external payable nonReentrant {
        require(activeState == State.Public, "Mainsale is not active");
        uint256 _supply = tokenSupply;
        require(
            mainsaleSupplyMinted + _amt < mainsaleSupply &&
                _supply + _amt < collectionSize,
            "Mainsale supply has been minted"
        );
        require(_amt < maxMint, "Exceeds max mints per transaction");
        require(
            verifyValidity(msg.sender, _holdings, _proof),
            "Not authorized"
        );
        require(
            mintedTokens[msg.sender] + _amt < maxPerWallet,
            "Exceeded mint allocation"
        );
        require(msg.value == price * _amt, "Incorrect price");
        mintedTokens[msg.sender] += _amt;
        mainsaleSupplyMinted += _amt;
        safeMint(msg.sender, _amt, _supply);
    }

    function adminMint(uint256 _amt) external nonReentrant onlyOwner {
        require(activeState == State.Admin, "State must be set to admin");
        uint256 _supply = tokenSupply;
        uint256 _supplyAndAmt = _supply + _amt;
        require(
            _supplyAndAmt < collectionSize && _vault + _amt < _reserve,
            "Not enough tokens remaining in supply"
        );
        _vault += _amt;
        safeMint(msg.sender, _amt, _supply);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return
            bytes(_baseTokenURI).length > 0
                ? string(abi.encodePacked(_baseTokenURI, tokenId.toString()))
                : "";
    }

    function baseTokenURI() public view virtual returns (string memory) {
        return _baseTokenURI;
    }

    function updateBaseURI(string memory _newURI) external onlyOwner {
        _baseTokenURI = _newURI;
    }

    function enableFreeMint() external onlyOwner {
        freeMintActive = true;
    }

    function disableFreeMint() external onlyOwner {
        freeMintActive = false;
    }

    function getSate() external view returns (State) {
        return activeState;
    }

    function setStateToAdmin() external onlyOwner {
        activeState = State.Admin;
    }

    function setStateToPublic() external onlyOwner {
        activeState = State.Public;
    }

    function setStateToPaused() external onlyOwner {
        activeState = State.Paused;
    }

    function totalSupply() external view returns (uint256) {
        return tokenSupply - 1;
    }

    function withdrawAll() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
