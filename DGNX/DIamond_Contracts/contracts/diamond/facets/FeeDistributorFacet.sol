// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IFeeDistributorFacet } from "./../interfaces/IFeeDistributorFacet.sol";
import { IDepositable } from "./../interfaces/IDepositable.sol";
import { IRouter02 } from "./../interfaces/IRouter02.sol";
import { IWAVAX } from "./../interfaces/IWAVAX.sol";
import { LibAccessControlEnumerable } from "./../libraries/LibAccessControlEnumerable.sol";
import { LibFeeManagerStorage } from "./../libraries/LibFeeManagerStorage.sol";
import { LibFeeManager } from "./../libraries/LibFeeManager.sol";
import { FeeConfig, FeeConfigSyncHomeDTO, FeeConfigSyncHomeFees, AddReceiverParams } from "./../helpers/Structs.sol";
import { AlreadyInitialized, ZeroValueNotAllowed } from "./../helpers/GenericErrors.sol";
import { Constants } from "./../helpers/Constants.sol";

/// @title Fee Distributor Facet
/// @author Daniel <danieldegendev@gmail.com>
/// @notice It is responsible for distributing received fees to its configured receivers
/// @custom:version 1.0.0
contract FeeDistributorFacet is IFeeDistributorFacet {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    bytes32 constant STORAGE_NAMESPACE = keccak256("degenx.fee-distributor.storage.v1");

    event ReceiverAdded(address account, uint64 points);
    event ReceiverRemoved(address account);
    event DistributionStarted();
    event DistributionStopped();
    event TriggerDistributionWhileNotRunning();
    event Distributed(address account, uint256 amount);
    event UpdatedDistributionShares(address[] receivers, uint64[] shares);
    event BountyEnabled();
    event BountyDisabled();
    event BountyShareUpdated(uint64 share);
    event PushFeesGasCompensationForCallerUpdate(uint256 amountInWei);
    event BountyPaid(uint256 amount, address receiver);
    event BountyPaidFailed(uint256 amount, address receiver);
    event EnableBountyInToken();
    event DisableBountyInToken();

    error ReceiverNotExisting(address receiver);
    error WrongData();
    error WrongToken();
    error MissingData();
    error FailedStartMissingShares();
    error InvalidSwapPath();

    /// @param name the name of the fee share for the UI
    /// @param points the fee share points
    /// @param receiver the receiver of the fee share
    /// @param swap a dedicated swapping path for the fee share
    struct Share {
        string name;
        uint64 points;
        address receiver;
        address[] swap;
    }

    /// @param shares stores the shares in an array
    /// @param queue stores a queue of fees that can be send home
    /// @param shareIndex store the share index of the shares array
    /// @param totalPoints cumulative share points
    /// @param baseToken the expected token from the bridge
    /// @param router uniswap v2 based router
    /// @param bountyShare share of the bounty
    /// @param bountyReceiver bounty receiver for processing purposes
    /// @param lastBountyReceiver last recent bounty receiver
    /// @param lastBountyAmount last recent bounty amount that receiver got
    /// @param totalBounties total amount of bounties paid out
    /// @param running running state of the fee distributor
    /// @param bountyActive is a bounty active or not
    /// @param initialized initialize state of the facet
    struct Storage {
        Share[] shares;
        FeeConfigSyncHomeDTO[] queue;
        mapping(address => uint256) shareIndex;
        uint64 totalPoints;
        address baseToken;
        address nativeWrapper;
        address router;
        uint256 pushFeesGasCompensationForCaller;
        // bounties
        uint64 bountyShare;
        address bountyReceiver;
        address lastBountyReceiver;
        uint256 lastBountyAmount;
        uint256 totalBounties;
        // flags
        bool running;
        bool bountyActive;
        bool bountyInToken;
        bool initialized;
    }

    /// Initializes the facet
    /// @param _baseToken address of the expected token we get from the bridge
    /// @param _nativeWrapper address of native wrapper token on the operating chain
    /// @param _router uniswap v2 based router
    /// @param _bountyShare share of bounty  (10000 = 1%, 1000 = 0.1%)
    /// @dev only available to DEPLOYER_ROLE
    function initFeeDistributorFacet(address _baseToken, address _nativeWrapper, address _router, uint64 _bountyShare) external {
        LibAccessControlEnumerable.checkRole(Constants.DEPLOYER_ROLE);
        Storage storage s = _store();
        if (s.initialized) revert AlreadyInitialized();
        s.bountyShare = _bountyShare;
        s.baseToken = _baseToken;
        s.nativeWrapper = _nativeWrapper;
        s.router = _router;
        s.bountyInToken = false;
        s.initialized = true;
    }

    /// @inheritdoc IFeeDistributorFacet
    function pushFees(address _token, uint256 _amount, FeeConfigSyncHomeDTO calldata _dto) external payable {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_PUSH_ROLE);
        Storage storage s = _store();

        if (s.baseToken != _token) revert WrongToken();
        if (_amount == 0) revert ZeroValueNotAllowed();

        // before native swap
        if (s.bountyInToken) _amount = _payoutBountyInToken(_token, _amount, _dto.bountyReceiver);

        // swap basetoken to native
        address[] memory _path = new address[](2);
        _path[0] = s.baseToken;
        _path[1] = s.nativeWrapper;
        IERC20(s.baseToken).approve(s.router, _amount);
        uint256[] memory _amounts = IRouter02(s.router).swapExactTokensForAVAX(
            _amount,
            (_amount * 997) / 1000,
            _path,
            address(this),
            block.timestamp
        );
        _amount = _amounts[_amounts.length - 1];

        // pay gas compensation to EOA
        if (s.pushFeesGasCompensationForCaller > 0 && _amount > s.pushFeesGasCompensationForCaller && !msg.sender.isContract()) {
            payable(msg.sender).sendValue(s.pushFeesGasCompensationForCaller);
            _amount -= s.pushFeesGasCompensationForCaller;
        }

        // after native swap
        if (!s.bountyInToken) _amount = _payoutBountyInNative(_amount, _dto.bountyReceiver);

        // generate new dto and redraw shares based on _amount and original send amount (_dto.totalFees) because we substract some stuff and bridged funds will differ from initial funds anyway
        // slither-disable-next-line uninitialized-local-variables
        FeeConfigSyncHomeDTO memory _updatedDto = FeeConfigSyncHomeDTO({
            totalFees: _amount,
            bountyReceiver: _dto.bountyReceiver,
            fees: new FeeConfigSyncHomeFees[](_dto.fees.length)
        });
        for (uint256 i = 0; i < _dto.fees.length; ) {
            uint256 _feeAmount = (_amount * _dto.fees[i].amount) / _dto.totalFees;
            _updatedDto.fees[i] = FeeConfigSyncHomeFees({ id: _dto.fees[i].id, amount: _feeAmount });
            unchecked {
                i++;
            }
        }

        _pushFees(_updatedDto);
    }

    /// Adds a fee receiver
    /// @param _params contains the name, points, account address und swapPath for the receiver
    /// @dev swapPath[] needs to have the base token address on position 0
    /// @dev This method also checks if there is a valid swap path existing, otherwise it will be reverted by the aggregator
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function addFeeDistributionReceiver(AddReceiverParams calldata _params) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        // check if it is a valid pair
        if (_params.swapPath.length > 1) IRouter02(s.router).getAmountsOut(10 ** 6, _params.swapPath);
        s.shareIndex[_params.account] = s.shares.length;
        s.shares.push(Share({ name: _params.name, points: _params.points, receiver: _params.account, swap: _params.swapPath }));
        s.totalPoints += _params.points;
        emit ReceiverAdded(_params.account, _params.points);
    }

    /// Removes a receiver based on the receiver address
    /// @param _account address of the receiver
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function removeFeeDistributionReceiver(address _account) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        if (s.shares.length == 0) {
            revert ReceiverNotExisting(_account);
        } else if (s.shares.length == 1) {
            delete s.shares;
            delete s.shareIndex[_account];
            s.totalPoints = 0;
            s.running = false; // stop when there is no share available anymore
        } else {
            for (uint256 i = 0; i < s.shares.length; ) {
                if (s.shares[i].receiver == _account) {
                    delete s.shareIndex[_account];
                    s.shareIndex[s.shares[s.shares.length - 1].receiver] = i;
                    s.totalPoints -= s.shares[i].points;
                    s.shares[i] = s.shares[s.shares.length - 1];
                }
                unchecked {
                    i++;
                }
            }
            s.shares.pop();
        }
        emit ReceiverRemoved(_account);
    }

    /// Updates the shares of existing receivers
    /// @param _receivers array of existing receivers
    /// @param _shares array of new shares to be set
    /// @dev if a receiver is not existing, it'll be reverted
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function updateFeeDistributionShares(address[] calldata _receivers, uint64[] calldata _shares) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        if (_receivers.length == 0 || _shares.length == 0 || _receivers.length != _shares.length) revert WrongData();
        Storage storage s = _store();
        if (s.shares.length == 0) revert MissingData();
        for (uint256 i = 0; i < _receivers.length; ) {
            if (s.shares[s.shareIndex[_receivers[i]]].receiver != _receivers[i]) revert ReceiverNotExisting(_receivers[i]);
            s.totalPoints -= s.shares[s.shareIndex[_receivers[i]]].points;
            s.shares[s.shareIndex[_receivers[i]]].points = _shares[i];
            s.totalPoints += _shares[i];
            unchecked {
                i++;
            }
        }
        emit UpdatedDistributionShares(_receivers, _shares);
    }

    /// Starts the fee distribution
    /// @dev It will be also check if the bounties are being activated and if there are already fees in the queue to process. If so, it'll be process on activating the fee distribution.
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function startFeeDistribution() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();

        if (s.shares.length == 0) revert FailedStartMissingShares();

        _setRunning(true);

        bool _initialState = s.bountyActive;
        if (_initialState) s.bountyActive = false;
        if (s.queue.length > 0) {
            for (uint256 i = 0; i < s.queue.length; ) {
                _pushFees(s.queue[i]);
                unchecked {
                    i++;
                }
            }
            delete s.queue;
        }

        if (_initialState) s.bountyActive = true;

        emit DistributionStarted();
    }

    /// Stops the fee distribution
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function stopFeeDistribution() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        _setRunning(false);
        emit DistributionStopped();
    }

    /// @dev Enables the bounty possibility
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function enableFeeDistributorBounty() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        s.bountyActive = true;
        emit BountyEnabled();
    }

    /// @dev Disables the bounty possibility
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function disableFeeDistributorBounty() external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        s.bountyActive = false;
        emit BountyDisabled();
    }

    /// Sets the share of the bounty
    /// @param _share share of the bounty
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function setFeeDistributorBountyShare(uint64 _share) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        s.bountyShare = _share;
        emit BountyShareUpdated(_share);
    }

    /// Sets the gas compensation for the caller of the push fee method
    /// @param _amountInWei share of the bounty
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function setPushFeesGasCompensationForCaller(uint256 _amountInWei) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        s.pushFeesGasCompensationForCaller = _amountInWei;
        emit PushFeesGasCompensationForCallerUpdate(_amountInWei);
    }

    /// Enables  or disables the bountyInToken flag based on the given parameter
    /// @param _bountyInToken flag if enabled or not
    /// @dev only available to FEE_DISTRIBUTIOR_MANAGER role
    function enableBountyInToken(bool _bountyInToken) external {
        LibAccessControlEnumerable.checkRole(Constants.FEE_DISTRIBUTOR_MANAGER);
        Storage storage s = _store();
        s.bountyInToken = _bountyInToken;
        if (_bountyInToken) emit EnableBountyInToken();
        else emit DisableBountyInToken();
    }

    /// viewables

    /// @dev check whether the bounty is active of not
    /// @return _is if true, it's on
    function isFeeDistributorBountyActive() external view returns (bool _is) {
        Storage storage s = _store();
        _is = s.bountyActive;
    }

    /// @dev check whether the distributor is running of not
    /// @return _is if true, it's on
    function isFeeDistributorRunning() external view returns (bool _is) {
        Storage storage s = _store();
        _is = s.running;
    }

    /// @dev check whether the distributors bounty is paid in the token or not
    /// @return _is if true, it's paid in token
    function isFeeDistributorBountyInToken() external view returns (bool _is) {
        Storage storage s = _store();
        _is = s.bountyInToken;
    }

    /// @dev Gets the current total points of all shares
    /// @return _totalPoints points
    function getFeeDistributorTotalPoints() external view returns (uint64 _totalPoints) {
        Storage storage s = _store();
        _totalPoints = s.totalPoints;
    }

    /// @dev Gets all items in queue
    /// @return _queue array of sync items
    function getFeeDistributorQueue() external view returns (FeeConfigSyncHomeDTO[] memory _queue) {
        Storage storage s = _store();
        _queue = s.queue;
    }

    /// @dev Gets all shares
    /// @return _shares array of configured shares
    function getFeeDistributorReceivers() external view returns (Share[] memory _shares) {
        Storage storage s = _store();
        _shares = s.shares;
    }

    /// @dev Gets last bounty information
    /// @return _receiver address of recent receiver
    /// @return _payout amount being paid to recent receiver
    function getFeeDistributorLastBounty() external view returns (address _receiver, uint256 _payout) {
        Storage storage s = _store();
        _receiver = s.lastBountyReceiver;
        _payout = s.lastBountyAmount;
    }

    /// @dev Gets the bounty share
    /// @return _share current bounty share
    function getFeeDistributorBountyShare() external view returns (uint64 _share) {
        Storage storage s = _store();
        _share = s.bountyShare;
    }

    /// @dev Gets the total bounties being paid
    /// @return _totalBounties total bounties
    function getFeeDistributorTotalBounties() external view returns (uint256 _totalBounties) {
        Storage storage s = _store();
        _totalBounties = s.totalBounties;
    }

    /// internals

    /// Distributes the fees to the desired receivers based on their share
    /// @param _dto a dto that needs to be synced
    /// @dev If the distribution is running, it'll distribute it directly, otherwise it will be queued up and distributed once the distirbution is enabled
    function _pushFees(FeeConfigSyncHomeDTO memory _dto) internal {
        Storage storage s = _store();
        if (_dto.fees.length == 0) revert MissingData();
        // more efficient way to check this before and not in loop
        if (s.running) {
            for (uint256 i = 0; i < _dto.fees.length; ) {
                _distribute(LibFeeManager.getFeeConfigById(_dto.fees[i].id).receiver, _dto.fees[i].amount);
                unchecked {
                    i++;
                }
            }
        } else {
            FeeConfigSyncHomeDTO storage _q = s.queue.push();
            _q.totalFees = _dto.totalFees;
            _q.bountyReceiver = _dto.bountyReceiver;
            for (uint256 i = 0; i < _dto.fees.length; ) {
                _q.fees.push(FeeConfigSyncHomeFees({ id: _dto.fees[i].id, amount: _dto.fees[i].amount }));
                unchecked {
                    i++;
                }
            }
            emit TriggerDistributionWhileNotRunning();
        }
    }

    /// Distributes the fees to the desired addresses
    /// @param _receiver address of the receiver, can be address(0)
    /// @param _amount amount of tokens being distributed
    /// @dev If the receiver is address(0), the funds will be distributed to all defined shares based on their points and desired swap
    /// @dev If the receiver is not address(0), the funds will be directly send to the address
    function _distribute(address _receiver, uint256 _amount) internal {
        Storage storage s = _store();
        if (_receiver == address(0) && s.totalPoints > 0) {
            uint256 _rest = _amount;
            for (uint256 i = 0; i < s.shares.length; i++) {
                bool _useRest = s.shares.length == i + 1;
                uint256 _share = _useRest ? _rest : (_amount * uint256(s.shares[i].points)) / uint256(s.totalPoints);
                _rest = _useRest ? 0 : _rest - _share;
                if (s.shares[i].swap.length > 1) {
                    address _token = s.shares[i].swap[s.shares[i].swap.length - 1];
                    uint256[] memory amounts = IRouter02(s.router).swapExactAVAXForTokens{ value: _share }(
                        0,
                        s.shares[i].swap,
                        s.shares[i].receiver.isContract() ? address(this) : s.shares[i].receiver,
                        block.timestamp
                    );
                    _share = amounts[amounts.length - 1];
                    if (s.shares[i].receiver.isContract()) {
                        IERC20(_token).approve(s.shares[i].receiver, _share);
                        IDepositable(s.shares[i].receiver).deposit(_token, _share);
                    }
                    emit Distributed(s.shares[i].receiver, _share);
                } else if (s.shares[i].receiver.isContract()) {
                    IWAVAX(s.nativeWrapper).deposit{ value: _share }();
                    IERC20(s.nativeWrapper).approve(s.shares[i].receiver, _share);
                    IDepositable(s.shares[i].receiver).deposit(s.nativeWrapper, _share);
                    emit Distributed(s.shares[i].receiver, _share);
                } else {
                    payable(s.shares[i].receiver).sendValue(_share);
                    emit Distributed(s.shares[i].receiver, _share);
                }
            }
        } else {
            payable(_receiver).sendValue(_amount);
            emit Distributed(_receiver, _amount);
        }
    }

    /// Set the the running state of the distributor
    /// @param _running flag
    function _setRunning(bool _running) internal {
        LibAccessControlEnumerable.checkRole(Constants.FEE_MANAGER_ROLE);
        Storage storage s = _store();
        s.running = _running;
    }

    function _payoutBountyInToken(address _token, uint256 _amount, address _receiver) internal returns (uint256 _amountLeft) {
        Storage storage s = _store();
        _amountLeft = _amount;
        if (s.bountyActive && s.bountyShare > 0 && _receiver != address(0) && _amountLeft > 0) {
            uint256 _bountyAmount = (_amountLeft * s.bountyShare) / 10 ** 6;
            _amountLeft -= _bountyAmount;
            s.totalBounties += _bountyAmount;
            s.lastBountyAmount = _bountyAmount;
            s.lastBountyReceiver = _receiver;
            // slither-disable-next-line unchecked-transfer
            IERC20(_token).transfer(_receiver, _bountyAmount);
            emit BountyPaid(_bountyAmount, _receiver);
        }
    }

    function _payoutBountyInNative(uint256 _amount, address _receiver) internal returns (uint256 _amountLeft) {
        Storage storage s = _store();
        _amountLeft = _amount;
        if (s.bountyActive && s.bountyShare > 0 && _receiver != address(0) && _amountLeft > 0) {
            uint256 _bountyAmount = (_amountLeft * s.bountyShare) / 10 ** 6;
            _amountLeft -= _bountyAmount;
            s.totalBounties += _bountyAmount;
            s.lastBountyAmount = _bountyAmount;
            s.lastBountyReceiver = _receiver;
            payable(_receiver).sendValue(_bountyAmount);
            emit BountyPaid(_bountyAmount, _receiver);
        }
    }

    /// Store
    function _store() internal pure returns (Storage storage s) {
        bytes32 position = STORAGE_NAMESPACE;
        assembly {
            s.slot := position
        }
    }
}
