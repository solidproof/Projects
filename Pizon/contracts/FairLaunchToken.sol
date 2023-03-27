// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

library LPercentage {
    using SafeMath for uint;
    uint constant public DEMI = 10000;

    function validatePercent(
        uint percent_
    )
        internal
        pure
    {
        // 100% == DEMI == 10000
        require(percent_ <= DEMI, "invalid percent");
    }

    function getPercentA(
        uint value,
        uint percent
    )
        public
        pure
        returns(uint)
    {
        return value.mul(percent).div(DEMI);
    }
}

library LAmmDetector {
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    function gotFactory(
        address addr_
    )
        public
        view
        returns(bool)
    {
        if (!isContract(addr_)) {
            return false;
        }

        try IRouter(addr_).factory()
        {
            return true;
        } catch {
            return false;
        }  
    }

    function isRouter(
        address router_
    )
        public
        view
        returns(bool)
    {
        if (!gotFactory(router_)) {
            return false;
        }

        try IRouter(router_).WETH()
        {
            return true;
        } catch {
            return false;
        }
    }

    function isPair(
        address pair_
    )
        public
        view
        returns(bool)
    {
        if (!gotFactory(pair_)) {
            return false;
        }

        try IRouter(pair_).WETH()
        {
            return false;
        } catch {
            return true;
        }
    }
}

