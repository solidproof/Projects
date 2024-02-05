// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BITBOT is ERC20, Ownable {
    address private feeReceiver;
    uint256 public feeRate = 0;

    constructor(address mintTarget, address _feeReceiver) ERC20("Bitbot", "BITBOT") {
        _mint(mintTarget, 1_000_000_000 * (10 ** decimals()));
        feeReceiver = _feeReceiver;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function getTax(uint256 amount) private view returns (uint256) {
        if (feeRate == 0) {
            return 0;
        }

        return (amount / 10000) * feeRate;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 tax = getTax(amount);
        uint256 amountAfterTax = amount - tax;

        _transfer(_msgSender(), recipient, amountAfterTax);
        _transfer(_msgSender(), feeReceiver, tax);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 tax = getTax(amount);
        uint256 amountAfterTax = amount - tax;

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);

        _transfer(from, to, amountAfterTax);
        _transfer(from, feeReceiver, tax);

        return true;
    }

    function adminSetFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function adminSetFeeRate(uint256 _feeRate) public onlyOwner {
        require(_feeRate <= 10000, "BITBOT: fee rate must be less than or equal to 10000");
        feeRate = _feeRate;
    }
}