//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IFomo {
	function transferNotify(address user) external;
	function swap() external;
}