contract Lockable {
    using SafeMath for uint;
    using LAmmDetector for *;

    event SetLockPeriodByFrom(
        address indexed from,
        uint period
    );

    event SetDefaultLockPeriod(
        uint period
    );

    event UpdatingLockDataOf(
        address indexed account
    );

    event UpdateLockData(
        SLock lockData
    );

    event SetIsTaxerLocked(
        bool isTaxerLocked
    );

    event Unlocked(
        address indexed account,
        uint amount,
        UnlockType unlockType
    );

    struct SLock {
        uint updatedAt;
        uint amount;
        uint duration;
    }

    enum UnlockType{
        AS_REF,
        AS_CHILD,
        SELF,
        OTHER
    }

    mapping(address => SLock) private _lockDataOf;
    mapping(address => uint) private _lockPeriodByFrom;

    mapping(address => mapping(UnlockType => uint)) private _unlockedSumOf;

    SLock private _supplyLockData;

    uint private _defaultLockPeriod;
    bool private _isTaxerLocked;

    function _setLockPeriodByFrom(
        address from_,
        uint period_
    )
        internal
    {
        _lockPeriodByFrom[from_] = period_;
        emit SetLockPeriodByFrom(from_, period_);
    }

    function _setDefaultLockPeriod(
        uint defaultLockPeriod_
    )
        internal
    {
        _defaultLockPeriod = defaultLockPeriod_;
        emit SetDefaultLockPeriod(defaultLockPeriod_);
    }

    function _setIsTaxerLocked(
        bool isTaxerLocked_
    )
        internal
    {
        _isTaxerLocked = isTaxerLocked_;
        emit SetIsTaxerLocked(isTaxerLocked_);
    }

    function _restLockDuration(
        SLock memory lockData_
    )
        internal
        view
        returns(uint restLockDuration)
    {
        uint pastTime = block.timestamp.sub(lockData_.updatedAt);
        if (pastTime >= lockData_.duration) {
            restLockDuration = 0;
        } else {
            restLockDuration = lockData_.duration.sub(pastTime);
        }
    }

    function _lockedA(
        SLock memory lockData_
    )
        internal
        view
        returns(uint lockedA)
    {
        uint restLockDuration = _restLockDuration(lockData_);
        if (restLockDuration == 0) {
            lockedA = 0;
        } else {
            // lockData.duration >= restLockDuration > 0
            lockedA = restLockDuration.mul(lockData_.amount).div(lockData_.duration);
        }
    }
        
    function unlockedSumOf(
        address account_,
        UnlockType unlockType_
    )
        public
        view
        returns(uint)
    {
        return _unlockedSumOf[account_][unlockType_];
    }

    function lockDurationOf(
        address account_
    )
        public
        view
        returns(uint restLockDuration)
    {
        restLockDuration = _restLockDuration(_lockDataOf[account_]);
    }

    function lockedAOf(
        address account_
    )
        public
        view
        returns(uint lockedA)
    {
        lockedA = _lockedA(_lockDataOf[account_]);
    }

    function lockedSupply()
        public
        view
        returns(uint lockedA)
    {
        lockedA = _lockedA(_supplyLockData);
    }

    function _rebaseCurrentLockData(
        SLock storage lockData
    )
        internal
    {
        uint restLockDuration = _restLockDuration(lockData);
        if (restLockDuration == 0) {
            lockData.amount = 0;
            lockData.duration = 0;
            lockData.updatedAt = block.timestamp;
        } else {
            // lockData.duration >= restLockDuration > 0
            lockData.amount = restLockDuration.mul(lockData.amount).div(lockData.duration);
            lockData.duration = restLockDuration;
            lockData.updatedAt = block.timestamp;
        }
        emit UpdateLockData(lockData);
    }

    function _prolongLockdata(
        SLock storage lockData,
        uint amount_,
        uint duration_
    )
        internal
    {
        if (amount_ == 0 || duration_ == 0) {
            return;
        }
        _rebaseCurrentLockData(lockData);
    
        // (l * t + a * T) / (l + a);
        uint lt = lockData.amount.mul(lockData.duration);
        uint aT = amount_.mul(duration_);
        lockData.duration = (lt.add(aT)).div(lockData.amount.add(amount_));
        // lockData.duration = (lockData.amount * lockData.duration + amount_ * duration_) / (lockData.amount + amount_);
        lockData.amount = lockData.amount.add(amount_);
        lockData.updatedAt = block.timestamp;
        emit UpdateLockData(lockData);
    }

    function _unlockLockData(
        SLock storage lockData,
        uint amount_
    )
        internal
    {
        if (amount_ == 0) {
            return;
        }
        _rebaseCurrentLockData(lockData);
        uint amount = amount_ >= lockData.amount ? lockData.amount : amount_;
        uint restLockA = lockData.amount - amount;
        if (restLockA == 0) {
            lockData.duration = 0;
            lockData.amount = 0;
        } else {
            lockData.duration = lockData.duration.mul(restLockA).div(lockData.amount);
            lockData.amount = restLockA;
        }
        emit UpdateLockData(lockData);
    }

    function _unlock(
        address account_,
        uint amount_,
        UnlockType unlockType_
    )
        internal
    {
        if (amount_ == 0) {
            return;
        }

        emit UpdatingLockDataOf(account_);
        _unlockLockData(_lockDataOf[account_], amount_);

        emit UpdatingLockDataOf(address(0x0));
        _unlockLockData(_supplyLockData, amount_);

        _unlockedSumOf[account_][unlockType_] += amount_;
        emit Unlocked(account_, amount_, unlockType_);
    }

    function _lock(
        address account_,
        uint amount_,
        uint duration_
    )
        internal
        returns(bool success)
    {
        if (duration_ > 1) {
            emit UpdatingLockDataOf(account_);
            _prolongLockdata(_lockDataOf[account_], amount_, duration_);

            emit UpdatingLockDataOf(address(0x0));
            _prolongLockdata(_supplyLockData, amount_, duration_);
            success = true;
        } else {
            // nothing locked
            success = false;
        }
    }

    function defaultLockPeriod()
        public
        view
        returns(uint)
    {
        return _defaultLockPeriod;
    }

    function isTaxerLocked()
        public
        view
        returns(bool)
    {
        return _isTaxerLocked;
    }

    function lockPeriodByFrom(
        address from_
    )
        public
        view
        returns(uint)
    {
        if (_lockPeriodByFrom[from_] > 0) {
            return _lockPeriodByFrom[from_];
        } else 
        if (LAmmDetector.isPair(from_) || LAmmDetector.isRouter(from_)) {
            return _defaultLockPeriod;
        } else {
            return 0;
        }
    }

    function supplyLockData()
        public
        view
        returns(SLock memory)
    {
        return _supplyLockData;
    }

    function lockDataOf(
        address account_
    )
        public
        view
        returns(SLock memory)
    {
        return _lockDataOf[account_];
    }
}

