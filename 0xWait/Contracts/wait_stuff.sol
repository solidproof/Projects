//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IWAIT {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
    function mintedPeople(uint sac) external view returns (uint);
    function ClaimedAmount(uint sac, address user) external view returns (uint);
    function totalWait(uint sac) external view returns (uint);
    function burnFrom(address account, uint amount) external;
    }