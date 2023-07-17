pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ILockPayFactory.sol";
import "./interfaces/IOwnable.sol";

contract LockPaySettings is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

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

    // @todo: add customize locker fees option
    constructor(address _feesToken, address _feesBeneficiary, uint256 _creationFee) {
        settings.feesToken = _feesToken; 
        settings.feesBeneficiary = _feesBeneficiary; 
        settings.creationFee = _creationFee;
    }

    function getLockerFees(address _locker) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, address) {
        Fees memory lockerFees = lockersFees[_locker];
        Fees memory extraFees = lockersAdminFees[_locker];

        return (lockerFees.lockFee, lockerFees.relockFee, lockerFees.referralFee, extraFees.lockFee, extraFees.relockFee, extraFees.referralFee, settings.feesBeneficiary);
    }

    function setLockerFees(address _locker) external onlyGenerator {
        require(_locker != address(0), "LockPay: INVALID_LOCKER");
        lockersFees[_locker] = defaultFees;

        emit LockerFeesUpdated(_locker, defaultFees.lockFee, defaultFees.relockFee, defaultFees.referralFee);
    }

    function updateLockerFees(
        uint256 _lockFee,
        uint256 _relockFee,
        uint256 _referralFee
    ) external {
        require(factory.lockerIsRegistered(msg.sender), "LockPay: FORBIDDEN");
        require(_lockFee <= 3000, "LockPay: INVALID_FEE");
        require(_relockFee <= 3000, "LockPay: INVALID_FEE");
        require(_relockFee <= 3000, "LockPay: INVALID_FEE");

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

    function updateFactory(address _factoryContract) external onlyOwner {
        require(_factoryContract != address(0), "LockPay: INVALID_FACTORY");
        factory = ILockPayFactory(_factoryContract);

        emit FactoryUpdated(_factoryContract);
    }

    function adminUpdateGeneratorAddress(address _generator) external onlyOwner {
        require(_generator != address(0), "LockPay: INVALID_ADDRESS");
        generator = _generator;

        emit generatorUpdated(generator);
    }

    function getFeesToken () external view returns (address) {
        return settings.feesToken;
    }

    function getFeesBeneficiary () external view returns (address) {
        return settings.feesBeneficiary;
    }

    function getFeesAmount () external view returns (uint256) {
        return settings.creationFee;
    }

    function setFees(address _feesToken, address _feesBeneficiary, uint256 _creationFee) external onlyOwner {
        require(_feesBeneficiary != address(0), "LockPay: INVALID_BENEFICIARY");
        require(_creationFee <= 3000, "LockPay: INVALID_FEE");
        settings.feesToken = _feesToken; 
        settings.feesBeneficiary = _feesBeneficiary; 
        settings.creationFee = _creationFee;

        emit FeesUpdated(_feesToken, _feesBeneficiary, _creationFee);
    }

    function updateDefaultFees(uint256 _lockFee, uint256 _relockFee, uint256 _referralFee) external onlyOwner {
        require(_lockFee <= 3000, "LockPay: EXCEED_MAX_LIMIT");
        require(_relockFee <= 3000, "LockPay: EXCEED_MAX_LIMIT");
        require(_referralFee <= 3000, "LockPay: EXCEED_MAX_LIMIT");
        defaultFees.lockFee = _lockFee; 
        defaultFees.relockFee = _relockFee; 
        defaultFees.referralFee = _referralFee;

        emit DefaultFeesUpdated(_lockFee, _relockFee, _referralFee);
    }


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
