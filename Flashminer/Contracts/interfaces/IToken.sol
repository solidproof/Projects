/**
 * SPDX-License-Identifier: MI231321T
*/
pragma solidity >=0.8.0 <0.9.0;

interface IToken {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function amountForEth(uint256 ethAmount) external view returns (uint256 tokenAmount);
}
