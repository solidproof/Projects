// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ITLFVesting.sol";

/// @title Vesting Contract

contract TLFVesting is AccessControl, ReentrancyGuard, ITLFVesting {
	using SafeERC20 for ERC20;

	bytes32 public constant TLF_ADMIN_ROLE = keccak256("TLF_ADMIN_ROLE");

	ERC20 immutable private _token;
	uint256 immutable private _startVesting;

	uint256 private _vestingSchedulesTotalAmount;
	uint256 private _vestingSchedulesTotalReleased;

	mapping(address => mapping(bytes32 => VestingSchedule)) private _vestingSchedules;

	/// @notice Check if caller is contract admin
	modifier onlyTLFAdmin {
		require(hasRole(TLF_ADMIN_ROLE, msg.sender), "TLFVesting: Caller is not an admin");
		_;
	}

	/// @notice Check if caller is contract owner
	modifier onlyOwner {
		require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "TLFVesting: Caller is not an owner");
		_;
	}

	/// @notice Check if vesting schedule is exist
	/// @param account_ Address account
	/// @param round_ Round name
	modifier onlyVestingScheduleIsExist(address account_, bytes32 round_) {
		require(_vestingSchedules[account_][round_].initialized, "TLFVesting: Vesting schedule does not exist");
		_;
	}

	/// @notice Check if vesting schedule is not revoked
	/// @param account_ Address account
	/// @param round_ Round name
	modifier onlyVestingScheduleNotRevoked(address account_, bytes32 round_)
	{
		require(!_vestingSchedules[account_][round_].revoked, "TLFVesting: Vesting schedule revoked");
		_;
	}

	/// @notice Contract constructor
	/// @dev Sets roles
	/// @dev Sets TLF token contract
	/// @dev Sets start vesting timestamp
	/// @param token_ Token contract address
	/// @param startVesting_ Start vesting timestamp
	constructor (address token_, uint256 startVesting_) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(TLF_ADMIN_ROLE, msg.sender);

		require(token_ != address(0), "TLFVesting: Invalid token address");
		_token = ERC20(token_);

		_startVesting = startVesting_;
	}

	/// @notice Return vesting schedules total amount
	/// @dev Return the total amount of tokens needed for vesting schedules
	/// @return Vesting schedules total amount
	function getVestingSchedulesTotalAmount() external view returns(uint256) {
		return _vestingSchedulesTotalAmount;
	}

	/// @notice Return vesting schedules total release.js
	/// @dev Return total release.js of tokens for vesting schedules
	/// @return Vesting schedules total release.js
	function getVestingSchedulesTotalReleased() external view returns (uint256) {
		return _vestingSchedulesTotalReleased;
	}

	/// @notice Return start vesting timestamp
	/// @return start vesting timestamp
	function getStartVesting() external view returns (uint256) {
		return _startVesting;
	}

	/// @notice Return TLF token address
	/// @return token contract address
	function getTokenAddress() external view returns (address) {
		return address(_token);
	}

	/// @notice Return amount available for withdrawal
	/// @return withdrawable amount
	function getWithdrawableAmount() public view returns (uint256) {
		return _token.balanceOf(address(this)) - _vestingSchedulesTotalAmount;
	}

	/// @notice Return amount available for release in round
	/// @dev Only vesting schedule is exist
	/// @param account_ Address account
	/// @param round_ Round name
	/// @return releasable round amount
	function getReleasableRoundAmount(address account_, bytes32 round_)
		onlyVestingScheduleIsExist(account_, round_)
		external
		view
		returns (uint256)
	{
		VestingSchedule memory vestingSchedule = _vestingSchedules[account_][round_];
		return _computeReleasableRoundAmount(vestingSchedule);
	}

	/// @notice Return vesting schedule
	/// @dev If no vesting schedules exist, return empty struct
	/// @dev struct VestingSchedule {
	/// @dev  uint32 lock
	/// @dev  uint32 duration
	/// @dev  uint256 totalAmount
	/// @dev  uint256 release.js
	/// @dev  bool revocable
	/// @dev  bool revoked
	/// @dev  bool initialized
	/// @dev }
	/// @param account_ Address account
	/// @param round_ Round name
	/// @return Vesting schedules total amount
	function getVestingSchedule(address account_, bytes32 round_)
		external
		view
		returns (VestingSchedule memory)
	{
		return _vestingSchedules[account_][round_];
	}

	/// @notice Create vesting schedule
	/// @dev Only available to admin
	/// @dev Amount of TLF tokens must be sufficient for vesting schedule amount
	/// @dev Account address must be valid
	/// @dev Vesting schedule amount must be greater than zero
	/// @dev Vesting schedule should not exist
	/// @param lock_ Release delay time after vesting start
	/// @param duration_ Vesting schedule duration
	/// @param amount_ Vesting schedule amount
	/// @param account_ Account address
	/// @param revocable_ If vesting schedule is available for revoke
	/// @param round_ Round name
	function createVestingSchedule(
		uint32 lock_,
		uint32 duration_,
		uint256 amount_,
		address account_,
		bool revocable_,
		bytes32 round_
	) external onlyTLFAdmin {
		require(getWithdrawableAmount() >= amount_, "TLFVesting: Not enough TLF tokens");
		require(account_ != address(0), "TLFVesting: Invalid account address");
		require(amount_ > 0, "TLFVesting: Amount must be > 0");

		VestingSchedule memory vestingSchedule = _vestingSchedules[account_][round_];
		require(!vestingSchedule.initialized, "TLFVesting: Vesting schedule exist");

		_vestingSchedules[account_][round_] = VestingSchedule(
			true,
			revocable_,
			false,
			lock_,
			duration_,
			amount_,
			0
		);
		_vestingSchedulesTotalAmount += amount_;

		emit CreateVestingSchedule(lock_, duration_, amount_, account_, revocable_, round_);
	}

	/// @notice Increase vesting schedule
	/// @dev Only available to admin
	/// @dev Amount of TLF tokens must be sufficient for vesting schedule amount
	/// @dev Vesting schedule amount must be greater than zero
	/// @dev Vesting schedule must exist
	/// @dev Vesting schedule should be not revoked
	/// @param account_ Account address
	/// @param round_ Round name
	/// @param amount_ Vesting schedule increase amount
	function increaseVestingSchedule(address account_, bytes32 round_, uint256 amount_)
		onlyVestingScheduleIsExist(account_, round_)
		onlyVestingScheduleNotRevoked(account_, round_)
		onlyTLFAdmin
		external
	{
		require(getWithdrawableAmount() >= amount_, "TLFVesting: Not enough TLF tokens");
		require(amount_ > 0, "TLFVesting: Amount must be > 0");

		_vestingSchedules[account_][round_].totalAmount += amount_;
		_vestingSchedulesTotalAmount += amount_;

		emit IncreaseVestingSchedule(amount_, account_, round_);
	}

	/// @notice Withdraw TLF tokens
	/// @dev Only available to owner
	/// @dev Non reentrant function
	/// @dev Amount must be more than available amount
	/// @param amount_ Withdrawable amount
	function withdraw(uint256 amount_) external nonReentrant onlyOwner {
		require(getWithdrawableAmount() >= amount_, "TLFVesting: Not enough withdrawable funds");

		_token.safeTransfer(msg.sender, amount_);

		emit Withdraw(amount_);
	}

	/// @notice Release TLF tokens
	/// @dev Only available to owner and token recipient
	/// @dev Non reentrant function
	/// @dev Vesting schedule must exist
	/// @dev Vesting schedule should be not revoked
	/// @dev Amount must be more than available amount
	/// @param account_ Account address
	/// @param round_ Round name
	/// @param amount_ Releasable amount
	function release(address account_, bytes32 round_, uint256 amount_)
		onlyVestingScheduleIsExist(account_, round_)
		onlyVestingScheduleNotRevoked(account_, round_)
		nonReentrant
		external
	{
		bool isRecipient = msg.sender == account_;
		bool isOwner = hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
		require(isRecipient || isOwner, "TLFVesting: Caller is not recipient or owner");

		_release(account_, round_, amount_);
	}

	/// @notice Revoke TLF tokens
	/// @dev Release to recipient currently available amount and revoke remaining amount
	/// @dev Only available to owner
	/// @dev Non reentrant function
	/// @dev Vesting schedule must exist
	/// @dev Vesting schedule should be revocable
	/// @dev Vesting schedule should be not revoked
	/// @param account_ Account address
	/// @param round_ Round name
	function revoke(address account_, bytes32 round_)
		onlyVestingScheduleIsExist(account_, round_)
		onlyVestingScheduleNotRevoked(account_, round_)
		onlyOwner
		nonReentrant
		external
	{
		VestingSchedule memory vestingSchedule = _vestingSchedules[account_][round_];

		require(vestingSchedule.revocable, "TokenVesting: Vesting is not revocable");
		require(
			_startVesting + vestingSchedule.lock + vestingSchedule.duration > block.timestamp,
			"TokenVesting: Vesting is over"
		);

		uint256 releasableAmount = _computeReleasableRoundAmount(vestingSchedule);
		if (releasableAmount > 0) _release(account_, round_, releasableAmount);

		uint256 revocableAmount = vestingSchedule.totalAmount - vestingSchedule.released - releasableAmount;

		_vestingSchedulesTotalAmount -= revocableAmount;

		_vestingSchedules[account_][round_].revoked = true;
		_vestingSchedules[account_][round_].totalAmount = vestingSchedule.released + releasableAmount;

		emit Revoked(account_, round_, revocableAmount);
	}

	/// @notice Private function for release
	function _release(address account_, bytes32 round_, uint256 amount_) private {
		VestingSchedule memory vestingSchedule = _vestingSchedules[account_][round_];

		uint256 releasableAmount = _computeReleasableRoundAmount(vestingSchedule);
		require(releasableAmount >= amount_, "TLFVesting: Not enough available tokens");

		_vestingSchedules[account_][round_].released += amount_;

		_vestingSchedulesTotalReleased += amount_;
		_vestingSchedulesTotalAmount -= amount_;

		_token.safeTransfer(account_, amount_);

		emit Released(account_, round_, amount_);
	}

	/// @notice Private function for compute releasable round amount
	function _computeReleasableRoundAmount(VestingSchedule memory vestingSchedule_)
		private
		view
		returns (uint256)
	{
		uint256 currentTime = block.timestamp;
		uint256 lockEndTime = _startVesting + vestingSchedule_.lock;
		if (
			(currentTime < lockEndTime) ||
			vestingSchedule_.revoked
		) {
			return 0;
		} else if (
			currentTime >= lockEndTime + vestingSchedule_.duration ||
			vestingSchedule_.duration == 0
		) {
			return vestingSchedule_.totalAmount - vestingSchedule_.released;
		} else {
			uint256 timeFromStartRelease = currentTime - lockEndTime;
			uint256 releasableRoundAmount = (vestingSchedule_.totalAmount *
			timeFromStartRelease) / vestingSchedule_.duration;
			return releasableRoundAmount - vestingSchedule_.released;
		}
	}
}
