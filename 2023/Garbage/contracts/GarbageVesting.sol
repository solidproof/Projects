// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IGarbageVesting.sol";

contract GarbageVesting is Ownable, IGarbageVesting {
    using SafeERC20 for IERC20;
    struct Beneficiary {
        uint256 amount;
        uint256 vestingAmount;
        uint256 claimed;
    }

    // _______________ Storage _______________

    /// @dev Number of vesting periods.
    uint256 public vestingPeriods;

    /// @dev Vesting period duration.
    uint256 public vestingPeriodDuration;

    /// @dev Vesting start timestamp.
    uint256 public startTimestamp;

    /// @dev Vesting end timestamp.
    uint256 public endTimestamp;

    /// @dev Sum of all vesting amounts added to the contract.
    uint256 public totalVestingAmount;

    /// @dev vestingToken $GARBAGE token address.
    IERC20 public vestingToken;

    /// @dev Garbage sale contract address.
    address public garbageSale;

    // beneficiary address => beneficiary data struct
    mapping(address => Beneficiary) public beneficiaries;

    // amount of tokens claimed by all beneficiaries
    uint256 public totalClaimed;

    uint256 public constant VESTING_DURATION = 10 weeks;

    // _______________ Errors _______________

    /// @dev Revert is zero address is passed.
    error ZeroAddress();

    /// @dev Revert if zero vesting amount is passed.
    error ZeroVestingAmount(address _beneficiary);

    error LessThanTwoVestingPeriods(uint256 _vestingPeriods);

    /// @dev Revert if beneficiary does not exist.
    error NotABeneficiary(address _user);

    /// @dev Revert if caller is not a garbage sale contract.
    error NotAGarbageSale(address _caller);

    /// @dev Revert if vesting is not initialized.
    error VestingDatesNotSet();

    /// @dev Revert if vesting period is not set.
    error VestingPeriodNotSet();

    /// @dev Revert if user has already claimed.
    error NothingToClaim(address user);

    /// @dev Revert when trying to rescue vesting tokens.
    error VestingTokenRescue(IERC20 vestingToken);

    /// @dev Revert if end timestamp is before start timestamp.
    error EndTimestampBeforeStartTimestamp(uint256 end, uint256 start);

    /// @dev Revert if claim amount exceeds vesting amount.
    error ClaimAmountExceedsVestingAmount(address _beneficiary, uint256 _claimAmount, uint256 _amount);

    /// @dev Revert if start timestamp is before current timestamp (now).
    error StartTimestampBeforeCurrentTimestamp(uint256 start, uint256 current);

    /// @dev Revert if vesting already started.
    error VestingAlreadyStarted();

    // _______________ Events _______________

    /**
     * @dev Emitted when the claim is successful.
     *
     * @param _user   Address of the user.
     * @param _amount   Amount of the claim.
     */
    event Claim(address indexed _user, uint256 indexed _amount);

    /**
     * @dev Emitted when a new beneficiary is added or when additional amount is added to the existing beneficiary.
     *
     * @param _beneficiary   Address of the beneficiary.
     * @param _newAmount   Total amount to vest to the user.
     * @param _newVestingAmount   Token amount per one vesting period.
     */
    event BeneficiaryUpdated(address indexed _beneficiary, uint256 indexed _newAmount, uint256 _newVestingAmount);

    /**
     * @dev Emitted when the start and/or end date is updated.
     */
    event VestingDatesUpdated(uint256 indexed _startTimestamp, uint256 indexed _endTimestamp);

    /**
     * @dev Emitted when the vestingToken token address is updated.
     */
    event VestingTokenUpdated(address indexed _vestingToken);

    /**
     * @dev Emitted when the garbage sale contract address is updated.
     */
    event GarbageVestingUpdated(address indexed _garbageVesting);

    /**
     * @dev Emitted when the number of vesting periods is updated.
     */
    event VestingPeriodsNumberUpdated(uint256 _vestingPeriodsNumber);

    /**
     * @dev Emitted when ERC20 tokens are rescued.
     */
    event ERC20Rescued(address indexed _token, address indexed _to, uint256 indexed _amount);

    // _______________ Modifiers _______________

    /**
     * @dev Zero address check.
     */
    modifier notZeroAddress(address _address) {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    /**
     * @dev Check if _user is a beneficiary.
     */
    modifier onlyBeneficiary(address _user) {
        if (beneficiaries[_user].amount == 0) {
            revert NotABeneficiary(_user);
        }
        _;
    }

    /**
     * @dev Check if mgs.sender is a garbage sale contract.
     */
    modifier onlyGarbageSale() {
        if (msg.sender != garbageSale) {
            revert NotAGarbageSale(msg.sender);
        }
        _;
    }

    // _______________ Constructor ______________

    /**
     * @dev Initialize vesting.
     *
     * @param _startTimestamp   Start timestamp of the vesting.
     * @param _vestingToken   Address of the vestingToken token.
     * @param _vestingPeriods   Number of vesting periods.
     */
    constructor(
        IERC20 _vestingToken,
        uint256 _startTimestamp,
        uint256 _vestingPeriods
    ) Ownable() {
        if (_startTimestamp <= block.timestamp)
            revert StartTimestampBeforeCurrentTimestamp(_startTimestamp, block.timestamp);
        // init variables
        _setVestingStartDate(_startTimestamp);
        _setVestingToken(_vestingToken);
        _setVestingPeriods(_vestingPeriods);
    }

    // _______________ External functions _______________

    /**
     * @dev Claim tokens.
     */
    function claim() external onlyBeneficiary(msg.sender) {
        uint256 amount = calculateClaimAmount(msg.sender);
        if (amount == 0) {
            revert NothingToClaim(msg.sender);
        }
        beneficiaries[msg.sender].claimed += amount;
        totalClaimed += amount;

        vestingToken.safeTransfer(msg.sender, amount);

        emit Claim(msg.sender, amount);
    }

    /**
     * @dev Update start timestamp. End timestamp is calculated based on the start timestamp.
     * @param _startTimestamp  Start timestamp of the vesting.
     */
    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        _setVestingStartDate(_startTimestamp);
    }

    /**
     * @dev Set new GarbageSale contract address.
     * @param _garbageSale Address of the new GarbageSale contract.
     */
    function setGarbageSale(address _garbageSale) external onlyOwner {
        _setGarbageSale(_garbageSale);
    }

    /**
     * @dev Rescue ERC20 tokens from the contract. Token must be not vestingToken.
     * @param _token Address of the token to rescue.
     * @param _to Address to send tokens to.
     */
    function rescueERC20(IERC20 _token, address _to)
        external
        onlyOwner
        notZeroAddress(address(_token))
        notZeroAddress(_to)
    {
        if (vestingToken == _token) {
            revert VestingTokenRescue(vestingToken);
        }
        emit ERC20Rescued(address(_token), _to, _token.balanceOf(address(this)));
        _token.safeTransfer(_to, _token.balanceOf(address(this)));
    }

    // _______________ Garbage sale functions _______________

    /**
     * @dev Allows GarbageSale contract to add beneficiary. If beneficiary already exists, it adds amount to the existing beneficiary.
     * @param _beneficiary Address of the beneficiary.
     * @param _amount Amount of tokens to be vested.
     */
    function addAmountToBeneficiary(address _beneficiary, uint256 _amount) external onlyGarbageSale {
        vestingToken.safeTransferFrom(msg.sender, address(this), _amount);
        _addAmountToBeneficiary(_beneficiary, _amount);
    }

    // _______________ Public functions _______________

    /**
     * @dev Calculate claim amount for the beneficiary. It returns 0 if vesting is not active or beneficiary has already claimed all tokens.
     *
     * @param _beneficiary   Address of the beneficiary.
     * @return claimAmount   Amount of tokens that can be claimed by the beneficiary.
     */
    function calculateClaimAmount(address _beneficiary)
        public
        view
        onlyBeneficiary(_beneficiary)
        returns (uint256 claimAmount)
    {
        Beneficiary storage beneficiary = beneficiaries[_beneficiary];

        // theoretically should never happen, but just in case
        if (startTimestamp == 0 || endTimestamp == 0) return 0;
        if (beneficiary.amount == 0 || beneficiary.amount <= beneficiary.claimed) return 0;
        if (block.timestamp <= startTimestamp) return 0;

        uint256 vestedPeriods = (block.timestamp - startTimestamp) / vestingPeriodDuration;
        // because we already checked that block.timestamp > initialUnlockTimestamp, so user can claim at least initialAmount
        uint256 claimableAmount = 0;

        if (vestedPeriods >= vestingPeriods) {
            claimableAmount = beneficiary.amount;
        } else {
            claimableAmount += vestedPeriods * beneficiary.vestingAmount;
        }
        claimAmount = claimableAmount - beneficiary.claimed;
        // should never happen, but just in case
        if (claimAmount + beneficiary.claimed > beneficiary.amount)
            revert ClaimAmountExceedsVestingAmount(_beneficiary, claimAmount, beneficiary.amount);
    }

    /**
     * @dev Returns all vesting data.
     *
     * @return _totalVestingAmount   Total amount of vesting tokens.
     * @return _startTimestamp   Start timestamp of the vesting.
     * @return _endTimestamp   End timestamp of the vesting.
     * @return _vestingPeriods   Number of vesting periods.
     * @return _vestingPeriodDuration   Duration of the vesting period.
     * @return _vestingToken   Address of the vestingToken token.
     */
    function getAllVestingData()
        external
        view
        returns (
            uint256 _totalVestingAmount,
            uint256 _startTimestamp,
            uint256 _endTimestamp,
            uint256 _vestingPeriods,
            uint256 _vestingPeriodDuration,
            address _vestingToken
        )
    {
        _totalVestingAmount = totalVestingAmount;
        _startTimestamp = startTimestamp;
        _endTimestamp = endTimestamp;
        _vestingPeriods = vestingPeriods;
        _vestingPeriodDuration = vestingPeriodDuration;
        _vestingToken = address(vestingToken);
    }

    // _______________ Internal functions _______________

    /**
     * @dev Add beneficiary to the vesting.
     *
     * @param _beneficiary   Address of the beneficiary.
     * @param _amount   Amount of tokens to be vested.
     */
    function _addAmountToBeneficiary(address _beneficiary, uint256 _amount) internal notZeroAddress(_beneficiary) {
        // theoretically it should never happen, but just in case
        if (vestingPeriods == 0) revert VestingPeriodNotSet();
        if (_amount == 0) revert ZeroVestingAmount(_beneficiary);

        beneficiaries[_beneficiary].amount += _amount;
        beneficiaries[_beneficiary].vestingAmount = beneficiaries[_beneficiary].amount / vestingPeriods;

        emit BeneficiaryUpdated(
            _beneficiary,
            beneficiaries[_beneficiary].amount,
            beneficiaries[_beneficiary].vestingAmount
        );
        totalVestingAmount = totalVestingAmount + _amount;
    }

    /**
     * @dev Set the claim start timestamp. End timestamp is calculated based on the start timestamp.
     *
     * @param _startTimestamp Claim start timestamp.
     */
    function _setVestingStartDate(uint256 _startTimestamp) internal {
        if (block.timestamp > startTimestamp && startTimestamp != 0) revert VestingAlreadyStarted();
        startTimestamp = _startTimestamp;
        endTimestamp = startTimestamp + VESTING_DURATION;
        emit VestingDatesUpdated(_startTimestamp, endTimestamp);
    }

    /**
     * @dev Set the vestingToken token address.
     * Requirements:
     * - vestingToken token address must not be zero address.
     * @param _vestingToken vestingToken token address.
     */
    function _setVestingToken(IERC20 _vestingToken) internal notZeroAddress(address(_vestingToken)) {
        vestingToken = _vestingToken;
        emit VestingTokenUpdated(address(_vestingToken));
    }

    /**
     * @dev Set address of the garbage sale contract.
     * Requirements:
     * - garbage sale contract address must not be zero address.
     * @param _garbageSale Address of the garbage sale contract.
     */
    function _setGarbageSale(address _garbageSale) internal notZeroAddress(_garbageSale) {
        garbageSale = _garbageSale;
        emit GarbageVestingUpdated(_garbageSale);
    }

    /**
     * @dev Set the vesting periods.
     * Requirements:
     * - vesting periods must be greater than 1.
     * @param _vestingPeriods Number of vesting periods.
     */
    function _setVestingPeriods(uint256 _vestingPeriods) internal {
        if (_vestingPeriods < 2) revert LessThanTwoVestingPeriods(_vestingPeriods);
        // theoretically it should never happen, but just in case
        if (endTimestamp == 0 || startTimestamp == 0) revert VestingDatesNotSet();
        // theoretically it should never happen, but just in case
        if (endTimestamp <= startTimestamp) revert EndTimestampBeforeStartTimestamp(endTimestamp, startTimestamp);
        vestingPeriods = _vestingPeriods;
        vestingPeriodDuration = (endTimestamp - startTimestamp) / vestingPeriods;
        emit VestingPeriodsNumberUpdated(_vestingPeriods);
    }
}
