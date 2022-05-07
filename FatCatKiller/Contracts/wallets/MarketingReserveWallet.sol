// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "./LockupWallet.sol";
import "./IDistributionWallet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketingReserveWallet is IDistributionWallet, LockupWallet, Ownable {
    constructor(IFCKToken token_) LockupWallet(token_) {}

    function distribute(address account, uint256 amount)
        external
        override
        onlyOwner
    {
        _distribute(account, amount);
    }

    function transferBalanceToPlatformReserve() public pure {
        revert("Method is not supported for this wallet!");
    }
}
