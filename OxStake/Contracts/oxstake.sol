/**
 *Submitted for verification at FtmScan.com on 2022-04-24
*/

// SPDX-License-Identifier: MIT

 /*


 *   [USAGE INSTRUCTION]
 *
 *   1) Connect browser extension Metamask (see help: https://academy.binance.com/en/articles/how-to-add-polygon-to-metamask)
 *   2) Choose one of the tariff plans, enter the MATIC amount (10 MATIC minimum) using our website "Stake MATIC" button
 *   3) Wait for your earnings
 *   4) Withdraw earnings any time using our website "Withdraw" button
 *
 *   [INVESTMENT CONDITIONS]
 *
 *   - Basic interest rate: +2% every 24 hours - only for new deposits
 *   - Minimal deposit: 10 FTM, no maximal limit
 *   - Total income: based on your tarrif plan (from 8% to 10% daily!!!) + Basic interest rate !!!
 *   - Earnings every moment, withdraw any time (if you use capitalization of interest you can withdraw only after end of your deposit)
 *
 *   [AFFILIATE PROGRAM]
 *
 *   - 3-level referral commission: 7% - 3% - 1%
 *
 */

pragma solidity >=0.4.22 <0.9.0;

contract OxStake {
	using SafeMath for uint256;

	uint256 constant public INVEST_MIN_AMOUNT = 10 ether;
	uint256[] public REFERRAL_PERCENTS = [70, 30, 10];
	uint256 constant public PROJECT_FEE = 200;
    uint256 constant public MARKETING_FEE = 500;
	uint256 constant public PERCENT_STEP = 20;
	uint256 constant public WITHDRAW_FEE = 800; //In base point
	uint256 constant public PERCENTS_DIVIDER = 1000;
 	uint256 constant public TIME_STEP = 24 hours;

	uint256 public totalStaked;
	uint256 public totalRefBonus;
	uint256 public totalUsers;

    struct Plan {
        uint256 time;
        uint256 percent;
    }

    Plan[] internal plans;

	struct Deposit {
        uint8 plan;
		uint256 percent;
		uint256 amount;
		uint256 profit;
		uint256 start;
		uint256 finish;
	}

	struct User {
		Deposit[] deposits;
		uint256 checkpoint;
		address referrer;
		uint256[3] levels;
		uint256 bonus;
		uint256 totalBonus;
		uint256 totalWithdrawn;
	}

	mapping (address => User) internal users;

	uint256 public startUNIX;
    address payable public marketingWallet;
    address payable public projectWallet;

	event Newbie(address user);
	event NewDeposit(address indexed user, uint8 plan, uint256 percent, uint256 amount, uint256 profit, uint256 start, uint256 finish);
	event Withdrawn(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);
	event FeePayed(address indexed user, uint256 totalAmount);
    event GiveAwayBonus(address indexed user,uint256 amount);

	constructor(address payable marketing, address payable project, uint256 startDate)  {
		require(!isContract(project));
		require(startDate > 0);
        marketingWallet = marketing;
        projectWallet = project;

		startUNIX = startDate; // 1649703600 // Date and time (GMT): Monday, 4 April 2022 19:00:00

		plans.push(Plan(14, 100)); // 10% per day for 14 days
        plans.push(Plan(21, 90)); // 9% per day for 21 days
        plans.push(Plan(28, 85)); // 8.5% per day for 28 days
		plans.push(Plan(14, 110)); // 11% per day for 14 days (at the end)
        plans.push(Plan(21, 100)); // 10% per day for 21 days (at the end)
        plans.push(Plan(28, 90)); // 9% per day for 28 days (at the end)
	}

	function invest(address referrer, uint8 plan) public payable {
        require(block.timestamp > startUNIX, "We are not live yet!");
		require(msg.value >= INVEST_MIN_AMOUNT,"Invalid amount");
        require(plan < 6, "Invalid plan");

        //emit FeePayed(msg.sender, fee);

        uint256 marketingfee = msg.value.mul(MARKETING_FEE).div(PERCENTS_DIVIDER);
		marketingWallet.transfer(marketingfee);// MARKETING

		uint256 projectfee = msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER);
		projectWallet.transfer(projectfee); // PROJECT


		User storage user = users[msg.sender];

		if (user.referrer == address(0)) {
			if (referrer != msg.sender) {
				user.referrer = referrer;
			}

			address upline = user.referrer;
			for (uint256 i = 0; i < 3; i++) {
				if (upline != address(0)) {
					users[upline].levels[i] = users[upline].levels[i].add(1);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.referrer != address(0)) {

			address upline = user.referrer;
			for (uint256 i = 0; i < 3; i++) {
				if (upline != address(0)) {
					uint256 amount = msg.value.mul(REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER);
					users[upline].bonus = users[upline].bonus.add(amount);
					totalRefBonus = totalRefBonus.add(amount);
					users[upline].totalBonus = users[upline].totalBonus.add(amount);
					emit RefBonus(upline, msg.sender, i, amount);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.deposits.length == 0) {
			user.checkpoint = block.timestamp;
			totalUsers = totalUsers.add(1);
			emit Newbie(msg.sender);
		}

		(uint256 percent, uint256 profit, uint256 finish) = getResult(plan, msg.value);
		user.deposits.push(Deposit(plan, percent, msg.value, profit, block.timestamp, finish));

		totalStaked = totalStaked.add(msg.value);
		emit NewDeposit(msg.sender, plan, percent, msg.value, profit, block.timestamp, finish);
	}

	function withdraw() public {
		User storage user = users[msg.sender];

		uint256 totalAmount = getUserDividends(msg.sender);
		uint256 fees = totalAmount.mul(WITHDRAW_FEE).div(10000);
        totalAmount = totalAmount.sub(fees);

		uint256 referralBonus = getUserReferralBonus(msg.sender);
		if (referralBonus > 0) {
			user.bonus = 0;
			totalAmount = totalAmount.add(referralBonus);
		}

		require(totalAmount > 0, "User has no dividends");

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			totalAmount = contractBalance;
		}

		user.checkpoint = block.timestamp;

		payable(msg.sender).transfer(totalAmount);
		user.totalWithdrawn = user.totalWithdrawn.add(totalAmount);
		emit Withdrawn(msg.sender, totalAmount);

	}

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function getPlanInfo(uint8 plan) public view returns(uint256 time, uint256 percent) {
		time = plans[plan].time;
		percent = plans[plan].percent;
	}

		function getPercent(uint8 plan) public view returns (uint256) {
		if (block.timestamp > startUNIX) {
			return plans[plan].percent.add(PERCENT_STEP.mul(block.timestamp.sub(startUNIX)).div(TIME_STEP));
		} else {
			return plans[plan].percent;
		}
    }

	function getResult(uint8 plan, uint256 deposit) public view returns (uint256 percent, uint256 profit, uint256 finish) {
		percent = getPercent(plan);
			profit = deposit.mul(percent).div(PERCENTS_DIVIDER).mul(plans[plan].time);
		finish = block.timestamp.add(plans[plan].time.mul(TIME_STEP));
	}



	function getUserDividends(address userAddress) public view returns (uint256) {
		User storage user = users[userAddress];

		uint256 totalAmount;

		for (uint256 i = 0; i < user.deposits.length; i++) {
			if (user.checkpoint < user.deposits[i].finish) {
				if (user.deposits[i].plan < 3) {
					uint256 share = user.deposits[i].amount.mul(user.deposits[i].percent).div(PERCENTS_DIVIDER);
					uint256 from = user.deposits[i].start > user.checkpoint ? user.deposits[i].start : user.checkpoint;
					uint256 to = user.deposits[i].finish < block.timestamp ? user.deposits[i].finish : block.timestamp;
					if (from < to) {
						totalAmount = totalAmount.add(share.mul(to.sub(from)).div(TIME_STEP));
					}
				} else if (block.timestamp > user.deposits[i].finish) {
					totalAmount = totalAmount.add(user.deposits[i].profit);
				}
			}
		}

		return totalAmount;
	}

	 function getContractInfo() public view returns(uint256, uint256, uint256) {
        return(totalStaked, totalRefBonus, totalUsers);
    }

	function getUserCheckpoint(address userAddress) public view returns(uint256) {
		return users[userAddress].checkpoint;
	}

	function getUserReferrer(address userAddress) public view returns(address) {
		return users[userAddress].referrer;
	}

	function getUserDownlineCount(address userAddress) public view returns(uint256, uint256, uint256) {
		return (users[userAddress].levels[0],users[userAddress].levels[1],users[userAddress].levels[2]);
	}

	function getUserReferralBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].bonus;
	}


	function getUserReferralTotalBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus;
	}

	function getUserReferralWithdrawn(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus.sub(users[userAddress].bonus);
	}

	function getUserAvailable(address userAddress) public view returns(uint256) {
		return getUserReferralBonus(userAddress).add(getUserDividends(userAddress));
	}

	function getUserAmountOfDeposits(address userAddress) public view returns(uint256) {
		return users[userAddress].deposits.length;
	}

	function getUserTotalDeposits(address userAddress) public view returns(uint256 amount) {
		for (uint256 i = 0; i < users[userAddress].deposits.length; i++) {
			amount = amount.add(users[userAddress].deposits[i].amount);
		}
	}

	function gettotalWithdrawn(address userAddress) public view returns(uint256 amount)
	{
		return users[userAddress].totalWithdrawn;
	}

	function getUserDepositInfo(address userAddress, uint256 index) public view returns(uint8 plan, uint256 percent, uint256 amount, uint256 profit, uint256 start, uint256 finish) {
	    User storage user = users[userAddress];

		plan = user.deposits[index].plan;
		percent = user.deposits[index].percent;
		amount = user.deposits[index].amount;
		profit = user.deposits[index].profit;
		start = user.deposits[index].start;
		finish = user.deposits[index].finish;
	}

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}