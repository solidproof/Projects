// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20 } from "@solidstate/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@solidstate/contracts/utils/SafeERC20.sol";
import { IFeeDistributorFacet } from "./../interfaces/IFeeDistributorFacet.sol";
import { ICelerFeeHubFacet } from "./../interfaces/ICelerFeeHubFacet.sol";
import { IFeeStoreFacet } from "./../interfaces/IFeeStoreFacet.sol";
import { IRelayerCeler } from "./../interfaces/IRelayerCeler.sol";
import { LibAccessControlEnumerable } from "./../libraries/LibAccessControlEnumerable.sol";
import { LibFeeManagerStorage } from "./../libraries/LibFeeManagerStorage.sol";
import { LibFeeManager } from "./../libraries/LibFeeManager.sol";
import { LibFeeStore } from "./../libraries/LibFeeStore.sol";
import { LibDiamond } from "./../libraries/LibDiamond.sol";
import { FeeConfig, FeeConfigSyncDTO, FeeConfigSyncHomeDTO, FeeSyncQueue } from "./../helpers/Structs.sol";
import { AddressZero, AlreadyInitialized, NotAllowed, WrongChain, ZeroValueNotAllowed } from "./../helpers/GenericErrors.sol";
import { addressZeroCheck } from "./../helpers/Functions.sol";
import { FeeDeployState } from "./../helpers/Enums.sol";
import { Constants } from "./../helpers/Constants.sol";

