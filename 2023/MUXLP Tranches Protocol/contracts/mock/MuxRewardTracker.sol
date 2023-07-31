// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SignedMathUpgradeable.sol";

import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IMuxRewardTracker.sol";

/*
@title Curve Fee Distribution modified for ve(3,3) emissions
@author Curve Finance, andrecronje
@license MIT 
*/
contract MuxRewardTracker is ReentrancyGuardUpgradeable, OwnableUpgradeable, IMuxRewardTracker {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    event CheckpointToken(uint256 time, uint256 tokens);

    event Claimed(address addr, uint256 amount, uint256 claim_epoch, uint256 maxEpoch);

    uint256 constant WEEK = 7 * 86400;

    uint256 public startTime;
    uint256 public timeCursor;
    mapping(address => uint256) public timeCursorOf;
    mapping(address => uint256) public userEpochOf;
    mapping(address => uint256) public override cumulativeRewards;

    uint256 public lastTokenTime;
    uint256[1000000000000000] public tokensPerWeek;
    address public distributor;
    address public votingEscrow;
    address public rewardToken;
    uint256 public tokenLastBalance;

    mapping(address => bool) public isHandler;

    uint256[1000000000000000] public veSupply;

    function initialize(
        address _distributor,
        address _votingEscrow,
        address _rewardToken,
        uint256 _startTime
    ) external initializer {
        __Ownable_init();

        uint256 _t = (_startTime / WEEK) * WEEK;
        startTime = _t;
        lastTokenTime = _t;
        timeCursor = _t;

        rewardToken = _rewardToken;
        votingEscrow = _votingEscrow;
        distributor = _distributor;
    }

    function setHandler(address _handler, bool _isActive) external onlyOwner {
        isHandler[_handler] = _isActive;
    }

    function setDistributor(address _distributor) external onlyOwner {
        distributor = _distributor;
    }

    function timestamp() external view returns (uint256) {
        return (_blockTime() / WEEK) * WEEK;
    }

    function averageStakedAmounts(address) external pure returns (uint256) {
        return 0;
    }

    function checkpointToken() external {
        assert(msg.sender == distributor);
        _checkpointToken();
    }

    function veForAt(address _addr, uint256 _timestamp) external view returns (uint256) {
        address ve = votingEscrow;
        uint256 maxUserEpoch = IVotingEscrow(ve).userPointEpoch(_addr);
        uint256 epoch = IVotingEscrow(ve).findTimestampUserEpoch(_addr, _timestamp, maxUserEpoch);
        IVotingEscrow.Point memory pt = IVotingEscrow(ve).userPointHistory(_addr, epoch);
        return
            uint256(
                SignedMathUpgradeable.max(
                    int256(pt.bias - pt.slope * (int128(int256(_timestamp - pt.ts)))),
                    0
                )
            );
    }

    function _checkpointTotalSupply() internal {
        address ve = votingEscrow;
        uint256 t = timeCursor;
        uint256 roundedTimestamp = (_blockTime() / WEEK) * WEEK;
        for (uint256 i = 0; i < 20; i++) {
            if (t > roundedTimestamp) {
                break;
            } else {
                uint256 epoch = IVotingEscrow(ve).findTimestampEpoch(t);
                IVotingEscrow.Point memory pt = IVotingEscrow(ve).pointHistory(epoch);
                int128 dt = 0;
                if (t > pt.ts) {
                    dt = int128(int256(t - pt.ts));
                }
                veSupply[t] = uint256(
                    SignedMathUpgradeable.max(int256(pt.bias - pt.slope * dt), 0)
                );
            }
            t += WEEK;
        }
        timeCursor = t;
    }

    function checkpointTotalSupply() external {
        _checkpointTotalSupply();
    }

    function _claim(address _addr, address ve, uint256 _lastTokenTime) internal returns (uint256) {
        uint256 userEpoch = 0;
        uint256 toDistribute = 0;

        uint256 maxUserEpoch = IVotingEscrow(ve).userPointEpoch(_addr);
        uint256 _startTime = startTime;

        if (maxUserEpoch == 0) return 0;

        uint256 weekCursor = timeCursorOf[_addr];
        if (weekCursor == 0) {
            userEpoch = IVotingEscrow(ve).findTimestampUserEpoch(_addr, _startTime, maxUserEpoch);
        } else {
            userEpoch = userEpochOf[_addr];
        }

        if (userEpoch == 0) userEpoch = 1;

        IVotingEscrow.Point memory userPoint = IVotingEscrow(ve).userPointHistory(_addr, userEpoch);

        if (weekCursor == 0) weekCursor = ((userPoint.ts + WEEK - 1) / WEEK) * WEEK; // 1652918400 week
        if (weekCursor >= lastTokenTime) return 0;
        if (weekCursor < _startTime) weekCursor = _startTime; // 1651708800

        IVotingEscrow.Point memory oldUserPoint;

        for (uint256 i = 0; i < 50; i++) {
            if (weekCursor >= _lastTokenTime) break;

            if (weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
                userEpoch += 1;
                oldUserPoint = userPoint;
                if (userEpoch > maxUserEpoch) {
                    userPoint = IVotingEscrow.Point(0, 0, 0, 0);
                } else {
                    userPoint = IVotingEscrow(ve).userPointHistory(_addr, userEpoch);
                }
            } else {
                int128 dt = int128(int256(weekCursor - oldUserPoint.ts));
                uint256 balanceOf = uint256(
                    SignedMathUpgradeable.max(
                        int256(oldUserPoint.bias - dt * oldUserPoint.slope),
                        0
                    )
                );
                if (balanceOf == 0 && userEpoch > maxUserEpoch) break;
                if (balanceOf > 0) {
                    toDistribute += (balanceOf * tokensPerWeek[weekCursor]) / veSupply[weekCursor];
                }
                weekCursor += WEEK;
            }
        }

        userEpoch = MathUpgradeable.min(maxUserEpoch, userEpoch - 1);
        userEpochOf[_addr] = userEpoch;
        timeCursorOf[_addr] = weekCursor;
        cumulativeRewards[_addr] += toDistribute;

        emit Claimed(_addr, toDistribute, userEpoch, maxUserEpoch);

        return toDistribute;
    }

    function _claimable(
        address _addr,
        address ve,
        uint256 _lastTokenTime
    ) internal view returns (uint256) {
        uint256 userEpoch = 0;
        uint256 toDistribute = 0;

        uint256 maxUserEpoch = IVotingEscrow(ve).userPointEpoch(_addr); // 5
        uint256 _startTime = startTime;

        if (maxUserEpoch == 0) return 0;

        uint256 weekCursor = timeCursorOf[_addr]; // 0
        if (weekCursor == 0) {
            userEpoch = IVotingEscrow(ve).findTimestampUserEpoch(_addr, _startTime, maxUserEpoch);
        } else {
            userEpoch = userEpochOf[_addr];
        }

        if (userEpoch == 0) userEpoch = 1; // = 1
        IVotingEscrow.Point memory userPoint = IVotingEscrow(ve).userPointHistory(_addr, userEpoch);

        if (weekCursor == 0) weekCursor = ((userPoint.ts + WEEK - 1) / WEEK) * WEEK;
        if (weekCursor >= lastTokenTime) return 0;
        if (weekCursor < _startTime) weekCursor = _startTime;

        IVotingEscrow.Point memory oldUserPoint;

        for (uint256 i = 0; i < 50; i++) {
            if (weekCursor >= _lastTokenTime) break;

            if (weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
                userEpoch += 1;
                oldUserPoint = userPoint;
                if (userEpoch > maxUserEpoch) {
                    userPoint = IVotingEscrow.Point(0, 0, 0, 0);
                } else {
                    userPoint = IVotingEscrow(ve).userPointHistory(_addr, userEpoch);
                }
            } else {
                int128 dt = int128(int256(weekCursor - oldUserPoint.ts));

                uint256 balanceOf = uint256(
                    SignedMathUpgradeable.max(
                        int256(oldUserPoint.bias - dt * oldUserPoint.slope),
                        0
                    )
                );
                if (balanceOf == 0 && userEpoch > maxUserEpoch) break;
                if (balanceOf > 0) {
                    toDistribute += (balanceOf * tokensPerWeek[weekCursor]) / veSupply[weekCursor];
                }
                weekCursor += WEEK;
            }
        }
        return toDistribute;
    }

    function claimable(address _addr) public virtual override returns (uint256) {
        IRewardDistributor(distributor).distribute();
        if (_blockTime() >= timeCursor) _checkpointTotalSupply();
        uint256 _lastTokenTime = (lastTokenTime / WEEK) * WEEK; // 1653523200
        return _claimable(_addr, votingEscrow, _lastTokenTime);
    }

    function claim(address _recipient) public virtual returns (uint256) {
        return _claimForAccount(msg.sender, _recipient);
    }

    function claimForAccount(address _addr, address _recipient) public virtual returns (uint256) {
        _validateHandler();
        return _claimForAccount(_addr, _recipient);
    }

    function _claimForAccount(address _addr, address _recipient) internal returns (uint256) {
        IRewardDistributor(distributor).distribute();
        if (_blockTime() >= timeCursor) _checkpointTotalSupply();
        uint256 _lastTokenTime = lastTokenTime;
        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint256 amount = _claim(_addr, votingEscrow, _lastTokenTime);
        if (amount != 0) {
            tokenLastBalance -= amount;
            IERC20Upgradeable(rewardToken).safeTransfer(_recipient, amount);
        }
        return amount;
    }

    function _checkpointToken() internal virtual {
        uint256 _balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        uint256 toDistribute = _balance - tokenLastBalance;
        tokenLastBalance = _balance;

        uint256 t = lastTokenTime;
        uint256 sinceLast = _blockTime() - t;
        lastTokenTime = _blockTime();

        uint256 thisWeek = (t / WEEK) * WEEK;
        uint256 nextWeek = 0;

        for (uint256 i = 0; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            if (_blockTime() < nextWeek) {
                if (sinceLast == 0 && _blockTime() == t) {
                    tokensPerWeek[thisWeek] += toDistribute;
                } else {
                    tokensPerWeek[thisWeek] += (toDistribute * (_blockTime() - t)) / sinceLast;
                }
                break;
            } else {
                if (sinceLast == 0 && nextWeek == t) {
                    tokensPerWeek[thisWeek] += toDistribute;
                } else {
                    tokensPerWeek[thisWeek] += (toDistribute * (nextWeek - t)) / sinceLast;
                }
            }
            t = nextWeek;
            thisWeek = nextWeek;
        }
        emit CheckpointToken(_blockTime(), toDistribute);
    }

    function _blockTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "MuxRewardTracker: forbidden");
    }
}
