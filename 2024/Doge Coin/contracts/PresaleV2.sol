//SPDX-License-Identifier: MIT
//               _    _____                                        _
// __      _____| |__|___ / _ __   __ _ _   _ _ __ ___   ___ _ __ | |_ ___
// \ \ /\ / / _ \ '_ \ |_ \| '_ \ / _` | | | | '_ ` _ \ / _ \ '_ \| __/ __|
//  \ V  V /  __/ |_) |__) | |_) | (_| | |_| | | | | | |  __/ | | | |_\__ \
//   \_/\_/ \___|_.__/____/| .__/ \__,_|\__, |_| |_| |_|\___|_| |_|\__|___/
//                         |_|          |___/
//

pragma solidity ^0.8.9;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface Aggregator {
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface StakingManagerInterface {
    function depositByPresale(address _user, uint256 _amount) external;
}

contract PresaleV2 is Initializable, ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    uint256 public totalTokensSold;
    uint256 public startTime;
    uint256 public startPrice;
    bool public claimStart;
    address public saleToken;
    uint256 public baseDecimals;
    uint256 public maxTokensToBuy;
    uint256 public usdRaised;
    uint256 public timeConstant;
    uint256 public totalBoughtAndStaked;
    uint256[] public percentages;
    address[] public wallets;
    address public paymentWallet;
    bool public whitelistClaimOnly;
    bool public stakingWhitelistStatus;

    IERC20Upgradeable public USDTInterface;
    Aggregator public aggregatorInterface;
    mapping(address => uint256) public userDeposits;
    mapping(address => bool) public hasClaimed;
    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public wertWhitelisted;

    StakingManagerInterface public stakingManagerInterface;

    event SaleTimeSet(uint256 _start, uint256 timestamp);
    event SaleTimeUpdated(bytes32 indexed key, uint256 prevValue, uint256 newValue, uint256 timestamp);
    event TokensBought(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 amountPaid, uint256 usdEq, uint256 timestamp);
    event TokensAdded(address indexed token, uint256 timestamp);
    event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event ClaimStartUpdated(uint256 timestamp);
    event MaxTokensUpdated(uint256 prevValue, uint256 newValue, uint256 timestamp);
    event TokensBoughtAndStaked(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 amountPaid, uint256 usdEq, uint256 timestamp);
    event TokensClaimedAndStaked(address indexed user, uint256 amount, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
   * @dev Initializes the contract and sets key parameters
   * @param _oracle Oracle contract to fetch ETH/USDT price
   * @param _usdt USDT token contract address
   * @param _startTime start time of the presale
   * @param _paymentWallet address to recive payments
   */
    function initialize(
        address _oracle,
        address _usdt,
        uint256 _startTime,
        uint256 _startPrice,
        address _paymentWallet
    ) external initializer {
        require(_oracle != address(0), "Zero aggregator address");
        require(_usdt != address(0), "Zero USDT address");
        require(_startTime > block.timestamp, "Invalid time");
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        startTime = _startTime;
        startPrice = _startPrice;
        baseDecimals = (10 ** 18);
        aggregatorInterface = Aggregator(_oracle);
        USDTInterface = IERC20Upgradeable(_usdt);
        paymentWallet = _paymentWallet;
        timeConstant = 1 days;
        emit SaleTimeSet(startTime, block.timestamp);
    }

    /**
     * @dev To pause the presale
   */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev To unpause the presale
   */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev To calculate the price in USD of token.
   */
    function calculatePrice() public view returns (uint256) {
        uint256 currentCheckPoint = (block.timestamp - startTime) / timeConstant;
        uint256 currentPrice = startPrice + (5 * startPrice * currentCheckPoint) / 1000;
        return currentPrice;
    }

    /**
     * @dev To update the sale times
   * @param _startTime New start time
   */
    function changeSaleTimes(uint256 _startTime) external onlyOwner {
        require(_startTime > 0, "Invalid parameters");
        require(block.timestamp < startTime, "Sale already started");
        require(block.timestamp < _startTime, "Sale time in past");
        uint256 prevValue = startTime;
        startTime = _startTime;
        emit SaleTimeUpdated(bytes32("START"), prevValue, _startTime, block.timestamp);
    }

    /**
     * @dev To get latest ETH price in 10**18 format
   */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function setSplits(address[] memory _wallets, uint256[] memory _percentages) public onlyOwner {
        require(_wallets.length == _percentages.length, "Mismatched arrays");
        delete wallets;
        delete percentages;
        uint256 totalPercentage = 0;

        for (uint256 i = 0; i < _wallets.length; i++) {
            require(_percentages[i] > 0, "Percentage must be greater than 0");
            totalPercentage += _percentages[i];
            wallets.push(_wallets[i]);
            percentages.push(_percentages[i]);
        }

        require(totalPercentage == 100, "Total percentage must equal 100");
    }

    modifier checkSaleState() {
        require(block.timestamp >= startTime, "Invalid time for buying");
        _;
    }

    /**
     * @dev To buy into a presale using USDT
   * @param usdAmount No of usd to buy
   * @param stake boolean flag for token staking
   */
    function buyWithUSDT(uint256 usdAmount, bool stake) external checkSaleState() whenNotPaused returns (bool) {
        uint256 usdPrice = calculatePrice();
        uint256 amount = usdAmount / usdPrice;
        totalTokensSold += amount;
        uint256 price = usdAmount / (10 ** 12);
        if (stake) {
            if (stakingWhitelistStatus) {
                require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
            }
            stakingManagerInterface.depositByPresale(_msgSender(), amount * baseDecimals);
            totalBoughtAndStaked += amount;
            emit TokensBoughtAndStaked(_msgSender(), amount, address(USDTInterface), price, usdPrice, block.timestamp);
        } else {
            userDeposits[_msgSender()] += (amount * baseDecimals);
            emit TokensBought(_msgSender(), amount, address(USDTInterface), price, usdPrice, block.timestamp);
        }
        usdRaised += usdPrice;
        uint256 ourAllowance = USDTInterface.allowance(_msgSender(), address(this));
        require(price <= ourAllowance, "Make sure to add enough allowance");
        splitUSDTValue(price);

        return true;
    }

    /**
     * @dev To buy into a presale using ETH
   * @param stake boolean flag for token staking
   */
    function buyWithEth(bool stake) external payable checkSaleState() whenNotPaused nonReentrant returns (bool) {
        uint256 usdPrice = calculatePrice();
        uint256 ethAmount = msg.value;
        uint256 amount = ethToAmountHelper(ethAmount) / baseDecimals;
        totalTokensSold += amount;
        if (stake) {
            if (stakingWhitelistStatus) {
                require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
            }
            stakingManagerInterface.depositByPresale(_msgSender(), amount * baseDecimals);
            totalBoughtAndStaked += amount;
            emit TokensBoughtAndStaked(_msgSender(), amount, address(0), ethAmount, usdPrice, block.timestamp);
        } else {
            userDeposits[_msgSender()] += (amount * baseDecimals);
            emit TokensBought(_msgSender(), amount, address(0), ethAmount, usdPrice, block.timestamp);
        }
        usdRaised += usdPrice;
        splitETHValue(ethAmount);
        return true;
    }

    /**
     * @dev To buy ETH directly from wert .*wert contract address should be whitelisted if wertBuyRestrictionStatus is set true
   * @param _user address of the user
   * @param stake boolean flag for token staking
   */
    function buyWithETHWert(address _user, bool stake) external payable checkSaleState() whenNotPaused nonReentrant returns (bool) {
        uint256 usdPrice = calculatePrice();
        uint256 ethAmount = msg.value;
        uint256 _amount = ethToAmountHelper(ethAmount) / baseDecimals;
        totalTokensSold += _amount;
        if (stake) {
            if (stakingWhitelistStatus) {
                require(isWhitelisted[_user], "User not whitelisted for stake");
            }
            stakingManagerInterface.depositByPresale(_user, _amount * baseDecimals);
            totalBoughtAndStaked += _amount;
            emit TokensBoughtAndStaked(_user, _amount, address(0), ethAmount, usdPrice, block.timestamp);
        } else {
            userDeposits[_user] += (_amount * baseDecimals);
            emit TokensBought(_user, _amount, address(0), ethAmount, usdPrice, block.timestamp);
        }
        usdRaised += usdPrice;
        splitETHValue(ethAmount);
        return true;
    }

    /**
     * @dev Helper funtion to get ETH price for given amount
     * @param amount No of tokens to buy
    */
    function ethBuyHelper(uint256 amount) external view returns (uint256 ethAmount) {
        uint256 usdPrice = calculatePrice() * amount;
        ethAmount = (usdPrice * baseDecimals) / getLatestPrice();
    }

    /**
     * @dev Helper funtion to get USDT price for given amount
     * @param amount No of tokens to buy
   */
    function usdtBuyHelper(uint256 amount) external view returns (uint256 usdPrice) {
        usdPrice = calculatePrice() * amount;
        usdPrice = usdPrice / (10 ** 12);
    }

    /**
     * @dev Helper funtion to get amount for given ETH
     * @param amount No of tokens to buy
    */
    function ethToAmountHelper(uint256 ethAmount) public view returns (uint256 amount) {
        uint256 usdPrice = calculatePrice();
        amount = (ethAmount * getLatestPrice()) / usdPrice;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    function splitETHValue(uint256 _amount) internal {
        if (wallets.length == 0) {
            require(paymentWallet != address(0), "Payment wallet not set");
            sendValue(payable(paymentWallet), _amount);
        } else {
            uint256 tempCalc;
            for (uint256 i = 0; i < wallets.length; i++) {
                uint256 amountToTransfer = (_amount * percentages[i]) / 100;
                sendValue(payable(wallets[i]), amountToTransfer);
                tempCalc += amountToTransfer;
            }
            if ((_amount - tempCalc) > 0) {
                sendValue(payable(wallets[wallets.length - 1]), _amount - tempCalc);
            }
        }
    }

    function splitUSDTValue(uint256 _amount) internal {
        if (wallets.length == 0) {
            require(paymentWallet != address(0), "Payment wallet not set");
            (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), paymentWallet, _amount));
            require(success, "Token payment failed");
        } else {
            uint256 tempCalc;
            for (uint256 i = 0; i < wallets.length; i++) {
                uint256 amountToTransfer = (_amount * percentages[i]) / 100;
                (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), wallets[i], amountToTransfer));
                require(success, "Token payment failed");
                tempCalc += amountToTransfer;
            }
            if ((_amount - tempCalc) > 0) {
                (bool success, ) = address(USDTInterface).call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), wallets[wallets.length - 1], _amount - tempCalc));
                require(success, "Token payment failed");
            }
        }
    }

    /**
     * @dev to initialize staking manager with new addredd
   * @param _stakingManagerAddress address of the staking smartcontract
   */
    function setStakingManager(address _stakingManagerAddress) external onlyOwner {
        require(_stakingManagerAddress != address(0), "staking manager cannot be inatialized with zero address");
        stakingManagerInterface = StakingManagerInterface(_stakingManagerAddress);
        IERC20Upgradeable(saleToken).approve(_stakingManagerAddress, type(uint256).max);
    }

    /**
     * @param _saleToken sale toke address
     * @param _stakingManagerAddress staking manager address
   */
    function startClaim(address _saleToken, address _stakingManagerAddress) external onlyOwner returns (bool) {
        require(_saleToken != address(0), "Zero token address");
        saleToken = _saleToken;
        whitelistClaimOnly = true;
        stakingManagerInterface = StakingManagerInterface(_stakingManagerAddress);
        IERC20Upgradeable(_saleToken).approve(_stakingManagerAddress, type(uint256).max);
        emit TokensAdded(_saleToken, block.timestamp);
        return true;
    }

    /**
     * @dev To set status for claim whitelisting
   * @param _status bool value
   */
    function setStakeingWhitelistStatus(bool _status) external onlyOwner {
        stakingWhitelistStatus = _status;
    }

    /**
     * @dev To change the claim start time by the owner
   * @param _claimStart is started
   */
    function changeClaimStart(bool _claimStart) external onlyOwner returns (bool) {
        claimStart = _claimStart;
        return true;
    }

    /**
     * @dev To claim tokens after claiming starts
   */
    function claim() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
        if (whitelistClaimOnly) {
            require(isWhitelisted[_msgSender()], "User not whitelisted for claim");
        }
        require(claimStart, "Claim has not started yet");
        require(!hasClaimed[_msgSender()], "Already claimed");
        hasClaimed[_msgSender()] = true;
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to claim");
        delete userDeposits[_msgSender()];
        bool success = IERC20Upgradeable(saleToken).transfer(_msgSender(), amount);
        require(success, "Token transfer failed");
        emit TokensClaimed(_msgSender(), amount, block.timestamp);
        return true;
    }

    function claimAndStake() external whenNotPaused returns (bool) {
        require(saleToken != address(0), "Sale token not added");
        require(!isBlacklisted[_msgSender()], "This Address is Blacklisted");
        if (stakingWhitelistStatus) {
            require(isWhitelisted[_msgSender()], "User not whitelisted for stake");
        }
        uint256 amount = userDeposits[_msgSender()];
        require(amount > 0, "Nothing to stake");
        stakingManagerInterface.depositByPresale(_msgSender(), amount);
        delete userDeposits[_msgSender()];
        emit TokensClaimedAndStaked(_msgSender(), amount, block.timestamp);
        return true;
    }

    /**
     * @dev To add wert contract addresses to whitelist
   * @param _addressesToWhitelist addresses of the contract
   */
    function whitelistUsersForWERT(address[] calldata _addressesToWhitelist) external onlyOwner {
        for (uint256 i = 0; i < _addressesToWhitelist.length; i++) {
            wertWhitelisted[_addressesToWhitelist[i]] = true;
        }
    }

    /**
     * @dev To remove wert contract addresses to whitelist
   * @param _addressesToRemoveFromWhitelist addresses of the contracts
   */
    function removeFromWhitelistForWERT(address[] calldata _addressesToRemoveFromWhitelist) external onlyOwner {
        for (uint256 i = 0; i < _addressesToRemoveFromWhitelist.length; i++) {
            wertWhitelisted[_addressesToRemoveFromWhitelist[i]] = false;
        }
    }

    function changeMaxTokensToBuy(uint256 _maxTokensToBuy) external onlyOwner {
        require(_maxTokensToBuy > 0, "Zero max tokens to buy value");
        uint256 prevValue = maxTokensToBuy;
        maxTokensToBuy = _maxTokensToBuy;
        emit MaxTokensUpdated(prevValue, _maxTokensToBuy, block.timestamp);
    }

    /**
     * @dev To add users to blacklist which restricts blacklisted users from claiming
   * @param _usersToBlacklist addresses of the users
   */
    function blacklistUsers(address[] calldata _usersToBlacklist) external onlyOwner {
        for (uint256 i = 0; i < _usersToBlacklist.length; i++) {
            isBlacklisted[_usersToBlacklist[i]] = true;
        }
    }

    /**
     * @dev To remove users from blacklist which restricts blacklisted users from claiming
   * @param _userToRemoveFromBlacklist addresses of the users
   */
    function removeFromBlacklist(address[] calldata _userToRemoveFromBlacklist) external onlyOwner {
        for (uint256 i = 0; i < _userToRemoveFromBlacklist.length; i++) {
            isBlacklisted[_userToRemoveFromBlacklist[i]] = false;
        }
    }

    /**
     * @dev To add users to whitelist which restricts users from claiming if claimWhitelistStatus is true
   * @param _usersToWhitelist addresses of the users
   */
    function whitelistUsers(address[] calldata _usersToWhitelist) external onlyOwner {
        for (uint256 i = 0; i < _usersToWhitelist.length; i++) {
            isWhitelisted[_usersToWhitelist[i]] = true;
        }
    }

    /**
     * @dev To remove users from whitelist which restricts users from claiming if claimWhitelistStatus is true
   * @param _userToRemoveFromWhitelist addresses of the users
   */
    function removeFromWhitelist(address[] calldata _userToRemoveFromWhitelist) external onlyOwner {
        for (uint256 i = 0; i < _userToRemoveFromWhitelist.length; i++) {
            isWhitelisted[_userToRemoveFromWhitelist[i]] = false;
        }
    }

    /**
     * @dev To set status for claim whitelisting
   * @param _status bool value
   */
    function setClaimWhitelistStatus(bool _status) external onlyOwner {
        whitelistClaimOnly = _status;
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
     * @dev To set time constant for manageTimeDiff()
   * @param _timeConstant time in <days>*24*60*60 format
   */
    function setTimeConstant(uint256 _timeConstant) external onlyOwner {
        timeConstant = _timeConstant;
    }

    /**
     * @dev to update userDeposits for purchases made on other chain
     * @param _users array of users
     * @param _userDeposits array of userDeposits associated with users
   */
    function updateFromOtherChain(address[] calldata _users, uint256[] calldata _userDeposits) external onlyOwner {
        require(_users.length == _userDeposits.length, "Length mismatch");
        for (uint256 i = 0; i < _users.length; i++) {
            userDeposits[_users[i]] += _userDeposits[i];
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/5.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}