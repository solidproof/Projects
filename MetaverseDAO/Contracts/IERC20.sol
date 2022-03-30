// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface IERC20 {

    /**
     * @dev returns the amount of tokens in existence.
     */
    function totalSupply() external view returns(uint256);

    /**
     * @dev returns the amount of tokens owned by account
     */
    function balanceOf(address account) external view returns(uint256);

    /**
     * @dev moves amount tokens from the call's account to recipient.
     * returns a bool value indicating whether the operation successed.
     */
    function transfer(address recipient, uint256 amount) external returns(bool);

    /**
     * @dev returns the remaining number of tokens that spender will be allowed to spend
     * on behalf of owner through {transferFrom}. this is zero by default.
     *
     * his value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns(uint256);

    /**
     * @dev sets amount as the allowance of spender over the caller's tokens.
     * returns a bool value indicating whether the operation is successed.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns(bool);

    /**
     * @dev moves amount tokens from sender to recipient using the allowance mechanism.
     * amount is then deducted from the caller's allowance.
     *
     * returns a boolean value indicating whether the operation successed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

}