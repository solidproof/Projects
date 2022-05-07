// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../token/IFCKToken.sol";
import "../wallets/IDistributionWallet.sol";
import "../wallets/IPlatformReserveWallet.sol";
import "./IFCKController.sol";

contract FCKController is IFCKController, Ownable {
    IFCKToken private _token;

    IDistributionWallet private _teamAndAdvisorsWallet;
    IDistributionWallet private _marketingReserveWallet;
    IPlatformReserveWallet private _platformReserveWallet;
    bool private _started;

    modifier onlyStarted() {
        require(_started, "Not yet started");
        _;
    }

    constructor(
        IFCKToken token_,
        IDistributionWallet teamAndAdvisorsWallet_,
        IDistributionWallet marketingReserveWallet_,
        IPlatformReserveWallet platformReserveWallet_
    ) {
        _token = token_;
        _teamAndAdvisorsWallet = teamAndAdvisorsWallet_;
        _marketingReserveWallet = marketingReserveWallet_;
        _platformReserveWallet = platformReserveWallet_;
    }

    // mint tokens and start process
    function start() external {
        require(!_started, "Already started");
        _token.mint(
            address(_teamAndAdvisorsWallet),
            _token.teamAndAdvisorsCap()
        );
        _token.mint(
            address(_marketingReserveWallet),
            _token.marketingReserveCap()
        );
        _token.mint(
            address(_platformReserveWallet),
            _token.platformReserveCap()
        );
        _token.setMaxTxAmount(_token.totalSupply());
        _token.setMaxWalletBalance(_token.totalSupply());
        _started = true;
    }

    function tokenPause() external override onlyOwner {
        _token.pause();
    }

    function tokenUnpause() external override onlyOwner {
        _token.unpause();
    }

    // distribute tokens
    function distributeTeam(address account, uint256 amount)
        external
        override
        onlyOwner
        onlyStarted
    {
        _teamAndAdvisorsWallet.distribute(account, amount);
    }

    function distributeMarketing(address account, uint256 amount)
        external
        override
        onlyOwner
        onlyStarted
    {
        _marketingReserveWallet.distribute(account, amount);
    }

    function setSellBuyFee(
        uint8 sellBuyCharityFee_,
        uint8 sellBuyOperatingFee_,
        uint8 sellBuyMarketingFee_
    ) external override onlyOwner {
        _token.setSellBuyFee(
            sellBuyCharityFee_,
            sellBuyOperatingFee_,
            sellBuyMarketingFee_
        );
    }

    function setTransferFee(
        uint8 transferCharityFee_,
        uint8 transferOperatingFee_,
        uint8 transferMarketingFee_
    ) external override onlyOwner {
        _token.setTransferFee(
            transferCharityFee_,
            transferOperatingFee_,
            transferMarketingFee_
        );
    }

    function setFeeExempt(address account, bool exempt)
        external
        override
        onlyOwner
    {
        _token.setFeeExempt(account, exempt);
    }

    // Platform reserve wallet
    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external override onlyOwner {
        _platformReserveWallet.createProposal(recipient, amount, endsAt);
    }

    function completeProposal() external override onlyOwner {
        _platformReserveWallet.completeProposal();
    }

    function platformReserveTransferTokens(address recipient, uint256 amount)
        external
        override
        onlyOwner
    {
        _platformReserveWallet.transferTokens(recipient, amount);
    }

    function setMaxTxAmount(uint256 maxTxAmount_) external override onlyOwner {
        _token.setMaxTxAmount(maxTxAmount_);
    }

    function setMaxWalletBalance(uint256 maxWalletBalance_)
        external
        override
        onlyOwner
    {
        _token.setMaxWalletBalance(maxWalletBalance_);
    }

    function setIsTxLimitExempt(address recipient, bool exempt)
        external
        override
        onlyOwner
    {
        _token.setIsTxLimitExempt(recipient, exempt);
    }
}
