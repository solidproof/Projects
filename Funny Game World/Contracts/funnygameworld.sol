// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FunnyWorldGameToken is ERC20, Ownable {
	mapping(address => bool) private _isBlacklisted;
    mapping(address => bool) private feeExemption;
	address public feeAddress;
	uint256 public taxFee;

	uint256 public constant TAX_FEE_MAX = 500; // 5% = 500, 0.8% = 80
	uint256 private constant TOTAL_SUPPLY_ = 1_000_000_000_000;
	string private constant NAME_ = "Funny Game World";
	string private constant SYMBOL_ = "FGW";

	event FeeAddressChanged(address oldAddress, address newAddress);
	event FeeTaxesChanged(uint256 newFee);

	modifier onlyValidAddress(address address_) {
		require(address_ != address(0), "Address cannot be zero");
		_;
	}

    constructor(address feeAddress_)
		ERC20(
			NAME_,
			SYMBOL_
		)
	{
		require(feeAddress_ != address(0), "Fee Address cannot be zero");
		feeAddress = feeAddress_;

		_exemptFromFee(feeAddress, true);
		_exemptFromFee(_msgSender(), true);

		uint256 totalSupply_ = TOTAL_SUPPLY_ * 10**decimals();
		_mint(_msgSender(), totalSupply_);

        emit Transfer(address(0), _msgSender(), totalSupply_);
    }

	function setFeeAddress(address feeAddress_)
		external
		onlyOwner()
		onlyValidAddress(feeAddress_)
	{
		_setFeeAddress(feeAddress_);
	}

	function setTaxFeePercentage(uint256 fee_)
		external
		onlyOwner()
	{
		require(fee_ <= TAX_FEE_MAX, "Fee cannot be higher than 5%");
		_setTaxFeePercentage(fee_);
	}

	function setBlacklist(
		address address_,
		bool status_
	)
		external
		onlyOwner()
		onlyValidAddress(address_)
	{
		_setBlacklist(address_, status_);
	}

	function isBlacklisted(address address_)
		public
		view
		returns(bool)
	{
		return _isBlacklisted[address_];
	}

	function isExemptFromFee(address address_)
		public
		view
		returns(bool)
	{
		return feeExemption[address_];
	}

	function exemptFromFee(
		address address_,
		bool exemptStatus_
	)
        external
        onlyOwner()
		onlyValidAddress(address_)
    {
        _exemptFromFee(address_, exemptStatus_);
    }

	// solium-disable-next-line security/no-assign-params
	function transfer(
		address to_,
		uint256 amount_
	)
		public
		override
		returns (bool)
	{
		address from = _msgSender();

		require(!isBlacklisted(from), "You're blacklisted");
		require(!isBlacklisted(to_), "Recipient is blacklisted");

		if(to_ != owner() && from != owner()) {
			if(!isExemptFromFee(from))
				amount_ = _takeTaxFee(from, amount_);
		}

		super._transfer(from, to_, amount_);

		return true;
	}

	function _setFeeAddress(address feeAddress_)
		private
	{
		_exemptFromFee(feeAddress, false);

		address oldAddress = feeAddress;
		feeAddress = feeAddress_;

		_exemptFromFee(feeAddress, true);

		emit FeeAddressChanged(oldAddress, feeAddress_);
	}

	function _isTaxFeeEnabled()
		private
		view
		returns(bool)
	{
		return taxFee > 0;
	}

	function _takeTaxFee(
		address from_,
		uint256 amount_
	)
		private
		returns(uint256 newAmount)
	{
		newAmount = amount_;

		if(_isTaxFeeEnabled() && from_ != feeAddress) {
			uint256 feeAmount = (amount_ * taxFee) / 10000;
			super._transfer(from_, feeAddress, feeAmount);

			newAmount = amount_ - feeAmount;
		}
	}

	function _setBlacklist(
		address address_,
		bool status_
	)
		private
	{
		_isBlacklisted[address_] = status_;
	}

	function _setTaxFeePercentage(uint256 fee_)
		private
	{
		taxFee = fee_;
		emit FeeTaxesChanged(fee_);
	}

	function _exemptFromFee(
		address address_,
		bool exemptStatus_
	)
        private
    {
        feeExemption[address_] = exemptStatus_;
    }
}
