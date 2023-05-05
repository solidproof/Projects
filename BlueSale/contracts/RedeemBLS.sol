// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IStakeXBLSDividend {
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount, bool _onlyHarvest, bool _isReward) external;
}

contract RedeemBLS is Initializable, PausableUpgradeable, 
    OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    IERC20 public rewardToken;
    IERC20 public depositToken;
    
    uint256 public constant PERCENT_MUL = 100;
    uint256 public constant PERCENT_DIV = 10000;

    uint256 public  percentCreditPerUnit; // 0.3%  = 50%/(180days-15days)=0.30303 * 100000;
    uint256 public  toDividendPercent;
    uint256 public  claimBLSFee; //
    uint256 public  claimXBLSPercent; // 9975 99,75% coz already minus 0,25% in dividend pool

    // The fee collector.
    address public feeCollector;
    address public xBlsFeeWallet;
    address public BlsFeeWallet;
    address public admin;
    address public dividendPool;

    // storing redeem by user
    struct UserRedeem {
      address userWallet;
      uint256 amount;
      uint256 startRedeemDate;
      uint256 redeemPeriod; // in seconds
      uint256 redeemIndex;
    }

    mapping(uint256 => UserRedeem) public redeemDetails;

    // address to redeemIndex to value
    mapping(address => uint256[]) public userRedeemIds;
    //user to redeemdPeriod to amount redeemd
    mapping(address => mapping(uint256 => uint256)) public userPeriodAmount;
    mapping(address => uint256) public totalUserStaking;

    // redeem type to unredeem fee percentage, 7days => 
    // mapping(uint256 => uint256) public unredeemFees;

    uint256 public redeemPeriodMin;
    uint256 public redeemPeriodMax;
    uint256 public rewardPerSecond;
    
    uint256 public yearToSeconds;
    uint256 public dayToSeconds;
    uint256 public redeemIndex;
    uint256 public redeemPeriodCount;
    uint256 public feePeriodCount;
    uint256 public totalLocked;
    uint256 public poolStartTime;

    uint256 public ptotalRedeemd; // all redeemd token
    uint256 public ptotalUnRedeem; // all unredeemd
    uint256 public ptotalHarvested;
    uint256 public ptotalRewardPaid;

    // Whether it is initialized
    bool public isInitialized;

    event EventRedeem(address indexed user, uint256 amount, uint256 period);

    function initialize(
        address _admin,
        uint256 _poolStartTime,
        uint256 _yearToSeconds,
        uint256 _dayToSeconds,
        uint256 _redeemIndex,
        uint256 _redeemPeriodMin,
        uint256 _redeemPeriodMax,
        uint256 _toDividendPercent,
        uint256 _percentCreditPerUnit
        ) public initializer {
        __Context_init();
        __Ownable_init();
        __ReentrancyGuard_init();
        
        admin = _admin;
        poolStartTime = _poolStartTime;
        yearToSeconds = _yearToSeconds; //31556926;
        dayToSeconds = _dayToSeconds; //86400;
        redeemIndex = _redeemIndex; //1;
        redeemPeriodMin = _redeemPeriodMin;// 15*dayToSeconds;
        redeemPeriodMax = _redeemPeriodMax;//180*dayToSeconds;
        toDividendPercent = _toDividendPercent; //5000; // 50%
        percentCreditPerUnit = _percentCreditPerUnit;
    }
    
    // constructor() {
    //     admin = msg.sender;
    //     poolStartTime = block.timestamp;
    //     yearToSeconds = 31556926;
    //     dayToSeconds = 86400;
    //     redeemIndex = 1;
    //     redeemPeriodMin = 15*dayToSeconds;
    //     redeemPeriodMax = 180*dayToSeconds;
    //     toDividendPercent = 5000; // 50%
    // }

     /*
     * @notice config the contract
     */
    function config(
        address _redeemToken, 
        address _rewardToken,
        address _xBlsFeeWallet,
        address _BlsFeeWallet,
        address _feeCollector,
        uint256 _redeemPeriodMin, // in day
        uint256 _redeemPeriodMax,// in day
        uint256 _percentCreditPerUnit // in day
    ) external onlyOwner{
        // Make this contract initialized
        isInitialized = true;
        depositToken = IERC20(_redeemToken);
        rewardToken = IERC20(_rewardToken);
        feeCollector = _feeCollector;
        redeemPeriodMin = _redeemPeriodMin;
        redeemPeriodMax = _redeemPeriodMax;
        xBlsFeeWallet = _xBlsFeeWallet;
        BlsFeeWallet = _BlsFeeWallet;
        percentCreditPerUnit = _percentCreditPerUnit;
    }


    function configDurationToPercent(
        uint256 _minDurationPercent,  //  e.g. 50 (15 days get 50%)
        uint256 _maxDurationPercent // e.g. 100 (180 days get 100%)
    ) 
        public 
        onlyOwner 
    {
        
    }

    function setSecondsInYear(uint256 _seconds) external onlyOwner {
        yearToSeconds = _seconds;
    }

    function setRewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        rewardPerSecond = _rewardPerSecond;
    }

    function setPoolStatus(uint256 _poolStartTime) external onlyOwner {
        poolStartTime = _poolStartTime;
    }

    function userRedeemIndex(address _addr) public view returns(uint256){
        return userRedeemIds[_addr].length;
    }

    function setDividenPool(address _addr) external onlyOwner{
        dividendPool = _addr;
    }

    function setPercentToDividenPool(uint256 _percent) external onlyOwner{
        toDividendPercent = _percent;
    }
    
    function setClaimFee(uint256 _feePercentBLS, uint256 _claimPercentXBLS) external onlyOwner{
        claimBLSFee = _feePercentBLS;
        claimXBLSPercent = _claimPercentXBLS;
    }

    // _period: locking time in day
    function redeem(uint256 _amount, uint256 _period) external whenNotPaused{
        require(block.timestamp >= poolStartTime, "Pool is not ready");
        require(isInitialized,"Not yet initialized");
        require(_amount > 0, "Invalid amount");
        require(dividendPool != address(0), "Invalid dividend");
        require(_period >= redeemPeriodMin && _period <= redeemPeriodMax, "Invalid period");
        require(depositToken.balanceOf(msg.sender) >= _amount, "Not enough balance");
        rmHarvestedEl();
        

        UserRedeem storage currentRedeem = redeemDetails[redeemIndex]; 
        currentRedeem.userWallet = msg.sender;
        currentRedeem.amount = _amount;
        currentRedeem.startRedeemDate = block.timestamp;
        currentRedeem.redeemPeriod = _period;
        currentRedeem.redeemIndex = redeemIndex;

        // [address][i][index]
        userRedeemIds[msg.sender].push(redeemIndex);

        redeemIndex++;

        userPeriodAmount[msg.sender][_period] += _amount;
        totalUserStaking[msg.sender] += _amount;
        totalLocked += _amount;
        ptotalRedeemd += _amount;
        
        uint256 dividenStakeAmount = _amount.mul(toDividendPercent).div(PERCENT_DIV);
        IERC20(depositToken).transferFrom(
            address(msg.sender),
            address(this),
            _amount.sub(dividenStakeAmount)
        );

        // deposit 50% xBLS to dividend pool
        IStakeXBLSDividend(dividendPool).deposit(dividenStakeAmount);

        emit EventRedeem(msg.sender, _amount, _period);
    }

    function claim(uint256 _redeemId) external whenNotPaused{
        uint256 totalDeposit;
        uint256 totalReward;

        for(uint256 i = 0; i < userRedeemIds[msg.sender].length; i++) {
            if (userRedeemIds[msg.sender][i] > 0 
                && (block.timestamp - redeemDetails[userRedeemIds[msg.sender][i]].startRedeemDate) >= (redeemDetails[userRedeemIds[msg.sender][i]].redeemPeriod)
                && _redeemId == userRedeemIds[msg.sender][i]
            ) {
                totalDeposit += redeemDetails[userRedeemIds[msg.sender][i]].amount;
                totalReward += calcRewards(userRedeemIds[msg.sender][i]);

                totalLocked -= redeemDetails[userRedeemIds[msg.sender][i]].amount;
                ptotalHarvested += redeemDetails[userRedeemIds[msg.sender][i]].amount;
                userPeriodAmount[msg.sender][redeemDetails[userRedeemIds[msg.sender][i]].redeemPeriod] -= redeemDetails[userRedeemIds[msg.sender][i]].amount;
                totalUserStaking[msg.sender] -= redeemDetails[userRedeemIds[msg.sender][i]].amount;

                // removing redeem elmenet
                delete redeemDetails[userRedeemIds[msg.sender][i]];

                // removing redeem id
                userRedeemIds[msg.sender][i] = 0;
             }
        }

        // if (feeCollector != address(0) && totalharvest > 0) {
        //     depositToken.transfer(msg.sender, totalharvest);
        // }

        require(totalReward > 0 && totalDeposit > 0, "No credit to claim");

        // TODO withdraw xBLS from dividend to pool and burn
        IStakeXBLSDividend(dividendPool).withdraw(totalDeposit.mul(toDividendPercent).div(PERCENT_DIV), false, true);

        // Transferring xBLS to fee wallet to be burned later, minus 0.25% coz already charged in dividen pool
        depositToken.transfer(xBlsFeeWallet, totalDeposit.mul(claimXBLSPercent).div(PERCENT_DIV));

        // Transferring BLS to user
        uint256 fee = collectClaimFee(totalReward);
        rewardToken.transfer(msg.sender, totalReward.sub(fee));
        rewardToken.transfer(BlsFeeWallet, fee);
        ptotalRewardPaid += totalReward;
    }

    function collectClaimFee(uint256 _amount) internal view returns(uint256)
    {   
        if (claimBLSFee > 0 && BlsFeeWallet != address(0)) {
            return _amount.mul(claimBLSFee).div(PERCENT_DIV);
        }
        return 0;
    }

    function calcRewards(uint256 _redeemId) public view returns(uint256) {
        uint256 lockedPlusPeriod = redeemDetails[_redeemId].redeemPeriod - redeemPeriodMin; // in seconds
        uint256 amount = redeemDetails[_redeemId].amount;
        uint256 amountPerEarnUnit = amount * percentCreditPerUnit / PERCENT_DIV;
        uint256 plusEarnedToken = lockedPlusPeriod * amountPerEarnUnit;
        uint256 creditAmount = amount / 2 + plusEarnedToken;
        return creditAmount;
    }

    function unRedeem(uint256[] memory _redeemIds) external whenNotPaused {
        require(_redeemIds.length > 0, "Invalid ids");
        uint256 totalRedeemd;
        // uint256 totalUnredeemFee;
        for(uint256 i = 0; i < _redeemIds.length; i++) {

            totalRedeemd += redeemDetails[_redeemIds[i]].amount;
            // totalUnredeemFee += collectUnredeemFee(_redeemIds[i]);

            totalLocked -= redeemDetails[_redeemIds[i]].amount;
            ptotalUnRedeem += redeemDetails[_redeemIds[i]].amount;

            userPeriodAmount[msg.sender][redeemDetails[_redeemIds[i]].redeemPeriod] -= redeemDetails[_redeemIds[i]].amount;
            totalUserStaking[msg.sender] -= redeemDetails[userRedeemIds[msg.sender][i]].amount;

            // removing redeem elmenet
            delete redeemDetails[_redeemIds[i]];

            // removing redeem id
            userRedeemIds[msg.sender][getIndexByRedeemId(msg.sender,_redeemIds[i])] = 0;
        }
        
        // deduct 9975 is 100-0.25%
        uint256 withdrawAmt = totalRedeemd.mul(9975).div(PERCENT_DIV);

        depositToken.transfer(msg.sender, withdrawAmt);

        // TODO withdraw 44.95% XBLS from dividend to this staking pool
        IStakeXBLSDividend(dividendPool).withdraw(totalRedeemd.mul(toDividendPercent).div(PERCENT_DIV), false, false);
    }

    function getIndexByRedeemId(address _addr, uint256 _redeemId) internal view returns(uint256) {
        uint256 index;
        for(uint256 i = 0; i < userRedeemIds[_addr].length; i++) {
            if (_redeemId == userRedeemIds[_addr][i]) {
                index = i;
            }
        }
        return index;
    }

    function getExpiredTokens(address _addr) public view returns(uint256){
        uint256 amount;
        // uint256 rewards;
        
        for(uint256 i = 0; i < userRedeemIds[_addr].length; i++) {
            if (userRedeemIds[_addr][i] > 0 && (block.timestamp - redeemDetails[userRedeemIds[_addr][i]].startRedeemDate) >= redeemDetails[userRedeemIds[_addr][i]].redeemPeriod) {
                amount += redeemDetails[userRedeemIds[_addr][i]].amount;
                // rewards += calcRewards(userRedeemIds[_addr][i]);
            }
        }
        return amount;// + rewards;
    }

    function getUnexpiredTokens(address _addr) public view returns(uint256 ){
        uint256 amount;
        
        for(uint256 i = 0; i < userRedeemIds[_addr].length; i++) {
            if (userRedeemIds[_addr][i] > 0 && (block.timestamp - redeemDetails[userRedeemIds[_addr][i]].startRedeemDate) < redeemDetails[userRedeemIds[_addr][i]].redeemPeriod) {
                amount += redeemDetails[userRedeemIds[_addr][i]].amount;
            }
        }
        return amount;
    }


    function rmHarvestedEl() internal {
        for(uint256 i = 0; i < userRedeemIds[msg.sender].length; i++) {
            // this variable was set to 0 when harvesting
            if(userRedeemIds[msg.sender][i]  == 0) {
                userRedeemIds[msg.sender][i] = userRedeemIds[msg.sender][userRedeemIds[msg.sender].length - 1];
                userRedeemIds[msg.sender].pop();
            }
        }
    }

    function emerWithdraw(
        address _token, 
        address _to, 
        uint256 _amount
    ) 
        external onlyOwner
    {
        if (address(this).balance > 0) {
            uint256 amt  = address(this).balance ;
            payable(_to).transfer(amt);
        }
        IERC20(_token).transfer(_to, _amount);
    }

}
