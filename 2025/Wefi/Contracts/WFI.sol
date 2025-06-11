// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WFI is ERC20, Ownable2Step, ERC20Permit {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor(address initialOwner) ERC20("WFI", "WFI") Ownable(initialOwner) ERC20Permit("WFI") {
        _mint(initialOwner, MAX_SUPPLY);
    }
}