// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { LibAccessControlEnumerable } from "./../libraries/LibAccessControlEnumerable.sol";
import { LibFeeManagerStorage } from "./../libraries/LibFeeManagerStorage.sol";
import { LibFeeManager } from "./../libraries/LibFeeManager.sol";
import {
    AddChainParams,
    AddFeeConfigParams,
    AssignFeeConfigToChainParams,
    FeeConfig,
    FeeConfigDeployState,
    FeeSyncQueue,
    RemoveChainParams,
    RemoveFeeConfigParams,
    UnassignFeeConfigFromAllChainsParams,
    UnassignFeeConfigFromChainParams,
    UpdateFeeConfigParams
} from "./../helpers/Structs.sol";
import { addressZeroCheck } from "./../helpers/Functions.sol";
import { FeeSyncAction, FeeDeployState } from "./../helpers/Enums.sol";
import { Constants } from "./../helpers/Constants.sol";

/// @title Fee Manager Facet
/// @author Daniel <danieldegendev@gmail.com>
/// @notice It's responsible for managing fees and its state of deployment. This contract supposed to be deployed only on the home chain, not on the target chain.
/// @custom:version 1.0.0
contract FeeManagerFacet {
    error ChainIdZero();
    error ChainIdExists(uint256 chainId);
    error ChainIdNotExisting(uint256 chainId);
    error ConfigAlreadyAssignedToChain(bytes32 id, uint256 chainId);
    error ConfigNotAssignedToChain(bytes32 id, uint256 chainId);
    error ConfigsAssignedToChain(uint256 chainId);
    error ConfigInUse(bytes32 id);
    error FeeZero();
    error ConfigExists(bytes32 id);
    error ConfigNotExisting(bytes32 id);
    error SyncQueueEmpty();

    event FeeConfigAdded(bytes32 indexed id, AddFeeConfigParams params, address sender);
    event FeeConfigUpdated(bytes32 indexed id, UpdateFeeConfigParams params, address sender);
    event FeeConfigRemoved(bytes32 indexed id, address sender);
    event ChainAdded(uint256 chainId, address target);
    event ChainRemoved(uint256 chainId);
    event ConfigAssignedToChain(bytes32 indexed id, uint256 chainId);
    event ConfigUnassignedFromChain(bytes32 indexed id, uint256 chainId);
    event ConfigUnassignedFromAllChains(bytes32 indexed id);
    event ClearQueue();
    event ManuallyQueued();

    /// Adds a corresponding chain
    /// @param _params consists of the chain id and target addess
    /// @dev the target address is the desired contract address receiving the fee config information
    function addChain(AddChainParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (_params.chainId == 0) revert ChainIdZero();
        addressZeroCheck(_params.target);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        if (_store.isChainSupported[_params.chainId]) revert ChainIdExists(_params.chainId);
        _store.isChainSupported[_params.chainId] = true;
        _store.chainTargets[_params.chainId] = _params.target;
        _store.chainIds.push(_params.chainId);
        emit ChainAdded(_params.chainId, _params.target);
    }

    /// Removes a corresponding chain
    /// @param _params consists only of the chain id
    function removeChain(RemoveChainParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        if (!_store.isChainSupported[_params.chainId]) revert ChainIdNotExisting(_params.chainId);
        if (_store.chainIdFeeConfigMap[_params.chainId].length > 0) revert ConfigsAssignedToChain(_params.chainId);
        delete _store.chainTargets[_params.chainId];
        delete _store.isChainSupported[_params.chainId];
        emit ChainRemoved(_params.chainId);
    }

    /// Adds a fee config
    /// @param _params see {contracts/diamond/helpers/Structs.sol#AddFeeConfigParams}
    /// @dev will fail if a config id is already existing or the fee value is zero
    function addFeeConfig(AddFeeConfigParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (LibFeeManager.exists(_params.id)) revert ConfigExists(_params.id);
        if (_params.fee == 0) revert FeeZero();
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        _store.feeConfigs[_params.id] = FeeConfig({
            fee: _params.fee,
            receiver: _params.receiver,
            ftype: _params.ftype,
            currency: _params.currency
        });
        _store.feeConfigIds.push(_params.id);
        emit FeeConfigAdded(_params.id, _params, msg.sender);
    }

    /// Updates a fee config partially
    /// @param _params see {contracts/diamond/helpers/Structs.sol#UpdateFeeConfigParams}
    /// @dev if you need more data changed than _params in providing, remove and add a fee
    function updateFeeConfig(UpdateFeeConfigParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (!LibFeeManager.exists(_params.id)) revert ConfigNotExisting(_params.id);
        if (_params.fee == 0) revert FeeZero();
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        LibFeeManager.archiveFeeConfig(_params.id);
        _store.feeConfigs[_params.id].fee = _params.fee;
        _store.feeConfigs[_params.id].receiver = _params.receiver;
        for (uint256 i = 0; i < _store.chainIds.length; i++) {
            for (uint256 j = 0; j < _store.chainIdFeeConfigMap[_store.chainIds[i]].length; j++) {
                if (_store.chainIdFeeConfigMap[_store.chainIds[i]][j] == _params.id) {
                    LibFeeManager.queue(_params.id, _store.chainIds[i], FeeSyncAction.Update);
                }
            }
        }
        emit FeeConfigUpdated(_params.id, _params, msg.sender);
    }

    /// Removes a fee config
    /// @param _params params consist of a fee id that should be removed
    function removeFeeConfig(RemoveFeeConfigParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (!LibFeeManager.exists(_params.id)) revert ConfigNotExisting(_params.id);
        if (LibFeeManager.isFeeConfigInUse(_params.id)) revert ConfigInUse(_params.id);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        LibFeeManager.archiveFeeConfig(_params.id);
        for (uint256 i = 0; i < _store.feeConfigIds.length; i++) {
            if (_store.feeConfigIds[i] == _params.id) {
                _store.feeConfigIds[i] = _store.feeConfigIds[_store.feeConfigIds.length - 1];
                break;
            }
        }
        _store.feeConfigIds.pop();
        delete _store.feeConfigs[_params.id];
        emit FeeConfigRemoved(_params.id, msg.sender);
    }

    /// Adds a fee config to chain connection
    /// @param _params see {contracts/diamond/helpers/Structs.sol#AssignFeeConfigToChainParams}
    /// @dev after the assignment, the fee config is added to a queue with an add action
    function assignFeeConfigToChain(AssignFeeConfigToChainParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (!LibFeeManager.exists(_params.id)) revert ConfigNotExisting(_params.id);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        if (!_store.isChainSupported[_params.chainId]) revert ChainIdNotExisting(_params.chainId);
        if (_store.chainIdFeeConfig[_params.chainId][_params.id]) revert ConfigAlreadyAssignedToChain(_params.id, _params.chainId);
        _store.chainIdFeeConfig[_params.chainId][_params.id] = true;
        _store.chainIdFeeConfigMap[_params.chainId].push(_params.id);
        LibFeeManager.queue(_params.id, _params.chainId, FeeSyncAction.Add);
        emit ConfigAssignedToChain(_params.id, _params.chainId);
    }

    /// Removes a fee config to chain connection
    /// @param _params see {contracts/diamond/helpers/Structs.sol#UnassignFeeConfigFromChainParams}
    /// @dev the main task will be done in {_decoupleFeeConfigFromChain}
    function unassignFeeConfigFromChain(UnassignFeeConfigFromChainParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (!LibFeeManager.exists(_params.id)) revert ConfigNotExisting(_params.id);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        if (!_store.isChainSupported[_params.chainId]) revert ChainIdNotExisting(_params.chainId);
        if (!_store.chainIdFeeConfig[_params.chainId][_params.id]) revert ConfigNotAssignedToChain(_params.id, _params.chainId);
        _decoupleFeeConfigFromChain(_params.id, _params.chainId);
        emit ConfigUnassignedFromChain(_params.id, _params.chainId);
    }

    /// Removes all existing fee config to chain connections
    /// @param _params see {contracts/diamond/helpers/Structs.sol#UnassignFeeConfigFromAllChainsParams}
    /// @dev it will iteration through all chains and removes the connections. The main task will be done in {_decoupleFeeConfigFromChain}
    function unassignFeeConfigFromAllChains(UnassignFeeConfigFromAllChainsParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        if (!LibFeeManager.exists(_params.id)) revert ConfigNotExisting(_params.id);
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        for (uint256 i = 0; i < _store.chainIds.length; i++) _decoupleFeeConfigFromChain(_params.id, _store.chainIds[i]);
        emit ConfigUnassignedFromAllChains(_params.id);
    }

    /// Clears the queue and removes all current jobs
    /// @dev the deployment state is set to pending while doing
    function clearQueue() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        LibFeeManagerStorage.FeeManagerStorage storage s = LibFeeManagerStorage.feeManagerStorage();
        uint256[] memory _chainIds = s.chainIds;
        for (uint256 i = 0; i < _chainIds.length; i++) {
            for (uint256 j = 0; j < s.feeSyncQueue[_chainIds[i]].length; j++) {
                delete s.feeDeployState[_chainIds[i]][s.feeSyncQueue[_chainIds[i]][j].id];
            }
            delete s.feeSyncQueue[_chainIds[i]];
        }
        emit ClearQueue();
    }

    /// Queues up fee configs manually
    /// @param _syncQueue list of FeeSyncQueue data
    function queueUpManually(FeeSyncQueue[] calldata _syncQueue) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        LibFeeManagerStorage.FeeManagerStorage storage s = LibFeeManagerStorage.feeManagerStorage();
        for (uint256 i = 0; i < _syncQueue.length; i++) {
            if (!LibFeeManager.exists(_syncQueue[i].id)) revert ConfigNotExisting(_syncQueue[i].id);
            if (!s.isChainSupported[_syncQueue[i].chainId]) revert ChainIdNotExisting(_syncQueue[i].chainId);
            LibFeeManager.queue(_syncQueue[i].id, _syncQueue[i].chainId, _syncQueue[i].action);
        }
        emit ManuallyQueued();
    }

    /// viewables

    /// Gets the fee config ids
    /// @return _feeConfigIds returns an arrayf of fee config ids
    function getFeeConfigIds() external view returns (bytes32[] memory _feeConfigIds) {
        _feeConfigIds = LibFeeManagerStorage.feeManagerStorage().feeConfigIds;
    }

    /// Gets the fee config by fee config id
    /// @param _id fee config id
    /// @return _feeConfig fee config
    function getFeeConfig(bytes32 _id) external view returns (FeeConfig memory _feeConfig) {
        _feeConfig = LibFeeManagerStorage.feeManagerStorage().feeConfigs[_id];
    }

    /// Gets all previous fee config states by fee config id
    /// @param _id fee config id
    /// @return _feeConfig array of fee configs
    function getArchivedFeeConfigs(bytes32 _id) external view returns (FeeConfig[] memory _feeConfig) {
        _feeConfig = LibFeeManagerStorage.feeManagerStorage().feeConfigsArchive[_id];
    }

    /// Gets all fee config ids by chain id
    /// @param _chainId chain id
    /// @return _feeConfigs array of fee config ids
    function getFeeConfigsByChain(uint256 _chainId) external view returns (bytes32[] memory _feeConfigs) {
        _feeConfigs = LibFeeManagerStorage.feeManagerStorage().chainIdFeeConfigMap[_chainId];
    }

    /// Gets the current queue for a chain
    /// @param _chainId chain id
    /// @return _feeSyncQueue returns an array of queue items. See {contracts/diamond/helpers/Structs.sol#FeeSyncQueue}
    function getFeeSyncQueueByChain(uint256 _chainId) external view returns (FeeSyncQueue[] memory _feeSyncQueue) {
        _feeSyncQueue = LibFeeManagerStorage.feeManagerStorage().feeSyncQueue[_chainId];
    }

    /// Gets the current deployment state of a fee config id
    /// @param _chainId chain id
    /// @param _id fee config id
    /// @return _state deployment state of a fee config
    function getFeeConfigDeployState(uint256 _chainId, bytes32 _id) external view returns (FeeDeployState _state) {
        _state = LibFeeManagerStorage.feeManagerStorage().feeDeployState[_chainId][_id];
    }

    /// Gets the current deployment state of all fee config ids from a given chain id
    /// @param _chainId chain id
    /// @return _states all deployment states of config ids for a specific chain
    function getDeployStatesForChain(uint256 _chainId) external view returns (FeeConfigDeployState[] memory _states) {
        LibFeeManagerStorage.FeeManagerStorage storage _s = LibFeeManagerStorage.feeManagerStorage();
        if (_s.chainIdFeeConfigMap[_chainId].length > 0) {
            _states = new FeeConfigDeployState[](_s.chainIdFeeConfigMap[_chainId].length);
            for (uint256 i = 0; i < _s.chainIdFeeConfigMap[_chainId].length; i++) {
                _states[i] = FeeConfigDeployState({
                    id: _s.chainIdFeeConfigMap[_chainId][i],
                    state: _s.feeDeployState[_chainId][_s.chainIdFeeConfigMap[_chainId][i]]
                });
            }
        }
    }

    /// internals

    /// Removes a fee config to chain connection and queues it
    /// @param _id fee config id
    /// @param _chainId chain id
    function _decoupleFeeConfigFromChain(bytes32 _id, uint256 _chainId) internal {
        LibFeeManagerStorage.FeeManagerStorage storage _store = LibFeeManagerStorage.feeManagerStorage();
        if (_store.chainIdFeeConfigMap[_chainId].length > 0) {
            for (uint256 i = 0; i < _store.chainIdFeeConfigMap[_chainId].length; i++) {
                if (_store.chainIdFeeConfigMap[_chainId][i] == _id) {
                    _store.chainIdFeeConfigMap[_chainId][i] = _store.chainIdFeeConfigMap[_chainId][
                        _store.chainIdFeeConfigMap[_chainId].length - 1
                    ];
                    break;
                }
            }
            _store.chainIdFeeConfigMap[_chainId].pop();
            delete _store.chainIdFeeConfig[_chainId][_id];
            LibFeeManager.queue(_id, _chainId, FeeSyncAction.Delete);
        }
    }
}
