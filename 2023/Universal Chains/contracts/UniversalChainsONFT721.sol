// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "@layerzerolabs/solidity-examples/contracts/token/onft/ONFT721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// ██╗░░░██╗███╗░░██╗██╗██╗░░░██╗███████╗██████╗░░██████╗░█████╗░██╗░░░░░
// ██║░░░██║████╗░██║██║██║░░░██║██╔════╝██╔══██╗██╔════╝██╔══██╗██║░░░░░
// ██║░░░██║██╔██╗██║██║╚██╗░██╔╝█████╗░░██████╔╝╚█████╗░███████║██║░░░░░
// ██║░░░██║██║╚████║██║░╚████╔╝░██╔══╝░░██╔══██╗░╚═══██╗██╔══██║██║░░░░░
// ╚██████╔╝██║░╚███║██║░░╚██╔╝░░███████╗██║░░██║██████╔╝██║░░██║███████╗
// ░╚═════╝░╚═╝░░╚══╝╚═╝░░░╚═╝░░░╚══════╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝╚══════╝

// ░█████╗░██╗░░██╗░█████╗░██╗███╗░░██╗░██████╗
// ██╔══██╗██║░░██║██╔══██╗██║████╗░██║██╔════╝
// ██║░░╚═╝███████║███████║██║██╔██╗██║╚█████╗░
// ██║░░██╗██╔══██║██╔══██║██║██║╚████║░╚═══██╗
// ╚█████╔╝██║░░██║██║░░██║██║██║░╚███║██████╔╝
// ░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝╚═════╝░

