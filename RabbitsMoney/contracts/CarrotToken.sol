// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ITEST.sol"; 

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}
 
interface IUniswapV2Router02 {
 
    function factory() external pure returns (address);

 
    // function addLiquidityETH(
    //     address token,
    //     uint256 amountTokenDesired,
    //     uint256 amountTokenMin,
    //     uint256 amountETHMin,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     payable
    //     returns (
    //         uint256 amountToken,
    //         uint256 amountETH,
    //         uint256 liquidity
    //     );

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
}
 
contract TEST is ITEST, ERC20, Ownable {
    
    uint256 public maxSupply;
    uint256 private initialSupply;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    //safeMathuse
    using SafeMath for uint256;
    
    // a mapping from an address to whether or not it can mint / burn

    mapping(address => bool) public isController;


    //set defaut trading status to false

    bool public tradingEnabled = false;

    //constructor 

    constructor(uint256 _initialSupply , uint256 _maxSupply) ERC20("TEST", "TEST") 
    {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);//
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
        initialSupply = _initialSupply;
        maxSupply = _maxSupply;
        _mint(msg.sender, initialSupply);
    }

    //mints $TEST to a recipient

    function mint(address to_, uint256 amount_)
        external
        onlyController
    {
        _mint(to_, amount_);
    }

    //burns $TEST from a holder

    function burn(address from_, uint256 amount_)
        external
        
        onlyController
    {
        _burn(from_, amount_);
    }

    event ControllerAdded(address newController);

    //enables an address to mint / burn   
    
    function addController(address toAdd_) external onlyOwner {
        isController[toAdd_] = true;
        emit ControllerAdded(toAdd_);
    }

    event ControllerRemoved(address controllerRemoved);

    //disable an address to mint / burn

    function removeController(address toRemove_) external onlyOwner {
        isController[toRemove_] = false;
        emit ControllerRemoved(toRemove_);
    }

    //only controllers

    modifier onlyController() {
        if(isController[_msgSender()] == false) revert("CallerNotController");
        _;
    }

    //trading status function 

     function pause_trading() public onlyController{       
        tradingEnabled = false;
    }

    function enable_trading() public onlyController{
        tradingEnabled = true;
    }


    //transfer function
    function _transfer(
    address from,
    address to,
    uint256 amount
    
    ) internal override {
    require(tradingEnabled, "Trading is currently disabled");
    ERC20._transfer(from, to, amount);
    
   }
   
}