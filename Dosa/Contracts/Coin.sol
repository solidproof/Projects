// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IDex.sol";

contract DOSA is ERC20, Ownable{
    using Address for address payable;

    mapping(address => bool) public exemptFee;

    IRouter public router;
    address public pair;

    address public lpRecipient;
    address public marketingWallet;
    address public dosaBombWallet;

    bool private swapping;
    bool public swapEnabled;
    uint256 public swapThreshold;
    uint256 public maxWalletAmount;

    uint256 public transferFee;

    struct Fees {
        uint256 lp;
        uint256 marketing;
        uint256 dosaBomb;
    }

    Fees public buyFees = Fees(3,2,2);
    Fees public sellFees = Fees(3,2,2);
    uint256 public totalSellFee = 7;
    uint256 public totalBuyFee = 7;

    bool public enableTransfers;

    modifier inSwap() {
        if (!swapping) {
            swapping = true;
            _;
            swapping = false;
        }
    }

    event TaxRecipientsUpdated(address newLpRecipient, address newMarketingWallet, address newDosaBombWallet);
    event FeesUpdated();
    event SwapEnabled(bool state);
    event SwapThresholdUpdated(uint256 amount);
    event MaxWalletAmountUpdated(uint256 amount);
    event RouterUpdated(address newRouter);
    event ExemptFromFeeUpdated(address user, bool state);
    event PairUpdated(address newPair);

    constructor(address _routerAddress, string memory _name_, string memory _symbol_) ERC20(_name_, _symbol_) {
        require(_routerAddress != address(0), "Router address cannot be zero address");
        IRouter _router = IRouter(_routerAddress);

        address _pair = IFactory(_router.factory()).createPair(address(this), _router.WETH());

        router = _router;
        pair = _pair;

        swapEnabled = true;
        swapThreshold = 500_000 * 10**18;
        maxWalletAmount = 10_000_000 * 10**18;

        exemptFee[msg.sender] = true;
        exemptFee[address(this)] = true;
        exemptFee[marketingWallet] = true;
        exemptFee[dosaBombWallet] = true;
        exemptFee[lpRecipient] = true;

        _mint(msg.sender, 1_000_000_000 * 10**18);
    }

    function setTaxRecipients(address _lpRecipient, address _marketingWallet, address _dosaBombWallet) external onlyOwner{
        require(_lpRecipient != address(0), "lpRecipient cannot be the zero address");
        require(_marketingWallet != address(0), "marketingWallet cannot be the zero address");
        require(_dosaBombWallet != address(0), "dosaBombWallet cannot be the zero address");
        lpRecipient = _lpRecipient;
        marketingWallet = _marketingWallet;
        dosaBombWallet = _dosaBombWallet;

        exemptFee[dosaBombWallet] = true;
        exemptFee[marketingWallet] = true;
        exemptFee[lpRecipient] = true;

        emit TaxRecipientsUpdated(_lpRecipient, _marketingWallet, _dosaBombWallet);
    }

    function setTransferFee(uint256 _transferFee) external onlyOwner{
        require(_transferFee < 7, "Transfer fee must be less than 7");
        transferFee = _transferFee;
        emit FeesUpdated();
    }

    function setBuyFees(uint256 _lp, uint256 _marketing, uint256 _dosaBomb) external onlyOwner{
        require(_lp + _marketing + _dosaBomb < 7, "Buy fee must be less than 7");
        buyFees = Fees(_lp, _marketing, _dosaBomb);
        totalBuyFee = _lp + _marketing + _dosaBomb;
        emit FeesUpdated();
    }

    function setSellFees(uint256 _lp, uint256 _marketing, uint256 _dosaBomb) external onlyOwner{
        require(_lp + _marketing + _dosaBomb < 7, "Sell fee must be less than 7");
        sellFees = Fees(_lp, _marketing, _dosaBomb);
        totalSellFee = _lp + _marketing + _dosaBomb;
        emit FeesUpdated();
    }

    function setSwapEnabled(bool state) external onlyOwner{
        swapEnabled = state;
        emit SwapEnabled(state);
    }

    function setSwapThreshold(uint256 amount) external onlyOwner{
        swapThreshold = amount * 10**18;
        emit SwapThresholdUpdated(amount);
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner{
        require(amount >= 5_000_000, "Max wallet amount must be >= 5,000,000");
        maxWalletAmount = amount * 10**18;
        emit MaxWalletAmountUpdated(amount);
    }

    function setRouter(address newRouter) external onlyOwner{
        router = IRouter(newRouter);
        emit RouterUpdated(newRouter);
    }

    function setPair(address newPair) external onlyOwner{
        require(newPair != address(0), "Pair cannot be zero address");
        pair = newPair;
        emit PairUpdated(newPair);
    }

    function exemptFromFee(address user, bool state) external onlyOwner{
        require(exemptFee[user] != state, "State already set");
        exemptFee[user] = state;
        emit ExemptFromFeeUpdated(user, state);
    }

    function rescueETH() external onlyOwner{
        require(address(this).balance > 0, "Insufficient ETH balance");
        payable(owner()).sendValue(address(this).balance);
    }

    function rescueERC20(address tokenAdd, uint256 amount) external onlyOwner{
        require(tokenAdd != address(this), "Cannot rescue self");
        require(IERC20(tokenAdd).balanceOf(address(this)) >= amount, "Insufficient ERC20 balance");
        IERC20(tokenAdd).transfer(owner(), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(amount > 0, "Transfer amount must be greater than zero");

        if(!exemptFee[from] && !exemptFee[to]) {
            require(enableTransfers, "Transactions are not enable");
            if(to != pair) require(balanceOf(to) + amount <= maxWalletAmount, "Receiver balance is exceeding maxWalletAmount");
        }

        uint256 taxAmt;

        if(!swapping && !exemptFee[from] && !exemptFee[to]){
            if(to == pair){
                taxAmt = amount * totalSellFee / 100;
            } else if(from == pair){
                taxAmt = amount * totalBuyFee / 100;
            } else {
                taxAmt = amount * transferFee / 100;
            }
        }

        if (!swapping && swapEnabled && to == pair && totalSellFee > 0) {
            handle_fees();
        }

        super._transfer(from, to, amount - taxAmt);
        if(taxAmt > 0) {
            super._transfer(from, address(this), taxAmt);
        }
    }

    function handle_fees() private inSwap {
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance >= swapThreshold) {
            if(swapThreshold > 1){
                contractBalance = swapThreshold;
            }
            // Split the contract balance into halves
            uint256 denominator = totalSellFee * 2;
            uint256 tokensToAddLiquidityWith = contractBalance * sellFees.lp / denominator;
            uint256 toSwap = contractBalance - tokensToAddLiquidityWith;

            uint256 initialBalance = address(this).balance;

            swapTokensForETH(toSwap);

            uint256 deltaBalance = address(this).balance - initialBalance;
            uint256 unitBalance= deltaBalance / (denominator - sellFees.lp);
            uint256 ethToAddLiquidityWith = unitBalance * sellFees.lp;

            if(ethToAddLiquidityWith > 0){
                // Add liquidity to pancake
                addLiquidity(tokensToAddLiquidityWith, ethToAddLiquidityWith);
            }

            uint256 marketingAmt = unitBalance * 2 * sellFees.marketing;
            if(marketingAmt > 0){
                payable(marketingWallet).sendValue(marketingAmt);
            }

            uint256 dosaBombAmt = unitBalance * 2 * sellFees.dosaBomb;
            if(dosaBombAmt > 0){
                payable(dosaBombWallet).sendValue(dosaBombAmt);
            }
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> ETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);

    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lpRecipient,
            block.timestamp
        );
    }

    function setEnableTransfers() external onlyOwner {
        enableTransfers = true;
    }

    // fallbacks
    receive() external payable {}
}