// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @title Cryptowalkers Females
/// @author continuumlabs.io

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "erc721a/contracts/ERC721A.sol";
import "closedsea/src/OperatorFilterer.sol";

contract CryptowalkersFemales is
    ERC721A,
    OperatorFilterer,
    ERC2981,
    Ownable,
    ReentrancyGuard
{
    using MerkleProof for bytes32[];
    enum State {
        Admin,
        EarlyBird,
        Presale,
        Public,
        Paused
    }
    uint64 public maxSupply = 6545; /// @notice The available total supply will decrease the longer the sale is open
    uint64 public constant RESERVE = 200;
    uint64 public constant MAX_PER_TX = 10;
    uint64 public constant MAX_PER_ADDR = 20;
    uint64 public constant PRICE = 0.069 ether;
    uint64 public constant MAX_SUPPLY_DECREMENT = 300;
    uint64 public constant MAX_VAULT_SUPPLY = 1625; /// @notice The amount that will be minted to vault for eligible CW holders to claim their CWFs
    State private activeState;
    string private tokenBaseURI;
    bytes32 public rootHash;
    address public vaultAddress;
    uint64 public reserveMinted;
    bool public operatorFilteringEnabled;
    enum PresaleGroup {
        EarlyBird,
        General
    }

    constructor() ERC721A("CryptowalkersFemales", "CWF") {
        tokenBaseURI = "https://example.com/";
        activeState = State.Admin;
        _registerForOperatorFiltering();
        operatorFilteringEnabled = true;
    }

    /// @notice Using function modifiers to reduce the repetitive require checks in subsequent functions
    modifier verifyAdminState(State _requiredState) {
        require(activeState == _requiredState, "State must be set to admin");
        _;
    }
    modifier verifyPrice(uint64 _amt) {
        require(msg.value == PRICE * _amt, "Incorrect price");
        _;
    }
    modifier verifyTotalSupply(uint64 _amt) {
        require(totalSupply() + _amt <= maxSupply, "Exceeds max supply");
        _;
    }

    function setVault(address _vaultAddress)
        external
        onlyOwner
        verifyAdminState(State.Admin)
    {
        require(_vaultAddress != address(0x0));
        vaultAddress = _vaultAddress;
    }

    function setRootHash(bytes32 _newHash)
        external
        onlyOwner
        verifyAdminState(State.Admin)
    {
        rootHash = _newHash;
    }

    function verifyAddr(
        address _addr,
        uint256 _presaleGroup,
        uint256 _spots,
        bytes32[] calldata _proof
    ) internal view returns (bool) {
        return
            _proof.verifyCalldata(
                rootHash,
                keccak256(
                    abi.encodePacked(
                        uint256(uint160(_addr)),
                        _presaleGroup,
                        _spots
                    )
                )
            );
    }

    function mintReserve(uint64 _amt)
        external
        onlyOwner
        verifyAdminState(State.Admin)
    {
        require(reserveMinted + _amt <= RESERVE, "Max reserve minted");
        reserveMinted += _amt;
        _mint(msg.sender, _amt);
    }

    function mintToVault(uint64 _amt)
        external
        onlyOwner
        verifyAdminState(State.Admin)
    {
        require(
            totalSupply() + _amt <= MAX_VAULT_SUPPLY,
            "Exceeds max amount allocated for vault"
        );
        _mint(vaultAddress, _amt);
    }

    function presaleMint(
        PresaleGroup _presaleGroup,
        uint64 _spots,
        uint64 _amt,
        bytes32[] calldata _proof
    ) external payable nonReentrant verifyPrice(_amt) verifyTotalSupply(_amt) {
        require(
            activeState == State.EarlyBird || activeState == State.Presale,
            "Presale inactive"
        );

        /// @dev Use ERC721A's existing available _numberMinted to verify spots minted
        require(
            _spots >= (_amt + _numberMinted(msg.sender)),
            "You've exceeded your max spots for presale"
        );

        if (activeState == State.EarlyBird) {
            require(
                _presaleGroup == PresaleGroup.EarlyBird &&
                    verifyAddr(
                        msg.sender,
                        uint256(_presaleGroup),
                        _spots,
                        _proof
                    ),
                "Not authorized. Must be in early bird group."
            );
        } else {
            require(
                (_presaleGroup == PresaleGroup.EarlyBird ||
                    _presaleGroup == PresaleGroup.General) &&
                    verifyAddr(
                        msg.sender,
                        uint256(_presaleGroup),
                        _spots,
                        _proof
                    ),
                "Not authorized. Must be in early bird or general group."
            );
        }
        _mint(msg.sender, _amt);
    }

    function mint(uint64 _amt)
        external
        payable
        nonReentrant
        verifyPrice(_amt)
        verifyTotalSupply(_amt)
    {
        require(activeState == State.Public, "Public sale inactive");
        require(_amt <= MAX_PER_TX, "Exceeds max per tx");
        require(
            (_amt + _numberMinted(msg.sender)) <= MAX_PER_ADDR,
            "Exceeds max per wallet"
        );
        _mint(msg.sender, _amt);
    }

    function decreaseSupply(uint64 _amt) external onlyOwner {
        require(_amt <= MAX_SUPPLY_DECREMENT, "Exceeds max decrement amount");
        require(
            (maxSupply - _amt) >= totalSupply(),
            "Cannot decrease max supply beyond total supply"
        );
        maxSupply -= _amt;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return tokenBaseURI;
    }

    function setBaseURI(string calldata _newURI)
        external
        onlyOwner
        verifyAdminState(State.Admin)
    {
        tokenBaseURI = _newURI;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function getState() external view returns (State) {
        return activeState;
    }

    function setStateToAdmin() external onlyOwner {
        activeState = State.Admin;
    }

    function setStateToEarlyBird() external onlyOwner {
        activeState = State.EarlyBird;
    }

    function setStateToPresale() external onlyOwner {
        activeState = State.Presale;
    }

    function setStateToPublic() external onlyOwner {
        activeState = State.Public;
    }

    function setStateToPaused() external onlyOwner {
        activeState = State.Paused;
    }

    function getMintedByAddress(address _user) external view returns (uint256) {
        return _numberMinted(_user);
    }

    function withdrawAll(uint256 amountPercentage) external onlyOwner {
        require(
            0 < amountPercentage && amountPercentage <= 100,
            "Requested percentage of contract balance not within acceptable range, [0,100]."
        );
        uint256 withdrawAmt = (amountPercentage * address(this).balance) / 100;
        (bool success, ) = msg.sender.call{value: withdrawAmt}("");
        require(success, "Transfer failed.");
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /// @dev Below functions are to satisfy marketplace creator fee enforement requirements
    function repeatRegistration() public {
        if (_operatorFilteringEnabled()) {
            _registerForOperatorFiltering();
        }
    }

    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        payable
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function setOperatorFilteringEnabled(bool value) public onlyOwner {
        operatorFilteringEnabled = value;
    }

    function _operatorFilteringEnabled()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return operatorFilteringEnabled;
    }
}
