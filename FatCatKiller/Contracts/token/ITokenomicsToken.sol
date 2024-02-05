// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../strategies/ITokenomicsStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ITokenomicsToken is IERC20, IERC20Metadata {
    function feeDenominator() external view returns (uint16);

    function maxSellBuyFee() external view returns (uint8);

    function sellBuyBurnFee() external view returns (uint8);

    function sellBuyCharityFee() external view returns (uint8);

    function sellBuyOperatingFee() external view returns (uint8);

    function sellBuyMarketingFee() external view returns (uint8);

    function sellBuyTotalFee() external view returns (uint8);

    function setSellBuyFee(
        uint8 sellBuyCharityFee_,
        uint8 sellBuyOperatingFee_,
        uint8 sellBuyMarketingFee_
    ) external;

    function maxTransferFee() external view returns (uint8);

    function transferBurnFee() external view returns (uint8);

    function transferCharityFee() external view returns (uint8);

    function transferOperatingFee() external view returns (uint8);

    function transferMarketingFee() external view returns (uint8);

    function transferTotalFee() external view returns (uint8);

    function setTransferFee(
        uint8 transferCharityFee_,
        uint8 transferOperatingFee_,
        uint8 transferMarketingFee_
    ) external;

    function process() external;

    function isFeeExempt(address account) external view returns (bool);

    function setFeeExempt(address account, bool exempt) external;

    function strategy() external view returns (ITokenomicsStrategy strategy_);

    function setStrategy(ITokenomicsStrategy strategy_) external;

    function dexPair() external view returns (address);

    function setDexPair(address dexPair_) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;

    event FeePayment(address indexed payer, uint256 fee);

    event Burnt(address indexed account, uint256 amount);
}