contract TransferTax {
    using SafeMath for uint;

    event SetTax(
        uint buyTaxP,
        uint sellTaxP,
        uint transferTaxP,
        address indexed taxReceiver
    );

    event TaxIgnore(
        address indexed account,
        bool isTaxIgnored
    );

    event AddTotalTaxOf(
        address indexed account,
        uint totalTaxed
    );

    uint internal _buyTaxP;
    uint internal _sellTaxP;
    uint internal _transferTaxP;

    address internal _taxReceiver;

    mapping(address => bool) internal _isTaxIgnored;
    mapping(address => uint) internal _totalTaxOf;

    function _setTaxs(
        uint buyTaxP_,
        uint sellTaxP_,
        uint transferTaxP_,
        address taxReceiver_
    )
        internal
    {
        LPercentage.validatePercent(buyTaxP_);
        LPercentage.validatePercent(sellTaxP_);
        LPercentage.validatePercent(transferTaxP_);
        _buyTaxP = buyTaxP_;
        _sellTaxP = sellTaxP_;
        _transferTaxP = transferTaxP_;
        _taxReceiver = taxReceiver_;

        emit SetTax(buyTaxP_, sellTaxP_, transferTaxP_, taxReceiver_);
    }

    function _taxIgnore(
        address account_,
        bool isTaxIgnored_
    )
        internal
    {
        _isTaxIgnored[account_] = isTaxIgnored_;
        emit TaxIgnore(account_, isTaxIgnored_);
    }

    function _addTotalTaxOf(
        address account_,
        uint taxA_
    )
        internal
    {
        _totalTaxOf[account_] = _totalTaxOf[account_].add(taxA_);
        emit AddTotalTaxOf(account_, _totalTaxOf[account_]);
    }

    function isTaxIgnored(
        address account_
    )
        public
        view
        returns(bool)
    {
        return _isTaxIgnored[account_];
    }

    function totalTaxOf(
        address account_
    )
        public
        view
        returns(uint)
    {
        return _totalTaxOf[account_];
    }

    function getTaxs()
        public
        view
        returns(
            uint buyTaxP,
            uint sellTaxP,
            uint transferTaxP,
            address taxReceiver
        )
    {
        buyTaxP = _buyTaxP;
        sellTaxP = _sellTaxP;
        transferTaxP = _transferTaxP;
        taxReceiver = _taxReceiver;
    }
}

contract RefKing {
    address private _refKing;
    uint private _refKingBalance;

    uint private _refKingUnlockP;
    uint private _maxSelfUnlockP;

    event SetRefKingUnlockP(
        uint refKingUnlockP
    );

    event SetMaxSelfUnlockP(
        uint maxSelfUnlockP
    );

    event UpdateRefKing(
        address indexed refKing,
        uint balance
    );

    function _setRefKingUnlockP(
        uint refKingUnlockP_
    )
        internal
    {
        LPercentage.validatePercent(refKingUnlockP_);
        _refKingUnlockP = refKingUnlockP_;
        emit SetRefKingUnlockP(refKingUnlockP_);
    }

    function _setMaxSelfUnlockP(
        uint maxSelfUnlockP_
    )
        internal
    {
        LPercentage.validatePercent(maxSelfUnlockP_);
        _maxSelfUnlockP = maxSelfUnlockP_;
        emit SetMaxSelfUnlockP(maxSelfUnlockP_); 
    }

    function _updateRefKing(
        address account_,
        uint balance_
    )
        internal
    {
        if (account_ == address(0x0) || account_ == address(0xdead)) {
            return;
        }
        if (_refKing == account_) {
            _refKingBalance = balance_;
            emit UpdateRefKing(_refKing, _refKingBalance);
            return;
        }
        // ignore contracts
        if (LAmmDetector.isContract(account_)) {
            return;
        }
        if (balance_ > _refKingBalance) {
            _refKing = account_;
            _refKingBalance = balance_;
            emit UpdateRefKing(_refKing, _refKingBalance);
        }
    }

    function refKingUnlockP()
        public
        view
        returns(uint)
    {
        return _refKingUnlockP;
    }

    function maxSelfUnlockP()
        public
        view
        returns(uint)
    {
        return _maxSelfUnlockP;
    }

    function refKing()
        public
        view
        returns(address)
    {
        return _refKing;
    }

    function refKingBalance()
        public
        view
        returns(uint)
    {
        return _refKingBalance;
    }
}

