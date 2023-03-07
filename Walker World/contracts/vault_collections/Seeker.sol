// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import "./ERC721A-SEEKER.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Seeker is ERC721A, ReentrancyGuard, Ownable {
    using ECDSA for bytes32;
    using Address for address;

    enum State {
        Setup,
        PublicSale,
        Finished
    }

    struct WhitelistDiscount {
        // The number of discounts available for a user in the whitelist.
        // Applying a discount changes the mint price to 0.09 ETH.
        uint16 discounts;
        // The number of full discounts available for a user in the whitelist.
        // Applying this makes the mint price 0 ETH.
        uint16 fullDiscounts;
    }

    State private _state;
    address private _signer;
    address public _beneficiaryWallet;
    string private _tokenUriBase;
    uint256 private _saleStart;
    uint256 public _baseMintLimit;

    uint256 public constant INITIAL_SEEKER_SUPPLY = 50000;
    uint256 public constant MINIMUM_SEEKER_SUPPLY = 10101;
    uint256 private constant SEEKERS_PRICE = 0.10101 ether;
    uint256 private constant DISCOUNT_PRICE = 0.09 ether;

    mapping(uint256 => mapping(address => bool)) private _mintedInBlock;
    mapping(bytes => bool) public usedToken;

    mapping(address => WhitelistDiscount) public remainingDiscounts;

    event Minted(address minter, uint256 fromTokenId, uint256 amount);

    event StateChanged(State _state);

    constructor(
        address signer,
        address beneficiaryWallet,
        uint256 baseMintLimit
    ) ERC721A("Seekers", "SEEKERS") {
        _signer = signer;
        _state = State.Setup;
        _beneficiaryWallet = beneficiaryWallet;
        _baseMintLimit = baseMintLimit;
    }

    function updateBeneficiaryWallet(address _wallet) external onlyOwner {
        _beneficiaryWallet = _wallet;
    }

    function updateSigner(address __signer) external onlyOwner {
        _signer = __signer;
    }

    function _hash(string calldata salt, address _address)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(salt, address(this), _address));
    }

    function _verify(bytes32 hash, bytes memory token)
        public
        view
        returns (bool)
    {
        return (_recover(hash, token) == _signer);
    }

    function _recover(bytes32 hash, bytes memory token)
        public
        pure
        returns (address)
    {
        return hash.toEthSignedMessageHash().recover(token);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI(), Strings.toString(tokenId)));
    }

    function baseTokenURI() public view virtual returns (string memory) {
        return _tokenUriBase;
    }

    function setTokenURI(string memory tokenUriBase_) external onlyOwner {
        _tokenUriBase = tokenUriBase_;
    }

    function getState() external view returns (State) {
        return _state;
    }

    function setStateToSetup() external onlyOwner {
        _state = State.Setup;
        emit StateChanged(_state);
    }

    function setStateToPublicSale() external onlyOwner {
        require(_saleStart == 0, "public sale can not be started again");

        _state = State.PublicSale;
        _saleStart = block.timestamp;
        emit StateChanged(_state);
    }

    function setStateToFinished() external onlyOwner {
        _state = State.Finished;
        emit StateChanged(_state);
    }

    function mint(
        //string calldata salt,
        bytes calldata token,
        uint256 amount
    ) external payable nonReentrant {
        require(!usedToken[token], "The token has been used.");
        //require(_verify(_hash(salt, msg.sender), token), "Invalid token.");

        //_mint(amount, amount * SEEKERS_PRICE);
        _mint(amount, 0);

        usedToken[token] = true;
    }

    function discountedMint(
        WhitelistDiscount calldata whitelistSpot,
        bytes calldata token,
        uint16 discounts,
        uint16 fullDiscounts,
        uint256 amount
    ) external payable nonReentrant {
        require(
            discounts + fullDiscounts > 0,
            "discounted mint requires at least one discount"
        );

        require(
            discounts + fullDiscounts <= amount,
            "can not use more discounts than amount"
        );

        WhitelistDiscount memory remaining = remainingDiscounts[msg.sender];

        // this is the first time that a discounted mint has occured for the sender
        if (remaining.discounts == 0 && remaining.fullDiscounts == 0) {
            // To differentiate between the map value never being set vs
            // all discounts used, we add 1 to the remaining, and we then
            // consider a value of 0 as never set, and 1 as all used.
            remaining.discounts = whitelistSpot.discounts + 1;
            remaining.fullDiscounts = whitelistSpot.fullDiscounts + 1;
        }

        // verify that the sender has enough discounts still available
        require(
            remaining.discounts >= discounts + 1,
            "more discounts specified than there is remaining"
        );
        require(
            remaining.fullDiscounts >= fullDiscounts + 1,
            "more full discounts specified than there is remaining"
        );

        // verify the whitelist spot is valid
        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
                whitelistSpot.discounts,
                whitelistSpot.fullDiscounts,
                remaining.discounts + remaining.fullDiscounts - 2 // subtract 2 here because we added 1 to each counter before
            )
        );
        require(_verify(message, token), "Invalid token.");

        uint256 fullPricedSeekers = amount - (discounts + fullDiscounts);

        uint256 price = discounts *
            DISCOUNT_PRICE +
            fullPricedSeekers *
            SEEKERS_PRICE;

        _mint(amount, price);

        remaining.discounts = remaining.discounts - discounts;
        remaining.fullDiscounts = remaining.fullDiscounts - fullDiscounts;
        remainingDiscounts[msg.sender] = remaining;
    }

    function _mint(uint256 amount, uint256 price) internal {
        require(_state == State.PublicSale, "public sale is not active.");

        uint256 maxSupply = getCurrentSupply();
        uint256 totalSupply = totalSupply();
        require(
            totalSupply + amount <= maxSupply,
            "Amount should not exceed current max supply of Seekers."
        );

        require(amount <= _baseMintLimit, "can not exceed max mint limit");
        require(msg.sender == tx.origin, "mint from contract not allowed");
        require(
            !Address.isContract(msg.sender),
            "contracts are not allowed to mint"
        );

        require(
            _mintedInBlock[block.number][msg.sender] == false,
            "already minted in this block"
        );

        require(msg.value >= price, "ether value sent is incorrect");

        _mintedInBlock[block.number][msg.sender] = true;

        _safeMint(msg.sender, amount);
        forwardEther(_beneficiaryWallet);

        uint256 fromTokenId = totalSupply + 1;
        emit Minted(msg.sender, fromTokenId, amount);
    }

    function getCurrentSupply() public view returns (uint256) {
        if (_saleStart == 0) {
            return INITIAL_SEEKER_SUPPLY;
        }

        uint256 timeElapsed = block.timestamp - _saleStart;

        uint256 maximumDecrease = INITIAL_SEEKER_SUPPLY - MINIMUM_SEEKER_SUPPLY;

        uint256 decreasedAmount = (maximumDecrease * timeElapsed) / 24 hours;

        if (decreasedAmount > maximumDecrease) {
            return MINIMUM_SEEKER_SUPPLY;
        } else {
            return INITIAL_SEEKER_SUPPLY - decreasedAmount;
        }
    }

    function forwardEther(address _to) public payable {
        (bool sent, bytes memory data) = _to.call{value: msg.value}("");
        data = "";
        require(sent, "Failed to send Ether");
    }

    function withdrawAll(address recipient) public onlyOwner {
        uint256 balance = address(this).balance;
        payable(recipient).transfer(balance);
    }

    function withdrawAllViaCall(address payable _to) public onlyOwner {
        uint256 balance = address(this).balance;
        (bool sent, bytes memory data) = _to.call{value: balance}("");
        data = "";
        require(sent, "Failed to send Ether");
    }
}
