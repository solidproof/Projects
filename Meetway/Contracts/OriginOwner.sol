// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/*
    originOwner should send txs only to trusted contracts
    DANGER: problem with fallback
*/
contract OriginOwner {
    event ChangeOriginOwner(
        address originOwner
    );

    modifier onlyOriginOwner()
    {
        require(tx.origin == _originOwner, "OriginOwner: access denied");
        _;
    }

    address private _originOwner;

    constructor()
    {
        _originOwner = tx.origin;
    }

    function _changeOriginOwner(
        address originOwner_
    )
    internal
    {
        _originOwner = originOwner_;
        emit ChangeOriginOwner(originOwner_);
    }

    function _removeOriginOwner()
    internal
    {
        _changeOriginOwner(address(0x0));
    }

    function changeOriginOwner(
        address payable originOwner_
    )
    external
    onlyOriginOwner
    {
        _changeOriginOwner(originOwner_);
    }

    function removeOriginOwner()
    external
    onlyOriginOwner
    {
        _removeOriginOwner();
    }

    function originOwner()
    external
    view
    returns (address)
    {
        return _originOwner;
    }

    function isOriginOwner()
    public
    view
    returns (bool)
    {
        return _originOwner == tx.origin;
    }
}
