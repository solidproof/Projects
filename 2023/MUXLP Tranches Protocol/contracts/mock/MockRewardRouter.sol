// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract MockRewardRouter {
    address public stakeToken;
    address public depositToken;

    constructor(address stakeToken_, address depositToken_) {
        stakeToken = stakeToken_;
        depositToken = depositToken_;
    }

    // function mlpVester() external view returns (address);

    // function mlp() external view returns (address);

    // function mcb() external view returns (address);

    // function mux() external view returns (address);

    // function weth() external view returns (address);

    function mlpFeeTracker() external view returns (address) {
        return address(this);
    }

    function claimableRewards(
        address account
    )
        external
        returns (
            uint256 mlpFeeAmount,
            uint256 mlpMuxAmount,
            uint256 veFeeAmount,
            uint256 veMuxAmount,
            uint256 mcbAmount
        )
    {}

    function claimAll() external {}

    function stakeMlp(uint256 _amount) external returns (uint256) {
        IERC20Upgradeable(depositToken).transferFrom(msg.sender, address(this), _amount);
        IERC20Upgradeable(stakeToken).transfer(msg.sender, _amount);
        return _amount;
    }

    function unstakeMlp(uint256 _amount) external returns (uint256) {
        IERC20Upgradeable(stakeToken).transferFrom(msg.sender, address(this), _amount);
        IERC20Upgradeable(depositToken).transfer(msg.sender, _amount);
        return _amount;
    }
}
