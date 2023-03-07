// SPDX-License-Identifier: Unlicensed

/**
 * @title: Jurassic Punks: OG-Rex
 * @author: Elevate Consulting
 *
 *      ____.                                 .__         __________              __
 *     |    |__ ______________    ______ _____|__| ____   \______   \__ __  ____ |  | __  ______
 *     |    |  |  \_  __ \__  \  /  ___//  ___/  |/ ___\   |     ___/  |  \/    \|  |/ / /  ___/
 * /\__|    |  |  /|  | \// __ \_\___ \ \___ \|  \  \___   |    |   |  |  /   |  \    <  \___ \
 * \________|____/ |__|  (____  /____  >____  >__|\___  >  |____|   |____/|___|  /__|_ \/____  >
 *                            \/     \/     \/        \/                       \/     \/     \/
 * ________    ________  __________
 * \_____  \  /  _____/  \______   \ ____ ___  ___
 *  /   |   \/   \  ___   |       _// __ \\  \/  /
 * /    |    \    \_\  \  |    |   \  ___/ >    <
 * \_______  /\______  /  |____|_  /\___  >__/\_ \
 *         \/        \/          \/     \/      \/
 */

pragma solidity ^0.8.6;

import "./ERC721A-OGREX.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract OGRex is ERC721A, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    /**
     * @dev CONTRACT STATES
     */
    enum State {
        Setup,
        Presale,
        Public,
        Closed
    }
    State private state;

    /**
     * @dev METADATA
     */
    string private baseURIString;

    /**
     * @dev MINT DETAILS
     */
    uint256 public immutable MAX_OGREX = 7777;
    uint256 public immutable RESERVED_OGREX = 807;
    uint256 public constant MAX_BATCH = 200;
    uint256 public immutable MAX_MINT = 5;
    uint256 public OGREX_PRICE = 0.10 ether;
    address private recipientWallet;
    uint256 private amountReserved;
    bool private reservedMinted;

    /**
     * @dev PRESALE TRACKING
     */
    uint256 public immutable MAX_PRESALE_MINT = 2;
    address private endorser;
    mapping(bytes => bool) public usedKey;
    mapping(address => bool) public presaleMinted;
    mapping(address => uint256) public walletPresaleTotalMinted;

    /**
     * @dev EVENTS
     */
    event ReserveMinted(
        address receiver,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 amount,
        bool reserveMinted
    );
    event Minted(
        address minter,
        uint256 fromTokenId,
        uint256 toTokenId,
        uint256 amount
    );
    event OGRexDetailsChanged(
        uint256 indexed tokenId,
        string name,
        string description
    );
    event BalanceWithdrawn(address receiver, uint256 value);

    constructor() ERC721A("JPunks: OG-Rex", "OGREX", MAX_BATCH) {
        state = State.Setup;
        baseURIString = "https://example.com/";
        recipientWallet = msg.sender;
        endorser = msg.sender;
    }

    /**
     * @notice Check token URI for given tokenId
     * @param tokenId OG Rex token ID
     * @return API endpoint for token metadata
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI(), Strings.toString(tokenId)));
    }

    /**
     * @notice Check the token URI
     * @return Base API endpoint for token metadata URI
     */
    function baseTokenURI() public view virtual returns (string memory) {
        return baseURIString;
    }

    /**
     * @notice Update the token URI for the contract
     * @param tokenUriBase_ New metadata endpoint to set for contract
     */
    function setTokenURI(string memory tokenUriBase_) public onlyOwner {
        baseURIString = tokenUriBase_;
    }

    /**
     * @notice Set a new receiving wallet address for ETH
     * @param newRecipient A new receipient wallet address
     */
    function setRecipientWallet(address newRecipient) public onlyOwner {
        recipientWallet = newRecipient;
    }

    /**
     * @notice Set a new signing wallet address for presale
     * @param newEndorser A new endorser wallet address
     */
    function setEndorser(address newEndorser) public onlyOwner {
        endorser = newEndorser;
    }

    /**
     * @notice Check current contract state
     * @return Current contract state
     */
    function contractState() public view virtual returns (State) {
        return state;
    }

    /**
     * @notice Set contract state to Setup
     */
    function setStateToSetup() public onlyOwner {
        state = State.Setup;
    }

    /**
     * @notice Set contract state to Presale
     */
    function setStateToPresale() public onlyOwner {
        state = State.Presale;
    }

    /**
     * @notice Set contract state to Public sale
     */
    function setStateToPublic() public onlyOwner {
        state = State.Public;
    }

    /**
     * @notice Set contract state to Closed
     */
    function setStateToClosed() public onlyOwner {
        state = State.Closed;
    }

    /**
     * @notice Only Owner function to mint reserved OG Rex
     * @param reserveAddress Address which reserved OG Rex will be minted to
     * @param amountToReserve Amount of reserved OG Rex to be minted
     */
    function mintReserve(address reserveAddress, uint256 amountToReserve)
        public
        onlyOwner
    {
        require(!reservedMinted, "Reserve minting has already been completed");
        require(
            amountReserved + amountToReserve <= RESERVED_OGREX,
            "Reserving too many OG Rex"
        );
        _safeMint(reserveAddress, amountToReserve);
        amountReserved = amountReserved + amountToReserve;
        if (amountReserved == RESERVED_OGREX) {
            reservedMinted = true;
        }
        uint256 firstOGRexReceived = totalSupply() - amountToReserve;
        uint256 lastOGRexReceived = totalSupply() - 1;
        emit ReserveMinted(
            reserveAddress,
            firstOGRexReceived,
            lastOGRexReceived,
            amountToReserve,
            reservedMinted
        );
    }

    /**
     * @notice Public mint function
     * @param amountOfOGRex Amount of OG Rex to be minted
     */
    function mintOGRex(uint256 amountOfOGRex)
        public
        payable
        virtual
        nonReentrant
    {
        address recipient = msg.sender;
        require(state == State.Public, "JPunks: OG Rex aren't available yet");
        require(
            totalSupply() + amountOfOGRex <= MAX_OGREX,
            "Sorry, there is not that many OG Rex left."
        );
        require(
            amountOfOGRex <= MAX_MINT,
            "You can only mint 5 OG Rex at a time."
        );
        require(
            msg.value >= OGREX_PRICE * amountOfOGRex,
            "You must send the proper value per OG Rex."
        );

        _safeMint(recipient, amountOfOGRex);
        forwardEth(recipientWallet);
        uint256 firstOGRexReceived = totalSupply() - amountOfOGRex;
        uint256 lastOGRexReceived = totalSupply() - 1;
        emit Minted(
            msg.sender,
            firstOGRexReceived,
            lastOGRexReceived,
            amountOfOGRex
        );
    }

    /**
     * @notice Function to change the name and description on an OG Rex
     * @param tokenId Token to update details
     * @param newName New name for token
     * @param newDescription New description for token
     */
    function changeOGRexDetails(
        uint256 tokenId,
        string memory newName,
        string memory newDescription
    ) public {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "This isn't your OG Rex");
        emit OGRexDetailsChanged(tokenId, newName, newDescription);
    }

    /**
     * @notice Only Owner Function to change OGREX_PRICE
     * @param newPrice The new price to set on contract
     */
    function setMintPricing(uint256 newPrice) public onlyOwner {
        OGREX_PRICE = newPrice;
    }

    /**
     * @notice Function to forward ETH directly to wallet on minting
     * @param to Address to forward ETH to
     */
    function forwardEth(address to) public payable {
        (bool sent, bytes memory data) = to.call{value: msg.value}("");
        data = "";
        require(sent, "Failed to send Ether");
    }

    /**
     * @notice Only Owner Function to withdraw ETH from contract
     * @param receiver Address to withdraw ETH to
     */
    function withdrawAllEth(address receiver) public virtual onlyOwner {
        uint256 balance = address(this).balance;
        payable(receiver).transfer(balance);
        emit BalanceWithdrawn(receiver, balance);
    }

    /**
     * @notice Function that creates hash from popToken and msgSender
     * @param popToken A random hex generated from signature
     * @param msgSender The wallet address of the message sender
     */
    function hashHexAddress(string calldata popToken, address msgSender)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(popToken, address(this), msgSender));
    }
}
