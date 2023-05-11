// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IPresaleFang {
    enum State {
        NOT_ACTIVE,
        WL,
        PUBLIC,
        OVER
    }
    enum WlType {
        VAMPIRE,
        MILLENIAL
    }

    struct VestingInfo {
        uint256 fangAmount;
        uint256 vestingType;
    }

    function vestingInfoByAddress(
        address
    ) external view returns (VestingInfo memory);

    function state() external view returns (State);

    function getAmountSeed() external view returns (uint256);

    function getAmountPresale() external view returns (uint256);
}
