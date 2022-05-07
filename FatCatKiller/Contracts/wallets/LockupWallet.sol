// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract LockupWallet {
    uint256 constant SECONDS_PER_WEEK = 7 * 24 * 60 * 60;

    uint256 public totalDistributedAmount;
    uint256 internal _totalClaimed;

    // the amount of to ens distributed during the distribution
    mapping(address => uint256) private _distributedAmount;
    // when amount has been distributed
    mapping(address => uint256) private _distributedAt;
    // claimed amount of tokens
    mapping(address => uint256) private _claimedAmount;

    uint256 private _initialPercentage = 6;
    uint256 private _weeksCountToUnlock = 12;
    uint256 private _percentagePerWeek = 2;

    IFCKToken public token;

    constructor(IFCKToken token_) {
        token = token_;
    }

    function _distribute(address account, uint256 amount) internal {
        totalDistributedAmount += amount;
        require(
            token.balanceOf(address(this)) >= totalDistributedAmount,
            "LockupWallet: Insufficient funds"
        );
        _distributedAmount[account] += amount;
        // if account has already participated in the distribution - date of distribution not changed
        if (_distributedAt[account] == 0) {
            _distributedAt[account] = block.timestamp;
        }
    }

    function distributedAmountOf(address account)
        external
        view
        returns (uint256)
    {
        return _distributedAmount[account];
    }

    function claimedAmountOf(address account) external view returns (uint256) {
        return _claimedAmount[account];
    }

    function sum(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    function availableAmountToClaim(address account, uint256 timestamp)
        external
        view
        returns (uint256)
    {
        if (token.launched()) {
            uint256 startTime = Math.max(
                token.launchedAt(),
                _distributedAt[account]
            );

            uint256 weeksFromLaunch = (timestamp - startTime) /
                SECONDS_PER_WEEK;

            uint256 percentage = _initialPercentage;

            if (weeksFromLaunch > _weeksCountToUnlock) {
                percentage +=
                    (weeksFromLaunch - _weeksCountToUnlock) *
                    _percentagePerWeek;
            }

            percentage = Math.min(100, percentage);

            uint256 availableTokens = Math.ceilDiv(
                _distributedAmount[account] * percentage,
                100
            );

            return availableTokens - _claimedAmount[account];
        }
        return 0;
    }

    function claim() external {
        uint256 amount = this.availableAmountToClaim(
            msg.sender,
            block.timestamp
        );
        if (amount > 0) {
            _claimedAmount[msg.sender] += amount;
            require(
                _claimedAmount[msg.sender] <= _distributedAmount[msg.sender]
            );
            token.transfer(msg.sender, amount);
        }
    }

    function _transferBalance(address recipient) internal {
        uint256 availableBalance = token.balanceOf(address(this)) -
            totalDistributedAmount;
        if (availableBalance > 0) {
            token.transfer(recipient, availableBalance);
        }
    }
}
