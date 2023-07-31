// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./Storage.sol";

contract Admin is Storage {
    event AddBroker(address indexed newBroker);
    event RemoveBroker(address indexed broker);
    event AddRebalancer(address indexed newRebalancer);
    event RemoveRebalancer(address indexed rebalancer);
    event SetLiquidityLockPeriod(uint32 oldLockPeriod, uint32 newLockPeriod);
    event SetOrderTimeout(uint32 marketOrderTimeout, uint32 maxLimitOrderTimeout);
    event PausePositionOrder(bool isPaused);
    event PauseLiquidityOrder(bool isPaused);
    event SetMaintainer(address indexed newMaintainer);
    event SetReferralManager(address newReferralManager);
    event SetAggregator(address indexed aggregatorAddress, bool isEnable);

    modifier onlyBroker() {
        require(_storage.brokers[_msgSender()], "BKR"); // only BroKeR
        _;
    }

    modifier onlyRebalancer() {
        require(_storage.rebalancers[_msgSender()], "BAL"); // only reBALancer
        _;
    }

    modifier onlyMaintainer() {
        require(_msgSender() == _storage.maintainer || _msgSender() == owner(), "S!M"); // Sender is Not MaiNTainer
        _;
    }

    function addBroker(address newBroker) external onlyOwner {
        require(!_storage.brokers[newBroker], "CHG"); // not CHanGed
        _storage.brokers[newBroker] = true;
        emit AddBroker(newBroker);
    }

    function removeBroker(address broker) external onlyOwner {
        _removeBroker(broker);
    }

    function renounceBroker() external {
        _removeBroker(msg.sender);
    }

    function addRebalancer(address newRebalancer) external onlyOwner {
        require(!_storage.rebalancers[newRebalancer], "CHG"); // not CHanGed
        _storage.rebalancers[newRebalancer] = true;
        emit AddRebalancer(newRebalancer);
    }

    function removeRebalancer(address rebalancer) external onlyOwner {
        _removeRebalancer(rebalancer);
    }

    function renounceRebalancer() external {
        _removeRebalancer(msg.sender);
    }

    function setLiquidityLockPeriod(uint32 newLiquidityLockPeriod) external onlyOwner {
        require(newLiquidityLockPeriod <= 86400 * 30, "LCK"); // LoCK time is too large
        require(_storage.liquidityLockPeriod != newLiquidityLockPeriod, "CHG"); // setting is not CHanGed
        emit SetLiquidityLockPeriod(_storage.liquidityLockPeriod, newLiquidityLockPeriod);
        _storage.liquidityLockPeriod = newLiquidityLockPeriod;
    }

    function setOrderTimeout(
        uint32 marketOrderTimeout_,
        uint32 maxLimitOrderTimeout_
    ) external onlyOwner {
        require(marketOrderTimeout_ != 0, "T=0"); // Timeout Is Zero
        require(marketOrderTimeout_ / 10 <= type(uint24).max, "T>M"); // Timeout is Larger than Max
        require(maxLimitOrderTimeout_ != 0, "T=0"); // Timeout Is Zero
        require(maxLimitOrderTimeout_ / 10 <= type(uint24).max, "T>M"); // Timeout is Larger than Max
        require(
            _storage.marketOrderTimeout != marketOrderTimeout_ ||
                _storage.maxLimitOrderTimeout != maxLimitOrderTimeout_,
            "CHG"
        ); // setting is not CHanGed
        _storage.marketOrderTimeout = marketOrderTimeout_;
        _storage.maxLimitOrderTimeout = maxLimitOrderTimeout_;
        emit SetOrderTimeout(marketOrderTimeout_, maxLimitOrderTimeout_);
    }

    function pause(
        bool isPositionOrderPaused_,
        bool isLiquidityOrderPaused_
    ) external onlyMaintainer {
        if (_storage.isPositionOrderPaused != isPositionOrderPaused_) {
            _storage.isPositionOrderPaused = isPositionOrderPaused_;
            emit PausePositionOrder(isPositionOrderPaused_);
        }
        if (_storage.isLiquidityOrderPaused != isLiquidityOrderPaused_) {
            _storage.isLiquidityOrderPaused = isLiquidityOrderPaused_;
            emit PauseLiquidityOrder(isLiquidityOrderPaused_);
        }
    }

    function setMaintainer(address newMaintainer) external onlyOwner {
        require(_storage.maintainer != newMaintainer, "CHG"); // not CHanGed
        _storage.maintainer = newMaintainer;
        emit SetMaintainer(newMaintainer);
    }

    function setReferralManager(address newReferralManager) external onlyOwner {
        require(newReferralManager != address(0), "ZAD");
        _storage.referralManager = newReferralManager;
        emit SetReferralManager(newReferralManager);
    }

    function setAggregator(address aggregatorAddress, bool isEnable) external onlyOwner {
        require(aggregatorAddress != address(0), "ZAD");
        _storage.aggregators[aggregatorAddress] = isEnable;
        emit SetAggregator(aggregatorAddress, isEnable);
    }

    function setCallbackGasLimit(uint256 gasLimit) external onlyOwner {
        _storage.callbackGasLimit = gasLimit;
    }

    function setCallbackWhitelist(address caller, bool enable) external onlyOwner {
        _storage.callbackWhitelist[caller] = enable;
    }

    function _removeBroker(address broker) internal {
        require(_storage.brokers[broker], "CHG"); // not CHanGed
        _storage.brokers[broker] = false;
        emit RemoveBroker(broker);
    }

    function _removeRebalancer(address rebalancer) internal {
        require(_storage.rebalancers[rebalancer], "CHG"); // not CHanGed
        _storage.rebalancers[rebalancer] = false;
        emit RemoveRebalancer(rebalancer);
    }
}
