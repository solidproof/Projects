// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

abstract contract FayreMembershipCard721 is OwnableUpgradeable, ERC721EnumerableUpgradeable, ERC721BurnableUpgradeable {
    /**
        E#1: must send liquidity
        E#2: insufficient funds
        E#3: unable to refund extra liquidity
        E#4: unable to send liquidity to treasury
        E#5: insufficient volume left
        E#6: only membership cards manager
        E#7: supply cap reached
        E#8: insufficient free multi-asset swaps left
        E#9: the message must be signed by a validator
        E#10: message already processed
        E#11:
        E#12:
        E#13: multichain destination address must be this contract
        E#14: wrong destination network id
    */

    struct MembershipCardData {
        uint256 volume;
        uint256 nftPriceCap;
        uint256 freeMultiAssetSwapCount;
    }

    event Mint(address indexed owner, uint256 indexed tokenId, string tokenURI, MembershipCardData membershipCardData);
    event MultichainTransfer(address indexed to, uint256 indexed tokenId, uint256 fromNetworkId, address fromContractAddress, uint256 destinationNetworkId, address destinationContractAddress, MembershipCardData membershipCardData);
    event MultichainClaim(address indexed to, uint256 indexed tokenId, uint256 indexed fromTokenId, uint256 fromNetworkId, address fromContractAddress, uint256 destinationNetworkId, address destinationContractAddress, MembershipCardData membershipCardData);

    address public oracleDataFeed;
    mapping(uint256 => MembershipCardData) public membershipCardsData;
    uint256 public priceUSD;
    uint256 public startingVolume;
    uint256 public nftPriceCap;
    uint256 public freeMultiAssetSwapCount;
    uint256 public supplyCap;
    address public treasuryAddress;
    mapping(address => bool) public isValidator;
    mapping(address => bool) public isMembershipCardsManager;
    mapping(address => bool) public isFreeMinter;

    uint256 private _currentTokenId;
    string private _tokenURI;
    mapping(bytes32 => bool) private _isMultichainHashProcessed;
    uint256 private _networkId;

    modifier onlyMembershipCardsManager() {
        require(isMembershipCardsManager[msg.sender], "E#6");
        _;
    }

    function setOracleDataFeedAddress(address newOracleDataFeed) external onlyOwner {
        oracleDataFeed = newOracleDataFeed;
    }

    function setTokenURI(string memory newTokenUri) external onlyOwner {
        _tokenURI = newTokenUri;
    }

    function setPrice(uint256 newPriceUSD) external onlyOwner {
        priceUSD = newPriceUSD;
    }

    function setStartingVolume(uint256 newStartingVolume) external onlyOwner {
        startingVolume = newStartingVolume;
    }

    function setNFTPriceCap(uint256 newNFTPriceCap) external onlyOwner {
        nftPriceCap = newNFTPriceCap;
    }

    function setFreeMultiAssetSwapCount(uint256 newFreeMultiAssetSwapCount) external onlyOwner {
        freeMultiAssetSwapCount = newFreeMultiAssetSwapCount;
    }

    function setSupplyCap(uint256 newSupplyCap) external onlyOwner {
        supplyCap = newSupplyCap;
    }

    function setTreasury(address newTreasuryAddress) external onlyOwner {
        treasuryAddress = newTreasuryAddress;
    }

    function setAddressAsValidator(address validatorAddress) external onlyOwner {
        isValidator[validatorAddress] = true;
    }

    function unsetAddressAsValidator(address validatorAddress) external onlyOwner {
        isValidator[validatorAddress] = false;
    }

    function setAddressAsMembershipCardsManager(address membershipCardsManagerAddress) external onlyOwner {
        isMembershipCardsManager[membershipCardsManagerAddress] = true;
    }

    function unsetAddressAsMembershipCardsManager(address membershipCardsManagerAddress) external onlyOwner {
        isMembershipCardsManager[membershipCardsManagerAddress] = false;
    }

    function setFreeMinterAddresses(address[] calldata freeMinterAddresses) external onlyMembershipCardsManager {
        for (uint256 i = 0; i < freeMinterAddresses.length; i++) {
            isFreeMinter[freeMinterAddresses[i]] = true;
        }
    }

    function decreaseMembershipCardVolume(uint256 tokenId, uint256 amount) external onlyMembershipCardsManager {
        require(membershipCardsData[tokenId].volume >= amount, "E#5");

        membershipCardsData[tokenId].volume -= amount;
    }

    function decreaseMembershipCardFreeMultiAssetSwapCount(uint256 tokenId, uint256 amount) external onlyMembershipCardsManager {
        require(membershipCardsData[tokenId].freeMultiAssetSwapCount >= amount, "E#8");

        membershipCardsData[tokenId].freeMultiAssetSwapCount -= amount;
    }

    function mint(address recipient) external payable returns(uint256) {
        uint256 tokenId = _currentTokenId++;

        if (supplyCap > 0)
            require(_currentTokenId - 1 < supplyCap, "E#7");

        if (isFreeMinter[msg.sender]) {
            isFreeMinter[msg.sender] = false;
        } else {
            require(msg.value > 0, "E#1");

            (, int256 ethUSDPrice, , , ) = AggregatorV3Interface(oracleDataFeed).latestRoundData();

            uint8 oracleDataDecimals = AggregatorV3Interface(oracleDataFeed).decimals();

            uint256 paidUSDAmount = (msg.value * uint256(ethUSDPrice)) / (10 ** oracleDataDecimals);

            require(paidUSDAmount >= priceUSD, "E#2");

            uint256 valueToRefund = 0;

            if (paidUSDAmount - priceUSD > 0) {
                valueToRefund = ((paidUSDAmount - priceUSD) * (10 ** oracleDataDecimals)) / uint256(ethUSDPrice);

                (bool refundSuccess, ) = msg.sender.call{value: valueToRefund }("");

                require(refundSuccess, "E#3");
            }

            (bool liquiditySendToTreasurySuccess, ) = treasuryAddress.call{value: msg.value - valueToRefund }("");

            require(liquiditySendToTreasurySuccess, "E#4");
        }

        _mint(recipient, tokenId);

        membershipCardsData[tokenId].volume = startingVolume;
        membershipCardsData[tokenId].nftPriceCap = nftPriceCap;
        membershipCardsData[tokenId].freeMultiAssetSwapCount = freeMultiAssetSwapCount;

        emit Mint(recipient, tokenId, _tokenURI, membershipCardsData[tokenId]);

        return tokenId;
    }

    function multichainTransferFrom(address from, address to, uint256 tokenId, uint256 destinationNetworkId, address destinationContractAddress) external {
        transferFrom(from, address(this), tokenId);

        _burn(tokenId);

        emit MultichainTransfer(to, tokenId, _networkId, address(this), destinationNetworkId, destinationContractAddress, membershipCardsData[tokenId]);

        delete membershipCardsData[tokenId];
    }

    function multichainClaim(address to, uint256 fromTokenId, uint256 fromNetworkId, address fromContractAddress, uint256 destinationNetworkId, address destinationContractAddress, MembershipCardData calldata membershipCardData, uint8 v, bytes32 r, bytes32 s) external returns(uint256) {
        bytes32 generatedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encode(to, fromTokenId, fromNetworkId, fromContractAddress, destinationNetworkId, destinationContractAddress, membershipCardData.volume, membershipCardData.nftPriceCap, membershipCardData.freeMultiAssetSwapCount))));

        require(isValidator[ecrecover(generatedHash, v, r, s)], "E#9");
        require(!_isMultichainHashProcessed[generatedHash], "E#10");
        require(destinationContractAddress == address(this), "E#13");
        require(destinationNetworkId == _networkId, "E#14");

        _isMultichainHashProcessed[generatedHash] = true;

        uint256 mintTokenId = _currentTokenId++;

        _mint(to, mintTokenId);

        membershipCardsData[mintTokenId].volume = membershipCardData.volume;
        membershipCardsData[mintTokenId].nftPriceCap = membershipCardData.nftPriceCap;
        membershipCardsData[mintTokenId].freeMultiAssetSwapCount = membershipCardData.freeMultiAssetSwapCount;

        emit Mint(to, mintTokenId, _tokenURI, membershipCardsData[mintTokenId]);

        emit MultichainClaim(to, mintTokenId, fromTokenId, fromNetworkId, fromContractAddress, destinationNetworkId, destinationContractAddress, membershipCardsData[mintTokenId]);

        return mintTokenId;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return _tokenURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns(bool) {
        return interfaceId == type(ERC721EnumerableUpgradeable).interfaceId || interfaceId == type(ERC721BurnableUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function __FayreMembershipCard721_init(uint256 networkId, string memory name, string memory symbol, uint256 priceUSD_, uint256 startingVolume_, uint256 supplyCap_, uint256 nftPriceCap_, uint256 freeMultiAssetSwapCount_) internal onlyInitializing {
        __Ownable_init();

        __ERC721_init(name, symbol);

        __ERC721Enumerable_init();

        __FayreMembershipCard721_init_unchained(networkId, priceUSD_, startingVolume_, supplyCap_, nftPriceCap_, freeMultiAssetSwapCount_);
    }

    function __FayreMembershipCard721_init_unchained(uint256 networkId, uint256 priceUSD_, uint256 startingVolume_, uint256 supplyCap_, uint256 nftPriceCap_, uint256 freeMultiAssetSwapCount_) internal onlyInitializing {
        _networkId = networkId;

        priceUSD = priceUSD_;

        startingVolume = startingVolume_;

        supplyCap = supplyCap_;

        nftPriceCap = nftPriceCap_;

        freeMultiAssetSwapCount = freeMultiAssetSwapCount_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        ERC721EnumerableUpgradeable._beforeTokenTransfer(from , to, tokenId);
    }

    uint256[35] private __gap;
}