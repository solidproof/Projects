// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ProtocolEarnings is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public dividendsWallet;
    address public buybackAndBurnWallet;
    address public operatingFundsWallet;

    uint256 public constant sharePrecision = 10000;
    uint256 public dividendsShare = 5625;
    uint256 public buybackAndBurnShare = 3125;

    constructor(address dividends, address buyback, address operating) {
        dividendsWallet = dividends;
        buybackAndBurnWallet = buyback;
        operatingFundsWallet = operating;
    }

    event Distribute(IERC20 token, uint256 dividendsAmount, uint256 buybackAndBurnAmount, uint256 operatingAmount);

    function updateBuybackAndBurnWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "zero address");
        buybackAndBurnWallet = newWallet;
    }

    function updateDevelopmentFundsWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "zero address");
        operatingFundsWallet = newWallet;
    }

    function updateDividendsWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "zero address");
        dividendsWallet = newWallet;
    }

    function distributeShares(IERC20 token) external onlyOwner {
        uint256 _balance = token.balanceOf(address(this));

        uint256 dividendsAmount = _balance.mul(dividendsShare).div(sharePrecision);
        uint256 buybackAndBurnAmount = _balance.mul(buybackAndBurnShare).div(sharePrecision);
        uint256 operatingFundsAmount = _balance.sub(dividendsAmount).sub(buybackAndBurnAmount);

        if (dividendsAmount > 0) token.safeTransfer(dividendsWallet, dividendsAmount);
        if (buybackAndBurnAmount > 0) token.safeTransfer(buybackAndBurnWallet, buybackAndBurnAmount);
        if (operatingFundsAmount > 0) token.safeTransfer(operatingFundsWallet, operatingFundsAmount);

        emit Distribute(token, dividendsAmount, buybackAndBurnAmount, operatingFundsAmount);
    }

    function updateShares(uint256 dividendsShare_, uint256 buybackAndBurnShare_) external onlyOwner {
        require(dividendsShare_.add(buybackAndBurnShare_) <= sharePrecision, "invalid shares");
        dividendsShare = dividendsShare_;
        buybackAndBurnShare = buybackAndBurnShare_;
    }

    function safeEmergencyWithdraw(IERC20 token, address to) external onlyOwner {
        token.safeTransfer(to, token.balanceOf(address(this)));
    }
}