contract Referral is RefKing {
    using SafeMath for uint;

    modifier onlyReferralManager() {
        require(msg.sender == _referralManager, "onlyReferralManager");
        _;
    }

    event ConfigWar(
        uint warDuration,
        uint expInterval,
        uint minRefInvValue
    );

    event SetReferralManager(
        address indexed referralManager
    );

    event SetReturnPOf(
        address indexed referrer,
        uint percent
    );

    event UpdateReferrer(
        address indexed referrer,
        address indexed child
    );

    struct SReferrer {
        address addr;
        uint invValue;
        uint updatedAt;
    }

    mapping(address => SReferrer) private _referrerOf;
    mapping(address => uint) private _totalChildren;

    mapping(address => uint) private _returnPOf;

    address private _referralManager;

    uint private _warDuration;
    uint private _expInterval;
    uint private _minRefInvValue;

    function _configWar(
        uint warDuration_,
        uint expInterval_,
        uint minRefInvValue_
    )
        internal
    {
        _warDuration = warDuration_;
        _expInterval = expInterval_;
        _minRefInvValue = minRefInvValue_;
        emit ConfigWar(warDuration_, expInterval_, minRefInvValue_);
    }

    function _setReferralManager(
        address referralManager_
    )
        internal
    {
        _referralManager = referralManager_;
        emit SetReferralManager(referralManager_);
    }

    function _setReturnPOf(
        address referrer_,
        uint percent_
    )
        internal
    {
        LPercentage.validatePercent(percent_);
        _returnPOf[referrer_] = percent_;
        emit SetReturnPOf(referrer_, percent_);
    }

    function warDuration()
        external
        view
        returns(uint)
    {
        return _warDuration;
    }

    function expInterval()
        external
        view
        returns(uint)
    {
        return _expInterval;
    }

    function requiredInvValue(
        address child_
    )
        public
        view
        returns(uint)
    {
        SReferrer memory referrer = _referrerOf[child_];
        if (referrer.addr == address(0x0)) {
            return _minRefInvValue;
        }
        uint pastTime = (block.timestamp - referrer.updatedAt);
        if (pastTime > _warDuration) {
            return ~uint(0);
        }

        uint exp = pastTime / _expInterval;
        return exp == 0 ? referrer.invValue + 1 : referrer.invValue.mul(1 << (exp));
    }

    function _updateReferrer(
        address from_,
        address to_,
        uint amount_
    )
        internal
    {
        // ignore contract
        if (
            LAmmDetector.isContract(from_)
            || LAmmDetector.isContract(to_)
            || from_ == address(0x0)
            )
        {
            return;
        }
        uint requiredValue = requiredInvValue(to_);
        if (amount_ >= requiredValue) {
            SReferrer storage referrer = _referrerOf[to_];
            address oldReferrerAccount = referrer.addr;
            referrer.addr = from_;
            referrer.invValue = amount_;
            referrer.updatedAt = block.timestamp;
            if (oldReferrerAccount != from_) {
                if (_totalChildren[oldReferrerAccount] > 0) {
                    _totalChildren[oldReferrerAccount]--;
                }
                _totalChildren[from_]++;
                emit UpdateReferrer(from_, to_);
            }
        }
    }

    function  _getKingBasedUnlockA(
        uint maxUnlockP_,
        uint targetBalance_,
        uint lockedA_
    )
        internal
        view
        returns(uint)
    {
        uint highestBalance = refKingBalance();
        if (highestBalance < targetBalance_) {
            highestBalance = targetBalance_;
        }
        uint unlockP = maxUnlockP_.mul(targetBalance_).div(highestBalance);
        return LPercentage.getPercentA(lockedA_, unlockP);     
    }

    function referrerUnlockA(
        uint referrerBalance_,
        uint lockedA_
    )
        public
        view
        returns(uint)
    {
        return _getKingBasedUnlockA(refKingUnlockP(), referrerBalance_, lockedA_);
    }

    function selfUnlockA(
        uint balance_,
        uint lockedA_
    )
        public
        view
        returns(uint)
    {
        return _getKingBasedUnlockA(maxSelfUnlockP(), balance_, lockedA_);
    }

    function referrerOf(
        address child_
    )
        public
        view
        returns(SReferrer memory referrer)
    {
        referrer = _referrerOf[child_];
    }

    function totalChildren(
        address referrer
    )
        public
        view
        returns(uint)
    {
        return _totalChildren[referrer];
    }

    function returnPOf(
        address referrer_
    )
        public
        view
        returns(uint)
    {
        return _returnPOf[referrer_];
    }

    function minRefInvValue()
        public
        view
        returns(uint)
    {
        return _minRefInvValue;
    }

    function referralManager()
        public
        view
        returns(address)
    {
        return _referralManager;
    }

    function setReturnP(
        uint percent_
    )
        external
    {
        _setReturnPOf(msg.sender, percent_);
    }

    function setReturnPWithManager(
        address referrer_,
        uint percent_
    )
        external
        onlyReferralManager
    {
        _setReturnPOf(referrer_, percent_);
    }
}

