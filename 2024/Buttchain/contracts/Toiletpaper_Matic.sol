//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/*

████████╗░█████╗░██╗██╗░░░░░███████╗████████╗██████╗░░█████╗░██████╗░███████╗██████╗░
╚══██╔══╝██╔══██╗██║██║░░░░░██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
░░░██║░░░██║░░██║██║██║░░░░░█████╗░░░░░██║░░░██████╔╝███████║██████╔╝█████╗░░██████╔╝
░░░██║░░░██║░░██║██║██║░░░░░██╔══╝░░░░░██║░░░██╔═══╝░██╔══██║██╔═══╝░██╔══╝░░██╔══██╗
░░░██║░░░╚█████╔╝██║███████╗███████╗░░░██║░░░██║░░░░░██║░░██║██║░░░░░███████╗██║░░██║
░░░╚═╝░░░░╚════╝░╚═╝╚══════╝╚══════╝░░░╚═╝░░░╚═╝░░░░░╚═╝░░╚═╝╚═╝░░░░░╚══════╝╚═╝░░╚═╝

███╗░░░███╗░█████╗░████████╗██╗░█████╗░
████╗░████║██╔══██╗╚══██╔══╝██║██╔══██╗
██╔████╔██║███████║░░░██║░░░██║██║░░╚═╝
██║╚██╔╝██║██╔══██║░░░██║░░░██║██║░░██╗
██║░╚═╝░██║██║░░██║░░░██║░░░██║╚█████╔╝
╚═╝░░░░░╚═╝╚═╝░░╚═╝░░░╚═╝░░░╚═╝░╚════╝░

https://buttchain.xyz

© Copyright ButtChain 2024 – All Rights Reserved

*/

contract Toiletpaper_Matic is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint256;

    // ---- Events ----
    event deposit_event(
        uint256 amount_in,
        address indexed recipient_address
    );

    event withdraw_for_event(
        uint256 amount_out,
        address indexed recipient_address
    );

    event withdraw_event(
        uint256 amount_out,
        address indexed recipient_address
    );

    // ---- Constants ----
    address public constant Deposit_Address = 0x899aBE2FE7390334727B59A1c1C2DA467Fa6D67B;

    uint256 public constant Total_Transfer_Tax = 100; // div 1000
    uint256 public constant Royalty_Transfer_Tax = 50; // div 1000
    uint256 public constant Liquidity_Transfer_Tax = 50; // div 1000

    // ---- Constructor ----
    function initialize()
        public
        initializer
    {
        __ERC20_init("Toiletpaper_Matic", "TP_MATIC");
        __Ownable_init();
    }

    // ---- Admin Functions ----
    address public Butcoin_Address;
    address public Liquidity_Pool_Address;
    
    function update_interfaces(
        address butcoin_address,
        address liquidity_pool_address
        )
        public
        onlyOwner
    {
        Butcoin_Address = butcoin_address;
        Liquidity_Pool_Address = liquidity_pool_address;
    }

    // ---- Public Functions ----
    function deposit(
        )
        public payable
    {
        _mint(msg.sender, msg.value);
        emit deposit_event(msg.value, msg.sender);
    }

    function withdraw(
        uint256 amount
        )
        public
    {
        require(
            balanceOf(msg.sender) >= amount,
            "You have unsufficient T_MATIC for requested withdrawl."
        );

        _burn(msg.sender, amount);
        msg.sender.transfer(amount);

        emit withdraw_event(amount, msg.sender);
    }

    function withsraw_for_user(
        address user
        )
        public
    {
        require(
            msg.sender == Butcoin_Address,
            "Unauthorized access"
        );

        uint256 amount = balanceOf(user);
        _burn(user, amount);
        payable(user).transfer(amount);

        emit withdraw_for_event(amount, user);
    }

    // ---- Override Functions ----
    function transfer(
        address recipient,
        uint256 amount
        )
        public override
        returns (bool)
    {
        if (msg.sender == Liquidity_Pool_Address) {
            uint256 transfer_amount = handle_tax(msg.sender, amount);
            return super.transfer(recipient, transfer_amount);
        }

        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
        )
        public override
        returns (bool)
    {
        if (sender == Liquidity_Pool_Address) {
            uint256 transfer_amount = handle_tax(sender, amount);
            return super.transferFrom(sender, recipient, transfer_amount);
        }

        return super.transferFrom(sender, recipient, amount);
    }

    // ---- Internal Functions ----
    function handle_tax(
        address sender,
        uint256 amount
        )
        internal
        returns (uint256)
    {
        // uint256 royalty_amount = Royalty_Transfer_Tax * amount / 1000;
        // uint256 liquidity_amount = Liquidity_Transfer_Tax * amount / 1000;

        uint256 royalty_amount = Royalty_Transfer_Tax.mul(amount).div(1000);
        uint256 liquidity_amount = Liquidity_Transfer_Tax.mul(amount).div(1000);

        _burn(sender, royalty_amount);
        payable(Deposit_Address).transfer(royalty_amount);

        _transfer(sender, Butcoin_Address, liquidity_amount);

        // return amount - royalty_amount - liquidity_amount;
        return amount.sub(royalty_amount).sub(liquidity_amount);
    }

    // ---- Extra / Fallback ----
    receive() external payable {
        deposit();
    }

    fallback() external payable {
        deposit();
    }

}