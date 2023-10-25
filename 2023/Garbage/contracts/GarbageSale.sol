// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./IGarbageSale.sol";
import "./IGarbageVesting.sol";

contract GarbageSale is Pausable, AccessControl, IGarbageSale {
    using SafeERC20 for IERC20;

    struct Stage {
        uint256 tokensToSale; // Amount of tokens to sale
        uint256 tokensSold; // Sold tokens amount
        uint256 priceInUSD; // Price in USD with 8 decimals
    }

    Stage[] public stages; // Array with stages and their info

    IERC20 public garbageToken; // Token for sale
    IERC20 public usdt; // USDT token for garbage token purchasing
    IGarbageVesting public vestingContract; // Address of vesting contract
    address public treasury; // Address to receive funds

    uint256 public maxClaimableAmountInUSD; // Max amount of garbage tokens in USD (8 decimals) which can bought without vesting. Any amount of garbage above this limit will be vested.
    uint256 public currentStage; // Current stage
    uint256 public saleStartDate; // Date when garbage token sale starts
    uint256 public saleDeadline; // Deadline for garbage token sale
    uint256 public claimDate; // Date when users can claim their tokens
    uint256 public bloggerRewardPercent; // Reward percent for referrers-blogger
    uint256 public userRewardPercent; // Reward percent for referrers-user

    uint256 public totalTokensToBeDistributed; // Total amount of tokens to be distributed (sum of initial garbage tokens amount from all stages)
    uint256 public totalTokensSold; // Total amount of tokens sold
    uint256 public totalTokensClaimed; // Total amount of tokens claimed by users
    uint256 public totalRewardsClaimedEth; // Total amount of ETH claimed by referrers
    uint256 public totalRewardsClaimedUsdt; // Total amount of USDT claimed by referrers
    uint256 public totalRewardsEth; // Total amount of ETH received by referrers
    uint256 public totalRewardsUsdt; // Total amount of USDT received by referrers

    uint256 public constant PERCENT_DENOMINATOR = 10000; // so, 10% -> 1000, 5% -> 500

    bytes32 public constant WERT_ROLE = keccak256("WERT_ROLE"); // Role for wert wallet
    bytes32 public constant BLOGGER_ROLE = keccak256("BLOGGER_ROLE"); // Role for referrers-blogger
    bytes32 public constant REFERRER_ROLE = keccak256("REFERRER_ROLE"); // Role for referrers-user
    bytes32 public constant AFFILIATE_ADMIN_ROLE = keccak256("AFFILIATE_ADMIN_ROLE"); // Role for affiliate admin
    bytes32 public constant MEME_ADMIN_ROLE = keccak256("MEME_ADMIN_ROLE"); // Role for meme admin

    mapping(address => uint256) public referralRewardsEth; // Amount of ETH received by referrers
    mapping(address => uint256) public referralRewardsUsdt; // Amount of USDT received by referrers
    mapping(address => uint256) public claimableTokens; // Amount of garbage tokens claimable by users
    mapping(address => uint256) public totalGarbageBoughtInUSD; // Total amount of garbage tokens bought by user in USD (8 decimals). Needed to calculate vesting amount.

    AggregatorV3Interface public priceFeedUsdt; // Chainlink price feed for USDT
    AggregatorV3Interface public priceFeedEth; // Chainlink price feed for ETH

    event ClaimDateExtended(uint256 newClaimDate);
    event DeadlineExtended(uint256 newDeadline);
    event GarbageTokenChanged(address newGarbageToken);
    event PriceFeedEthChanged(address newPriceFeedEth);
    event PriceFeedUsdtChanged(address newPriceFeedUsdt);
    event RewardCalculated(uint256 reward, address referrer);
    event RewardPaid(address referrer, uint256 amountEth, uint256 amountUsdt);
    event RewardPercentChanged(uint256 bloggerRewardPercent, uint256 userRewardPercent);
    event RemainderWithdrawn(address treasury, uint256 amountWithdrawn);
    event StageAdded(uint256 tokens, uint256 priceInUSD);
    event TokensBought(address buyer, uint256 amount);
    event TokensClaimed(address claimer, uint256 amount);
    event TreasuryChanged(address newTreasury);
    event UsdtChanged(address newUsdt);
    event VestingContractChanged(address newVestingContract);

    error AllStagesCompleted();
    error CallerIsNotAdmin();
    error CallerIsNotAffiliateAdmin();
    error ClaimDateNotReached();
    error ContractPaused();
    error DeadlineNotReached();
    error NewDeadlineIsInPast();
    error NotEnoughTokensInLastStage();
    error NotEnoughTokensInNextStage();
    error NotEnoughTokensInStageToDistribute();
    error PercentEqualOrGreaterThanDenominator();
    error ReferrerIsNotRegistered();
    error ReferrerIsSender();
    error SaleIsStarted();
    error SaleIsNotStarted();
    error TokenSaleEnded();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    modifier whenActive() {
        if (saleStartDate > block.timestamp) {
            revert SaleIsNotStarted();
        }
        if (block.timestamp >= saleDeadline) revert TokenSaleEnded();
        if (currentStage >= stages.length) revert AllStagesCompleted();
        if (paused()) revert ContractPaused();
        _;
    }

    modifier beforeSaleStart() {
        if (block.timestamp > saleStartDate) {
            revert SaleIsStarted();
        }
        _;
    }

    constructor(
        IERC20 _token,
        IERC20 _usdt,
        IGarbageVesting _vestingContract,
        address _priceFeedEth,
        address _priceFeedUsdt,
        address _treasury
    ) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        setMaxClaimableAmountInUSD(50_000 * 1e8); // 50k USD

        setSaleStartDate(1698168600); // Tue Oct 24 2023 17:30:00 GMT+0000
        setSaleDeadline(saleStartDate + 4 * 30 days);
        setClaimDate(saleDeadline + 1825 days);

        setVestingContract(_vestingContract);
        setTreasury(_treasury);
        setUsdt(_usdt);
        bloggerRewardPercent = 1000;
        userRewardPercent = 500;
        setPriceFeedEth(_priceFeedEth);
        setPriceFeedUsdt(_priceFeedUsdt);

        _addStages();
        setGarbageToken(_token);

        _setupRole(AFFILIATE_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(BLOGGER_ROLE, AFFILIATE_ADMIN_ROLE);
        _setRoleAdmin(REFERRER_ROLE, AFFILIATE_ADMIN_ROLE);
    }

    receive() external payable {}

    ///@notice Pause contract
    ///@dev Only admin can pause contract
    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    ///@notice Unpause contract
    ///@dev Only admin can unpause contract
    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Buy garbage tokens with ETH
    /// @param referrer Referrer address
    /// @dev There is no purchase itself. Users collect their tokens in the claimTokens() function
    /// @dev Perform calculation of how many tokens the user is entitled to via _buyTokens() function
    /// @dev Transfer ETH to the treasury
    /// @dev Reward to the referrer is kept on the contract
    function buyTokensWithEth(address referrer) public payable whenActive nonZeroAmount(msg.value) {
        uint256 reward = _calculateRewardReferral(referrer, msg.sender, msg.value, true);
        uint256 remaining = msg.value - reward;
        _buyTokens(msg.value, true, msg.sender);
        (bool success, ) = payable(treasury).call{value: remaining}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Buy garbage tokens with USDT
    /// @param usdtAmount Amount of USDT - 6 decimals
    /// @param referrer Referrer address
    /// @dev There is no purchase itself. Users collect their tokens in the claimTokens() function
    /// @dev Perform calculation of how many tokens the user is entitled to via _buyTokens() function
    /// @dev Transfer USDT to the treasury
    /// @dev Reward to the referrer is kept on the contract
    function buyTokensWithUsdt(uint256 usdtAmount, address referrer) public whenActive nonZeroAmount(usdtAmount) {
        uint256 reward = _calculateRewardReferral(referrer, msg.sender, usdtAmount, false);
        uint256 remaining = usdtAmount - reward;
        usdt.safeTransferFrom(msg.sender, treasury, remaining);
        usdt.safeTransferFrom(msg.sender, address(this), reward);
        _buyTokens(usdtAmount, false, msg.sender);
    }

    /// @notice Version of the buyTokensWithEth() function for Wert ramp.
    /// @param referrer Referrer address
    /// @param user User address for whom tokens are bought
    function buyTokensWithEthWert(address referrer, address user)
        public
        payable
        whenActive
        onlyRole(WERT_ROLE)
        nonZeroAmount(msg.value)
    {
        uint256 reward = _calculateRewardReferral(referrer, user, msg.value, true);
        uint256 remaining = msg.value - reward;
        _buyTokens(msg.value, true, user);
        (bool success, ) = payable(treasury).call{value: remaining}("");
        if (!success) revert TransferFailed();
    }

    ///@notice Claim garbage tokens by user
    ///@dev Users can claim their tokens after the claim date
    ///@dev Tokens are transferred to the user's wallet
    ///@dev Calculation of user's garbage token amount is performed in the _buyTokens() function
    function claimTokens() external {
        if (block.timestamp < claimDate) {
            revert ClaimDateNotReached();
        }
        uint256 amount = claimableTokens[msg.sender];
        claimableTokens[msg.sender] = 0;
        totalTokensClaimed += amount;
        garbageToken.safeTransfer(msg.sender, amount);
        emit TokensClaimed(msg.sender, amount);
    }

    ///@notice Claim reward in USDT/ETH by referrer
    ///@dev Referrers can claim their reward without restrictions
    ///@dev Reward is transferred to the referrer's wallet
    function claimReferralReward() external {
        uint256 amountEth = referralRewardsEth[msg.sender];
        if (amountEth != 0) {
            referralRewardsEth[msg.sender] = 0;
            totalRewardsClaimedEth += amountEth;
            (bool success, ) = payable(msg.sender).call{value: amountEth}("");
            if (!success) revert TransferFailed();
        }

        uint256 amountUsdt = referralRewardsUsdt[msg.sender];
        if (amountUsdt != 0) {
            referralRewardsUsdt[msg.sender] = 0;
            totalRewardsClaimedUsdt += amountUsdt;
            usdt.safeTransfer(msg.sender, amountUsdt);
        }
        emit RewardPaid(msg.sender, amountEth, amountUsdt);
    }

    ///@notice Withdraw remainder of garbage tokens
    ///@dev Only admin can withdraw remainder of garbage tokens
    ///@dev Remainder of garbage tokens after token sale is transferred to the treasury
    ///@dev Possible to withdraw only after token sale is ended
    function withdrawRemainder(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (block.timestamp < saleDeadline || currentStage < stages.length) {
            revert DeadlineNotReached();
        }
        garbageToken.safeTransfer(treasury, amount);
        emit RemainderWithdrawn(treasury, amount);
    }

    /// @notice Calculate garbage token amount entitled to user
    /// @param amount Amount of ETH or USDT - 18 or 6 decimals
    /// @param isEth True if amount is in ETH, false if amount is in USDT
    /// @param user User address
    /*
    If user wants to buy more tokens than there are left in the current stage,
    the missing amount is taken from the next stage at the price specified in the new stage.
    Example: a user wants to buy 100 tokens from stage 0 at the price of 0.01, but there are only 50 tokens left in stage 0.
    The shortage, i.e. 100 - 50 = 50, will be sold to the user at the new price, 0.0125, which is specified in stage 1.
    */
    function _buyTokens(
        uint256 amount,
        bool isEth,
        address user
    ) internal {
        uint256 alreadyBoughtInUSD = totalGarbageBoughtInUSD[user];
        uint256 amountInUSD = getCurrencyInUSD(amount, isEth);
        totalGarbageBoughtInUSD[user] += amountInUSD;

        if (alreadyBoughtInUSD >= maxClaimableAmountInUSD) {
            _vestTokens(amount, isEth, user);
            return;
        }

        uint256 claimableAmount = amount;

        if (alreadyBoughtInUSD + amountInUSD > maxClaimableAmountInUSD) {
            uint256 amountToVestInUSD = alreadyBoughtInUSD + amountInUSD - maxClaimableAmountInUSD;
            uint256 amountToVest = getUSDinCurrency(amountToVestInUSD, isEth);
            _vestTokens(amountToVest, isEth, user);
            claimableAmount = amount - amountToVest;
        }

        (uint256 currentStageTokens, uint256 tokensNextStage) = _calculateTokenAmountFromCurrencyAmount(
            claimableAmount,
            isEth
        );

        _subtractTokensFromCurrentStage(currentStageTokens);
        if (tokensNextStage > 0) {
            // stage is changed in the previous distribute call
            _subtractTokensFromCurrentStage(tokensNextStage);
        }
        claimableTokens[user] += currentStageTokens + tokensNextStage;
        emit TokensBought(user, currentStageTokens + tokensNextStage);
    }

    ///@notice Vest garbage tokens, adding amount for vesting in GarbageVesting contract.
    ///@param amount Amount of ETH or USDT - 18 or 6 decimals
    ///@param isEth True if amount is in ETH, false if amount is in USDT
    ///@param user User address
    function _vestTokens(
        uint256 amount,
        bool isEth,
        address user
    ) internal {
        (uint256 currentStageTokens, uint256 tokensNextStage) = _calculateTokenAmountFromCurrencyAmount(amount, isEth);

        _subtractTokensFromCurrentStage(currentStageTokens);
        if (tokensNextStage > 0) {
            // stage is changed in the previous distribute call
            _subtractTokensFromCurrentStage(tokensNextStage);
        }
        garbageToken.approve(address(vestingContract), currentStageTokens + tokensNextStage);
        vestingContract.addAmountToBeneficiary(user, currentStageTokens + tokensNextStage);
        emit TokensBought(user, currentStageTokens + tokensNextStage);
    }

    ///@notice Calculate rate in currency
    function _getRateInCurrency(uint256 stageId, bool isEth) internal view returns (uint256) {
        Stage storage stage = stages[stageId];
        // price in 18 decimals
        uint256 currentPrice = (isEth ? _getEthPrice() : _getUsdtPrice()) * 1e10;
        uint256 priceInUSDDecimals = 1e8;
        uint256 rateInCurrency = (priceInUSDDecimals * currentPrice) / stage.priceInUSD; // calculate the number of tokens in 1 unit of the selected currency based on its current price (USDT or ETH)
        return rateInCurrency;
    }

    ///@notice Validate and calculate tokens distribution for current stage. When current stage is finished, move to the next.
    function _subtractTokensFromCurrentStage(uint256 tokens) internal {
        Stage storage stage = stages[currentStage];
        if (stage.tokensToSale - stage.tokensSold < tokens) revert NotEnoughTokensInStageToDistribute();
        stage.tokensSold += tokens;
        totalTokensSold += tokens;

        if (stage.tokensSold == stage.tokensToSale) {
            currentStage++;
        }
    }

    /// @notice Calculate reward for referrer
    /// @param referrer Referrer address
    /// @param amount Amount of ETH or USDT - 18 or 6 decimals
    /// @param isEth True if amount is in ETH, false if amount is in USDT
    /// @return reward Reward amount in ETH or USDT - 18 or 6 decimals
    /// @dev Reward is calculated based on the amount of ETH or USDT sent by the user
    /// @dev Blogger referrers receive 10% of the amount sent by the user and user referrers receive 5%
    function _calculateRewardReferral(
        address referrer,
        address user,
        uint256 amount,
        bool isEth
    ) internal returns (uint256 reward) {
        if (referrer == user) revert ReferrerIsSender();
        if (referrer != address(0)) {
            if (!hasRole(REFERRER_ROLE, referrer) && !hasRole(BLOGGER_ROLE, referrer)) revert ReferrerIsNotRegistered();
            bool isBlogger = hasRole(BLOGGER_ROLE, referrer);
            uint256 rewardPercent = isBlogger ? bloggerRewardPercent : userRewardPercent;
            reward = (amount * rewardPercent) / PERCENT_DENOMINATOR;
            if (isEth) {
                referralRewardsEth[referrer] += reward;
                totalRewardsEth += reward;
            } else {
                referralRewardsUsdt[referrer] += reward;
                totalRewardsUsdt += reward;
            }
        }
        emit RewardCalculated(reward, referrer);
        return reward;
    }

    ///@notice Add all stages with tokens and price in USD
    function _addStages() internal {
        _addStage(51_282_051, 1950000);
        _addStage(47_483_381, 2106000);
        _addStage(43_966_093, 2274480);
        _addStage(40_709_346, 2456438);
        _addStage(36_874_407, 2711908);
        _addStage(32_923_578, 3037337);
        _addStage(29_396_052, 3401817);
        _addStage(26_014_205, 3844054);
        _addStage(22_819_478, 4382221);
        _addStage(18_531_329, 5396267);
    }

    ///@notice Add stage with tokens and price in USD
    function _addStage(uint256 tokensToSale, uint256 priceInUSD) internal {
        uint256 tokensToSaleWithDecimals = tokensToSale * 10**18;
        stages.push(Stage(tokensToSaleWithDecimals, 0, priceInUSD));
        totalTokensToBeDistributed += tokensToSaleWithDecimals;
        emit StageAdded(tokensToSale, priceInUSD);
    }

    ///@notice Set new treasury address
    ///@param _treasury New treasury address
    ///@dev Only admin can set new treasury address
    function setTreasury(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) nonZeroAddress(_treasury) {
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    ///@notice Set new garbage token address
    ///@param _token New garbage token address
    ///@dev Only admin can set new garbage token address
    function setGarbageToken(IERC20 _token)
        public
        beforeSaleStart
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonZeroAddress(address(_token))
    {
        garbageToken = _token;
        emit GarbageTokenChanged(address(_token));
    }

    ///@notice Set new USDT address
    ///@param _usdt New USDT address
    ///@dev Only admin can set new USDT address
    function setUsdt(IERC20 _usdt) public onlyRole(DEFAULT_ADMIN_ROLE) nonZeroAddress(address(_usdt)) {
        usdt = _usdt;
        emit UsdtChanged(address(_usdt));
    }

    ///@notice Set new price feed for ETH
    ///@param _priceFeedEth New price feed for ETH
    ///@dev Only admin can set new price feed for ETH
    function setPriceFeedEth(address _priceFeedEth) public onlyRole(DEFAULT_ADMIN_ROLE) nonZeroAddress(_priceFeedEth) {
        priceFeedEth = AggregatorV3Interface(_priceFeedEth);
        emit PriceFeedEthChanged(_priceFeedEth);
    }

    ///@notice Set new price feed for USDT
    ///@param _priceFeedUsdt New price feed for USDT
    ///@dev Only admin can set new price feed for USDT
    function setPriceFeedUsdt(address _priceFeedUsdt)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonZeroAddress(_priceFeedUsdt)
    {
        priceFeedUsdt = AggregatorV3Interface(_priceFeedUsdt);
        emit PriceFeedUsdtChanged(_priceFeedUsdt);
    }

    ///@notice Set new sale start date
    ///@param _saleStartDate New sale start date
    ///@dev Only admin can set new sale start date
    function setSaleStartDate(uint256 _saleStartDate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_saleStartDate < block.timestamp) {
            revert NewDeadlineIsInPast();
        }
        if (block.timestamp > saleStartDate && saleStartDate > 0) {
            revert SaleIsStarted();
        }
        saleStartDate = _saleStartDate;
    }

    ///@notice Set new claim date
    ///@param _claimDate New claim date
    ///@dev Only admin can set new claim date
    function setClaimDate(uint256 _claimDate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_claimDate < block.timestamp) {
            revert NewDeadlineIsInPast();
        }
        claimDate = _claimDate;
        emit ClaimDateExtended(_claimDate);
    }

    ///@notice Set new sale deadline
    ///@param newDeadline New sale deadline
    ///@dev Only admin can set new sale deadline
    function setSaleDeadline(uint256 newDeadline) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newDeadline < block.timestamp || newDeadline < saleDeadline) {
            revert NewDeadlineIsInPast();
        }
        saleDeadline = newDeadline;
        emit DeadlineExtended(newDeadline);
    }

    ///@notice Set new max amount of garbage tokens in USD (8 decimals) which can be bought without vesting.
    function setMaxClaimableAmountInUSD(uint256 _maxClaimableAmountInUSD) public onlyRole(DEFAULT_ADMIN_ROLE) {
        maxClaimableAmountInUSD = _maxClaimableAmountInUSD;
    }

    ///@notice Set new address of vesting contract.
    function setVestingContract(IGarbageVesting _vestingContract)
        public
        beforeSaleStart
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonZeroAddress(address(_vestingContract))
    {
        vestingContract = _vestingContract;
        emit VestingContractChanged(address(_vestingContract));
    }

    ///@notice Return stages quantity
    function getStagesLength() external view returns (uint256) {
        return stages.length;
    }

    ///@notice Return current stage info
    ///@return tokensToSale Amount of tokens to sale
    ///@return tokensSold Sold tokens amount
    ///@return priceInUSD Price in USD with 8 decimals
    ///@return _currentStage Current stage
    ///@return nextStagePriceInUsd Price in USD with 8 decimals for next stage
    function getCurrentStageInfo()
        external
        view
        returns (
            uint256 tokensToSale,
            uint256 tokensSold,
            uint256 priceInUSD,
            uint256 _currentStage,
            uint256 nextStagePriceInUsd
        )
    {
        uint256 stageId = currentStage;
        nextStagePriceInUsd = stageId == stages.length - 1 ? 0 : stages[stageId + 1].priceInUSD;
        return (
            stages[stageId].tokensToSale,
            stages[stageId].tokensSold,
            stages[stageId].priceInUSD,
            currentStage,
            nextStagePriceInUsd
        );
    }

    ///@notice Return rewards amount in USDT and ETH for specified referrer
    function getRewardsForReferrer(address referrer) external view returns (uint256, uint256) {
        return (referralRewardsEth[referrer], referralRewardsUsdt[referrer]);
    }

    ///@notice Return user's balances in garbage token, USDT and ETH
    function getUserBalances(address user)
        external
        view
        returns (
            uint256 garbageBalance,
            uint256 usdtBalance,
            uint256 ethBalance
        )
    {
        garbageBalance = garbageToken.balanceOf(user);
        usdtBalance = usdt.balanceOf(user);
        ethBalance = address(user).balance;
    }

    ///@notice Calculate and return token amount from provided currency amount
    ///@param amount Amount of ETH or USDT - 18 or 6 decimals
    function getTokenAmountFromCurrencyAmount(uint256 amount, bool isEth) public view returns (uint256 tokens) {
        (uint256 currentStageTokens, uint256 nextStageTokens) = _calculateTokenAmountFromCurrencyAmount(amount, isEth);
        return currentStageTokens + nextStageTokens;
    }

    ///@notice Calculate currency price in USD
    ///@return priceInUSD Price in USD with 8 decimals
    function getCurrencyInUSD(uint256 currencyAmount, bool isEth) public view returns (uint256) {
        uint256 currentPrice = (isEth ? _getEthPrice() : _getUsdtPrice());
        uint256 currencyDecimals = isEth ? 1e18 : 1e6;
        uint256 usdValue = (currencyAmount * currentPrice) / currencyDecimals;
        return usdValue;
    }

    /// @notice Calculate currency amount from provided USD amount
    /// @param usdAmount Amount of USD - 8 decimals
    function getUSDinCurrency(uint256 usdAmount, bool isEth) public view returns (uint256) {
        uint256 currentPrice = (isEth ? _getEthPrice() : _getUsdtPrice());
        uint256 currencyDecimals = isEth ? 1e18 : 1e6;
        uint256 currencyValue = (usdAmount * currencyDecimals) / currentPrice;
        return currencyValue;
    }

    ///@notice Calculate and return token amount from provided currency amount
    ///@param amount Amount of ETH or USDT - 18 or 6 decimals
    ///@param isEth True if amount is in ETH, false if amount is in USDT
    function _calculateTokenAmountFromCurrencyAmount(uint256 amount, bool isEth)
        internal
        view
        returns (uint256 tokensAmount, uint256 tokensAmountNextStage)
    {
        Stage storage stage = stages[currentStage];
        uint256 _currentStage = currentStage;
        uint256 rateInCurrency = _getRateInCurrency(_currentStage, isEth); // calculate the number of tokens in 1 unit of the selected currency based on its current price (USDT or ETH)
        uint256 tokens = (amount * rateInCurrency) / (isEth ? 1e18 : 1e6); // calculate the number of tokens based on the passed amount of currency

        if (stage.tokensToSale - stage.tokensSold >= tokens) {
            return (tokens, 0);
        }

        _currentStage++;
        uint256 remainingTokens = stage.tokensToSale - stage.tokensSold;
        uint256 usedAmount = (remainingTokens * (isEth ? 1e18 : 1e6)) / rateInCurrency;
        uint256 excessAmount = amount - usedAmount;

        if (excessAmount == 0) return (remainingTokens, 0);

        if (_currentStage >= stages.length) {
            uint256 checkGarbageAmount = (excessAmount * rateInCurrency) / (isEth ? 1e18 : 1e6);
            if (checkGarbageAmount <= 1 ether) {
                return (remainingTokens, 0);
            } else {
                revert NotEnoughTokensInLastStage();
            }
        }
        Stage storage nextStage = stages[_currentStage];
        uint256 nextRateInCurrency = _getRateInCurrency(_currentStage, isEth);
        uint256 nextTokens = (excessAmount * nextRateInCurrency) / (isEth ? 1e18 : 1e6);
        if (nextTokens > nextStage.tokensToSale) revert NotEnoughTokensInNextStage();
        return (remainingTokens, nextTokens);
    }

    ///@notice Calculate and return currency amount from provided token amount
    ///@param tokens Amount of garbage tokens
    ///@param isEth True if amount to return is in ETH, false if amount to return is in USDT
    function getCurrencyAmountFromTokenAmount(uint256 tokens, bool isEth) external view returns (uint256 amount) {
        Stage storage stage = stages[currentStage];
        uint256 rateInCurrency = _getRateInCurrency(currentStage, isEth); // calculate the number of tokens in 1 unit of the selected currency based on its current price (USDT or ETH)
        if (stage.tokensToSale - stage.tokensSold >= tokens) {
            amount = (tokens * (isEth ? 1e18 : 1e6)) / rateInCurrency; // calculate the amount of currency based on the passed number of tokens
            return amount;
        }

        uint256 _currentStage = currentStage;
        uint256 remainingTokens = stage.tokensToSale - stage.tokensSold;
        uint256 usedAmount = (remainingTokens * (isEth ? 1e18 : 1e6)) / rateInCurrency;
        uint256 excessTokens = tokens - remainingTokens;

        _currentStage++;

        if (_currentStage >= stages.length) {
            if (excessTokens > 1 ether) {
                revert NotEnoughTokensInLastStage();
            } else {
                amount = (tokens * (isEth ? 1e18 : 1e6)) / rateInCurrency; // calculate the amount of currency based on the passed number of tokens
                return amount;
            }
        }
        // Calculate the amount of currency needed to buy tokens from the next stage
        Stage storage nextStage = stages[_currentStage];
        uint256 nextRateInCurrency = _getRateInCurrency(_currentStage, isEth);
        uint256 nextAmount = (excessTokens * (isEth ? 1e18 : 1e6)) / nextRateInCurrency;

        if (excessTokens > nextStage.tokensToSale) revert NotEnoughTokensInNextStage();

        amount = usedAmount + nextAmount;
    }

    ///@notice Return ETH price from Chainlink
    function _getEthPrice() internal view returns (uint256) {
        (, int256 price, , , ) = priceFeedEth.latestRoundData();
        return uint256(price);
    }

    ///@notice Return USDT price from Chainlink
    function _getUsdtPrice() internal view returns (uint256) {
        (, int256 price, , , ) = priceFeedUsdt.latestRoundData();
        return uint256(price);
    }
}
