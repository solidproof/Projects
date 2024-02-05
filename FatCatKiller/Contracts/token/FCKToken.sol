// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./TokenomicsToken.sol";
import "./IFCKToken.sol";
import "../governance/IVoting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract FCKToken is IFCKToken, TokenomicsToken, Pausable {
    uint256 private _launchedAt;
    uint256 private _startTime;
    uint256 public cap;

    uint256 private _teamAndAdvisorsCap;
    uint256 private _marketingReserveCap;
    uint256 private _platformReserveCap;
    uint256 private _minted;

    uint256 private _maxTxAmount;
    uint256 private _maxWalletBalance;
    mapping(address => bool) private _isTxLimitExempt;

    IVoting private _voting;

    constructor(uint256 startTime) TokenomicsToken("Fat Cat Killer", "$KILLER") {
        cap = 900 * (10**12) * (10**decimals()); // 900 000 000 000 000
        _teamAndAdvisorsCap = 288 * (10**12) * (10**decimals()); // 288 000 000 000 000
        _marketingReserveCap = 162 * (10**12) * (10**decimals()); // 162 000 000 000 000
        _platformReserveCap = 450 * (10**12) * (10**decimals()); // 450 000 000 000 000
        _maxTxAmount = 100 * (10**6) * (10**decimals()); // 100 000 000;
        _maxWalletBalance = 100 * (10**6) * (10**decimals()); // 100 000 000;
        _startTime = startTime;
    }

    function teamAndAdvisorsCap() external view override returns (uint256) {
        return _teamAndAdvisorsCap;
    }

    function marketingReserveCap() external view override returns (uint256) {
        return _marketingReserveCap;
    }

    function platformReserveCap() external view override returns (uint256) {
        return _platformReserveCap;
    }

    function launchedAt() external view override returns (uint256) {
        return _launchedAt;
    }

    function launched() external view override returns (bool) {
        return _launchedAt > 0;
    }

    function launch() external override returns (bool) {
        if (_launchedAt == 0 && block.timestamp >= _startTime) {
            _launchedAt = block.timestamp;
            emit Launched(_launchedAt);
            return true;
        }
        return false;
    }

    function mint(address account, uint256 amount) external override onlyOwner {
        require(_minted + amount <= cap, "It's impossible mint more than cap");
        _mint(account, amount);
        _minted += amount;
        emit Minted(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
        require(this.launched(), "FCKToken: Not yet launched");
        require(!paused(), "ERC20Pausable: token transfer while paused");

        if (address(_voting) != address(0)) {
            require(
                _voting.canTransfer(from),
                "Voting: there is no possibility for the participant to transfer tokens while voting is in progress"
            );
        }

        require(amount <= _maxTxAmount || _isTxLimitExempt[from], "FCKToken: TX Limit Exceeded");
        require(
                (balanceOf(to) + amount) <= _maxWalletBalance || this.isFeeExempt(from),
                "FCKToken: Total Holding is currently limited, you can not buy that much."
            );
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function setVoting(IVoting voting) external onlyOwner {
        _voting = voting;
        _isTxLimitExempt[address(voting)] = true;
    }

    function maxTxAmount() external view override returns (uint256) {
        return _maxTxAmount;
    }

    function setMaxTxAmount(uint256 maxTxAmount_) external override onlyOwner {
        _maxTxAmount = maxTxAmount_;
    }

    function maxWalletBalance() external view override returns (uint256) {
        return _maxWalletBalance;
    }

    function setMaxWalletBalance(uint256 maxWalletBalance_)
        external
        override
        onlyOwner
    {
        _maxWalletBalance = maxWalletBalance_;
    }

    function isTxLimitExempt(address account)
        external
        view
        override
        returns (bool)
    {
        return _isTxLimitExempt[account];
    }

    function setIsTxLimitExempt(address recipient, bool exempt)
        external
        override
        onlyOwner
    {
        _isTxLimitExempt[recipient] = exempt;
    }
}
