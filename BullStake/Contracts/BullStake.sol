// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BullStake is Ownable {
	using SafeMath for uint256;

	struct TPlan {
		uint256 durationDays;
		uint256 percent;
		uint256 taxPercentMarketing;
		uint256 taxPercentContract;
		uint256 taxPercentGa;
		uint256 taxPercentCommission;
		uint256 investFactor;
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

	address payable private _marketingWallet;
	address payable private _comissionWallet;
	address payable private _forcewithdrawalWallet;
	address payable private _cbWallet;
	address payable private _tenpercentWallet;
	address payable private _twentypercentWallet;
	address payable private _gaWallet;

	uint256 public constant DEPOSIT_TAX_PERCENT = 100; 			// 10 % deposit tax
	uint256 public constant USER_REF_TAX_PERCENT = 200; 		// 20 % user ref deviden tax
	uint256 public constant PERCENTS_DIVIDER = 1000;
	uint256 public constant TIME_STEP = 1 days;
	uint256 public constant INVEST_MIN_AMOUNT = 0.01 ether;		// 0.01 Avax
	uint256 public constant REINVEST_PERCENT = 350;				// get 35% extra daily ROI

	uint256 public constant CLAIM_PERCENTAGE_MARKETING = 30;	// 3%
	uint256 public constant CLAIM_PERCENTAGE_CONTRACT = 40;		// 4%
	uint256 public constant CLAIM_PERCENTAGE_GA = 30;	// 3%
	uint256 public constant CLAIM_PERCENTAGE_COMMISSION = 100;	// 10%

	uint256[] public REFERRAL_PERCENTS	= [50, 1, 1];	        // 5% 0.1% 0.1%
	uint256 public forcewithdrawalWalletClaimedAmount;
	uint256 public forceWithdrawPercent = 400; 	// force withdraw tax 40%
	uint256 public forcewithdrawalWithdrawTaxPercent = 500; 	// forcewithdrawal withdraw tax percent
	uint256 public totalDepositNo;
	uint256 public totalInvested;
	uint256 public totalRefDividends;
	uint256 public totalRefDividendsClaimed;
	uint256 public totalClaimed;

    bool public launched;
    bool public reinvestAllowed;
    bool public newReferralsAllowed;

	event UpdateReinvestAllowedStatus(bool isAllowed);
	event UpdateNewReferralsAllowedStatus(bool isAllowed);
	event Claimed(address user, uint256 amount);
	event NewDeposit(address user, uint256 planIdx, uint256 amount);
	event ForceWithdrawPercentUpdated(uint256 oldValue, uint256 newValue);
	event ForceWithdrawalWithdrawTaxPercentUpdated(uint256 oldValue, uint256 newValue);

	constructor(
        address payable marketingWallet_,
		address payable gaWallet_,
		address payable comissionWallet_,
		address payable tenpercentWallet_,
		address payable forcewithdrawalWallet_,
		address payable twentypercentWallet_,
		address payable cbWallet_
	)
	{
		require(marketingWallet_ != address(0), "BullStake::Marketing wallet is zero");
		require(gaWallet_ != address(0), "BullStake::ga wallet is zero");
		require(comissionWallet_ != address(0), "BullStake::Comission wallet is zero");
		require(tenpercentWallet_ != address(0), "BullStake::Tenpercent wallet is zero");
		require(forcewithdrawalWallet_ != address(0), "BullStake::Forcewithdrawal wallet is zero");
		require(twentypercentWallet_ != address(0), "BullStake::Twentypercent wallet is zero");
		require(cbWallet_ != address(0), "BullStake::Cb wallet is zero");

        _marketingWallet = marketingWallet_;
		_gaWallet = gaWallet_;
		_comissionWallet = comissionWallet_;
		_tenpercentWallet = tenpercentWallet_;
		_forcewithdrawalWallet = forcewithdrawalWallet_;
		_twentypercentWallet = twentypercentWallet_;
		_cbWallet = cbWallet_;

		plans.push( TPlan(7, 0, 30, 30, 40, 100, 0) );
		plans.push( TPlan(10, 0, 30, 30, 40, 100, 1300) );
		plans.push( TPlan(20, 0, 30, 30, 40, 100, 2000) );
		plans.push( TPlan(30, 0, 30, 30, 40, 100, 2520) );

		plans.push( TPlan(7, 0, 30, 40, 30, 100, 0) );
		plans.push( TPlan(10, 0, 30, 30, 40, 100, 1590) );
		plans.push( TPlan(20, 0, 10, 10, 10, 100, 3660) );
		plans.push( TPlan(30, 0, 0, 0, 10, 100, 9062) );

	newReferralsAllowed = true;
	}

	function setWallets(
		address payable marketingWallet_,
		address payable gaWallet_,
		address payable comissionWallet_,
		address payable tenpercentWallet_,
		address payable forcewithdrawalWallet_,
		address payable twentypercentWallet_,
		address payable cbWallet_
	)
		external
		onlyOwner()
	{
		require(marketingWallet_ != address(0), "BullStake::Marketing wallet is zero");
		require(gaWallet_ != address(0), "BullStake::ga wallet is zero");
		require(comissionWallet_ != address(0), "BullStake::Comission wallet is zero");
		require(tenpercentWallet_ != address(0), "BullStake::Tenpercent wallet is zero");
		require(forcewithdrawalWallet_ != address(0), "BullStake::Forcewithdrawal wallet is zero");
		require(twentypercentWallet_ != address(0), "BullStake::Twentypercent wallet is zero");
		require(cbWallet_ != address(0), "BullStake::CB wallet is zero");

        _marketingWallet = marketingWallet_;
		_gaWallet = gaWallet_;
		_comissionWallet = comissionWallet_;
		_tenpercentWallet = tenpercentWallet_;
		_forcewithdrawalWallet = forcewithdrawalWallet_;
		_twentypercentWallet = twentypercentWallet_;
		_cbWallet = cbWallet_;
	}

	function setReinvestAllowedStatus(bool status)
		external
		onlyOwner()
	{
		reinvestAllowed = status;
		emit UpdateReinvestAllowedStatus(status);
	}

	function setNewReferralAllowedStatus(bool status)
		external
		onlyOwner()
	{
		newReferralsAllowed = status;
		emit UpdateNewReferralsAllowedStatus(status);
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
        require (launched, "BullStake::Project is not launched.");
        require(msg.value >= INVEST_MIN_AMOUNT, "BullStake::The deposit amount is too low");
        require(_planIdx < plans.length, "BullStake::Invalid plan index");

		_transferTo(msg.value, DEPOSIT_TAX_PERCENT, _tenpercentWallet);

		if(newReferralsAllowed)
			_setUserReferrer(msg.sender, _referrer);

        _allocateReferralRewards(msg.sender, msg.value);

        _createDeposit( msg.sender, _planIdx, msg.value, false, 0);

	}

	function withdraw(uint256 depIdx)
		public
	{
		TUser storage user = users[msg.sender];

		_checkDepositIsDeceased(user, depIdx);

		(uint256 claimAmount, uint256 checkPoint) = _calculateDepositDividends(msg.sender, depIdx, true);

		require(claimAmount > 0, "BullStake::Nothing to withdraw");
		require(checkPoint > 0, "BullStake::Not able to withdraw");

		updateCheckPoint(msg.sender, depIdx, checkPoint);

		TPlan storage plan = plans[user.deposits[depIdx].planIdx];

		// Transfer to wallets
		uint256 marketingAmount = _transferTo(claimAmount, plan.taxPercentMarketing, _marketingWallet);
		uint256 contractAmount = _transferTo(claimAmount, plan.taxPercentContract, _cbWallet);
		uint256 gaAmount = _transferTo(claimAmount, plan.taxPercentGa, _gaWallet);
		uint256 commissionAmount = _transferTo(claimAmount, plan.taxPercentCommission, _comissionWallet);

		claimAmount -= marketingAmount;
		claimAmount -= contractAmount;
		claimAmount -= gaAmount;
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

	function _transferToForcewithdrawal(uint256 claimAmount, uint256 percentage, address payable to_)
		internal
		returns(uint256 amount)
	{

		amount = claimAmount * percentage / PERCENTS_DIVIDER;

		uint256 forcewithdrawalAmount = amount * forcewithdrawalWithdrawTaxPercent / PERCENTS_DIVIDER;
		forcewithdrawalWalletClaimedAmount += forcewithdrawalAmount;
		to_.transfer(forcewithdrawalAmount);
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
		uint256 forceWithdrawTax = _transferToForcewithdrawal(depositAmount, forceWithdrawPercent, _forcewithdrawalWallet);

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
		require(reinvestAllowed, "BullStake::Reinvest is deactivated");

		TUser storage user = users[msg.sender];
		uint256 planIdx = user.deposits[depIdx].planIdx;

		require(!user.deposits[depIdx].isReinvest, "BullStake::You can reinvest only once");

		_checkIsOnlyLockedPackageOperation(planIdx);
		_checkDepositIsDeceased(user, depIdx);

		(uint256 profit, uint256 checkPoint) = _calculateDepositDividends(msg.sender, depIdx, true);

		require(profit > 0, "Nothing to withdraw or reinvest");
		require(profit >= reinvestAmount, "BullStake::Profit must be higher than reinvest.");
		require(checkPoint > 0, "Not able to withdraw or reinvest");

		uint256 half = profit.div(100) / 2;
		require(reinvestAmount >= half, "You need more MATIC for re-invest");

		updateCheckPoint(msg.sender, depIdx, checkPoint);

		_createDeposit( msg.sender, planIdx, reinvestAmount, true,  depIdx);

		uint256 withdrawAmount = profit - reinvestAmount;

		//withdraw the rest
		TPlan storage plan = plans[user.deposits[depIdx].planIdx];

		// Transfer to wallets
		uint256 marketingAmount = _transferTo(withdrawAmount, plan.taxPercentMarketing, _marketingWallet);
		uint256 contractAmount = _transferTo(withdrawAmount, plan.taxPercentContract, _cbWallet);
		uint256 gaAmount = _transferTo(withdrawAmount, plan.taxPercentGa, _gaWallet);
		uint256 commissionAmount = _transferTo(withdrawAmount, plan.taxPercentCommission, _comissionWallet);

		withdrawAmount -= marketingAmount;
		withdrawAmount -= contractAmount;
		withdrawAmount -= gaAmount;
		withdrawAmount -= commissionAmount;

		uint256 balance = address(this).balance;
		if (withdrawAmount > balance) {
			withdrawAmount = balance;
		}

		user.totalClaimed += withdrawAmount;
		totalClaimed += withdrawAmount;

		payable(msg.sender).transfer(withdrawAmount);

		emit Claimed(msg.sender, withdrawAmount);
	}

	function claim()
		public
	{
		TUser storage user = users[msg.sender];

		uint256 userRefDividendsTax = _transferTo(user.refDividends, USER_REF_TAX_PERCENT, _twentypercentWallet);
		uint256 userRefDividends = user.refDividends - userRefDividendsTax;

		user.totalRefDividendsClaimed += user.refDividends;
		totalRefDividendsClaimed += user.refDividends;

		user.refDividends = 0;				//clear refDividends
		uint256 claimAmount = userRefDividends;

		for(uint256 i=0; i<user.deposits.length; i++) {
			if(_isDepositDeceased(user, i)) continue;
			if(user.deposits[i].planIdx >= 4) continue;

			(uint256 claimAmount_, uint256 checkpoint_) = _calculateDepositDividends(msg.sender,i, false);

			if(claimAmount_ <= 0) continue;
			if(checkpoint_ <= 0) continue;

			updateCheckPoint(msg.sender, i, checkpoint_);
			claimAmount += claimAmount_;
		}

		uint256 marketingAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_MARKETING, _marketingWallet);
		uint256 contractAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_CONTRACT, _cbWallet);
		uint256 gaAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_GA, _gaWallet);
		uint256 commissionAmount =_transferTo(claimAmount, CLAIM_PERCENTAGE_COMMISSION, _comissionWallet);

		claimAmount -= marketingAmount;
		claimAmount -= contractAmount;
		claimAmount -= gaAmount;
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

	function _calculateDepositDividends(address _user, uint256 _depIdx, bool _isWithdraw) internal view returns (uint256 o_amount, uint256 checkPoint) {
		TUser storage user = users[_user];
		if(!_isDepositDeceased(user, _depIdx)) {
			TDeposit storage deposit = user.deposits[_depIdx];

			if(deposit.planIdx < 4) {
				//calculate withdrawable dividends starting from the last Claim checkpoint
				uint256 timeA = deposit.timeStart > deposit.checkpoint ? deposit.timeStart : deposit.checkpoint;
				uint256 timeB = deposit.timeEnd < block.timestamp ? deposit.timeEnd : block.timestamp;

				if (timeA < timeB) {
					uint256 dayCounts = plans[deposit.planIdx].durationDays;
					uint256 multiplier = timeB.sub(timeA);

					if(multiplier < TIME_STEP) {
						o_amount = (deposit.profit.mul(
							multiplier
						).div(dayCounts)).div(TIME_STEP);
					} else {
						o_amount = deposit.profit.mul(
							multiplier.div(TIME_STEP)
						).div(dayCounts);
					}

					checkPoint = timeB; ///deposit.checkpoint = timeB;
				}
			}else {
				// Only locked packages
				if(deposit.timeEnd <= block.timestamp){
					uint256 divideBy = _isWithdraw ? 1 : 1000;
					o_amount = deposit.profit / divideBy;
					checkPoint = deposit.timeEnd; ///deposit.checkpoint = deposit.timeEnd;
				}
			}
		}
	}

	function _checkIsOnlyLockedPackageOperation(uint256 index_)
		internal
		pure
	{
		require(index_ >= 4, "BullStake::Only locked packages");
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
		uint256 gaBalance = _gaWallet.balance;
		return( totalDepositNo, totalInvested, gaBalance, address(this).balance, block.timestamp );
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

			(uint256 claimAmount_, uint256 checkpoint_) = _calculateDepositDividends(msg.sender,i, false);

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
		uint256 gaBalance = _gaWallet.balance;

		return address(this).balance + gaBalance;
	}

	function setForceWithdrawPercent(uint256 percent)
		public
		onlyOwner()
	{
		require(110 <= percent && percent <= 400, "New percent must be between 11% - 40%");
		uint256 old = forceWithdrawPercent;
		forceWithdrawPercent = percent;
		emit ForceWithdrawPercentUpdated(old, percent);
	}

	function setForcewithdrawalWithdrawPercent(uint256 percent)
		public
		onlyOwner()
	{
		require(100 <= percent && percent <= 500, "New percent must be between 10% - 50%");
		uint256 old = forcewithdrawalWithdrawTaxPercent;
		forcewithdrawalWithdrawTaxPercent = percent;
		emit ForceWithdrawalWithdrawTaxPercentUpdated(old, percent);
	}

	receive() external payable {}

	function _getResult(
		uint256 planIdx,
		uint256 amount,
		bool _isReinvest
	)
		private
		view
		returns
		(
			uint256 percent,
			uint256 profit
		)
	{
		TPlan memory plan = plans[planIdx];

		uint256 factor = plan.investFactor;

		if(planIdx >= 4) {
			if(_isReinvest)
				factor = factor.mul(
					REINVEST_PERCENT.add(PERCENTS_DIVIDER)
				);
		}

		profit = amount.div(PERCENTS_DIVIDER).mul(factor);
	}
}