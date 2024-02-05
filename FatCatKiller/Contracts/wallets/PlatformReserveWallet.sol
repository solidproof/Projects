// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "../governance/IVoting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlatformReserveWallet is Ownable {
    IFCKToken private _token;
    IVoting private _voting;
    uint256 private _initialLiquidityRemainder;

    constructor(IFCKToken token, IVoting voting) {
        _token = token;
        _voting = voting;
        _initialLiquidityRemainder = 90 * (10**12) * (10**token.decimals()); // 90 000 000 000 000
        _token.approve(address(voting), type(uint256).max);
    }

    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external onlyOwner {
        require(
            _token.balanceOf(address(this)) >= amount,
            "PlatformReserveWallet: Insufficient funds"
        );
        _voting.createProposal(recipient, amount, endsAt);
    }

    function completeProposal() external onlyOwner {
        _voting.complete();
    }

    function transferTokens(address recipient, uint256 amount)
        external
        onlyOwner
    {
        require(
            _initialLiquidityRemainder >= amount,
            "PlatformReserveWallet: Insufficient funds"
        );
        _initialLiquidityRemainder -= amount;
        _token.transfer(recipient, amount);
    }
}
