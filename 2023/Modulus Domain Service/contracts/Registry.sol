// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract IMODSMDS {
    function mintTokens(address _to) external {}
}

contract Registry is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum DomainLength {
        Three,
        Four,
        Five
    }

    struct DomainReserve {
        string name;
        bool isDomainReserve;
        bool isDomainRegister;
        bool isFreeForWallet;
        address wallet;
        uint walletPrice;
    }

    struct Domain {
        string name;
        address owner;
        bool isDomainRegister;
        uint price;
    }

    IMODSMDS public modsMNSNFT;
    IUniswapV2Router02 public uniswapRouter;
    IERC20Upgradeable public usdcToken;
    IERC20Upgradeable public daiToken;
    IERC20Upgradeable public mods;
    mapping(string => DomainReserve) public domainsReserve;
    mapping(string => Domain) public domainsPublic;
    mapping(address => string[]) private ownerDomain;
    mapping(DomainLength => uint256) public prices;
    string[] public reserveDomains;

    uint public modsHoldersDiscountPercent;
    uint public modsDiscountAmount;
    mapping(bytes1 => bool) public isDislikeSymbol;

    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event WithdrawAllEvent(address indexed to, uint256 amount);
    event PriceUpdated(DomainLength domainLength, uint256 price);
    event DislikeSymbolUpdate(string _symbol, bool _status);
    event DomainRegisterPublic(address _user, string _domain, uint _ethBalance);
    event ReserveDomainRegister(
        address _user,
        string _domain,
        uint _ethBalance
    );
    event ReserveDomainRegisterOwner(address _user, string _domain);
    event UsdcTokenUpdated(address _usdcToken);
    event DaiTokenUpdated(address _daiToken);
    event ModsTokenUpdated(address _mods);
    event ModsMNSNFTTokenUpdated(address _modsMNSNFT);
    event ModsDiscountAmountUpdated(uint _modsDiscountAmount);
    event ModsHoldersDiscountPercentUpdated(uint _modsHoldersDiscountPercent);
    event ReserveDomainRemoved(address _user, string _domain);
    event ReserveDomainUpdated(
        address _user,
        string[] _domain,
        bool _isFreeForWallet,
        address[] _wallet
    );

    function initialize(
        IMODSMDS _modsMNSNFT,
        IUniswapV2Router02 _uniswapRouter,
        IERC20Upgradeable _usdcToken,
        IERC20Upgradeable _mods,
        IERC20Upgradeable _daiToken,
        uint _modsHoldersDiscountPercent,
        uint _modsDiscountAmount
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        require(address(_modsMNSNFT) != address(0), "Invalid _modsMNSNFT");
        require(
            address(_uniswapRouter) != address(0),
            "Invalid _uniswapRouter"
        );
        require(address(_usdcToken) != address(0), "Invalid _usdcToken");
        require(address(_mods) != address(0), "Invalid _mods");
        require(address(_daiToken) != address(0), "Invalid _mods");
        modsMNSNFT = _modsMNSNFT;
        uniswapRouter = _uniswapRouter;
        usdcToken = _usdcToken;
        mods = _mods;
        daiToken = _daiToken;
        modsHoldersDiscountPercent = _modsHoldersDiscountPercent;
        modsDiscountAmount = _modsDiscountAmount;

        prices[DomainLength.Three] = 300000000;
        prices[DomainLength.Four] = 150000000;
        prices[DomainLength.Five] = 20000000;
    }

    /**
     * @notice disallow symbol.
     *
     * @param _symbol. _symbol name.
     * @param _status. true if not allow
     * _wallet. domain owner address
     *
     */
    function updateDislikeSymbol(
        string memory _symbol,
        bool _status
    ) public onlyOwner {
        bytes memory disallowedBytes = bytes(_symbol);
        for (uint i = 0; i < disallowedBytes.length; i++) {
            require(isDislikeSymbol[disallowedBytes[i]] != _status, "Failed");
            isDislikeSymbol[disallowedBytes[i]] = _status;
        }
        emit DislikeSymbolUpdate(_symbol, _status);
    }

    /**
     * @notice update reserve domain.
     *
     * @param _domain. domain name.
     * @param _isFreeForWallet. true if free
     * _wallet. domain owner address
     *
     */
    function updateReserveDomains(
        string[] memory _domain,
        bool _isFreeForWallet,
        address[] memory _wallet
    ) public onlyOwner {
        require(_domain.length == _wallet.length, "Invalid data");
        for (uint i = 0; i < _domain.length; i++) {
            DomainReserve storage _domainsReserve = domainsReserve[toLower(_domain[i])];
            require(
                _domainsReserve.isDomainRegister == false &&
                    domainsPublic[toLower(_domain[i])].isDomainRegister == false,
                "Already Buy"
            );
            require(validateString(toLower(_domain[i])), "Not Valid String");

            _domainsReserve.name = toLower(_domain[i]);
            _domainsReserve.isFreeForWallet = _isFreeForWallet;
            _domainsReserve.wallet = _wallet[i];

            if (_domainsReserve.isDomainReserve == false) {
                reserveDomains.push(toLower(_domain[i]));
            }

            _domainsReserve.isDomainReserve = true;
        }
        emit ReserveDomainUpdated(
            msg.sender,
            _domain,
            _isFreeForWallet,
            _wallet
        );
    }

    /**
     * @notice remove reserve domain.
     *
     * @param _domain. domain name.
     */
    function removeReserveDomains(string memory _domain) public onlyOwner {
        _domain = toLower(_domain);
        DomainReserve storage _domainsReserve = domainsReserve[_domain];
        require(_domainsReserve.isDomainReserve == true, "Not Reserve");
        require(_domainsReserve.isDomainRegister == false, "Already Buy");

        delete (domainsReserve[_domain]);
        emit ReserveDomainRemoved(msg.sender, _domain);
    }

    /**
     * @notice update _modsHoldersDiscountPercent amount.
     *
     * @param _modsHoldersDiscountPercent. amount of _modsHoldersDiscountPercent.
     */
    function updateModsHoldersDiscountPercent(
        uint _modsHoldersDiscountPercent
    ) public onlyOwner {
        modsHoldersDiscountPercent = _modsHoldersDiscountPercent;
        emit ModsHoldersDiscountPercentUpdated(_modsHoldersDiscountPercent);
    }

    /**
     * @notice update _modsDiscountAmount amount.
     *
     * @param _modsDiscountAmount. amount of _modsDiscountAmount.
     */
    function updateModsDiscountAmount(
        uint _modsDiscountAmount
    ) public onlyOwner {
        modsDiscountAmount = _modsDiscountAmount;
        emit ModsDiscountAmountUpdated(_modsDiscountAmount);
    }

    /**
     * @notice update _modsMNSNFT token.
     *
     * @param _modsMNSNFT. address of _modsMNSNFT.
     */
    function updateModsMNSNFT(IMODSMDS _modsMNSNFT) public onlyOwner {
        require(address(_modsMNSNFT) != address(0), "Invalid _modsMNSNFT");
        modsMNSNFT = _modsMNSNFT;
        emit ModsMNSNFTTokenUpdated(address(_modsMNSNFT));
    }

    /**
     * @notice update mods token.
     *
     * @param _mods. address of _mods.
     */
    function updateModsToken(IERC20Upgradeable _mods) public onlyOwner {
        require(address(_mods) != address(0), "Invalid _mods");
        mods = _mods;
        emit ModsTokenUpdated(address(_mods));
    }

    /**
     * @notice update usdc token.
     *
     * @param _usdcToken. address of usdc.
     */
    function updateUsdcToken(IERC20Upgradeable _usdcToken) public onlyOwner {
        require(address(_usdcToken) != address(0), "Invalid _usdcToken");
        usdcToken = _usdcToken;
        emit UsdcTokenUpdated(address(_usdcToken));
    }

    /**
     * @notice update dai token.
     *
     * @param _daiToken. address of dai.
     */
    function updateDaiToken(IERC20Upgradeable _daiToken) public onlyOwner {
        require(address(_daiToken) != address(0), "Invalid _daiToken");
        daiToken = _daiToken;
        emit DaiTokenUpdated(address(_daiToken));
    }

    /**
     * @notice return if domain is register.
     *
     * @param domainName. domain name.
     */
    function isDomainRegister(
        string memory domainName
    ) public view returns (bool) {
        domainName = toLower(domainName);
        bool _status = false;
        if (domainsReserve[domainName].isDomainRegister == true) {
            _status = true;
        } else if (domainsPublic[domainName].isDomainRegister == true) {
            _status = true;
        }
        return _status;
    }

    /**
     * @notice return if domain is reserve.
     *
     * @param domainName. domain name.
     */
    function isDomainReserve(
        string memory domainName
    ) public view returns (bool) {
        domainName = toLower(domainName);
        bool _status = false;
        if (domainsReserve[domainName].isDomainReserve == true) {
            _status = true;
        }
        return _status;
    }

    /**
     * @notice return domains list of user.
     *
     * @param _user. user address.
     */
    function userDomains(address _user) public view returns (string[] memory) {
        return ownerDomain[_user];
    }

    /**
     * @notice get USDC price in usdc.
     *
     * @param _amount. amount in usdc.
     */
    function getUSDCPriceInETH(uint _amount) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdcToken);
        path[1] = uniswapRouter.WETH(); // ETH address

        if (_amount == 0) {
            return 0;
        }
        uint256[] memory amounts = uniswapRouter.getAmountsOut(_amount, path); // 1 ETH (1e18 wei)
        uint256 ethPrice = amounts[1]; // USDC amount

        return ethPrice;
    }

    /**
     * @notice get mods tokens for eth profit.
     */
    function getModsPriceInUsdc() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(daiToken);
        path[1] = address(mods);

        if (modsDiscountAmount == 0) {
            return 0;
        }
        uint256[] memory amounts = uniswapRouter.getAmountsOut(
            modsDiscountAmount,
            path
        ); // 1 ETH (1e18 wei)
        uint256 usdPrice = amounts[1]; // USDC amount

        return usdPrice;
    }

    /**
     * @notice get user discount status.
     *
     * @param _user. address of user.
     */
    function isUserReceiveDiscount(address _user) public view returns (bool) {
        uint modsBalance = IERC20Upgradeable(mods).balanceOf(_user);
        if (getModsPriceInUsdc() <= modsBalance) {
            return true;
        }
        return false;
    }

    /**
     * @notice update price of domain.
     *
     * @param domainLength. domain length.
     * @param newPrice. newPrice new price of domain.
     */
    function updatePrice(
        DomainLength domainLength,
        uint256 newPrice
    ) external onlyOwner {
        prices[domainLength] = newPrice;
        emit PriceUpdated(domainLength, newPrice);
    }

    /**
     * @notice Buy reserve domain by owner.
     *
     * @param _domain. _domain name.
     */
    function buyReserveDomainByOwner(string memory _domain) public onlyOwner {
        _domain = toLower(_domain);
        require(
            domainsReserve[_domain].isDomainRegister == false,
            "Domain Reserved"
        );
        require(validateString(_domain), "Not Valid String");
        require(bytes(_domain).length > 2, "Not Available");

        require(
            domainsPublic[_domain].isDomainRegister == false,
            "Not Available"
        );

        if (domainsReserve[_domain].isDomainReserve == true) {
            require(
                domainsReserve[_domain].wallet == address(0),
                "Can not mint by owner"
            );
            DomainReserve storage _domainsReserve = domainsReserve[_domain];
            _domainsReserve.isDomainRegister = true;
            _domainsReserve.name = _domain;
            _domainsReserve.wallet = msg.sender;
        } else {
            Domain storage domain_ = domainsPublic[_domain];
            domain_.isDomainRegister = true;
            domain_.name = _domain;
            domain_.owner = msg.sender;
        }
        ownerDomain[msg.sender].push(_domain);
        modsMNSNFT.mintTokens(msg.sender);

        emit ReserveDomainRegisterOwner(msg.sender, _domain);
    }

    /**
     * @notice Buy reserve domain by reserve wallet.
     *
     * @param _domain. _domain name.
     */
    function buyReserveDomain(string memory _domain) public payable {
        _domain = toLower(_domain);
        require(
            domainsReserve[_domain].isDomainReserve == true,
            "Domain not Reserved"
        );
        require(validateString(_domain), "Not Valid String");
        require(
            domainsReserve[_domain].isDomainRegister == false,
            "Domain Registerd"
        );
        require(bytes(_domain).length > 2, "Not Available");

        require(
            msg.sender == domainsReserve[_domain].wallet,
            "Not correct owner"
        );
        uint _ethBalance = msg.value;
        uint _ethPrice = getUSDCPriceInETH(calculateDomainPrice(_domain));
        uint modsBalance = IERC20Upgradeable(mods).balanceOf(msg.sender);
        if (getModsPriceInUsdc() <= modsBalance) {
            _ethPrice = (_ethPrice -
                (_ethPrice * modsHoldersDiscountPercent) /
                100);
        }
        if (domainsReserve[_domain].isFreeForWallet == true) {
            _ethPrice = 0;
        }
        require(_ethBalance >= _ethPrice, "Incorrect amount of Ether sent");

        DomainReserve storage _domainsReserve = domainsReserve[_domain];
        _domainsReserve.isDomainRegister = true;
        _domainsReserve.name = _domain;
        _domainsReserve.walletPrice = _ethPrice;

        ownerDomain[msg.sender].push(_domain);
        modsMNSNFT.mintTokens(msg.sender);
        if((_ethBalance - _ethPrice) > 0) {
            payable(msg.sender).transfer(_ethBalance - _ethPrice);
        }

        emit ReserveDomainRegister(msg.sender, _domain, _ethPrice);
    }

    /**
     * @notice Buy public domain by any user.
     *
     * @param _domain. _domain name.
     */
    function registerDomainPublic(string memory _domain) public payable {
        _domain = toLower(_domain);
        require(
            domainsReserve[_domain].isDomainReserve != true,
            "Domain Reserved"
        );
        require(validateString(_domain), "Not Valid String");
        require(bytes(_domain).length > 2, "Not Available");
        require(
            domainsPublic[_domain].isDomainRegister == false,
            "Not Available"
        );

        uint _ethBalance = msg.value;
        uint _ethPrice = getUSDCPriceInETH(calculateDomainPrice(_domain));
        uint modsBalance = IERC20Upgradeable(mods).balanceOf(msg.sender);
        if (getModsPriceInUsdc() <= modsBalance) {
            _ethPrice = (_ethPrice -
                (_ethPrice * modsHoldersDiscountPercent) /
                100);
        }
        require(_ethBalance >= _ethPrice, "Incorrect amount of Ether sent");

        Domain storage domain_ = domainsPublic[_domain];
        domain_.isDomainRegister = true;
        domain_.name = _domain;
        domain_.owner = msg.sender;
        domain_.price = _ethPrice;

        ownerDomain[msg.sender].push(_domain);
        modsMNSNFT.mintTokens(msg.sender);
        if((_ethBalance - _ethPrice) > 0) {
            payable(msg.sender).transfer(_ethBalance - _ethPrice);
        }

        emit DomainRegisterPublic(msg.sender, _domain, _ethPrice);
    }

    function calculateDomainPrice(
        string memory domainName
    ) internal view returns (uint256) {
        uint256 length = bytes(domainName).length;

        if (length == 3) {
            return prices[DomainLength.Three];
        } else if (length == 4) {
            return prices[DomainLength.Four];
        } else {
            return prices[DomainLength.Five];
        }
    }

    /**
     * @notice Allows owner to withdraw funds generated from sale.
     */
    function withdrawAll() external onlyOwner {
        address _to = msg.sender;
        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NO ETHER TO WITHDRAW");

        payable(_to).transfer(contractBalance);
        emit WithdrawAllEvent(_to, contractBalance);
    }

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function validateString(string memory _input) internal view returns (bool) {
        bytes memory inputBytes = bytes(_input);
        for (uint256 i = 0; i < inputBytes.length; i++) {
            if (isDislikeSymbol[inputBytes[i]]) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);

        for (uint i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }

        return string(bLower);
    }
}