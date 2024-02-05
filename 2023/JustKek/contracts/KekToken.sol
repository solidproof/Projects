// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KekToken is ERC20, ERC20Burnable, Ownable {
    using Address for address payable;
    using SafeMath for uint256;

    address public treasury;
    uint32 public tax = 3;

    uint256 public maxWalletAmount;
    address public uniswapV2Pair;
    bool public maxWalletAmountEnabled = true;

    event TreasuryAddressUpdated(address newTreasury);
    event UniswapV2PairUpdated(address newUniswapV2Pair);
    event TaxUpdated(uint256 taxAmount);
    event MaxWalletAmountCheckPassed(address recipient, uint256 amount);
    event MaxWalletToggled(bool enabled);

    constructor(uint256 supply, address _treasury) ERC20("Kek", "KEK") {
        _mint(msg.sender, supply.mul(10 ** decimals()));
        maxWalletAmount = supply.mul(10 ** decimals()).div(100);
        treasury = _treasury;
    }

    function setTreasuryAddress(address _treasury) external onlyOwner {
        require(
            _treasury != address(0),
            "Zero address cannot be set as Treasury"
        );
        treasury = _treasury;

        emit TreasuryAddressUpdated(_treasury);
    }

    function setUniswapV2Pair(address _uniswapV2Pair) external onlyOwner {
        require(
            _uniswapV2Pair != address(0),
            "Zero address cannot be set as UniswapV2Pair"
        );
        uniswapV2Pair = _uniswapV2Pair;
        emit UniswapV2PairUpdated(_uniswapV2Pair);
    }

    function toggleWalletLimit(bool enabled) external onlyOwner {
        maxWalletAmountEnabled = enabled;
        emit MaxWalletToggled(enabled);
    }

  function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (uniswapV2Pair == address(0)) {
            require(from == owner() || to == owner(), "Trading has not started");
            return;
        }

        if (maxWalletAmountEnabled && from == uniswapV2Pair) {
            require(
                super.balanceOf(to) + amount <= maxWalletAmount,
                "Forbidden. Wallet maximum amount exceeded"
            );
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 feeAmount = amount.mul(tax).div(100);
        uint256 netAmount = amount.sub(feeAmount);

        super._transfer(sender, recipient, netAmount);
        super._transfer(sender, treasury, feeAmount);
    }

    function setTax(uint32 _tax) external onlyOwner {
        require(_tax <= 5, "Maximum tax allowed is 5%");
        tax = _tax;
        emit TaxUpdated(tax);
    }

    receive() external payable {}
}
