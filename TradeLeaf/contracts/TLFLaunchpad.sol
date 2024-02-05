// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ITLFVesting.sol";
import "./ITLFLaunchpad.sol";

/// @title Launchpad Contract

contract TLFLaunchpad is AccessControl, ReentrancyGuard, ITLFLaunchpad {
	using SafeERC20 for ERC20;

	bytes32 public constant TLF_ADMIN_ROLE = keccak256("TLF_ADMIN_ROLE");

	ITLFVesting private immutable _vesting;
	address private _receiver;

	mapping(bytes32 => RoundProperty) private _roundProperties;
	mapping(address => mapping(bytes32 => bool)) private _whitelist;
	mapping(bytes32 => Stablecoin) private _stablecoins;

	/// @notice Check if caller is contract admin
	modifier onlyTLFAdmin {
		require(hasRole(TLF_ADMIN_ROLE, msg.sender), "TLFLaunchpad: Caller is not an admin");
		_;
	}

	/// @notice Check if caller is contract owner
	modifier onlyOwner {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "TLFLaunchpad: Caller is not an owner");
		_;
	}

	/// @notice Contract constructor
	/// @dev Sets roles
	/// @dev Sets vesting contract
	/// @param vesting_ Vesting contract address
	/// @param receiver_ Stablecoin recipient address
	constructor(address vesting_, address receiver_) {
		require(vesting_ != address(0), "TLFLaunchpad: Invalid vesting address");
		require(receiver_ != address(0), "TLFLaunchpad: Invalid receiver address");

		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(TLF_ADMIN_ROLE, msg.sender);

		_vesting = ITLFVesting(vesting_);
		_receiver = receiver_;

		emit SetReceiver(receiver_);
	}

	/// @notice Get stablecoins receiver
	/// @dev Only available to owner
	function getReceiver() external view returns(address) {
		return _receiver;
	}

	/// @notice Set stablecoins receiver
	/// @dev Only available to owner
	/// @dev Receiver address must be valid
	/// @param receiver_ new receiver address
	function setReceiver(address receiver_) external onlyOwner {
		require(receiver_ != address(0), "TLFLaunchpad: Invalid receiver address");

		_receiver = receiver_;

		emit SetReceiver(receiver_);
	}

	/// @notice Return properties of the round
	/// @dev If no round property exist, return empty struct
	/// @dev struct RoundProperty {
	/// @dev 	bool initialize
	/// @dev 	uint32 startTime
	/// @dev 	uint32 duration
	/// @dev 	uint256 totalAmount
	/// @dev 	uint256 soldAmount
	/// @dev 	uint256 limit
	/// @dev 	uint32 price
	/// @dev 	uint32 vestingLock
	/// @dev 	uint32 vestingDuration
	/// @dev 	bool paused
	/// @dev }
	/// @param round_ Round name
	/// @return Properties of the round
	function getRound(bytes32 round_) external view returns(RoundProperty memory) {
		return _roundProperties[round_];
	}

	/// @notice Initialize round
	/// @dev Only available to owner
	/// @dev Round must not be initialized
	/// @param round_ Round name
	/// @param startTime_ Round start timestamp
	/// @param duration_ Round duration
	/// @param totalAmount_ Round totalAmount
	/// @param limit_ Round limit for account, if 0 than not limit
	/// @param price_ Price TLF token, if price is set to 0 then round works like an airdrop
	/// @param vestingLock_ Release delay time after vesting start
	/// @param vestingDuration_ Vesting schedule duration
	function initializeRound(
		bytes32 round_,
		uint32 startTime_,
		uint32 duration_,
		uint256 totalAmount_,
		uint256 limit_,
		uint32 price_,
		uint32 vestingLock_,
		uint32 vestingDuration_
	) external onlyOwner {
		require(!_roundProperties[round_].initialize, "TLFLaunchpad: Round already initialized");

		_roundProperties[round_] = RoundProperty(
			true,
			false,
			startTime_,
			duration_,
			price_,
			vestingLock_,
			vestingDuration_,
			totalAmount_,
			0,
			limit_
		);

		emit InitializeRound(
			round_,
			startTime_,
			duration_,
			totalAmount_,
			limit_,
			price_,
			vestingLock_,
			vestingDuration_
		);
	}

	/// @notice Change round
	/// @dev Only available to owner
	/// @dev Round must be initialized
	/// @dev Round must not start and start time of round must be longer than now
	/// @dev Round must not be over yet and the end of round must be longer than now
	/// @dev Total amount of round must be greater than amount of sold tokens
	/// @param round_ Round name
	/// @param startTime_ Round start timestamp
	/// @param duration_ Round duration
	/// @param totalAmount_ Round totalAmount
	/// @param limit_ Round limit for account, if 0 than not limit
	/// @param price_ Price TLF token
	/// @param vestingLock_ Release delay time after vesting start
	/// @param vestingDuration_ Vesting schedule duration
	/// @param paused_ TRUE if the round is paused.
	function changeRound(
		bytes32 round_,
		uint32 startTime_,
		uint32 duration_,
		uint256 totalAmount_,
		uint256 limit_,
		uint32 price_,
		uint32 vestingLock_,
		uint32 vestingDuration_,
		bool paused_
	) external onlyOwner {
		RoundProperty memory round = _roundProperties[round_];

		require(round.initialize, "TLFLaunchpad: Round is not initialized");

		if (startTime_ != round.startTime) {
			require(round.startTime > block.timestamp, "TLFLaunchpad: Round has already started");
			require(startTime_ > block.timestamp, "TLFLaunchpad: Round start time is less than now");

			round.startTime = startTime_;
		}

		if (duration_ != round.duration) {
			require(round.startTime + round.duration > block.timestamp, "TLFLaunchpad: Round is over");
			require(round.startTime + duration_ > block.timestamp, "TLFLaunchpad: Round ending less than now");

			round.duration = duration_;
		}

		if (totalAmount_ != round.totalAmount) {
			require(totalAmount_ >= round.soldAmount, "TLFLaunchpad: Total amount is less than amount sold");

			round.totalAmount = totalAmount_;
		}

		if (price_ != round.price) {
			round.price = price_;
		}

		if (limit_ != round.limit) {
			round.limit = limit_;
		}

		if (vestingLock_ != round.vestingLock) {
			round.vestingLock = vestingLock_;
		}

		if (vestingDuration_ != round.vestingDuration) {
			round.vestingDuration = vestingDuration_;
		}

		if (paused_ != round.paused) {
			round.paused = paused_;
		}

		_roundProperties[round_] = round;

		emit ChangeRound(round_, startTime_, duration_, totalAmount_, limit_, price_, vestingLock_, vestingDuration_, paused_);
	}

	/// @notice Return stablecoin contract address
	/// @dev Stablecoin must be initialized
	/// @param name_ Stablecoin name
	/// @return stablecoin contract address
	function getStablecoin(bytes32 name_) external view returns(address) {
		require(_stablecoins[name_].initialize, "TLFLaunchpad: Stablecoin not initialized");

		return address(_stablecoins[name_].token);
	}

	/// @notice Initialize stablecoin
	/// @dev Only available to owner
	/// @dev Stablecoin must be not initialized
	/// @dev Stablecoin contract address must be valid
	/// @param name_ Stablecoin name
	/// @param token_ Stablecoin contract address
	function setStablecoin(bytes32 name_, address token_) external onlyOwner {
		require(!_stablecoins[name_].initialize, "TLFLaunchpad: Stablecoin already initialized");
		require(token_ != address(0), "TLFLaunchpad: Invalid token address");

		_stablecoins[name_] = Stablecoin(true, ERC20(token_));

		emit InitializeStablecoin(name_, token_);
	}

	/// @notice Remove stablecoin
	/// @dev Only available to owner
	/// @dev Stablecoin must be initialized
	/// @param name_ Stablecoin name
	function removeStablecoin(bytes32 name_) external onlyOwner {
		require(_stablecoins[name_].initialize, "TLFLaunchpad: Stablecoin not initialized");

		_stablecoins[name_].initialize = false;

		emit RemoveStablecoin(name_);
	}

	/// @notice Return vesting contract address
	/// @return vesting contract address
	function getVestingAddress() external view returns(address) {
		return address(_vesting);
	}

	/// @notice Return account whitelisted
	/// @dev Only vesting schedule is exist
	/// @param account_ Address account
	/// @param round_ Round name
	/// @return true if account whitelisted
	function getAccountWhitelist(address account_, bytes32 round_) external view returns(bool) {
		return _whitelist[account_][round_];
	}

	/// @notice Add account to whitelist
	/// @dev Only available to admin
	/// @dev Account must not be whitelisted
	/// @param account_ Address account
	/// @param round_ Round name
	function addAccountToWhitelist(address account_, bytes32 round_) external onlyTLFAdmin {
		require(!_whitelist[account_][round_], "TLFLaunchpad: Account is already whitelisted");
		require(account_ != address(0), "TLFLaunchpad: Invalid account address");

		_whitelist[account_][round_] = true;

		emit AddToWhitelist(account_, round_);
	}

	/// @notice Remove account from whitelist
	/// @dev Only available to admin
	/// @dev Account must not be not whitelisted
	/// @param account_ Address account
	/// @param round_ Round name
	function removeAccountFromWhitelist(address account_, bytes32 round_) external onlyTLFAdmin {
		require(_whitelist[account_][round_], "TLFLaunchpad: Account not whitelisted");

		delete _whitelist[account_][round_];

		emit RemoveFromWhitelist(account_, round_);
	}

	/// @notice Remove the amount of stablecoins you need to buy TLF tokens
	/// @param round_ Round name
	/// @param tlfAmount_ amount TLF tokens
	/// @param stablecoin_ Stablecoin name
	function getAmountToBuyTLF(bytes32 round_, uint256 tlfAmount_, bytes32 stablecoin_) external view returns(uint256) {
		require(_roundProperties[round_].initialize, "TLFLaunchpad: Round not initialized");
		require(_stablecoins[stablecoin_].initialize, "TLFLaunchpad: Stablecoin not initialized");

		return _getAmountToBuyTLF(_roundProperties[round_].price, tlfAmount_, stablecoin_);
	}

	/// @notice Buy TLF
	/// @dev Non reentrant function
	/// @dev Account must not be whitelisted
	/// @dev Stablecoin must be initialized
	/// @dev Round must be initialized
	/// @dev Round must be started and not finished
	/// @dev Round must be not paused
	/// @dev Сontract must have enough tokens to sell
	/// @dev Amount of redeemed and purchased tokens should not exceed the limit, if it is set
	/// @param round_ Round name
	/// @param amount_ amount TLF tokens
	/// @param stablecoin_ Stablecoin name
	function buyTLF(bytes32 round_, uint256 amount_, bytes32 stablecoin_)
		nonReentrant
		external
	{
		require(_whitelist[msg.sender][round_], "TLFLaunchpad: Account is not on the whitelist");
		require(_roundProperties[round_].initialize, "TLFLaunchpad: Round not initialized");
		require(_stablecoins[stablecoin_].initialize, "TLFLaunchpad: Stablecoin not initialized");

		uint256 currentTime = block.timestamp;
		RoundProperty memory roundProperty = _roundProperties[round_];

		require(currentTime > roundProperty.startTime, "TLFLaunchpad: Round has not started");
		require(currentTime < roundProperty.startTime + roundProperty.duration, "TLFLaunchpad: Round is over");
		require(!roundProperty.paused, "TLFLaunchpad: Round paused");
		require(amount_ <= roundProperty.totalAmount - roundProperty.soldAmount, "TLFLaunchpad: Not enough TLF tokens");

		uint256 soldAmount = _vesting.getVestingSchedule(msg.sender, round_).totalAmount;

		require(roundProperty.limit == 0
			|| roundProperty.limit >= soldAmount + amount_, "TLFLaunchpad: Purchase limit exceeded");

		uint256 stablecoinAmount = _getAmountToBuyTLF(roundProperty.price, amount_, stablecoin_);

		_stablecoins[stablecoin_].token.safeTransferFrom(
			msg.sender,
			_receiver,
			stablecoinAmount
		);

		if (soldAmount == 0) {
			_vesting.createVestingSchedule(
				roundProperty.vestingLock,
				roundProperty.vestingDuration,
				amount_,
				msg.sender,
				false,
				round_
			);
		} else {
			_vesting.increaseVestingSchedule(
				msg.sender,
				round_,
				amount_
			);
		}

		_roundProperties[round_].soldAmount += amount_;

		emit BuyTLF(msg.sender, round_, amount_, stablecoin_);
	}

	function _getAmountToBuyTLF(uint256 price_, uint256 tlfAmount_, bytes32 stablecoin_) private view returns(uint256) {
		uint256 stablecoinDecimals = _stablecoins[stablecoin_].token.decimals();
		uint256 tlfDecimals = ERC20(_vesting.getTokenAddress()).decimals();

		return tlfAmount_ * price_ * 10 ** stablecoinDecimals / (100000 * 10 ** tlfDecimals);
	}
}
