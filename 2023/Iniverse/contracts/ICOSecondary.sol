// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

interface IUSDT {
    function transfer(address, uint) external;
    function transferFrom(address, address, uint) external;
    function allowance(address, address) external returns (uint);
    function balanceOf(address) external returns (uint);
}

contract ICOSecondary is ReentrancyGuard, Ownable {

    using SafeCast for uint256;
    IUSDT public immutable _usdtToken;

    event SecondaryCurrencyReceived(address indexed purchaser, uint256 currency_amount);
    event SecondaryUsdtReceived(address indexed purchaser, uint256 usdt_amount);

    address payable private _wallet;

    constructor(address payable wallet, address usdtAddress) {
        require(wallet != address(0), "Pre-Sale: wallet is the zero address");
        _wallet = wallet;
        _usdtToken = IUSDT(usdtAddress);
    }

    receive() external payable {
        buyTokensBySecondaryCurrency(_msgSender());
    }

    function buyTokensBySecondaryCurrency(address beneficiary) public nonReentrant payable {
        emit SecondaryCurrencyReceived(beneficiary, msg.value);   
    }

    function buyTokensByUSDT(uint256 usdtAmount) public nonReentrant {
        uint256 ourAllowance = _usdtToken.allowance(
            _msgSender(),
            address(this)
        );
        require(usdtAmount <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(_usdtToken).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                address(this),
                usdtAmount
            )
        );
        require(success, "Token payment failed");
        emit SecondaryUsdtReceived(_msgSender(), usdtAmount);
    }

    function withdrawCurrency() external onlyOwner onlyContractHasCurrency {
        payable(_wallet).transfer(address(this).balance);
    }

    function withdrawUsdt() external onlyOwner onlyContractHasUSDT {
        uint balance = _usdtToken.balanceOf(address(this));
        _usdtToken.transfer(_wallet, balance);
    }

    modifier onlyContractHasUSDT() {
        require(_usdtToken.balanceOf(address(this)) > 0, 'Pre-Sale: Contract has no usdt.');
    	_;
    }

    modifier onlyContractHasCurrency() {
        require(address(this).balance > 0, 'Pre-Sale: Contract has no main currency.');
        _;
    }
}