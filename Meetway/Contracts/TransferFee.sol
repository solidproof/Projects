// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./DexPair.sol";


contract TransferFee {
    bytes4 private constant FACTORY_SELECTOR = bytes4(keccak256(bytes('factory()')));

    event SetTransferFee(
        STransferFee transferFee
    );

    struct STransferFee {
        address to;
        uint buy;
        uint sell;
        uint normal;
    }

    STransferFee private _transferFee;
    uint constant private DEMI = 100;

    function _setTransferFee(
        address to_,
        uint buyFee_,
        uint sellFee_,
        uint normalFee_
    )
    internal
    {
        require(buyFee_ <= 1, "TransferFee: fee must be less or equal 10%");
        require(sellFee_ <= 10, "TransferFee: fee must be less or equal 20%");
        require(normalFee_ <= 2, "TransferFee: fee must be less or equal 2%");
        _transferFee.to = to_;
        _transferFee.buy = buyFee_;
        _transferFee.sell = sellFee_;
        _transferFee.normal = normalFee_;
        emit SetTransferFee(_transferFee);
    }

    function _getTransferFee(
        address sender_,
        address recipient_,
        uint256 amount_
    )
    internal
    returns (uint)
    {
        if (DexPair._isPair(recipient_)) {
            return amount_ * _transferFee.sell / DEMI;
        } else {
            if (DexPair._isPair(sender_)) {
                return amount_ * _transferFee.buy / DEMI;
            } else {
                return amount_ * _transferFee.normal / DEMI;
            }
        }
    }

    function _getTransferFeeTo()
    internal
    view
    returns (address)
    {
        return _transferFee.to;
    }

    function transferFee()
    public
    view
    returns (STransferFee memory)
    {
        return _transferFee;
    }
}