contract UniversalChainsONFT721 is ONFT721, ERC721Enumerable {
    /**********/
    /* ERRORS */
    /**********/

    error UniversalChainsONFT721_MaxLimitReached();
    error UniversalChainsONFT721_ReferrerCannotBeSender();
    error UniversalChainsONFT721_IncorrectMintingFee();
    error UniversalChainsONFT721_NoEarningsToClaim();
    error UniversalChainsONFT721_OnlyProtocolAddressCanClaim();
    error UniversalChainsONFT721_TokenURIIsLocked();

    /**********/
    /* EVENTS */
    /**********/

    event MintingFeeUpdated(
        uint256 indexed oldMintingFee,
        uint256 indexed newMintingFee
    );
    event ProtocolAddressUpdated(
        address indexed oldProtocolAddress,
        address indexed newProtocolAddress
    );
    event ONFTMinted(
        address indexed minter,
        address indexed referrer,
        uint256 indexed mintId,
        uint256 referralEarnings,
        uint256 protocolEarnings
    );
    event EarningsClaimed(address indexed claimer, uint256 amount);
    event ProtocolEarningsClaimed(
        address indexed protocolAddress,
        uint256 amount
    );
    event TokenURIUpdated(
        string indexed oldTokenURI,
        string indexed newTokenURI
    );
    event TokenURILocked();

    /*************/
    /* CONSTANTS */
    /*************/

    uint public DENOMINATOR = 10000;
    uint256 public constant REFERRAL_EARNINGS_SHARE_BIPS = 1000; // 10% of the referral earnings

    /**********/
    /* STATES */
    /**********/

    uint public nextMintId;
    uint public maxMintId;

    uint256 public amountMinted;

    uint256 public mintingFee;
    address public protocolAddress;

    mapping(address => uint256) public referralEarningsOpen;
    mapping(address => uint256) public referralEarningsClaimed;
    mapping(address => uint256) public amountOfMintsWithReferrer;

    uint256 public protocolEarningsOpen;
    uint256 public protocolEarningsClaimed;

    string private currentTokenURI;
    bool public isTokenURILocked;

    /*****************/
    /*  CONSTRUCTOR  */
    /*****************/

    /// @notice Constructor for the UniversalONFT
    /// @param _layerZeroEndpoint handles message transmission across chains
    /// @param _startMintId the starting mint number on this chain
    /// @param _endMintId the max number of mints on this chain
    constructor(
        uint256 _minGasToTransfer,
        address _layerZeroEndpoint,
        uint _startMintId,
        uint _endMintId,
        uint256 _mintingFee,
        address _protocolAddress
    ) ONFT721("OmniRock Edicts", "ORE", _minGasToTransfer, _layerZeroEndpoint) {
        nextMintId = _startMintId;
        maxMintId = _endMintId;
        mintingFee = _mintingFee;
        protocolAddress = _protocolAddress;
    }

    /***********/
    /*  ADMIN  */
    /***********/

    /// @notice Update the minting fee
    /// @param _mintingFee the new minting fee
    function setMintingFee(uint256 _mintingFee) external onlyOwner {
        uint256 oldMintingFee = mintingFee;
        mintingFee = _mintingFee;
        emit MintingFeeUpdated(oldMintingFee, _mintingFee);
    }

    /// @notice Set the protocol address
    /// @param _protocolAddress the new protocol address
    function setProtocolAddress(address _protocolAddress) external onlyOwner {
        address oldProtocolAddress = protocolAddress;
        protocolAddress = _protocolAddress;
        emit ProtocolAddressUpdated(oldProtocolAddress, _protocolAddress);
    }

    /// @notice Sets the URI for the token
    /// @dev If the tokenURI is locked, this function reverts
    /// @param newtokenURI The URI to be set
    function setTokenURI(string memory newtokenURI) external onlyOwner {
        string memory oldTokenURI = currentTokenURI;

        if (isTokenURILocked) {
            revert UniversalChainsONFT721_TokenURIIsLocked();
        }
        currentTokenURI = newtokenURI;

        emit TokenURIUpdated(oldTokenURI, newtokenURI);
    }

    /// @notice Locks the token URI, preventing future changes
    /// @dev Once locked, the tokenURI cannot be changed again
    function lockTokenURI() external onlyOwner {
        if (isTokenURILocked) {
            revert UniversalChainsONFT721_TokenURIIsLocked();
        }
        isTokenURILocked = true;

        emit TokenURILocked();
    }

    /**********/
    /*  MINT  */
    /**********/

    function mint() external payable {
        mint(address(0));
    }

    /// @notice Mint your ONFT with a referral. If the referrer address is the zero address,
    ///         the minting fee will go entirely to the protocol, and no referral earnings will be calculated or stored.
    /// @param referrer The address of the referrer, or the zero address to skip the referral program
    function mint(address referrer) public payable {
        if (nextMintId > maxMintId) {
            revert UniversalChainsONFT721_MaxLimitReached();
        }
        if (referrer == _msgSender()) {
            revert UniversalChainsONFT721_ReferrerCannotBeSender();
        }
        if (msg.value != mintingFee) {
            revert UniversalChainsONFT721_IncorrectMintingFee();
        }

        amountMinted++;
        uint newId = nextMintId;
        nextMintId++;

        uint256 referrerEarnings = 0;
        uint256 ownerEarnings = mintingFee;
        if (referrer != address(0)) {
            amountOfMintsWithReferrer[referrer]++;
            referrerEarnings =
                (mintingFee * REFERRAL_EARNINGS_SHARE_BIPS) /
                DENOMINATOR; // 10% of the minting fee

            ownerEarnings = mintingFee - referrerEarnings; // 90% of the minting fee
            referralEarningsOpen[referrer] += referrerEarnings;
        }

        protocolEarningsOpen += ownerEarnings;

        _safeMint(_msgSender(), newId);

        emit ONFTMinted(
            _msgSender(),
            referrer,
            newId,
            referrerEarnings,
            ownerEarnings
        );
    }

    /***********/
    /*  CLAIM  */
    /***********/

    /// @notice Claim referral earnings
    function claimEarnings() external {
        uint256 earnings = referralEarningsOpen[_msgSender()];
        if (earnings == 0) {
            revert UniversalChainsONFT721_NoEarningsToClaim();
        }

        referralEarningsOpen[_msgSender()] = 0;
        referralEarningsClaimed[_msgSender()] += earnings;
        payable(_msgSender()).transfer(earnings);

        emit EarningsClaimed(_msgSender(), earnings);
    }

    /// @notice Claim protocol earnings
    function claimProtocolEarnings() external {
        if (_msgSender() != protocolAddress) {
            revert UniversalChainsONFT721_OnlyProtocolAddressCanClaim();
        }
        uint256 earnings = protocolEarningsOpen;
        if (earnings == 0) {
            revert UniversalChainsONFT721_NoEarningsToClaim();
        }

        protocolEarningsOpen = 0;
        protocolEarningsClaimed += earnings;
        payable(protocolAddress).transfer(earnings);

        emit ProtocolEarningsClaimed(protocolAddress, earnings);
    }

    /**********************/
    /*  ERC721Enumerable  */
    /**********************/

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721Enumerable, ONFT721) returns (bool) {
        return
            interfaceId == type(IONFT721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**********/
    /*  VIEW  */
    /**********/

    /// @notice Get the URI
    /// @dev This function is overridden to return the currentTokenURI variable
    /// @dev The URI is always the same for all tokens
    /// @return the URI
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        tokenId;
        return currentTokenURI;
    }
}