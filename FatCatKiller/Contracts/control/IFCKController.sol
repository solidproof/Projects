// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IFCKController {
    // distribution
    function distributeTeam(address account, uint256 amount) external;

    function distributeMarketing(address account, uint256 amount) external;

    // token
    function tokenPause() external;

    function tokenUnpause() external;

    // tokenomics
    function setSellBuyFee(
        uint8 sellBuyCharityFee_,
        uint8 sellBuyOperatingFee_,
        uint8 sellBuyMarketingFee_
    ) external;

    function setTransferFee(
        uint8 transferCharityFee_,
        uint8 transferOperatingFee_,
        uint8 transferMarketingFee_
    ) external;

    function setFeeExempt(address account, bool exempt) external;

    // platform reserve wallet
    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external;

    function completeProposal() external;

    function platformReserveTransferTokens(address recipient, uint256 amount)
        external;

    // anti bot
    function setMaxTxAmount(uint256 maxTxAmount_) external;

    function setMaxWalletBalance(uint256 maxWalletBalance_) external;

    function setIsTxLimitExempt(address recipient, bool exempt) external;
}
