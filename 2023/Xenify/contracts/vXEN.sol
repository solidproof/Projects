// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {StringToAddress, AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {ILayerZeroEndpoint} from "@layerzerolabs/lz-evm-sdk-v1-0.7/contracts/interfaces/ILayerZeroEndpoint.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWormholeRelayer} from "./interfaces/IWormholeRelayer.sol";
import {IBurnRedeemable} from "./interfaces/IBurnRedeemable.sol";
import {IBurnableToken} from "./interfaces/IBurnableToken.sol";
import {IvXEN} from "./interfaces/IvXEN.sol";

/*
 * @title vXEN Contract
 *
 * @notice Represents the vXEN token, an ERC20 token with bridging and burning capabilities.
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
contract vXEN is
    IvXEN,
    ERC20,
    ERC165,
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
     * @notice Address of the vXEN token in a string format.
     */
    string public vXENAddress;

    /**
     * @notice Immutable ratio used for token conversions.
     */
    uint256 public immutable RATIO;

    /// ------------------------------------ INTERFACES ------------------------------------- \\\

    /**
     * @notice Interface to interact with address of the XEN token contract.
     */
    IBurnableToken public immutable XEN;

    /**
     * @notice Interface to interact with LayerZero endpoint for bridging operations.
     */
    ILayerZeroEndpoint public immutable ENDPOINT;

    /**
     * @notice Interface to interact with Axelar gas service for estimating transaction fees.
     */
    IAxelarGasService public immutable GAS_SERVICE;

    /**
     * @notice Interface to interact with Wormhole relayer for bridging operations.
     */
    IWormholeRelayer public immutable WORMHOLE_RELAYER;

    /// ------------------------------------- MAPPING --------------------------------------- \\\

    /**
     * @notice Mapping to prevent replay attacks by storing processed delivery hashes.
     */
    mapping (bytes32 => bool) public seenDeliveryVaaHashes;

    /// ------------------------------------- MODIFIER -------------------------------------- \\\

    /**
     * @notice Modifier to protect against replay attacks.
     * @dev Ensures that a given delivery hash from the Wormhole relayer has not been processed before.
     * If it hasn't, the hash is marked as seen to prevent future replay attacks.
     * @param deliveryHash The delivery hash received from the Wormhole relayer.
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
     * @notice Constructs the vXEN token and initialises its dependencies.
     * @dev Sets up the vXEN token with references to other contracts like Axelar gateway, gas service,
     * LayerZero endpoint, and Wormhole relayer. Also computes the string representation of the vXEN contract address.
     * @param _ratio The ratio between vXEN and XEN used for minting and burning.
     * @param _XEN The address of the XEN token.
     * @param _gateway Address of the Axelar gateway contract.
     * @param _gasService Address of the Axelar gas service contract.
     * @param _endpoint Address of the LayerZero endpoint contract.
     * @param _wormholeRelayer Address of the Wormhole relayer contract.
     */
    constructor(
        uint256 _ratio,
        address _XEN,
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    ) payable ERC20("vXEN", "vXEN") AxelarExecutable(_gateway) {
        XEN = IBurnableToken(_XEN);
        GAS_SERVICE = IAxelarGasService(_gasService);
        ENDPOINT = ILayerZeroEndpoint(_endpoint);
        WORMHOLE_RELAYER = IWormholeRelayer(_wormholeRelayer);
        vXENAddress = address(this).toString();
        RATIO = _ratio;
    }

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice A hook triggered post token burning. It currently has no implementation but can be overridden.
     * @dev Complies with the IBurnRedeemable interface. Extend this function for additional logic after token burning.
     */
    function onTokenBurned(
        address,
        uint256
    ) external override {}

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns a specified quantity of XEN tokens and then mints an equivalent quantity of vXEN tokens to the burner.
     * @dev This function burns XEN tokens and mints vXEN in accordance to the defined RATIO.
     * @param _amount The volume of XEN tokens to burn.
     */
    function burnXEN(uint256 _amount)
        external
        override
    {
        XEN.burn(msg.sender, _amount);
        uint256 amt;
        unchecked {
            amt = _amount / RATIO;
        }
        _mint(msg.sender, amt);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns the specified amount of XEN tokens and bridges them via the LayerZero network.
     * @dev Burns the XEN tokens from the sender's address and then initiates a bridge operation using the LayerZero network.
     * @param _amount The amount of XEN tokens to burn and bridge.
     * @param dstChainId The Chain ID of the destination chain on the LayerZero network.
     * @param to The recipient address on the destination chain.
     * @param feeRefundAddress Address to refund any excess fees.
     * @param zroPaymentAddress Address of the ZRO token holder who would pay for the transaction.
     * @param adapterParams Parameters for custom functionality, e.g., receiving airdropped native gas from the relayer on the destination.
     */
    function burnAndBridgeViaLayerZero(
        uint256 _amount,
        uint16 dstChainId,
        address to,
        address payable feeRefundAddress,
        address zroPaymentAddress,
        bytes calldata adapterParams
    )
        external
        payable
        override
    {
        XEN.burn(msg.sender, _amount);
        uint256 amt;
        unchecked {
            amt = _amount / RATIO;
        }
        _mint(msg.sender, amt);
        bridgeViaLayerZero(dstChainId, msg.sender, to, amt, feeRefundAddress, zroPaymentAddress, adapterParams);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns the specified amount of XEN tokens and bridges them via the Axelar network.
     * @dev Burns the XEN tokens from the sender's address and then initiates a bridge operation using the Axelar network.
     * @param _amount The amount of XEN tokens to burn and bridge.
     * @param dstChainId The target chain where tokens should be bridged to on the Axelar network.
     * @param to The recipient address on the destination chain.
     * @param feeRefundAddress Address to refund any excess fees.
     */
    function burnAndBridgeViaAxelar(
        uint256 _amount,
        string calldata dstChainId,
        address to,
        address payable feeRefundAddress
    )
        external
        payable
        override
    {
        XEN.burn(msg.sender, _amount);
        uint256 amt;
        unchecked {
            amt = _amount / RATIO;
        }
        _mint(msg.sender, amt);
        bridgeViaAxelar(dstChainId, msg.sender, to, amt, feeRefundAddress);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns the specified amount of XEN tokens and bridges them via the Wormhole network.
     * @dev Burns the XEN tokens from the sender's address and then initiates a bridge operation using the Wormhole network.
     * @param _amount The amount of XEN tokens to burn and bridge.
     * @param targetChain The ID of the target chain on the Wormhole network.
     * @param to The recipient address on the destination chain.
     * @param feeRefundAddress Address to refund any excess fees.
     * @param gasLimit The gas limit for the transaction on the destination chain.
     */
    function burnAndBridgeViaWormhole(
        uint256 _amount,
        uint16 targetChain,
        address to,
        address payable feeRefundAddress,
        uint256 gasLimit
    )
        external
        payable
        override
    {
        XEN.burn(msg.sender, _amount);
        uint256 amt;
        unchecked {
            amt = _amount / RATIO;
        }
        _mint(msg.sender, amt);
        bridgeViaWormhole(targetChain, msg.sender, to, amt, feeRefundAddress, gasLimit);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Burns a specific amount of vXEN tokens from a user's address.
     * @dev Allows an external entity to burn tokens from a user's address, provided they have the necessary allowance.
     * @param _user The address from which the vXEN tokens will be burned.
     * @param _amount The amount of vXEN tokens to burn.
     */
    function burn(
        address _user,
        uint256 _amount
    )
        external
        override
    {
        if (_user != msg.sender)
            _spendAllowance(_user, msg.sender, _amount);
        _burn(_user, _amount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Receives vXEN tokens via the LayerZero bridge.
     * @dev Handles the receipt of vXEN tokens that have been bridged from another chain using the LayerZero network.
     * @param _srcChainId The Chain ID of the source chain on the LayerZero network.
     * @param _srcAddress The address on the source chain from which the vXEN tokens were sent.
     * @param _payload The encoded data containing details about the bridging operation, including the recipient address and amount.
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
        if (address(ENDPOINT) != msg.sender) {
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
        emit vXENBridgeReceive(to, _amount, BridgeId.LayerZero, abi.encode(_srcChainId), from);
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
        external
        payable
        override
        replayProtect(deliveryHash)
    {
        if (msg.sender != address(WORMHOLE_RELAYER)) {
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
        emit vXENBridgeReceive(to, _amount, BridgeId.Wormhole, abi.encode(_srcChainId), from);
    }

    /// ---------------------------------- PUBLIC FUNCTIONS --------------------------------- \\\

    /**
     * @notice Checks if a given interface ID is supported by the contract.
     * @dev Implements the IERC165 standard for interface detection.
     * @param interfaceId The ID of the interface in question.
     * @return bool `true` if the interface is supported, otherwise `false`.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IBurnRedeemable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to another chain via LayerZero.
     * @dev Encodes destination and contract addresses, checks Ether sent against estimated gas,
     * then triggers the LayerZero endpoint to bridge tokens.
     * @param _dstChainId ID of the target chain on LayerZero.
     * @param from Sender's address on the source chain.
     * @param to Recipient's address on the destination chain.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address for any excess fee refunds.
     * @param _zroPaymentAddress Address of the ZRO token holder covering transaction fees.
     * @param _adapterParams Additional parameters for custom functionalities.
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
        public
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
        ENDPOINT.send{value: msg.value} (
            _dstChainId,
            abi.encodePacked(address(this),address(this)),
            abi.encode(from, to, _amount),
            feeRefundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
        emit vXENBridgeTransfer(from, _amount, BridgeId.LayerZero, abi.encode(_dstChainId), to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to another chain via Axelar.
     * @dev Encodes sender's address and amount, then triggers the Axelar gateway to bridge tokens.
     * @param destinationChain ID of the target chain on Axelar.
     * @param from Sender's address on the source chain.
     * @param to Recipient's address on the destination chain.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address for any excess fee refunds.
     */
    function bridgeViaAxelar(
        string calldata destinationChain,
        address from,
        address to,
        uint256 _amount,
        address payable feeRefundAddress
    )
        public
        payable
        override
    {
        bytes memory payload = abi.encode(from, to, _amount);
        string memory _vXENAddress = vXENAddress;
        if (msg.value != 0) {
            GAS_SERVICE.payNativeGasForContractCall{value: msg.value} (
                address(this),
                destinationChain,
                _vXENAddress,
                payload,
                feeRefundAddress
            );
        }
        if (from != msg.sender)
            _spendAllowance(from, msg.sender, _amount);
        _burn(from, _amount);
        gateway.callContract(destinationChain, _vXENAddress, payload);
        emit vXENBridgeTransfer(from, _amount, BridgeId.Axelar, abi.encode(destinationChain), to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Bridges tokens to another chain via Wormhole.
     * @dev Estimates gas for the Wormhole bridge, checks Ether sent, then triggers the Wormhole relayer.
     * @param targetChain ID of the target chain on Wormhole.
     * @param from Sender's address on the source chain.
     * @param to Recipient's address on the destination chain.
     * @param _amount Amount of tokens to bridge.
     * @param feeRefundAddress Address for any excess fee refunds.
     * @param _gasLimit Gas limit for the transaction on the destination chain.
     */
    function bridgeViaWormhole(
        uint16 targetChain,
        address from,
        address to,
        uint256 _amount,
        address payable feeRefundAddress,
        uint256 _gasLimit
    )
        public
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
        WORMHOLE_RELAYER.sendPayloadToEvm{value: msg.value} (
            targetChain,
            address(this),
            abi.encode(from, to, _amount),
            0,
            _gasLimit,
            targetChain,
            feeRefundAddress
        );
        emit vXENBridgeTransfer(from, _amount, BridgeId.Wormhole, abi.encode(targetChain), to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Estimates the bridging fee on LayerZero.
     * @dev Uses the `estimateFees` method of the endpoint contract.
     * @param _dstChainId ID of the destination chain on LayerZero.
     * @param from Sender's address on the source chain.
     * @param to Recipient's address on the destination chain.
     * @param _amount Amount of tokens to bridge.
     * @param _payInZRO If false, user pays the fee in native token.
     * @param _adapterParam Parameters for adapter services.
     * @return nativeFee Estimated fee in native tokens.
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
        (nativeFee, ) = ENDPOINT.estimateFees(
            _dstChainId,
            address(this),
            abi.encode(from, to, _amount),
            _payInZRO,
            _adapterParam
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Estimates the bridging fee on Wormhole.
     * @dev Uses the `quoteEVMDeliveryPrice` method of the wormholeRelayer contract.
     * @param targetChain ID of the destination chain on Wormhole.
     * @param _gasLimit Gas limit for the transaction on the destination chain.
     * @return cost Estimated fee for the operation.
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
        (cost, ) = WORMHOLE_RELAYER.quoteEVMDeliveryPrice(
            targetChain,
            0,
            _gasLimit
        );
    }

    /// --------------------------------- INTERNAL FUNCTION --------------------------------- \\\

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
        emit vXENBridgeReceive(to, _amount, BridgeId.Axelar, abi.encode(sourceChain), from);
    }

    /// ------------------------------------------------------------------------------------- \\\
}