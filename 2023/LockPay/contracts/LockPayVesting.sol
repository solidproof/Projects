pragma solidity 0.8.4;

import "./libraries/TransferHelper.sol";
import './libraries/VestingMathLibrary.sol';
import './libraries/FullMath.sol';

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Adminable.sol";
import './interfaces/ILockPayGenerator.sol';
import './interfaces/ILockPaySettings.sol';
import './interfaces/IMigrator.sol';

contract LockPayVesting is Ownable, ReentrancyGuard, Adminable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint;

    struct TokenLock {
        uint256 sharesDeposited; // the total amount of shares deposited
        uint256 sharesWithdrawn; // amount of shares withdrawn
        uint256 startEmission; // date token emission begins
        uint256 endEmission; // the date the tokens can be withdrawn
        uint256 lockID; // lock id per token lock
        address owner; // the owner who can edit or withdraw the lock
        address condition; // address(0) = no condition, otherwise the condition contract must implement IUnlockCondition
        bool refunded;
    }

    struct LockParams {
        address payable owner; // the user who can withdraw tokens once the lock expires.
        uint256 durationId; // amount of tokens to lock
        address condition; // address(0) = no condition, otherwise the condition must implement IUnlockCondition
    }

    struct PlansParams {
        uint256 duration;
        uint256 amount;
        bool isPercentage;
    }

    struct Settings {
        string name;
        uint256 earlyWithdrawPenalty;
        uint256 maxWithdrawPercentage; // With 2 decimals
        address beneficiaryAddress;
        address stakingAddress;
        string stakingSignature;
        bool canAddDuration;
        bool canUpdateBeneficiary;
        bool canUpdateStaking;
        bool isStakable;
        bool isRelockable;
        bool initialized;
    }

    struct RefundParams {
        address refundWallet;
        uint256 maxRefundPercentage;
        bool withoutPenalty;
    }

    uint256 constant MIN_WITHDRAW_PERCENTAGE = 6000; // 60% (with 2 decimals)
    uint256 constant MAX_PLANS_DURATION = 2 * 365 * 24 * 60 * 60; // 2 years

    RefundParams public refundSettings;
    Settings public settings;
    ILockPayGenerator public generator;
    address public referrer;
    address private token; // list of all unique tokens that have a lock
    mapping(uint256 => TokenLock) public locks; // map lockID nonce to the lock
    uint256 public NONCE = 0; // incremental lock nonce counter, this is the unique ID for the next lock
    uint256 public MINIMUM_DEPOSIT = 100; // minimum divisibility per lock at time of locking
    uint public shares; // map token to number of shares per token, shares allow rebasing and deflationary tokens to compute correctly

    mapping(address => uint256[]) private users;
    PlansParams[] private durations;

    EnumerableSet.AddressSet private whitelistedUsers; // Tokens that have been whitelisted to bypass all fees

    IMigrator public migrator;
    bool public paused;

    modifier onlyGenerator {
        require(address(generator) == msg.sender, "LockPay: FORBIDDEN");
        _;
    }

    modifier notPaused {
        require(!paused, "LockPay: PAUSED");
        _;
    }

    event onLock(uint256 lockID, address token, address owner, uint256 amountInTokens, uint256 startEmission, uint256 endEmission);
    event onWithdraw(address token, uint256 amountInTokens);
    event onRefund(address token, uint256 amountInTokens);
    event onRelock(uint256 lockID, uint256 unlockDate);
    event onTransferLock(uint256 lockIDFrom, uint256 lockIDto, address oldOwner, address newOwner);
    event onSplitLock(uint256 fromLockID, uint256 toLockID, uint256 amountInTokens);
    event onMigrate(uint256 lockID, uint256 amountInTokens);
    event onUpdateBeneficiary(address indexed oldBeneficiary, address indexed newBeneficiary);
    event onUpdateStaking(address indexed oldStakingAddress, address indexed newStakingAddress);

    // @todo: add events
    constructor (address _generator, address _admin, address _token) Adminable(_admin) {
        generator = ILockPayGenerator(_generator);
        token = _token;
    }

    /**
    * @notice LockPay Generator would call this function to initialize the locker and add Locker information
    * to states. This function would be callable only through Generator.
    * @param _name The Locker name
    * @param _earlyWithdrawPenalty Early withdraw penalty percentage (with 2 decimals)
    * @param _maxWithdrawPercentage Maximum withdraw percentage (with 2 decimals). This value must be more than 60%.
    * @param _beneficiaryAddress Beneficiary address. Pass address(0) to disable this parameter.
    * @param _stakingAddress Staking address. Pass address(0) to disable this parameter.
    * @param _stakingSignature The Staking contract call signature for delegation call.
    * @param _canAddDuration Boolean flag for adding new locker duration after generating locker.
    * @param _canUpdateBeneficiary Boolean flag for updating beneficiary address after generating locker.
    * @param _canUpdateStaking Boolean flag for updating staking contract address after generating locker.
    * @param _isStakable Is Stakable.
    * @param _isRelockable Flag for allowing lockers to relock their deposits.
    */
    function init(
        string memory _name,
        uint256 _earlyWithdrawPenalty,
        uint256 _maxWithdrawPercentage,
        address _beneficiaryAddress,
        address _stakingAddress,
        string memory _stakingSignature,
        bool _canAddDuration,
        bool _canUpdateBeneficiary,
        bool _canUpdateStaking,
        bool _isStakable,
        bool _isRelockable
    ) external onlyGenerator {
        require(!settings.initialized, "LockPay: ALREADY_INITALIZED");
        require(_maxWithdrawPercentage >= MIN_WITHDRAW_PERCENTAGE, "LockPay: INVALID_MAX_WITHDRAW");
        if(_isStakable) {
            require(_stakingAddress != address(0), "LockPay: INVALID_STAKING");
        }

        settings.name = _name;
        settings.earlyWithdrawPenalty = _earlyWithdrawPenalty;
        settings.maxWithdrawPercentage = _maxWithdrawPercentage;
        settings.beneficiaryAddress = _beneficiaryAddress;
        settings.stakingAddress = _stakingAddress;
        settings.stakingSignature = _stakingSignature;
        settings.canAddDuration = _canAddDuration;
        settings.canUpdateBeneficiary = _canUpdateBeneficiary;
        settings.canUpdateStaking = _canUpdateStaking;
        settings.isStakable = _isStakable;
        settings.isRelockable = _isRelockable;
        settings.initialized = true;
    }

    /**
    * @notice Generator adds locking durations. Only Generator is allowed to call this function.
    * @param _duration New lock duration
    * @param _amount New Lock deposit amount.
    * @param _isPercentage Is the lock deposit amount a percentage of user balance or exact amount.
    */
    function addDuration(
        uint256 _duration,
        uint256 _amount,
        bool _isPercentage
    ) external onlyOwner {
        require(settings.canAddDuration, "LockPay: NOT_ALLOWED");
        require(settings.initialized, "LockPay: NOT_INITALIZED");
        require(_duration > 3600, "LockPay: INVALID_DURATION"); // An hour
        require(_duration <= MAX_PLANS_DURATION, 'LockPay: TIMESTAMP_INVALID');
        require(_duration < 1e10, 'LockPay: TIMESTAMP_INVALID'); // prevents errors when timestamp entered in milliseconds
        require(_amount > 1000, "LockPay: INVALID_DURATION_AMOUNT");
        durations.push(
            PlansParams(_duration, _amount, _isPercentage)
        );
    }

    /**
    * @notice Owner would be able to add new locking duration.
    * @param _duration New lock duration
    * @param _amount New Lock deposit amount.
    * @param _isPercentage Is the lock deposit amount a percentage of user balance or exact amount.
    */
    function createDurations(
        uint256 _duration,
        uint256 _amount,
        bool _isPercentage
    ) external onlyGenerator {
        require(settings.initialized, "LockPay: NOT_INITALIZED");
        require(_duration > 3600, "LockPay: INVALID_DURATION"); // An hour
        require(_duration <= MAX_PLANS_DURATION, 'LockPay: TIMESTAMP_INVALID');
        require(_duration < 1e10, 'LockPay: TIMESTAMP_INVALID'); // prevents errors when timestamp entered in milliseconds
        require(_amount > 1000, "LockPay: INVALID_DURATION_AMOUNT");
        durations.push(
            PlansParams(_duration, _amount, _isPercentage)
        );
    }

    /**
    * @notice Owner can update locker settings. Only owner allowed to call this function.
    * @param _name New locker name
    * @param _earlyWithdrawPenalty Early withdraw penalty percentage (with 2 decimals)
    * @param _maxWithdrawPercentage Maximum withdraw percentage (with 2 decimals). This value must be more than 60%.
    * @param _isStakable Is Stakable.
    * @param _isRelockable Flag for allowing lockers to relock their deposits.
    */
    function updateSettings(
        string memory _name,
        uint256 _earlyWithdrawPenalty,
        uint256 _maxWithdrawPercentage,
        bool _isStakable,
        bool _isRelockable
    ) external onlyOwnerOrAdmin {
        require(_maxWithdrawPercentage >= MIN_WITHDRAW_PERCENTAGE, "LockPay: INVALID_MAX_WITHDRAW");
        require(_earlyWithdrawPenalty <= 2500, "LockPay: INVALID_PENALTY");

        settings.name = _name;
        settings.earlyWithdrawPenalty = _earlyWithdrawPenalty;
        settings.maxWithdrawPercentage = _maxWithdrawPercentage;
        settings.isStakable = _isStakable;
        settings.isRelockable = _isRelockable;
    }

    /**
    * @notice Updates the beneficiary address. Reverts if canUpdateBeneficiary == false. Only owner allowed to call this function.
    * @param _beneficiaryAddress New Beneficiary address.
    */
    function updateBeneficiaryAddress(address _beneficiaryAddress) external onlyOwner {
        require(settings.canUpdateBeneficiary, "LockPay: NOT_ALLOWED");
        require(_beneficiaryAddress != address(0), "LockPay: INVALID_ADDRESS");
        require(_beneficiaryAddress != settings.beneficiaryAddress, "LockPay: SELF");

        emit onUpdateBeneficiary(settings.beneficiaryAddress, _beneficiaryAddress);
        settings.beneficiaryAddress = _beneficiaryAddress;
    }

    /**
    * @notice Updates the Staking address. Reverts if canUpdateStaking == false. Only owner allowed to call this function.
    * @param _stakingAddress New Staking address.
    */
    function updateStakingAddress(address _stakingAddress) external onlyOwner {
        require(settings.canUpdateStaking, "LockPay: NOT_ALLOWED");
        require(settings.isStakable, "LockPay: NOT_STAKABLE");
        require(_stakingAddress != address(0), "LockPay: INVALID_ADDRESS");
        require(_stakingAddress != settings.stakingAddress, "LockPay: SELF");

        emit onUpdateStaking(settings.stakingAddress, _stakingAddress);
        settings.stakingAddress = _stakingAddress;
    }

    /**
    * @notice Updates the Locker Fees. Fees amount are capped to 25%.
    * @param _lockFee Lock Fee (with 2 decimals)
    * @param _relockFee Relock Fee (with 2 decimals)
    * @param _referralFee Referral Fee (with 2 decimals)
    */
    function updateFees(
        uint256 _lockFee,
        uint256 _relockFee,
        uint256 _referralFee
    ) external onlyOwner {
        require(_lockFee <= 2500, "LockPay: INVALID_FEE");
        require(_relockFee <= 2500, "LockPay: INVALID_FEE");
        require(_referralFee <= 2500, "LockPay: INVALID_FEE");

        ILockPaySettings(generator.settings()).updateLockerFees(_lockFee, _relockFee, _referralFee);
    }

    /**
    * @notice Toggles pause flag. Only owner allowed to call.
    * @param _paused New Paused flag
    */
    function togglePaused(bool _paused) external onlyOwnerOrAdmin {
        paused = _paused;
    }

    /**
    * @notice Setup the refund settings after initialization event. Generator calls this function during creating locker.
    * @param _refundWallet Refund wallet address.
    * @param _maxRefundPercentage Max refund percentage
    * @param _withoutPenalty Boolean flag for taking penalty on refund.
    */
    function setRefundSettings(
        address _refundWallet,
        uint256 _maxRefundPercentage,
        bool _withoutPenalty
    ) external onlyGenerator {
        require(settings.initialized, "LockPay: NOT_INITALIZED");
        require(_refundWallet != address(0), "LockPay: INVALID_ADDRESS");
        refundSettings = RefundParams(
            _refundWallet,
            _maxRefundPercentage,
            _withoutPenalty
        );
    }

    /**
    * @notice Updates the refund settings after initialization event. 
    * @param _refundWallet New Refund wallet address.
    * @param _maxRefundPercentage Max refund percentage
    * @param _withoutPenalty Boolean flag for taking penalty on refund.
    */
    function updateRefundSettings(
        address _refundWallet,
        uint256 _maxRefundPercentage,
        bool _withoutPenalty
    ) external onlyOwnerOrAdmin {
        require(settings.initialized, "LockPay: NOT_INITALIZED");
        refundSettings = RefundParams(
            _refundWallet,
            _maxRefundPercentage,
            _withoutPenalty
        );
    }

    /**
    * @notice Add referral addresses. Generator calls this function during creating locker.
    * @param _referralAddress Referral wallet address.
    */
    function addReferral(
        address _referralAddress
    ) external onlyGenerator {
        require(settings.initialized, "LockPay: NOT_INITALIZED");
        require(_referralAddress != address(0), "LockPay: INVALID_REFERRAL");

        referrer = _referralAddress;
    }

    /**
     * @notice set the migrator contract which allows the lock to be migrated
     */
    function setMigrator(IMigrator _migrator) external onlyOwner {
        migrator = _migrator;
    }

    /**
     * @notice whitelisted accounts and contracts
     */
    function adminSetWhitelistedUsers(address _user, bool _add) external onlyOwner {
        if (_add) {
            whitelistedUsers.add(_user);
        } else {
            whitelistedUsers.remove(_user);
        }
    }

    /**
     * @notice Creates one or multiple locks for the specified token
     * @param _lock_params an array of locks with format: [LockParams[owner, amount, startEmission, endEmission, condition]]
     * owner: user or contract who can withdraw the tokens
     * amount: must be >= 100 units
     * startEmission = 0 : LockType 1
     * startEmission != 0 : LockType 2 (linear scaling lock)
     * use address(0) for no premature unlocking condition
     * Fails if startEmission is not less than EndEmission
     * Fails is amount < 100
     */
    function lock (LockParams calldata _lock_params) external notPaused nonReentrant {
        require(durations[_lock_params.durationId].amount > 0, "LockPay: INVALID_DURATION");
        PlansParams memory duration = durations[_lock_params.durationId];

        uint256 totalAmount = 0;
        if(duration.isPercentage) {
            uint256 senderBalance = IERC20(token).balanceOf(address(msg.sender));
            totalAmount = FullMath.mulDiv(senderBalance, duration.amount, 10000);
        } else {
            totalAmount = duration.amount;
        }

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransferFrom(token, address(msg.sender), address(this), totalAmount);
        uint256 amountIn = IERC20(token).balanceOf(address(this)) - balanceBefore;

        // Fees
        if (!whitelistedUsers.contains(_msgSender())) {
            (uint256 _lockFee,, uint256 _referralFee, uint256 _lockAdminFee,,, address _beneficiary) = generator.getFees(address(this));
            uint256 lockFeeAmount = FullMath.mulDiv(amountIn, _lockFee, 10000);
            TransferHelper.safeTransfer(token, _beneficiary, lockFeeAmount);
            amountIn -= lockFeeAmount;

            if(_lockAdminFee > 0) {
                uint256 lockAdminFeeAmount = FullMath.mulDiv(amountIn, _lockAdminFee, 10000);
                TransferHelper.safeTransfer(token, admin, lockAdminFeeAmount);
                amountIn -= lockAdminFeeAmount;
            }

            if(referrer != address(0)) {
                uint256 referrerFeeAmount = FullMath.mulDiv(amountIn, _referralFee, 10000);
                TransferHelper.safeTransfer(token, referrer, referrerFeeAmount);
                amountIn -= referrerFeeAmount;
            }
        }

        uint256 _shares = 0;
        require(amountIn >= MINIMUM_DEPOSIT, 'LockPay: MIN_DEPOSIT');

        if (shares == 0) {
            _shares = amountIn;
        } else {
            _shares = FullMath.mulDiv(amountIn, shares, balanceBefore == 0 ? 1 : balanceBefore);
        }
        require(_shares > 0, 'LockPay: SHARES');
        shares += _shares;

        TokenLock memory token_lock;
        token_lock.sharesDeposited = _shares;
        token_lock.startEmission = 0;
        token_lock.endEmission = block.timestamp.add(duration.duration);
        token_lock.lockID = NONCE;
        token_lock.owner = _lock_params.owner;
        if (_lock_params.condition != address(0)) {
            // if the condition contract does not implement the interface and return a bool
            // the below line will fail and revert the tx as the conditional contract is invalid
            IUnlockCondition(_lock_params.condition).unlockTokens();
            token_lock.condition = _lock_params.condition;
        }

        // record the lock globally
        locks[NONCE] = token_lock;

        // record the lock for the user
        users[_lock_params.owner].push(NONCE);

        NONCE ++;
        emit onLock(token_lock.lockID, token, token_lock.owner, amountIn, token_lock.startEmission, token_lock.endEmission);
    }

    /**
    * @notice withdraw a specified amount from a lock. _amount is the ideal amount to be withdrawn.
    * however, this amount might be slightly different in rebasing tokens due to the conversion to shares,
    * then back into an amount
    * @param _lockID the lockID of the lock to be withdrawn
    * @param _amount amount of tokens to withdraw
    */
    function withdraw (uint256 _lockID, uint256 _amount) external nonReentrant {
        TokenLock storage userLock = locks[_lockID];
        require(userLock.owner == msg.sender, 'LockPay: OWNER');
        // convert _amount to its representation in shares
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 shareDebit = FullMath.mulDiv(shares, _amount, balance);
        // round _amount up to the nearest whole share if the amount of tokens specified does not translate to
        // at least 1 share.
        if (shareDebit == 0 && _amount > 0) {
            shareDebit ++;
        }
        require(shareDebit > 0, 'LockPay: ZERO_WITHDRAWL');
        uint256 withdrawableShares = getWithdrawableShares(userLock.lockID);
        // dust clearance block, as mulDiv rounds down leaving one share stuck, clear all shares for dust amounts
        if (shareDebit + 1 == withdrawableShares) {
            if (FullMath.mulDiv(shares, balance / shares, balance) == 0){
                shareDebit++;
            }
        }
        uint256 remainingShare = userLock.sharesDeposited - userLock.sharesWithdrawn;
        require(shareDebit <= remainingShare, 'LockPay: AMOUNT');
        uint256 penaltyShare = 0;
        if(shareDebit > withdrawableShares) {
            // Take penalty for early withdraw
            require(settings.earlyWithdrawPenalty > 0, "LockPay: NOT_ALLOWED");

            penaltyShare = FullMath.mulDiv(shareDebit, settings.earlyWithdrawPenalty, 10000);
        }

        userLock.sharesWithdrawn += shareDebit;

        uint256 withdrawnPercentage = FullMath.mulDiv(userLock.sharesWithdrawn, 10000, userLock.sharesDeposited);
        require(withdrawnPercentage <= settings.maxWithdrawPercentage, "LockPay: EXCEEDED_LIMIT");

        shares -= shareDebit;
        shareDebit -= penaltyShare;
        // now convert shares to the actual _amount it represents, this may differ slightly from the
        // _amount supplied in this methods arguments.
        uint256 amountInTokens = FullMath.mulDiv(shareDebit, balance, shares);
        uint256 penaltyInTokens = FullMath.mulDiv(penaltyShare, balance, shares);

        TransferHelper.safeTransfer(token, admin, penaltyInTokens);
        if(settings.beneficiaryAddress != address(0)) {
            TransferHelper.safeTransfer(token, settings.beneficiaryAddress, amountInTokens);
        } else {
            TransferHelper.safeTransfer(token, msg.sender, amountInTokens);
        }

        emit onWithdraw(token, amountInTokens);
    }

    /**
    * @notice refund a lock. _amount is the ideal amount to be refunded.
    * however, this amount might be slightly different in rebasing tokens due to the conversion to shares,
    * then back into an amount
    * @param _lockID the lockID of the lock to be refunded
    * @param _amount amount of tokens to refund
    */
    function refund(uint256 _lockID, uint256 _amount) external nonReentrant {
        require(refundSettings.refundWallet == msg.sender, 'LockPay: NOT_ALLOWED');
        TokenLock storage userLock = locks[_lockID];
        require(!userLock.refunded, "LockPay: REFUNDED");
        // convert _amount to its representation in shares
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 shareDebit = FullMath.mulDiv(shares, _amount, balance);
        // round _amount up to the nearest whole share if the amount of tokens specified does not translate to
        // at least 1 share.
        if (shareDebit == 0 && _amount > 0) {
            shareDebit ++;
        }
        require(shareDebit > 0, 'LockPay: ZERO_WITHDRAWL');
        uint256 withdrawableShares = getWithdrawableShares(userLock.lockID);
        // dust clearance block, as mulDiv rounds down leaving one share stuck, clear all shares for dust amounts
        if (shareDebit + 1 == withdrawableShares) {
            if (FullMath.mulDiv(shares, balance / shares, balance) == 0){
                shareDebit++;
            }
        }
        uint256 remainingShare = userLock.sharesDeposited - userLock.sharesWithdrawn;
        require(shareDebit <= remainingShare, 'LockPay: AMOUNT');
        uint256 remainingSharePercentage = FullMath.mulDiv(userLock.sharesDeposited, refundSettings.maxRefundPercentage, 10000);
        require(shareDebit <= remainingSharePercentage, 'LockPay: INVALID_AMOUNT');

        uint256 penaltyShare = 0;
        if(!refundSettings.withoutPenalty) {
            penaltyShare = FullMath.mulDiv(shareDebit, settings.earlyWithdrawPenalty, 10000);
        }

        userLock.sharesWithdrawn += shareDebit;
        userLock.refunded = true;

        shares -= shareDebit;
        shareDebit -= penaltyShare;
        // now convert shares to the actual _amount it represents, this may differ slightly from the
        // _amount supplied in this methods arguments.
        uint256 amountInTokens = FullMath.mulDiv(shareDebit, balance, shares);
        uint256 penaltyInTokens = FullMath.mulDiv(penaltyShare, balance, shares);

        TransferHelper.safeTransfer(token, admin, penaltyInTokens);
        if(settings.beneficiaryAddress != address(0)) {
            TransferHelper.safeTransfer(token, settings.beneficiaryAddress, amountInTokens);
        } else {
            TransferHelper.safeTransfer(token, msg.sender, amountInTokens);
        }

        emit onRefund(token, amountInTokens);
    }

    /**
     * @notice extend a lock with a new unlock date, if lock is Type 2 it extends the emission end date
    */
    function relock (uint256 _lockID, uint256 _durationId) external notPaused nonReentrant {
        require(settings.isRelockable, "LockPay: NOT_SUPPORTED");
        PlansParams memory duration = durations[_durationId];
        require(duration.amount > 0, "LockPay: INVALID_DURATION");
        TokenLock storage userLock = locks[_lockID];
        require(userLock.owner == msg.sender, 'LockPay: OWNER');
        require(userLock.endEmission >= block.timestamp, 'LockPay: NOT_ENDED');

        // Fees
        if (!whitelistedUsers.contains(_msgSender())) {
            (, uint256 _relockFee, uint256 _referralFee,, uint256 _relockAdminFee,, address _beneficiary) = generator.getFees(address(this));
            uint256 remainingShares = userLock.sharesDeposited - userLock.sharesWithdrawn;
            uint256 feeInShares = FullMath.mulDiv(remainingShares, _relockFee, 10000);

            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 feeInTokens = FullMath.mulDiv(feeInShares, balance, shares == 0 ? 1 : shares);

            TransferHelper.safeTransfer(token, _beneficiary, feeInTokens);

            if(_relockAdminFee > 0) {
                uint256 feeAdminInShares = FullMath.mulDiv(remainingShares, _relockAdminFee, 10000);
                uint256 feeAdminInTokens = FullMath.mulDiv(feeAdminInShares, balance, shares == 0 ? 1 : shares);
                TransferHelper.safeTransfer(token, admin, feeAdminInTokens);

                userLock.sharesWithdrawn += feeAdminInShares;
                shares -= feeAdminInShares;
            }

            if(referrer != address(0)) {
                uint256 feeReferralInShares = FullMath.mulDiv(remainingShares, _referralFee, 10000);

                balance = IERC20(token).balanceOf(address(this));
                uint256 feeReferralInTokens = FullMath.mulDiv(feeReferralInShares, balance, shares == 0 ? 1 : shares);

                TransferHelper.safeTransfer(token, referrer, feeReferralInTokens);

                userLock.sharesWithdrawn += feeReferralInTokens;
                shares -= feeReferralInTokens;
            }

            userLock.sharesWithdrawn += feeInShares;
            shares -= feeInShares;
        }

        userLock.endEmission = block.timestamp + duration.duration;
        emit onRelock(_lockID, userLock.endEmission);
    }

    /**
     * @notice transfer a lock to a new owner, e.g. presale project -> project owner
     * Please be aware this generates a new lock, and nulls the old lock, so a new ID is assigned to the new lock.
     */
    function transferLockOwnership (uint256 _lockID, address payable _newOwner) external notPaused nonReentrant {
        require(msg.sender != _newOwner, 'LockPay: SELF');
        TokenLock storage transferredLock = locks[_lockID];
        require(transferredLock.owner == msg.sender, 'LockPay: OWNER');

        TokenLock memory token_lock;
        token_lock.sharesDeposited = transferredLock.sharesDeposited;
        token_lock.sharesWithdrawn = transferredLock.sharesWithdrawn;
        token_lock.startEmission = transferredLock.startEmission;
        token_lock.endEmission = transferredLock.endEmission;
        token_lock.lockID = NONCE;
        token_lock.owner = _newOwner;
        token_lock.condition = transferredLock.condition;

        // record the lock globally
        locks[NONCE] = token_lock;

        // record the lock for the new owner
        users[_newOwner].push(token_lock.lockID);
        NONCE ++;

        // zero the lock from the old owner
        transferredLock.sharesWithdrawn = transferredLock.sharesDeposited;
        emit onTransferLock(_lockID, token_lock.lockID, msg.sender, _newOwner);
    }

    /**
     * @notice split a lock into two seperate locks, useful when a lock is about to expire and youd like to relock a portion
    * and withdraw a smaller portion
    * Only works on lock type 1, this feature does not work with lock type 2
    * @param _amount the amount in tokens
    */
    function splitLock (uint256 _lockID, uint256 _amount) external nonReentrant {
        require(_amount > 0, 'LockPay: ZERO AMOUNT');
        TokenLock storage userLock = locks[_lockID];
        require(userLock.owner == msg.sender, 'LockPay: OWNER');
        require(userLock.startEmission == 0, 'LockPay: LOCK TYPE 2');

        // convert _amount to its representation in shares
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountInShares = FullMath.mulDiv(shares, _amount, balance);

        require(userLock.sharesWithdrawn + amountInShares <= userLock.sharesDeposited);

        TokenLock memory token_lock;
        token_lock.sharesDeposited = amountInShares;
        token_lock.endEmission = userLock.endEmission;
        token_lock.lockID = NONCE;
        token_lock.owner = msg.sender;
        token_lock.condition = userLock.condition;

        // debit previous lock
        userLock.sharesWithdrawn += amountInShares;

        // record the new lock globally
        locks[NONCE] = token_lock;

        // record the new lock for the owner
        users[msg.sender].push(token_lock.lockID);
        NONCE ++;
        emit onSplitLock(_lockID, token_lock.lockID, _amount);
    }

    /**
     * @notice migrates to the next locker version, only callable by lock owners
     */
    function migrate (uint256 _lockID, uint256 _option) external nonReentrant {
        require(address(migrator) != address(0), "LockPay: NOT SET");
        TokenLock storage userLock = locks[_lockID];
        require(userLock.owner == msg.sender, 'LockPay: OWNER');
        uint256 sharesAvailable = userLock.sharesDeposited - userLock.sharesWithdrawn;
        require(sharesAvailable > 0, 'LockPay: AMOUNT');

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountInTokens = FullMath.mulDiv(sharesAvailable, balance, shares);

        TransferHelper.safeApprove(token, address(migrator), amountInTokens);
        migrator.migrate(token, userLock.sharesDeposited, userLock.sharesWithdrawn, userLock.startEmission,
            userLock.endEmission, userLock.lockID, userLock.owner, userLock.condition, amountInTokens, _option);

        userLock.sharesWithdrawn = userLock.sharesDeposited;
        shares -= sharesAvailable;
        emit onMigrate(_lockID, amountInTokens);
    }

    /**
     * @notice premature unlock conditions can be malicous (prevent withdrawls by failing to evalaute or return non bools)
    * or not give community enough insurance tokens will remain locked until the end date, in such a case, it can be revoked
    */
    function revokeCondition (uint256 _lockID) external nonReentrant {
        TokenLock storage userLock = locks[_lockID];
        require(userLock.owner == msg.sender, 'LockPay: OWNER');
        require(userLock.condition != address(0)); // already set to address(0)
        userLock.condition = address(0);
    }

    // test a condition on front end, added here for convenience in UI, returns unlockTokens() bool, or fails
    function testCondition (address condition) external view returns (bool) {
        return (IUnlockCondition(condition).unlockTokens());
    }

    // returns withdrawable share amount from the lock, taking into consideration start and end emission
    function getWithdrawableShares (uint256 _lockID) public view returns (uint256) {
        TokenLock storage userLock = locks[_lockID];
        uint8 lockType = userLock.startEmission == 0 ? 1 : 2;
        uint256 amount = lockType == 1 ? userLock.sharesDeposited - userLock.sharesWithdrawn : userLock.sharesDeposited;
        uint256 withdrawable;
        withdrawable = VestingMathLibrary.getWithdrawableAmount (
            userLock.startEmission,
            userLock.endEmission,
            amount,
            block.timestamp,
            userLock.condition
        );
        if (lockType == 2) {
            withdrawable -= userLock.sharesWithdrawn;
        }
        return withdrawable;
    }

    // convenience function for UI, converts shares to the current amount in tokens
    function getWithdrawableTokens (uint256 _lockID) external view returns (uint256) {
        TokenLock storage userLock = locks[_lockID];
        uint256 withdrawableShares = getWithdrawableShares(userLock.lockID);
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 amountTokens = FullMath.mulDiv(withdrawableShares, balance, shares == 0 ? 1 : shares);
        return amountTokens;
    }

    // For UI use
    function convertSharesToTokens (uint256 _shares) external view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        return FullMath.mulDiv(_shares, balance, shares);
    }

    function convertTokensToShares (uint256 _tokens) external view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        return FullMath.mulDiv(shares, _tokens, balance);
    }

    // For use in UI, returns more useful lock Data than just querying LOCKS,
    // such as the real-time token amount representation of a locks shares
    function getLock (uint256 _lockID) external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256, address, address) {
        TokenLock memory tokenLock = locks[_lockID];

        uint256 stakedAmount = 0;
        if(settings.isStakable) {
            (bool success, bytes memory data) = settings.stakingAddress.staticcall(abi.encodeWithSignature(settings.stakingSignature, tokenLock.owner));

            if(success) {
                stakedAmount = abi.decode(data, (uint256));
            }
        }

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 totalSharesOr1 = shares == 0 ? 1 : shares;
        // tokens deposited and tokens withdrawn is provided for convenience in UI, with rebasing these amounts will change
        uint256 tokensDeposited = FullMath.mulDiv(tokenLock.sharesDeposited, balance, totalSharesOr1);
        uint256 tokensWithdrawn = FullMath.mulDiv(tokenLock.sharesWithdrawn, balance, totalSharesOr1);
        return (tokenLock.lockID, stakedAmount, tokensDeposited, tokensWithdrawn, tokenLock.sharesDeposited, tokenLock.sharesWithdrawn, tokenLock.startEmission, tokenLock.endEmission,
        tokenLock.owner, tokenLock.condition);
    }

    function getToken () external view returns (address) {
        return token;
    }

    function getLocksLength () external view returns (uint256) {
        return NONCE;
    }

    function getTokenLockIDAtIndex (uint256 _index) external view returns (TokenLock memory) {
        return locks[_index];
    }

    // user functions
    function getUserLockedTokensLength (address _user) external view returns (uint256) {
        return users[_user].length;
    }

    function getUserLockIDForTokenAtIndex (address _user, uint256 _index) external view returns (uint256) {
        return users[_user][_index];
    }

    // whitelist
    function getWhitelistedLength () external view returns (uint256) {
        return whitelistedUsers.length();
    }

    function getWhitelistedAtIndex (uint256 _index) external view returns (address) {
        return whitelistedUsers.at(_index);
    }

    function getWhitelistedStatus (address _user) external view returns (bool) {
        return whitelistedUsers.contains(_user);
    }
}
