/*
▒█░░▒█ ▒█▀▀▀ ▒█░░░ ▒█▀▀█ ▒█▀▀▀█ ▒█▀▄▀█ ▒█▀▀▀ 　 ▀▀█▀▀ ▒█▀▀▀█ 　 ▀▀█▀▀ ▒█░▒█ ▒█▀▀▀ 
▒█▒█▒█ ▒█▀▀▀ ▒█░░░ ▒█░░░ ▒█░░▒█ ▒█▒█▒█ ▒█▀▀▀ 　 ░▒█░░ ▒█░░▒█ 　 ░▒█░░ ▒█▀▀█ ▒█▀▀▀ 
▒█▄▀▄█ ▒█▄▄▄ ▒█▄▄█ ▒█▄▄█ ▒█▄▄▄█ ▒█░░▒█ ▒█▄▄▄ 　 ░▒█░░ ▒█▄▄▄█ 　 ░▒█░░ ▒█░▒█ ▒█▄▄▄ 

▒█▀▀▀ ▒█░▒█ ▀▀█▀▀ ▒█░▒█ ▒█▀▀█ ▒█▀▀▀ 　 ▒█▀▀▀█ ▒█▀▀▀ 　 ▒█▀▀█ ▀█▀ ▀▀█▀▀ ▒█▀▀█ ▒█▀▀▀█ ▀█▀ ▒█▄░▒█ 
▒█▀▀▀ ▒█░▒█ ░▒█░░ ▒█░▒█ ▒█▄▄▀ ▒█▀▀▀ 　 ▒█░░▒█ ▒█▀▀▀ 　 ▒█▀▀▄ ▒█░ ░▒█░░ ▒█░░░ ▒█░░▒█ ▒█░ ▒█▒█▒█ 
▒█░░░ ░▀▄▄▀ ░▒█░░ ░▀▄▄▀ ▒█░▒█ ▒█▄▄▄ 　 ▒█▄▄▄█ ▒█░░░ 　 ▒█▄▄█ ▄█▄ ░▒█░░ ▒█▄▄█ ▒█▄▄▄█ ▄█▄ ▒█░░▀█

*100% SAFU
*Owner cant mint, changetax, or blacklist
*Permanently fixed 1% Burn tax

##Socials##
twitter: https://twitter.com/btcx_token
telegram: https://t.me/btcx_token
github: https://t.me/btcx_token
*/
// SPDX-License-Identifier: MIT

import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./EnumerableSet.sol";

// File: BTCX.sol
pragma solidity =0.8.19;

contract BTCXTOKEN is ERC20, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    event Burn(uint256 amount, uint timestamp);
	event Trade(address pair, uint256 amount, uint side, uint256 circulatingSupply, uint timestamp);

    bool public burnEnabled = false;

    mapping(address => bool) public isFeeExempt;
    mapping(address => bool) public canAddLiquidityBeforeLaunch;

    uint256 private burnFee;
    uint256 private totalFee;
    uint256 public feeDenominator = 10000;

    // Buy Fees
    uint256 public burnFeeBuy = 100;
    uint256 public totalFeeBuy = 100;
	
    // Sell Fees
    uint256 public burnFeeSell = 100;
    uint256 public totalFeeSell = 100;
	
    uint256 public launchedAt;
    uint256 public launchedAtTimestamp;
	
    address public constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    EnumerableSet.AddressSet private _pairs;

    constructor() ERC20("BTCXTOKEN", "BTCX") {
        uint256 _totalSupply = 21_000_000 * 1e18;
        canAddLiquidityBeforeLaunch[_msgSender()] = true;
        isFeeExempt[msg.sender] = true;
        isFeeExempt[address(this)] = true;
        _mint(_msgSender(), _totalSupply);
    }



    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        return _btcxTransfer(_msgSender(), to, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(sender, spender, amount);
        return _btcxTransfer(sender, recipient, amount);
    }

    function _btcxTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        
        if (!canAddLiquidityBeforeLaunch[sender]) {
            require(launched(), "Project Not yet started");
        }

        bool shouldTakeFee = (!isFeeExempt[sender] && !isFeeExempt[recipient]) && launched() && burnEnabled;
        uint side = 0;
        address pair_ = recipient;
        // Set Fees
        if (isPair(sender)) {
            buyFees();
            side = 1;
            pair_ = sender;

		} else if (isPair(recipient)) {
            sellFees();
            side = 2;
        } else {
            shouldTakeFee = false; //dont take BURN fee for wallet to wallet token transfers
        }

        uint256 amountReceived = shouldTakeFee ? takeAndBurnFee(sender, amount) : amount;
        _transfer(sender, recipient, amountReceived);

        if (side > 0) {
            emit Trade(pair_, amount, side, getCirculatingSupply(), block.timestamp);
        }
        return true;
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function buyFees() internal {
        burnFee = burnFeeBuy;
        totalFee = totalFeeBuy;
    }

    function sellFees() internal {
        burnFee = burnFeeSell;
        totalFee = totalFeeSell;
    }

    function takeAndBurnFee(address sender, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = (amount * totalFee) / feeDenominator;
        _transfer(sender, BURN_ADDRESS, feeAmount);
        return amount - feeAmount;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return totalSupply() - balanceOf(BURN_ADDRESS) - balanceOf(ZERO_ADDRESS);
    }
	
	function getMinterLength() public view returns (uint256) {
        return _pairs.length();
    }

    function getPair(uint256 index) public view returns (address) {
        require(index <= _pairs.length() - 1, "index out of bounds");
        return _pairs.at(index);
    }
	
	function isPair(address account) public view returns (bool) {
        return _pairs.contains(account);
    }


    
	/*** ADMIN FUNCTIONS ***/
    function launch() public onlyOwner {
        require(launchedAt == 0, "Already launched");
        launchedAt = block.number;
        launchedAtTimestamp = block.timestamp;
    }

    function rescueToken(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(msg.sender,IERC20(tokenAddress).balanceOf(address(this)));
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }    
	
	function setPresaleWallet(address holder, bool exempt) external onlyOwner {
        canAddLiquidityBeforeLaunch[holder] = exempt;
    }

    function setBurnSettings(bool _enabled) external onlyOwner {
        burnEnabled = _enabled;
    }

    function addPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "pair is the zero address");
        return _pairs.add(pair);
    }

    function delPair(address pair) public onlyOwner returns (bool) {
        require(pair != address(0), "pair is the zero address");
        return _pairs.remove(pair);
    }
	
}