// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ICairoToken {

    function calculateTransferTaxes(address _from, uint256 _value) external view returns (uint256 adjustedValue, uint256 taxAmount);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address who) external view returns (uint256);

    function burnFromCairoNetwork(address account, uint256 amount) external;
    function transferFromCairoNetwork(address sender, address recipient, uint256 amount) external;

    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);
}

contract CairoMaximizer is OwnableUpgradeable {

    using SafeMath for uint256;

    struct User {
        //Referral Info
        address upline;
        uint256 referrals;
        uint256 total_structure;

        //Long-term Referral Accounting
        uint256 direct_bonus;
        uint256 match_bonus;

        //Deposit Accounting
        uint256 deposits;
        uint256 deposit_time;

        //Payout and Roll Accounting
        uint256 payouts;
        uint256 rolls;

        //Upline Round Robin tracking
        uint256 ref_claim_pos;

        uint256 accumulatedDiv;
    }

    struct Airdrop {
        //Airdrop tracking
        uint256 airdrops;
        uint256 airdrops_received;
        uint256 last_airdrop;
    }

    struct Custody {
        address manager;
        address beneficiary;
        uint256 last_heartbeat;
        uint256 last_checkin;
        uint256 heartbeat_interval;
    }

    address public cairoVaultAddress;
    address public adminFeeAddress;

    ICairoToken private cairoToken;

    mapping(address => User) public users;
    mapping(address => Airdrop) public airdrops;
    mapping(address => Custody) public custody;

    uint256 public CompoundTax;
    uint256 public ExitTax;

    uint256 private payoutRate;
    uint256 private ref_depth;
    uint256 private ref_bonus;

    uint private maximizerBurnPercent;
    uint private maximizerFeePercent;
    uint256 private maximizerAdminFee;
    uint256 private maximizerKeepAmount;

    uint256 private minimumInitial;
    uint256 private minimumAmount;

    uint256 public max_payout_cap;

    uint256 public total_airdrops;
    uint256 public total_users;
    uint256 public total_deposited;
    uint256 public total_withdraw;
    uint256 public total_bnb;
    uint256 public total_txs;

    uint256 public constant MAX_UINT = 2**256 - 1;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event Leaderboard(address indexed addr, uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event BalanceTransfer(address indexed _src, address indexed _dest, uint256 _deposits, uint256 _payouts);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);
    event NewAirdrop(address indexed from, address indexed to, uint256 amount, uint256 timestamp);
    event ManagerUpdate(address indexed addr, address indexed manager, uint256 timestamp);
    event BeneficiaryUpdate(address indexed addr, address indexed beneficiary);
    event HeartBeatIntervalUpdate(address indexed addr, uint256 interval);
    event HeartBeat(address indexed addr, uint256 timestamp);
    event Checkin(address indexed addr, uint256 timestamp);

    address public adminFeeAddress2;

    /* ========== INITIALIZER ========== */

    function initialize(address cairoTokenAddr) external initializer {
        __Ownable_init();
        cairoVaultAddress = address(this);
        cairoToken = ICairoToken(cairoTokenAddr);
    }

    fallback() external payable {

    }

    /****** Administrative Functions *******/
    function updateCairoTokenAddress(address cairoTokenAddress) public onlyOwner {
        cairoToken = ICairoToken(cairoTokenAddress);
    }

    function updatePayoutRate(uint256 _newPayoutRate) public onlyOwner {
        payoutRate = _newPayoutRate;
    }

    function updateBurnPercent(uint256 _newBurnPercent) public onlyOwner {
        maximizerBurnPercent = _newBurnPercent;
    }

    function updateAdminFeeAddress(address feeAddress, address feeAddress2) public onlyOwner {
        adminFeeAddress = feeAddress;
        adminFeeAddress2 = feeAddress2;
    }

    function updateKeepPercent(uint256 _newKeepPercent) public onlyOwner {
        maximizerKeepAmount = _newKeepPercent;
    }

    function updateRefDepth(uint256 _newRefDepth) public onlyOwner {
        ref_depth = _newRefDepth;
    }

    function updateRefBonus(uint256 _newRefBonus) public onlyOwner {
        ref_bonus = _newRefBonus;
    }

    function updateInitialDeposit(uint256 _newInitialDeposit) public onlyOwner {
        minimumInitial = _newInitialDeposit;
    }

    function updateCompoundTax(uint256 _newCompoundTax) public onlyOwner {
        require(_newCompoundTax >= 0 && _newCompoundTax <= 20);
        CompoundTax = _newCompoundTax;
    }

    function updateExitTax(uint256 _newExitTax) public onlyOwner {
        require(_newExitTax >= 0 && _newExitTax <= 20);
        ExitTax = _newExitTax;
    }

    function updateMaxPayoutCap(uint256 _newPayoutCap) public onlyOwner {
        max_payout_cap = _newPayoutCap;
    }

    /********** User Fuctions **************************************************/
    function checkin() public {
        address _addr = tx.origin;
        custody[_addr].last_checkin = block.timestamp;
        emit Checkin(_addr, custody[_addr].last_checkin);
    }

    //@dev Deposit specified CAIRO amount supplying an upline referral
    function deposit(address _upline, uint256 _amount) external {

        address _addr = msg.sender;

        (uint256 realizedDeposit, uint256 taxAmount) = cairoToken.calculateTransferTaxes(_addr, _amount);
        uint256 _total_amount = realizedDeposit;

        //Checkin for custody management.
        checkin();

        require(_amount >= minimumAmount, "Minimum deposit");

        //If fresh account require a minimal amount of CAIRO
        if (users[_addr].deposits == 0){
            require(_amount >= minimumInitial, "Initial deposit too low");
        }

        _setUpline(_addr, _upline);

        uint256 taxedDivs;

        // Claim if divs are greater than 1% of the deposit
        if (claimsAvailable(_addr) > _amount / 100){
            uint256 claimedDivs = _claim(_addr);
            taxedDivs = claimedDivs.mul(SafeMath.sub(100, CompoundTax)).div(100); // 5% tax on compounding
            _total_amount += taxedDivs;
            taxedDivs = taxedDivs / 2;
        }

        //Transfer CAIRO to the contract
        require(
            cairoToken.transferFrom(
                _addr,
                address(this),
                _amount
            ),
            "CAIRO token transfer failed"
        );

        // Burn 90% of what goes in to the maximizer

        uint256 scriptShare = _amount.mul(10).div(100);
        uint256 adminHalfShare = scriptShare.mul(50).div(100);

        cairoToken.burnFromCairoNetwork(address(this), _amount.sub(scriptShare));

        require(
            cairoToken.transfer(address(adminFeeAddress), adminHalfShare),
            "CAIRO token transfer failed"
        );

        require(
            cairoToken.transfer(address(adminFeeAddress2), adminHalfShare),
            "CAIRO token transfer failed"
        );

        _deposit(_addr, _total_amount);
        uint256 payoutBonus = realizedDeposit + taxedDivs;

        _refPayout(_addr, payoutBonus.safeSub(scriptShare), ref_bonus);

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }

    //@dev Claim, transfer, withdraw from vault
    function claim() external {

        //Checkin for custody management.  If a user rolls for themselves they are active
        checkin();

        address _addr = msg.sender;

        _claim_out(_addr);
    }

    //@dev Claim and deposit;
    function roll() public {

        //Checkin for custody management.  If a user rolls for themselves they are active
        checkin();

        address _addr = msg.sender;

        _roll(_addr);
    }

    /********** Internal Fuctions **************************************************/

    //@dev Add direct referral and update team structure of upline
    function _setUpline(address _addr, address _upline) internal {
        /*
        1) User must not have existing up-line
        2) Up-line argument must not be equal to senders own address
        3) Up-lined user must have a existing deposit
        */
          if(users[_addr].upline == address(0) && _upline != _addr && (users[_upline].deposit_time > 0 )) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);

            total_users++;

            for(uint8 i = 0; i < ref_depth; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++;

                _upline = users[_upline].upline;
            }
        }
    }

    //@dev Deposit
    function _deposit(address _addr, uint256 _amount) internal {
        // require(users[_addr].upline != address(0) || _addr == owner(), "No upline");

        //stats
        users[_addr].deposits += _amount;
        users[_addr].deposit_time = block.timestamp;

        total_deposited += _amount;

        //events
        emit NewDeposit(_addr, _amount);

    }

    //Payout upline
    function _refPayout(address _addr, uint256 _amount, uint256 _refBonus) internal {
        //for deposit _addr is the sender/depositor

        address _up = users[_addr].upline;
        uint256 _bonus = _amount * _refBonus / 100; // 10% of amount
        uint256 _share = _bonus / 10;                // 1% of amount
        bool first_level = true;

        for(uint8 i = 0; i < ref_depth; i++) {

            // If we have reached the top of the chain, the owner
            if(_up == address(0)){
                //The equivalent of looping through all available
                users[_addr].ref_claim_pos = ref_depth;
                break;
            }

            //We only match if the claim position is valid
            if(users[_addr].ref_claim_pos == i) {
                if (isBalanceCovered(_up, i + 1) && isNetPositive(_up)){
                    (uint256 gross_payout,,) = payoutOf(_up);
                    users[_up].accumulatedDiv = gross_payout;

                    users[_up].deposit_time = block.timestamp;

                    uint256 bonus_payout = _bonus;
                    if (!first_level) bonus_payout = _share;

                    //match accounting
                    users[_up].match_bonus += bonus_payout;
                    users[_up].deposits += bonus_payout;

                    //events
                    emit NewDeposit(_up, bonus_payout);
                    emit MatchPayout(_up, _addr, bonus_payout);

                    if (users[_up].upline == address(0)){
                        users[_addr].ref_claim_pos = ref_depth;
                    }
                }

                users[_addr].ref_claim_pos += 1;
                first_level = false;

            }

            _up = users[_up].upline;

        }

        //Reward the next
        users[_addr].ref_claim_pos += 1;

        //Reset if we've hit the end of the line
        if (users[_addr].ref_claim_pos >= ref_depth){
            users[_addr].ref_claim_pos = 0;
        }
    }

    //@dev General purpose heartbeat in the system used for custody/management planning
    function _heart(address _addr) internal {
        custody[_addr].last_heartbeat = block.timestamp;
        emit HeartBeat(_addr, custody[_addr].last_heartbeat);
    }

    //@dev Claim and deposit;
    function _roll(address _addr) internal {
        uint256 to_payout = _claim(_addr);
        uint256 scriptShare = to_payout.mul(5).div(100);
        uint256 adminHalfShare = scriptShare.mul(50).div(100);

        uint256 payout_taxed = to_payout.sub(scriptShare);

        require(
            cairoToken.transfer(address(adminFeeAddress), adminHalfShare),
            "CAIRO token transfer failed"
        );

        require(
            cairoToken.transfer(address(adminFeeAddress2), adminHalfShare),
            "CAIRO token transfer failed"
        );

        cairoToken.burnFromCairoNetwork(address(this), payout_taxed);

        _deposit(_addr, payout_taxed);

        // track recompoundings for net positive
        users[_addr].rolls += payout_taxed;

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }

    //@dev Claim, transfer, and topoff
    function _claim_out(address _addr) internal {
        uint256 to_payout = _claim(_addr);

        uint256 scriptShare = to_payout.mul(10).div(100);
        uint256 adminHalfShare = scriptShare.mul(50).div(100);
        require(
            cairoToken.transfer(address(adminFeeAddress), adminHalfShare),
            "CAIRO token transfer failed"
        );

        require(
            cairoToken.transfer(address(adminFeeAddress2), adminHalfShare),
            "CAIRO token transfer failed"
        );

        uint256 realizedPayout = to_payout.sub(scriptShare);
        require(cairoToken.transfer(address(msg.sender), realizedPayout), "Cairo token payout failed");

        emit Leaderboard(_addr, users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure);
        total_txs++;

    }

    //@dev Claim current payouts
    function _claim(address _addr) internal returns (uint256) {
        (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout) = payoutOf(_addr);
        require(users[_addr].payouts < _max_payout, "Full payouts");

        // Deposit payout
        if(_to_payout > 0) {
            // Only payout remaining allowable dividends if exceeds
            if(users[_addr].payouts + _to_payout > _max_payout) {
                _to_payout = _max_payout.safeSub(users[_addr].payouts);
            }
            users[_addr].payouts += _gross_payout;
        }

        require(_to_payout > 0, "Zero payout");

        // Update the payouts
        total_withdraw += _to_payout;

        // Update deposit/recompound time
        users[_addr].deposit_time = block.timestamp;
        users[_addr].accumulatedDiv = 0;

        emit Withdraw(_addr, _to_payout);

        if(users[_addr].payouts >= _max_payout) {
            emit LimitReached(_addr, users[_addr].payouts);
        }

        return _to_payout;
    }

    // Взгляды

    //@dev Returns true if the address is net positive
    function isNetPositive(address _addr) public view returns (bool) {
        (uint256 _credits, uint256 _debits) = creditsAndDebits(_addr);
        return _credits > _debits;
    }

    //@dev Returns the total credits and debits for a given address
    function creditsAndDebits(address _addr) public view returns (uint256 _credits, uint256 _debits) {
        User memory _user = users[_addr];
        Airdrop memory _airdrop = airdrops[_addr];

        _credits = _airdrop.airdrops + _user.rolls + _user.deposits;
        _debits = _user.payouts;

    }

    //@dev Returns whether balance matches level
    function isBalanceCovered(address _addr, uint8 _level) public view returns (bool) {
        if (users[_addr].upline == address(0)){
            return true;
        }
        return balanceLevel(_addr) >= _level;
    }

    //@dev Совместимость
    function balanceLevel(address _addr) public view returns (uint8) {
        uint8 _level = 0;
        for (uint8 i = 0; i < ref_depth; i++) {
            _level += 1;
        }

        return _level;
    }

    //@dev Пользователь в аплайне
    function getCustody(address _addr) public view returns (address _beneficiary, uint256 _heartbeat_interval, address _manager) {
        return (custody[_addr].beneficiary, custody[_addr].heartbeat_interval, custody[_addr].manager);
    }

    function lastActivity(address _addr) public view returns (uint256 _heartbeat, uint256 _lapsed_heartbeat, uint256 _checkin, uint256 _lapsed_checkin) {
        _heartbeat = custody[_addr].last_heartbeat;
        _lapsed_heartbeat = block.timestamp.safeSub(_heartbeat);
        _checkin = custody[_addr].last_checkin;
        _lapsed_checkin = block.timestamp.safeSub(_checkin);
    }

    function claimsAvailable(address _addr) public view returns (uint256) {
        (uint256 _gross_payout, uint256 _max_payout, uint256 _to_payout) = payoutOf(_addr);
        return _to_payout;
    }

    function maxPayoutOf(uint256 _amount) public pure returns(uint256) {
        return _amount * 365 / 100;
    }

    function payoutOf(address _addr) public view returns(uint256 payout, uint256 max_payout, uint256 net_payout) {
        //The max_payout is capped so that we can also cap available rewards daily
        max_payout = maxPayoutOf(users[_addr].deposits).min(max_payout_cap);

        uint256 share;

        if(users[_addr].payouts < max_payout) {
            //Using 1e18 we capture all significant digits when calculating available dividends
            share = users[_addr].deposits.mul(payoutRate * 1e18).div(100e18).div(24 hours); // divide the profit by payout rate and seconds in the day
            payout = share * block.timestamp.safeSub(users[_addr].deposit_time);
            payout += users[_addr].accumulatedDiv;

            // payout remaining allowable divs if exceeds
            if(users[_addr].payouts + payout > max_payout) {
                payout = max_payout.safeSub(users[_addr].payouts);
            }

            net_payout = payout;
        }
    }

    function userInfo(address _addr) external view returns(address upline, uint256 deposit_time, uint256 deposits, uint256 payouts, uint256 direct_bonus, uint256 match_bonus, uint256 last_airdrop) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposits, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].match_bonus, airdrops[_addr].last_airdrop);
    }
    function userInfoTotals(address _addr) external view returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure, uint256 airdrops_total, uint256 airdrops_received) {
        return (users[_addr].referrals, users[_addr].deposits, users[_addr].payouts, users[_addr].total_structure, airdrops[_addr].airdrops, airdrops[_addr].airdrops_received);
    }
    function contractInfo() external view returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw, uint256 _total_bnb, uint256 _total_txs, uint256 _total_airdrops) {
        return (total_users, total_deposited, total_withdraw, total_bnb, total_txs, total_airdrops);
    }

    //@dev Send specified CAIRO amount supplying an upline referral
    function airdrop(address _to, uint256 _amount) external {

        address _addr = tx.origin;

        (uint256 _realizedAmount, uint256 taxAmount) = cairoToken.calculateTransferTaxes(_addr, _amount);
        //This can only fail if the balance is insufficient
        require(
            cairoToken.transfer(
                address(cairoVaultAddress),
                _amount
            ),
            "CAIRO to contract transfer failed; check balance and allowance, airdrop"
        );

        //Make sure _to exists in the system; we increase
        require(users[_to].upline != address(0), "_to not found");

        (uint256 gross_payout,,) = payoutOf(_to);

        users[_to].accumulatedDiv = gross_payout;

        //Fund to deposits (not a transfer)
        users[_to].deposits += _realizedAmount;
        users[_to].deposit_time = block.timestamp;

        //User stats
        airdrops[_addr].airdrops += _realizedAmount;
        airdrops[_addr].last_airdrop = block.timestamp;
        airdrops[_to].airdrops_received += _realizedAmount;

        // Keep track of overall stats
        total_airdrops += _realizedAmount;
        total_txs += 1;

        // Submit Events
        emit NewAirdrop(_addr, _to, _realizedAmount, block.timestamp);
        emit NewDeposit(_to, _realizedAmount);
    }

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
   */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**j m m  ihi hjngyhnb nhnj m
     * @dev Integer division of two numbers, truncating the quotient.
   */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
   */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /* @dev Subtracts two numbers, else returns zero */
    function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b > a) {
            return 0;
        } else {
            return a - b;
        }
    }

    /**
     * @dev Adds two numbers, throws on overflow.
   */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}