// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IVault} from "./interfaces/IVault.sol";
import {ILsdRateOracle} from "./interfaces/ILsdRateOracle.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Pool
/// @author velodrome.finance, @figs999, @pegahcarter
/// @notice Veldrome V2 token pool, either stable or volatile
contract Vault is IVault, ERC20Permit, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string private _name;

    string private _symbol;

    address private vaultFactory;
    
    address public lsdToken;

    address public vaultGauge;

    address public lsdRateOracle;

    error FactoryAlreadySet();

    constructor() ERC20("", "") ERC20Permit("") {}

    modifier onlyFactory() {
        require(msg.sender == vaultFactory ,"onlyFactory");
        _;
    }

    function setGauge(address _vaultGauge) external onlyFactory {
        require(vaultGauge == address(0),"gauge not null");
        vaultGauge = _vaultGauge;
    }

    function initialize(address _lsdToken, address _lsdRateOracle) external {
        if (vaultFactory != address(0)) revert FactoryAlreadySet();
        require(_lsdToken != address(0),"null address") ;
        require(_lsdRateOracle != address(0),"null address") ;
        vaultFactory = msg.sender;
        lsdToken = _lsdToken;
        lsdRateOracle = _lsdRateOracle;
        string memory symbol = ERC20(_lsdToken).symbol();
        _name = string(abi.encodePacked("Vault-", symbol));
        _symbol = string(abi.encodePacked("Vault-", symbol));
    }

    function deposit(uint256 amount) external {

        require(amount > 0 ,"amount = 0");

        uint256 eqEth = _getEqEth(amount);

        require(IERC20(lsdToken).allowance(msg.sender,address(this)) >= amount,"not enough allowance" );
        
        IERC20(lsdToken).safeTransferFrom(msg.sender, address(this), amount);
        
        _mint(msg.sender,eqEth);

        emit Deposit(msg.sender, amount, eqEth);       
    }

    function withdraw(uint256 amount) external {

        require(amount > 0, "amount = 0");

        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _burn(msg.sender,amount);

        uint256 eqLsd = _getEqLsd(amount);
        
        IERC20(lsdToken).safeTransfer(msg.sender, eqLsd);

        emit Withdraw(msg.sender, amount, eqLsd);
    }

    function claimFees() external nonReentrant returns (uint256) {
        require(msg.sender== vaultGauge ,"only vaultGauge");
        uint256 _totalSupply = totalSupply(); 
        uint256 _totalLsd = IERC20(lsdToken).balanceOf(address(this));
        uint256 userLsd = _getEqLsd(_totalSupply);
        require(_totalLsd > userLsd,"null address") ;
        uint256 claimFeeLsd = _totalLsd - userLsd;
        if(claimFeeLsd > 0 ){
          IERC20(lsdToken).safeTransfer(msg.sender, claimFeeLsd);
        }
        emit ClaimFees(msg.sender, claimFeeLsd);
        return claimFeeLsd;
    }

   function _getEqEth(uint256 lsdAmount) view internal returns(uint256 eqEth) {
        if(lsdAmount == 0 ){
          return 0;
        }
        uint256 currentRate = ILsdRateOracle(lsdRateOracle).getLsdRate();
        require(currentRate >= 1e18 ,"rate wrong");
        eqEth = (lsdAmount * currentRate) / 1e18;
    }
    
    function _getEqLsd(uint256 amount) view internal returns(uint256 eqLsd) {
        if(amount == 0 ){
          return 0;
        }
        uint256 currentRate = ILsdRateOracle(lsdRateOracle).getLsdRate();
        require(currentRate >= 1e18 ,"rate wrong");
        eqLsd = (amount * 1e18) / currentRate;
    }
    

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
   
}
