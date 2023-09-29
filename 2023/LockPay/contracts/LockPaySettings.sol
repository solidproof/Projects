pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ILockPayFactory.sol";
import "./interfaces/IOwnable.sol";

contract LockPaySettings is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    struct Settings {
        address feesToken;
        address feesBeneficiary;
        uint256 creationFee;
    }

    struct Fees {
        uint256 lockFee;
        uint256 relockFee;
        uint256 referralFee; 
    }
    
    EnumerableSet.AddressSet private allowedReferrers;

    address public generator;
    ILockPayFactory public factory;
    Settings public settings;
    Fees public defaultFees;
    mapping(address => Fees) public lockersFees;
    mapping(address => Fees) public lockersAdminFees;

    modifier onlyGenerator {
        require(generator == msg.sender, "LockPay: FORBIDDEN");
        _;
    }

    event FactoryUpdated(address newFactoryContract);
    event generatorUpdated(address generatorContract);
    event FeesUpdated(address feesToken, address beneficiary, uint256 creationFee);
    event DefaultFeesUpdated(uint256 lockFee, uint256 relockFee, uint256 referralFee);
    event LockerFeesUpdated(address indexed lockerContract, uint256 lockFee, uint256 relockFee, uint256 referralFee);

    constructor(address _feesToken, address _feesBeneficiary, uint256 _creationFee) {
        settings.feesToken = _feesToken; 
        settings.feesBeneficiary = _feesBeneficiary; 
        settings.creationFee = _creationFee;
    }

    /**
    * @notice returns specific locker fees amount
    * @param _locker locker address
    * @return (lockFee, relockFee, referralFee, extraLockFee, extraRelockFee, extraReferralFee, feesBeneficiary) returns fees amount and beneficiary address.
    */
    function getLockerFees(address _locker) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, address) {
        Fees memory lockerFees = lockersFees[_locker];
        Fees memory extraFees = lockersAdminFees[_locker];

        return (lockerFees.lockFee, lockerFees.relockFee, lockerFees.referralFee, extraFees.lockFee, extraFees.relockFee, extraFees.referralFee, settings.feesBeneficiary);
    }

    /**
    * @notice Set default fees for locker during generation event. Only callable with Generator.
    * @param _locker locker address
    */
    function setLockerFees(address _locker) external onlyGenerator {
        require(_locker != address(0), "LockPay: INVALID_LOCKER");
        lockersFees[_locker] = defaultFees;

        emit LockerFeesUpdated(_locker, defaultFees.lockFee, defaultFees.relockFee, defaultFees.referralFee);
    }

    /**
    * @notice Updates locker fees in settings contract. Locker calls this function.
    * @param _lockFee Lock Fee (with 2 decimals)
    * @param _relockFee Relock Fee (with 2 decimals)
    * @param _referralFee Referral Fee (with 2 decimals)
    */
    function updateLockerFees(
        uint256 _lockFee,
        uint256 _relockFee,
        uint256 _referralFee
    ) external {
        require(factory.lockerIsRegistered(msg.sender), "LockPay: FORBIDDEN");
        require(_lockFee <= 2500, "LockPay: INVALID_FEE");
        require(_relockFee <= 2500, "LockPay: INVALID_FEE");
        require(_relockFee <= 2500, "LockPay: INVALID_FEE");

        address lockerOwner = IOwnable(msg.sender).owner();
        if(lockerOwner == owner()) {
            lockersFees[msg.sender].lockFee = _lockFee;
            lockersFees[msg.sender].relockFee = _relockFee;
            lockersFees[msg.sender].referralFee = _referralFee;
        } else {
            lockersAdminFees[msg.sender].lockFee = _lockFee;
            lockersAdminFees[msg.sender].relockFee = _relockFee;
            lockersAdminFees[msg.sender].referralFee = _referralFee;
        }

        emit LockerFeesUpdated(msg.sender, _lockFee, _relockFee, _referralFee);

    }

    /**
    * @notice Updates LockPay factory contract address.
    * @param _factoryContract New Factory address.
    */
    function updateFactory(address _factoryContract) external onlyOwner {
        require(_factoryContract != address(0), "LockPay: INVALID_FACTORY");
        require(_factoryContract.isContract(), "LockPay: NOT_CONTRACT");
        factory = ILockPayFactory(_factoryContract);

        emit FactoryUpdated(_factoryContract);
    }

    /**
    * @notice Updates LockPay Generator contract address.
    * @param _generator New generator address.
    */
    function adminUpdateGeneratorAddress(address _generator) external onlyOwner {
        require(_generator != address(0), "LockPay: INVALID_ADDRESS");
        generator = _generator;

        emit generatorUpdated(generator);
    }

    /**
    * @notice Returns fees token address.
    * @return address Fees token
    */
    function getFeesToken () external view returns (address) {
        return settings.feesToken;
    }

    /**
    * @notice Returns fees Beneficiary address.
    * @return address Beneficiary address.
    */
    function getFeesBeneficiary () external view returns (address) {
        return settings.feesBeneficiary;
    }

    /**
    * @notice Returns creation fee amount.
    * @return uint256 creation fee.
    */
    function getFeesAmount () external view returns (uint256) {
        return settings.creationFee;
    }

    /**
    * @notice Updates default fees settings.
    * @param _feesToken Fee token
    * @param _feesBeneficiary fees Beneficiary address.
    * @param _creationFee Creation Fee (with 2 decimals)
    */
    function setFees(address _feesToken, address _feesBeneficiary, uint256 _creationFee) external onlyOwner {
        require(_feesBeneficiary != address(0), "LockPay: INVALID_BENEFICIARY");
        require(_creationFee <= 2500, "LockPay: INVALID_FEE");
        settings.feesToken = _feesToken; 
        settings.feesBeneficiary = _feesBeneficiary; 
        settings.creationFee = _creationFee;

        emit FeesUpdated(_feesToken, _feesBeneficiary, _creationFee);
    }

    /**
    * @notice Updates lockers default fees.
    * @param _lockFee Lock Fee (with 2 decimals)
    * @param _relockFee Relock Fee (with 2 decimals)
    * @param _referralFee Referral Fee (with 2 decimals)
    */
    function updateDefaultFees(uint256 _lockFee, uint256 _relockFee, uint256 _referralFee) external onlyOwner {
        require(_lockFee <= 2500, "LockPay: EXCEED_MAX_LIMIT");
        require(_relockFee <= 2500, "LockPay: EXCEED_MAX_LIMIT");
        require(_referralFee <= 2500, "LockPay: EXCEED_MAX_LIMIT");
        defaultFees.lockFee = _lockFee; 
        defaultFees.relockFee = _relockFee; 
        defaultFees.referralFee = _referralFee;

        emit DefaultFeesUpdated(_lockFee, _relockFee, _referralFee);
    }


    /**
    * @notice Updates referrals
    * @param _referrer Referrer address.
    * @param _allow Boolean flag.
    */
    function editAllowedReferrers(address payable _referrer, bool _allow) external onlyOwner {
        if (_allow) {
            allowedReferrers.add(_referrer);
        } else {
            allowedReferrers.remove(_referrer);
        }
    }

    // Referrers
    function allowedReferrersLength() external view returns (uint256) {
        return allowedReferrers.length();
    }
    
    function getReferrerAtIndex(uint256 _index) external view returns (address) {
        return allowedReferrers.at(_index);
    }
    
    function referrerIsValid(address _referrer) external view returns (bool) {
        return allowedReferrers.contains(_referrer);
    }
}
