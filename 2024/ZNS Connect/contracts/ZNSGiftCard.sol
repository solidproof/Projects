// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { ZNSOracle } from "./ZNSOracle.sol";

contract ZNSGiftCard is
	ERC721URIStorage,
	Pausable,
	ReentrancyGuard,
	AccessControl
{
	/*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

	uint256 public giftTokenID;
	mapping(uint256 => uint256) public giftCardBalances;
	string public tokenURI;

	address public oracle = 0xc4D867696AE3465364F8bfE390f4cd572eb837bb;

	struct UserData {
		uint256 credits;
		uint256[] ownedGiftCards;
	}

	mapping(address => UserData) internal userData;
	address public treasury;
	address public registry;

	bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

	constructor(
		string memory _tokenURI
	) ERC721("ZNS Gift Cards", "ZNSGiftCard") {
		tokenURI = _tokenURI;
		giftTokenID++;
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(MAINTAINER_ROLE, msg.sender);
	}

	/*//////////////////////////////////////////////////////////////
                            CUSTOM MODIFIERS
    //////////////////////////////////////////////////////////////*/

	modifier onlyMaintainer() {
		require(
			hasRole(MAINTAINER_ROLE, msg.sender),
			"maintainer role required"
		);
		_;
	}

	modifier onlyAdmin() {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "admin role required");
		_;
	}

	/*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

	error InvalidAddress();
	error NotEnoughNativeTokenPaid();
	error AmountMustBeGreaterThanZero();
	error NotOwner();
	error NotEnoughCredits();
	error LengthsDoNotMatch();

	/*//////////////////////////////////////////////////////////////
                            USER READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function getUserCredits(address _user) public view returns (uint256) {
		return userData[_user].credits;
	}

	function getUserOwnedGiftCards(
		address _user
	) public view returns (uint256[] memory) {
		return userData[_user].ownedGiftCards;
	}

	function getOraclePrice() public view returns (uint256) {
		return ZNSOracle(oracle).priceToUSD();
	}

	/*//////////////////////////////////////////////////////////////
                            USER WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function mintGiftCard(
		address _to
	) public payable whenNotPaused nonReentrant {
		if (msg.value <= 0) revert AmountMustBeGreaterThanZero();
		if (isInvalidAddress(_to)) revert InvalidAddress();
		uint256 credits = getCreditsFromValue(msg.value);
		if (credits <= 0) revert NotEnoughNativeTokenPaid();
		giftCardBalances[giftTokenID] = credits;
		userData[_to].ownedGiftCards.push(giftTokenID);
		_safeMint(_to, giftTokenID);
		_setTokenURI(giftTokenID, tokenURI);
		payable(treasury).transfer(msg.value);
		unchecked {
			giftTokenID++;
		}
	}

	function burnGiftCard(uint256 _tokenId) public whenNotPaused nonReentrant {
		if (msg.sender != ownerOf(_tokenId)) revert NotOwner();
		userData[msg.sender].credits += giftCardBalances[_tokenId];
		giftCardBalances[_tokenId] = 0;
		uint256[] memory newOwnedCards = new uint256[](
			userData[msg.sender].ownedGiftCards.length - 1
		);
		uint256 counter = 0;
		uint256[] memory ownedCards = userData[msg.sender].ownedGiftCards;
		for (uint256 i = 0; i < ownedCards.length; i++) {
			if (ownedCards[i] != _tokenId) {
				newOwnedCards[counter] = ownedCards[i];
				counter++;
			}
		}
		userData[msg.sender].ownedGiftCards = newOwnedCards;
		_burn(_tokenId);
	}

	/*//////////////////////////////////////////////////////////////
                            ADMIN WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function adminMintGiftCards(
		address[] memory _to,
		uint256[] memory _amountOfCredits
	) public onlyAdmin nonReentrant whenNotPaused {
		if (_to.length != _amountOfCredits.length) revert LengthsDoNotMatch();

		for (uint256 i = 0; i < _to.length; i++) {
			if (isInvalidAddress(_to[i])) revert InvalidAddress();
			uint newGiftTokenID = giftTokenID;
			userData[_to[i]].ownedGiftCards.push(newGiftTokenID);
			giftCardBalances[newGiftTokenID] = _amountOfCredits[i];
			_safeMint(_to[i], newGiftTokenID);
			_setTokenURI(newGiftTokenID, tokenURI);
			unchecked {
				giftTokenID++;
			}
		}
	}

	function setTreasury(
		address _treasury
	) public onlyAdmin nonReentrant whenNotPaused {
		if (isInvalidAddress(_treasury)) revert InvalidAddress();
		treasury = _treasury;
	}

	function adminWithdraw() public onlyAdmin nonReentrant whenNotPaused {
		payable(msg.sender).transfer(address(this).balance);
	}

	function setRegistry(
		address _registry
	) public onlyAdmin nonReentrant whenNotPaused {
		if (isInvalidAddress(_registry)) revert InvalidAddress();
		registry = _registry;
		_grantRole(MAINTAINER_ROLE, registry);
	}

	function registryBurnCredits(
		address _to,
		uint256 _amountOfCredits
	) public onlyMaintainer nonReentrant whenNotPaused {
		if (_amountOfCredits <= 0) revert AmountMustBeGreaterThanZero();
		if (isInvalidAddress(_to)) revert InvalidAddress();
		if (userData[_to].credits < _amountOfCredits) revert NotEnoughCredits();
		userData[_to].credits -= _amountOfCredits;
	}

	function setTokenURI(
		string memory _tokenURI
	) public onlyAdmin whenNotPaused nonReentrant {
		tokenURI = _tokenURI;
	}

	function setOracle(
		address _oracleAddress
	) public onlyAdmin nonReentrant whenNotPaused {
		if (isInvalidAddress(_oracleAddress)) revert InvalidAddress();
		oracle = _oracleAddress;
	}

	/*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function isInvalidAddress(address _address) internal view returns (bool) {
		return _address == address(this) || _address == address(0);
	}

	function getCreditsFromValue(
		uint256 _value
	) internal view returns (uint256) {
		uint256 currentUSDPrice = getOraclePrice();
		return (_value * currentUSDPrice) / 1e18;
	}

	/*//////////////////////////////////////////////////////////////
                            DEPENDANCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function supportsInterface(
		bytes4 interfaceId
	)
		public
		view
		virtual
		override(ERC721URIStorage, AccessControl)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}
}