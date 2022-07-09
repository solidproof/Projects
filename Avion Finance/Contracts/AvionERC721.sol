//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import './interfaces/IAvionToken.sol';
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract AvionCollection is ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    VRFCoordinatorV2Interface COORDINATOR;

    error OnlyCoordinatorCanFulfill(address have, address want);

    uint256 public constant TOTAL_SUPPLY = 15000;
    uint256 constant SUBSCRIPTION_INTERVAL = 30 days;
    uint256 constant BASE_PERCENT = 1000;

    struct VRFStruct {
        address user;
        uint256 tokenID;
    }
    
    mapping(uint256 => uint256) tokenTier;
    
    bytes32 constant KEY_HASH = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
    uint256 public randomResult;

    bytes32 whitelist;

    IERC20 public BUSD;
    address public token;

    address treasury;
    address public devWallet;
    uint256 public whitelistPresalePeriodLimit;
    uint256 public publicPresalePeriodLimit;
    uint256 public currentSupply;
    uint256 mintFeeTreasuryPercent;
    uint256 mintFeeDevWalletPercent;
    string BASE_URI;
    bool public allowedToMint;
    bool public whitelistPresalePeriod;
    bool public publicPresalePeriod;

    mapping(uint256 => uint256) public totalNftMinted;
    mapping(address => uint256) public userNftMinted;
    mapping(address => uint256) public userNftMintedWhitelist;
    mapping(uint256 => VRFStruct) public VRFRequests;

    uint64 public s_subscriptionId;
    uint32 public numWords;
    uint16 public requestConfirmations;
    uint32 public callbackGasLimit;
    address public s_owner;
    bytes32 public keyHash;
    address private vrfCoordinator;

    event RewardClaimed(address indexed sender, uint256 indexed amount);

    function initialize(
        address _BUSD,
        address _treasury,
        address _devWallet
    ) public initializer {
        __ERC721_init("Avion Collection", "AC");
        __Ownable_init();

        BUSD = IERC20(_BUSD);
        treasury = _treasury;
        devWallet = _devWallet;

        whitelistPresalePeriodLimit = 1650;
        publicPresalePeriodLimit = 3150;

        mintFeeTreasuryPercent = 700;
        mintFeeDevWalletPercent = 300;
    }

    receive() external payable {}

    function setBaseURI(string memory _uri) external onlyOwner {
        BASE_URI = _uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return BASE_URI;
    }

    function tokenURI(uint256 tokenID) public view override virtual returns (string memory) {
        return string(abi.encodePacked(string(abi.encodePacked(_baseURI(), tokenTier[tokenID].toString())), ".json"));
    }

    function setChainLinkParam(
        uint64 _s_subscriptionId,
        uint32 _numWords,
        uint16 _requestConfirmations,
        uint32 _callbackGasLimit,
        address _vrfCoordinator,
        bytes32 _keyHash,
        address _owner
    ) external onlyOwner {
        s_subscriptionId = _s_subscriptionId;
        numWords = _numWords;
        requestConfirmations = _requestConfirmations;
        callbackGasLimit = _callbackGasLimit;
        s_owner = _owner;
        keyHash = _keyHash;
        vrfCoordinator = _vrfCoordinator;
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external {
        if (msg.sender != vrfCoordinator) {
        revert OnlyCoordinatorCanFulfill(msg.sender, vrfCoordinator);
        }
        fulfillRandomWords(requestId, randomWords);
    }



    /* Random */

    function getRandomNumber() internal returns (uint256 requestId) {
        return COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomness) internal {
        uint256 random = randomness[0] % TOTAL_SUPPLY;
        uint256 tier = 1;
        if (random <= 750 && totalNftMinted[3] < 750 ) {
            tier = 3;
        } else if (random <= 3000 && totalNftMinted[2] < 2250 ) {
            tier = 2;
        }
        
        tokenTier[VRFRequests[requestId].tokenID] = tier;
        totalNftMinted[tier] += 1;
    }

    
    /* Whitelist */

    function setWhitelist(bytes32 _whitelist) external onlyOwner{
        whitelist = _whitelist;
    }

    function isAddressWhitelisted(address account, bytes32[] calldata merkleProof) public view returns(bool) {
		bytes32 leaf = keccak256( abi.encodePacked(account) );
		bool whitelisted = MerkleProof.verify(merkleProof, whitelist, leaf);

		return whitelisted;
	}




    /* Mint */

    function mintInternal(uint256 _tier, address _recipient) internal {
        currentSupply += 1;
        tokenTier[currentSupply] = _tier;
        totalNftMinted[_tier] += 1;
        _mint(_recipient, currentSupply);
    }

    function _mint(uint256 _amount, uint256 _price) internal {
        require(currentSupply + _amount <= TOTAL_SUPPLY, "AC: total supply exceeded");
        distributeTokens(msg.sender, _price);
        for (uint256 i; i < _amount; i++) {
            currentSupply += 1;
            _mint(msg.sender, currentSupply);
            VRFRequests[getRandomNumber()] = VRFStruct(msg.sender, currentSupply);
        }
    }

    function mint(uint256 _amount) external {
        require(allowedToMint && !whitelistPresalePeriod && !publicPresalePeriod, "AC: can be called only when presale periods are finished");
        require(userNftMinted[msg.sender]  + _amount <= 3, "AC: maximum amount of nft per wallet exceeded");
        _mint(_amount, getPrice());
        userNftMinted[msg.sender] += _amount;
    }

    function mintForTest(uint256 _amount) external onlyOwner {
        for (uint256 i; i < _amount; i++) {
            currentSupply += 1;
            _mint(msg.sender, currentSupply);
            VRFRequests[getRandomNumber()] = VRFStruct(msg.sender, currentSupply);
        }
    }

    function mintAtPublicPresalePeriod(uint256 _amount) external {
        require(publicPresalePeriod && !whitelistPresalePeriod && !allowedToMint, "AC: can be called when only public presale period is active");
        require(currentSupply < publicPresalePeriodLimit, "AC: public presale period limit exceeded");
        require(userNftMinted[msg.sender]  + _amount <= 3, "AC: maximum amount of nft per wallet exceeded");
        _mint(_amount, 320 ether * _amount);
        userNftMinted[msg.sender] += _amount;
    }
    
    function mintAtWhitelistPresalePeriod(bytes32[] calldata merkleProof, uint256 _amount) external {
        require(whitelistPresalePeriod && !publicPresalePeriod && !allowedToMint, "AC: can be called when only whitelist presale period is active");
        require(isAddressWhitelisted(msg.sender, merkleProof), "AC: sender is not in whitelist");
        require(currentSupply < whitelistPresalePeriodLimit, "AC: whitelist presale period limit exceeded");
        require(userNftMintedWhitelist[msg.sender]  + _amount <= 2, "AC: maximum amount of nft per wallet exceeded");
        _mint(_amount, 250 ether * _amount);
        userNftMintedWhitelist[msg.sender] += _amount;
    }

    function mintToDevWallet(uint256[] calldata _tier) external onlyOwner {
        for (uint256 i = 0; i < _tier.length; ++i) {
            mintInternal(_tier[i], devWallet);
        }
    }

    function distributeTokens(address _from, uint256 _value) internal {
        uint256 toTreasury = (_value * mintFeeTreasuryPercent) / BASE_PERCENT;
        BUSD.transferFrom(_from, treasury, toTreasury);
        uint256 toDevWallet = (_value * mintFeeDevWalletPercent) / BASE_PERCENT;
        BUSD.transferFrom(_from, devWallet, toDevWallet);
    }
    
    function getPrice() public view returns (uint256) {
        if (currentSupply > 5000) {
            return 430 ether;
        } else if (currentSupply > 6000) {
            return 490 ether;
        } else if (currentSupply > 7000) {
            return 550 ether;
        } else if (currentSupply > 8000) {
            return 630 ether;
        } else if (currentSupply > 9000) {
            return 700 ether;
        } else if (currentSupply > 10000) {
            return 800 ether;
        } else if (currentSupply > 12000) {
            return 950 ether;
        } else if (currentSupply > 14000) {
            return 1100 ether;
        } else if (currentSupply > 14500) {
            return 1250 ether;
        } else {
            return 400 ether;
        }
  	}




    /* Get NFT Tier

        Tier 3 : First class tier
        Tier 2 : Business class tier
        Tier 1 : Coach class tier
        Tier 0 : No NFT

    */

    function getNftTier(uint256 tokenId) public view returns (uint256 tier) {
        return tokenTier[tokenId];
    }

    function getHigherTier(address account) public view returns (uint256 _highestTier) {
        uint256 highestTier = 0;
        uint256 tier;

        for (uint256 i; i < balanceOf(account); i++) {
            tier = getNftTier(tokenOfOwnerByIndex(account, i));
            if (tier > highestTier) highestTier = tier;
        }
        return highestTier;
    }

    function getNFTs(address account) public view returns (uint256[] memory nfts) {
        uint256 amount = balanceOf(account);
        uint256[] memory _nfts = new uint256[](amount);
        for (uint256 i; i < amount; i++) {
            _nfts[i] = tokenOfOwnerByIndex(account, i);
        }
        return _nfts;
    }


    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        uint256 highestTierFrom = 0;
        uint256 highestTierTo = getHigherTier(to);
        uint256 tier;
        uint256 _tokenId;

        if (from != address(0)) {
            for (uint256 i; i < balanceOf(from); i++) {
                _tokenId = tokenOfOwnerByIndex(from, i);
                if (tokenId == _tokenId) continue;
                tier = getNftTier(_tokenId);
                if (tier > highestTierFrom) highestTierFrom = tier;
            }  
            
            IAvionToken(token).updateYield(from, highestTierFrom);
        }
        
        if (to != address(0)) {
            tier = getNftTier(tokenId);
            if (tier > highestTierTo) highestTierTo = tier;
        
            IAvionToken(token).updateYield(to, highestTierTo);
        }
    }



    /* Settings */
    
    function setMintFeeDistribution(
        uint256 _mintFeeTreasuryPercent,
        uint256 _mintFeeDevWalletPercent
    )
        external
        onlyOwner
    {
        require(
            _mintFeeTreasuryPercent +
            _mintFeeDevWalletPercent ==
            BASE_PERCENT,
            "AC: percent sum does not equal 100%"
        );
        mintFeeTreasuryPercent = _mintFeeTreasuryPercent;
        mintFeeDevWalletPercent = _mintFeeDevWalletPercent;
    }

    function setAllowanceToMint(bool _value) external onlyOwner {
        allowedToMint = _value;
    }
    
    function setWhitelistPresalePeriod(bool _value) external onlyOwner {
        whitelistPresalePeriod = _value;
    }

    function setPublicPresalePeriod(bool _value) external onlyOwner {
        publicPresalePeriod = _value;
    }

    function setWhitelistPresalePeriodLimit(uint256 _value) external onlyOwner {
        require(_value > currentSupply, "AC: limit must exceed current supply");
        whitelistPresalePeriodLimit = _value;
    }

    function setPublicPresalePeriodLimit(uint256 _value) external onlyOwner {
        require(_value > currentSupply, "AC: limit must exceed current supply");
        publicPresalePeriodLimit = _value;
    }

    function setTokenAddress(address _token) external onlyOwner {
        token = _token;
    }

    function withdrawErc20(address _token, address _recipient) external onlyOwner {
        IERC20(_token).transfer(_recipient, IERC20(_token).balanceOf(address(this)));
    }
}