// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GoldenCaskClub {
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Anti-whale mechanism
    uint256 public maxTransactionAmount;

    // Anti-bot mechanism
    mapping(address => bool) private _isBot;
    address private _owner;

    // Tax rates for buys and sells
    uint8 public buyTaxPercentage = 6;
    uint8 public sellTaxPercentage = 12;

    // Tax rates allocation
    uint8 public liquidityTaxPercentage = 2;
    uint8 public burnTaxPercentage = 2;
    uint8 public marketingTaxPercentage = 7; // Updated marketing tax for sells

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        name = "GoldenCaskClub";
        symbol = "GCC";
        decimals = 18;
        totalSupply = 1000000000 * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        maxTransactionAmount = totalSupply / 100; // Set maximum transaction amount to 1% of total supply
        _owner = msg.sender;
    }

    modifier isNotBot() {
        require(!_isBot[msg.sender], "Bot address is not allowed.");
        _;
    }

    function transfer(address to, uint256 value) public isNotBot returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance.");

        if (msg.sender != _owner && to != _owner) {
            require(value <= maxTransactionAmount, "Exceeds maximum transaction amount.");
        }

        uint256 taxAmount;
        if (msg.sender == _owner) {
            // No tax for token transfers by the contract owner
            taxAmount = 0;
        } else {
            taxAmount = (value * buyTaxPercentage) / 100;
        }

        uint256 transferAmount = value - taxAmount;

        balanceOf[msg.sender] -= value;
        balanceOf[to] += transferAmount;

        handleTax(taxAmount);

        emit Transfer(msg.sender, to, transferAmount);
        return true;
    }

    function approve(address spender, uint256 value) public isNotBot returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public isNotBot returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance.");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance.");

        if (from != _owner && to != _owner) {
            require(value <= maxTransactionAmount, "Exceeds maximum transaction amount.");
        }

        uint256 taxAmount;
        if (from == _owner) {
            // No tax for token transfers by the contract owner
            taxAmount = 0;
        } else {
            taxAmount = (value * sellTaxPercentage) / 100;
        }

        uint256 transferAmount = value - taxAmount;

        balanceOf[from] -= value;
        balanceOf[to] += transferAmount;

        handleTax(taxAmount);

        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, transferAmount);
        return true;
    }

    // Calculate tax amount based on the tax percentage
    function handleTax(uint256 taxAmount) private {
        uint256 liquidityTax = (taxAmount * liquidityTaxPercentage) / 100;
        uint256 burnTax = (taxAmount * burnTaxPercentage) / 100;
        uint256 marketingTax = (taxAmount * marketingTaxPercentage) / 100;

        // Handle liquidity tax distribution (you can implement your liquidity pool functionality here)
        // Handle burn tax (you can implement your token burning functionality here)
        // Handle marketing tax (you can implement your marketing fund distribution here)
        // Note: The specific implementations for these functions are omitted in this example.
    }

    // Anti-whale mechanism: Set the maximum transaction amount
    function setMaxTransactionAmount(uint256 amount) external {
        require(msg.sender == _owner, "Only owner can set the maximum transaction amount.");
        maxTransactionAmount = amount;
    }

    // Anti-bot mechanism: Add or remove bot addresses
    function addBotAddress(address botAddress) external {
        require(msg.sender == _owner, "Only owner can add bot addresses.");
        _isBot[botAddress] = true;
    }

    function removeBotAddress(address botAddress) external {
        require(msg.sender == _owner, "Only owner can remove bot addresses.");
        _isBot[botAddress] = false;
    }
}
