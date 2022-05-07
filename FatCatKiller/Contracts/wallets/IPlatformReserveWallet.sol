// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPlatformReserveWallet {
    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external;

    function completeProposal() external;

    function transferTokens(address recipient, uint256 amount) external;
}
