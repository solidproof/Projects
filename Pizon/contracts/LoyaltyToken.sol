// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LString {
    function concatenate(
        string memory a,
        string memory b
    )
        public
        pure
        returns(string memory)
    {
        return string(abi.encodePacked(a,' ',b));
    } 
}

interface ILockableERC20 is IERC20 {
    function fullBalanceOf(
        address account
    )
        external
        view
        returns (uint256);

    function lockedIncTotalSupply()
        external
        view
        returns(uint);
}

contract LoyaltyToken is ERC20 {
    using LString for string;

    string constant public VERSION = "mainnet-arbitrum-v2";

    modifier onlyMainToken()
    {
        require(msg.sender == address(_mainToken), "onlyMainToken");
        _;
    }

    struct SBalance{
        uint main;
        uint loyalty;
        uint updatedAt;
    }

    mapping(address => SBalance) private _balanceDataOf;

    ILockableERC20 immutable private _mainToken;

    address constant private ZERO_ADDRESS = address(0x0);

    SBalance private _supplyData;

    constructor (
        ILockableERC20 mainToken_
    )
        ERC20(
            LString.concatenate(ERC20(address(mainToken_)).name(), "Loyalty"),
            "LOYALTY"
        )
    {
        _mainToken = mainToken_;
        _supplyData.main = mainToken_.lockedIncTotalSupply();
        _supplyData.updatedAt = block.timestamp;
    }

    function _beforeTokenTransfer(
        address ,
        address ,
        uint256 
    )
        internal
        override
    {
        require(false, "untransferable token");
    }

    function _updateTotalSupply()
        internal
    {
        uint pastTime = block.timestamp - _supplyData.updatedAt;
        _supplyData.loyalty = _supplyData.loyalty + _supplyData.main * pastTime;
        _supplyData.updatedAt = block.timestamp;
        _supplyData.main = _mainToken.lockedIncTotalSupply();
    }

    function _updateBalance(
        address account_
    )
        internal
    {
        if (account_ != ZERO_ADDRESS) {
            SBalance storage balanceData = _balanceDataOf[account_];
            balanceData.loyalty = balanceOf(account_);
            balanceData.updatedAt = block.timestamp;
            balanceData.main = _mainToken.fullBalanceOf(account_);
        } else {
            _updateTotalSupply();
        }
    }

    function afterTransferCallback(
        address from_,
        address to_,
        uint256
    )
        external
        onlyMainToken
    {
        _updateBalance(from_);
        _updateBalance(to_);
    }

    function balanceOf(
        address account_
    )
        public
        view
        override
        returns (uint256)
    {
        SBalance memory balanceData = _balanceDataOf[account_];
        uint pastTime = block.timestamp - balanceData.updatedAt;
        return balanceData.loyalty + balanceData.main * pastTime;
    }

    function totalSupply()
        public
        view
        override
        returns (uint256)
    {
        uint pastTime = block.timestamp - _supplyData.updatedAt;
        return _supplyData.loyalty + _supplyData.main * pastTime;
    }

    function mainToken()
        external
        view
        returns(ILockableERC20)
    {
        return _mainToken;
    }
}