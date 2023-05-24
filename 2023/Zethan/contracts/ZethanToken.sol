pragma solidity 0.8.8;

// Import necessary libraries
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

 struct route {
        address from;
        address to;
        bool stable;
    }

interface    IUniswapV2Router02  {
    function swapExactTokensForETH(uint256,
        uint256,
        route[] calldata,
        address,
        uint256
) external returns (uint256);


        function weth() external pure returns (address);

}


interface    ITreasury  {
    function processTreasure() external returns (bool);

}


 


contract ZethanToken is ERC20 {
    using SafeMath for uint256;

    // Address of the contract owner
    address public _owner;

    address public _pair ; 

    bool public allowSwapping ; 
    bool public allowTransfer ; 
  

    // Address of the Uniswap router
    IUniswapV2Router02 public uniswapV2Router;

    // Percentage tax on each sell transaction (6% in this case)
    uint256 public _sellTaxPercentage = 6;

    // Address to receive the swapped ETH
    address public _treasuryAddress;

    // Addresses excluded from the sell tax
    mapping(address => bool) public _excludedFromTax;

    receive() external payable {}
    fallback() external payable {}


    constructor(
    ) ERC20("ZethanToken", "ZETH") {
        _owner = msg.sender;
        uniswapV2Router = IUniswapV2Router02(0xB2CEF7f2eCF1f4f0154D129C6e111d81f68e6d03);
        _treasuryAddress = 0x1DE12233C4AB68018173Ade5EE074d89C7254F4b;
        _pair = 0xB2CEF7f2eCF1f4f0154D129C6e111d81f68e6d03 ; 
        _excludedFromTax[msg.sender] = true;
        _excludedFromTax[0xB2CEF7f2eCF1f4f0154D129C6e111d81f68e6d03] = true;
        _mint(msg.sender, 100 * 1000000 * 10**decimals());
    }

    // Modifier to ensure that only the contract owner can call a function
    modifier onlyOwner() {
        require(msg.sender == _owner, "Caller is not the contract owner");
        _;
    }

    // Function to update the Uniswap router address
    function setUniswapRouter(address uniswapRouter) external onlyOwner {
        require(uniswapRouter != address(0) , "Can't set Zero Address" );
        uniswapV2Router = IUniswapV2Router02(uniswapRouter);
    }


       // Function to update the Uniswap pair address
    function setUniswapPair(address pair) external onlyOwner {
        require(pair != address(0) , "Can't set Zero Address" );

        _pair = pair;
    }


       // Function to update the _allowSwapping
    function setAllowSwapping(bool _allowSwapping) external onlyOwner {
        allowSwapping = _allowSwapping;
    }


     

         // Function to update the _allowTransfer
    function setAllowTransfer(bool _allowTransfer) external onlyOwner {
        allowTransfer = _allowTransfer;
    }



    

    // Function to get the current sell tax percentage
    function getSellTaxPercentage() public view returns (uint256) {
        return _sellTaxPercentage;
    }

    // Function to set the sell tax percentage
    function setSellTaxPercentage(uint256 sellTaxPercentage) external onlyOwner {
        require(sellTaxPercentage <= 6, "Sell tax percentage exceeds 6");
        _sellTaxPercentage = sellTaxPercentage;
    }

    // Function to update the tax wallet address
    function setTaxWallet(address taxWallet) external onlyOwner {
       
        _treasuryAddress = taxWallet;
    }

    // Function to exclude an address from the sell tax
    function excludeFromSellTax(address account) external onlyOwner {
        require(account != address(0) , "Can't set Zero Address" );
        
        _excludedFromTax[account] = true;
    }

    // Function to include an address in the sell tax
    function includeInSellTax(address account) external onlyOwner {
        require(account != address(0) , "Can't set Zero Address" );

        _excludedFromTax[account] = false;
    }

    
    // Override ERC20 _transfer function 
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        bool takeFee = true ;
        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_excludedFromTax[from]) {
            takeFee = false;
        }


        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee && to == _pair ) {
            // on sell
            if (_sellTaxPercentage > 0) {
                fees = amount.mul(_sellTaxPercentage).div(100);
            }
           

            if (fees > 0) {
                super._transfer(from, _treasuryAddress, fees);
                if(allowSwapping){
                ITreasury(_treasuryAddress).processTreasure();
                }
                if(allowTransfer){
                recoverEth() ;
                }
            }
            amount -= fees;
        }
        super._transfer(from, to, amount);
    }

    // Get ETH address from router
    function getWeth() public view returns  (address) {
       return uniswapV2Router.weth();

    }

    // Recover ETH from contract
    function recoverEth() public returns (bool){

                bool success; 
                (success, ) = payable(_treasuryAddress).call{
                     value: address(this).balance
                          }("");
                    return success ; 
    }


    // Recover ERC-20 from contract

  function recoverERC20(address tokenAddress, uint256 tokenAmount)
        public
        virtual
        onlyOwner
    {
        IERC20(tokenAddress).transfer(_treasuryAddress, tokenAmount);
     
    }



}



