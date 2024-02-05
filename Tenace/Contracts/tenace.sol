/**
 *Submitted for verification at BscScan.com on 2022-06-14
*/

//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

contract Tenace {
	using SafeMath for uint256;

	uint256 constant public INVEST_MIN_AMOUNT = 0.1 ether;
	uint256 constant public INVEST_MAX_AMOUNT = 150 ether;
	uint256 constant public MAX_DEPOSITS = 100;
	uint256 constant public BASE_PERCENT = 40;
	uint256[] public REFERRAL_PERCENTS = [250, 150, 100];
	uint256 constant public PROJECT_FEE = 60;
	uint256 constant public DEV_FEE = 40;
	uint256 constant public PERCENTS_DIVIDER = 1000;
	uint256 constant public PERCENTS_DIVIDER_REFERRAL = 10000;
    uint256 public constant withdraw_MAX_AMOUNT = 10 ether;
	uint256 constant public CONTRACT_BALANCE_STEP = 500 ether;
	uint256 constant public TIME_STEP = 1 days;

	uint256 public totalUsers;
	uint256 public totalInvested;
	uint256 public totalWithdrawn;
	uint256 public totalDeposits;
	uint256 public totalReferrals;

	address payable public devAddress;
	address payable public projectAddress;

	struct Deposit {
		uint256 amount;
		uint256 withdrawn;
		uint256 start;
	}

	struct User {
		Deposit[] deposits;
		uint256 checkpoint;
		address referrer;
		uint256 bonus;
		uint256 totalBonus;
		uint256 totalInvested;
		uint256[5] levels;
	}

	mapping (address => User) internal users;
	mapping (address => bool) internal antiWhale;

	uint256 public startUNIX;

	event Newbie(address user);
	event NewDeposit(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);

	constructor(address payable projectAddr, address payable devAddr, uint256 start) {
		require(!isContract(devAddr) && !isContract(projectAddr));
		projectAddress = projectAddr;
		devAddress = devAddr;

        if(start > 0){
            startUNIX = start;
        }
        else{
		    startUNIX = block.timestamp;
        }
	}

	function invest(address referrer) public payable {
		require(block.timestamp > startUNIX, "not luanched yet");
		require(!antiWhale[msg.sender],"AntiWhale limit");
		require(msg.value >= INVEST_MIN_AMOUNT);
		User storage user = users[msg.sender];
		require(user.deposits.length < MAX_DEPOSITS, "max deposits is 100");

		projectAddress.transfer(msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER));
		devAddress.transfer(msg.value.mul(DEV_FEE).div(PERCENTS_DIVIDER));


		if (user.referrer == address(0)) {
            if(users[referrer].deposits.length > 0 && referrer != msg.sender){
			    user.referrer = referrer;
            }
            else{
                user.referrer = projectAddress;
            }

			address upline = user.referrer;
			for (uint256 i = 0; i < 5; i++) {
				if (upline != address(0)) {
					users[upline].levels[i] = users[upline].levels[i].add(1);
					upline = users[upline].referrer;
				} else break;
			}
		}

		if (user.referrer != address(0)) {

			address upline = user.referrer;
			for (uint256 i = 0; i < 5; i++) {
				if (upline != address(0)) {
					uint256 amount = msg.value.mul(REFERRAL_PERCENTS[i]).div(PERCENTS_DIVIDER_REFERRAL);
					users[upline].bonus = users[upline].bonus.add(amount);
					users[upline].totalBonus = users[upline].totalBonus.add(amount);
					totalReferrals = totalReferrals.add(amount);
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

		user.deposits.push(Deposit(msg.value, 0, block.timestamp));

		user.totalInvested = user.totalInvested.add(msg.value);
		totalInvested = totalInvested.add(msg.value);
		totalDeposits = totalDeposits.add(1);

		emit NewDeposit(msg.sender, msg.value);

	}

	function withdraw() public {
		require(block.timestamp > startUNIX, "not luanched yet");
		require(!antiWhale[msg.sender],"AntiWhale limit");
		User storage user = users[msg.sender];

		uint256 userPercentRate = getUserPercentRate(msg.sender);

		uint256 totalAmount;
		uint256 dividends;

		for (uint256 i = 0; i < user.deposits.length; i++) {

			if (user.deposits[i].withdrawn < user.deposits[i].amount.mul(2)) {
				if (user.deposits[i].start > user.checkpoint) {
					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.deposits[i].start))
						.div(TIME_STEP);

				} else {
					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.checkpoint))
						.div(TIME_STEP);
				}

				if (user.deposits[i].withdrawn.add(dividends) > user.deposits[i].amount.mul(2)) {
					dividends = (user.deposits[i].amount.mul(2)).sub(user.deposits[i].withdrawn);
				}
				user.deposits[i].withdrawn = user.deposits[i].withdrawn.add(dividends);
				totalAmount = totalAmount.add(dividends);
			}
		}

		uint256 referralBonus = getUserReferralBonus(msg.sender);
		if (referralBonus > 0) {
			totalAmount = totalAmount.add(referralBonus);
			user.bonus = 0;
		}

		require(totalAmount > 0, "User has no dividends");

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			totalAmount = contractBalance;
		}

		user.checkpoint = block.timestamp;
		payable(msg.sender).transfer(totalAmount);
		totalWithdrawn = totalWithdrawn.add(totalAmount);
		emit Withdrawn(msg.sender, totalAmount);
	}

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function getContractBalanceRate() public view returns (uint256) {
		uint256 contractBalance = address(this).balance;
		uint256 contractBalancePercent = contractBalance.div(CONTRACT_BALANCE_STEP);
		return BASE_PERCENT.add(contractBalancePercent);
	}

	function getUserPercentRate(address userAddress) public view returns (uint256) {
		User storage user = users[userAddress];

		uint256 contractBalanceRate = getContractBalanceRate();
		if (isActive(userAddress)) {
			uint256 timeMultiplier = (block.timestamp.sub(user.checkpoint)).div(TIME_STEP);
			return contractBalanceRate.add(timeMultiplier);
		} else {
			return contractBalanceRate;
		}
	}

	function getUserDividends(address userAddress) public view returns (uint256) {
		User storage user = users[userAddress];

		uint256 userPercentRate = getUserPercentRate(userAddress);
		uint256 totalDividends;
		uint256 dividends;

		for (uint256 i = 0; i < user.deposits.length; i++) {
			if (user.deposits[i].withdrawn < user.deposits[i].amount.mul(2)) {
				if (user.deposits[i].start > user.checkpoint) {
					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.deposits[i].start))
						.div(TIME_STEP);
				} else {
					dividends = (user.deposits[i].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
						.mul(block.timestamp.sub(user.checkpoint))
						.div(TIME_STEP);
				}

				if (user.deposits[i].withdrawn.add(dividends) > user.deposits[i].amount.mul(2)) {
					dividends = (user.deposits[i].amount.mul(2)).sub(user.deposits[i].withdrawn);
				}
				totalDividends = totalDividends.add(dividends);
			}
		}

		return totalDividends;
	}

	function getUserCheckpoint(address userAddress) public view returns(uint256) {
		return users[userAddress].checkpoint;
	}

	function getUserReferrer(address userAddress) public view returns(address) {
		return users[userAddress].referrer;
	}

	function getUserReferralBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].bonus;
	}

	function getUserAvailable(address userAddress) public view returns(uint256) {
		return getUserReferralBonus(userAddress).add(getUserDividends(userAddress));
	}

	function isActive(address userAddress) public view returns (bool status) {
		User storage user = users[userAddress];
		if (user.deposits.length > 0) {
			if (user.deposits[user.deposits.length-1].withdrawn < user.deposits[user.deposits.length-1].amount.mul(2)) {
				status = true;
				return status;
			}
		}
	}

	function getUserDepositInfo(address userAddress, uint256 index) public view returns(uint256, uint256, uint256) {
	    User storage user = users[userAddress];
		uint256 dividends;
		uint256 userPercentRate = getUserPercentRate(msg.sender);
		if (user.deposits[index].withdrawn < user.deposits[index].amount.mul(2)) {
			if (user.deposits[index].start > user.checkpoint) {
				dividends = (user.deposits[index].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
					.mul(block.timestamp.sub(user.deposits[index].start))
					.div(TIME_STEP);
			} else {
				dividends = (user.deposits[index].amount.mul(userPercentRate).div(PERCENTS_DIVIDER))
					.mul(block.timestamp.sub(user.checkpoint))
					.div(TIME_STEP);
			}
			if (user.deposits[index].withdrawn.add(dividends) > user.deposits[index].amount.mul(2)) {
				dividends = (user.deposits[index].amount.mul(2)).sub(user.deposits[index].withdrawn);
			}
		}
		return (user.deposits[index].amount, user.deposits[index].withdrawn.add(dividends), user.deposits[index].start);
	}

	function getUserAmountOfDeposits(address userAddress) public view returns(uint256) {
		return users[userAddress].deposits.length;
	}

	function setAntiWhale(address userAddress, bool status) external {
		require(msg.sender == projectAddress, "only owner");
		require(getUserTotalDeposits(userAddress) > 100 ether, "only whales" );
		antiWhale[userAddress] = status;
	}

	function getUserTotalDeposits(address userAddress) public view returns(uint256) {
	    User storage user = users[userAddress];
		return user.totalInvested;
	}

	function getUserTotalWithdrawn(address userAddress) public view returns(uint256) {
	    User storage user = users[userAddress];
		uint256 amount;
		for (uint256 i = 0; i < user.deposits.length; i++) {
			amount = amount.add(user.deposits[i].withdrawn);
		}
		return amount;
	}

	function getUserDownlineCount(address userAddress) public view returns(uint256, uint256, uint256, uint256, uint256) {
		return (users[userAddress].levels[0], users[userAddress].levels[1], users[userAddress].levels[2], users[userAddress].levels[3], users[userAddress].levels[4]);
	}

	function getUserReferralTotalBonus(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus;
	}

	function getUserReferralWithdrawn(address userAddress) public view returns(uint256) {
		return users[userAddress].totalBonus.sub(users[userAddress].bonus);
	}

	function getUserInfo(address userAddress) public view returns(uint256, uint256, uint256){
		return (
			getUserAvailable(userAddress),
			getUserTotalDeposits(userAddress),
			getUserTotalWithdrawn(userAddress)
		);
	}

	function getContractInfo() public view returns(uint256, uint256, uint256, uint256, uint256){
		return (
			totalUsers,
			totalInvested,
			totalWithdrawn,
			totalReferrals,
			getContractBalance()
		);
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