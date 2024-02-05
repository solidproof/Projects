//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


// This interface defines the functions that all ERC20 tokens should implement
interface IERC20 {
    
    // Returns the total supply of the token
    function totalSupply() external view returns (uint256);
    
    // Returns the number of decimal places used by the token
    function decimals() external view returns (uint8);
    
    // Returns the symbol used to represent the token
    function symbol() external view returns (string memory);
    
    // Returns the name of the token
    function name() external view returns (string memory);
    
    // Returns the balance of the specified account
    function balanceOf(address account) external view returns (uint256);
    
    // Transfers a specified amount of tokens from the sender's account to the recipient's account
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    // Returns the amount of tokens that the spender is allowed to spend on behalf of the owner
    function allowance(address _owner, address spender) external view returns (uint256);
    
    // Approves the spender to spend a specified amount of tokens on behalf of the owner
    function approve(address spender, uint256 amount) external returns (bool);
    
    // Transfers a specified amount of tokens from the sender's account to the recipient's account, given that the sender has sufficient allowance
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    // Emitted when tokens are transferred from one account to another
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    // Emitted when the allowance of a spender for an owner is set or decreased
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// This interface defines the functions that the Uniswap V2 factory contract should implement
interface IDEXFactory {  
    // Creates a new trading pair for the specified tokens and returns its address
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// This interface defines the functions that the Uniswap V2 router contract should implement
interface IDEXRouter {
    
    // Returns the address of the Uniswap V2 factory contract that this router is connected to
    function factory() external pure returns (address);

    // Returns the address of the WETH token contract
    function WETH() external pure returns (address);

    // Adds liquidity for the specified tokens and returns the amount of liquidity tokens received
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    // Adds liquidity for the specified token and ETH and returns the amount of liquidity tokens received
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    // Swaps an exact amount of input tokens for output tokens, supporting fee-on-transfer tokens
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    // Swaps exact amount of ETH for output tokens, supporting fee-on-transfer tokens
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    // Swaps exact amount of input tokens for ETH, supporting fee-on-transfer tokens
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// Interface for the DividendDistributor contract
interface IDividendDistributor {
    // Function to set the distribution criteria (minimum period and minimum distribution amount)
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;

    // Function to set the amount of shares for a given shareholder
    function setShare(address shareholder, uint256 amount) external;

    // Function to deposit rewards into the contract (must be payable)
    function deposit() external payable;

