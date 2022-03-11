// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IAllowContract {
    function has(address _addr) external view returns (bool);
}
