// SPDX-License-Identifier: UNLICENSED
import "@openzeppelin/contracts/access/IAccessControl.sol";
pragma solidity ^0.8.20;

interface IFactoryERC20 is IAccessControl{
    function lockAddress(address token) external view returns(address);
    function erc20(string memory _brc20Ticker) external view returns(address);
    function brc20(address token) external view returns(string memory);
    function BRIDGE_TOKEN()external view returns(bytes32);
}
