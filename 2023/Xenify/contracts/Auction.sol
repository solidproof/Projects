// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {IBurnableToken} from "./interfaces/IBurnableToken.sol";
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";
import {IFeeSplitter} from "./interfaces/IFeeSplitter.sol";
import {SignatureHelper} from "./libs/SignatureHelper.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IRecycle} from "./interfaces/IRecycle.sol";
import {IVeXNF} from "./interfaces/IVeXNF.sol";
import {IXNF} from "./interfaces/IXNF.sol";
import {console} from "hardhat/console.sol";
import {Math} from "./libs/Math.sol";

/*
 * @title Auction Contract
 *
 * @notice This contract facilitates a token burning mechanism where users can burn their tokens in exchange
 * for rewards. The contract manages the burn process, calculates rewards, and distributes them accordingly.
 * It's an essential component of the ecosystem, promoting token scarcity and incentivising user participation.
 *
 * Co-Founders:
 * - Simran Dhillon: simran@xenify.io
 * - Hardev Dhillon: hardev@xenify.io
 * - Dayana Plaz: dayana@xenify.io
 *
 * Official Links:
 * - Twitter: https://twitter.com/xenify_io
 * - Telegram: https://t.me/xenify_io
 * - Website: https://xenify.io
 *
 * Disclaimer:
 * This contract aligns with the principles of the Fair Crypto Foundation, promoting self-custody, transparency, consensus-based
 * trust, and permissionless value exchange. There are no administrative access keys, underscoring our commitment to decentralization.
 * Engaging with this contract involves technical and legal risks. Users must conduct their own due diligence and ensure compliance
 * with local laws and regulations. The software is provided "AS-IS," without warranties, and the co-founders and developers disclaim
 * all liability for any vulnerabilities, exploits, errors, or breaches that may occur. By using this contract, users accept all associated
 * risks and this disclaimer. The co-founders, developers, or related parties will not bear liability for any consequences of non-compliance.
 *
 * Redistribution and Use:
 * Redistribution, modification, or repurposing of this contract, in whole or in part, is strictly prohibited without express written
 * approval from all co-founders. Approval requests must be sent to the official email addresses of the co-founders, ensuring responses
 * are received directly from these addresses. Proposals for redistribution, modification, or repurposing must include a detailed explanation
 * of the intended changes or uses and the reasons behind them. The co-founders reserve the right to request additional information or
 * clarification as necessary. Approval is at the sole discretion of the co-founders and may be subject to conditions to uphold the
 * project’s integrity and the values of the Fair Crypto Foundation. Failure to obtain express written approval prior to any redistribution,
 * modification, or repurposing will result in a breach of these terms and immediate legal action.
 *
 * Copyright and License:
 * Copyright © 2023 Xenify (Simran Dhillon, Hardev Dhillon, Dayana Plaz). All rights reserved.
 * This software is primarily licensed under the Business Source License 1.1 (BUSL-1.1).
 * Please refer to the BUSL-1.1 documentation for complete license details.
 */