    // Function to process rewards for all shareholders
    function process(uint256 gas) external;
}

/**
* @title DividendDistributor
* @dev A contract that distributes dividends in a specified ERC20 token to shareholders.
* Implements the IDividendDistributor interface.
*/
contract DividendDistributor is IDividendDistributor {

    // The address of the contract owner
    address private _token;

    // Struct for keeping track of a shareholder's share and earnings
    struct Share {
        uint256 amount; // The number of tokens held by the shareholder
        uint256 totalExcluded; // The total amount of dividends the shareholder is excluded from
        uint256 totalRealised; // The total amount of dividends the shareholder has realized
    }

    // The Uniswap router interface
    IDEXRouter private router;
    // ARB token interface
    IERC20 private RewardToken = IERC20(0x4526b62fcaF1FdA52c5f0aaD813874CD7995c5a9);

    // Arrays and mappings to keep track of shareholders and their shares
    address[] shareholders; // Array of shareholder addresses
    mapping (address => uint256) private shareholderIndexes; // Mapping from shareholder address to index in shareholders array
    mapping (address => uint256) private shareholderClaims; // Mapping from shareholder address to timestamp of last claimed dividend
    mapping (address => Share) private shares; // Mapping from shareholder address to their Share struct

    // Total shares of the dividend distribution
    uint256 private totalShares;

    // Total amount of dividends that have been deposited into the contract
    uint256 private totalDividends;

    // Total amount of dividends that have been distributed to shareholders
    uint256 private totalDistributed;

    // Dividends per share
    uint256 private dividendsPerShare;

    // Accuracy factor for calculating dividends per share
    uint256 private dividendsPerShareAccuracyFactor = 10 ** 36;

    // Minimum time period between dividend distributions
    uint256 private minPeriod = 60 minutes;

    // Minimum distribution threshold for a shareholder to receive dividends
    uint256 private minDistribution = 1 * (10 ** 6);

    // Current index for processing shareholder dividends
    uint256 private currentIndex;

    // Flag indicating whether the contract has been initialized
    bool private initialized;

    // Modifier restricting access to only the contract owner
    modifier onlyToken() {
        require(msg.sender == _token); _;
    }

    // Modifier restricting contract initialization to once
    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    /**
    * @dev Constructor function to set the Uniswap router address
    * @param _router The address of the Uniswap router
    */
    constructor (address _router) {
        router = IDEXRouter(_router);
        _token = msg.sender;
    }

    /**
    * @dev Sets the minimum distribution period and amount required to distribute rewards to shareholders
    * @param newMinPeriod The new minimum distribution period
    * @param newMinDistribution The new minimum distribution amount
    */
    function setDistributionCriteria(uint256 newMinPeriod, uint256 newMinDistribution) external override onlyToken {
        minPeriod = newMinPeriod;
        minDistribution = newMinDistribution;
    }

    /**
    * @dev Sets the amount of shares for a shareholder, updates the totalShares value, and calculates the totalExcluded value for the shareholder.
    * If the shareholder already has shares, it will distribute any owed dividends before updating the share amount.
    * If the new amount is zero and the shareholder had shares, it will remove the shareholder from the list.
    * @param shareholder The address of the shareholder
    * @param amount The new amount of shares to set for the shareholder
    */
    function setShare(address shareholder, uint256 amount) external override onlyToken {
        // Distribute any owed dividends to the shareholder if they already have shares
        if(shares[shareholder].amount > 0){
            distributeDividend(shareholder);
        }
        // Add or remove shareholder from the list depending on the new amount of shares
        if(amount > 0 && shares[shareholder].amount == 0){
            addShareholder(shareholder);
            }else if(amount == 0 && shares[shareholder].amount > 0){
            removeShareholder(shareholder);
        }
        // Update totalShares value
        totalShares = totalShares - (shares[shareholder].amount + amount);

        // Set the new amount of shares for the shareholder and calculate the totalExcluded value
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    /**
    * @dev Deposits the received ETH to Uniswap to obtain the current amount of reward token.
    * It calculates the new distribution amount per share and updates the state variables accordingly.
    */
    function deposit() external payable override onlyToken {
        uint256 balanceBefore = RewardToken.balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(RewardToken);

        // Swaps the received ETH for reward tokens and deposits it in this contract
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        // Calculates the amount of reward tokens received and updates the total dividends state variable
        uint256 amount = RewardToken.balanceOf(address(this)) - balanceBefore;
        totalDividends = totalDividends + amount;

        // Calculates the new distribution amount per share if there are shareholders and updates the state variable accordingly
        if(totalShares > 0){
            dividendsPerShare = dividendsPerShare + (dividendsPerShareAccuracyFactor * amount / (totalShares));
        }else{
            dividendsPerShare = dividendsPerShare + (dividendsPerShareAccuracyFactor * amount);
        }     
    }

    /**
    * @dev Distributes the dividends to all eligible shareholders.
    * It loops through all the shareholders and calls `distributeDividend` for each shareholder.
    * The function stops if either all shareholders have been processed or the gas limit is reached.
    * @param gas The maximum amount of gas that can be used for the distribution process
    */
    function process(uint256 gas) external override onlyToken {
        uint256 shareholderCount = shareholders.length;

        if(shareholderCount == 0) { return; }

        uint256 iterations = 0;
        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        // Loops through all shareholders and distributes dividends to eligible ones
        while(gasUsed < gas && iterations < shareholderCount) {

            if(currentIndex >= shareholderCount){ currentIndex = 0; }

            if(shouldDistribute(shareholders[currentIndex])){
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - (gasleft()));
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    /**
    * @dev Checks whether a shareholder is eligible for dividend distribution based on the time elapsed and the minimum distribution amount.
    * @param shareholder The address of the shareholder to be checked
    * @return A boolean indicating whether the shareholder is eligible for dividend distribution
    */
    function shouldDistribute(address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
                && getUnpaidEarnings(shareholder) > minDistribution;
    }

    /**
    * @dev Calculates the total amount of dividends that a shareholder is eligible to receive based on their share.
    * @param share The amount of shares owned by the shareholder
    * @return The total amount of dividends that the shareholder is eligible to receive
    */
    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share * (dividendsPerShare) / (dividendsPerShareAccuracyFactor);
    }

    /**
    * @dev Add a new shareholder to the shareholders array and update their index in the shareholderIndexes mapping
    * @param shareholder The address of the new shareholder to be added
    */
    function addShareholder(address shareholder) internal {
        // Set the index of the new shareholder to the current length of the shareholders array
        shareholderIndexes[shareholder] = shareholders.length;
        // Add the new shareholder to the end of the shareholders array
        shareholders.push(shareholder);
    }

    /**
    * @dev Removes the shareholder from the shareholders array and updates the shareholderIndexes mapping
    * @param shareholder The address of the shareholder to be removed
    */
    function removeShareholder(address shareholder) internal {
        // Replace the shareholder to be removed with the last shareholder in the array
        shareholders[shareholderIndexes[shareholder]] = shareholders[shareholders.length-1];
        // Update the index of the last shareholder to point to the position of the shareholder to be removed
        shareholderIndexes[shareholders[shareholders.length-1]] = shareholderIndexes[shareholder];
        // Remove the last element from the shareholders array
        shareholders.pop();
    }
    /**
    * @dev Distributes dividends to a shareholder
    * @param shareholder The address of the shareholder to receive the dividends
    */
    function distributeDividend(address shareholder) internal {
        // If the shareholder has no shares, return
        if(shares[shareholder].amount == 0){ return; }

        // Calculate the amount of unpaid earnings for the shareholder
        uint256 amount = getUnpaidEarnings(shareholder);
        // If the amount of unpaid earnings is greater than 0, distribute the dividends to the shareholder
        if(amount > 0){
            // Update the total amount of distributed dividends
            totalDistributed = totalDistributed + (amount);
            // Transfer the dividends to the shareholder
            RewardToken.transfer(shareholder, amount);
            // Update the timestamp of the last dividend claim for the shareholder
            shareholderClaims[shareholder] = block.timestamp;
            // Update the total realized dividends and cumulative dividends for the shareholder
            shares[shareholder].totalRealised = shares[shareholder].totalRealised + (amount);
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }

    /**
    * @dev Allows a shareholder to claim their unpaid dividends
    * @param shareholder The address of the shareholder to claim the dividends
    */
    function claimDividend(address shareholder) external onlyToken{
        distributeDividend(shareholder);
    }
    
    /**
    * @dev Transfer all remaining dividend tokens to the specified address
    * @param to The address to transfer the dividend tokens to
    */
    function rescueDividends(address to) external onlyToken {
        RewardToken.transfer(to, RewardToken.balanceOf(address(this)));
    }

    /**
    * @dev Set the reward token to a new address
    * @param _rewardToken The address of the new reward token contract
    */
    function setRewardToken(address _rewardToken) external onlyToken{
    RewardToken = IERC20(_rewardToken);
    }
    /**

    @dev Get the share details for a specific shareholder
    @param shareholder The address of the shareholder to get the details for
    @return A Share struct containing the amount, total excluded, and total realised for the shareholder
    */
    function viewShares(address shareholder) public view returns (Share memory){
       return shares[shareholder];
    }

    /**
    * @dev Get the unpaid earnings for a specific shareholder
    * @param shareholder The address of the shareholder to get the unpaid earnings for
    * @return The amount of unpaid earnings for the shareholder
    */
    function getUnpaidEarnings(address shareholder) public view returns (uint256) {
        if(shares[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends + (shareholderTotalExcluded);
    }

    /**
    * @dev returns the total number of shares
    */
    function getTotalShares() public view returns (uint256){
        // Returns the total number of shares
        return totalShares;
    }

    /**
    * @dev returns the total number of dividends
    */
    function getTotalDividends() public view returns (uint256){
        // Returns the total amount of dividends earned so far
        return totalDividends;
    }

    /**
    * @dev returns the total distributed
    */
    function getTotalDistributed() public view returns (uint256){
        // Returns the total amount of dividends distributed to shareholders
        return totalDistributed;
    }

    /**
    * @dev returns the dividend per share
    */
    function getDividendsPerShare() public view returns (uint256){
        // Returns the current dividends per share
        return dividendsPerShare;
    }

    /**
    * @dev returns the dividendsPerShareAccuracyFactor
    */
    function getDividendsPerShareAccuracyFactor() public view returns (uint256){
        // Returns the factor used to calculate the accuracy of the dividends per share
        return dividendsPerShareAccuracyFactor;
    }

    /**
    * @dev returns the minimum period between distributions and the minimum distribution amount

    */
    function getPeriodAndDistribution() public view returns (uint256, uint256){
        // Returns the minimum period between distributions and the minimum distribution amount
        return (minPeriod, minDistribution);
    }

    
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Contract for the ROI token, implementing the IERC20 interface and Ownable contract
contract ROI is IERC20, Ownable {
    
    // Constants for the token name, symbol, and decimals
    string constant private _name = "ROI";
    string constant private _symbol = "ROI";
    uint8 constant private _decimals = 18;

    // Total supply of the token, represented in wei
    uint256 _totalSupply = 1000000000 * (10 ** _decimals);

    // Mapping of addresses to token balances
    mapping (address => uint256) private _balances;

    // Mapping of allowances granted by token holders to other addresses
    mapping (address => mapping (address => uint256)) private _allowances;

    // Mapping of addresses exempt from transaction fees
    mapping (address => bool) private isFeeExempt;

    // Mapping of addresses exempt from transaction limits
    mapping (address => bool) private isTxLimitExempt;

    // Mapping of addresses exempt from receiving dividends
    mapping (address => bool) private isDividendExempt;

    // Variables for the transaction fees and sell multiplier
    uint256 private liquidityFee = 0;
    uint256 private marketingFee = 2;
    uint256 private rewardsFee = 3;
    uint256 private sellMultiplier = 15;

    // Total fee for transactions and total fee if selling
    uint256 private totalFee = 0;
    uint256 private totalFeeIfSelling = 0;

    // Address of the marketing wallet
    address private marketingWallet;

    // Router for the Uniswap exchange
    IDEXRouter private router;

    // Address of the Uniswap exchange pair
    address private pair;

    // Flag for first trade
    bool private firstTrade = true;

    // Dividend distributor contract
    DividendDistributor private dividendDistributor;

    // Gas limit for the dividend distributor
    uint256 distributorGas = 750000;

    // Flags for swap and liquify functionality
    bool private inSwapAndLiquify;
    bool private swapAndLiquifyEnabled = true;
    bool private swapAndLiquifyByLimitOnly = false;

    // Threshold for swap and liquify
    uint256 private swapThreshold = 0.001 ether;

    // Modifier to lock swap and liquify functionality during execution
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    // Constructor function
    constructor (address routerAddress, address marketingWalletAddr){
        
        // Initialize the Uniswap router and pair
        router = IDEXRouter(routerAddress);
        pair = IDEXFactory(router.factory()).createPair(router.WETH(), address(this));

        // Create a new dividend distributor contract
        dividendDistributor = new DividendDistributor(address(router));

        // Set initial exemptions
        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;

        isTxLimitExempt[msg.sender] = true;
        isTxLimitExempt[pair] = true;

        isDividendExempt[pair] = true;
        isDividendExempt[msg.sender] = true;
        isDividendExempt[address(this)] = true;

        // Set the marketing wallet address and initial token balances
        marketingWallet = marketingWalletAddr; 
        
        totalFee = liquidityFee + marketingFee + rewardsFee;
        totalFeeIfSelling = totalFee * sellMultiplier / 10;

        // Set initial balance of the contract deployer to 90% of the total supply
        _balances[msg.sender] = _totalSupply * 9 / 10;

        // Set initial balance of the marketing wallet to 10% of the total supply
        _balances[marketingWallet] = _totalSupply * 1 / 10;

        // Emit transfer events to reflect the initial token distribution
        emit Transfer(address(0), msg.sender, _totalSupply * 9 / 10);
        emit Transfer(address(0), marketingWallet, _totalSupply * 1 / 10);
    }

    // This function receives Ether sent to the contract and is payable
    receive() external payable { }

    // Returns the name of the token
    function name() external pure override returns (string memory) { return _name; }

    // Returns the symbol of the token
    function symbol() external pure override returns (string memory) { return _symbol; }

    // Returns the number of decimal places used in the token
    function decimals() external pure override returns (uint8) { return _decimals; }

    // Returns the total supply of tokens
    function totalSupply() external view override returns (uint256) { return _totalSupply; }

    // Returns the total circulating supply of tokens
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // Returns the balance of a specific account
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }

    // Returns the amount which spender is still allowed to withdraw from holder
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    // Allows `spender` to withdraw from `msg.sender` up to the specified `amount`
    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    // Calls the dividend distributor contract to allow the caller to claim their dividends
    function claimDividend() external {
        dividendDistributor.claimDividend(msg.sender);
    }

    /**
    * @dev Changes the selling fee multiplier. Only the owner can call this function.
    * @param newMulti The new value for the selling fee multiplier.
    */
    function changeSellFeeX10(uint256 newMulti) external onlyOwner{
        require(newMulti <= 30);
        sellMultiplier = newMulti;
        totalFeeIfSelling = totalFee*(sellMultiplier)/(10);
    }

    /**
    * @dev Changes whether a holder is exempt from paying fees. Only the owner can call this function.
    * @param holder The address of the holder to change exemption status for.
    * @param exempt The new exemption status.
    */
    function changeIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    /**
    * @dev Changes whether a holder is exempt from transaction limits. Only the owner can call this function.
    * @param holder The address of the holder to change exemption status for.
    * @param exempt The new exemption status.
    */
    function changeIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        isTxLimitExempt[holder] = exempt;
    }

    /**
    * @dev Changes whether a holder is exempt from receiving dividends. Only the owner can call this function.
    * @param holder The address of the holder to change exemption status for.
    * @param exempt The new exemption status.
    */
    function changeIsDividendExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        
        if(exempt){
            dividendDistributor.setShare(holder, 0);
        }else{
            dividendDistributor.setShare(holder, _balances[holder]);
        }
    }

    /**
    * @dev Changes the tax fees applied to buy/sell transactions.Only the owner can call this function.
    * @param newLiqFee new liquidity fee.
    * @param newRewardFee The new reward fee.
    * @param newMarketingFee The new newMarketing fee.
    */
    function changeFees(uint256 newLiqFee, uint256 newRewardFee, uint256 newMarketingFee) external onlyOwner {
        liquidityFee = newLiqFee;
        rewardsFee = newRewardFee;
        marketingFee = newMarketingFee;
        // Calculate the new total fee based on the new fees
        totalFee = liquidityFee+(marketingFee)+(rewardsFee);
        require(totalFee <= 10);
        // Calculate the new total fee if selling based on the new fees and the sell multiplier
        totalFeeIfSelling = totalFee*(sellMultiplier)/(10);
    }


    /**
    * @dev Changes the address of the marketing wallet where marketing fees are sent to.
    * @param newMarketingWallet The new address of the marketing wallet.
    */
    function changeFeeReceivers(address newMarketingWallet) external onlyOwner {
        marketingWallet = newMarketingWallet;
    }

    /**
    * @dev Changes the settings for the swap back feature.
    * @param enableSwapBack A boolean indicating whether or not the swap back feature is enabled.
    * @param newSwapBackLimit The new swap back limit for the swap back feature.
    * @param swapByLimitOnly A boolean indicating whether or not the swap back feature should only be triggered by reaching the swap back limit.
    */
    function changeSwapBackSettings(bool enableSwapBack, uint256 newSwapBackLimit, bool swapByLimitOnly) external onlyOwner {
        swapAndLiquifyEnabled = enableSwapBack;
        swapThreshold = newSwapBackLimit;
        swapAndLiquifyByLimitOnly = swapByLimitOnly;
    }


    /**
    * @dev Changes the distribution criteria for the dividend distributor contract.
    * @param newinPeriod The new time period for distribution calculations.
    * @param newMinDistribution The new minimum amount of tokens required for a distribution to occur.
    */
    function changeDistributionCriteria(uint256 newinPeriod, uint256 newMinDistribution) external onlyOwner {
        dividendDistributor.setDistributionCriteria(newinPeriod, newMinDistribution);
    }

    /**
    * @dev Changes the gas limit for dividend distribution processing.
    * @param gas The new gas limit for dividend distribution processing.
    */
    function changeDistributorSettings(uint256 gas) external onlyOwner {
        // Gas limit should not exceed 750,000
        require(gas < 750000);
        distributorGas = gas;
    }

    /**
    * @dev Sets the reward token for the dividend distributor contract.
    * @param _rewardToken The address of the new reward token.
    */
    function setRewardToken(address _rewardToken) external onlyOwner {
        dividendDistributor.setRewardToken(_rewardToken);
    }

    /**
    * @dev Transfers tokens from the sender to the recipient.
    * @param recipient The address to receive the tokens.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful or not.
    */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }
    
    /**
    * @dev Transfers tokens from one address to another.
    * @param sender The address to transfer tokens from.
    * @param recipient The address to transfer tokens to.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful.
    */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        
        if(_allowances[sender][msg.sender] >= amount){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]-amount;
        }
        return _transferFrom(sender, recipient, amount);
    }

    /**
    * @dev Internal function to transfer tokens from one address to another.
    * @param sender The address to transfer tokens from.
    * @param recipient The address to transfer tokens to.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful.
    */
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        
        if(inSwapAndLiquify){ return _basicTransfer(sender, recipient, amount); }

        if(msg.sender != pair && !inSwapAndLiquify && swapAndLiquifyEnabled && _balances[address(this)] >= swapThreshold){
             swapBack(amount); 
        }

        //Exchange tokens
        _balances[sender] = _balances[sender]-amount;

        uint256 finalAmount = !isFeeExempt[sender] && !isFeeExempt[recipient] ? takeFee(sender, recipient, amount) : amount;
        _balances[recipient] = _balances[recipient]+(finalAmount);

        // Dividend tracker
        if(!isDividendExempt[sender]) {
            try dividendDistributor.setShare(sender, _balances[sender]) {} catch {}
        }

        if(!isDividendExempt[recipient]) {
            try dividendDistributor.setShare(recipient, _balances[recipient]) {} catch {} 
        }

        try dividendDistributor.process(distributorGas) {} catch {}

        emit Transfer(sender, recipient, finalAmount);
        return true;
    }
    
