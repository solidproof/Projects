// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./opensea-enforcer/DefaultOperatorFilterer.sol";
import "./INFT.sol";

contract NFT is INFT, ERC721Royalty, ERC721Enumerable, DefaultOperatorFilterer, Ownable, ReentrancyGuard, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _allowList;

    string private _name;
    string private _symbol;
    string private _baseTokenURI;
    uint256 public limitSupply;
    uint256 public presaleSupply;
    uint256 public presalePrice;
    uint256 public publicSalePrice;
    uint256 public PRESALE_MAX_MINT;
    uint256 public MAX_PER_MINT;

    address public constant serviceFeeAddress = 0xBa4DB2a52109E538C5b6deD452202e87Ed9A57fC;
    uint16 public constant serviceFee = 700; // 7% - default NFTGen service commission, which will be deducted from each sell.

    uint256 public publicSaleMinted;
    bool public publicSaleActive = false;

    uint256 public presaleMinted;
    bool public presaleActive = false;

    event AddedToAllowList(address indexed _address);
    event RemovedFromAllowList(address indexed _address);
    event PresaleStart();
    event PresalePaused();
    event SaleStart();
    event SalePaused();
    event PerTransactionMaxChanged(uint256 newValue);
    event PresaleMaxMintChanged(uint256 newValue);

    error PresaleIsNotPaused();
    error PresaleIsNotActive();
    error PresaleIsAlreadyPaused();
    error PublicSaleIsAlreadyPaused();
    error PublicSaleIsNotActive();
    error ListOfAddressesIsToLong(uint256 sentAmount, uint256 maxAmount);
    error WrongPaymentAmount(uint256 sent, uint256 required);
    error NoActiveSale();
    error WrongTokensAmount();
    error ExceedingTheSaleSupply(
        uint256 desiredAmount,
        uint256 availableAmount
    );
    error LimitedAmountPerAddress(
        uint256 desiredAmount,
        uint256 availableAmount
    );
    error LimitedAmountPerTransaction(
        uint256 desiredAmount,
        uint256 availableAmount
    );
    error CallerIsNotInAllowlist();

    mapping(address => uint256) private _totalClaimed;

    constructor() ERC721("", "") {
        _disableInitializers();
    }

    /**
     * @dev A method which allows to initialize another collection contract with the same functionality as this one, using some proxy contract
     */
    function initialize(Initialization calldata initialization) external initializer {
        _transferOwnership(_msgSender());
        _name = initialization.name;
        _symbol = initialization.symbol;
        _baseTokenURI = initialization.baseTokenURI;
        limitSupply = initialization.limitSupply;
        presaleSupply = initialization.presaleSupply;
        presalePrice = initialization.presalePrice;
        publicSalePrice = initialization.publicSalePrice;
        PRESALE_MAX_MINT = initialization.PRESALE_MAX_MINT;
        MAX_PER_MINT = initialization.MAX_PER_MINT;
        _setDefaultRoyalty(initialization.royaltyReceiverAddress, initialization.royaltyFee);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {ERC721Enumerable-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /**
     * @dev See {ERC721Royalty-_burn}.
     */
    function _burn(uint256 tokenId) internal override(ERC721, ERC721Royalty) {
        super._burn(tokenId);
    }

    /**
     * @dev Method for burning the NFT on blockchain.
     * @param tokenId Token ID to burn
     */
    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");
        _burn(tokenId);
    }

    /**
     * @dev Checks if collection contract supports specified interface
     * @return interfaceId Identifier hash of the interface
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, ERC721Royalty) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Gets the number of NFTs that can be minted during the public sale.
     * @return uint256 Static quantity of NFTs
     */
    function publicSaleSupply() public view virtual returns (uint256) {
        return limitSupply - presaleSupply;
    }

    /**
     * @dev Updates royalties receiver and royalties percent for the whole collection.
     * @param receiver New royalties receiver address
     * @param feeNumerator New royalties percent. If user want to set new royalties as 15% they shoud enter 1500 as `feeNumerator`
     */
    function setRoyalties(address receiver, uint96 feeNumerator) external onlyOwner {
        return _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev Gets current royalty percent of the whole collection.
     * @return uint96 Returns royalty percent 1% = 100 (returned value)
     */
    function royaltyFee() view external returns (uint96) {
        (,uint256 value) = royaltyInfo(type(uint256).max, _feeDenominator());

        return uint96(value);
    }

    /**
     * @dev Gets current royalty receiver address.
     * @return address Royalty receiver address 
     */
    function royaltyReceiverAddress() view external returns (address) {
        (address value,) = royaltyInfo(type(uint256).max, _feeDenominator());

        return value;
    }

    /**
     * @dev Adds the specified addresses to the allow list of the presale
     * @param addresses an array of addresses which should be added to the allow list
     */
    function addToAllowList(address[] memory addresses) external onlyOwner {
        if (presaleActive) revert PresaleIsNotPaused();
        uint256 length = addresses.length;
        for (uint256 index = 0; index < length; ++index) {
            if (_allowList.add(addresses[index])) {
                emit AddedToAllowList(addresses[index]);
            }
        }
    }

    /**
     * @dev Removes the specified addresses from the allow list of the presale
     * @param addresses an array of addresses which should be added to the allow list
     */
    function removeFromAllowList(address[] memory addresses) external onlyOwner {
        if (presaleActive) revert PresaleIsNotPaused();
        uint256 length = addresses.length;

        for (uint256 index = 0; index < length; ++index) {
            if (_allowList.remove(addresses[index])) {
                emit RemovedFromAllowList(addresses[index]);
            }
        }
    }

    /**
     * @dev Checks if address is in allo list of the presale
     * @return bool Returns true if wallet address can mint NFTs during the presale
     */
    function inAllowList(address value) public view returns (bool) {
        return _allowList.contains(value);
    }

    /**
     * @dev Transfers the NFTGen service fee to the `serviceFeeAddress`
     */
    function _transferServiceFee() private {
        uint256 serviceFeeAmount = msg.value * serviceFee / 1e4;

        if (serviceFeeAmount > 0 && serviceFeeAddress != address(0)) {
            (bool sent,) = serviceFeeAddress.call{value: serviceFeeAmount}("");
            require(sent, "Failed to send service fee");
        }
    }

    /**
     * @dev Validation of the amount of NFTs to mint and paid amount for the presale
     */
    function _preValidatePresaleMint(uint32 amountOfNFTs) private view {
        if (!inAllowList(msg.sender)) revert CallerIsNotInAllowlist();
        if (amountOfNFTs > MAX_PER_MINT)
            revert LimitedAmountPerTransaction({
                desiredAmount: amountOfNFTs,
                availableAmount: MAX_PER_MINT
            });
        if (amountOfNFTs + _totalClaimed[msg.sender] > PRESALE_MAX_MINT)
            revert LimitedAmountPerAddress({
                desiredAmount: amountOfNFTs,
                availableAmount: PRESALE_MAX_MINT - _totalClaimed[msg.sender]
            });
        if (presaleMinted + amountOfNFTs > presaleSupply)
            revert ExceedingTheSaleSupply({
                desiredAmount: amountOfNFTs,
                availableAmount: presaleSupply - presaleMinted
            });
        if (presalePrice * amountOfNFTs != msg.value)
            revert WrongPaymentAmount({
                sent: msg.value,
                required: presalePrice * amountOfNFTs
            });
    }

    /**
     * @dev Validation of the amount of NFTs to mint and paid amount for the public sale
     */
    function _preValidatePublicMint(uint32 amountOfNFTs) private view {
        if (amountOfNFTs > MAX_PER_MINT)
            revert LimitedAmountPerTransaction({
                desiredAmount: amountOfNFTs,
                availableAmount: MAX_PER_MINT
            });
        if (publicSaleMinted + amountOfNFTs > publicSaleSupply())
            revert ExceedingTheSaleSupply({
                desiredAmount: amountOfNFTs,
                availableAmount: publicSaleSupply() - publicSaleMinted
            });
        if (publicSalePrice * amountOfNFTs != msg.value)
            revert WrongPaymentAmount({
                sent: msg.value,
                required: publicSalePrice * amountOfNFTs
            });
    }

    /**
     * @dev Mint NFT to the `recipient` address
     * @param recipient A Wallet address of the NFT recipient (Mint functions caller address)
     */
    function _processTokenMint(address recipient) internal virtual returns (uint256 tokenId) {
        tokenId = totalSupply() + 1;
        _safeMint(recipient, tokenId);
    }

    /**
     * @dev Mints the specified amount of NFTs to the caller wallet during the presale for the presale price (available only for wallets from the allow list)
     * @param amountOfNFTs A quantity of NFTs to be minted
     */
    function mintPresale(uint32 amountOfNFTs) external payable {
        if (amountOfNFTs == 0) revert WrongTokensAmount();
        if (!presaleActive) revert PresaleIsNotActive();
        _preValidatePresaleMint(amountOfNFTs);

        presaleMinted += amountOfNFTs;
        _totalClaimed[msg.sender] += amountOfNFTs;

        for (uint256 i = 0; i < amountOfNFTs; i++) {
            _processTokenMint(msg.sender);
        }

        _transferServiceFee();
    }

    /**
     * @dev Mints the specified amount of NFTs to the caller wallet during the public sale for the sale price
     * @param amountOfNFTs A quantity of NFTs to be minted
     */
    function mint(uint32 amountOfNFTs) external payable {
        if (amountOfNFTs == 0) revert WrongTokensAmount();
        if (!publicSaleActive) revert PublicSaleIsNotActive();
        _preValidatePublicMint(amountOfNFTs);
        publicSaleMinted += amountOfNFTs;

        for (uint32 i = 0; i < amountOfNFTs; ++i) {
            _processTokenMint(msg.sender);
        }

        _transferServiceFee();
    }

    /**
     * @dev Starts the presale, so only users from the allow list can mint the presale NFTs
     */
    function startPresale() external onlyOwner {
        _saleState(false);
        _presaleState(true);
    }

    /**
     * @dev Pauses the presale, no one able to mint the presale supply anymore
     */
    function pausePresale() external onlyOwner {
        if (!presaleActive) revert PresaleIsAlreadyPaused();
        _presaleState(false);
    }

    /**
     * @dev Starts the public sale, so all users can mint the public sales NFTs
     */
    function startPublicSale() external onlyOwner {
        _presaleState(false);
        _saleState(true);
    }

    /**
     * @dev Pauses the pblic sale, so no one is able to mint the public sale supply anymore (except the owner via `devMint()`)
     */
    function pausePublicSale() external onlyOwner {
        if (!publicSaleActive) revert PublicSaleIsAlreadyPaused();
        _saleState(false);
    }

    /**
     * @dev Updates the status of the presale
     */
    function _presaleState(bool value) private {
        if (presaleActive != value) {
            presaleActive = value;
            if (value) emit PresaleStart();
            else emit PresalePaused();
        }
    }

    /**
     * @dev Updates the status of the public sale
     */
    function _saleState(bool value) private {
        if (publicSaleActive != value) {
            publicSaleActive = value;
            if (value) emit SaleStart();
            else emit SalePaused();
        }
    }

    /**
     * @dev Changes the limit of NFTs per wallet during the presale (default value is set during the contract deploy)
     * @param number A new number of allowed NFTs per wallet during the presale
     */
    function setTokensPerWalletMax(uint32 number) public onlyOwner {
        PRESALE_MAX_MINT = number;
        emit PresaleMaxMintChanged(number);
    }

    /**
     * @dev Changes the limit of NFTs per transaction (default value is set during the contract deploy). The user cannot mint more NFTs during the presale and public sale in one transaction. 
     * @param number A new number of allowed NFTs per transaction for both sales
     */
    function setPerTransactionMax(uint32 number) public onlyOwner {
        MAX_PER_MINT = number;
        emit PerTransactionMaxChanged(number);
    }

    /**
     * @dev A method to withdraw funds accumulated by NFT mints from a collection contract
     * @param wallet (payable) A wallet address (receiver) of the funds
     * @param amount An amount to withdraw (in wei)
     */
    function withdraw(
        address payable wallet,
        uint256 amount
    ) external onlyOwner {
        require(amount <= address(this).balance);
        wallet.transfer(amount);
    }

    /**
     * @dev A method solely for contract owner use, to be able to mint NFTs from the public supply for free. No need to have an active sale for using this method.
     * @param amountOfNFTs An amount of NFTs to mint
     */
    function devMint(uint32 amountOfNFTs) external onlyOwner {
        if (amountOfNFTs == 0) revert WrongTokensAmount();
        if (totalSupply() + amountOfNFTs > limitSupply)
            revert ExceedingTheSaleSupply({
                desiredAmount: amountOfNFTs,
                availableAmount: limitSupply - totalSupply()
            });
        publicSaleMinted += amountOfNFTs;
        for (uint32 i = 0; i < amountOfNFTs; i++) {
            _processTokenMint(msg.sender);
        }
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public override(IERC721, ERC721) onlyAllowedOperator {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(IERC721, ERC721) onlyAllowedOperator {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