contract Auction is
    IAuction,
    ReentrancyGuard
{

    /// ------------------------------------- LIBRARYS ------------------------------------- \\\

    /**
     * @notice Library used for splitting and recovering signatures.
     */
    using SignatureHelper for bytes;

    /**
     * @notice Library used for handling message hashes.
     */
    using SignatureHelper for bytes32;

    /**
     * @notice Library used for safeTransfer.
     */
    using SafeERC20 for IERC20Mintable;

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Internal flag to check if a function was previously called.
     */
    bool internal _isTriggered;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Denominator for basis points calculations.
     */
    uint256 constant public BP = 1e18;

    /**
     * @notice The constant pool fee value.
     */
    uint24 public constant POOL_FEE = 1e4;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice The current nonce value.
     */
    uint256 public nonce;

    /**
     * @notice Fee amount per batch.
     */
    uint256 public batchFee;

    /**
     * @notice Amount of YSL tokens per batch.
     */
    uint256 public YSLPerBatch;

    /**
     * @notice Amount of vXEN tokens per batch.
     */
    uint256 public vXENPerBatch;

    /**
     * @notice The current cycle number.
     */
    uint256 public currentCycle;

    /**
     * @notice The last active cycle number.
     */
    uint256 public lastActiveCycle;

    /**
     * @notice Duration of a period in seconds.
     */
    uint256 public i_periodDuration;

    /**
     * @notice The initial timestamp when the contract was deployed.
     */
    uint256 public i_initialTimestamp;

    /**
     * @notice The last cycle in which fees were claimed.
     */
    uint256 public lastClaimFeesCycle;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Array of cycle numbers for halving events.
     */
    uint256[9] public cyclesForHalving;

    /**
     * @notice Array of reward amounts for each halving event.
     */
    uint256[9] public rewardsPerHalving;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Address of the veXNF contract, set during deployment and cannot be changed.
     */
    address public veXNF;

    /**
     * @notice Address of the Auction contract, set during deployment and cannot be changed.
     */
    address public Recycle;

    /**
     * @notice Address of the first registrar.
     */
    address public registrar1;

    /**
     * @notice Address of the second registrar.
     */
    address public registrar2;

    /// ------------------------------------ INTERFACES ------------------------------------- \\\

    /**
     * @notice Interface to interact with the XNF token contract.
     */
    IERC20Mintable public xnf;

    /**
     * @notice Interface to interact with the YSL token contract.
     */
    IBurnableToken public ysl;

    /**
     * @notice Interface to interact with the vXEN token contract.
     */
    IBurnableToken public vXEN;

    /**
     * @notice Interface to interact with the NonfungiblePositionManager contract.
     */
    INonfungiblePositionManager public nonfungiblePositionManager;

    /// ------------------------------------ MAPPINGS --------------------------------------- \\\

    /**
     * @notice Mapping that associates each user address with their respective user information.
     */
    mapping (address => User) public userInfo;

    /**
     * @notice Mapping that associates each cycle number with its respective cycle information.
     */
    mapping (uint256 => Cycle) public cycleInfo;

    /**
     * @notice Mapping that associates each user address with their last activity information.
     */
    mapping (address => UserLastActivity) public userLastActivityInfo;

    /**
     * @notice Mapping that associates each cycle number with the total recycler power during the first hour.
     */
    mapping (uint256 => uint256) public totalPowerOfRecyclersFirstHour;

    /**
     * @notice Mapping that associates each user and cycle with their recycler power during the first hour.
     */
    mapping (address => mapping (uint256 => uint256)) public recyclerPowerFirstHour;

    /// -------------------------------------- ERRORS --------------------------------------- \\\

    /**
     * @notice Error thrown when the transfer of native tokens failed.
     */
    error TransferFailed();

    /**
     * @notice Error thrown when the provided YSL address is the zero address.
     */
    error ZeroYSLAddress();

    /**
     * @notice Error thrown when the provided vXEN address is the zero address.
     */
    error ZeroVXENAddress();

    /**
     * @notice Error thrown when the provided signature is invalid.
     */
    error InvalidSignature();

    /**
     * @notice Error thrown when the batch number is out of the allowed range.
     */
    error InvalidBatchNumber();

    /**
     * @notice Error thrown when a function is called by an unauthorized address.
     */
    error UnauthorizedCaller();

    /**
     * @notice Error thrown when the provided value is less than the required burn fee.
     */
    error InsufficientBurnFee();

    /**
     * @notice Error thrown when the provided Registrar 1 address is the zero address.
     */
    error ZeroRegistrar1Address();

    /**
     * @notice Error thrown when native fee is insufficient.
     */
    error InsufficientNativeFee();

    /**
     * @notice Error thrown when the provided Registrar 2 address is the zero address.
     */
    error ZeroRegistrar2Address();

    /**
     * @notice Error thrown when the partner percentage exceeds the allowed limit.
     */
    error InvalidPartnerPercentage();

    /**
     * @notice Error thrown when there's an attempt to distribute an invalid amount.
     */
    error InvalidDistributionAmount();

    /**
     * @notice Error thrown when the transfer amount is insufficient.
     */
    error InsufficientTransferAmount();

    /**
     * @notice Error thrown when no native rewards are available for recycling.
     */
    error NoNativeRewardsForRecycling();

    /**
     * @notice Error thrown when the contract is already initialised.
     */
    error ContractInitialised(address contractAddress);

    /**
     * @notice Error thrown when native value is insufficient for burn.
     */
    error InsufficientNativeValue(uint256 nativeValue, uint256 burnFee);

    /// ------------------------------------- STRUCTURES ------------------------------------ \\\

    /**
     * @notice User info struct detailing accumulated activities and pending rewards.
     * @param accCycleYSLBurnedBatches Accumulated YSL batches burned by the user in the current cycle.
     * @param accCyclevXENBurnedBatches Accumulated vXEN batches burned by the user in the current cycle.
     * @param accCycleNativeBatches Accumulated native batches by the user in the current cycle.
     * @param accCycleSwaps Accumulated swaps made by the user in the current cycle.
     * @param pendingRewardsFromBurn Pending XNF rewards from burning activities.
     * @param pendingRewardsFromSwap Pending XNF rewards from swapping activities.
     * @param pendingRewardsFromNative Pending XNF rewards from native participation activities.
     * @param pendingNative Pending native rewards for the user.
     */
    struct User {
        uint256 accCycleYSLBurnedBatches;
        uint256 accCyclevXENBurnedBatches;
        uint256 accCycleNativeBatches;
        uint256 accCycleSwaps;
        uint256 pendingRewardsFromBurn;
        uint256 pendingRewardsFromSwap;
        uint256 pendingRewardsFromNative;
        uint256 pendingNative;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Struct capturing the accumulated activities and rewards for a specific cycle.
     * @param previouseActiveCycle The previous active cycle number.
     * @param cycleYSLBurnedBatches Accumulated YSL batches burned in the current cycle.
     * @param cyclevXENBurnedBatches Accumulated vXEN batches burned in the current cycle.
     * @param cycleNativeBatches Accumulated native batches in the current cycle.
     * @param cycleAccNative Accumulated native rewards in the current cycle.
     * @param cycleAccNativeFromSwaps Accumulated native rewards from swaps in the current cycle.
     * @param cycleAccNativeFromNativeParticipants Accumulated native rewards from native participation in the current cycle.
     * @param cycleAccNativeFromAuction Accumulated native rewards from auctions in the current cycle.
     * @param cycleAccExactNativeFromSwaps Accumulated exact native rewards from swaps in the current cycle.
     * @param cycleAccBonus Accumulated bonus in the current cycle.
     * @param accRewards Accumulated rewards for the current cycle.
     */
    struct Cycle {
        uint256 previouseActiveCycle;
        uint256 cycleYSLBurnedBatches;
        uint256 cyclevXENBurnedBatches;
        uint256 cycleNativeBatches;
        uint256 cycleAccNative;
        uint256 cycleAccNativeFromSwaps;
        uint256 cycleAccNativeFromNativeParticipants;
        uint256 cycleAccNativeFromAuction;
        uint256 cycleAccExactNativeFromSwaps;
        uint256 cycleAccBonus;
        uint256 accRewards;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Struct capturing the last cycle of various user activities.
     * @param lastCycleForBurn Last cycle in which the user burned tokens.
     * @param lastCycleForRecycle Last cycle in which the user recycled.
     * @param lastCycleForSwap Last cycle in which the user swapped.
     * @param lastCycleForNativeParticipation Last cycle in which the user participated in native activities.
     * @param lastUpdatedStats Last cycle in which the user's stats were updated.
     */
    struct UserLastActivity {
        uint256 lastCycleForBurn;
        uint256 lastCycleForRecycle;
        uint256 lastCycleForSwap;
        uint256 lastCycleForNativeParticipation;
        uint256 lastUpdatedStats;
    }

    /// -------------------------------------- EVENTS --------------------------------------- \\\

    /**
     * @notice Triggered when a user burns tokens.
     * @param isvXEN Indicates if the burned tokens are vXEN.
     * @param user Address initiating the burn.
     * @param batchNumber Count of batches burned.
     * @param burnFee Fee incurred for the burn action.
     * @param cycle Current cycle during which the action is taking place.
     */
    event BurnAction(
        bool isvXEN,
        address indexed user,
        uint256 batchNumber,
        uint256 burnFee,
        uint256 cycle
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered when a user claims XNF rewards.
     * @param user Address of the claimer.
     * @param cycle Current cycle during which the action is taking place.
     * @param pendingRewardsFromBurn Amount of XNF rewards claimed from burning.
     */
    event XNFClaimed(
        address indexed user,
        uint256 cycle,
        uint256 pendingRewardsFromBurn
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered when a user claims veXNF.
     * @param user Address of the claimer.
     * @param cycle Current cycle during which the action is taking place.
     * @param veXNFClaimedAmount Total amount of veXNF claimed.
     */
    event veXNFClaimed(
        address indexed user,
        uint256 cycle,
        uint256 veXNFClaimedAmount
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered when a user claims native rewards.
     * @param user Address of the claimer.
     * @param cycle Current cycle during which the action is taking place.
     * @param bonusAdded Bonus amount added to the rewards pool.
     * @param nativeTransferred Total native amount transferred to the user.
     */
    event NativeClaimed(
        address indexed user,
        uint256 cycle,
        uint256 bonusAdded,
        uint256 nativeTransferred
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered when a user recycles tokens.
     * @param user Address initiating the recycle action.
     * @param cycle Current cycle during which the action is taking place.
     * @param burnFee Fee incurred for recycling.
     * @param batchNumber Count of batches recycled.
     * @param nativeAmountRecycled Total native amount recycled.
     * @param userRecyclerPower Power of the user during recycling.
     * @param totalRecyclerPower Combined power of all recyclers.
     */
    event RecycleAction(
        address indexed user,
        uint256 cycle,
        uint256 burnFee,
        uint256 batchNumber,
        uint256 nativeAmountRecycled,
        uint256 userRecyclerPower,
        uint256 totalRecyclerPower
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered when a user registers for swapping.
     * @param user Address of the registered user.
     * @param cycle Current cycle during which the action is taking place.
     * @param swapFee Fee incurred for the swap registration.
     * @param registrar Address responsible for the registration.
     */
    event SwapUserRegistered(
        address indexed user,
        uint256 cycle,
        uint256 swapFee,
        address registrar
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Triggered upon participation using native tokens.
     * @param user Participant's address.
     * @param batchNumber Count of participation batches.
     * @param burnFee Fee incurred for participation.
     * @param cycle Current cycle during which the action is taking place.
     */
    event ParticipateWithNative(
        address indexed user,
        uint256 batchNumber,
        uint256 burnFee,
        uint256 cycle
    );

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Initialises the contract with essential parameters.
     * @param _Recycle Address of the Recycle contract.
     * @param _xnf Address of the XNF token contract.
     * @param _veXNF Address of the veXNF contract.
     * @param _vXEN Address of the vXEN token contract.
     * @param _ysl Address of the YSL token contract.
     * @param _registrar1 Address of the first registrar.
     * @param _registrar2 Address of the second registrar.
     * @param _YSLPerBatch Amount of YSL tokens per batch.
     * @param _vXENPerBatch Amount of vXEN tokens per batch.
     * @param _batchFee Amount of native tokens per batch.
     * @param _nonfungiblePositionManager Address of the NonfungiblePositionManager contract.
     */
    function initialise(
        address _Recycle,
        address _xnf,
        address _veXNF,
        address _vXEN,
        address _ysl,
        address _registrar1,
        address _registrar2,
        uint256 _YSLPerBatch,
        uint256 _vXENPerBatch,
        uint256 _batchFee,
        address _nonfungiblePositionManager
    ) external {
        if (address(ysl) != address(0)) {
            revert ContractInitialised(address(ysl));
        }
        if (_ysl == address(0)) {
            revert ZeroYSLAddress();
        }
        if (_vXEN == address(0)) {
            revert ZeroVXENAddress();
        }
        if (_registrar1 == address(0)) {
            revert ZeroRegistrar1Address();
        }
        if (_registrar2 == address(0)) {
            revert ZeroRegistrar2Address();
        }
        rewardsPerHalving = [
            10000 ether, 5000 ether, 2500 ether,
            1250 ether, 625 ether, 312.5 ether,
            156.25 ether
        ];
        cyclesForHalving = [
            90, 270, 630,
            1350, 2790, 4230,
            5670, 73830
        ];
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        registrar1 = _registrar1;
        registrar2 = _registrar2;
        i_initialTimestamp = block.timestamp;
        i_periodDuration = 1 days;
        vXEN = IBurnableToken(_vXEN);
        ysl = IBurnableToken(_ysl);
        vXENPerBatch = _vXENPerBatch;
        YSLPerBatch = _YSLPerBatch;
        batchFee = _batchFee;
        Recycle = _Recycle;
        veXNF = _veXNF;
        xnf = IERC20Mintable(_xnf);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Accepts native tokens and contributes to the cycle's auction fees.
     * @dev Updates the current cycle's accumulated fees from auctions and creates protocol-owned liquidity.
     */
    receive() external payable {
        calculateCycle();
        cycleInfo[currentCycle].cycleAccNativeFromAuction += msg.value * 2 / 5;
        IRecycle(Recycle).executeBuybackBurn{value: msg.value * 3 / 5} ();
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim all their pending rewards.
     * @dev Claims native, XNF, and veXNF rewards for the caller.
     */
    function claimAll() external override {
        _updateStatsForUser(msg.sender);
        _claimNative(msg.sender);
        _claimXNF(msg.sender);
        _claimveXNF(msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims all rewards on behalf of a specified user.
     * @dev Only callable by the veXNF contract. Claims native, XNF, and veXNF rewards for the specified user.
     * @param _user Address of the user for whom rewards are being claimed.
     */
    function claimAllForUser(address _user)
        external
        override
    {
        if (msg.sender != veXNF) {
            revert UnauthorizedCaller();
        }
        _updateStatsForUser(_user);
        _claimNative(_user);
        _claimXNF(_user);
        _claimveXNF(_user);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to recycle native rewards and claim all other rewards.
     * @dev Recycles native rewards and claims XNF and veXNF rewards for the caller.
     */
    function claimAllAndRecycle() external override {
        _updateStatsForUser(msg.sender);
        _recycle(msg.sender);
        _claimXNF(msg.sender);
        _claimveXNF(msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns specified batches of vXEN or YSL tokens to earn rewards.
     * @dev Updates the current cycle and user stats based on the burn action.
     * @param _isvXEN Indicates if vXEN tokens are being burned. If false, YSL tokens are burned.
     * @param _batchNumber Number of token batches to burn.
     */
    function burn(
        bool _isvXEN,
        uint256 _batchNumber
    )
        external
        payable
        override
    {
        if (_isvXEN) {
            vXEN.burn(msg.sender, _batchNumber * vXENPerBatch);
        }
        else {
            ysl.burn(msg.sender, _batchNumber * YSLPerBatch);
        }
        calculateCycle();
        if (_batchNumber > 1e4 || _batchNumber < 1) {
            revert InvalidBatchNumber();
        }
        uint256 burnFee = coefficientWrapper(_batchNumber);
        if (_isvXEN) {
            _setupNewCycle(0, _batchNumber, 0, 0, burnFee);
            if (currentCycle == 0) {
                userInfo[msg.sender].accCyclevXENBurnedBatches += _batchNumber;
            }
            else {
                updateStats(msg.sender);
                if (userLastActivityInfo[msg.sender].lastCycleForBurn != currentCycle) {
                    userInfo[msg.sender].accCyclevXENBurnedBatches = _batchNumber;
                }
                else {
                    userInfo[msg.sender].accCyclevXENBurnedBatches += _batchNumber;
                }
                userLastActivityInfo[msg.sender].lastCycleForBurn = currentCycle;
            }
        } else {
            _setupNewCycle(_batchNumber, 0, 0, 0, burnFee);
            if (currentCycle == 0) {
                userInfo[msg.sender].accCycleYSLBurnedBatches += _batchNumber;
            }
            else {
                updateStats(msg.sender);
                if (userLastActivityInfo[msg.sender].lastCycleForBurn != currentCycle) {
                    userInfo[msg.sender].accCycleYSLBurnedBatches = _batchNumber;
                }
                else {
                    userInfo[msg.sender].accCycleYSLBurnedBatches += _batchNumber;
                }
                userLastActivityInfo[msg.sender].lastCycleForBurn = currentCycle;
            }
        }
        if (msg.value < burnFee) {
            revert InsufficientBurnFee();
        }
        _sendViaCall(
            payable(msg.sender),
            msg.value - burnFee
        );
        emit BurnAction(
            _isvXEN,
            msg.sender,
            _batchNumber,
            burnFee,
            currentCycle
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Registers the caller as a swap user and earns rewards.
     * @dev Validates the signature, updates the current cycle, and user stats.
     * @param signature Signed data for user registration.
     * @param partner Address of the partner for fee distribution.
     * @param partnerPercent Percentage of fees to be distributed to the partner.
     * @param feeSplitter Address responsible for fee distribution.
     */
    function registerSwapUser(
        bytes calldata signature,
        address partner,
        uint256 partnerPercent,
        address feeSplitter
    )
        external
        payable
        override
    {
        if (msg.value == 0) {
            revert InsufficientTransferAmount();
        }
        if (partnerPercent > 50) {
            revert InvalidPartnerPercentage();
        }
        calculateCycle();
        uint256 fee;
        if (partner != address(0)) {
            fee = msg.value - msg.value * partnerPercent / 100;
        } else {
            fee = msg.value;
        }
        _setupNewCycle(0, 0, 0, fee, msg.value);
        (bytes32 r, bytes32 s, uint8 v) = signature._splitSignature();
        bytes32 messageHash = (
            SignatureHelper._getMessageHash(
                msg.sender,
                msg.value,
                partner,
                partnerPercent,
                feeSplitter,
                nonce
            )
        )._getEthSignedMessageHash();
        address signatureAddress = ecrecover(messageHash, v, r, s);
        if (signatureAddress != registrar1 && signatureAddress != registrar2) {
            revert InvalidSignature();
        }
        nonce++;
        if (currentCycle == 0) {
            userInfo[msg.sender].accCycleSwaps = msg.value;
        }
        else {
            updateStats(msg.sender);
            if (userLastActivityInfo[msg.sender].lastCycleForSwap != currentCycle) {
                userInfo[msg.sender].accCycleSwaps = msg.value;
            }
            else {
                userInfo[msg.sender].accCycleSwaps += msg.value;
            }
            userLastActivityInfo[msg.sender].lastCycleForSwap = currentCycle;
        }
        if (partner != address(0)) {
            IFeeSplitter(feeSplitter).distributeFees{value: msg.value * partnerPercent / 100} (partner);
        }
        emit SwapUserRegistered(
            msg.sender,
            currentCycle,
            msg.value,
            signatureAddress
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Registers the caller as a burner by paying in native tokens.
     * @dev Updates the current cycle and user stats based on the native participation.
     * @param _batchNumber Number of batches the user is participating with.
     */
    function participateWithNative(uint256 _batchNumber)
        external
        payable
        override
    {
        calculateCycle();
        if (_batchNumber > 1e4 || _batchNumber < 1) {
            revert InvalidBatchNumber();
        }
        uint256 nativeFee = coefficientWrapper(_batchNumber);
        _setupNewCycle(0, 0, _batchNumber, 0, nativeFee);
        if (currentCycle == 0) {
            userInfo[msg.sender].accCycleNativeBatches += _batchNumber;
        }
        else {
            updateStats(msg.sender);
            if (userLastActivityInfo[msg.sender].lastCycleForNativeParticipation != currentCycle) {
                userInfo[msg.sender].accCycleNativeBatches = _batchNumber;
            }
            else {
                userInfo[msg.sender].accCycleNativeBatches += _batchNumber;
            }
            userLastActivityInfo[msg.sender].lastCycleForNativeParticipation = currentCycle;
        }
        if (msg.value < nativeFee) {
            revert InsufficientNativeFee();
        }
        _sendViaCall(
            payable(msg.sender),
            msg.value - nativeFee
        );
        emit ParticipateWithNative(
            msg.sender,
            _batchNumber,
            nativeFee,
            currentCycle
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim their native rewards.
     * @dev Internally calls the _claimNative function to handle the reward claim.
     */
    function claimNative()
        external
        override
        nonReentrant
    {
        _updateStatsForUser(msg.sender);
        _claimNative(msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim their pending XNF rewards.
     * @dev Updates user stats and transfers the XNF rewards to the caller.
     */
    function claimXNF() external override {
        _updateStatsForUser(msg.sender);
        _claimXNF(msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows the caller to claim XNF rewards and locks them in the veXNF contract for a year.
     * @dev Claims XNF rewards for the caller and locks them in the veXNF contract.
     */
    function claimVeXNF() external override {
        _updateStatsForUser(msg.sender);
        _claimveXNF(msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Enables users to recycle their native rewards and claim other rewards.
     * @dev Processes the recycling of native rewards and distributes rewards based on user participation.
     */
    function recycle() external override {
        _updateStatsForUser(msg.sender);
        _recycle(msg.sender);
    }

    /// --------------------------------- PUBLIC FUNCTIONS ---------------------------------- \\\

    /**
     * @notice Updates the current cycle number based on the elapsed time since the contract's initialisation.
     * @dev If the calculated cycle is greater than the stored cycle, it updates the stored cycle.
     * @return The calculated current cycle, representing the number of complete cycles that have elapsed.
     */
    function calculateCycle()
        public
        override
        returns (uint256)
    {
        uint256 calculatedCycle = getCurrentCycle();
        if (calculatedCycle > currentCycle) {
            currentCycle = calculatedCycle;
        }
        return calculatedCycle;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Refreshes the user's statistics, including pending rewards and fees.
     * @dev This function should be called periodically to ensure accurate user statistics.
     * @param _user The user's address whose statistics need to be updated.
     */
    function updateStats(address _user)
        public
        override
    {
        calculateCycle();
        User storage user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        (
            uint256 pendingRewardsFromBurn,
            uint256 pendingRewardsFromSwap,
            uint256 pendingRewardsFromNative
        ) = pendingXNF(_user);
        if (userLastActivity.lastCycleForBurn != currentCycle && (user.accCycleYSLBurnedBatches != 0 || user.accCyclevXENBurnedBatches != 0)) {
            user.accCycleYSLBurnedBatches = 0;
            user.accCyclevXENBurnedBatches = 0;
        }
        if (userLastActivity.lastCycleForNativeParticipation != currentCycle && user.accCycleNativeBatches != 0) {
            user.accCycleNativeBatches = 0;
        }
        if (userLastActivity.lastCycleForSwap != currentCycle && user.accCycleSwaps != 0) {
            user.accCycleSwaps = 0;
        }
        user.pendingRewardsFromSwap = pendingRewardsFromSwap;
        user.pendingRewardsFromBurn = pendingRewardsFromBurn;
        user.pendingRewardsFromNative = pendingRewardsFromNative;
        user.pendingNative = pendingNative(_user);
        if (userLastActivity.lastCycleForRecycle < currentCycle) {
            recyclerPowerFirstHour[_user][userLastActivity.lastCycleForRecycle] = 0;
        }
        userLastActivity.lastUpdatedStats = currentCycle;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the pending XNF rewards for a user across various activities.
     * @dev Rewards are calculated based on user's activities like burning, swapping, recycling, and native participation.
     * @param _user Address of the user to compute rewards for.
     * @return pendingRewardsFromBurn Rewards from burning tokens.
     * @return pendingRewardsFromSwap Rewards from swapping tokens.
     * @return pendingRewardsFromNative Rewards from native token participation.
     */
    function pendingXNF(address _user)
        public
        view
        override
        returns (
            uint256 pendingRewardsFromBurn,
            uint256 pendingRewardsFromSwap,
            uint256 pendingRewardsFromNative
        )
    {
        uint256 rewardsFromYSLBurn;
        uint256 rewardsFromvXENBurn;
        uint256 rewardsFromSwap;
        uint256 rewardsFromNative;
        User memory user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        uint256 cycle = getCurrentCycle();
        if (cycleInfo[userLastActivity.lastCycleForSwap].cycleAccNativeFromSwaps != 0 && user.accCycleSwaps != 0) {
            rewardsFromSwap = calculateRewardPerCycle(userLastActivity.lastCycleForSwap) * user.accCycleSwaps
                                    / cycleInfo[userLastActivity.lastCycleForSwap].cycleAccNativeFromSwaps;
            if (cycleInfo[userLastActivity.lastCycleForBurn].cycleYSLBurnedBatches != 0 || cycleInfo[userLastActivity.lastCycleForBurn].cyclevXENBurnedBatches != 0) {
                rewardsFromSwap /= 2;
            }
            if (cycleInfo[userLastActivity.lastCycleForBurn].cycleNativeBatches != 0) {
                rewardsFromSwap /= 5;
            }
        }
        if (cycleInfo[userLastActivity.lastCycleForNativeParticipation].cycleNativeBatches != 0 && user.accCycleNativeBatches != 0) {
            rewardsFromNative = calculateRewardPerCycle(userLastActivity.lastCycleForNativeParticipation) * user.accCycleNativeBatches
                                    / cycleInfo[userLastActivity.lastCycleForNativeParticipation].cycleNativeBatches;
            if (cycleInfo[userLastActivity.lastCycleForBurn].cycleYSLBurnedBatches != 0 || cycleInfo[userLastActivity.lastCycleForBurn].cyclevXENBurnedBatches != 0) {
                rewardsFromNative /= 2;
            }
            if (cycleInfo[userLastActivity.lastCycleForBurn].cycleAccNativeFromSwaps != 0) {
                rewardsFromNative = rewardsFromNative * 4 / 5;
            }
        }
        if (cycleInfo[userLastActivity.lastCycleForBurn].cycleYSLBurnedBatches != 0 && user.accCycleYSLBurnedBatches != 0) {
            rewardsFromYSLBurn = calculateRewardPerCycle(userLastActivity.lastCycleForBurn) * user.accCycleYSLBurnedBatches
                                    / cycleInfo[userLastActivity.lastCycleForBurn].cycleYSLBurnedBatches;
            if (cycleInfo[userLastActivity.lastCycleForSwap].cycleAccNativeFromSwaps != 0 || cycleInfo[userLastActivity.lastCycleForBurn].cycleNativeBatches != 0) {
                rewardsFromYSLBurn /= 2;
            }
            if (cycleInfo[userLastActivity.lastCycleForBurn].cyclevXENBurnedBatches != 0) {
                rewardsFromYSLBurn /= 2;
            }
        }
        if (cycleInfo[userLastActivity.lastCycleForBurn].cyclevXENBurnedBatches != 0 && user.accCyclevXENBurnedBatches != 0) {
            rewardsFromvXENBurn = calculateRewardPerCycle(userLastActivity.lastCycleForBurn) * user.accCyclevXENBurnedBatches
                                    / cycleInfo[userLastActivity.lastCycleForBurn].cyclevXENBurnedBatches;
            if (cycleInfo[userLastActivity.lastCycleForSwap].cycleAccNativeFromSwaps != 0 || cycleInfo[userLastActivity.lastCycleForBurn].cycleNativeBatches != 0) {
                rewardsFromvXENBurn /= 2;
            }
            if (cycleInfo[userLastActivity.lastCycleForBurn].cycleYSLBurnedBatches != 0) {
                rewardsFromvXENBurn /= 2;
            }
        }
        if (userLastActivity.lastCycleForBurn != cycle && (user.accCycleYSLBurnedBatches != 0 || user.accCyclevXENBurnedBatches != 0)) {
            pendingRewardsFromBurn = rewardsFromYSLBurn + rewardsFromvXENBurn;
        }
        if (userLastActivity.lastCycleForSwap != cycle && user.accCycleSwaps != 0) {
            pendingRewardsFromSwap += rewardsFromSwap;
        }
        if (userLastActivity.lastCycleForNativeParticipation != cycle && user.accCycleNativeBatches != 0) {
            pendingRewardsFromNative += rewardsFromNative;
        }
        if (userLastActivity.lastUpdatedStats < cycle) {
            pendingRewardsFromBurn += user.pendingRewardsFromBurn;
            pendingRewardsFromSwap += user.pendingRewardsFromSwap;
            pendingRewardsFromNative += user.pendingRewardsFromNative;
        } else {
            pendingRewardsFromBurn = user.pendingRewardsFromBurn;
            pendingRewardsFromSwap = user.pendingRewardsFromSwap;
            pendingRewardsFromNative = user.pendingRewardsFromNative;
        }
        return (pendingRewardsFromBurn, pendingRewardsFromSwap, pendingRewardsFromNative);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the pending native token rewards for a user based on their NFT ownership and recycling activities.
     * @dev The rewards are accumulated over cycles and are based on user's recycling power and NFT ownership.
     * @param _user Address of the user to compute native rewards for.
     * @return _pendingNative Total pending native rewards for the user.
     */
    function pendingNative(address _user)
        public
        view
        override
        returns (uint256 _pendingNative)
    {
        User memory user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        uint256 cycle = getCurrentCycle();
        if (userLastActivity.lastUpdatedStats < cycle) {
            uint256 cycleEndTs;
            for (uint256 i = userLastActivity.lastUpdatedStats; i < cycle; i++) {
                cycleEndTs = i_initialTimestamp + i_periodDuration * (i + 1) - 1;
                if (cycleInfo[i].cycleAccNative + cycleInfo[i].cycleAccExactNativeFromSwaps
                    + cycleInfo[i].cycleAccNativeFromAuction + cycleInfo[i].cycleAccNativeFromNativeParticipants != 0) {
                    if (IVeXNF(veXNF).totalBalanceOfNFTAt(_user, cycleEndTs) != 0) {
                        _pendingNative += (cycleInfo[i].cycleAccNative + cycleInfo[i].cycleAccExactNativeFromSwaps
                                            + cycleInfo[i].cycleAccNativeFromAuction + cycleInfo[i].cycleAccNativeFromNativeParticipants)
                                                * IVeXNF(veXNF).totalBalanceOfNFTAt(_user, cycleEndTs) / IVeXNF(veXNF).totalSupplyAtT(cycleEndTs);
                    }
                }
            }
        }
        if (userLastActivity.lastCycleForRecycle < cycle) {
            if (cycleInfo[userLastActivity.lastCycleForRecycle].cycleAccBonus != 0) {
                if (recyclerPowerFirstHour[_user][userLastActivity.lastCycleForRecycle] != 0) {
                    _pendingNative += cycleInfo[userLastActivity.lastCycleForRecycle].cycleAccBonus
                                        * recyclerPowerFirstHour[_user][userLastActivity.lastCycleForRecycle]
                                            / totalPowerOfRecyclersFirstHour[userLastActivity.lastCycleForRecycle];
                }
            }
        }
        if (userLastActivity.lastUpdatedStats < cycle) {
            _pendingNative += user.pendingNative;
        } else {
            _pendingNative = user.pendingNative;
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the pending native token rewards for a user for the current cycle based on their NFT ownership and recycling activities.
     * @dev The rewards are accumulated over cycles and are based on user's recycling power and NFT ownership.
     * @param _user Address of the user to compute native rewards for.
     * @return _pendingNative Total pending native rewards for the user for the current cycle.
     */
    function pendingNativeForCurrentCycle(address _user)
        public
        view
        override
        returns (uint256 _pendingNative)
    {
        User memory user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        uint256 cycle = getCurrentCycle();
        uint256 cycleEndTs;
        cycleEndTs = i_initialTimestamp + i_periodDuration * (cycle + 1) - 1;
        if (cycleInfo[cycle].cycleAccNative + cycleInfo[cycle].cycleAccExactNativeFromSwaps
                + cycleInfo[cycle].cycleAccNativeFromAuction + cycleInfo[cycle].cycleAccNativeFromNativeParticipants != 0) {
            if (IVeXNF(veXNF).totalBalanceOfNFTAt(_user, cycleEndTs) != 0) {
                _pendingNative = (cycleInfo[cycle].cycleAccNative + cycleInfo[cycle].cycleAccExactNativeFromSwaps
                                    + cycleInfo[cycle].cycleAccNativeFromAuction + cycleInfo[cycle].cycleAccNativeFromNativeParticipants)
                                        * IVeXNF(veXNF).totalBalanceOfNFTAt(_user, cycleEndTs) / IVeXNF(veXNF).totalSupplyAtT(cycleEndTs);
            }
        }
        if (userLastActivity.lastCycleForRecycle == cycle) {
            if (cycleInfo[cycle].cycleAccBonus != 0) {
                if (recyclerPowerFirstHour[_user][cycle] != 0) {
                    _pendingNative += cycleInfo[cycle].cycleAccBonus
                                        * recyclerPowerFirstHour[_user][cycle]
                                            / totalPowerOfRecyclersFirstHour[cycle];
                }
            }
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the pending XNF rewards for a user for the current cycle across various activities.
     * @dev Rewards are calculated based on user's activities like burning, swapping, recycling, and native participation.
     * @param _user Address of the user to compute rewards for.
     * @return pendingRewardsFromBurn Rewards from burning tokens.
     * @return pendingRewardsFromSwap Rewards from swapping tokens.
     * @return pendingRewardsFromNative Rewards from native token participation.
     */
    function pendingXNFForCurrentCycle(address _user)
        public
        view
        override
        returns (
            uint256 pendingRewardsFromBurn,
            uint256 pendingRewardsFromSwap,
            uint256 pendingRewardsFromNative
        )
    {
        uint256 rewardsFromYSLBurn;
        uint256 rewardsFromvXENBurn;
        uint256 rewardsFromSwap;
        uint256 rewardsFromNative;
        User memory user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        uint256 cycle = getCurrentCycle();
        if (cycleInfo[cycle].cycleAccNativeFromSwaps != 0 && user.accCycleSwaps != 0) {
            rewardsFromSwap = calculateRewardPerCycle(cycle) * user.accCycleSwaps
                                    / cycleInfo[cycle].cycleAccNativeFromSwaps;
            if (cycleInfo[cycle].cycleYSLBurnedBatches != 0 || cycleInfo[cycle].cyclevXENBurnedBatches != 0) {
                rewardsFromSwap /= 2;
            }
            if (cycleInfo[cycle].cycleNativeBatches != 0) {
                rewardsFromSwap /= 5;
            }
        }
        if (cycleInfo[cycle].cycleNativeBatches != 0 && user.accCycleNativeBatches != 0) {
            rewardsFromNative = calculateRewardPerCycle(cycle) * user.accCycleNativeBatches
                                    / cycleInfo[cycle].cycleNativeBatches;
            if (cycleInfo[cycle].cycleYSLBurnedBatches != 0 || cycleInfo[cycle].cyclevXENBurnedBatches != 0) {
                rewardsFromNative /= 2;
            }
            if (cycleInfo[cycle].cycleAccNativeFromSwaps != 0) {
                rewardsFromNative = rewardsFromNative * 4 / 5;
            }
        }
        if (cycleInfo[cycle].cycleYSLBurnedBatches != 0 && user.accCycleYSLBurnedBatches != 0) {
            rewardsFromYSLBurn = calculateRewardPerCycle(cycle) * user.accCycleYSLBurnedBatches
                                    / cycleInfo[cycle].cycleYSLBurnedBatches;
            if (cycleInfo[cycle].cycleAccNativeFromSwaps != 0 || cycleInfo[cycle].cycleNativeBatches != 0) {
                rewardsFromYSLBurn /= 2;
            }
            if (cycleInfo[cycle].cyclevXENBurnedBatches != 0) {
                rewardsFromYSLBurn /= 2;
            }
        }
        if (cycleInfo[cycle].cyclevXENBurnedBatches != 0 && user.accCyclevXENBurnedBatches != 0) {
            rewardsFromvXENBurn = calculateRewardPerCycle(cycle) * user.accCyclevXENBurnedBatches
                                    / cycleInfo[cycle].cyclevXENBurnedBatches;
            if (cycleInfo[cycle].cycleAccNativeFromSwaps != 0 || cycleInfo[cycle].cycleNativeBatches != 0) {
                rewardsFromvXENBurn /= 2;
            }
            if (cycleInfo[cycle].cycleYSLBurnedBatches != 0) {
                rewardsFromvXENBurn /= 2;
            }
        }
        if (userLastActivity.lastCycleForBurn == cycle && (user.accCycleYSLBurnedBatches != 0 || user.accCyclevXENBurnedBatches != 0)) {
            pendingRewardsFromBurn = rewardsFromYSLBurn + rewardsFromvXENBurn;
        }
        if (userLastActivity.lastCycleForSwap == cycle && user.accCycleSwaps != 0) {
            pendingRewardsFromSwap += rewardsFromSwap;
        }
        if (userLastActivity.lastCycleForNativeParticipation == cycle && user.accCycleNativeBatches != 0) {
            pendingRewardsFromNative += rewardsFromNative;
        }
        return (pendingRewardsFromBurn, pendingRewardsFromSwap, pendingRewardsFromNative);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Determines the burn or native fee for a given number of batches, adjusting for the time within the current cycle.
     * @dev The burn and native fee is dynamic and changes based on the number of hours passed in the current cycle.
     * @param batchNumber The number of batches for which the burn or native fee is being calculated.
     * @return burnFee The calculated burn or native fee in wei for the given number of batches.
     */
    function coefficientWrapper(uint256 batchNumber)
        public
        view
        override
        returns (uint256 burnFee)
    {
        uint256 cycle = getCurrentCycle();
        uint256 startOfCurrentCycle = i_initialTimestamp + cycle * i_periodDuration + 1;
        uint256 hoursPassed = (block.timestamp - startOfCurrentCycle) / 1 hours;
        uint256 burnCoefficient;
        if (hoursPassed == 0) {
            burnCoefficient = 50 * BP;
        }
        else {
            burnCoefficient = 50 * BP + (50 * BP * hoursPassed) / 23;
        }
        uint256 ETHValueOfBatches = batchFee * batchNumber;
        uint256 constantValue;
        if (hoursPassed > 19) {
            constantValue = 0;
        }
        else {
           constantValue = 5 * 1e13 - (hoursPassed * 5 * 1e12) / 2;
        }
        burnFee = burnCoefficient * ETHValueOfBatches
                                        * (1e18 - constantValue * batchNumber) / (100 * BP * BP);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the current cycle number based on the time elapsed since the contract's initialization.
     * @dev The cycle number is determined by dividing the elapsed time by the period duration.
     * @return The current cycle number, representing how many complete cycles have elapsed.
     */
    function getCurrentCycle()
        public
        view
        override
        returns (uint256)
    {
        return (block.timestamp - i_initialTimestamp) / i_periodDuration;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the reward amount for a given cycle, adjusting for halving events.
     * @dev The reward amount decreases over time based on predefined halving cycles.
     * @param cycle The cycle number for which the reward is being calculated.
     * @return The reward amount for the specified cycle.
     */
    function calculateRewardPerCycle(uint256 cycle)
        public
        view
        override
        returns (uint256)
    {
        for (uint256 i; i < 7; i++) {
            if (cycle >= cyclesForHalving[i] && cycle < cyclesForHalving[i+1]) {
                return rewardsPerHalving[i];
            }
        }
        if (cycle >= cyclesForHalving[7]) {
            return 0;
        }
        if (cycle < cyclesForHalving[0]) {
            return 20000 ether;
        }
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Initialises liquidity for the XNF token by calculating the required XNF amount based on native token price.
     * @dev The function ensures that the liquidity is only added once.
     */
    function _addInitialLiquidity() internal {
        if (_isTriggered) {
            return;
        }
        uint256 nativeAmount = cycleInfo[0].cycleAccNative
                                + cycleInfo[0].cycleAccExactNativeFromSwaps
                                + cycleInfo[0].cycleAccNativeFromAuction
                                + cycleInfo[0].cycleAccNativeFromNativeParticipants;
        uint256 xnfRequired = 1e5 ether;
        xnf.mint(address(this), xnfRequired);
        uint256 amount0;
        uint256 amount1;
        address token0;
        address token1;
        address weth = nonfungiblePositionManager.WETH9();
        if (weth < address(xnf)) {
            token0 = weth;
            token1 = address(xnf);
            amount0 = nativeAmount;
            amount1 = xnfRequired;
        } else {
            token0 = address(xnf);
            token1 = weth;
            amount0 = xnfRequired;
            amount1 = nativeAmount;
        }
        uint160 sqrtPrice = Math.sqrt(uint160(amount1)) * 2**96 / Math.sqrt(uint160(amount0));
        TransferHelper.safeApprove(address(xnf), address(nonfungiblePositionManager), xnfRequired);
        address pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, POOL_FEE, sqrtPrice);
        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: POOL_FEE,
                tickLower: TickMath.MIN_TICK / IUniswapV3Pool(pool).tickSpacing() * IUniswapV3Pool(pool).tickSpacing(),
                tickUpper: TickMath.MAX_TICK / IUniswapV3Pool(pool).tickSpacing() * IUniswapV3Pool(pool).tickSpacing(),
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: Recycle,
                deadline: block.timestamp + 100
            });
        (uint256 tokenId, , , ) = nonfungiblePositionManager.mint{value: nativeAmount} (params);
        IRecycle(Recycle).setTokenId(tokenId);
        IXNF(address(xnf)).setLPAddress(pool);
        _isTriggered = true;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Updates the statistics for a specific user.
     * @dev This function recalculates the current cycle and updates the user's statistics accordingly.
     * @param _user Address of the user whose statistics are being updated.
     */
    function _updateStatsForUser(address _user) internal {
        calculateCycle();
        updateStats(_user);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims the accumulated native rewards for a specific user.
     * @dev This function also updates the cycle's accumulated bonus based on the user's pending native rewards.
     * @param _user Address of the user for whom the native rewards are being claimed.
     */
    function _claimNative(address _user) internal {
        cycleInfo[currentCycle].cycleAccBonus += userInfo[_user].pendingNative * 25 / 100;
        if (lastClaimFeesCycle != currentCycle) {
            if (cycleInfo[lastClaimFeesCycle].cycleAccBonus != 0 && totalPowerOfRecyclersFirstHour[lastClaimFeesCycle] == 0) {
                cycleInfo[currentCycle].cycleAccBonus += cycleInfo[lastClaimFeesCycle].cycleAccBonus;
                cycleInfo[lastClaimFeesCycle].cycleAccBonus = 0;
            }
            lastClaimFeesCycle = currentCycle;
        }
        uint256 nativeAmount = userInfo[_user].pendingNative * 75 / 100;
        userInfo[_user].pendingNative = 0;
        _sendViaCall(
            payable(_user),
            nativeAmount
        );
        emit NativeClaimed(
            _user,
            currentCycle,
            userInfo[_user].pendingNative * 25 / 100,
            nativeAmount
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims the accumulated XNF rewards for a specific user.
     * @dev This function mints and transfers the XNF tokens to the user.
     * @param _user Address of the user for whom the XNF rewards are being claimed.
     */
    function _claimXNF(address _user) internal {
        uint256 pendingRewardsFromBurn = userInfo[_user].pendingRewardsFromBurn;
        userInfo[_user].pendingRewardsFromBurn = 0;
        if (pendingRewardsFromBurn != 0) {
            xnf.mint(_user, pendingRewardsFromBurn);
        }
        if (!_isTriggered && lastActiveCycle != currentCycle && lastActiveCycle == 0) {
            _addInitialLiquidity();
        }
        emit XNFClaimed(
            _user,
            currentCycle,
            pendingRewardsFromBurn
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Claims the accumulated veXNF rewards for a specific user.
     * @dev This function mints and transfers the veXNF tokens to the user.
     * @param _user Address of the user for whom the veXNF rewards are being claimed.
     */
    function _claimveXNF(address _user) internal {
        uint256 pendingRewardsFromSwap = userInfo[_user].pendingRewardsFromSwap;
        uint256 pendingRewardsFromNative = userInfo[_user].pendingRewardsFromNative;
        userInfo[_user].pendingRewardsFromSwap = 0;
        userInfo[_user].pendingRewardsFromNative = 0;
        if (pendingRewardsFromSwap != 0) {
            xnf.mint(address(this), pendingRewardsFromSwap);
        }
        if (pendingRewardsFromNative != 0) {
            xnf.mint(address(this), pendingRewardsFromNative);
        }
        uint256 pendingveXNF = pendingRewardsFromSwap + pendingRewardsFromNative;
        if (pendingveXNF != 0) {
            xnf.approve(veXNF, pendingveXNF);
            IVeXNF(veXNF).createLockFor(pendingveXNF, 365, _user);
            emit veXNFClaimed(_user, currentCycle, pendingveXNF);
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows users to recycle their native rewards and subsequently claim their rewards.
     * @dev Users can recycle their native rewards and receive rewards based on their participation in the cycle.
     * @param _user Address of the user performing the recycling action.
     */
    function _recycle(address _user) internal {
        uint256 nativeAmount = userInfo[_user].pendingNative;
        userInfo[_user].pendingNative = 0;
        if (nativeAmount == 0) {
           revert NoNativeRewardsForRecycling();
        }
        uint256 batchNumber = nativeAmount / batchFee;
        if (batchNumber > 1e4) {
            batchNumber = 1e4;
        }
        uint256 burnFee = coefficientWrapper(batchNumber);
        IRecycle(Recycle).recycle{value: nativeAmount - burnFee} ();
        _burn(_user, batchNumber, burnFee);
        uint256 startOfCurrentCycle = i_initialTimestamp + currentCycle * i_periodDuration + 1;
        uint256 hoursPassed = (block.timestamp - startOfCurrentCycle) / 1 hours;
        if (hoursPassed == 0) {
            recyclerPowerFirstHour[_user][currentCycle] = IVeXNF(veXNF).totalBalanceOfNFTAt(_user, block.timestamp);
            totalPowerOfRecyclersFirstHour[currentCycle] += IVeXNF(veXNF).totalBalanceOfNFTAt(_user, block.timestamp);
        }
        userLastActivityInfo[_user].lastCycleForRecycle = currentCycle;
        emit RecycleAction(
            _user,
            currentCycle,
            burnFee,
            batchNumber,
            nativeAmount,
            recyclerPowerFirstHour[_user][currentCycle],
            totalPowerOfRecyclersFirstHour[currentCycle]
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initialises or updates cycle data based on the provided parameters.
     * @dev This function sets up the cycle data for a new cycle or updates an existing cycle's data.
     * @param _YSLBatchAmount Number of YSL batches being burned.
     * @param _vXENBatchAmount Number of vXEN batches being burned.
     * @param _nativeBatchAmount Number of native batches.
     * @param _exactSwapFee Exact fee from swapping.
     * @param _burnFee Fee amount for burning.
     */
    function _setupNewCycle(
        uint256 _YSLBatchAmount,
        uint256 _vXENBatchAmount,
        uint256 _nativeBatchAmount,
        uint256 _exactSwapFee,
        uint256 _burnFee
    ) internal {
        Cycle storage cycle = cycleInfo[currentCycle];
        uint256 swapFee;
        uint256 feeFromNative;
        if (_exactSwapFee != 0) {
            swapFee = _burnFee;
            _burnFee = 0;
        }
        if (_nativeBatchAmount != 0) {
            feeFromNative = _burnFee;
            _burnFee = 0;
        }
        uint256 amountToAddLiquidity;
        if (_burnFee != 0) {
            amountToAddLiquidity = _burnFee * 3 / 5;
        } else if (swapFee != 0) {
            amountToAddLiquidity = _exactSwapFee * 3 / 5;
        } else {
            amountToAddLiquidity = feeFromNative * 3 / 5;
        }
        if (lastActiveCycle != 0 && lastActiveCycle != currentCycle) {
            uint256 cycleEndTs = i_initialTimestamp + i_periodDuration * (lastActiveCycle + 1) - 1;
            if (IVeXNF(veXNF).totalSupplyAtT(cycleEndTs) == 0) {
                if (cycleInfo[lastActiveCycle].cycleAccNative != 0
                        || cycleInfo[lastActiveCycle].cycleAccExactNativeFromSwaps != 0
                        || cycleInfo[lastActiveCycle].cycleAccNativeFromAuction != 0
                        || cycleInfo[lastActiveCycle].cycleAccNativeFromNativeParticipants != 0)
                {
                uint256 nativeAmount = cycleInfo[lastActiveCycle].cycleAccNative +
                        cycleInfo[lastActiveCycle].cycleAccExactNativeFromSwaps +
                        cycleInfo[lastActiveCycle].cycleAccNativeFromAuction +
                        cycleInfo[lastActiveCycle].cycleAccNativeFromNativeParticipants;
                        IRecycle(Recycle).executeBuybackBurn{value: nativeAmount} ();
                }
            }
        }
        if (currentCycle == 0 && cycle.accRewards == 0) {
            cycle.cycleYSLBurnedBatches = _YSLBatchAmount;
            cycle.cyclevXENBurnedBatches = _vXENBatchAmount;
            cycle.cycleNativeBatches = _nativeBatchAmount;
            cycle.cycleAccNative = _burnFee;
            cycle.cycleAccNativeFromSwaps = swapFee;
            cycle.cycleAccNativeFromNativeParticipants = feeFromNative;
            cycle.cycleAccExactNativeFromSwaps = _exactSwapFee;
            cycle.accRewards = calculateRewardPerCycle(currentCycle);
        }
        else if (lastActiveCycle != currentCycle) {
            cycleInfo[currentCycle] = Cycle(
                lastActiveCycle,
                _YSLBatchAmount,
                _vXENBatchAmount,
                _nativeBatchAmount,
                _burnFee * 2 / 5,
                swapFee,
                feeFromNative * 2 / 5,
                cycleInfo[currentCycle].cycleAccNativeFromAuction,
                _exactSwapFee * 2 / 5,
                0,
                calculateRewardPerCycle(currentCycle)
            );
            if (lastActiveCycle == 0) {
                _addInitialLiquidity();
            }
            IRecycle(Recycle).executeBuybackBurn{value: amountToAddLiquidity} ();
            lastActiveCycle = currentCycle;
        }
        else {
            cycle.cycleYSLBurnedBatches += _YSLBatchAmount;
            cycle.cyclevXENBurnedBatches += _vXENBatchAmount;
            cycle.cycleNativeBatches += _nativeBatchAmount;
            if (currentCycle == 0) {
                cycle.cycleAccNative += _burnFee;
                cycle.cycleAccNativeFromSwaps += swapFee;
                cycle.cycleAccExactNativeFromSwaps += _exactSwapFee;
                cycle.cycleAccNativeFromNativeParticipants += feeFromNative;
            } else {
                cycle.cycleAccNative += _burnFee * 2 / 5;
                cycle.cycleAccNativeFromSwaps += swapFee;
                cycle.cycleAccExactNativeFromSwaps += _exactSwapFee * 2 / 5;
                cycle.cycleAccNativeFromNativeParticipants += feeFromNative * 2 / 5;
                IRecycle(Recycle).executeBuybackBurn{value: amountToAddLiquidity} ();
            }
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns tokens for a user based on the number of batches and the native amount provided.
     * @dev Calculates the number of YSL and vXEN batches to burn, updates user statistics, and handles rewards.
     * @param _user Address of the user whose tokens are being burned.
     * @param _batchNumber Total number of batches being burned.
     * @param _nativeAmount Amount of native currency associated with the burn.
     */
    function _burn(
        address _user,
        uint256 _batchNumber,
        uint256 _nativeAmount
    ) internal {
        User storage user = userInfo[_user];
        UserLastActivity storage userLastActivity = userLastActivityInfo[_user];
        uint256 burnFee = coefficientWrapper(_batchNumber);
        uint256 YSLBurnedBatches;
        uint256 vXENBurnedBatches;
        if (cycleInfo[currentCycle].cycleYSLBurnedBatches == cycleInfo[currentCycle].cyclevXENBurnedBatches) {
            if (_batchNumber % 2 != 0) {
                vXENBurnedBatches = _batchNumber / 2 + 1;
                YSLBurnedBatches = _batchNumber / 2;
            } else {
                YSLBurnedBatches = _batchNumber / 2;
                vXENBurnedBatches = _batchNumber / 2;
            }
        } else if (cycleInfo[currentCycle].cycleYSLBurnedBatches > cycleInfo[currentCycle].cyclevXENBurnedBatches) {
            uint256 diff = cycleInfo[currentCycle].cycleYSLBurnedBatches - cycleInfo[currentCycle].cyclevXENBurnedBatches;
            if (diff >= _batchNumber) {
                vXENBurnedBatches = _batchNumber;
            } else {
                uint256 remainder = _batchNumber - diff;
                if (remainder % 2 != 0) {
                    YSLBurnedBatches = remainder / 2 + 1;
                    vXENBurnedBatches = remainder / 2 + diff;
                } else {
                    YSLBurnedBatches = remainder / 2;
                    vXENBurnedBatches = remainder / 2 + diff;
                }
            }
        } else {
            uint256 diff = cycleInfo[currentCycle].cyclevXENBurnedBatches - cycleInfo[currentCycle].cycleYSLBurnedBatches;
            if (diff >= _batchNumber) {
                YSLBurnedBatches = _batchNumber;
            } else {
                uint256 remainder = _batchNumber - diff;
                if (remainder % 2 != 0) {
                    YSLBurnedBatches = remainder / 2 + diff;
                    vXENBurnedBatches = remainder / 2 + 1;
                } else {
                    YSLBurnedBatches = remainder / 2 + diff;
                    vXENBurnedBatches = remainder / 2;
                }
            }
        }
        _setupNewCycle(YSLBurnedBatches, vXENBurnedBatches, 0, 0, burnFee);
        if (currentCycle == 0) {
            user.accCycleYSLBurnedBatches += YSLBurnedBatches;
            user.accCyclevXENBurnedBatches += vXENBurnedBatches;
        }
        else {
            updateStats(_user);
            if (userLastActivity.lastCycleForBurn != currentCycle) {
                user.accCycleYSLBurnedBatches = YSLBurnedBatches;
                user.accCyclevXENBurnedBatches = vXENBurnedBatches;
            } else {
                user.accCycleYSLBurnedBatches += YSLBurnedBatches;
                user.accCyclevXENBurnedBatches += vXENBurnedBatches;
            }
            userLastActivity.lastCycleForBurn = currentCycle;
        }
        if (_nativeAmount < burnFee) {
            revert InsufficientNativeValue(_nativeAmount, burnFee);
        }
        _sendViaCall(
            payable(_user),
            _nativeAmount - burnFee
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sends the specified amount of native currency to the provided address.
     * @dev Uses a low-level call to send native currency. Reverts if the send operation fails.
     * @param to Address to send the native currency to.
     * @param amount Amount of native currency to send.
     */
    function _sendViaCall(
        address payable to,
        uint256 amount
    ) internal {
        (bool sent, ) = to.call{value: amount} ("");
        if (!sent) {
            revert TransferFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}