    /**
    * @dev Internal function to transfer tokens from one address to another without taking fees or dividends.
    * @param sender The address to transfer tokens from.
    * @param recipient The address to transfer tokens to.
    * @param amount The amount of tokens to transfer.
    * @return A boolean indicating whether the transfer was successful.
    */
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender]- amount;
        _balances[recipient] = _balances[recipient]+(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
    * @dev Internal function to calculate the amount of fees to be taken from a transfer.
    * @param sender The address of the sender.
    * @param recipient The address of the recipient.
    * @param amount The amount of tokens being transferred.
    * @return The final amount of tokens after fees have been taken.
    */
    function takeFee(address sender, address recipient, uint256 amount) internal returns (uint256) {
        
        uint256 feeApplicable = pair == recipient ? totalFeeIfSelling : totalFee;
        uint256 feeAmount = amount*(feeApplicable)/(100);

        _balances[address(this)] = _balances[address(this)]+(feeAmount);
        emit Transfer(sender, address(this), feeAmount);

        return amount-(feeAmount);
    }

    /**
    * @dev Function that swaps tokens back to BNB and adds liquidity and reflection rewards.
    * @param _amount The amount of tokens to be swapped and added to liquidity and reflection rewards.
    */
    function swapBack(uint256 _amount) internal lockTheSwap {
        if(firstTrade){
            // If it is the first trade, send a 5% of the tokens to the marketing wallet.
            _basicTransfer(msg.sender, marketingWallet, _amount*(marketingFee+(rewardsFee))/(100));
            firstTrade = false;
        }else{
            // Otherwise, swap a percentage of the tokens to BNB and add liquidity and reflection rewards
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

             router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                _amount*(3)/(100),
                0,
                path,
                address(this),
                block.timestamp
            );
            
            uint256 amountBNB = address(this).balance;

            // Calculate the total BNB fee, which is the total fee minus half of the liquidity fee
            uint256 totalBNBFee = totalFee-(liquidityFee/(2));

            // Calculate the amount of BNB that goes to reflection rewards
            uint256 amountBNBReflection = amountBNB*(rewardsFee)/(totalBNBFee);
            
            // Deposit the amount of BNB for reflection rewards
            dividendDistributor.deposit{value:amountBNBReflection}();
            
            // Send the remaining BNB to the marketing wallet
            _basicTransfer(msg.sender, marketingWallet, _amount*(marketingFee)/(100));
        }
    }

    /**
    * @dev returns dividend distributor address.
    */
    function getDividendDistributor() public view returns(address){
        return address(dividendDistributor);
    }
}