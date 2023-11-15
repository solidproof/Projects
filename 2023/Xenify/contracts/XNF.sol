// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {StringToAddress, AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroEndpoint.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWormholeRelayer} from "./interfaces/IWormholeRelayer.sol";
import {IBurnRedeemable} from "./interfaces/IBurnRedeemable.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IXNF} from "./interfaces/IXNF.sol";

/*
 * @title XNF Contract
 *
 * @notice XNF is an ERC20 token with enhanced features such as token locking and specialized minting
 * and burning mechanisms. It's primarily used within a broader protocol to reward users who burn YSL or vXEN.
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
contract XNF is
    IXNF,
    ERC20,
    AxelarExecutable
{

    /// ------------------------------------- LIBRARYS ------------------------------------- \\\

    /**
     * @notice Utility library to convert a string representation into an address.
     */
    using StringToAddress for string;

    /**
     * @notice Utility library to convert an address into its string representation.
     */
    using AddressToString for address;

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Address of the Auction contract, set during deployment and cannot be changed.
     */
    address public Auction;

    /**
     * @notice Address of the Recycle contract, set during deployment and cannot be changed.
     */
    address public Recycle;

    /**
     * @notice Address of the protocol owned liquidity pool contract, set after initialising the pool and cannot be changed.
     */
    address public lpAddress;

    /**
     * @notice Address of the XNF token in a string format.
     */
    string public XNFAddress;

    /**
     * @notice Root of the Merkle tree used for airdrop claims.
     */
    bytes32 public merkleRoot;

    /**
     * @notice Duration (in days) for which tokens are locked. Set to 730 days (2 years).
     */
    uint256 public lockPeriod;

    /**
     * @notice Timestamp when the contract was initialised, set during deployment and cannot be changed.
     */
    uint256 public i_timestamp;

    /**
     * @notice Indicator to check if the function was invoked previously.
     */
    bool internal _isTriggered;

    /// ------------------------------------ INTERFACES ------------------------------------- \\\

    /**
     * @notice Interface to interact with the LayerZero endpoint for bridging operations.
     */
    ILayerZeroEndpoint public immutable endpoint;

    /**
     * @notice Interface to interact with the Axelar gas service for fee estimations.
     */
    IAxelarGasService public immutable gasService;

    /**
     * @notice Interface to interact with the Wormhole relayer for bridging operations.
     */
    IWormholeRelayer public immutable wormholeRelayer;

    /// ------------------------------------ MAPPINGS --------------------------------------- \\\

    /**
     * @notice Keeps track of token lock details for each user.
     */
    mapping (address => Lock) public userLocks;

    /**
     * @notice Records the total number of tokens burned by each user.
     */
    mapping (address => uint256) public userBurns;

    /**
     * @notice Mapping to track if a user has claimed their airdrop.
     */
    mapping (bytes32 => bool) public airdropClaimed;

    /**
     * @notice Mapping to prevent replay attacks from Wormhole.
     */
    mapping (bytes32 => bool) public seenDeliveryVaaHashes;

    /// ------------------------------------- MODIFIER -------------------------------------- \\\

    /**
     * @notice Modifier to protect the contract from replay attacks.
     * @dev Ensures that a particular delivery hash from the Wormhole relayer is only processed once.
     * @param deliveryHash The unique hash received from the Wormhole relayer.
     */
    modifier replayProtect(bytes32 deliveryHash) {
        if (seenDeliveryVaaHashes[deliveryHash]) {
            revert WormholeMessageAlreadyProcessed();
        }
        seenDeliveryVaaHashes[deliveryHash] = true;
        _;
    }

    /// ------------------------------------ CONSTRUCTOR ------------------------------------ \\\

    /**
     * @notice Initialises the XNF token with a specified storage contract address, sets the token's name and symbol.
     * @param _gateway Address of the Axelar gateway contract for cross-chain communication.
     * @param _gasService Address of the Axelar gas service contract used to handle gas payments for cross-chain transactions.
     * @param _endpoint Address of the LayerZero endpoint contract used for cross-chain message passing.
     * @param _wormholeRelayer Address of the Wormhole relayer contract used to relay messages across chains.
     */
    constructor(
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    )
        payable
        ERC20("XNF", "XNF")
        AxelarExecutable(_gateway)
    {
        endpoint = ILayerZeroEndpoint(_endpoint);
        gasService = IAxelarGasService(_gasService);
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        XNFAddress = address(this).toString();
    }

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Initialises the contract with Auction contract's address and merkleRoot.
     * @dev Fails if the contract has already been initialised i.e., address of Auction is zero.
     * @param _auction Address of the Auction contract.
     * @param _merkleRoot Hashed Root of Merkle Tree for Airdrop.
     */
    function initialise(
        address _auction,
        address _recycle,
        bytes32 _merkleRoot
    ) external {
        if (Auction != address(0))
            revert ContractInitialised(Auction);
        lockPeriod = 730;
        Auction = _auction;
        Recycle = _recycle;
        merkleRoot = _merkleRoot;
        i_timestamp = block.timestamp;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sets the liquidity pool (LP) address.
     * @dev Only the Auction contract is allowed to call this function.
     * @param _lp The address of the liquidity pool to be set.
     */
    function setLPAddress(address _lp)
        external
        override
    {
        if (msg.sender != Auction) {
            revert OnlyAuctionAllowed();
        }
        lpAddress = _lp;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Allows users to claim their airdropped tokens using a Merkle proof.
     * @dev Verifies the Merkle proof against the stored Merkle root and mints the claimed amount to the user.
     * @param proof Array of bytes32 values representing the Merkle proof.
     * @param account Address of the user claiming the airdrop.
     * @param amount Amount of tokens being claimed.
     */
    function claim(
        bytes32[] calldata proof,
        address account,
        uint256 amount
    )
        external
        override
    {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidClaimProof();
        }
        if (airdropClaimed[leaf]) {
            revert AirdropAlreadyClaimed();
        }
        if (i_timestamp + 2 hours > block.timestamp ) {
            revert TooEarlyToClaim();
        }
        airdropClaimed[leaf] = true;
        _mint(account, amount);
        unchecked {
            userLocks[account] = Lock(
                amount,
                block.timestamp,
                uint128((amount * 1e18) / lockPeriod),
                0
            );
        }
        emit Airdropped(account, amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Mints XNF tokens to a specified account.
     * @dev Only the Auction contract can mint tokens, and the total supply cap is checked before minting.
     * @param account Address receiving the minted tokens.
     * @param amount Number of tokens to mint.
     */
    function mint(
        address account,
        uint256 amount
    )
        external
        override
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        if (msg.sender != Auction) {
            revert OnlyAuctionAllowed();
        }
        if (totalSupply() + amount >= 22_600_000 ether) {
            revert ExceedsMaxSupply();
        }
        _mint(account, amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns a specified amount of tokens from a user's account.
     * @dev The calling contract must support the IBurnRedeemable interface.
     * @param user Address from which tokens will be burned.
     * @param amount Number of tokens to burn.
     */
    function burn(
        address user,
        uint256 amount
    )
        external
        override
    {
        if (!IERC165(msg.sender).supportsInterface(type(IBurnRedeemable).interfaceId)) {
            revert UnsupportedInterface();
        }
        if (msg.sender != user) {
            _spendAllowance(user, msg.sender, amount);
        }
        _burn(user, amount);
        unchecked{
            userBurns[user] += amount;
        }
        IBurnRedeemable(msg.sender).onTokenBurned(user, amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to a target chain using the LayerZero network.
     * @dev Estimates the gas fee, checks if the provided Ether covers the fee, and sends the tokens through the LayerZero endpoint.
     * @param _dstChainId Chain ID of the target chain.
     * @param from Address on the source chain sending the tokens.
     * @param to Address on the target chain receiving the tokens.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address on the source chain to receive any fee refund.
     * @param _zroPaymentAddress Address of the ZRO token holder paying for the transaction.
     * @param _adapterParams Parameters for custom functionalities, e.g., receiving airdropped native gas from the relayer on the target chain.
     */
    function bridgeViaLayerZero(
        uint16 _dstChainId,
        address from,
        address to,
        uint256 _amount,
        address payable feeRefundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    )
        external
        payable
        override
    {
        if (_zroPaymentAddress == address(0)) {
            if (msg.value < estimateGasForLayerZero(_dstChainId, from, to, _amount, false, _adapterParams)) {
                revert InsufficientFee();
            }
        }
        else {
            if (msg.value < estimateGasForLayerZero(_dstChainId, from, to, _amount, true, _adapterParams)) {
                revert InsufficientFee();
            }
        }
        if (msg.sender != from)
            _spendAllowance(from, msg.sender, _amount);
        _burn(from, _amount);
        endpoint.send{value: msg.value} (
            _dstChainId,
            abi.encodePacked(address(this),address(this)),
            abi.encode(from, to, _amount),
            feeRefundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
        emit XNFBridgeTransfer(from, _amount, BridgeId.LayerZero, abi.encode(_dstChainId), to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to a target chain using the Axelar network.
     * @dev Encodes the sender's address and amount into a payload, then sends the tokens through the Axelar gateway.
     * @param destinationChain Name of the target chain.
     * @param from Address on the source chain sending the tokens.
     * @param to Address on the target chain receiving the tokens.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address on the source chain to receive any fee refund.
     */
    function bridgeViaAxelar(
        string calldata destinationChain,
        address from,
        address to,
        uint256 _amount,
        address payable feeRefundAddress
    )
        external
        payable
        override
    {
        bytes memory payload = abi.encode(from, to, _amount);
        string memory _XNFAddress = XNFAddress;
        if (msg.value != 0) {
            gasService.payNativeGasForContractCall{value: msg.value} (
                address(this),
                destinationChain,
                _XNFAddress,
                payload,
                feeRefundAddress
            );
        }
        if (from != msg.sender)
            _spendAllowance(from, msg.sender, _amount);
        _burn(from, _amount);
        gateway.callContract(destinationChain, _XNFAddress, payload);
        emit XNFBridgeTransfer(from, _amount, BridgeId.Axelar, abi.encode(destinationChain), to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Receives tokens from the LayerZero bridge.
     * @dev Decodes the user's address and amount from the payload and mints the tokens to the user's address.
     * @param _srcChainId Chain ID of the source chain.
     * @param _srcAddress Address on the source chain sending the tokens.
     * @param _payload Encoded data containing user's address and amount.
     */
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    )
        external
        override
    {
        if (address(endpoint) != msg.sender) {
            revert NotVerifiedCaller();
        }
        if (address(this) != address(uint160(bytes20(_srcAddress)))) {
            revert InvalidLayerZeroSourceAddress();
        }
        (address from, address to, uint256 _amount) = abi.decode(
            _payload,
            (address, address, uint256)
        );
        _mint(to, _amount);
        emit XNFBridgeReceive(to, _amount, BridgeId.LayerZero, abi.encode(_srcChainId), from);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to a target chain using the Wormhole network.
     * @dev Estimates the gas fee, checks if the provided Ether covers the fee, and sends the tokens through the Wormhole relayer.
     * @param targetChain Chain ID of the target chain.
     * @param from Address on the source chain sending the tokens.
     * @param to Address on the target chain receiving the tokens.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address on the target chain to receive any fee refund.
     * @param _gasLimit Gas limit for the transaction on the target chain.
     */
    function bridgeViaWormhole(
        uint16 targetChain,
        address from,
        address to,
        uint256 _amount,
        address payable feeRefundAddress,
        uint256 _gasLimit
    )
        external
        payable
        override
    {
        uint256 cost = estimateGasForWormhole(targetChain, _gasLimit);
        if (msg.value < cost) {
            revert InsufficientFeeForWormhole();
        }
        if (msg.sender != from)
            _spendAllowance(from, msg.sender, _amount);
        _burn(from, _amount);
        wormholeRelayer.sendPayloadToEvm{value: msg.value} (
            targetChain,
            address(this),
            abi.encode(from, to, _amount),
            0,
            _gasLimit,
            targetChain,
            feeRefundAddress
        );
        emit XNFBridgeTransfer(from, _amount, BridgeId.Wormhole, abi.encode(targetChain), to);
    }

    /// --------------------------------- PUBLIC FUNCTIONS ---------------------------------- \\\

    /**
     * @notice Determines the number of days since a user's tokens were locked.
     * @dev If the elapsed days exceed the lock period, it returns the lock period.
     * @param _user Address of the user to check.
     * @return passedDays Number of days since the user's tokens were locked, capped at the lock period.
     */
    function daysPassed(address _user)
        public
        override
        view
        returns (uint256 passedDays)
    {
        passedDays = (block.timestamp - userLocks[_user].timestamp) / 1 days;
        if (passedDays > lockPeriod) {
            passedDays = lockPeriod;
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the amount of unlocked tokens for a user based on the elapsed time since locking.
     * @dev If the user's tokens have been locked for the full lock period, all tokens are considered unlocked.
     * @param _user Address of the user to check.
     * @return unlockedTokens Number of tokens that are currently unlocked for the user.
     */
    function getUnlockedTokensAmount(address _user)
        public
        override
        view
        returns (uint256 unlockedTokens)
    {
        uint256 passedDays = daysPassed(_user);
        Lock storage lock = userLocks[_user];
        if (userLocks[_user].timestamp != 0) {
            if (passedDays >= lockPeriod) {
                unlockedTokens = lock.amount;
            } else {
                unchecked {
                    unlockedTokens = (passedDays * lock.dailyUnlockAmount) / 1e18;
                }
            }
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Receives tokens via the Wormhole bridge.
     * @dev This function is called by the Wormhole relayer to mint tokens after they've been bridged from another chain.
     * Only the Wormhole relayer can call this function. The function decodes the user address and amount from the payload,
     * and then mints the respective amount of tokens to the user's address.
     * @param payload The encoded data containing user address and amount.
     * @param sourceAddress The address of the caller on the source chain in bytes32.
     * @param _srcChainId The chain ID of the source chain from which the tokens are being bridged.
     * @param deliveryHash The hash which is used to verify relay calls.
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory,
        bytes32 sourceAddress,
        uint16 _srcChainId,
        bytes32 deliveryHash
    )
        public
        payable
        override
        replayProtect(deliveryHash)
    {
        if (msg.sender != address(wormholeRelayer)) {
            revert OnlyRelayerAllowed();
        }
        if (address(this) != address(uint160(uint256(sourceAddress)))) {
            revert InvalidWormholeSourceAddress();
        }
        (address from, address to, uint256 _amount) = abi.decode(
            payload,
            (address, address, uint256)
        );
        _mint(to, _amount);
        emit XNFBridgeReceive(to, _amount, BridgeId.Wormhole, abi.encode(_srcChainId), from);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Estimates the gas fee for a bridging operation via LayerZero.
     * @dev This function uses the `estimateFees` method of the endpoint contract to determine
     * the gas fee required to bridge a specified amount of tokens to a target chain.
     * @param _dstChainId The Chain ID of the destination chain.
     * @param from The address on the source chain to send the tokens.
     * @param to The address on the destination chain to receive the tokens.
     * @param _amount The amount of tokens to bridge.
     * @param _payInZRO - if false, user app pays the protocol fee in native token
     * @param _adapterParam - parameters for the adapter service, e.g. send some dust native token to dstChain
     * @return nativeFee The estimated fee required in native tokens for the bridging operation.
     */
    function estimateGasForLayerZero(
        uint16 _dstChainId,
        address from,
        address to,
        uint256 _amount,
        bool _payInZRO,
        bytes calldata _adapterParam
    )
        public
        override
        view
        returns (uint256 nativeFee)
    {
        (nativeFee, ) = endpoint.estimateFees(
            _dstChainId,
            address(this),
            abi.encode(from, to, _amount),
            _payInZRO,
            _adapterParam
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Estimates the gas fee for an operation via Wormhole.
     * @dev This function utilises the `quoteEVMDeliveryPrice` method from the wormholeRelayer contract
     * to determine the gas fee needed for a specified gas limit on a target chain.
     * @param targetChain The Chain ID of the destination chain.
     * @param _gasLimit The gas limit for the transaction on destination chain.
     * @return cost The estimated fee required for the operation.
     */
    function estimateGasForWormhole(
        uint16 targetChain,
        uint256 _gasLimit
    )
        public
        override
        view
        returns (uint256 cost)
    {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            _gasLimit
        );
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Executes a mint operation based on data from another chain.
     * @dev The function decodes the `payload` to extract the user's address and the amount,
     * then proceeds to mint tokens to the user's account. This is an internal function and can't
     * be called externally.
     * @param sourceChain The name or identifier of the source chain from which the tokens are being bridged.
     * @param sourceAddress The originating address from the source chain.
     * @param payload The encoded data payload containing user information and the amount to mint.
     */
    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    )
        internal
        override
    {
        if (sourceAddress.toAddress() != address(this)) {
            revert InvalidSourceAddress();
        }
        (address from, address to, uint256 _amount) = abi.decode(
            payload,
            (address, address, uint256)
        );
        _mint(to, _amount);
        emit XNFBridgeReceive(to, _amount, BridgeId.Axelar, abi.encode(sourceChain), from);
    }

    /// --------------------------------------------------------------------------------- \\\

    /**
     * @notice Manages token transfers, ensuring that locked tokens are not transferred.
     * @dev This hook is invoked before any token transfer. It checks the locking conditions and updates lock details.
     * @param from Address sending the tokens.
     * @param amount Number of tokens being transferred.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
    {
        if (userLocks[from].timestamp != 0) {
            Lock storage lock = userLocks[from];
            uint256 passedDays = daysPassed(from);
            uint256 unlockedTokens = getUnlockedTokensAmount(from);
            uint256 userBalance = balanceOf(from);
            if (passedDays >= lockPeriod) {
                lock.timestamp = 0;
            }
            if (amount > userBalance - (lock.amount - unlockedTokens)) {
                revert InsufficientUnlockedTokens();
            }
            uint256 userUsedAmount = userLocks[from].usedAmount;
            unchecked {
                uint256 notLockedTokens = userBalance + userUsedAmount - userLocks[from].amount;
                if (amount > notLockedTokens) {
                    userLocks[from].usedAmount = uint128(userUsedAmount + amount - notLockedTokens);
                }
            }
        }
        if (lpAddress != address(0) && from == lpAddress && to != Recycle) {
            revert CantPurchaseFromPOL();
        }
        if (lpAddress != address(0) && to == lpAddress && from != Recycle && from != Auction) {
            revert CanSellOnlyViaRecycle();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}