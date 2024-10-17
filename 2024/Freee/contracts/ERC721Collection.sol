// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC721AUpgradeable} from "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/contracts/IERC721AUpgradeable.sol";
import {IERC2981Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {IMetadataRenderer} from "./interfaces/IMetadataRenderer.sol";
import {IERC721Collection} from "./interfaces/IERC721Collection.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IERC4906} from "./interfaces/IERC4906.sol";
import {IFactoryUpgradeGate} from "./interfaces/IFactoryUpgradeGate.sol";
import {OwnableSkeleton} from "./utils/OwnableSkeleton.sol";
import {FundsReceiver} from "./utils/FundsReceiver.sol";
import {Version} from "./utils/Version.sol";
import {PublicMulticall} from "./utils/PublicMulticall.sol";
import {ERC721CollectionStorageV1} from "./storage/ERC721CollectionStorageV1.sol";

/**
 * @notice Freee NFT Base contract for collection
 */
contract ERC721Collection is
    ERC721AUpgradeable,
    UUPSUpgradeable,
    IERC2981Upgradeable,
    IERC4906,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    IERC721Collection,
    PublicMulticall,
    OwnableSkeleton,
    FundsReceiver,
    Version(1),
    ERC721CollectionStorageV1
{
    /// @dev This is the max mint batch size for the optimized ERC721A mint contract
    uint256 internal immutable MAX_MINT_BATCH_SIZE = 8;

    /// @dev Gas limit to send funds
    uint256 internal immutable FUNDS_SEND_GAS_LIMIT = 210_000;

    /// @dev This is the max number of presale stage allowed
    uint256 internal immutable PRESALE_STAGES_ALLOWED = 5;

    /// @notice Access control roles
    bytes32 public immutable MINTER_ROLE = keccak256("MINTER");
    bytes32 public immutable SALES_MANAGER_ROLE = keccak256("SALES_MANAGER");

    /// @dev Factory upgrade gate
    IFactoryUpgradeGate public immutable factoryUpgradeGate;

    /// @notice Freee Mint Fee
    uint256 private immutable MINT_FEE;

    /// @notice Mint Fee Recipient
    address payable private immutable MINT_FEE_RECIPIENT;

    /// @notice Max royalty BPS
    uint16 constant MAX_ROYALTY_BPS = 50_00;

    // /// @notice Empty string for blank comments
    // string constant EMPTY_STRING = "";

    /// @notice Only allow for users with admin access
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert Access_OnlyAdmin();
        }

        _;
    }

    /// @notice Only a given role has access or admin
    /// @param role role to check for alongside the admin role
    modifier onlyRoleOrAdmin(bytes32 role) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) && !hasRole(role, _msgSender())) {
            revert Access_MissingRoleOrAdmin(role);
        }

        _;
    }

    /// @notice Allows user to mint tokens at a quantity
    modifier canMintTokens(uint256 quantity) {
        if (quantity + _totalMinted() > config.collectionSize) {
            revert Mint_SoldOut();
        }

        _;
    }

    function _presaleActive(uint256 stageIndex) internal view returns (bool) {
        return 
            presaleConfig[stageIndex].presaleStart > 0 && 
            presaleConfig[stageIndex].presaleStart <= block.timestamp && 
            presaleConfig[stageIndex].presaleEnd > block.timestamp;
    }

    function _publicSaleActive() internal view returns (bool) {
        return 
            publicSaleConfig.publicSaleStart > 0 &&
            publicSaleConfig.publicSaleStart <= block.timestamp && 
            publicSaleConfig.publicSaleEnd > block.timestamp;
    }

    /// @notice Presale active
    modifier onlyPresaleActive(uint256 stagIndex) {
        if (!_presaleActive(stagIndex)) {
            revert Presale_Inactive();
        }

        _;
    }

    /// @notice Public sale active
    modifier onlyPublicSaleActive() {
        if (!_publicSaleActive()) {
            revert Sale_Inactive();
        }

        _;
    }

    /// @notice Can transfer token
    modifier canTradeToken() {
        bool mintedOut = config.collectionSize == uint64(_totalMinted());
        if (config.lockBeforeMintOut && !mintedOut) {
            revert Collection_TradingLocked();
        }

        _;
    }

    /// @notice Getter for last minted token ID (gets next token id and subtracts 1)
    function _lastMintedTokenId() internal view returns (uint256) {
        return _currentIndex - 1;
    }

    /// @notice Start token ID for minting (1-100 vs 0-99)
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    /// @notice Global constructor – these variables will not change with further proxy deploys
    /// @dev Marked as an initializer to prevent storage being used of base implementation. Can only be init'd by a proxy.
    /// @param _factoryUpgradeGate Factory upgrade gate address
    /// @param _mintFeeAmount Mint fee amount in wei
    /// @param _mintFeeRecipient Mint fee recipient address
    constructor(IFactoryUpgradeGate _factoryUpgradeGate, uint256 _mintFeeAmount, address payable _mintFeeRecipient) initializer {
        factoryUpgradeGate = _factoryUpgradeGate;
        MINT_FEE = _mintFeeAmount;
        MINT_FEE_RECIPIENT = _mintFeeRecipient;
    }

    ///  @dev Create a new collection contract
    ///  @param _contractName Contract name
    ///  @param _contractSymbol Contract symbol
    ///  @param _initialOwner User that owns and can mint the collection, gets royalty and sales payouts and can update the base url if needed.
    ///  @param _fundsRecipient Wallet/user that receives funds from sale
    ///  @param _collectionSize max supply of collection
    ///  @param _royaltyBPS BPS of the royalty set on the contract. Can be 0 for no royalty.
    ///  @param _setupCalls Bytes-encoded list of setup multicalls
    ///  @param _metadataRenderer Renderer contract to use
    ///  @param _metadataRendererInit Renderer data initial contract
    function initialize(
        string memory _contractName,
        string memory _contractSymbol,
        address _initialOwner,
        address payable _fundsRecipient,
        uint64 _collectionSize,
        uint16 _royaltyBPS,
        bytes[] calldata _setupCalls,
        bool _tradingLocked,
        bool _revealed,
        IMetadataRenderer _metadataRenderer,
        bytes memory _metadataRendererInit,
        bytes memory _dynamicMetadataInit
    ) public initializer {
        // Setup ERC721A
        __ERC721A_init(_contractName, _contractSymbol);
        // Setup access control
        __AccessControl_init();
        // Setup re-entracy guard
        __ReentrancyGuard_init();
        // Setup the owner role
        _setupRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        // Set ownership to original sender of contract call
        _setOwner(_initialOwner);

        if (_setupCalls.length > 0) {
            // Setup temporary role
            _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
            // Execute setupCalls
            multicall(_setupCalls);
            // Remove temporary role
            _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
        }

        // Setup config variables
        config.collectionSize = _collectionSize;
        config.metadataRenderer = _metadataRenderer;
        config.royaltyBPS = _royaltyBPS;
        config.fundsRecipient = _fundsRecipient;
        config.revealed = _revealed;
        config.lockBeforeMintOut = _tradingLocked;

        if (config.royaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        _metadataRenderer.initializeWithData(_metadataRendererInit, _dynamicMetadataInit);
    }

    /// @dev Getter for admin role associated with the contract to handle metadata
    /// @return boolean if address is admin
    function isAdmin(address user) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, user);
    }

    /// @notice Connects this contract to the factory upgrade gate
    /// @param newImplementation proposed new upgrade implementation
    /// @dev Only can be called by admin
    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin {
        if (!factoryUpgradeGate.isValidUpgradePath({_newImpl: newImplementation, _currentImpl: _getImplementation()})) {
            revert Admin_InvalidUpgradeAddress(newImplementation);
        }
    }

    /// @param tokenId Token ID to burn
    /// @notice User burn function for token id
    function burn(uint256 tokenId) public {
        _burn(tokenId, true);
    }

    /// @dev Get royalty information for token
    /// @param _salePrice Sale price for the token
    function royaltyInfo(uint256, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        if (config.fundsRecipient == address(0)) {
            return (config.fundsRecipient, 0);
        }
        return (config.fundsRecipient, (_salePrice * config.royaltyBPS) / 10_000);
    }

    /// @dev Number of NFTs the user has minted per address
    /// @param minter to get counts for
    function mintedPerAddress(address minter) external view override returns (IERC721Collection.AddressMintDetails memory) {
        uint256 totalPresaleMints = _totalPresaleMinted(_msgSender());
        uint256[] memory mintsByStage = new uint256[](PRESALE_STAGES_ALLOWED);
        mintsByStage[0] = presaleMintedByAddress[minter][1];
        mintsByStage[1] = presaleMintedByAddress[minter][2];
        mintsByStage[2] = presaleMintedByAddress[minter][3];
        mintsByStage[3] = presaleMintedByAddress[minter][4];
        mintsByStage[4] = presaleMintedByAddress[minter][5];
        return
            IERC721Collection.AddressMintDetails({
                presaleMintsByStage: mintsByStage,
                presaleMints: totalPresaleMints,
                publicMints: _numberMinted(minter) - totalPresaleMints,
                totalMints: _numberMinted(minter)
            });
    }

    /// @dev Setup auto-approval for Freee v3 access to sell NFT
    ///      Still requires approval for module
    /// @param nftOwner owner of the nft
    /// @param operator operator wishing to transfer/burn/etc the NFTs
    function isApprovedForAll(address nftOwner, address operator) public view override(IERC721Upgradeable, ERC721AUpgradeable) returns (bool) {
        return super.isApprovedForAll(nftOwner, operator);
    }

    /// @notice Freee fee is fixed now per mint
    /// @dev Gets the Freee fee for amount of withdraw
    function feeForAmount(uint256 quantity) public view returns (address payable recipient, uint256 fee) {
        recipient = MINT_FEE_RECIPIENT;
        fee = MINT_FEE * quantity;
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     PUBLIC MINTING FUNCTIONS       ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /**
      @dev This allows the user to purchase collection item
           at the given price in the contract.
     */
    /// @notice Purchase a quantity of tokens
    /// @param quantity quantity to purchase
    /// @return tokenId of the first token minted
    function purchase(uint256 quantity) external payable nonReentrant canMintTokens(quantity) onlyPublicSaleActive returns (uint256) {
        return _handlePurchase(quantity, "");
    }

    /// @notice Purchase a quantity of tokens with a comment
    /// @param quantity quantity to purchase
    /// @param comment comment to include in the IERC721Collection.Sale event
    /// @return tokenId of the first token minted
    function purchaseWithComment(
        uint256 quantity,
        string calldata comment
    ) external payable nonReentrant canMintTokens(quantity) onlyPublicSaleActive returns (uint256) {
        return _handlePurchase(quantity, comment);
    }

    function _handlePurchase(uint256 quantity, string memory comment) internal returns (uint256) {
        uint256 salePrice = publicSaleConfig.publicSalePrice;

        if (msg.value != (salePrice + MINT_FEE) * quantity) {
            revert Purchase_WrongPrice((salePrice + MINT_FEE) * quantity);
        }

        uint256 presaleMinted = _totalPresaleMinted(_msgSender());
        // If max purchase per address == 0 there is no limit.
        // Any other number, the per address mint limit is that.
        if (
            publicSaleConfig.maxSalePurchasePerAddress != 0 &&
            _numberMinted(_msgSender()) + quantity - presaleMinted > publicSaleConfig.maxSalePurchasePerAddress
        ) {
            revert Purchase_TooManyForAddress();
        }

        _mintNFTs(_msgSender(), quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        _payoutFreeeFee(quantity);

        emit IERC721Collection.Sale({
            phase: IERC721Collection.PhaseType.Public,
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: salePrice,
            firstPurchasedTokenId: firstMintedTokenId,
            presaleStage: 0
        });
        if (bytes(comment).length > 0) {
            emit IERC721Collection.MintComment({
                sender: _msgSender(),
                tokenContract: address(this),
                tokenId: firstMintedTokenId,
                quantity: quantity,
                comment: comment
            });
        }
        return firstMintedTokenId;
    }

    /// @notice Function to mint NFTs
    /// @dev (important: Does not enforce max supply limit, enforce that limit earlier)
    /// @dev This batches in size of 8 as per recommended by ERC721A creators
    /// @param to address to mint NFTs to
    /// @param quantity number of NFTs to mint
    function _mintNFTs(address to, uint256 quantity) internal {
        do {
            uint256 toMint = quantity > MAX_MINT_BATCH_SIZE ? MAX_MINT_BATCH_SIZE : quantity;
            _mint({to: to, quantity: toMint});
            quantity -= toMint;
        } while (quantity > 0);
    }

    /// @notice Merkle-tree based presale purchase function
    /// @param quantity quantity to purchase
    /// @param maxQuantity max quantity that can be purchased via merkle proof #
    /// @param pricePerToken price that each token is purchased at
    /// @param merkleProof proof for presale mint
    function purchasePresale(
        uint256 stageIndex,
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof
    ) external payable nonReentrant canMintTokens(quantity) onlyPresaleActive(stageIndex) returns (uint256) {
        return _handlePurchasePresale(stageIndex, quantity, maxQuantity, pricePerToken, merkleProof, "");
    }

    /// @notice Merkle-tree based presale purchase function with a comment
    /// @param stageIndex targetted presale stage
    /// @param quantity quantity to purchase
    /// @param maxQuantity max quantity that can be purchased via merkle proof #
    /// @param pricePerToken price that each token is purchased at
    /// @param merkleProof proof for presale mint
    /// @param comment comment to include in the IERC721Collection.Sale event
    function purchasePresaleWithComment(
        uint256 stageIndex,
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof,
        string calldata comment
    ) external payable nonReentrant canMintTokens(quantity) onlyPresaleActive(stageIndex) returns (uint256) {
        return _handlePurchasePresale(stageIndex, quantity, maxQuantity, pricePerToken, merkleProof, comment);
    }

    function _handlePurchasePresale(
        uint256 stageIndex,
        uint256 quantity,
        uint256 maxQuantity,
        uint256 pricePerToken,
        bytes32[] calldata merkleProof,
        string memory comment
    ) internal returns (uint256) {
        if (stageIndex > activePresaleStageCount) {
            revert Presale_Invalid();
        }

        PresaleConfiguration memory saleConfig = presaleConfig[stageIndex];

        if (
            !MerkleProofUpgradeable.verify(
                merkleProof,
                saleConfig.presaleMerkleRoot,
                keccak256(
                    bytes.concat(
                        keccak256(
                            // address, uint256, uint256
                            abi.encode(_msgSender(), maxQuantity, pricePerToken)
                        )
                    )
                )
            )
        ) {
            revert Presale_MerkleNotApproved();
        }

        uint256 presalePrice = saleConfig.presalePrice;
        if (pricePerToken != presalePrice) {
            presalePrice = pricePerToken;
        }
        if (msg.value != (presalePrice + MINT_FEE) * quantity) {
            revert Purchase_WrongPrice((presalePrice + MINT_FEE) * quantity);
        }

        uint256 presaleQuantity = saleConfig.presaleMaxPurchasePerAddress;
        if (maxQuantity != presaleQuantity) {
            presaleQuantity = maxQuantity;
        }

        if (presaleMintedByAddress[_msgSender()][stageIndex] + quantity > presaleQuantity) {
            revert Presale_TooManyForAddress();
        }

        bool limitedPresaleSupply = saleConfig.presaleSupply > 0;
        if (limitedPresaleSupply && quantity + saleConfig.presaleMinted > saleConfig.presaleSupply) {
            revert Presale_ExceedStageSupply();
        }

        unchecked {
            presaleMintedByAddress[_msgSender()][stageIndex] += quantity;
            presaleConfig[stageIndex].presaleMinted += uint32(quantity);
        }

        _mintNFTs(_msgSender(), quantity);
        _payoutFreeeFee(quantity);

        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;
        emit IERC721Collection.Sale({
            phase: IERC721Collection.PhaseType.Presale,
            to: _msgSender(),
            quantity: quantity,
            pricePerToken: pricePerToken,
            firstPurchasedTokenId: firstMintedTokenId,
            presaleStage: stageIndex
        });
        if (bytes(comment).length > 0) {
            emit IERC721Collection.MintComment({
                sender: _msgSender(),
                tokenContract: address(this),
                tokenId: firstMintedTokenId,
                quantity: quantity,
                comment: comment
            });
        }

        return firstMintedTokenId;
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***     ADMIN MINTING FUNCTIONS        ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /// @notice Mint admin
    /// @param recipient recipient to mint to
    /// @param quantity quantity to mint
    function adminMint(address recipient, uint256 quantity) external onlyRoleOrAdmin(MINTER_ROLE) canMintTokens(quantity) returns (uint256) {
        _mintNFTs(recipient, quantity);
        uint256 firstMintedTokenId = _lastMintedTokenId() - quantity;

        emit IERC721Collection.Sale({
            phase: IERC721Collection.PhaseType.AdminMint,
            to: recipient,
            quantity: quantity,
            pricePerToken: 0,
            firstPurchasedTokenId: firstMintedTokenId,
            presaleStage: 0
        });

        return _lastMintedTokenId();
    }

    /// @dev This mints a token to the given list of addresses.
    /// @param recipients list of addresses to send the newly minted token to
    function adminMintAirdrop(address[] calldata recipients) external override onlyRoleOrAdmin(MINTER_ROLE) canMintTokens(recipients.length) returns (uint256) {
        uint256 atId = _currentIndex;
        uint256 startAt = atId;

        unchecked {
            for (uint256 endAt = atId + recipients.length; atId < endAt; atId++) {
                address recipient = recipients[atId - startAt];
                _mintNFTs(recipient, 1);
                uint256 firstMintedTokenId = _lastMintedTokenId() - 1;

                emit IERC721Collection.Sale({
                    phase: IERC721Collection.PhaseType.Airdrop,
                    to: recipient,
                    quantity: 1,
                    pricePerToken: 0,
                    firstPurchasedTokenId: firstMintedTokenId,
                    presaleStage: 0
                });
            }
        }
        return _lastMintedTokenId();
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***  ADMIN CONFIGURATION FUNCTIONS     ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /// @dev Set new owner for royalties / opensea
    /// @param newOwner new owner to set
    function setOwner(address newOwner) public onlyAdmin {
        _setOwner(newOwner);
    }

    /// @notice Set a new metadata renderer
    /// @param newRenderer new renderer address to use
    /// @param metadataBase normal metadata to setup new renderer with
    /// @param dynamicMetadataInfo dynamic metadata to setup new renderer with
function setMetadataRenderer(IMetadataRenderer newRenderer, bytes memory metadataBase, bytes memory dynamicMetadataInfo) external onlyAdmin {
        config.metadataRenderer = newRenderer;
        newRenderer.initializeWithData(metadataBase, dynamicMetadataInfo);
        emit UpdatedMetadataRenderer({sender: _msgSender(), renderer: newRenderer});

        _notifyMetadataUpdate();
    }

    /// @notice Calls the metadata renderer contract to make an update and uses the EIP4906 event to notify
    /// @param data raw calldata to call the metadata renderer contract with.
    /// @dev Only accessible via an admin role
    function callMetadataRenderer(bytes memory data) public onlyAdmin returns (bytes memory) {
        (bool success, bytes memory response) = address(config.metadataRenderer).call(data);
        if (!success) {
            revert ExternalMetadataRenderer_CallFailed();
        }
        _notifyMetadataUpdate();
        return response;
    }

    /// @dev This sets public sale configuration
    /// @param newConfig updated public stage config
    function setPublicSaleConfiguration(PublicSaleConfiguration memory newConfig) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        publicSaleConfig.publicSalePrice = newConfig.publicSalePrice;
        publicSaleConfig.maxSalePurchasePerAddress = newConfig.maxSalePurchasePerAddress;
        publicSaleConfig.publicSaleStart = newConfig.publicSaleStart;
        publicSaleConfig.publicSaleEnd = newConfig.publicSaleEnd;
        emit PublicSaleConfigChanged(_msgSender());
    }

    /// @dev This set presale configuration, use this when init presale stages or when need to remove presale stage
    /// @param presaleStages presale configuration data
    function setPresaleConfiguration(
        IERC721Collection.PresaleConfiguration[] memory presaleStages
    ) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        uint256 stageLength = presaleStages.length;
        if (stageLength > PRESALE_STAGES_ALLOWED) {
            revert Setup_Presale_StageOutOfRange();
        }

        activePresaleStageCount = stageLength;

        for (uint256 i = 0; i < stageLength; ) {
            uint256 stageIndex = i + 1;
            PresaleConfiguration memory existingConfig = presaleConfig[stageIndex];
            PresaleConfiguration memory newConfig = existingConfig;
            bool allowParamsChange = true;
            bool allowMerkleChange = true;

            if (existingConfig.presaleStart > 0 && existingConfig.presaleStart <= block.timestamp) {
                allowParamsChange = false;
            }

            if (existingConfig.presaleEnd > 0 && existingConfig.presaleEnd <= block.timestamp) {
                allowMerkleChange = false;
            }

            if (allowParamsChange) {
                newConfig.presaleName = presaleStages[i].presaleName;
                newConfig.presaleStart = presaleStages[i].presaleStart;
                newConfig.presaleEnd = presaleStages[i].presaleEnd;
                newConfig.presalePrice = presaleStages[i].presalePrice;
                newConfig.presaleMaxPurchasePerAddress = presaleStages[i].presaleMaxPurchasePerAddress;
                newConfig.presaleSupply = presaleStages[i].presaleSupply;
            }

            if (allowMerkleChange) {
                newConfig.presaleMerkleRoot = presaleStages[i].presaleMerkleRoot;
            }
            
            presaleConfig[stageIndex] = newConfig;

            unchecked {
                ++i;
            }
        }
        emit PresaleConfigChanged(_msgSender());
    }

    /// @dev Reveal collection artworks
    /// @param collectionURI collection artwork URI
    function revealCollection(string memory collectionURI) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        if (config.revealed) {
            revert Collection_Aready_Revealed();
        }

        config.metadataRenderer.updateMetadataBase(address(this), collectionURI, config.metadataRenderer.contractURI());
        config.revealed = true;
        emit CollectionRevealed(_msgSender());
    }

    /// @notice Admin function to finalize and open edition sale
    function finalizeOpenEdition() external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        if (config.collectionSize != type(uint64).max) {
            revert Admin_UnableToFinalizeNotOpenEdition();
        }

        config.collectionSize = uint64(_totalMinted());
        emit OpenMintFinalized(_msgSender(), config.collectionSize);
    }

    function setTradingLock(bool _locked) external onlyAdmin {
        config.lockBeforeMintOut = _locked;
        emit LockTradingStatusChanged(_msgSender(), _locked);
    }

    /// @notice Set new royalty percentage
    /// @param _royaltyBPS new funds recipient address
    function setRoyalty(uint16 _royaltyBPS) external onlyRoleOrAdmin(SALES_MANAGER_ROLE) {
        if (_royaltyBPS > MAX_ROYALTY_BPS) {
            revert Setup_RoyaltyPercentageTooHigh(MAX_ROYALTY_BPS);
        }

        config.royaltyBPS = _royaltyBPS;
        emit RoyaltyChanged(_msgSender(), _royaltyBPS);
    }

    /// @notice Set a different funds recipient
    /// @param newRecipientAddress new funds recipient address
    function setFundsRecipient(address payable newRecipientAddress) external onlyAdmin {
        config.fundsRecipient = newRecipientAddress;
        emit FundsRecipientChanged(newRecipientAddress, _msgSender());
    }

    /// @notice This withdraws ETH from the contract to the contract owner.
    function withdraw() external nonReentrant {
        address sender = _msgSender();
        uint256 funds = address(this).balance;

        // Check if withdraw is allowed for sender
        if (!hasRole(DEFAULT_ADMIN_ROLE, sender) && !hasRole(SALES_MANAGER_ROLE, sender) && sender != config.fundsRecipient) {
            revert Access_WithdrawNotAllowed();
        }

        // Payout recipient
        (bool successFunds, ) = config.fundsRecipient.call{value: funds, gas: FUNDS_SEND_GAS_LIMIT}("");
        if (!successFunds) {
            revert Withdraw_FundsSendFailure();
        }

        // Emit event for indexing
        emit FundsWithdrawn(_msgSender(), config.fundsRecipient, funds, address(0), 0);
    }

    /**
     *** ---------------------------------- ***
     ***                                    ***
     ***      GENERAL GETTER FUNCTIONS      ***
     ***                                    ***
     *** ---------------------------------- ***
     ***/

    /// @notice Simple override for owner interface.
    /// @return user owner address
    function owner() public view override(IERC721Collection, OwnableSkeleton) returns (address) {
        return super.owner();
    }

    /// @notice Contract URI Getter, proxies to metadataRenderer
    /// @return Contract URI
    function contractURI() external view returns (string memory) {
        return config.metadataRenderer.contractURI();
    }

    /// @notice Getter for metadataRenderer contract
    function metadataRenderer() external view returns (IMetadataRenderer) {
        return IMetadataRenderer(config.metadataRenderer);
    }

    /// @notice Token URI Getter, proxies to metadataRenderer
    /// @param tokenId id of token to get URI for
    /// @return Token URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert IERC721AUpgradeable.URIQueryForNonexistentToken();
        }

        return config.metadataRenderer.tokenURI(tokenId, config.revealed);
    }

    /// @notice Internal function to notify that all metadata may/was updated in the update
    /// @dev Since we don't know what tokens were updated, most calls to a metadata renderer
    ///      update the metadata we can assume all tokens metadata changed
    function _notifyMetadataUpdate() internal {
        uint256 totalMinted = _totalMinted();

        // If we have tokens to notify about
        if (totalMinted > 0) {
            emit BatchMetadataUpdate(_startTokenId(), totalMinted + _startTokenId());
        }
    }

    function _payoutFreeeFee(uint256 quantity) internal {
        // Transfer Freee fee to recipient
        (, uint256 FreeeFee) = feeForAmount(quantity);
        (bool success, ) = MINT_FEE_RECIPIENT.call{value: FreeeFee, gas: FUNDS_SEND_GAS_LIMIT}("");
        emit MintFeePayout(FreeeFee, MINT_FEE_RECIPIENT, success);
    }

    /// @notice Internal function to get total minted accross all presale stages
    /// @param minter to get presale counts for
    function _totalPresaleMinted(address minter) internal view returns (uint256) {
        uint256 totalMintCount = presaleMintedByAddress[minter][1] +
            presaleMintedByAddress[minter][2] +
            presaleMintedByAddress[minter][3] +
            presaleMintedByAddress[minter][4] +
            presaleMintedByAddress[minter][5];

        return totalMintCount;
    }

    /// @notice ERC165 supports interface
    /// @param interfaceId interface id to check if supported
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165Upgradeable, AccessControlUpgradeable, ERC721AUpgradeable) returns (bool) {
        return
            super.supportsInterface(interfaceId) ||
            type(IOwnable).interfaceId == interfaceId ||
            type(IERC2981Upgradeable).interfaceId == interfaceId ||
            // Because the EIP-4906 spec is event-based a numerically relevant interfaceId is used.
            bytes4(0x49064906) == interfaceId ||
            type(IERC721Collection).interfaceId == interfaceId;
    }

    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId,
        bytes memory _data
    ) public override(ERC721AUpgradeable, IERC721Upgradeable) canTradeToken {
        super.safeTransferFrom(from, to, tokenId, _data);
    }
    
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId
    ) public override(ERC721AUpgradeable, IERC721Upgradeable) canTradeToken {
        super.safeTransferFrom(from, to, tokenId);
    }
    
    function transferFrom(
        address from, 
        address to, 
        uint256 tokenId
    ) public override(ERC721AUpgradeable, IERC721Upgradeable) canTradeToken {
        super.transferFrom(from, to, tokenId);
    }
}
