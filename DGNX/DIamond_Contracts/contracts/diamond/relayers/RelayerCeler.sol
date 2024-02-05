// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { MessageApp, IMessageBus } from "celer/contracts/message/framework/MessageApp.sol";
import { MsgDataTypes } from "celer/contracts/message/libraries/MsgDataTypes.sol";

import { IFeeDistributorFacet } from "./../interfaces/IFeeDistributorFacet.sol";
import { ICelerFeeHubFacet } from "./../interfaces/ICelerFeeHubFacet.sol";
import { IFeeStoreFacet } from "./../interfaces/IFeeStoreFacet.sol";
import { IRelayerCeler } from "./../interfaces/IRelayerCeler.sol";
import { ZeroValueNotAllowed, NotAllowed, FailToSendNative } from "./../helpers/GenericErrors.sol";
import { CelerRelayerData, FeeConfigSyncHomeDTO } from "./../helpers/Structs.sol";
import { addressZeroCheck } from "./../helpers/Functions.sol";
import { Constants } from "./../helpers/Constants.sol";

/// @title Relayer for CELER IM
/// @author Daniel <danieldegendev@gmail.com>
/// @notice this contract will manage the interaction with the IM service of CELER. It can only be called by the message bus or the diamonds on the desired chains
/// @dev also have a look at https://github.com/celer-network/sgn-v2-contracts/blob/main/contracts/message/framework/MessageApp.sol
/// @custom:version 1.0.0
contract RelayerCeler is IRelayerCeler, MessageApp, Ownable2Step {
    using SafeERC20 for IERC20;
    using Address for address payable;

    /// @dev address of the diamond
    address immutable diamond;

    /// @dev address of the relayer on the home chain
    address immutable relayerHome;

    /// @dev chain id of the home chain
    uint256 immutable chainHome;

    /// @dev flag whether this relayer is based on a target chain or a home chain (true=home chain)
    bool immutable isHomeRelayer;

    /// @notice address of the operator which receives the funds in case every legit execution fails
    address public operator;

    /// @notice nonce for the transfers being created to avoid duplications
    uint64 public nonce = 0;

    /// @dev mapping of valid actors from specified chains
    mapping(uint256 => address) private _actors;

    event RefundForwarded(address asset, address receiver, uint256 amount);
    event MessageReceived(address srcContract, uint64 srcChainId, bytes message, bool status);
    event ActorAdded(uint256 chainId, address actor);
    event ActorRemoved(uint256 chainId);

    error ActorNotExisting();
    error MissingGasFees();

    modifier onlyDiamondHome() {
        if (msg.sender != diamond || !isHomeRelayer) revert NotAllowed();
        _;
    }

    modifier onlyDiamondTarget() {
        if (msg.sender != diamond || isHomeRelayer) revert NotAllowed();
        _;
    }

    modifier paybackOverhead(address _recipient) {
        uint256 _balanceBefore = address(this).balance - msg.value;
        _;
        uint256 _balanceAfter = address(this).balance;
        if (_balanceAfter > _balanceBefore) payable(_recipient).sendValue(_balanceAfter - _balanceBefore);
        else if (_balanceAfter < _balanceBefore) revert MissingGasFees();
    }

    /// Constructor
    /// @param _diamond address of the diamond
    /// @param _relayerHome address of the relayer on the home chain
    /// @param _operator address of the operator
    /// @param _messageBus address of the message bus from celer (if update needed, new deployment necessary)
    /// @param _chainHome chain id of the home chain
    /// @param _isHomeRelayer flag wheter this contract is deployed on the home chain or target chain
    /// @dev it also initializes the owner
    constructor(
        address _diamond,
        address _relayerHome,
        address _operator,
        address _messageBus,
        uint256 _chainHome,
        bool _isHomeRelayer
    ) MessageApp(_messageBus) Ownable() {
        diamond = _diamond;
        relayerHome = _relayerHome;
        operator = _operator;
        chainHome = _chainHome;
        isHomeRelayer = _isHomeRelayer;
    }

    /// @inheritdoc IRelayerCeler
    /// @dev can only be executed by the home chain diamond
    function deployFees(address _receiver, address _target, uint256 _chainId, bytes calldata _message) external payable onlyDiamondHome {
        CelerRelayerData memory _crd = CelerRelayerData({ what: Constants.RELAYER_ACTION_DEPLOY_FEES, target: _target, message: _message });
        bytes memory _crdMessage = abi.encode(_crd);
        uint256 _fee = IMessageBus(messageBus).calcFee(_crdMessage);
        sendMessage(_receiver, uint64(_chainId), _crdMessage, _fee);
    }

    /// @inheritdoc IRelayerCeler
    /// @dev can only be executed by the home chain diamond
    function deployFeesFeeCalc(address _target, bytes calldata _message) external view onlyDiamondHome returns (uint256 _wei) {
        CelerRelayerData memory _crd = CelerRelayerData({ what: Constants.RELAYER_ACTION_DEPLOY_FEES, target: _target, message: _message });
        _wei = IMessageBus(messageBus).calcFee(abi.encode(_crd));
    }

    /// @inheritdoc IRelayerCeler
    /// @dev can only be executred bei the target chain diamond
    function sendFees(address _asset, uint256 _amount, uint32 minMaxSlippage, bytes calldata _message) external payable onlyDiamondTarget {
        CelerRelayerData memory _crd = CelerRelayerData({
            what: Constants.RELAYER_ACTION_SEND_FEES,
            target: address(0),
            message: _message
        });
        bytes memory _crdMessage = abi.encode(_crd);
        uint256 _fee = IMessageBus(messageBus).calcFee(_crdMessage);
        _sendMessageWithTransfer(
            relayerHome,
            _asset,
            _amount,
            uint64(chainHome),
            nonce,
            minMaxSlippage,
            _crdMessage,
            MsgDataTypes.BridgeSendType.PegV2Burn,
            _fee
        );
        nonce++;
    }

    /// @inheritdoc IRelayerCeler
    /// @dev can only be executred bei the target chain diamond
    function sendFeesFeeCalc(bytes calldata _message) external view onlyDiamondTarget returns (uint256 _wei) {
        CelerRelayerData memory _crd = CelerRelayerData({
            what: Constants.RELAYER_ACTION_SEND_FEES,
            target: address(0),
            message: _message
        });
        _wei = IMessageBus(messageBus).calcFee(abi.encode(_crd));
    }

    /// Executes the message on the desired chain
    /// @param _srcContract relayer contract address
    /// @param _srcChainId chain id of the relayer
    /// @param _message encoded CelerRelayerData data
    /// @param _executor trusted account which is configured in the executor
    /// @dev this is only executed by the message bus from CELER IM
    function executeMessage(
        address _srcContract,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable override onlyMessageBus paybackOverhead(_executor) returns (ExecutionStatus) {
        if (!isActor(_srcChainId, _srcContract)) revert NotAllowed();
        CelerRelayerData memory _crd = abi.decode(_message, (CelerRelayerData));

        // deploy fees to fee store
        if (_crd.what == Constants.RELAYER_ACTION_DEPLOY_FEES) {
            (bool _success, ) = address(_crd.target).call(_crd.message);
            emit MessageReceived(_srcContract, _srcChainId, _message, _success);
            if (_success) {
                // send confirmation with mirrored data
                CelerRelayerData memory _crdConfirm = CelerRelayerData({
                    what: Constants.RELAYER_ACTION_DEPLOY_FEES_CONFIRM,
                    target: address(0),
                    message: _crd.message
                });
                bytes memory _crdMessage = abi.encode(_crdConfirm);
                uint256 _fee = IMessageBus(messageBus).calcFee(_crdMessage);
                sendMessage(_srcContract, _srcChainId, _crdMessage, _fee);
                return ExecutionStatus.Success;
            }
        }

        // process confirmation data and execute on celer fee hub facet
        if (_crd.what == Constants.RELAYER_ACTION_DEPLOY_FEES_CONFIRM) {
            ICelerFeeHubFacet(diamond).deployFeesWithCelerConfirm(_srcChainId, _crd.message);
            return ExecutionStatus.Success;
        }

        return ExecutionStatus.Fail;
    }

    /// @notice Called by MessageBus to execute a message with an associated token transfer.
    /// The contract is guaranteed to have received the right amount of tokens before this function is called.
    /// @param _sender The address of the source app contract
    /// @param _token The address of the token that comes out of the bridge
    /// @param _amount The amount of tokens received at this contract through the cross-chain bridge.
    /// @param _srcChainId The source chain ID where the transfer is originated from
    /// @param _message Arbitrary message bytes originated from and encoded by the source app contract
    /// @param _executor trusted account which is configured in the executor
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable override onlyMessageBus paybackOverhead(_executor) returns (ExecutionStatus) {
        if (!isActor(_srcChainId, _sender)) revert NotAllowed();
        CelerRelayerData memory _crd = abi.decode(_message, (CelerRelayerData));

        // send fees to distributor
        if (_crd.what == Constants.RELAYER_ACTION_SEND_FEES) {
            SafeERC20.safeTransfer(IERC20(_token), diamond, _amount);
            FeeConfigSyncHomeDTO memory _dto = abi.decode((_crd.message), (FeeConfigSyncHomeDTO));
            IFeeDistributorFacet(diamond).pushFees{ value: msg.value }(_token, _amount, _dto);
            emit MessageReceived(_sender, _srcChainId, _message, true);
            return ExecutionStatus.Success;
        }

        emit MessageReceived(_sender, _srcChainId, _message, false);
        return ExecutionStatus.Fail;
    }

    /// @notice Only called by MessageBus if
    ///         1. executeMessageWithTransfer reverts, or
    ///         2. executeMessageWithTransfer returns ExecutionStatus.Fail
    /// The contract is guaranteed to have received the right amount of tokens before this function is called.
    /// @param _sender The address of the source app contract
    /// @param _token The address of the token that comes out of the bridge
    /// @param _amount The amount of tokens received at this contract through the cross-chain bridge.
    /// @param _srcChainId The source chain ID where the transfer is originated from
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata,
        address
    ) external payable virtual override onlyMessageBus returns (ExecutionStatus) {
        if (!isActor(_srcChainId, _sender)) revert NotAllowed();
        try IERC20(_token).transfer(operator, _amount) returns (bool _success) {
            if (_success) return ExecutionStatus.Success;
            else return ExecutionStatus.Fail;
        } catch {
            return ExecutionStatus.Fail;
        }
    }

    /// @notice Called by MessageBus to process refund of the original transfer from this contract.
    /// The contract is guaranteed to have received the refund before this function is called.
    /// @param _token The token address of the original transfer
    /// @param _amount The amount of the original transfer
    /// @param _message The same message associated with the original transfer
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address
    ) external payable override onlyMessageBus returns (ExecutionStatus) {
        CelerRelayerData memory _crd = abi.decode(_message, (CelerRelayerData));
        if (_crd.what == Constants.RELAYER_ACTION_SEND_FEES) {
            IERC20(_token).approve(diamond, _amount);
            IFeeStoreFacet(diamond).restoreFeesFromSendFees(abi.decode((_crd.message), (FeeConfigSyncHomeDTO)));
            return ExecutionStatus.Success;
        }
        return ExecutionStatus.Fail;
    }

    /// Payout refund to receiver once token gets stuck
    /// @param _asset address of token that should be moved from the relayer
    /// @param _receiver receiver of token
    /// @param _amount amount of token
    /// @dev only executeable by the owner
    function forwardRefund(address _asset, address payable _receiver, uint256 _amount) external onlyOwner {
        if (_asset == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            payable(_receiver).sendValue(_amount);
        } else {
            SafeERC20.safeTransfer(IERC20(_asset), _receiver, _amount);
        }
        emit RefundForwarded(_asset, _receiver, _amount);
    }

    /// Adds an actor to the relayer
    /// @param _chainId chain id of the actor
    /// @param _actor address of the actor
    /// @dev manage actors that can execute methods of this relayer. Will mostly be relayers from the corresponding chains
    function addActor(uint256 _chainId, address _actor) external onlyOwner {
        if (_chainId == 0) revert ZeroValueNotAllowed();
        addressZeroCheck(_actor);
        _actors[_chainId] = _actor;
        emit ActorAdded(_chainId, _actor);
    }

    /// Removes an actor based on the chain id
    /// @param _chainId chain id of the actor
    function removeActor(uint256 _chainId) external onlyOwner {
        if (_chainId == 0) revert ZeroValueNotAllowed();
        if (_actors[_chainId] == address(0)) revert ActorNotExisting();
        delete _actors[_chainId];
        emit ActorRemoved(_chainId);
    }

    /// Checks whether an actor is existing or not
    /// @param _chainId chain id of actor
    /// @param _actor address of actor
    /// @return _isActor flag if is actor or not
    function isActor(uint256 _chainId, address _actor) public view returns (bool _isActor) {
        _isActor = _chainId != 0 && _actor != address(0) && _actors[_chainId] == _actor;
    }

    /// internals

    /// @notice Sends a message associated with a transfer to a contract on another chain.
    /// @param _receiver The address of the destination app contract.
    /// @param _token The address of the token to be sent.
    /// @param _amount The amount of tokens to be sent.
    /// @param _dstChainId The destination chain ID.
    /// @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
    /// @param _maxSlippage The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
    ///        Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least
    ///        (100% - max slippage percentage) * amount or the transfer can be refunded.
    ///        Only applicable to the {MsgDataTypes.BridgeSendType.Liquidity}.
    /// @param _message Arbitrary message bytes to be decoded by the destination app contract.
    ///        If message is empty, only the token transfer will be sent
    /// @param _bridgeSendType One of the {BridgeSendType} enum.
    /// @param _fee The fee amount to pay to MessageBus.
    /// @return _transferId he transfer ID.
    /// @dev wrapper function to write proper tests without mocking your ass of
    function _sendMessageWithTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        bytes memory _message,
        MsgDataTypes.BridgeSendType _bridgeSendType,
        uint256 _fee
    ) internal virtual returns (bytes32 _transferId) {
        _transferId = super.sendMessageWithTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _message,
            _bridgeSendType,
            _fee
        );
    }

    /// receiver
    receive() external payable {}
}
