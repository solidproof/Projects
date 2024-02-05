// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
/**
 * @title VIB is an ERC20-compliant token.
 * - VIB can only be exchanged to esVIB in the vibraniumFund contract.
 * - Apart from the initial production, VIB can only be produced by destroying esVIB in the fund contract.
 */
import "./ERC20.sol";

contract VIB is ERC20 {
    address public vibraniumFund;
    uint256 maxSupply = 50_000_000 * 1e18;
    address public owner;

    constructor(
        address _fund
    ) ERC20("VIB", "VIB") {
        owner = msg.sender;
        vibraniumFund = _fund;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    function setVibraniumFund(address _fund) external onlyOwner {
        vibraniumFund = _fund;
    }

    function mint(address user, uint256 amount) external returns(bool) {
        require(msg.sender == vibraniumFund, "not authorized");
        require(totalSupply() + amount <= maxSupply, "exceeding the maximum supply quantity.");
        _mint(user, amount);
        return true;
    }

    function burn(address user, uint256 amount) external returns(bool) {
        require(msg.sender == vibraniumFund, "not authorized");
        _burn(user, amount);
        return true;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;
    }
}