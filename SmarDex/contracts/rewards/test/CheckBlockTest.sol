// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// interfaces
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../interfaces/IStaking.sol";

contract CheckBlockTest {
    IStaking staking;
    IERC20 sdex;

    constructor(IStaking _staking, IERC20 _sdex) {
        staking = _staking;
        sdex = _sdex;
        sdex.approve(address(staking), type(uint256).max);
    }

    function exploitStaking(uint256 amount) external {
        staking.deposit(amount);
        staking.withdraw(address(this), amount * 1e27);
    }
}
