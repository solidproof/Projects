pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libraries/TransferHelper.sol";
import "./LockPayVesting.sol";

import "./interfaces/ILockPayFactory.sol";
import "./interfaces/ILockPaySettings.sol";

contract LockPayGenerator is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    
    ILockPayFactory public factory;
    ILockPaySettings public settings;

    struct LockerParams {
        string name;
        uint256 earlyWithdrawPenalty;
        uint256 maxWithdrawPercentage; // With 2 decimals
        address beneficiaryAddress;
        address stakingAddress;
        string stakingSignature;
        bool isStakable;
        bool isRelockable;
    }

    struct RefundParams {
        address refundWallet;
        uint256 maxRefundPercentage;
        bool withoutPenalty;
    }

    struct PlansParams {
        uint256 duration;
        uint256 amount;
        bool isPercentage;
    }

    event FactoryUpdated(address indexed newFactoryContract);
    event SettingsUpdated(address indexed newSettingsContract);
    event LockerGenerated(address indexed lockerContract, address indexed tokenContract);

    constructor(
        address _lockpayFactory,
        address _lockpaySettings
    ) {
        factory = ILockPayFactory(_lockpayFactory);
        settings = ILockPaySettings(_lockpaySettings);
    }

    function updateFactory(address _factoryContract) external onlyOwner {
        require(_factoryContract != address(0), "LockPay: INVALID_FACTORY");
        factory = ILockPayFactory(_factoryContract);

        emit FactoryUpdated(_factoryContract);
    }

    function updateSettings(address _settingsContract) external onlyOwner {
        require(_settingsContract != address(0), "LockPay: INVALID_SETTINGS");
        settings = ILockPaySettings(_settingsContract);

        emit SettingsUpdated(_settingsContract);
    }

    function getFees(address _locker) public view returns (uint256, uint256, uint256, uint256, uint256, uint256, address) {
        return settings.getLockerFees(_locker);
    }

    /**
     * @notice Creates a new Locker contract and registers it in the LockPayFactory.sol.
     */
    function createLocker (
      address payable _lockerAdmin,
      address payable _referralAddress,
      address _lockerToken,
      LockerParams calldata _lockerParams,
      RefundParams calldata _refundParams,
      PlansParams[] calldata _durations
    ) external payable nonReentrant {
        require(_lockerAdmin != address(0), "LockPay: INVALID_ADMIN");
        require(_lockerToken != address(0), "LockPay: INVALID_TOKEN");

        if (_referralAddress != address(0)) {
            require(settings.referrerIsValid(_referralAddress), 'LockPay: INVALID_REFERRAL');
        }

        uint256 feesAmount = settings.getFeesAmount();
        if(msg.sender == owner()) {
            feesAmount = 0;
        }
    
        if(settings.getFeesToken() == address(0)) {
            // Charge ETH fee for locker creation
            require(msg.value >= feesAmount, 'LockPay: INSUFFICIENT_FEE');
            payable(settings.getFeesBeneficiary()).transfer(feesAmount);

            if(msg.value > feesAmount) {
                payable(msg.sender).transfer(msg.value - feesAmount);
            }
        } else {
            TransferHelper.safeTransferFrom(settings.getFeesToken(), address(msg.sender), settings.getFeesBeneficiary(), feesAmount);
        }
        
        require(_lockerParams.earlyWithdrawPenalty <= 5000, 'LockPay: INVALID_PENALTY'); // max penalty percent
        require(_lockerParams.maxWithdrawPercentage > 0, "LockPay: INVALID_WITHDRAW_AMOUNT"); // min withdrawable amount
        require(_durations.length > 0, "LockPay: INVALID_DURATIONS_LENGTH");

        if(_refundParams.refundWallet != address(0)) {
            require(_refundParams.maxRefundPercentage > 0, "LockPay: INVALID_REFUND_AMOUNT"); // min refund amount
        }
        
        LockPayVesting newLocker = new LockPayVesting(address(this), _lockerAdmin, _lockerToken);
        {
        newLocker.init(
            _lockerParams.name,
            _lockerParams.earlyWithdrawPenalty,
            _lockerParams.maxWithdrawPercentage,
            _lockerParams.beneficiaryAddress,
            _lockerParams.stakingAddress,
            _lockerParams.stakingSignature,
            _lockerParams.isStakable,
            _lockerParams.isRelockable
        );
        }
        
        for(uint256 i = 0; i < _durations.length; i++) {
            newLocker.addDuration(
                _durations[0].duration,
                _durations[0].amount,
                _durations[0].isPercentage
            );
        }
        
        if(_refundParams.refundWallet != address(0)) {
            newLocker.setRefundSettings(
                _refundParams.refundWallet,
                _refundParams.maxRefundPercentage,
                _refundParams.withoutPenalty
            );
        }


        if (_referralAddress != address(0)) {
            newLocker.addReferral(_referralAddress);
        }

        factory.registerLocker(address(newLocker));
        settings.setLockerFees(address(newLocker));

        emit LockerGenerated(address(newLocker), _lockerToken);
    }
}