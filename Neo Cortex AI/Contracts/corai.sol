// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error invalidTaxValue();
error overMaxLimit();
error invalidTxLimit();
error overAllowedBalance();
error zeroAddress();
/**
* @title An ERC20 contract with tax and tx limit features
* @author sandwizard
* @dev Inherits the OpenZepplin ERC20 implentation
**/
contract CORAI is ERC20, ERC20Burnable,AccessControl,ERC20Permit,Ownable{
    /// @notice dead address used to burn tokens
    address constant private NullAddress = 0x000000000000000000000000000000000000dEaD;
    /// @notice percent of total supply txamount lower limit scaled by 1e18 0.0004 %
    /// @dev limit must be 0 or above lowestTXLimitPercent of total supply
    uint256 public  constant lowestTXLimitPercent =  400000000000000;

    /// @notice liquidity_pool role identifier. used to apply tax on liquidity pools
    /// @dev for use with role based access control.from open zeeplin access control
    /// @return  liquidity_pool  role identifier
    bytes32 public constant liquidity_pool = keccak256("liquidity_pool");

    /// @notice limit_exempt exempt from sell limit  ues with mm wallets
    /// @return limit_exempt role identifier
    bytes32 public constant limit_exempt = keccak256("limit_exempt");

    /// @notice max tx limit. only applied on sell to liquidity pool
    /// @return  maxTxAmount for sell to pools
    uint256  public maxTxAmount;

    /// @notice Deploys the smart contract and creates mints inital sypply to "to" address
    /// @dev owner ship is transfer on deployment and deployer address has no access to any admin functions
    /// @dev pass normal erc20 parameters such as symbol name. with to address and fee address
    constructor(uint256 initialSupply_,string memory name_,string memory symbol_,address to_) ERC20(name_, symbol_)   ERC20Permit(name_){
        if(to_ == address(0)){
            revert zeroAddress();
        }
        _transferOwnership(to_);
        _grantRole(DEFAULT_ADMIN_ROLE, to_);
        _grantRole(limit_exempt, to_);
        _mint(to_,initialSupply_);
        maxTxAmount = 200000000000000000000000;
    }

    /**
    * @return totalsupply factoring in burned tokens sent to dead address
    **/
    function totalSupply() public view  override returns (uint256) {
        uint256 totalSupplyWithNull_ = super.totalSupply();
        uint256 totalSupply_ = totalSupplyWithNull_ - balanceOf(NullAddress);
        return totalSupply_;
    }

    /// @dev normal erc20 transferFrom function incase of wallet transfer
    /// @dev else tax and limit(only sale) is applied when a lp pool is involved
    /// @dev in case on both sender and receiver is lp pool no tax or limit applied
    function transferFrom(address from,address to,uint256 amount) public virtual override  returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        validAmount(amount,from,to);
        return true;
    }

    /// @dev normal erc20 transfer function incase of wallet transfer
    /// @dev else tax and limit(only sale) is applied when a lp pool is involved
    /// @dev in case on both sender and receiver is lp pool no tax or limit applied
    function transfer(address to, uint256 amount) public virtual override returns (bool)  {
        address owner_ = _msgSender();
        _transfer(owner_, to, amount);
        validAmount(amount,owner_,to);
        return true;
    }
    /// @notice set the fee where txlimit in terms of token on sell to lp pools
    /// @dev  cannot be lower than lowertaxlimit percet of total supply
    /// @dev only admin can change
    function setMaxTxAmount (uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE){
        uint256 lowestPossibleTXLimit =getLowestPossibleTXLimit();
        if(amount != 0 && amount<lowestPossibleTXLimit){
            revert invalidTxLimit();
        }
        maxTxAmount = amount;
    }
    /// @notice get the lowest possible tx limit value
    /// @dev is 0.0004 % of total supply
    function getLowestPossibleTXLimit() public view returns(uint256){
        uint256 limit = totalSupply() * lowestTXLimitPercent /(100 * 1e18);
        return limit;
    }
    /// @dev  internal func to apply tx limit if sell to lp pool
    /// @dev ignored incase between lp pools
    function validAmount(uint256 amount,address from,address to) internal view{
        bool receiverIsLiquidityPool =  hasRole(liquidity_pool,to);
        bool senderIsLiquidityPool = hasRole(liquidity_pool, from);
        if((receiverIsLiquidityPool && !senderIsLiquidityPool)
        && (amount > maxTxAmount && maxTxAmount!= 0 ) && !hasRole(limit_exempt, to) && !hasRole(limit_exempt, from)
        ){
            revert overMaxLimit();
        }
    }

}