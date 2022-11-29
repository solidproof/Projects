// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// https://docs.synthetix.io/contracts/source/interfaces/istakingrewards
interface ITokenStake {
    // Views

    function balanceOf(address _account)
        external
        view
        returns (uint256[] memory);

    function isStaking(address _account) external view returns (bool);

    // function earning(address _account, uint256 stakingOrder)
    //     external
    //     view
    //     returns (uint256);

    function totalEarnOnePart(address _account, uint256 stakingOrder)
        external
        view
        returns (uint256);

    function totalSupply() external view returns (uint256);

    function getRemainStakingDuration(address _account, uint256 stakingOrder)
        external
        view
        returns (uint256);

    // Mutative
    function stake(uint256 _amount) external;

    function getReward(uint256 stakingOrder) external;

    function exit(uint256 stakingOrder) external;
}