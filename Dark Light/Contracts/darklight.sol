//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./IFomo.sol";

contract DLT is ERC20Upgradeable, AccessControlUpgradeable {
	bytes32 public constant MINTER_ROLE = "MINTER_ROLE";

	uint public _fee;
	mapping(address=>bool) public _isExcludedFromFee;
	IFomo public _fomo;
	address public _uniswapV2Pair;
	uint public _fomoMin;

	function initialize() initializer public {
		__ERC20_init("DarkLight", "DLT");
		__AccessControl_init();
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(MINTER_ROLE, msg.sender);
    }

	function init() public onlyRole(DEFAULT_ADMIN_ROLE){
		_fee = 5;
		_fomoMin = 1000 * decimals();
	}

	function mint(address account, uint amount) public  onlyRole(MINTER_ROLE) {
		_mint(account, amount);
	}

	function burn(address account, uint amount) public  onlyRole(MINTER_ROLE) {
		_burn(account, amount);
	}


	function changeAdmin(address admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
		_revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(DEFAULT_ADMIN_ROLE, admin);
	}

	function getFomoFee(address from,address to, uint256 amount ) private view returns (uint newAmount, uint useFee){
        bool takeFee = true;

        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

		newAmount = amount;
		if(takeFee){
			useFee = amount * _fee / 100;
			newAmount = amount - useFee;
		}
	}

	function processFomo(address from,address to, uint256 amount) private {
		bool takeFee = true;

        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

		if(address(_fomo) == address(0))return;

		if (takeFee && from == _uniswapV2Pair && amount >= _fomoMin) {
			_fomo.transferNotify(to);
		}
		if (from != _uniswapV2Pair && from != address(_fomo)) {
			_fomo.swap();
		}
	}

	function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
		(uint newAmount, uint useFee) = getFomoFee(from,to,amount);

		require(super.transferFrom(from,to,newAmount));
		if(useFee>0){
			require(super.transferFrom(from,address(_fomo),useFee));
		}

		processFomo(from,to,amount);
		return true;
    }

	function transfer(address to, uint256 amount) public virtual override returns (bool) {
		address from = msg.sender;

		(uint newAmount, uint useFee) = getFomoFee(from,to,amount);

		require(super.transfer(to,newAmount));
		if(useFee>0){
			require(super.transfer(address(_fomo),useFee));
		}

		processFomo(from,to,amount);
        return true;
    }

	function excludeFromFee(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _isExcludedFromFee[account] = false;
    }

	function setFomo(address fomo) public onlyRole(DEFAULT_ADMIN_ROLE){
		_fomo = IFomo(fomo);
	}

	function setUniswapV2Pair(address pair) public onlyRole(DEFAULT_ADMIN_ROLE){
		_uniswapV2Pair = pair;
	}

	function setFomoMin(uint min) public onlyRole(DEFAULT_ADMIN_ROLE){
		_fomoMin = min;
	}

	function setFee(uint fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
		require(fee>=0 && fee <= 20);
		_fee = fee;
	}
}