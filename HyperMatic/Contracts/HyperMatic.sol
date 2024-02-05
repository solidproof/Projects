// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HyperMatic is Ownable {
	using SafeMath for uint256;

	struct TPlan {
		uint256 durationDays;
		uint256 percent;
		uint256 taxPercentMarketing;
		uint256 taxPercentContract;
		uint256 taxPercentInsurance;
		uint256 taxPercentCommission;
	}

	struct TDeposit {
		uint256 planIdx;
		uint256 amount;
		uint256 timeStart;
		uint256 timeEnd;
		uint256 percent;
		uint256 profit;
		uint256 checkpoint;
		uint256 depositIdx;
		bool isDeceased;
		bool isReinvest;
	}

	struct TUser {
		TDeposit[] deposits;
		uint256[3] refCount;
		address referrer;
		uint256 refDividends;
		uint256 totalInvested;
		uint256 totalRefDividends;
		uint256 totalRefDividendsClaimed;
		uint256 totalClaimed;
	}

	mapping( address => TUser ) public users;
	TPlan[] public plans;

	address payable private _bananaWallet;
	address payable private _orangeWallet;
	address payable private _mangoWallet;
	address payable private _kiwiWallet;
	address payable private _grapeWallet;
	address payable private _watermelonWallet;
	address payable private _appleWallet;

	uint256 public constant FORCE_WITHDRAW_TAX_PERCENT = 400; 	// force withdraw tax 40%
	uint256 public constant DEPOSIT_TAX_PERCENT = 100; 			// 10 % deposit tax
	uint256 public constant USER_REF_TAX_PERCENT = 200; 		// 20 % user ref deviden tax
	uint256 public constant PERCENTS_DIVIDER = 1000;
	uint256 public constant TIME_STEP = 1 days;
	uint256 public constant INVEST_MIN_AMOUNT = 0.01 ether;		// 0.01 Avax
	uint256 public constant REINVEST_PERCENT = 20;				// get 2% extra daily ROI

	uint256 public constant CLAIM_PERCENTAGE_MARKETING = 30;	// 3%
	uint256 public constant CLAIM_PERCENTAGE_CONTRACT = 40;		// 4%
	uint256 public constant CLAIM_PERCENTAGE_INSURANCE = 30;	// 3%
	uint256 public constant CLAIM_PERCENTAGE_COMMISSION = 100;	// 10%

	uint256[] public REFERRAL_PERCENTS	= [70, 30, 20];	        // 7% 3% 2%

	uint256 public totalDepositNo;
	uint256 public totalInvested;
	uint256 public totalRefDividends;
	uint256 public totalRefDividendsClaimed;
	uint256 public totalClaimed;

    bool public launched;

	event Claimed(address user, uint256 amount);
	event NewDeposit(address user, uint256 planIdx, uint256 amount);

	constructor(
        address payable bananaWallet_,
		address payable appleWallet_,
		address payable orangeWallet_,
		address payable grapeWallet_,
		address payable mangoWallet_,
		address payable watermelonWallet_,
		address payable kiwiWallet_
	)
	{
		require(bananaWallet_ != address(0), "HyperMatic::Banana wallet is zero");
		require(appleWallet_ != address(0), "HyperMatic::Apple wallet is zero");
		require(orangeWallet_ != address(0), "HyperMatic::Orange wallet is zero");
		require(grapeWallet_ != address(0), "HyperMatic::Grape wallet is zero");
		require(mangoWallet_ != address(0), "HyperMatic::Mango wallet is zero");
		require(watermelonWallet_ != address(0), "HyperMatic::Watermelon wallet is zero");
		require(kiwiWallet_ != address(0), "HyperMatic::Kiwi wallet is zero");

        _bananaWallet = bananaWallet_;
		_appleWallet = appleWallet_;
		_orangeWallet = orangeWallet_;
		_grapeWallet = grapeWallet_;
		_mangoWallet = mangoWallet_;
		_watermelonWallet = watermelonWallet_;
		_kiwiWallet = kiwiWallet_;

		plans.push( TPlan(7, 190, 30, 40, 30, 100) );
		plans.push( TPlan(14, 120, 30, 40, 30, 100) );
		plans.push( TPlan(21, 120, 30, 40, 30, 100) );
		plans.push( TPlan(28, 120, 30, 40, 30, 100) );

		plans.push( TPlan(7, 140, 30, 40, 30, 100) );
		plans.push( TPlan(14, 100, 10, 30, 10, 100) );
		plans.push( TPlan(21, 90, 10, 10, 10, 100) );
		plans.push( TPlan(28, 90, 0, 0, 10, 100) );

	}

	function setWallets(
		address payable bananaWallet_,
		address payable appleWallet_,
		address payable orangeWallet_,
		address payable grapeWallet_,
		address payable mangoWallet_,
		address payable watermelonWallet_,
		address payable kiwiWallet_
	)
		external
		onlyOwner()
	{
		require(bananaWallet_ != address(0), "HyperMatic::Banana wallet is zero");
		require(appleWallet_ != address(0), "HyperMatic::Apple wallet is zero");
		require(orangeWallet_ != address(0), "HyperMatic::Orange wallet is zero");
		require(grapeWallet_ != address(0), "HyperMatic::Grape wallet is zero");
		require(mangoWallet_ != address(0), "HyperMatic::Mango wallet is zero");
		require(watermelonWallet_ != address(0), "HyperMatic::Watermelon wallet is zero");
		require(kiwiWallet_ != address(0), "HyperMatic::Kiwi wallet is zero");

        _bananaWallet = bananaWallet_;
		_appleWallet = appleWallet_;
		_orangeWallet = orangeWallet_;
		_grapeWallet = grapeWallet_;
		_mangoWallet = mangoWallet_;
		_watermelonWallet = watermelonWallet_;
		_kiwiWallet = kiwiWallet_;
	}

	function launch()
		external
		onlyOwner()
	{
		launched = true;
	}

	function invest(address _referrer, uint8 _planIdx)
		public
		payable
	{
        require (launched, "HyperMatic::Project is not launched.");
        require(msg.value >= INVEST_MIN_AMOUNT, "HyperMatic::The deposit amount is too low");
        require(_planIdx < plans.length, "HyperMatic::Invalid plan index");

		_transferTo(msg.value, DEPOSIT_TAX_PERCENT, _grapeWallet);

        _setUserReferrer(msg.sender, _referrer);

        _allocateReferralRewards(msg.sender, msg.value);

        _createDeposit( msg.sender, _planIdx, msg.value, false, 0);

	}

	function withdraw(uint256 depIdx)
		public
	{
		TUser storage user = users[msg.sender];

		_checkDepositIsDeceased(user, depIdx);

		(uint256 claimAmount, uint256 checkPoint) = _calculateDepositDividends(msg.sender, depIdx);

		require(claimAmount > 0, "HyperMatic::Nothing to withdraw");
		require(checkPoint > 0, "HyperMatic::Not able to withdraw");

		updateCheckPoint(msg.sender, depIdx, checkPoint);

		TPlan storage plan = plans[user.deposits[depIdx].planIdx];

		// Transfer to wallets
		uint256 marketingAmount = _transferTo(claimAmount, plan.taxPercentMarketing, _bananaWallet);
		uint256 contractAmount = _transferTo(claimAmount, plan.taxPercentContract, _kiwiWallet);
		uint256 insuranceAmount = _transferTo(claimAmount, plan.taxPercentInsurance, _appleWallet);
		uint256 commissionAmount = _transferTo(claimAmount, plan.taxPercentCommission, _orangeWallet);

		claimAmount -= marketingAmount;
		claimAmount -= contractAmount;
		claimAmount -= insuranceAmount;
		claimAmount -= commissionAmount;

		uint256 balance = address(this).balance;
		if (claimAmount > balance) {
			claimAmount = balance;
		}

		user.totalClaimed += claimAmount;
		totalClaimed += claimAmount;
		payable(msg.sender).transfer( claimAmount );

		emit Claimed(msg.sender, claimAmount );
	}

	function _transferTo(uint256 claimAmount, uint256 percentage, address payable to_)
		internal
		returns(uint256 amount)
	{
		amount = claimAmount * percentage / PERCENTS_DIVIDER;
		to_.transfer(amount);
	}

	function updateCheckPoint(address addr, uint256 deptId, uint256 checkPoint)
		internal
	{
		TUser storage user = users[addr];

		user.deposits[deptId].checkpoint = checkPoint;

		if(checkPoint >= user.deposits[deptId].timeEnd)
			user.deposits[deptId].isDeceased = true;
	}

	function forceWithdraw(uint256 depIdx)
		public
	{
		TUser storage user = users[msg.sender];

		uint256 planIdx = user.deposits[depIdx].planIdx;

		_checkIsOnlyLockedPackageOperation(planIdx);
		_checkDepositIsDeceased(user, depIdx);

		uint256 depositAmount = user.deposits[depIdx].amount;
		uint256 forceWithdrawTax = _transferTo(depositAmount, FORCE_WITHDRAW_TAX_PERCENT, _mangoWallet);

		user.deposits[depIdx].checkpoint = user.deposits[depIdx].timeEnd;
		user.deposits[depIdx].isDeceased = true;

		uint256 claimAmount = depositAmount - forceWithdrawTax;

		uint256 balance = address(this).balance;
		if (claimAmount > balance) {
			claimAmount = balance;
		}

		user.totalClaimed += claimAmount;
		totalClaimed += claimAmount;

		payable(msg.sender).transfer( claimAmount);

		emit Claimed(msg.sender, claimAmount);
	}

	function reinvest(uint256 depIdx, uint256 reinvestAmount)
		public
	{
		TUser storage user = users[msg.sender];

		uint256 planIdx = user.deposits[depIdx].planIdx;

		_checkIsOnlyLockedPackageOperation(planIdx);
		_checkDepositIsDeceased(user, depIdx);

		(uint256 profit, uint256 checkPoint) = _calculateDepositDividends(msg.sender, depIdx);

		require(profit > 0, "Nothing to withdraw or reinvest");
		require(checkPoint > 0, "Not able to withdraw or reinvest");

		uint256 half = profit / 2;
		require(reinvestAmount >= half, "You need more MATIC for re-invest");

		updateCheckPoint(msg.sender, depIdx, checkPoint);

		_createDeposit( msg.sender, planIdx, reinvestAmount, true,  depIdx);

		//withdraw the rest
		uint256 claimAmount = profit - reinvestAmount;

		TPlan storage plan = plans[user.deposits[depIdx].planIdx];


		// Transfer to wallets
		uint256 marketingAmount = _transferTo(claimAmount, plan.taxPercentMarketing, _bananaWallet);
		uint256 contractAmount = _transferTo(claimAmount, plan.taxPercentContract, _kiwiWallet);
		uint256 insuranceAmount = _transferTo(claimAmount, plan.taxPercentInsurance, _appleWallet);
		uint256 commissionAmount = _transferTo(claimAmount, plan.taxPercentCommission, _orangeWallet);

		claimAmount -= marketingAmount;
		claimAmount -= contractAmount;
		claimAmount -= insuranceAmount;
		claimAmount -= commissionAmount;

		uint256 balance = address(this).balance;
		if (claimAmount > balance) {
			claimAmount = balance;
		}

		user.totalClaimed += claimAmount;
		totalClaimed += claimAmount;

		payable(msg.sender).transfer(claimAmount);

		emit Claimed(msg.sender, claimAmount);
	}

	function claim()
		public
	{
		TUser storage user = users[msg.sender];

		uint userRefDividends_ = user.refDividends;
		user.refDividends = 0;	//clear refDividends

		uint256 userRefDividendsTax = _transferTo(userRefDividends_, USER_REF_TAX_PERCENT, _watermelonWallet);
		uint256 userRefDividends = userRefDividends_ - userRefDividendsTax;

		user.totalRefDividendsClaimed += userRefDividends_;
		totalRefDividendsClaimed += userRefDividends_;

		uint256 claimAmount = userRefDividends;

		for(uint256 i=0; i<user.deposits.length; i++) {
			if(_isDepositDeceased(user, i)) continue;
			if(user.deposits[i].planIdx >= 4) continue;

			(uint256 claimAmount_, uint256 checkpoint_) = _calculateDepositDividends(msg.sender,i);

			if(claimAmount_ <= 0) continue;
			if(checkpoint_ <= 0) continue;

			updateCheckPoint(msg.sender, i, checkpoint_);
			claimAmount += claimAmount_;
		}

		uint256 marketingAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_MARKETING, _bananaWallet);
		uint256 contractAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_CONTRACT, _kiwiWallet);
		uint256 insuranceAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_INSURANCE, _appleWallet);
		uint256 commissionAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_COMMISSION, _orangeWallet);

		claimAmount -= marketingAmount;
		claimAmount -= contractAmount;
		claimAmount -= insuranceAmount;
		claimAmount -= commissionAmount;

		uint256 balance = address(this).balance;
		if (claimAmount > balance) {
			claimAmount = balance;
		}

		user.totalClaimed += claimAmount;
		totalClaimed += claimAmount;
		payable(msg.sender).transfer( claimAmount );

		emit Claimed(msg.sender, claimAmount );

	}

	function _setUserReferrer(address _user, address _referrer)
		internal
	{
		if (users[_user].referrer != address(0)) return; 		// Already has a referrer
		if (users[_referrer].deposits.length == 0) return;		// Referrer doesn't exist
		if (_user == _referrer) return;						  //cant refer to yourself

		// Adopt
		users[_user].referrer = _referrer;

		// Loop through the referrer hierarchy, increase every referral Levels counter
		address upline = users[_user].referrer;

		for (uint256 i=0; i < REFERRAL_PERCENTS.length; i++) {
			if(upline == address(0)) break;

			users[upline].refCount[i]++;
			upline = users[upline].referrer;
		}

	}

	function _allocateReferralRewards(address _user, uint256 _depositAmount)
		internal
	{
		//loop through the referrer hierarchy, allocate refDividends
		address upline = users[_user].referrer;

		for (uint256 i=0; i < REFERRAL_PERCENTS.length; i++) {
			if (upline == address(0)) break;

			uint256 amount = _depositAmount * REFERRAL_PERCENTS[i] / PERCENTS_DIVIDER;

			users[upline].refDividends += amount;
			users[upline].totalRefDividends += amount;
			totalRefDividends += amount;
			upline = users[upline].referrer;
		}
	}

	function _createDeposit(
		address _user,
		uint256 _planIdx,
		uint256 _amount,
		bool _isReinvest,
		uint256 reinvestedDepIdx
	)
		internal
		returns(uint256 o_depIdx)
	{

		TUser storage user = users[_user];

		TDeposit memory newDep;

		(uint256 percent, uint256 profit) = _getResult(_planIdx, _amount, _isReinvest);

		if(!_isReinvest){
			o_depIdx = user.deposits.length;
			newDep = TDeposit(
				_planIdx,
				_amount,
				block.timestamp,
				block.timestamp + plans[_planIdx].durationDays * TIME_STEP,
				percent,
				profit,
				block.timestamp,
				o_depIdx,
				false,
				_isReinvest
			);
			user.deposits.push(newDep);
		}else{
			o_depIdx = reinvestedDepIdx;
			newDep = TDeposit(
				_planIdx,
				_amount,
				block.timestamp,
				block.timestamp + plans[_planIdx].durationDays * TIME_STEP,
				percent,
				profit,
				block.timestamp,
				o_depIdx,
				false,
				_isReinvest
			);
			user.deposits[reinvestedDepIdx] = newDep;
		}

		user.totalInvested += _amount;
		totalDepositNo++;
		totalInvested += _amount;

		emit NewDeposit(_user, newDep.planIdx, newDep.amount);
	}

	function _getResult(uint256 planIdx, uint256 amount, bool _isReinvest) internal view returns (uint256 percent, uint256 profit){
		percent = plans[planIdx].percent;

		if(_isReinvest)
			percent = percent + REINVEST_PERCENT;

		if (planIdx < 4) {
			profit = amount.mul(percent).mul(plans[planIdx].durationDays).div(PERCENTS_DIVIDER);
		} else {
            uint256 s1 = (percent + PERCENTS_DIVIDER) / 10;
			uint256 s2 = PERCENTS_DIVIDER / 10;
			uint256 t1 = 1;
            uint256 t2 = 1;

			for (uint256 i = 0; i < plans[planIdx].durationDays; i++) {
				t1 = t1 * s1;
                t2 = t2 * s2;
			}

			profit = amount * t1 / t2 - amount;
		}
	}

	function _isDepositDeceased(TUser memory user_, uint256 depositIndex) internal pure returns(bool) {
		TDeposit memory userDeposits = user_.deposits[depositIndex];

		return (userDeposits.checkpoint >= userDeposits.timeEnd);
	}

	function _checkDepositIsDeceased(TUser memory user_, uint256 depositIndex)
		internal
		pure
	{
		require(!_isDepositDeceased(user_, depositIndex) , "Deposit is deceased");
	}

	function _calculateDepositDividends(address _user, uint256 _depIdx) internal view returns (uint256 o_amount, uint256 checkPoint) {
		TUser storage user = users[_user];
		TDeposit storage deposit = user.deposits[_depIdx];

		if(deposit.planIdx < 4) {
			//calculate withdrawable dividends starting from the last Claim checkpoint
			uint256 timeA = deposit.timeStart > deposit.checkpoint ? deposit.timeStart : deposit.checkpoint;
			uint256 timeB = deposit.timeEnd < block.timestamp ? deposit.timeEnd : block.timestamp;

			if (timeA < timeB) {
				uint256 daycounts = plans[deposit.planIdx].durationDays;
				o_amount = deposit.profit.mul((timeB-timeA) / TIME_STEP).div(daycounts);
				checkPoint = timeB; ///deposit.checkpoint = timeB;
			}
		}else {
			// Only locked packages
			if(deposit.timeEnd <= block.timestamp){
				o_amount = deposit.profit;
				checkPoint = deposit.timeEnd; ///deposit.checkpoint = deposit.timeEnd;
			}
		}
	}

	function _checkIsOnlyLockedPackageOperation(uint256 index_)
		internal
		pure
	{
		require(index_ >= 4, "HyperMatic::Only locked packages");
	}

	function getPercentageOfPackages()
		public
		view
		returns(uint256[] memory)
	{
		uint256[] memory percentages;

		for(uint256 i; i < plans.length; i++) {
			TPlan memory plan = plans[i];
			percentages[i] = plan.percent;
		}

		return percentages;
	}

	function getPackageInfo(uint256 index_)
		public
		view
		returns(TPlan memory)
	{
		return plans[index_];
	}

	function getProjectInfo()
		public
		view
		returns(
			uint256 o_totDeposits,
			uint256 o_totInvested,
			uint256 o_insBalance,
			uint256 contractBalance,
			uint256 o_timestamp
		)
	{
		uint256 insuranceBalance = _appleWallet.balance;
		return( totalDepositNo, totalInvested, insuranceBalance, address(this).balance, block.timestamp );
	}

	function getUserDeposits()
		public
		view
		returns(TDeposit[] memory)
	{
		TUser storage user = users[msg.sender];

		return user.deposits;
	}

	function getUserInfo()
		public
		view
		returns(
			uint256 stakedAmount,
			uint256 availableAmount,
			uint256 tot_ref,
			uint256 tot_ref_earn
		)
	{
		TUser storage user = users[msg.sender];

		tot_ref = user.totalRefDividends;
		tot_ref_earn = user.totalRefDividendsClaimed;

		stakedAmount = user.totalInvested;

		uint256 claimAmount = user.refDividends;

		for(uint256 i=0;i<user.deposits.length;i++) {
			if(_isDepositDeceased(user,i)) continue;
			if(user.deposits[i].planIdx >= 4) continue;

			(uint256 claimAmount_, uint256 checkpoint_) = _calculateDepositDividends(msg.sender,i);

			if(claimAmount_ <= 0) continue;
			if(checkpoint_ <= 0) continue;

			claimAmount += claimAmount_;
		}

		availableAmount = claimAmount;
	}

	function getCurrentTime() public view returns(uint256){
		return block.timestamp;
	}

	function getContractBalance()
		public
		view
		returns(uint256)
	{
		uint256 insuranceBalance = _appleWallet.balance;

		return address(this).balance + insuranceBalance;
	}

	receive() external payable {}
}