contract SecureApproval {
    modifier onlyValidApprDuration(
        uint apprDuration_
    )
    {
        require(apprDuration_ >= MIN_VALID_DURATION || apprDuration_ == 0, "onlyValidApprDuration");
        _;
    }

    event SetValidApprDuration(
        uint duration
    );

    mapping(address => mapping(address => uint)) private _lastApproval;

    uint private _apprDuration;
    uint constant public MIN_VALID_DURATION = 15 minutes;

    function _setValidApprDuration(
        uint apprDuration_
    )
        internal
        onlyValidApprDuration(apprDuration_)
    {
        _apprDuration = apprDuration_;
        emit SetValidApprDuration(apprDuration_);
    }

    function _beforeApprove(
        address owner_,
        address spender_
    )
        internal
    {
        _lastApproval[owner_][spender_] = block.timestamp;
    }

    function apprDuration()
        public
        view
        returns(uint)
    {
        return _apprDuration;
    }

    function lastApproval(
        address owner_,
        address spender_
    )
        public
        view
        returns(uint)
    {
        return _lastApproval[owner_][spender_];
    }

    function isApprovalExpired(
        address owner_,
        address spender_
    )
        public
        view
        returns(bool)
    {
        return
            _apprDuration != 0 &&
            uint(block.timestamp) - _lastApproval[owner_][spender_] > _apprDuration;
    }
}

interface ITokenCallback {
    function beforeTransferCallback(
        address from,
        address to,
        uint256 amount
    )
        external;

    function afterTransferCallback(
        address from,
        address to,
        uint256 amount
    )
        external;
}

contract CallbackableERC20 {
    mapping(uint => ITokenCallback) public beforeTransferTargets;
    mapping(uint => ITokenCallback) public afterTransferTargets;

    uint public totalBeforeTransferTargets;
    uint public totalAfterTransferTargets;

    function _setBeforeTransferTargets(
        ITokenCallback[] memory targets_
    )
        internal
    {
        uint n = targets_.length;
        if (n > 0) {
            for(uint i = 0; i < n; i++) {
                beforeTransferTargets[i] = targets_[i];
            }
        }
        totalBeforeTransferTargets = n;
    }

    function _setAfterTransferTargets(
        ITokenCallback[] memory targets_
    )
        internal
    {
        uint n = targets_.length;
        if (n > 0) {
            for(uint i = 0; i < n; i++) {
                afterTransferTargets[i] = targets_[i];
            }
        }
        totalAfterTransferTargets = n;
    }
}

contract Importable{
    modifier onlyNotDisabled()
    {
        require(!_isDisabled, "onlyNotDisabled");
        _;
    }

    bool private _isDisabled;

    mapping(address => bool) public isImported;
    uint public totalImported;

    FairLaunchToken immutable _prevToken;

    constructor (
        address prevTokenAddr_
    )
    {
        _prevToken = FairLaunchToken(prevTokenAddr_);
    }

    function _importAccount(
        address account_
    )
        internal
        onlyNotDisabled
        returns(bool success)
    {
        success = !isImported[account_];
        if (success) totalImported++;
        isImported[account_] = true;
    }

    function _disableImport()
        internal
    {
        _isDisabled = true;
    }
}

