// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IFeeStoreFacet } from "./../interfaces/IFeeStoreFacet.sol";
import { LibAccessControlEnumerable } from "./../libraries/LibAccessControlEnumerable.sol";
import { LibFeeStoreStorage } from "./../libraries/LibFeeStoreStorage.sol";
import { LibFeeStore } from "./../libraries/LibFeeStore.sol";
import { FeeConfig, FeeConfigSyncDTO, FeeConfigSyncHomeDTO, FeeStoreConfig, FeeConfigSyncHomeFees } from "./../helpers/Structs.sol";
import { AlreadyInitialized } from "./../helpers/GenericErrors.sol";
import { addressZeroCheck } from "./../helpers/Functions.sol";
import { FeeSyncAction } from "./../helpers/Enums.sol";
import { Constants } from "./../helpers/Constants.sol";

/// @title Fee Store Facet
/// @author Daniel <danieldegendev@gmail.com>
/// @notice every contract needs to take care of the fees they collect. ITS JUST STORAGE HERE
/// @custom:version 1.0.0
contract FeeStoreFacet is IFeeStoreFacet {
    bytes32 constant STORAGE_NAMESPACE = keccak256("degenx.fee-store-internal.storage.v1");

    event FeeConfigAdded(bytes32 indexed id);
    event FeeConfigUpdated(bytes32 indexed id);
    event FeeConfigDeleted(bytes32 indexed id);
    event FeeConfigMarkedAsDeleted(bytes32 indexed id);
    event FeesPrepared(uint256 amount, FeeConfigSyncHomeDTO candidate);
    event FeesSynced(FeeConfigSyncDTO[] candidates);
    event FeesRestored(FeeConfigSyncHomeDTO candidate);
    event FeesCollected(FeeConfigSyncHomeDTO candidate);
    event UpdatedOperator(address operator);
    event UpdatedIntermediateAsset(address intermediateAsset);
    event FeeAmountDeposited(address indexed _asset, bytes32 indexed _feeConfigId, uint256 _amount);
    event Initialized();

    error InvalidFee(bytes32 id);
    error DataMissing();
    error TransferFailed();

    struct Storage {
        // initialized flag
        bool initialized;
    }

    /// Initializes the facet
    /// @param _operator address of account that is receiving fees if this contracts automations are failing
    function initFeeStoreFacet(address _operator, address _intermediateAsset) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        Storage storage si = _storeInternal();
        if (si.initialized) revert AlreadyInitialized();
        s.operator = _operator;
        s.intermediateAsset = _intermediateAsset;
        si.initialized = true;
        emit Initialized();
    }

    /// @inheritdoc IFeeStoreFacet
    /// @dev it will check wheter an array is sufficient and add, updates or removes fee configs based on the fee sync action create by the fee manager
    function syncFees(FeeConfigSyncDTO[] calldata _feeConfigSyncDTO) external payable {
        LibAccessControlEnumerable.checkRole(Constants.FEE_STORE_MANAGER_ROLE);
        if (_feeConfigSyncDTO.length == 0) revert DataMissing();
        for (uint256 i = 0; i < _feeConfigSyncDTO.length; ) {
            FeeConfigSyncDTO memory _dto = _feeConfigSyncDTO[i];
            if (_dto.id == bytes32(0)) revert InvalidFee(_dto.id);
            if (_dto.fee == 0) revert InvalidFee(_dto.id);
            if (_dto.action == FeeSyncAction.Add) {
                _addFee(_dto.id, _dto.fee, _dto.target);
            }
            if (_dto.action == FeeSyncAction.Update) {
                _updateFee(_dto.id, _dto.fee, _dto.target);
            }
            if (_dto.action == FeeSyncAction.Delete) {
                _deleteFee(_dto.id);
            }
            unchecked {
                i++;
            }
        }
        emit FeesSynced(_feeConfigSyncDTO);
    }

    /// @dev this function restores the fees based on refunds from bridge providers, in case someone starts try to sync fees home and it's failing on the bridge side
    /// @dev if the fee config is not configured anymore, the funds that are getting restored, will be send to the operator
    /// @inheritdoc IFeeStoreFacet
    function restoreFeesFromSendFees(FeeConfigSyncHomeDTO memory _dto) external payable {
        LibAccessControlEnumerable.checkRole(Constants.FEE_STORE_MANAGER_ROLE);
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        try IERC20(s.intermediateAsset).transferFrom(msg.sender, address(this), _dto.totalFees) returns (bool _success) {
            if (_success) {
                for (uint256 i = 0; i < _dto.fees.length; ) {
                    if (s.feeConfigs[_dto.fees[i].id].id == bytes32("")) {
                        IERC20(s.intermediateAsset).transfer(s.operator, _dto.fees[i].amount);
                    } else {
                        s.collectedFeesTotal += _dto.fees[i].amount;
                        s.collectedFees[_dto.fees[i].id] += _dto.fees[i].amount;
                    }
                    unchecked {
                        i++;
                    }
                }
                emit FeesRestored(_dto);
            } else revert TransferFailed();
        } catch Error(string memory reason) {
            revert(reason);
        }
    }

    /// @notice Sends the current collected fees to the Manager in case no bridge provider is working and the job needs to be done manually
    function collectFeesFromFeeStore() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_STORE_MANAGER_ROLE);
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        addressZeroCheck(s.operator);
        FeeConfigSyncHomeDTO memory _dto = LibFeeStore.prepareToSendFees();
        // slither-disable-next-line unchecked-transfer
        IERC20(s.intermediateAsset).transfer(s.operator, _dto.totalFees);
        emit FeesCollected(_dto);
    }

    /// Sets a new operator
    /// @param _operator address of the operator
    /// @dev _operator can't be a zero address
    function setOperator(address _operator) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        addressZeroCheck(_operator);
        LibFeeStore.setOperator(_operator);
        emit UpdatedOperator(_operator);
    }

    /// Sets the intermediate asset
    /// @param _intermediateAsset address of the asset
    /// @dev _intermediateAsset can't be a zero address
    function setIntermediateAsset(address _intermediateAsset) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        addressZeroCheck(_intermediateAsset);
        LibFeeStore.setIntermediateAsset(_intermediateAsset);
        emit UpdatedIntermediateAsset(_intermediateAsset);
    }

    /// Deposit a fee manually
    /// @param _feeConfigId fee config id
    /// @param _amount amount to deposit
    /// @dev can only be executed from the fee store manager role
    function feeStoreDepositFeeAmount(bytes32 _feeConfigId, uint256 _amount) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_STORE_MANAGER_ROLE);
        address _asset = LibFeeStore.getIntermediateAsset();
        IERC20(_asset).transferFrom(msg.sender, address(this), _amount);
        LibFeeStore.putFees(_feeConfigId, _amount);
        emit FeeAmountDeposited(_asset, _feeConfigId, _amount);
    }

    /// viewables

    /// Gets a fee store config based on the fee id
    /// @param _id fee config id
    /// @return _feeStoreConfig FeeStoreConfig, see {contracts/diamond/helpers/Structs.sol#FeeStoreConfig}
    function getFeeStoreConfig(bytes32 _id) external view returns (FeeStoreConfig memory _feeStoreConfig) {
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        _feeStoreConfig = s.feeConfigs[_id];
    }

    /// Gets the current collected total fees on this store
    /// @return _collectedFeesTotal amount of total fees collected
    /// @dev this is a cumulative number of all fees collected on this store until it get's send to the home chain
    function getCollectedFeesTotal() external view returns (uint256 _collectedFeesTotal) {
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        _collectedFeesTotal = s.collectedFeesTotal;
    }

    /// Gets the collected fees for a specific fee id
    /// @param _id fee config id
    /// @return _collectedFees amount of fees collected
    function getCollectedFeesByConfigId(bytes32 _id) external view returns (uint256 _collectedFees) {
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        _collectedFees = s.collectedFees[_id];
    }

    /// Gets all fee config ids defined on this fee store
    /// @return _feeConfigIds array of fee ids
    function getFeeConfigIds() external view returns (bytes32[] memory _feeConfigIds) {
        LibFeeStoreStorage.FeeStoreStorage storage s = _store();
        _feeConfigIds = s.feeConfigIds;
    }

    /// Gets the current operator
    /// @return _operator address of the operator
    function getOperator() external view returns (address _operator) {
        _operator = LibFeeStore.getOperator();
    }

    /// Gets the current intermediate asset
    /// @return _intermediateAsset address of the intermadiate asset
    function getIntermediateAsset() external view returns (address _intermediateAsset) {
        _intermediateAsset = LibFeeStore.getIntermediateAsset();
    }

    /// internals

    /// Wrapper function to add a fee to the store
    /// @param _id fee id
    /// @param _fee fee value
    /// @param _target the target address
    function _addFee(bytes32 _id, uint256 _fee, address _target) internal {
        LibFeeStore.addFee(_id, _fee, _target);
    }

    /// Wrapper function to update a fee in the store
    /// @param _id fee id
    /// @param _fee fee value
    /// @param _target the target address
    function _updateFee(bytes32 _id, uint256 _fee, address _target) internal {
        LibFeeStore.updateFee(_id, _fee, _target);
    }

    /// Removes a fee from the store
    /// @param _id fee id
    function _deleteFee(bytes32 _id) internal {
        LibFeeStore.deleteFee(_id);
    }

    /// Store
    function _store() internal pure returns (LibFeeStoreStorage.FeeStoreStorage storage s) {
        s = LibFeeStoreStorage.feeStoreStorage();
    }

    /// InternalStore
    function _storeInternal() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_NAMESPACE;
        assembly {
            s.slot := position
        }
    }
}
