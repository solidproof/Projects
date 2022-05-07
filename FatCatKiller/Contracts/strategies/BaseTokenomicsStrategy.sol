// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract BaseTokenomicsStrategy {
    IFCKToken internal _token;
    address private _charityWallet;
    address private _operationslWallet;
    address private _marketingWallet;

    constructor(
        IFCKToken token,
        address charityWallet,
        address operationsWallet,
        address marketingWallet
    ) {
        _token = token;
        _charityWallet = charityWallet;
        _operationslWallet = operationsWallet;
        _marketingWallet = marketingWallet;
    }

    receive() external payable {
        if (msg.value > 0) {
            _distribute(msg.value);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            _distribute(msg.value);
        }
    }

    function _distribute(uint256 amount) internal returns (bool) {
        uint8 totalDistribute = _token.transferTotalFee() -
            _token.transferBurnFee();
        uint16 charityFee = (_token.transferCharityFee() *
            _token.feeDenominator()) / totalDistribute;
        uint16 operatingFee = (_token.transferOperatingFee() *
            _token.feeDenominator()) / totalDistribute;

        uint256 charityAmount = Math.ceilDiv(
            amount * charityFee,
            _token.feeDenominator()
        );
        uint256 operatingAmount = Math.ceilDiv(
            amount * operatingFee,
            _token.feeDenominator()
        );
        uint256 marketingAmount = amount - charityAmount - operatingAmount;

        (bool charityRes, ) = payable(_charityWallet).call{
            value: charityAmount,
            gas: 30000
        }("");
        (bool operatingRes, ) = payable(_operationslWallet).call{
            value: operatingAmount,
            gas: 30000
        }("");
        (bool marketingRes, ) = payable(_marketingWallet).call{
            value: marketingAmount,
            gas: 30000
        }("");

        return charityRes && operatingRes && marketingRes;
    }
}
