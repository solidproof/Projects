// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Address.sol';

contract DGNXLegacyDisburser is ReentrancyGuard, Ownable {
    using SafeERC20 for ERC20;
    using Address for address;
    using SafeMath for uint256;

    address token;
    address locker;

    bool public _start = false;

    uint256 public timeInterval; // in seconds
    uint256 public timeStarted; // in seconds
    uint256 public timeIntervalTardyHolder = 7776000; // 90 days in seconds
    uint256 public ppInitial; // percentage points initial payout
    uint256 public ppRecurring; // percentage points recurring payouts

    mapping(address => uint256) private legacyAmounts;
    mapping(address => uint256) private paidOutAmounts;
    mapping(address => uint256) private payouts;
    mapping(address => uint256) public lastPayoutTimestamp;

    address[] private legacyAmountAddresses;

    event StartClaim(uint256 timestamp, address sender, uint256 amount);
    event Claim(uint256 timestamp, address sender, uint256 amount);
    event RemovedTardyHolder(
        uint256 timestamp,
        address sender,
        address tardyHolder,
        uint256 amount
    );

    constructor(
        address _token,
        address _locker,
        uint256 _timeInterval,
        uint256 _timeIntervalTardyHolder,
        uint256 _ppInitial,
        uint256 _ppRecurring
    ) {
        require(
            _token != address(0),
            'DGNXLegacyDisburser::constructor zero address'
        );
        require(
            _locker != address(0),
            'DGNXLegacyDisburser::constructor zero address'
        );
        require(
            _token != _locker,
            'DGNXLegacyDisburser::constructor token and locker same address'
        );
        require(
            _timeInterval > 0,
            'DGNXLegacyDisburser::constructor time interval missing'
        );
        require(
            _timeIntervalTardyHolder > 0,
            'DGNXLegacyDisburser::constructor tardy holder interfal missing'
        );
        require(
            _ppInitial > 0,
            'DGNXLegacyDisburser::constructor wrong initial pp'
        );
        require(
            _ppRecurring > 0,
            'DGNXLegacyDisburser::constructor wrong recurring pp'
        );

        token = _token;
        locker = _locker;
        timeInterval = _timeInterval;
        timeIntervalTardyHolder = _timeIntervalTardyHolder;
        ppInitial = _ppInitial;
        ppRecurring = _ppRecurring;
    }

    modifier _isStarted() {
        require(isStarted(), 'DGNXLegacyDisburser::isStarted not started');
        _;
    }

    modifier _allowedToClaim() {
        require(
            _msgSender() != address(0),
            'DGNXLegacyDisburser::allowedToClaim zero address'
        );
        require(
            legacyAmounts[_msgSender()] > 0,
            'DGNXLegacyDisburser::allowedToClaim not allowed to participate'
        );
        require(
            hasAmountLeft(_msgSender()),
            'DGNXLegacyDisburser::allowedToClaim no amount left'
        );
        _;
    }

    function claimStart() external _isStarted _allowedToClaim {
        require(
            block.timestamp - timeStarted < timeIntervalTardyHolder,
            'DGNXLegacyDisburser::claimStart first claming period is over'
        );
        require(
            paidOutAmounts[_msgSender()] == 0,
            'DGNXLegacyDisburser::claimStart already claimed initial funds'
        );
        uint256 legacyAmount = legacyAmounts[_msgSender()];
        uint256 initialPayout = (legacyAmount / 100) * ppInitial;
        require(
            initialPayout <= ERC20(token).balanceOf(address(this)),
            'DGNXLegacyDisburser::claimStart not enough funds claimed initial funds'
        );

        paidOutAmounts[_msgSender()] += initialPayout;
        lastPayoutTimestamp[_msgSender()] = block.timestamp;

        require(
            ERC20(token).transfer(_msgSender(), initialPayout),
            'DGNXLegacyDisburser::claimStart Tx failed'
        );
        emit StartClaim(
            lastPayoutTimestamp[_msgSender()],
            _msgSender(),
            initialPayout
        );
    }

    function claim() external _isStarted _allowedToClaim {
        require(
            paidOutAmounts[_msgSender()] > 0,
            'DGNXLegacyDisburser::claimStart missing initial claim'
        );

        removeOneTardyHolder();

        (
            uint256 claimable,
            uint256 missedPayouts,
            bool lastClaim
        ) = claimEstimate();

        require(claimable > 0, 'DGNXLegacyDisburser::claimStart not claimable');

        paidOutAmounts[_msgSender()] += claimable;
        payouts[_msgSender()] += missedPayouts;
        lastPayoutTimestamp[_msgSender()] += missedPayouts * timeInterval;

        if (lastClaim) {
            uint256 lockAmount = legacyAmounts[_msgSender()] -
                paidOutAmounts[_msgSender()];
            if (lockAmount > 0) {
                transferTokensToLocker(lockAmount);
            }
        }

        require(
            ERC20(token).transfer(_msgSender(), claimable),
            'DGNXLegacyDisburser::claimStart Tx failed'
        );

        emit Claim(lastPayoutTimestamp[_msgSender()], _msgSender(), claimable);
    }

    function claimEstimate()
        public
        view
        _isStarted
        _allowedToClaim
        returns (
            uint256 claimable,
            uint256 missedPayouts,
            bool lastClaim
        )
    {
        require(
            paidOutAmounts[_msgSender()] > 0,
            'DGNXLegacyDisburser::claimStart missing initial claim'
        );
        uint256 _currentBalance = ERC20(token).balanceOf(_msgSender());
        uint256 _timeBehind = block.timestamp -
            lastPayoutTimestamp[_msgSender()];
        uint256 _amountLeft = amountLeft(_msgSender());
        missedPayouts =
            (_timeBehind - (_timeBehind % timeInterval)) /
            timeInterval;

        if (missedPayouts > 0) {
            if (payouts[_msgSender()] + missedPayouts >= 24) {
                missedPayouts = 24 - payouts[_msgSender()];
                lastClaim = true;
            }

            uint256 _balance = _currentBalance;
            for (uint256 i; i < missedPayouts; i++) {
                _balance += (_balance * ppRecurring) / 100;
            }
            if (_balance - _currentBalance > _amountLeft) {
                claimable = _amountLeft;
            } else {
                claimable = _balance - _currentBalance;
            }
        }
    }

    function start() external onlyOwner {
        // only once
        require(!_start, 'DGNXLegacyDisburser::start already started');
        _start = true;
        timeStarted = block.timestamp;
    }

    function isStarted() public view returns (bool) {
        return _start;
    }

    function amountLeft(address addr) public view returns (uint256) {
        return (legacyAmounts[addr] - paidOutAmounts[addr]);
    }

    function hasAmountLeft(address addr) public view returns (bool) {
        return legacyAmounts[addr] > paidOutAmounts[addr];
    }

    function hasStartedClaiming(address addr) public view returns (bool) {
        return paidOutAmounts[addr] > 0;
    }

    function transferTokensTo(address addr) external onlyOwner {
        ERC20(token).safeTransfer(addr, ERC20(token).balanceOf(address(this)));
    }

    function transferTokensToLocker(uint256 amount) private {
        ERC20(token).safeTransfer(locker, amount);
    }

    function addAddresses(address[] memory addresses, uint256[] memory amounts)
        external
        onlyOwner
    {
        require(
            addresses.length == amounts.length,
            'DGNXLegacyDisburser::addBatch not the same length'
        );

        for (uint256 i; i < addresses.length; i++) {
            if (legacyAmounts[addresses[i]] == 0) {
                legacyAmounts[addresses[i]] = amounts[i];
                legacyAmountAddresses.push(addresses[i]);
            }
        }
    }

    function removeOneTardyHolder() internal {
        if (
            block.timestamp - timeStarted > timeIntervalTardyHolder &&
            legacyAmountAddresses.length > 0
        ) {
            address tardyHolder;
            uint256 tardyHolderIdx;
            for (
                uint256 i;
                i < legacyAmountAddresses.length && tardyHolder == address(0);
                i++
            ) {
                if (paidOutAmounts[legacyAmountAddresses[i]] == 0) {
                    tardyHolder = legacyAmountAddresses[i];
                    tardyHolderIdx = i;
                }
            }
            if (tardyHolder != address(0)) {
                uint256 transferAmount = legacyAmounts[tardyHolder];
                delete legacyAmounts[tardyHolder];
                delete paidOutAmounts[tardyHolder];
                legacyAmountAddresses[tardyHolderIdx] = legacyAmountAddresses[
                    legacyAmountAddresses.length - 1
                ];
                legacyAmountAddresses.pop();
                ERC20(token).transfer(locker, transferAmount);
                emit RemovedTardyHolder(
                    block.timestamp,
                    _msgSender(),
                    tardyHolder,
                    transferAmount
                );
            }
        }
    }

    function data()
        external
        view
        returns (
            uint256 claimableAmount,
            uint256 paidOutAmount,
            uint256 totalPayouts,
            uint256 recentClaim
        )
    {
        for (uint256 i; i < legacyAmountAddresses.length; i++) {
            address addr = legacyAmountAddresses[i];
            claimableAmount += legacyAmounts[addr];
            paidOutAmount += paidOutAmounts[addr];
            totalPayouts += payouts[addr];
            if (recentClaim < lastPayoutTimestamp[addr]) {
                recentClaim = lastPayoutTimestamp[addr];
            }
        }
    }
}
