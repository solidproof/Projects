// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMuxRewardRouter {
    function mlp() external view returns (address);

    function mcb() external view returns (address);

    function mux() external view returns (address);

    function weth() external view returns (address);

    // fmlp
    function mlpFeeTracker() external view returns (address);

    // smlp
    function mlpMuxTracker() external view returns (address);

    // vester
    function mlpVester() external view returns (address);

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
        );

    function claimAll() external;

    function stakeMlp(uint256 _amount) external returns (uint256);

    function unstakeMlp(uint256 _amount) external returns (uint256);

    function depositToMlpVester(uint256 amount) external;

    function withdrawFromMlpVester() external;

    function mlpLockAmount(address account, uint256 amount) external view returns (uint256);

    function reservedMlpAmount(address account) external view returns (uint256);
}
