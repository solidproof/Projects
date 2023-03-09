// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "hardhat/console.sol";
import "./IAccessManager.sol";
import "./IFeeManager.sol";
import "./DCATypes.sol";
import "./IFeeCollector.sol";

contract DCAStrategyManager is Ownable, AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 constant SECONDS_IN_A_WEEK = 60 * 60 * 24 * 7;
    uint256 constant DENOMINATOR = 1000000;
    uint256 constant MAX_STRATEGY_FEE = 25000; // 2.5%  - percentage amount divided by DENOMINATOR
    address public feeCollector;
    uint256 public participateFee;
    ISwapRouter public uniswapV3Router; // 0xE592427A0AEce92De3Edee1F18E0157C05861564

    error InvalidAddress();
    error StrategyAlreadyRegistered();
    error MaxParticipantsInStrategy();
    error InvalidStrategyId();
    error Unauthorized();
    error MaxStrategyFeeExceeded();
    error WeeklyAmountTooLow();
    error UserNotParticipating();
    error StrategyExecutionInProgress();
    error ParticipateFeeTooLow();

    event StrategyUpdated(
        uint256 indexed id,
        address indexed fromAsset,
        address indexed toAsset,
        address accessManager,
        address feeManager,
        uint256 strategyFee,
        uint24 uniswapFeeTier,
        uint256 maxParticipants,
        uint256 minWeeklyAmount
    );
    event UserRemoved(uint256 indexed strategyId, address indexed user);
    event UserJoined(
        uint256 indexed strategyId,
        address indexed user,
        uint256 weeklyAmount
    );
    event UserResigned(uint256 indexed strategyId, address indexed user);
    event Executed(
        uint256 indexed strategyId,
        uint256 fee,
        uint256 amountIn,
        uint256 amountOut
    );
    event ExecuteDCA(
        uint256 indexed strategyId,
        uint256 indexed executionTimestamp,
        address fromAsset,
        address toAsset
    );

    // strategyId into StrategyData mapping
    mapping(uint256 => DCATypes.StrategyData) private strategy;

    function getStrategy(
        uint256 strategyId
    ) public view returns (DCATypes.StrategyData memory) {
        return strategy[strategyId];
    }

    // user to strategyId to UserStrategyData mapping
    mapping(address => mapping(uint256 => DCATypes.UserStrategyData))
        private userStrategy;

    function getUserStrategy(
        address user,
        uint256 strategyId
    ) public view returns (DCATypes.UserStrategyData memory) {
        return userStrategy[user][strategyId];
    }

    // strategyId to participants array
    mapping(uint256 => address[]) public strategyParticipants;

    modifier strategyExists(uint256 id) {
        if (strategy[id].toAsset == address(0)) {
            revert InvalidStrategyId();
        }
        _;
    }

    constructor(address feeCollector_, address uniswapV3Router_) {
        feeCollector = feeCollector_;
        uniswapV3Router = ISwapRouter(uniswapV3Router_);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setFeeCollector(address feeCollector_) public onlyOwner {
        if (feeCollector_ == address(0)) {
            revert InvalidAddress();
        }
        feeCollector = feeCollector_;
    }

    function setParticipateFee(uint256 participateFee_) public onlyOwner {
        participateFee = participateFee_;
    }

    function registerStrategy(
        uint256 id,
        address fromAsset,
        address toAsset,
        address accessManager,
        address feeManager,
        uint256 strategyFee,
        uint24 uniswapFeeTier,
        uint256 maxParticipants,
        uint256 minWeeklyAmount
    ) public onlyOwner {
        if (fromAsset == address(0)) {
            revert InvalidAddress();
        }
        if (toAsset == address(0)) {
            revert InvalidAddress();
        }
        if (accessManager == address(0)) {
            revert InvalidAddress();
        }
        if (feeManager == address(0)) {
            revert InvalidAddress();
        }
        if (strategy[id].toAsset != address(0)) {
            revert StrategyAlreadyRegistered();
        }
        if (strategyFee > MAX_STRATEGY_FEE) {
            revert MaxStrategyFeeExceeded();
        }
        strategy[id] = DCATypes.StrategyData({
            fromAsset: fromAsset,
            toAsset: toAsset,
            accessManager: accessManager,
            feeManager: feeManager,
            totalCollectedFromAsset: 0,
            totalReceivedToAsset: 0,
            strategyFee: strategyFee,
            uniswapFeeTier: uniswapFeeTier,
            maxParticipants: maxParticipants,
            minWeeklyAmount: minWeeklyAmount,
            lastExecuted: 0,
            executionData: DCATypes.StrategyExecutionData({
                isExecuting: false,
                currentPhase: DCATypes.ExecutionPhase.FINISH,
                lastLoopIndex: 0,
                totalCollectedToExchange: 0,
                totalCollectedFee: 0,
                received: 0
            })
        });

        emit StrategyUpdated(
            id,
            fromAsset,
            toAsset,
            accessManager,
            feeManager,
            strategyFee,
            uniswapFeeTier,
            maxParticipants,
            minWeeklyAmount
        );
    }

    function updateStrategy(
        uint256 id,
        uint256 strategyFee,
        uint24 uniswapFeeTier,
        uint256 maxParticipants,
        uint256 minWeeklyAmount,
        address accessManager,
        address feeManager
    ) public onlyOwner strategyExists(id) {
        if (strategyFee > MAX_STRATEGY_FEE) {
            revert MaxStrategyFeeExceeded();
        }
        if (accessManager == address(0)) {
            revert InvalidAddress();
        }

        if (feeManager == address(0)) {
            revert InvalidAddress();
        }
        DCATypes.StrategyData storage strategyData = strategy[id];
        strategyData.strategyFee = strategyFee;
        strategyData.uniswapFeeTier = uniswapFeeTier;
        strategyData.maxParticipants = maxParticipants;
        strategyData.minWeeklyAmount = minWeeklyAmount;
        strategyData.accessManager = accessManager;
        strategyData.feeManager = feeManager;

        emit StrategyUpdated(
            id,
            strategyData.fromAsset,
            strategyData.toAsset,
            accessManager,
            feeManager,
            strategyFee,
            uniswapFeeTier,
            maxParticipants,
            minWeeklyAmount
        );
    }

    function getStrategiesInfo(
        uint256[] memory strategiesIds,
        address user
    ) external view returns (DCATypes.StrategyInfoResponse[] memory) {
        uint256 length = strategiesIds.length;
        DCATypes.StrategyInfoResponse[]
            memory response = new DCATypes.StrategyInfoResponse[](length);

        for (uint256 i = 0; i < length; i++) {
            response[i] = DCATypes.StrategyInfoResponse({
                fromAsset: strategy[strategiesIds[i]].fromAsset,
                toAsset: strategy[strategiesIds[i]].toAsset,
                accessManager: strategy[strategiesIds[i]].accessManager,
                feeManager: strategy[strategiesIds[i]].feeManager,
                totalCollectedFromAsset: strategy[strategiesIds[i]]
                    .totalCollectedFromAsset,
                totalReceivedToAsset: strategy[strategiesIds[i]]
                    .totalReceivedToAsset,
                strategyFee: strategy[strategiesIds[i]].strategyFee,
                uniswapFeeTier: strategy[strategiesIds[i]].uniswapFeeTier,
                maxParticipants: strategy[strategiesIds[i]].maxParticipants,
                minWeeklyAmount: strategy[strategiesIds[i]].minWeeklyAmount,
                lastExecuted: strategy[strategiesIds[i]].lastExecuted,
                isExecuting: strategy[strategiesIds[i]]
                    .executionData
                    .isExecuting,
                participantsAmount: strategyParticipants[strategiesIds[i]]
                    .length,
                userStrategyData: userStrategy[user][strategiesIds[i]]
            });
        }

        return response;
    }

    function participate(
        uint256 id,
        uint256 weeklyAmount
    ) public payable strategyExists(id) {
        DCATypes.UserStrategyData storage userStrategyData = userStrategy[
            msg.sender
        ][id];

        if (!userStrategyData.participating && msg.value != participateFee) {
            revert ParticipateFeeTooLow();
        }

        IAccessManager(strategy[id].accessManager).participate(
            id,
            msg.sender,
            weeklyAmount
        );

        if (!userStrategyData.participating) {
            strategyParticipants[id].push(msg.sender);
            userStrategyData.participantsIndex =
                strategyParticipants[id].length -
                1;
            userStrategyData.participating = true;
        }
        userStrategyData.start = block.timestamp;
        userStrategyData.totalCollectedFromAssetSinceStart = 0;
        userStrategyData.weeklyAmount = weeklyAmount;
        userStrategyData.lastCollectedFromAssetAmount = 0;
        if (msg.value > 0) {
            IFeeCollector(feeCollector).receiveNative{value: msg.value}();
        }
        emit UserJoined(id, msg.sender, weeklyAmount);
    }

    function _removeFromStrategy(
        uint256 id,
        address user
    ) internal strategyExists(id) {
        DCATypes.UserStrategyData storage userStrategyData = userStrategy[user][
            id
        ];
        if (!userStrategyData.participating) {
            revert UserNotParticipating();
        }
        userStrategyData.participating = false;
        userStrategyData.weeklyAmount = 0;
        // remove from strategy participants

        uint256 lastParticipantIndex = strategyParticipants[id].length - 1;
        address lastParticipant = strategyParticipants[id][
            lastParticipantIndex
        ];
        strategyParticipants[id][
            userStrategyData.participantsIndex
        ] = lastParticipant;
        userStrategy[lastParticipant][id].participantsIndex = userStrategyData
            .participantsIndex;
        strategyParticipants[id].pop();
    }

    function resign(uint256 id) public {
        DCATypes.StrategyData memory strategyData = strategy[id];
        if (strategyData.executionData.isExecuting) {
            revert StrategyExecutionInProgress();
        }
        _removeFromStrategy(id, msg.sender);

        emit UserResigned(id, msg.sender);
    }

    function removeFromStrategy(uint256 id, address user) public onlyOwner {
        DCATypes.StrategyData memory strategyData = strategy[id];
        if (strategyData.executionData.isExecuting) {
            revert StrategyExecutionInProgress();
        }
        _removeFromStrategy(id, msg.sender);

        emit UserRemoved(id, user);
    }

    function getStrategyParticipantsLength(
        uint256 strategyId
    ) public view returns (uint256) {
        return strategyParticipants[strategyId].length;
    }

    function _collectFromAsset(
        uint256 strategyId,
        uint32 maxLoopIterations
    ) internal returns (uint32) {
        DCATypes.StrategyData storage strategyData = strategy[strategyId];
        int256 participantsIndex = strategyData.executionData.lastLoopIndex;
        uint256 totalCollectedToExchange = 0;
        uint256 totalCollectedFee = 0;
        while (participantsIndex >= 0 && maxLoopIterations > 0) {
            maxLoopIterations--;

            address participant = strategyParticipants[strategyId][
                uint256(participantsIndex)
            ];
            DCATypes.UserStrategyData storage userStrategyData = userStrategy[
                participant
            ][strategyId];
            uint256 toCollect = (((strategyData.lastExecuted -
                userStrategyData.start) * userStrategyData.weeklyAmount) /
                SECONDS_IN_A_WEEK) -
                userStrategyData.totalCollectedFromAssetSinceStart;
            try
                IERC20(strategyData.fromAsset).transferFrom(
                    participant,
                    address(this),
                    toCollect
                )
            {
                userStrategyData.totalCollectedFromAssetSinceStart += toCollect;
                userStrategyData.totalCollectedFromAsset += toCollect;

                uint256 fee = IFeeManager(strategyData.feeManager).calculateFee(
                    strategyId,
                    msg.sender,
                    toCollect
                );
                if ((fee * DENOMINATOR) / toCollect > MAX_STRATEGY_FEE) {
                    revert MaxStrategyFeeExceeded();
                }

                totalCollectedFee += fee;
                totalCollectedToExchange += toCollect - fee;

                userStrategyData.lastCollectedFromAssetAmount = toCollect - fee;
            } catch {
                // remove strategy participant
                _removeFromStrategy(strategyId, participant);
                emit UserRemoved(strategyId, participant);
            }

            participantsIndex--;
        }

        if (participantsIndex < 0) {
            strategyData.executionData.currentPhase = DCATypes
                .ExecutionPhase
                .EXCHANGE;
            participantsIndex = 0;
        }
        strategyData.executionData.lastLoopIndex = participantsIndex;
        strategyData
            .executionData
            .totalCollectedToExchange += totalCollectedToExchange;
        strategyData.executionData.totalCollectedFee += totalCollectedFee;
        return maxLoopIterations;
    }

    function _distributeTargetAsset(
        uint256 strategyId,
        uint32 maxLoopIterations
    ) internal {
        DCATypes.StrategyData storage strategyData = strategy[strategyId];
        int256 participantsIndex = strategyData.executionData.lastLoopIndex;
        if (strategyData.executionData.received > 0) {
            while (
                uint256(participantsIndex) <
                strategyParticipants[strategyId].length &&
                maxLoopIterations > 0
            ) {
                maxLoopIterations--;

                address participant = strategyParticipants[strategyId][
                    uint256(participantsIndex)
                ];
                DCATypes.UserStrategyData
                    storage userStrategyData = userStrategy[participant][
                        strategyId
                    ];

                uint256 toSend = (userStrategyData
                    .lastCollectedFromAssetAmount *
                    strategyData.executionData.received) /
                    strategyData.executionData.totalCollectedToExchange;
                userStrategyData.totalReceivedToAsset += toSend;
                if (toSend > 0) {
                    IERC20(strategyData.toAsset).transfer(participant, toSend);
                }

                participantsIndex++;
            }
            if (
                uint256(participantsIndex) ==
                strategyParticipants[strategyId].length
            ) {
                strategyData.executionData.currentPhase = DCATypes
                    .ExecutionPhase
                    .FINISH;
            }

            strategyData.executionData.lastLoopIndex = participantsIndex;
        } else {
            strategyData.executionData.currentPhase = DCATypes
                .ExecutionPhase
                .FINISH;
        }
    }

    function executeDCA(
        uint256 strategyId,
        uint256 beliefPrice,
        uint32 maxLoopIterations
    ) public onlyRole(OPERATOR_ROLE) {
        DCATypes.StrategyData storage strategyData = strategy[strategyId];
        if (!strategyData.executionData.isExecuting) {
            strategyData.lastExecuted = block.timestamp;
            strategyData.executionData = DCATypes.StrategyExecutionData({
                isExecuting: true,
                currentPhase: DCATypes.ExecutionPhase.COLLECT,
                lastLoopIndex: int256(strategyParticipants[strategyId].length) -
                    1,
                totalCollectedToExchange: 0,
                totalCollectedFee: 0,
                received: 0
            });
        }
        emit ExecuteDCA(
            strategyId,
            strategyData.lastExecuted,
            strategyData.fromAsset,
            strategyData.toAsset
        );

        // 1. Collect "FromAsset" from all strategy participants based on their weeklyAmount
        if (
            strategyData.executionData.currentPhase ==
            DCATypes.ExecutionPhase.COLLECT
        ) {
            maxLoopIterations = _collectFromAsset(
                strategyId,
                maxLoopIterations
            );
        }
        if (
            strategyData.executionData.currentPhase ==
            DCATypes.ExecutionPhase.EXCHANGE
        ) {
            if (strategyData.executionData.totalCollectedFee > 0) {
                IERC20(strategyData.fromAsset).approve(
                    feeCollector,
                    strategyData.executionData.totalCollectedFee
                );
                IFeeCollector(feeCollector).receiveToken(
                    strategyData.fromAsset,
                    strategyData.executionData.totalCollectedFee
                );
            }
            uint256 received = 0;
            if (strategyData.executionData.totalCollectedToExchange > 0) {
                IERC20(strategyData.fromAsset).approve(
                    address(uniswapV3Router),
                    strategyData.executionData.totalCollectedToExchange
                );
                ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                    .ExactInputSingleParams({
                        tokenIn: strategyData.fromAsset,
                        tokenOut: strategyData.toAsset,
                        fee: strategyData.uniswapFeeTier,
                        recipient: address(this),
                        deadline: block.timestamp,
                        amountIn: strategyData
                            .executionData
                            .totalCollectedToExchange,
                        amountOutMinimum: (strategyData
                            .executionData
                            .totalCollectedToExchange * beliefPrice) /
                            DENOMINATOR,
                        sqrtPriceLimitX96: 0
                    });
                received = uniswapV3Router.exactInputSingle(params);
            }

            strategyData.totalCollectedFromAsset +=
                strategyData.executionData.totalCollectedToExchange +
                strategyData.executionData.totalCollectedFee;
            strategyData.totalReceivedToAsset += received;
            strategyData.executionData.received = received;
            strategyData.executionData.currentPhase = DCATypes
                .ExecutionPhase
                .DISTRIBUTE;
        }
        if (
            strategyData.executionData.currentPhase ==
            DCATypes.ExecutionPhase.DISTRIBUTE
        ) {
            _distributeTargetAsset(strategyId, maxLoopIterations);
        }
        if (
            strategyData.executionData.currentPhase ==
            DCATypes.ExecutionPhase.FINISH
        ) {
            strategyData.executionData.isExecuting = false;
            emit Executed(
                strategyId,
                strategyData.executionData.totalCollectedFee,
                strategyData.executionData.totalCollectedToExchange,
                strategyData.executionData.received
            );
        }
    }
}
