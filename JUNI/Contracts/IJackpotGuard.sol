// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

interface IJackpotGuard {
    function getJackpotQualifier(
        address routerAddress,
        address jpToken,
        uint256 jackpotMinBuy,
        uint256 tokenAmount
    ) external view returns (uint256);

    function usdEquivalent(address router, uint256 bnbAmount)
        external
        view
        returns (uint256);

    function isJackpotEligibleOnAward(address user)
        external
        view
        returns (bool);

    function isJackpotEligibleOnBuy(address user) external view returns (bool);

    function isRestricted(address user) external view returns (bool);

    function ban(address user) external;

    function ban(address[] calldata users) external;

    function unban(address user) external;

    function unban(address[] calldata users) external;
}
