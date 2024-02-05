// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ITLFVesting.sol";

interface ITLFLaunchpad {
	struct Stablecoin {
		bool initialize;
		ERC20 token;
	}

	struct RoundProperty {
		bool initialize;
		bool paused;
		uint32 startTime;
		uint32 duration;
		uint32 price;
		uint32 vestingLock;
		uint32 vestingDuration;
		uint256 totalAmount;
		uint256 soldAmount;
		uint256 limit;
	}

	event InitializeRound(
		bytes32 round,
		uint32 startTime,
		uint32 duration,
		uint256 totalAmount,
		uint256 limit,
		uint32 price,
		uint32 vestingLock,
		uint32 vestingDuration
	);

	event ChangeRound(
		bytes32 round,
		uint32 startTime,
		uint32 duration,
		uint256 totalAmount,
		uint256 limit,
		uint32 price,
		uint32 vestingLock,
		uint32 vestingDuration,
		bool paused
	);

	event SetReceiver(address receiver);

	event InitializeStablecoin(bytes32 name, address stablecoin);

	event RemoveStablecoin(bytes32 name);

	event AddToWhitelist(address account, bytes32 round);

	event RemoveFromWhitelist(address account, bytes32 round);

	event BuyTLF(address account, bytes32 round, uint256 amount, bytes32 stablecoin);

	function getReceiver() external view returns(address);

	function setReceiver(address receiver_) external;

	function getRound(bytes32 round_) external view returns(RoundProperty memory);

	function initializeRound(
		bytes32 round_,
		uint32 startTime_,
		uint32 duration_,
		uint256 totalAmount_,
		uint256 limit_,
		uint32 price_,
		uint32 vestingLock_,
		uint32 vestingDuration_
	) external;

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
	) external;

	function getStablecoin(bytes32 name_) external view returns(address);

	function setStablecoin(bytes32 name_, address token_) external;

	function removeStablecoin(bytes32 name_) external;

	function getVestingAddress() external view returns(address);

	function getAccountWhitelist(address account_, bytes32 round_) external view returns(bool);

	function addAccountToWhitelist(address account_, bytes32 round_) external;

	function removeAccountFromWhitelist(address account_, bytes32 round_) external;

	function getAmountToBuyTLF(bytes32 round_, uint256 tlfAmount_, bytes32 stablecoin_) external view returns(uint256);

	function buyTLF(bytes32 round_, uint256 amount_, bytes32 stablecoin_) external;
}
