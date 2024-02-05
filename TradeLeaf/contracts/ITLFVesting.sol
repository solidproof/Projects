// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ITLFVesting {
	struct VestingSchedule {
		bool initialized;
		bool revocable;
		bool revoked;
		uint32 lock;
		uint32 duration;
		uint256 totalAmount;
		uint256 released;
	}

	event CreateVestingSchedule(
		uint32 lock,
		uint32 duration,
		uint256 amount,
		address account,
		bool revocable,
		bytes32 round
	);

	event IncreaseVestingSchedule(
		uint256 amount,
		address account,
		bytes32 round
	);

	event Withdraw(
		uint256 amount
	);

	event Released(
		address account,
		bytes32 round,
		uint256 amount
	);

	event Revoked(
		address account,
		bytes32 round,
		uint256 amount
	);

	function getVestingSchedulesTotalAmount() external view returns(uint256);

	function getVestingSchedulesTotalReleased() external view returns (uint256);

	function getStartVesting() external view returns (uint256);

	function getTokenAddress() external view returns (address);

	function getWithdrawableAmount() external view returns (uint256);

	function getReleasableRoundAmount(address account_, bytes32 round_) external view returns (uint256);

	function getVestingSchedule(address account_, bytes32 round_) external view returns (VestingSchedule memory);

	function createVestingSchedule(
		uint32 lock_,
		uint32 duration_,
		uint256 amount_,
		address account_,
		bool revocable_,
		bytes32 round_
	) external;

	function increaseVestingSchedule(address account_, bytes32 round_, uint256 amount_) external;

	function withdraw(uint256 amount_) external;

	function release(address account_, bytes32 round_, uint256 amount_) external;

	function revoke(address account_, bytes32 round_) external;
}