contract FairLaunchToken is 
    ERC20,
    Lockable,
    Ownable,
    TransferTax,
    Referral,
    SecureApproval,
    CallbackableERC20,
    Importable
{
    using SafeMath for uint;
    using LAmmDetector for *;

    // change bytecode easy without logic change
    string constant public VERSION = "mainnet-arbitrum-v2";

    constructor(
        string memory tokenName_,
        string memory tokenSymbol_,
        uint initSupplyInEther_,
        address prevTokenAddr_
    )
        ERC20(tokenName_, tokenSymbol_)
        Importable(prevTokenAddr_)
    {
        _mint(msg.sender, initSupplyInEther_ * 1e18);
    }

    /*
        owner's txs
    */

    function setDefaultLockPeriod(
        uint defaultLockPeriod_
    )
        external
        onlyOwner
    {
        _setDefaultLockPeriod(defaultLockPeriod_);
    }

    function setIsTaxerLocked(
        bool isTaxerLocked_
    )
        external
        onlyOwner
    {
        _setIsTaxerLocked(isTaxerLocked_);
    }

    function setLockPeriodByFrom(
        address from_,
        uint period_
    )
        external
        onlyOwner
    {
        _setLockPeriodByFrom(from_, period_);
    }

    function setTaxs(
        uint buyTaxP_,
        uint sellTaxP_,
        uint transferTaxP_,
        address taxReceiver_
    )
        external
        onlyOwner
    {
        _setTaxs(buyTaxP_, sellTaxP_, transferTaxP_, taxReceiver_);
    }

    function taxIgnore(
        address account_,
        bool isTaxIgnored_
    )
        external
        onlyOwner
    {
        _taxIgnore(account_, isTaxIgnored_);
    }

    function setRefKingUnlockP(
        uint refKingUnlockP_
    )
        external
        onlyOwner
    {
        _setRefKingUnlockP(refKingUnlockP_);
    }

    function setMaxSelfUnlockP(
        uint maxSelfUnlockP_
    )
        external
        onlyOwner
    {
        _setMaxSelfUnlockP(maxSelfUnlockP_);
    }

    function configWar(
        uint warDuration_,
        uint expInterval_,
        uint minRefInvValue_
    )
        external
        onlyOwner
    {
        _configWar(warDuration_, expInterval_, minRefInvValue_);
    }

    function setReferralManager(
        address referralManager_
    )
        external
        onlyOwner
    {
        _setReferralManager(referralManager_);
    }

    function lock(
        address account_,
        uint amount_,
        uint duration_
    )
        onlyOwner
        external
    {
        _lock(account_, amount_, duration_);
    }

    function unlock(
        address account_,
        uint amount_
    )
        onlyOwner
        external
    {
        _unlock(account_, amount_, UnlockType.OTHER);
    }

    function _handleTax(
        address from,
        address to,
        uint256 amount   
    )
        internal
        returns(uint)
    {
        if (_isTaxIgnored[from] || _isTaxIgnored[to]) {
            return amount;
        }
        uint taxP = _transferTaxP;
        if (LAmmDetector.isPair(to)) {
            taxP = _sellTaxP;
        } else
        if (LAmmDetector.isPair(from)) {
            taxP = _buyTaxP;
        }

        uint taxA = LPercentage.getPercentA(amount, taxP);
        _addTotalTaxOf(to, taxA);

        if (taxA > 0) {
            if (_taxReceiver == address(0x0)) {
                _burn(from, taxA);
            } else {
                super._transfer(from, _taxReceiver, taxA);
                if (isTaxerLocked()) {
                    _lock(_taxReceiver, taxA, lockPeriodByFrom(from));
                }
            }
        }

        return amount.sub(taxA);
    }

    function afterTransferCallback(
        address from,
        address to,
        uint256
    )
        external
    {
        _updateRefKing(from, super.balanceOf(from));
        _updateRefKing(to, super.balanceOf(to));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
    {
        uint n = totalBeforeTransferTargets;
        if (n > 0) {
            for(uint i = 0; i < n; i++) {
                beforeTransferTargets[i].beforeTransferCallback(from, to, amount);
            }
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
    {
        uint n = totalAfterTransferTargets;
        if (n > 0) {
            for(uint i = 0; i < n; i++) {
                afterTransferTargets[i].afterTransferCallback(from, to, amount);
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override
    {
        if (!LAmmDetector.isRouter(from)) {
            require(unlockedBalanceOf(from) >= amount, "not enough unlocked balance");
        }

        uint afterTaxA = _handleTax(from, to, amount);
        if (afterTaxA > 0) {
            _updateReferrer(from, to, afterTaxA);
            super._transfer(from, to, afterTaxA);
            bool lockedSuccess = _lock(to, afterTaxA, lockPeriodByFrom(from));
            if (lockedSuccess && !LAmmDetector.isContract(to)) {
                address referrer = referrerOf(to).addr;
                uint unlockA = referrerUnlockA(super.balanceOf(referrer), afterTaxA);
                uint childUnlockA = LPercentage.getPercentA(unlockA, returnPOf(referrer));
                uint referrerUnlockA = unlockA.sub(childUnlockA);
                _unlock(referrer, referrerUnlockA, UnlockType.AS_REF);
                _unlock(to, childUnlockA, UnlockType.AS_CHILD);

                uint selfUnlockA = selfUnlockA(super.balanceOf(to), afterTaxA);
                _unlock(to, selfUnlockA, UnlockType.SELF);
            }
        }
    }

    function unlockedBalanceOf(
        address account
    )
        public
        view
        returns (uint256)
    {
        return super.balanceOf(account).sub(lockedAOf(account));
    }

    function fullBalanceOf(
        address account
    )
        public
        view
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    /*
        sell problem
        uint amountInput = IERC20(input).balanceOf(address(pair)).sub(reserve0);
    */
    function balanceOf(
        address account
    )
        public
        view
        override
        returns (uint256)
    {
        // sender is not router
        if (!LAmmDetector.isRouter(msg.sender)) {
            return unlockedBalanceOf(account);
        }

        // sender is router

        if (account == msg.sender) {
            // router asks router's balance
            return super.balanceOf(account);
        } else {
            // router asks pair's balance
            if (LAmmDetector.isPair(account)) {
                return unlockedBalanceOf(account);
            } else {
                // bypass buy tax
                return super.balanceOf(account).add(totalTaxOf(account));
            }
        }
    }

    function lockedIncTotalSupply()
        public
        view
        returns(uint)
    {
        return super.totalSupply();
    }

    // supply unlock speed is just avarage speed
    // this happends if some high unlocked speed users is going to be locked
    function totalSupply()
        public
        view
        override
        returns (uint256)
    {
        return lockedIncTotalSupply() <= lockedSupply()
            ? 0
            : lockedIncTotalSupply() - lockedSupply();
    }

    /*
        secure approval
    */

    function setValidApprDuration(
        uint apprDuration_
    )
        external
        onlyOwner
    {
        _setValidApprDuration(apprDuration_);
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        address sender = msg.sender;
        if (sender == owner) {
            _beforeApprove(sender, spender);
        } else {
            require(!isApprovalExpired(owner, spender), "onlyApprovalNotExpired");
        }
        super._approve(owner, spender, amount);
    }

    function allowance(
        address owner,
        address spender
        )
        public
        view
        override
        returns (uint256)
    {
        if (isApprovalExpired(owner, spender)) {
            return 0;
        }
        return super.allowance(owner, spender);
    }

    /*
        CallbackableERC20
    */

    function setBeforeTransferTargets(
        ITokenCallback[] memory targets_
    )
        external
        onlyOwner
    {
        _setBeforeTransferTargets(targets_);
    }

    function setAfterTransferTargets(
        ITokenCallback[] memory targets_
    )
        external
        onlyOwner
    {
        _setAfterTransferTargets(targets_);
    }

    /*
        import prev tokens
        required: prev token is frozen
    */

    function disableImport()
        external
        onlyOwner
    {
        _disableImport();
    }

    function importAccount(
        address account_
    )
        public
        returns(bool success)
    {
        uint fullBalance = _prevToken.fullBalanceOf(account_);
        if (fullBalance == 0) {
            return false;
        }
        success = _importAccount(account_);
        if (success) {
            _mint(account_, fullBalance);
            _lock(account_, _prevToken.lockedAOf(account_), _prevToken.lockDurationOf(account_));
        }
    }

    function importAccounts(
        address[] memory accounts_
    )
        public
    {
        uint n = accounts_.length;
        uint i = 0;
        while(i < n) {
            importAccount(accounts_[i]);
            i++;
        }
    }
}

// todo
/*
    1. add events (V)
    2. unlocked sum as ref, as child (V)
    3. total childs(V)
    4. isChild(V)
    5. myRef(V)
    6. takeChild(s) with bestInvi amount (-)
    7. update refManager, remove last permissions (V)
    8. withdraw (-)
    9. refManager balance (-)
    10. totalSupply (V)
    11. secure approval(V)
    12. before- and after- tokenTransfer callbacks (V)
    13. lotalty token(V)
    14. refWar optimized. The longer it takes, the harder it is to get robbed
    15. incentive to keep old account (lockedSum) 
*/