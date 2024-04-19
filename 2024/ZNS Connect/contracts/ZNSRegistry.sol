// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { ZNSOracle } from "./ZNSOracle.sol";
import { ZNSGiftCard } from "./ZNSGiftCard.sol";

contract ZNSRegistryTest is
	ERC721URIStorage,
	Pausable,
	ReentrancyGuard,
	AccessControl
{
	/*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/

	uint256 public tokenID;
	bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");
	string public constant TLD = "cz";
	string constant SVG_PART_ONE =
		'<svg width="160" height="160" viewBox="0 0 1000 1000" fill="none" xmlns="http://www.w3.org/2000/svg"><g clip-path="url(#a)"><path fill="#000" d="M0 0h1000v1000H0z"/><path d="M1000 885c-178.771 139.55-551.222 50.439-1000 0v115h1000zM0 115c178.771-139.552 551.222-50.44 1000 0V0H0z" fill="#efcc4f"/><circle cx="50%" cy="180" r="70" fill="#efcc4f"/><text x="50%" y="200" text-anchor="middle" font-size="60" fill="#000" font-weight="bold" font-family="Futura">ZNS</text><text x="50%" y="755" font-size="100" text-anchor="middle" fill="#efcc4f" font-weight="bold" font-family="Futura">.cz</text></g><text x="50%" y="55%" text-anchor="middle" font-size="';
	string constant SVG_PART_TWO =
		'" fill="#efcc4f" font-weight="bold" font-family="Futura">';
	string constant SVG_PART_THREE = "</text></svg>";

	address[] profitSharingPartners = [
		0xD00c70F9b78C63a36519C488F862DF95b7A73d90
	];
	uint256[] profitSharesOfPartners = [10000];
	address public oracle = 0xc4D867696AE3465364F8bfE390f4cd572eb837bb;
	address public giftCard = 0xdc945D23D460b308dc2Fcf4FC53b5496960D2465;

	struct RegistryData {
		address owner;
		string domainName;
		uint16 lengthOfDomain;
		uint256 expirationDate;
	}

	struct UserData {
		uint256[] ownedGiftCards;
		uint256 credits;
	}

	struct UserConfig {
		uint256 primaryDomain;
		uint256[] allOwnedDomains;
		uint256 numberOfReferrals;
		uint256 totalEarnings;
	}

	enum domainStatus {
		AVAILABLE,
		REGISTERED,
		EXPIRED
	}

	mapping(uint256 => RegistryData) internal registryLookup;
	mapping(address => UserConfig) internal userLookup;
	mapping(string => uint256) public domainLookup;
	mapping(string => bool) public protectedDomains;
	mapping(address => uint256) public partnerReferrals;

	uint256[5] internal domainPricing = [99e12, 49e12, 9e12, 2e12, 5e12];
	uint256[5] internal renewPricing = [9e12, 4e12, 9e12, 2e12, 5e12];

	// 1 invites - 5%
	// 10 invites - 10-%
	// 30 invites - 15%
	// 60 invites - 20%
	// 100 invites - 25%
	uint256[5] referTicks = [500, 1000, 1500, 2000, 2500];

	constructor() ERC721("ZNS Connect", ".cz") {
		tokenID++;
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

	error InvalidLength();
	error AlreadyRegistered();
	error SelfReferral();
	error DomainExpired();
	error NotRegistered();
	error cannotBeMoreThan100Percent();
	error InvalidAddress();
	error LengthsDoNotMatch();
	error NoCredits();
	error NotOwner();
	error NotEnoughCredits();
	error RefferalEarningCannotBeCalculated();
	error DomainNotExpired();
	error NotEnoughNativeTokenPaid();
	error DomainIn30dayPeriod();
	error PriceCannotBeZero();
	error DomainExpiredButNotBurned();
	error InvalidExpiry();
	error DomainIsProtected();
	error AmountMoreThanShare();
	error InvalidDomainName();

	/*//////////////////////////////////////////////////////////////
                            CUSTOM EVENTS
    //////////////////////////////////////////////////////////////*/

	event MintedDomain(
		string domainName,
		uint256 indexed tokenId,
		address indexed owner,
		uint256 indexed expiry
	);
	event PrimaryDomainSet(uint256 indexed tokenId, address indexed owner);
	event RenewedDomain(uint256 indexed tokenId, uint256 indexed expiry);

	/*//////////////////////////////////////////////////////////////
                            PUBLIC READ FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function registryLookupByName(
		string memory domainName
	) external view returns (RegistryData memory) {
		if (checkDomainStatus(domainLookup[domainName]) == domainStatus.EXPIRED)
			revert DomainExpired();
		return registryLookup[domainLookup[domainName]];
	}

	function registryLookupById(
		uint256 tokenId
	) external view returns (RegistryData memory) {
		if (checkDomainStatus(tokenId) == domainStatus.EXPIRED)
			revert DomainExpired();
		return registryLookup[tokenId];
	}

	function checkDomainStatus(
		uint256 tokenId
	) public view returns (domainStatus status) {
		RegistryData memory _registryData = registryLookup[tokenId];
		if (
			_registryData.owner == address(0) &&
			_registryData.expirationDate == 0 &&
			_registryData.lengthOfDomain == 0
		) return domainStatus.AVAILABLE;
		else if (
			_registryData.owner != address(0) &&
			_registryData.expirationDate > block.timestamp
		) return domainStatus.REGISTERED;
		else if (
			_registryData.owner != address(0) &&
			_registryData.expirationDate < block.timestamp
		) return domainStatus.EXPIRED;
	}

	function priceToRegister(uint16 len) public view returns (uint256) {
		uint256 currentUSDPrice = getOraclePrice();
		if (len <= 0 || len > 24) revert InvalidLength();
		if (len == 1) return (domainPricing[0] * 1e18) / currentUSDPrice;
		else if (len == 2) return (domainPricing[1] * 1e18) / currentUSDPrice;
		else if (len == 3) return (domainPricing[2] * 1e18) / currentUSDPrice;
		else if (len == 4) return (domainPricing[3] * 1e18) / currentUSDPrice;
		else if (len >= 5 && len <= 24)
			return (domainPricing[4] * 1e18) / currentUSDPrice;
		else revert InvalidLength();
	}

	function priceToRenew(uint16 len) public view returns (uint256) {
		uint256 currentUSDPrice = getOraclePrice();
		if (len <= 0 || len > 24) revert InvalidLength();

		if (len == 1) return (renewPricing[0] * 1e18) / currentUSDPrice;
		else if (len == 2) return (renewPricing[1] * 1e18) / currentUSDPrice;
		else if (len == 3) return (renewPricing[2] * 1e18) / currentUSDPrice;
		else if (len == 4) return (renewPricing[3] * 1e18) / currentUSDPrice;
		else if (len >= 5 && len <= 24)
			return (renewPricing[4] * 1e18) / currentUSDPrice;
		else revert InvalidLength();
	}

	function userLookupByAddress(
		address user
	) external view returns (UserConfig memory) {
		return userLookup[user];
	}

	function getOraclePrice() public view returns (uint256) {
		return ZNSOracle(oracle).priceToUSD();
	}

	/*//////////////////////////////////////////////////////////////
                            ADMIN WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function setPartnerReferral(
		address referral,
		uint sharePercent
	) public onlyAdmin nonReentrant whenNotPaused {
		if (sharePercent > 10000) {
			revert cannotBeMoreThan100Percent();
		}
		partnerReferrals[referral] = sharePercent;
	}

	function setProfitSharingData(
		address[] memory _partners,
		uint256[] memory _percentages
	) public onlyAdmin nonReentrant whenNotPaused {
		if (_partners.length != _percentages.length) {
			revert LengthsDoNotMatch();
		}
		uint256 sum;
		for (uint256 i = 0; i < _percentages.length; i++) {
			sum += _percentages[i];
			if (isInvalidAddress(_partners[i])) revert InvalidAddress();
		}
		if (sum > 10000) {
			revert cannotBeMoreThan100Percent();
		}
		profitSharingPartners = _partners;
		profitSharesOfPartners = _percentages;
	}

	function setOracle(
		address _oracleAddress
	) public onlyAdmin nonReentrant whenNotPaused {
		if (isInvalidAddress(_oracleAddress)) revert InvalidAddress();
		oracle = _oracleAddress;
	}

	function setGiftCard(
		address _giftCardAddress
	) public onlyAdmin nonReentrant {
		if (isInvalidAddress(_giftCardAddress)) revert InvalidAddress();
		giftCard = _giftCardAddress;
	}

	function setReferTicks(
		uint256[5] memory _ticks
	) public onlyAdmin nonReentrant whenNotPaused {
		for (uint256 i = 0; i < 5; i++) {
			if (_ticks[i] > 10000) {
				revert cannotBeMoreThan100Percent();
			}
		}
		referTicks = _ticks;
	}

	function setDomainPricing(
		uint256[5] memory _domainPricing
	) external onlyAdmin nonReentrant whenNotPaused {
		if (_domainPricing.length != 5) revert InvalidLength();
		for (uint256 i = 0; i < _domainPricing.length; i++) {
			if (_domainPricing[i] == 0) revert PriceCannotBeZero();
		}
		domainPricing = _domainPricing;
	}

	function setRenewPricing(
		uint256[5] memory _renewPricing
	) external onlyAdmin nonReentrant {
		if (_renewPricing.length != 5) revert InvalidLength();
		for (uint256 i = 0; i < _renewPricing.length; i++) {
			if (_renewPricing[i] == 0) revert PriceCannotBeZero();
		}
		renewPricing = _renewPricing;
	}

	function adminWithdraw() public onlyAdmin nonReentrant {
		payable(msg.sender).transfer(address(this).balance);
	}

	function adminRegisterDomains(
		address[] memory owners,
		string[] memory domainNames,
		uint256[] memory expiries
	) public onlyAdmin nonReentrant whenNotPaused {
		uint16[] memory lengthsOfDomains = new uint16[](domainNames.length);

		for (uint256 i = 0; i < domainNames.length; i++) {
			uint16 lengthOfDomain = uint16(strlen(domainNames[i]));
			lengthsOfDomains[i] = lengthOfDomain;
		}

		mintDomains(owners, domainNames, lengthsOfDomains, expiries);
	}

	function pause() external onlyAdmin nonReentrant {
		_pause();
	}

	function unpause() external onlyAdmin nonReentrant {
		_unpause();
	}

	function protectDomains(
		string[] memory domainNames,
		bool[] memory isProtectedValues
	) external onlyAdmin nonReentrant whenNotPaused {
		if (domainNames.length != isProtectedValues.length) {
			revert LengthsDoNotMatch();
		}
		for (uint256 i = 0; i < domainNames.length; i++) {
			protectedDomains[domainNames[i]] = isProtectedValues[i];
		}
	}

	function burnExpiredDomains(
		uint256[] memory tokenIds
	) external onlyMaintainer nonReentrant whenNotPaused {
		for (uint256 i = 0; i < tokenIds.length; i++) {
			uint256 tokenId = tokenIds[i];
			if (registryLookup[tokenId].expirationDate > block.timestamp)
				revert DomainNotExpired();

			if (
				registryLookup[tokenId].expirationDate + 30 days >
				block.timestamp
			) revert DomainIn30dayPeriod();
			maintainerBurn(tokenId);
		}
	}

	/*//////////////////////////////////////////////////////////////
                            PUBLIC WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function registerDomains(
		address[] memory owners,
		string[] memory domainNames,
		uint256[] memory expiries,
		address referral,
		uint256 credits
	) external payable nonReentrant whenNotPaused {
		uint256 totalPrice;
		uint16[] memory lengthsOfDomains = new uint16[](domainNames.length);

		for (uint256 i = 0; i < domainNames.length; i++) {
			uint256 expiry = expiries[i];
			string memory domainName = domainNames[i];
			if (!isValidDomainName(domainName)) {
				revert InvalidDomainName();
			}
			if (protectedDomains[domainName]) revert DomainIsProtected();
			uint16 lengthOfDomain = uint16(strlen(domainName));
			lengthsOfDomains[i] = lengthOfDomain;

			if (!isValidLength(lengthOfDomain)) revert InvalidLength();
			if (referral == msg.sender) revert SelfReferral();

			uint256 price = priceToRegister(lengthOfDomain);
			totalPrice += price;

			if (expiry > 1) {
				totalPrice += priceToRenew(lengthOfDomain) * (expiry - 1);
			}
		}

		if (credits > 0) {
			if (ZNSGiftCard(giftCard).getUserCredits(msg.sender) < credits) {
				revert NotEnoughCredits();
			}
			uint256 creditValue = getValueFromCredits(credits);
			ZNSGiftCard(giftCard).registryBurnCredits(msg.sender, credits);
			totalPrice -= creditValue;
		}

		if (msg.value < totalPrice) revert NotEnoughNativeTokenPaid();

		uint256 earnings = totalPrice;

		if (referral != address(0)) {
			uint256 referralBand = getReferralBand(referral);
			uint256 referralInBIPS = calculateActualFromBIPS(
				totalPrice,
				referralBand
			);
			userLookup[referral].numberOfReferrals += domainNames.length;
			userLookup[referral].totalEarnings += referralInBIPS;
			payable(referral).transfer(referralInBIPS);

			earnings -= referralInBIPS;
		}
		for (uint256 i = 0; i < profitSharingPartners.length; i++) {
			payable(profitSharingPartners[i]).transfer(
				calculateActualFromBIPS(earnings, profitSharesOfPartners[i])
			);
		}
		mintDomains(owners, domainNames, lengthsOfDomains, expiries);
	}

	function renewDomain(
		uint256 _tokenId,
		uint256 _years
	) external payable nonReentrant whenNotPaused {
		if (registryLookup[_tokenId].owner != msg.sender) revert NotOwner();
		if (_years == 0) revert InvalidExpiry();
		uint256 price = priceToRenew(registryLookup[_tokenId].lengthOfDomain) *
			_years;
		if (msg.value < price) revert NotEnoughNativeTokenPaid();
		for (uint256 i = 0; i < profitSharingPartners.length; i++) {
			payable(profitSharingPartners[i]).transfer(
				calculateActualFromBIPS(price, profitSharesOfPartners[i])
			);
		}
		registryLookup[_tokenId].expirationDate += 365 days * _years;
		emit RenewedDomain(_tokenId, _years);
	}

	function setPrimaryDomain(
		uint256 _tokenId
	) external nonReentrant whenNotPaused {
		address owner = registryLookup[_tokenId].owner;
		if (owner != msg.sender) revert NotOwner();
		userLookup[owner].primaryDomain = _tokenId;
		emit PrimaryDomainSet(_tokenId, owner);
	}

	function burnDomain(uint256 _tokenId) external nonReentrant whenNotPaused {
		address owner = registryLookup[_tokenId].owner;
		if (owner != msg.sender) revert NotOwner();
		uint256[] memory ownedDomains = userLookup[owner].allOwnedDomains;
		uint256[] memory newOwnedDomains = new uint256[](
			ownedDomains.length - 1
		);
		uint256 counter = 0;
		for (uint256 i = 0; i < ownedDomains.length; i++) {
			if (ownedDomains[i] != _tokenId) {
				newOwnedDomains[counter] = ownedDomains[i];
				counter++;
			}
		}
		userLookup[owner].allOwnedDomains = newOwnedDomains;
		if (
			newOwnedDomains.length > 0 &&
			userLookup[owner].primaryDomain == _tokenId
		) {
			userLookup[owner].primaryDomain = newOwnedDomains[0];
			emit PrimaryDomainSet(newOwnedDomains[0], owner);
		} else {
			userLookup[owner].primaryDomain = 0;
			emit PrimaryDomainSet(0, owner);
		}
		delete registryLookup[_tokenId];
		_burn(_tokenId);
	}

	/*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

	function getValueFromCredits(
		uint256 credits
	) internal view returns (uint256) {
		uint256 currentUSDPrice = getOraclePrice();
		return (credits * 1e18) / currentUSDPrice;
	}

	function isValidDomainName(
		string memory domainName
	) internal pure returns (bool) {
		bytes memory domainBytes = bytes(domainName);
		for (uint i = 0; i < domainBytes.length; i++) {
			// Check for lowercase letters, numbers, and the "-" character
			if (
				!(domainBytes[i] >= 0x30 && domainBytes[i] <= 0x39) && // 0-9
				!(domainBytes[i] >= 0x61 && domainBytes[i] <= 0x7A) && // a-z
				!(domainBytes[i] == 0x2D) && // "-" character
				!(domainBytes[i] > 0x7F) // Allow non-ASCII characters (basic check for emojis and other languages)
			) {
				// If the character is not a lowercase letter, number, "-", or > 0x7F (basic non-ASCII),
				// then it's invalid based on our criteria.
				return false;
			}
		}
		// Passed all checks
		return true;
	}

	function createTokenURI(
		string memory domainName
	) internal pure returns (string memory) {
		uint256 fontSize = 0;
		uint8 length = uint8(strlen(domainName));
		if (length <= 6) fontSize = 250;
		else if (length > 6 && length <= 8) fontSize = 200;
		else if (length > 8 && length <= 10) fontSize = 160;
		else if (length > 10 && length <= 12) fontSize = 130;
		else if (length > 12 && length <= 15) fontSize = 100;
		else if (length > 15 && length <= 18) fontSize = 80;
		else fontSize = 60;

		string memory finalSvg = string(
			abi.encodePacked(
				SVG_PART_ONE,
				Strings.toString(fontSize),
				SVG_PART_TWO,
				domainName,
				SVG_PART_THREE
			)
		);

		string memory json = Base64.encode(
			abi.encodePacked(
				'{"name": "',
				domainName,
				'", "description": "A domain on ZNS Connect Name Service", "image": "data:image/svg+xml;base64,',
				Base64.encode(bytes(finalSvg)),
				'","length":"',
				Strings.toString(length),
				'"}'
			)
		);

		string memory finalTokenUri = string(
			abi.encodePacked("data:application/json;base64,", json)
		);
		return finalTokenUri;
	}

	function strlen(string memory s) internal pure returns (uint256) {
		uint256 len;
		uint256 i = 0;
		uint256 bytelength = bytes(s).length;
		for (len = 0; i < bytelength; len++) {
			bytes1 b = bytes(s)[i];
			if (b < 0x80) {
				i += 1;
			} else if (b < 0xE0) {
				i += 2;
			} else if (b < 0xF0) {
				i += 3;
			} else if (b < 0xF8) {
				i += 4;
			} else if (b < 0xFC) {
				i += 5;
			} else {
				i += 6;
			}
		}
		return len;
	}

	function isInvalidAddress(address _address) internal view returns (bool) {
		return _address == address(this) || _address == address(0);
	}

	function isValidLength(uint16 len) internal pure returns (bool) {
		return len > 0 && len <= 24;
	}

	function getReferralBand(address referral) public view returns (uint256) {
		if (partnerReferrals[referral] != 0) {
			return partnerReferrals[referral];
		}
		uint256 numberOfReferrals = userLookup[referral].numberOfReferrals;
		if (numberOfReferrals >= 0 && numberOfReferrals < 10)
			return referTicks[0];
		else if (numberOfReferrals >= 10 && numberOfReferrals < 30)
			return referTicks[1];
		else if (numberOfReferrals >= 30 && numberOfReferrals < 60)
			return referTicks[2];
		else if (numberOfReferrals >= 60 && numberOfReferrals < 100)
			return referTicks[3];
		else if (numberOfReferrals >= 100) return referTicks[4];
		else revert RefferalEarningCannotBeCalculated();
	}

	function calculateActualFromBIPS(
		uint256 price,
		uint256 bips
	) public pure returns (uint256) {
		return (price * bips) / 10000;
	}

	function mintDomains(
		address[] memory owners,
		string[] memory domainNames,
		uint16[] memory lengthsOfDomains,
		uint256[] memory expiries
	) internal whenNotPaused {
		if (
			domainNames.length != owners.length ||
			owners.length != expiries.length ||
			lengthsOfDomains.length != owners.length
		) {
			revert LengthsDoNotMatch();
		}

		uint256[] memory newTokenIds = new uint256[](domainNames.length);
		for (uint256 i = 0; i < domainNames.length; i++) {
			address owner = owners[i];
			string memory domainName = domainNames[i];
			uint256 expiry = expiries[i];
			uint16 lengthOfDomain = lengthsOfDomains[i];
			uint256 newRecordId = tokenID;
			newTokenIds[i] = newRecordId;

			if (isInvalidAddress(owners[i])) revert InvalidAddress();
			if (
				checkDomainStatus(domainLookup[domainName]) ==
				domainStatus.REGISTERED
			) revert AlreadyRegistered();
			if (
				checkDomainStatus(domainLookup[domainName]) ==
				domainStatus.EXPIRED
			) revert DomainExpiredButNotBurned();

			unchecked {
				tokenID++;
			}

			registryLookup[newRecordId] = RegistryData({
				owner: owner,
				domainName: domainName,
				lengthOfDomain: lengthOfDomain,
				expirationDate: block.timestamp + (365 days * expiry)
			});
			userLookup[owner].allOwnedDomains.push(newRecordId);
			domainLookup[domainName] = newRecordId;

			if (userLookup[owner].primaryDomain == 0) {
				userLookup[owner].primaryDomain = newRecordId;
				emit PrimaryDomainSet(newRecordId, owner);
			}

			_safeMint(owner, newRecordId);
			_setTokenURI(newRecordId, createTokenURI(domainName));
			emit MintedDomain(domainName, newRecordId, owner, expiry);
		}
	}

	function _beforeTokenTransfer(
		address from,
		address to,
		uint256 firstTokenId,
		uint256 batchSize
	) internal virtual override {
		super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
		if (from != address(0) && to != address(0)) {
			if (checkDomainStatus(firstTokenId) == domainStatus.EXPIRED)
				revert DomainExpired();
			uint256[] memory ownedDomains = userLookup[from].allOwnedDomains;
			uint256[] memory newOwnedDomains = new uint256[](
				ownedDomains.length - batchSize
			);
			uint256 counter = 0;
			for (uint256 i = 0; i < ownedDomains.length; i++) {
				if (ownedDomains[i] != firstTokenId) {
					newOwnedDomains[counter] = ownedDomains[i];
					counter++;
				}
			}
			userLookup[from].allOwnedDomains = newOwnedDomains;
			if (
				newOwnedDomains.length > 0 &&
				userLookup[from].primaryDomain == firstTokenId
			) {
				userLookup[from].primaryDomain = newOwnedDomains[0];
				emit PrimaryDomainSet(newOwnedDomains[0], from);
			} else {
				userLookup[from].primaryDomain = 0;
				emit PrimaryDomainSet(0, from);
			}
			userLookup[to].allOwnedDomains.push(firstTokenId);
			if (userLookup[to].primaryDomain == 0) {
				userLookup[to].primaryDomain = firstTokenId;
				emit PrimaryDomainSet(firstTokenId, to);
			}
			registryLookup[firstTokenId].owner = to;
		}
	}

	function maintainerBurn(uint256 tokenId) internal {
		if (tokenId == 0) revert NotRegistered();
		address owner = registryLookup[tokenId].owner;
		uint256[] memory ownedDomains = userLookup[owner].allOwnedDomains;
		uint256[] memory newOwnedDomains = new uint256[](
			ownedDomains.length - 1
		);
		uint256 counter = 0;
		for (uint256 i = 0; i < ownedDomains.length; i++) {
			if (ownedDomains[i] != tokenId) {
				newOwnedDomains[counter] = ownedDomains[i];
				counter++;
			}
		}
		userLookup[owner].allOwnedDomains = newOwnedDomains;
		if (
			newOwnedDomains.length > 0 &&
			userLookup[owner].primaryDomain == tokenId
		) {
			userLookup[owner].primaryDomain = newOwnedDomains[0];
			emit PrimaryDomainSet(newOwnedDomains[0], owner);
		} else {
			userLookup[owner].primaryDomain = 0;
			emit PrimaryDomainSet(0, owner);
		}
		delete registryLookup[tokenId];
		_burn(tokenId);
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