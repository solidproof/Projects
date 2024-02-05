// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IFeeHandler {
    function getFeeInfo(address sender, address recipient, uint256 amount) external returns (uint256);

    function onFeeReceived(address sender, address recipient, uint256 amount, uint256 fee) external;
}

contract DonutSwap is Context, Ownable, ERC20 {
    using Address for address;

    IFeeHandler public feeHandler;
    uint256 public constant MAX_TRANSFER_FEE = 1000; // 10%

    event FeeHandlerUpdated(address indexed oldFeeHandler, address indexed newFeeHandler);

    constructor(address _owner) ERC20("DonutSwap", "DONUT") {
        _mint(_owner, 500_000_000e18);
    }

    function setFeeHandler(IFeeHandler _feeHandler) external onlyOwner {
        emit FeeHandlerUpdated(address(feeHandler), address(_feeHandler));
        feeHandler = _feeHandler;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        uint256 amountToTransfer = amount;

        if (address(feeHandler).isContract())
            try feeHandler.getFeeInfo(sender, recipient, amount) returns (uint256 fee) {
                if (fee > 0 && fee <= MAX_TRANSFER_FEE) {
                    fee = (amount * fee) / 10000;
                    amountToTransfer -= fee;
                    super._transfer(sender, address(feeHandler), fee);
                    try feeHandler.onFeeReceived(sender, recipient, amount, fee) {} catch {}
                }
            } catch {}
        super._transfer(sender, recipient, amountToTransfer);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}