/// @title Celer Fee Hub Facet
/// @author Daniel <danieldegendev@gmail.com>
/// @notice This contract provides the functionality to interact with the celer services through a defined relayer
/// @custom:version 1.0.0
contract CelerFeeHubFacet is ICelerFeeHubFacet {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 constant STORAGE_NAMESPACE = keccak256("degenx.celer-fee-hub.storage.v1");

    address immutable relayer;

    event QueueProcessed();
    event FeesSent();
    event UpdateThreshold(uint256 amount);
    event UpdateSendFeesWei(uint256 amount);
    event UpdateDeployFeesWei(uint256 amount);
    event RefundCollected(address asset, address receiver, uint256 amount);
    event RefundForwarded(address asset, address receiver, uint256 amount);
    event RelayerForChainAdded(address relayer, uint256 chainId);
    event RelayerForChainUpdated(address relayer, uint256 chainId);
    event RelayerForChainRemoved(uint256 chainId);
    event DeploymentSuccessful(uint64 indexed chainId);

    error QueueEmpty();
    error NoChainsConfigured();
    error RefundFailed();
    error ChainExisting(uint256 chainId);
    error ChainNotExisting(uint256 chainId);
    error RelayerExists(address relayer);
    error ThresholdNotMet();
    error InsufficientFundsSent();
    error InsufficientFundsForGas();

    /// @param sendFeesThreshold defines threshold when it is allowed to send fees to home chain
    /// @param sendFeesWei defines the funds in wei that are needed to initiate the process. leftovers are moved back to sender
    /// @param deployFeesWei defines the funds in wei that are needed to initiate the process. leftovers are moved back to sender
    /// @param chainIdToRelayer a map of chain ids and their matching relayer address
    struct Storage {
        uint256 sendFeesThreshold;
        uint256 sendFeesWei;
        uint256 deployFeesWei;
        mapping(uint256 => address) chainIdToRelayer;
    }

    /// Constructor
    /// @param _relayer address of the relayer
    constructor(address _relayer) {
        relayer = _relayer;
    }

    /// Adds a relayer for a specific chain id
    /// @param _relayer address of a relayer
    /// @param _chainId chain id of the relayer
    /// @dev this can only be executed by the FEE_MANAGER_ROLE, which is the DAO and the owner
    function addRelayerForChain(address _relayer, uint256 _chainId) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        addressZeroCheck(_relayer);
        if (_chainId == 0) revert ZeroValueNotAllowed();
        Storage storage s = _store();
        if (s.chainIdToRelayer[_chainId] != address(0)) revert ChainExisting(_chainId);
        s.chainIdToRelayer[_chainId] = _relayer;
        emit RelayerForChainAdded(_relayer, _chainId);
    }

    /// Updates a relayer for a specific chain id
    /// @param _relayer address of a relayer
    /// @param _chainId chain id of the relayer
    /// @dev this can only be executed by the FEE_MANAGER_ROLE, which is the DAO and the owner
    function updateRelayerOnChain(address _relayer, uint256 _chainId) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        addressZeroCheck(_relayer);
        if (_chainId == 0) revert ZeroValueNotAllowed();
        Storage storage s = _store();
        if (s.chainIdToRelayer[_chainId] == address(0)) revert ChainNotExisting(_chainId);
        if (s.chainIdToRelayer[_chainId] == _relayer) revert RelayerExists(_relayer);
        s.chainIdToRelayer[_chainId] = _relayer;
        emit RelayerForChainUpdated(_relayer, _chainId);
    }

    /// Removes a relayer for a specific chain id
    /// @param _chainId chain id of the relayer
    /// @dev this can only be executed by the FEE_MANAGER_ROLE, which is the DAO and the owner
    function removeRelayerOnChain(uint256 _chainId) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        Storage storage s = _store();
        if (s.chainIdToRelayer[_chainId] == address(0)) revert ChainNotExisting(_chainId);
        delete s.chainIdToRelayer[_chainId];
        emit RelayerForChainRemoved(_chainId);
    }

    /// Sets the threshold a total fee can be sent to the home chain
    /// @param _amount threshold amount
    function updateSendFeesThreshold(uint256 _amount) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        Storage storage s = _store();
        s.sendFeesThreshold = _amount;
        emit UpdateThreshold(_amount);
    }

    /// Sets the amount of fees that is being used to initiate the send fees process
    /// @param _wei amount of fees
    function updateSendFeesWei(uint256 _wei) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        Storage storage s = _store();
        s.sendFeesWei = _wei;
        emit UpdateSendFeesWei(_wei);
    }

    /// Sets the amount of fees that is being used to initiate the deploy fees process
    /// @param _wei amount of fees
    function updateDeployFeesWei(uint256 _wei) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        Storage storage s = _store();
        s.deployFeesWei = _wei;
        emit UpdateDeployFeesWei(_wei);
    }

    /// @notice This method deploys added, updated or removed fee configuration to desired chains through CELER IM. It is executable by everyone (DeFi things obv)
    /// @dev Once the queue of the fee manager is filled with configs, it'll be processable. It creates an array of dtos which are being processed by the target chain and its relayer.
    function deployFeesWithCeler() external payable {
        LibFeeManagerStorage.FeeManagerStorage storage _managerStore = LibFeeManagerStorage.feeManagerStorage();
        Storage storage s = _store();

        uint256 _providedWei = msg.value;
        if (_providedWei == 0 || s.deployFeesWei > _providedWei) revert InsufficientFundsSent();

        uint256[] memory _chainIds = _managerStore.chainIds;
        if (_chainIds.length == 0) revert NoChainsConfigured();

        bool _sync = false;
        mapping(uint256 => FeeSyncQueue[]) storage _queue = _managerStore.feeSyncQueue;
        for (uint256 i = 0; i < _chainIds.length; i++) {
            if (_queue[_chainIds[i]].length == 0) continue;
            if (!_sync) _sync = true;
            uint256 chainId = _chainIds[i];
            addressZeroCheck(s.chainIdToRelayer[chainId]);
            FeeConfigSyncDTO[] memory _dto = new FeeConfigSyncDTO[](_queue[chainId].length);
            for (uint256 j = 0; j < _queue[chainId].length; j++) {
                bytes32 feeId = _queue[chainId][j].id;
                FeeConfig storage _config = _managerStore.feeConfigs[feeId];
                _dto[j] = FeeConfigSyncDTO({
                    id: feeId,
                    fee: _config.fee,
                    action: _queue[chainId][j].action,
                    target: _managerStore.chainTargets[chainId]
                });
                _managerStore.feeDeployState[chainId][feeId] = FeeDeployState.Pending;
            }

            address _target = LibFeeManager.getChainTarget(chainId);
            bytes memory _message = abi.encodeWithSelector(IFeeStoreFacet.syncFees.selector, _dto);

            uint256 _fee = IRelayerCeler(relayer).deployFeesFeeCalc(_target, _message);
            if (_fee > _providedWei) revert InsufficientFundsForGas();
            _providedWei -= _fee;

            IRelayerCeler(relayer).deployFees{ value: _fee }(s.chainIdToRelayer[chainId], _target, chainId, _message);
            delete _managerStore.feeSyncQueue[_chainIds[i]];
        }
        if (_sync) {
            if (_providedWei > 0) payable(msg.sender).sendValue(_providedWei);
            emit QueueProcessed();
        } else revert QueueEmpty();
    }

    /// @inheritdoc ICelerFeeHubFacet
    function deployFeesWithCelerConfirm(uint64 _chainId, bytes calldata _message) external {
        if (relayer != msg.sender) revert NotAllowed();
        LibFeeManagerStorage.FeeManagerStorage storage _managerStore = LibFeeManagerStorage.feeManagerStorage();
        FeeConfigSyncDTO[] memory _dto = abi.decode(_message[4:], (FeeConfigSyncDTO[]));
        for (uint256 i = 0; i < _dto.length; i++) {
            _managerStore.feeDeployState[_chainId][_dto[i].id] = FeeDeployState.Deployed;
        }
    }

    /// Sends fees stored on the FeeStore back to the home chain, respecting a bounty receiver
    /// @param minMaxSlippage external defined minimal max slippage by the estimation api of CELER
    /// @param _bountyReceiver address of the bounty receiver on the home chain
    /// @dev The bounty receiver is set because you can't relay on the initiator in the consuming
    ///      contract on the home chain, because contracts can execute this method without having
    ///      the same address on the home chain. It also transfers the tokens to the relayer which
    ///      then bridges the tokens and sends the message to the CELER IM service
    /// @notice Can be executed by everyone. Its success is dependend on the sendFeesThreshold being met
    function sendFeesWithCeler(uint32 minMaxSlippage, address _bountyReceiver) external payable {
        Storage storage s = _store();
        FeeConfigSyncHomeDTO memory _dto = LibFeeStore.prepareToSendFees(); // implicit zero fee check here
        if (_dto.totalFees < s.sendFeesThreshold) revert ThresholdNotMet();

        uint256 _providedWei = msg.value;
        if (_providedWei == 0 || s.sendFeesWei > _providedWei) revert InsufficientFundsSent();

        if (_bountyReceiver == address(0) || _bountyReceiver == address(0xdead)) revert AddressZero();

        _dto.bountyReceiver = _bountyReceiver;
        IERC20(LibFeeStore.getIntermediateAsset()).safeTransfer(relayer, _dto.totalFees);

        bytes memory _message = abi.encode(_dto);
        uint256 _fee = IRelayerCeler(relayer).sendFeesFeeCalc(_message);

        if (_fee > _providedWei) revert InsufficientFundsForGas();
        _providedWei -= _fee;

        IRelayerCeler(relayer).sendFees{ value: _fee }(LibFeeStore.getIntermediateAsset(), _dto.totalFees, minMaxSlippage, _message);

        if (_providedWei > 0) payable(msg.sender).sendValue(_providedWei);
        emit FeesSent();
    }

    /// viewables

    function celerFeeHubSendFeesWei() external view returns (uint256 _wei) {
        Storage storage s = _store();
        _wei = s.sendFeesWei;
    }

    function celerFeeHubDeployFeesWei() external view returns (uint256 _wei) {
        Storage storage s = _store();
        _wei = s.deployFeesWei;
    }

    /// internals

    /// Store
    function _store() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_NAMESPACE;
        assembly {
            s.slot := position
        }
    }
}
