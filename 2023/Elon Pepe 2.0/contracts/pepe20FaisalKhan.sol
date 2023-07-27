// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract ElonePepe20 is ERC20, Ownable {
           

            ///ERRORS //
      error MaxFeeLimitExceeded();
      error ZeroAddressNotAllowed();
      error TradingIsAlreadyLive();
      error UpdateBoolValue();
      error AmountTooLow();
      error TradingIsNotActiveYet();
      error CanNotModifyMainPair();
            ///Constants ///
      uint16 constant public MAX_FEE = 5;
      uint256 constant public MIN_SWAP_AT_AMOUNT = 1e8 * 1e9;
      address constant public DEAD = address(0xdead);
          
          ///Fees Variables ///
      uint16 public buyFees = 1;
      uint16 public sellFees = 1;

        ///Fee wallet and uniswap router, pair variables///
      address public feeWallet = address(0x123);
      address public uniswapV2Pair;
      IUniswapV2Router02 public uniswapV2Router;
        
        ///Max Supply/swap amount///
      uint256 maxSupply = 7e12 * 1e9; // 7 Trillion 
      uint256 swapTokensAtAmount = (maxSupply * 10) / 100000; // 0.01% of the supply

         ///Mappings//
      mapping(address => bool) public isExcludedFromFees;
      mapping(address=> bool) public isLiquidityPair;

         ///Bool
      bool public isTradingEnabled;
      bool public swapEnabled;
      bool swapping;
         ///events

      event TradingEnabled(uint256 indexed tradeStartTimeStamp);
      event SwapTokensAmountUpdated (uint256 indexed newAmount);
      event FeeWalletUpdated(address indexed newFeeWallet);
      event ExcludedFromFees (address account, bool value);
      event NewLPUpdated(address lp, bool value); 
      event FeesUpdated(uint16 buyFee, uint16 sellFee);  

      constructor() ERC20("Elonepepe2.0", "ElonePepe2.0"){
            IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D//uniswap V2 Router
        );

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        isLiquidityPair[uniswapV2Pair] = true;    
        
        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[feeWallet] = true;
        isExcludedFromFees[DEAD] = true;
        _mint(owner(), maxSupply);
      }
    ///@notice returns decimals
    function decimals () public pure override returns (uint8) {
        return 9;
    }
    
    ///@dev enable trading gloablly, once enabled it can 
    /// never be turned off
    function enableTrading () external onlyOwner {
        if(isTradingEnabled){
            revert TradingIsAlreadyLive();
        }
        isTradingEnabled = true;
        swapEnabled = true;
        emit TradingEnabled(block.timestamp);
    }
    
    ///@dev update fee wallet 
    ///@param _newFeeWallet: new wallet address for fees
    ///Requirements -
    /// _newFeeWallet address should not be zero address.
    function updateFeeWallet (address _newFeeWallet) external  onlyOwner {
        if(_newFeeWallet == address(0)){
            revert ZeroAddressNotAllowed();
        }
        feeWallet = _newFeeWallet;
        emit FeeWalletUpdated(_newFeeWallet);
    }
    
    ///@dev update fees for buy and sell
    ///@param buy: new buy fees
    ///@param sell: new sell fees
    ///Requirements-
    /// sum of buy and sell should be less than equal to MAX_FEE 
    function updateFees (uint16 buy, uint16 sell) external onlyOwner {
        if(buy+sell > MAX_FEE){
            revert MaxFeeLimitExceeded();
        }
        buyFees = buy;
        sellFees = sell;
        emit FeesUpdated(buy, sell);
    }
    
    ///@dev exclude or include in fee mapping
    ///@param user: user to exclude or include in fee
    function excludeFromFees (address user, bool isExcluded) external onlyOwner {
        if(isExcludedFromFees[user] = isExcluded){
            revert UpdateBoolValue();
        }
        isExcludedFromFees[user] = isExcluded;
        emit ExcludedFromFees(user, isExcluded);
    }
    
    ///@dev add or remove new pairs
    ///@param newPair; new pair address
    ///@param value: boolean value true true for adding, false for removing
    ///Requirements -
    ///Can't modify uniswapV2Pair (main pair)
    function manageLiquidityPairs (address newPair, bool value) external onlyOwner{
        if(newPair == uniswapV2Pair){
            revert CanNotModifyMainPair();
        }
        isLiquidityPair[newPair] = value;
        emit NewLPUpdated(newPair, value);
    }
    

    ///@dev update the swap token amount
    ///@param _newSwapAmount: new token amount to swap threshold
    ///Requirements--
    /// amount must greator than equal to MIN_SWAP_AT_AMOUNT
    function updateSwapTokensAtAmount (uint256 _newSwapAmount) external onlyOwner {
        if(_newSwapAmount < MIN_SWAP_AT_AMOUNT){
            revert AmountTooLow();
        }
        swapTokensAtAmount = _newSwapAmount;
        emit SwapTokensAmountUpdated(_newSwapAmount);
    }



    ///@notice transfer function to manage token transfer/fees/limits
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !swapping
            ) {
                if (!isTradingEnabled ) {
                    if(!isExcludedFromFees[from] || !isExcludedFromFees[to]) {
                        revert TradingIsNotActiveYet();
                    }
                }
               
            }
        uint256 contractBalance = balanceOf(address(this));

        if (
            swapEnabled && //if this is true
            !swapping && //if this is false
            !isLiquidityPair[from] && //if this is false
            !isExcludedFromFees[from] && //if this is false
            !isExcludedFromFees[to] && //if this false
            contractBalance >=swapTokensAtAmount //if this is true
        ) {
         
            swapping = true;
            swapTokensForEth(contractBalance);
            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (isExcludedFromFees[from] || isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
       
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
           
            //on sell
            if ( isLiquidityPair[to] && sellFees > 0) {
                fees = (amount * sellFees) / 100;
                
            }
            
            // on buy
            else if (isLiquidityPair[from] && buyFees > 0) {
                fees = (amount * buyFees) / 100;
             

            }
           
            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
            amount -= fees;
        }
        super._transfer(from, to, amount);
    }
    


     ///@notice private function to swap tax to eth
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        if(allowance(address(this), address(uniswapV2Router)) < tokenAmount){
          _approve(address(this), address(uniswapV2Router), type(uint256).max);
        }
       
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            feeWallet,
            block.timestamp
        );
    }

}