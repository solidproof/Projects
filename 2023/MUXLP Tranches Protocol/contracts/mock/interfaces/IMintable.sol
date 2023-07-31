// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMintable {
    function mint(address receiver, uint256 amount) external;

    function burn(address account, uint256 amount) external;
}
