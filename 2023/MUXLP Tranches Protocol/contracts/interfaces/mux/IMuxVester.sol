// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMuxVester {
    function deposit(uint256 _amount) external;

    function claim() external returns (uint256);

    function withdraw() external;

    function balanceOf(address _account) external view returns (uint256);

    function pairAmounts(address _account) external view returns (uint256);

    function getPairAmount(address _account, uint256 _esAmount) external view returns (uint256);

    function getCombinedAverageStakedAmount(address _account) external view returns (uint256);

    function getMaxVestableAmount(address _account) external view returns (uint256);
}
