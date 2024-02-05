// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./ITokenomicsStrategy.sol";
import "./BaseTokenomicsStrategy.sol";
import "../token/IFCKToken.sol";

contract ManualTokenomicsStrategy is
    ITokenomicsStrategy,
    BaseTokenomicsStrategy
{
    address private _tokensRecipient;

    constructor(
        IFCKToken token,
        address charityWallet,
        address operationsWallet,
        address marketingWallet,
        address tokensRecipient
    )
        BaseTokenomicsStrategy(
            token,
            charityWallet,
            operationsWallet,
            marketingWallet
        )
    {
        _tokensRecipient = tokensRecipient;
    }

    function process() external override {
        if (msg.sender != address(_token)) {
            _token.transferFrom(
                address(_token),
                _tokensRecipient,
                _token.balanceOf(address(_token))
            );
        }
    }
}
