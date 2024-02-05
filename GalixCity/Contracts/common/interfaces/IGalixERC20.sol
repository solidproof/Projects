// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @title GALIX Token
 * @author GALIX Inc
 */

interface IGalixERC20 {
    //admin view
    function transfer(address _to, uint256 _value) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mintFrom(address to, uint256 amount) external;
    function mint(uint256 amount) external;
    function burnFrom(address to, uint256 amount) external;
    function addMinter(address account) external;
    function removeMinter(address account) external;
    function pause() external;
    function unpause() external;
    function freeze(address account) external;
    function unfreeze(address account) external;

    //anon view
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function burn(uint256 amount) external;
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
