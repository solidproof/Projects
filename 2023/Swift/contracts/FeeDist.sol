// SPDX-License-Identifier: MIT
// ethereum
// impl: 0x309c656a95c04A9a7b7E055Cce16A733cf40D40b
// proxy: 0x07a844f086E33eE8fef9Bea54dEaf329880F13f7
// arbitrum
// impl: 0x3c86Fd44a3713383037f60ed9a4494Be093b3EE5
// proxy: 0x00DD2Caa56fAfbab7529147Ab5d2763978f50e8D
// bsc
// impl: 0x3c86Fd44a3713383037f60ed9a4494Be093b3EE5
// proxy: 0x00DD2Caa56fAfbab7529147Ab5d2763978f50e8D
// base
// impl: 0x3c86Fd44a3713383037f60ed9a4494Be093b3EE5
// proxy: 0x00DD2Caa56fAfbab7529147Ab5d2763978f50e8D

pragma solidity ^0.8.0;

contract FeeDist {
    struct FeeItem {
        address user;
        uint256 share;
    }

    uint256 constant RESOLUTION = 10000;

    bool initialized;
    bool isEntering;
    address public owner;

    uint256 public totalAmount;

    FeeItem[] feeItems;

    event TransferOwnership(address indexed oldOwner, address indexed newOwner);

    modifier nonReentrant() {
        require(!isEntering, "Already Entered");
        isEntering = true;
        _;
        isEntering = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner");
        _;
    }

    function initialize() external {
        require(!initialized, "Already Initialized");
        initialized = true;

        emit TransferOwnership(address(0), msg.sender);
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Null Address");
        emit TransferOwnership(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        emit TransferOwnership(owner, address(0));
        owner = address(0);
    }

    function setFeeItems(FeeItem[] calldata items) external onlyOwner {
        delete feeItems;
        uint256 i;
        for (i = 0; i < items.length; i ++) {
            feeItems.push(items[i]);
        }
    }

    function getFeeItems() external view returns (FeeItem[] memory) {
        return feeItems;
    }

    function deposit(address[] calldata referees) external nonReentrant payable {
        uint256 totalValue = msg.value;

        totalAmount += totalValue;
        uint256 spent = 0;
        uint256 i = 0;
        for (i = 0; i < feeItems.length; i ++) {
            FeeItem storage fi = feeItems[i];
            uint256 amount = totalValue * fi.share / RESOLUTION;
            spent += pay(fi.user, amount);
        }

        if (spent < totalValue) {
            totalValue = (totalValue - spent);
            for (i = 0; i < referees.length; i ++) {
                uint256 amount = totalValue / referees.length;
                spent += pay(referees[i], amount);
            }
        }
    }

    receive() external payable {
    }

    function pay(address user, uint256 amount) internal returns (uint256) {
        (bool success, ) = payable(user).call{value: amount}("");
        if (!success) {
            return 0;
        }
        return amount;
    }
}

