// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./lib/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./lib/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "./lib/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./lib/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./lib/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./lib/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./lib/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./lib/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./lib/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import "./interfaces/Aggregator.sol";
import "./interfaces/Vault.sol";

contract PresaleBASEV5 is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
   
    uint256 public startTime;
    uint256 public endTime;
    uint256 public baseDecimals;

    uint256 public usdRaised;
    address public admin;
    address public paymentWallet;

    IERC20Upgradeable public USDTInterface;
    Aggregator public aggregatorInterface;
    mapping(address => uint256) public userPresales;

    event SaleTimeSet(uint256 _start, uint256 _end, uint256 timestamp);

    event SaleTimeUpdated(
        bytes32 indexed key,
        uint256 prevValue,
        uint256 newValue,
        uint256 timestamp
    );
    event TokensPresale(
        address indexed user,
        address indexed purchaseToken,
        uint256 amountPaid,
        uint256 usdEq,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeV5() public reinitializer(5) {

    }
    
    /**
     * @dev To pause the presale
     */
    function pause() external onlyOwner {
        //_pause();
    }

    /**
     * @dev To unpause the presale
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /**
     * @dev To update the sale times
     * @param _startTime New start time
     * @param _endTime New end time
     */
    function changeSaleTimes(uint256 _startTime, uint256 _endTime)
        external
        onlyOwner
    {
        require(_startTime > 0 || _endTime > 0, "Invalid parameters");
        if (_startTime > 0) {
            require(block.timestamp < startTime, "Sale already started");
            require(block.timestamp < _startTime, "Sale time in past");
            uint256 prevValue = startTime;
            startTime = _startTime;
            emit SaleTimeUpdated(
                bytes32("START"),
                prevValue,
                _startTime,
                block.timestamp
            );
        }

        if (_endTime > 0) {
            require(_endTime > startTime, "Invalid endTime");
            uint256 prevValue = endTime;
            endTime = _endTime;
            emit SaleTimeUpdated(
                bytes32("END"),
                prevValue,
                _endTime,
                block.timestamp
            );
        }
    }

    /**
     * @dev To get latest ETH price in 10**18 format
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10**10));
        return uint256(price);
    }

    modifier checkSaleState() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Invalid time for buying"
        );
        require(
            claimingActive == false,
            "Claiming is active"
        );
        require(
            paymentWallet != address(0), 
            "Payment address cannot be zero");
        _;
    }

    /**
     * @dev To buy into a presale using USDT
     */
    function buyWithUSDT(uint256 usdAmount)
        external
        checkSaleState
        whenNotPaused
        returns (bool)
    {        
        require(usdAmount > 0, "Invalid amount");

        uint256 formatAmount = usdAmount * (10**12);

        userPresales[_msgSender()] += formatAmount;
        usdRaised += formatAmount;

        uint256 ourAllowance = USDTInterface.allowance(
            _msgSender(),
            address(this)
        );
        require(usdAmount <= ourAllowance, "Make sure to add enough allowance");

        (bool success, ) = address(USDTInterface).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                paymentWallet,
                usdAmount
            )
        );
        require(success, "Token payment failed");

        emit TokensPresale(
            _msgSender(),
            address(USDTInterface),
            usdAmount,
            formatAmount,
            block.timestamp
        );
        return true;
    }

    /**
     * @dev To buy into a presale using ETH
     */
    function buyWithETH()
        external
        payable
        checkSaleState
        whenNotPaused
        nonReentrant
        returns (bool)
    {       
        require(msg.value > 0, "Must send some Ether");        

        uint256 ethPrice = getLatestPrice();
        uint256 usdAmount = (msg.value * ethPrice) / (10**18);

        userPresales[_msgSender()] += usdAmount;
        usdRaised += usdAmount;

        sendValue(payable(paymentWallet), msg.value);

        emit TokensPresale(
            _msgSender(),
            address(0),
            msg.value,
            usdAmount,
            block.timestamp
        );

        return true;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    /**
     * @dev To set payment wallet address
     * @param _newPaymentWallet new payment wallet address
     */
    function changePaymentWallet(address _newPaymentWallet) external onlyOwner {
        require(_newPaymentWallet != address(0), "address cannot be zero");
        paymentWallet = _newPaymentWallet;
    }

    /**
     * @dev To set admin
     * @param _admin new admin wallet address
     */
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    /* v4 Add Token AirDrop*/
    
    mapping(address => uint256) airdropAmounts;

    bool public claimingActive;
    IERC20Upgradeable public preSaleToken;

    event AirdropClaimed(address indexed claimant, uint256 amount);

    function setPreSaleToken(address _tokenAddr) external onlyOwner {
        require(_tokenAddr != address(0), "address cannot be zero");
        require(claimingActive == false , "Claiming is active");
        preSaleToken =  IERC20Upgradeable(_tokenAddr);
    }

    function startClaiming() external onlyOwner {
        claimingActive = true;
    }

    function addAirDrop(address[] memory recipients, uint256[] memory amounts)  external onlyOwner {
        require(recipients.length == amounts.length, "Arrays must have same length");
        for (uint256 i = 0; i < recipients.length; i++) {
            airdropAmounts[recipients[i]] += amounts[i];
        }
    }

    function claim() external {
        require(claimingActive, "Claiming is not active");
        uint256 amount = airdropAmounts[msg.sender];
        require(amount > 0, "No airdrop available for this address");

        airdropAmounts[msg.sender] = 0;
        require(preSaleToken.transfer(msg.sender, amount), "Transfer failed");

        emit AirdropClaimed(msg.sender, amount);
    }

    function airdropAmount(address _address) external view returns (uint256) {
        return airdropAmounts[_address];
    }
}