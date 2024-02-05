// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
/**
 * @title esVIB is an ERC20-compliant token, but cannot be transferred and can only be minted through the esVIBMinter contract or redeemed for VIB by destruction.
 * - The maximum amount that can be minted through the esVIBMinter contract is 55 million.
 * - esVIB can be used for community governance voting.
 */

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "./Governable.sol";

interface IVibraniumFund {
    function refreshReward(address user) external;
}

contract esVIB is ERC20Votes, Governable {
    mapping(address => bool) public esVIBMinter;
    address public immutable vibraniumFund;

    uint256 maxMinted = 30_000_000 * 1e18;
    uint256 public totalMinted;

    constructor(
        address _fund
    ) ERC20Permit("esVIB") ERC20("esVIB", "esVIB") {
        vibraniumFund = _fund;
        gov = msg.sender;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override {
        revert("not authorized");
    }

    function setMinter(address[] calldata _contracts, bool[] calldata _bools) external onlyGov {
        for(uint256 i = 0;i<_contracts.length;i++) {
            esVIBMinter[_contracts[i]] = _bools[i];
        }
    }

    function mint(address user, uint256 amount) external returns(bool) {
        require(msg.sender == vibraniumFund || esVIBMinter[msg.sender] == true, "not authorized");
        uint256 reward = amount;
        if(msg.sender != vibraniumFund) {
            IVibraniumFund(vibraniumFund).refreshReward(user);
            if(totalMinted + reward > maxMinted) {
                reward = maxMinted - totalMinted;
            }
            totalMinted += reward;
        }
        _mint(user, reward);
        return true;
    }

    function burn(address user, uint256 amount) external returns(bool) {
        require(msg.sender == vibraniumFund || esVIBMinter[msg.sender] == true, "not authorized");
        if(msg.sender != vibraniumFund) {
            IVibraniumFund(vibraniumFund).refreshReward(user);
        }
        _burn(user, amount);
        return true;
    }
}