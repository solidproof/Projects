// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../lib/Math.sol";
import "../interface/IERC20.sol";
import "../interface/IVeDist.sol";
import "../interface/IVe.sol";
import "../lib/SafeERC20.sol";

contract VeDist is IVeDist {
    using SafeERC20 for IERC20;

    event CheckpointToken(uint256 time, uint256 tokens);

    event Claimed(
        uint256 tokenId,
        uint256 amount,
        uint256 claimEpoch,
        uint256 maxEpoch
    );

    struct ClaimCalculationResult {
        uint256 toDistribute;
        uint256 userEpoch;
        uint256 weekCursor;
        uint256 maxUserEpoch;
        bool success;
    }

    uint256 constant WEEK = 7 * 86400;

    uint256 public startTime;
    uint256 public timeCursor;
    mapping(uint256 => uint256) public timeCursorOf;
    mapping(uint256 => uint256) public userEpochOf;

    uint256 public lastTokenTime;
    uint256[1000000000000000] public tokensPerWeek;

    address public votingEscrow;
    address public token;
    uint256 public tokenLastBalance;

    uint256[1000000000000000] public veSupply;

    address public depositor;

    constructor(address _votingEscrow) {
        uint256 _t = (block.timestamp / WEEK) * WEEK;
        startTime = _t;
        lastTokenTime = _t;
        timeCursor = _t;
        address _token = IVe(_votingEscrow).token();
        token = _token;
        votingEscrow = _votingEscrow;
        depositor = msg.sender;
        IERC20(_token).safeIncreaseAllowance(_votingEscrow, type(uint256).max);
    }

    function timestamp() external view returns (uint256) {
        return (block.timestamp / WEEK) * WEEK;
    }

    function _checkpointToken() internal {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 toDistribute = tokenBalance - tokenLastBalance;
        tokenLastBalance = tokenBalance;

        uint256 t = lastTokenTime;
        uint256 sinceLast = block.timestamp - t;
        lastTokenTime = block.timestamp;
        uint256 thisWeek = (t / WEEK) * WEEK;
        uint256 nextWeek = 0;

        for (uint256 i = 0; i < 20; i++) {
            nextWeek = thisWeek + WEEK;
            if (block.timestamp < nextWeek) {
                tokensPerWeek[thisWeek] += _adjustToDistribute(
                    toDistribute,
                    block.timestamp,
                    t,
                    sinceLast
                );
                break;
            } else {
                tokensPerWeek[thisWeek] += _adjustToDistribute(
                    toDistribute,
                    nextWeek,
                    t,
                    sinceLast
                );
            }
            t = nextWeek;
            thisWeek = nextWeek;
        }
        emit CheckpointToken(block.timestamp, toDistribute);
    }

    /// @dev For testing purposes.
    function adjustToDistribute(
        uint256 toDistribute,
        uint256 t0,
        uint256 t1,
        uint256 sinceLastCall
    ) external pure returns (uint256) {
        return _adjustToDistribute(toDistribute, t0, t1, sinceLastCall);
    }

    function _adjustToDistribute(
        uint256 toDistribute,
        uint256 t0,
        uint256 t1,
        uint256 sinceLast
    ) internal pure returns (uint256) {
        if (t0 <= t1 || t0 - t1 == 0 || sinceLast == 0) {
            return toDistribute;
        }
        return (toDistribute * (t0 - t1)) / sinceLast;
    }

    function checkpointToken() external override {
        require(msg.sender == depositor, "!depositor");
        _checkpointToken();
    }

    function _findTimestampEpoch(
        address ve,
        uint256 _timestamp
    ) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = IVe(ve).epoch();
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) break;
            uint256 _mid = (_min + _max + 2) / 2;
            IVe.Point memory pt = IVe(ve).pointHistory(_mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    function findTimestampUserEpoch(
        address ve,
        uint256 tokenId,
        uint256 _timestamp,
        uint256 maxUserEpoch
    ) external view returns (uint256) {
        return _findTimestampUserEpoch(ve, tokenId, _timestamp, maxUserEpoch);
    }

    function _findTimestampUserEpoch(
        address ve,
        uint256 tokenId,
        uint256 _timestamp,
        uint256 maxUserEpoch
    ) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = maxUserEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) break;
            uint256 _mid = (_min + _max + 2) / 2;
            IVe.Point memory pt = IVe(ve).userPointHistory(tokenId, _mid);
            if (pt.ts <= _timestamp) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    function veForAt(
        uint256 _tokenId,
        uint256 _timestamp
    ) external view returns (uint256) {
        address ve = votingEscrow;
        uint256 maxUserEpoch = IVe(ve).userPointEpoch(_tokenId);
        uint256 epoch = _findTimestampUserEpoch(
            ve,
            _tokenId,
            _timestamp,
            maxUserEpoch
        );
        IVe.Point memory pt = IVe(ve).userPointHistory(_tokenId, epoch);
        return
            uint256(
                int256(
                    Math.positiveInt128(
                        pt.bias -
                            pt.slope *
                            (int128(int256(_timestamp - pt.ts)))
                    )
                )
            );
    }

    function _checkpointTotalSupply() internal {
        address ve = votingEscrow;
        uint256 t = timeCursor;
        uint256 roundedTimestamp = (block.timestamp / WEEK) * WEEK;
        IVe(ve).checkpoint();

        // assume will be called more frequently than 20 weeks
        for (uint256 i = 0; i < 20; i++) {
            if (t > roundedTimestamp) {
                break;
            } else {
                uint256 epoch = _findTimestampEpoch(ve, t);
                IVe.Point memory pt = IVe(ve).pointHistory(epoch);
                veSupply[t] = _adjustVeSupply(t, pt.ts, pt.bias, pt.slope);
            }
            t += WEEK;
        }
        timeCursor = t;
    }

    function adjustVeSupply(
        uint256 t,
        uint256 ptTs,
        int128 ptBias,
        int128 ptSlope
    ) external pure returns (uint256) {
        return _adjustVeSupply(t, ptTs, ptBias, ptSlope);
    }

    function _adjustVeSupply(
        uint256 t,
        uint256 ptTs,
        int128 ptBias,
        int128 ptSlope
    ) internal pure returns (uint256) {
        if (t < ptTs) {
            return 0;
        }
        int128 dt = int128(int256(t - ptTs));
        if (ptBias < ptSlope * dt) {
            return 0;
        }
        return uint256(int256(Math.positiveInt128(ptBias - ptSlope * dt)));
    }

    function checkpointTotalSupply() external override {
        _checkpointTotalSupply();
    }

    function _claim(
        uint256 _tokenId,
        address ve,
        uint256 _lastTokenTime
    ) internal returns (uint256) {
        ClaimCalculationResult memory result = _calculateClaim(
            _tokenId,
            ve,
            _lastTokenTime
        );
        if (result.success) {
            userEpochOf[_tokenId] = result.userEpoch;
            timeCursorOf[_tokenId] = result.weekCursor;
            emit Claimed(
                _tokenId,
                result.toDistribute,
                result.userEpoch,
                result.maxUserEpoch
            );
        }
        return result.toDistribute;
    }

    function _calculateClaim(
        uint256 _tokenId,
        address ve,
        uint256 _lastTokenTime
    ) internal view returns (ClaimCalculationResult memory) {
        uint256 userEpoch;
        uint256 toDistribute;
        uint256 maxUserEpoch = IVe(ve).userPointEpoch(_tokenId);
        uint256 _startTime = startTime;

        if (maxUserEpoch == 0) {
            return ClaimCalculationResult(0, 0, 0, 0, false);
        }

        uint256 weekCursor = timeCursorOf[_tokenId];

        if (weekCursor == 0) {
            userEpoch = _findTimestampUserEpoch(
                ve,
                _tokenId,
                _startTime,
                maxUserEpoch
            );
        } else {
            userEpoch = userEpochOf[_tokenId];
        }

        if (userEpoch == 0) userEpoch = 1;

        IVe.Point memory userPoint = IVe(ve).userPointHistory(
            _tokenId,
            userEpoch
        );
        if (weekCursor == 0) {
            weekCursor = ((userPoint.ts + WEEK - 1) / WEEK) * WEEK;
        }
        if (weekCursor >= lastTokenTime) {
            return ClaimCalculationResult(0, 0, 0, 0, false);
        }
        if (weekCursor < _startTime) {
            weekCursor = _startTime;
        }

        IVe.Point memory oldUserPoint;
        {
            for (uint256 i = 0; i < 50; i++) {
                if (weekCursor >= _lastTokenTime) {
                    break;
                }
                if (weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
                    userEpoch += 1;
                    oldUserPoint = userPoint;
                    if (userEpoch > maxUserEpoch) {
                        userPoint = IVe.Point(0, 0, 0, 0);
                    } else {
                        userPoint = IVe(ve).userPointHistory(
                            _tokenId,
                            userEpoch
                        );
                    }
                } else {
                    int128 dt = int128(int256(weekCursor - oldUserPoint.ts));
                    uint256 balanceOf = uint256(
                        int256(
                            Math.positiveInt128(
                                oldUserPoint.bias - dt * oldUserPoint.slope
                            )
                        )
                    );
                    if (balanceOf == 0 && userEpoch > maxUserEpoch) {
                        break;
                    }
                    toDistribute +=
                        (balanceOf * tokensPerWeek[weekCursor]) /
                        veSupply[weekCursor];
                    weekCursor += WEEK;
                }
            }
        }
        return
            ClaimCalculationResult(
                toDistribute,
                Math.min(maxUserEpoch, userEpoch - 1),
                weekCursor,
                maxUserEpoch,
                true
            );
    }

    function claimable(uint256 _tokenId) external view returns (uint256) {
        uint256 _lastTokenTime = (lastTokenTime / WEEK) * WEEK;
        ClaimCalculationResult memory result = _calculateClaim(
            _tokenId,
            votingEscrow,
            _lastTokenTime
        );
        return result.toDistribute;
    }

    function claim(uint256 _tokenId) external returns (uint256) {
        if (block.timestamp >= timeCursor) _checkpointTotalSupply();
        uint256 _lastTokenTime = lastTokenTime;
        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint256 amount = _claim(_tokenId, votingEscrow, _lastTokenTime);
        if (amount != 0) {
            IVe(votingEscrow).depositFor(_tokenId, amount);
            tokenLastBalance -= amount;
        }
        return amount;
    }

    function claimMany(uint256[] memory _tokenIds) external returns (bool) {
        if (block.timestamp >= timeCursor) _checkpointTotalSupply();
        uint256 _lastTokenTime = lastTokenTime;
        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        address _votingEscrow = votingEscrow;
        uint256 total = 0;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            if (_tokenId == 0) break;
            uint256 amount = _claim(_tokenId, _votingEscrow, _lastTokenTime);
            if (amount != 0) {
                IVe(_votingEscrow).depositFor(_tokenId, amount);
                total += amount;
            }
        }
        if (total != 0) {
            tokenLastBalance -= total;
        }

        return true;
    }

    // Once off event on contract initialize
    function setDepositor(address _depositor) external {
        require(msg.sender == depositor, "!depositor");
        depositor = _depositor;
    }
}
