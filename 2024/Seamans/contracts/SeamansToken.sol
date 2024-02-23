// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract SeamansToken is 
    Initializable,
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC777Upgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable {
    
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    
    struct VestingSchedule{
        bool initialized;
        // beneficiary of tokens after they are released
        address  beneficiary;
        // cliff period in seconds
        uint256  cliff;
        // start time of the vesting period
        uint256  start;
        // duration of the vesting period in seconds
        uint256  duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // whether or not the vesting is revocable
        bool  revocable;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256  released;
        // whether or not the vesting has been revoked
        bool revoked;
    }


    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;


    event Released(uint256 amount);
    event Revoked(bytes32);
    event VestingCreated(bytes32, address, uint256);

    /**
    * @dev Reverts if no vesting schedule matches the passed identifier.
    */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true, "not intialized");
        _;
    }

    /**
    * @dev Reverts if the vesting schedule does not exist or has been revoked.
    */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true, "not intialized");
        require(vestingSchedules[vestingScheduleId].revoked == false, "already revoked");
        _;
    }

    /**
     * @dev Creates a vesting contract.
     */
    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __ERC777_init(name, symbol, new address[](0));
        _mint(_msgSender(), initialSupply, "", "");

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
    }

    receive() external payable {}

    fallback() external payable {}

    /**
    * @dev Returns the number of vesting schedules associated to a beneficiary.
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
    public
    view
    returns(uint256){
        return holdersVestingCount[_beneficiary];
    }

    /**
    * @dev Returns the vesting schedule id at the given index.
    * @return the vesting id
    */
    function getVestingIdAtIndex(uint256 index)
    external
    view
    returns(bytes32){
        require(index < getVestingSchedulesCount(), "index out of bounds");
        return vestingSchedulesIds[index];
    }

    /**
    * @notice Returns the vesting schedule information for a given holder and index.
    * @return the vesting schedule structure information
    */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
    public
    view
    returns(VestingSchedule memory){
        return getVestingSchedule(computeVestingScheduleIdForAddressAndIndex(holder, index));
    }


    /**
    * @notice Returns the total amount of vesting schedules.
    * @return the total amount of vesting schedules
    */
    function getVestingSchedulesTotalAmount()
    external
    view
    returns(uint256){
        return vestingSchedulesTotalAmount;
    }

    /**
    * @notice Creates a new vesting schedule for a beneficiary.
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param _start start time of the vesting period
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
    * @param _revocable whether the vesting is revocable or not
    * @param _amount total amount of tokens to be released at the end of the vesting
    */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    )
        public
        {
        // require(
        //     this.getWithdrawableAmount() >= _amount,
        //     "cannot create vesting schedule because not sufficient tokens"
        // );
        require(hasRole(MANAGER_ROLE, _msgSender()), "unauthorized");
        require(_duration > 0, "duration must be > 0");
        require(_amount > 0, "amount must be > 0");
        require(_cliff <= _duration, "invalid cliff");
        require(_slicePeriodSeconds >= 1, "slicePeriodSeconds must be >= 1");

        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(_beneficiary);
        uint256 cliff = _start.add(_cliff);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            0,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);

        // todo: add event emit
        emit VestingCreated(vestingScheduleId, _beneficiary, _amount);
    }

    /**
    * @notice Revokes the vesting schedule for given identifier.
    * @param vestingScheduleId the vesting schedule identifier
    */
    function revoke(bytes32 vestingScheduleId)
        public
        onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        require(hasRole(MANAGER_ROLE, _msgSender()), "unauthorized");
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable == true, "vesting is not revocable");
        // uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        // if(vestedAmount > 0){
        //     release(vestingScheduleId, vestedAmount);
        // }
        uint256 unreleased = vestingSchedule.amountTotal.sub(vestingSchedule.released);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(unreleased);
        vestingSchedule.revoked = true;

        // todo: add event emit
        emit Revoked(vestingScheduleId);
    }

    /**
    * @dev Returns the number of vesting schedules managed by this contract.
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCount()
        public
        view
        returns(uint256){
        return vestingSchedulesIds.length;
    }

    /**
    * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
    * @return the vested amount
    */
    function computeReleasableAmount(bytes32 vestingScheduleId)
        public
        onlyIfVestingScheduleNotRevoked(vestingScheduleId)
        view
        returns(uint256){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    function computeLockedAmount(address holder)
        public
        view
        returns(uint256) {
        uint count = getVestingSchedulesCountByBeneficiary(holder);
        require(count <= getVestingSchedulesCount(), "index out of bounds");
        uint totalLocked = 0;
        for (uint i = 0; i < count; i++) {
            VestingSchedule memory vestingSchedule = getVestingScheduleByAddressAndIndex(holder, i);
            
            uint256 lockedAmount = _computeLockedAmount(vestingSchedule);
            totalLocked = totalLocked.add(lockedAmount);
        }

        return totalLocked;
    }

    /**
    * @notice Returns the vesting schedule information for a given identifier.
    * @return the vesting schedule structure information
    */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    /**
    * @dev Computes the next vesting schedule identifier for a given holder address.
    */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns(bytes32){
        return computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder]);
    }

    /**
    * @dev Returns the last vesting schedule for a given holder address.
    */
    function getLastVestingScheduleForHolder(address holder)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder] - 1)];
    }

    /**
    * @dev Computes the vesting schedule identifier for an address and an index.
    */
    function computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
        public
        pure
        returns(bytes32){
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
    * @dev Computes the releasable amount of tokens for a vesting schedule.
    * @return the amount of releasable tokens
    */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked == true) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(vestedSeconds).div(vestingSchedule.duration);
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
            return vestedAmount;
        }
    }

    function _computeLockedAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();
        if (vestingSchedule.revoked == true) {
            return 0;
        } else if ((currentTime < vestingSchedule.cliff)) {
            return vestingSchedule.amountTotal;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.duration)) {
            return 0;
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
            uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
            uint256 vestedAmount = vestingSchedule.amountTotal.mul(vestedSeconds).div(vestingSchedule.duration);
            return vestingSchedule.amountTotal.sub(vestedAmount);
        }
    }

    function getCurrentTime()
        internal
        virtual
        view
        returns(uint256){
        return block.timestamp;
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256 amount) internal override virtual {
        uint totalLocked = computeLockedAmount(from);
        
        if (from != address(0)) require(amount <= balanceOf(from).sub(totalLocked), 'check vesting or balance');
        super._beforeTokenTransfer(operator, from, to, amount);
    }

    function vestedTransfer(
        address _recipient, 
        uint256 _amount, 
        uint256 _start, 
        uint256 _cliff, 
        uint256 _duration, 
        uint256 _slicePeriodSeconds, 
        bool _revocable
    ) public virtual {
        require(hasRole(MANAGER_ROLE, _msgSender()), "unauthorized");
        createVestingSchedule(_recipient, _start, _cliff, _duration, _slicePeriodSeconds, _revocable, _amount);
        super.transfer(_recipient, _amount);
    }

    function vestedBatchTransfer(
        address[] calldata _recipients, 
        uint256[] calldata _amounts, 
        uint256 _start, 
        uint256 _cliff, 
        uint256 _duration, 
        uint256 _slicePeriodSeconds, 
        bool _revocable
    ) public virtual {
        require(hasRole(MANAGER_ROLE, _msgSender()), "unauthorized");
        require(_recipients.length == _amounts.length, "address & amount size mismatch");
        require(_duration > 0, "duration must be > 0");
        require(_cliff <= _duration, "invalid cliff");
        require(_slicePeriodSeconds >= 1, "slicePeriodSeconds must be >= 1");
        uint256 cliff = _start.add(_cliff);

        for (uint i; i < _recipients.length; i++) {
            require(_amounts[i] > 0, "amount must be > 0");
            bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(_recipients[i]);
            vestingSchedules[vestingScheduleId] = VestingSchedule(
                true,
                _recipients[i],
                cliff,
                _start,
                _duration,
                _slicePeriodSeconds,
                _revocable,
                _amounts[i],
                0,
                false
            );
            vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amounts[i]);
            vestingSchedulesIds.push(vestingScheduleId);
            uint256 currentVestingCount = holdersVestingCount[_recipients[i]];
            holdersVestingCount[_recipients[i]] = currentVestingCount.add(1);

            // todo: add event emit
            emit VestingCreated(vestingScheduleId, _recipients[i], _amounts[i]);
            super.transfer(_recipients[i], _amounts[i]);
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}