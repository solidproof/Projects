// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IBullFarm {
    function setOpenLines(address account, uint lines) external;
    function depositTo(address account) external payable;
}