// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../token/WonkaCapital.sol";

/* interface WonkaNFT {
	function balanceOf(address account) external view returns(uint256);
}
 
interface WonkaCapital {
	function getVestingFee(address addr) external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
	function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
} */

contract WonkaStake is Ownable, ReentrancyGuard {
    
    using SafeMath for uint256;

    struct Stake{
        uint256 deposit_amount;        //Deposited Amount
        uint256 stake_creation_time;   //The time when the stake was created
        bool returned;              //Specifies if the funds were withdrawed
        uint256 alreadyWithdrawedAmount;   //TODO Correct Lint
        uint256 interest;
    }

    /**
    *   @dev Emitted when a new stake is issued
     */
    event NewStake(uint256 stakeAmount, uint256 _stakeID);

    /**
    *   @dev Emitted when a new stake is withdrawed
     */
    event StakeWithdraw(uint256 stakeID, uint256 amount);

    event rewardWithdrawed(address account, uint256 _stakeID);
	

    mapping (address => Stake[]) private stake; /// @dev Map that contains account's stakes
    address public tokenAddress;
    WonkaCapital private wonkacapital;
	WonkaNFT public wonkabronze;
    WonkaNFT public wonkasilver;
    WonkaNFT public wonkagold;
	
	mapping(address => bool) public _isLocked;

    bool public isPaused = false;
    uint256 private constant _DECIMALS = 9;

    uint256 private constant _INTEREST_PERIOD = 1 hours;    //One Hours
    // uint256 private constant _INTEREST_PERIOD = 10 minutes;    //One Hours
    uint256 private constant _LOCK_PERIOD = 14 days;    //One Days
    // uint256 private constant _LOCK_PERIOD = 14 minutes;    //One Days
    
	mapping(string => mapping(string=>uint256)) public interests;
	
    uint256 public _MIN_STAKE_AMOUNT = 1 * (10**_DECIMALS);
    uint256 public _total_token_staked = 0;
    
    constructor(address _tokenAddress, address _wonkabronze, address _wonkasilver, address _wonkagold) {
        
        tokenAddress 	= _tokenAddress;
        wonkacapital 	= WonkaCapital(tokenAddress);
		wonkabronze 	= WonkaNFT(_wonkabronze);
		wonkasilver 	= WonkaNFT(_wonkasilver);
		wonkagold 		= WonkaNFT(_wonkagold);
		
		interests['gold']['vesting']		=	1250;
		interests['gold']['nonvesting']		=	1250;
		
		interests['silver']['vesting']		=	1000;
		interests['silver']['nonvesting']	=	750;
		
		interests['bronze']['vesting']		=	750;
		interests['bronze']['nonvesting']	=	500;
		
		interests['token']['vesting']		=	500;
		interests['token']['nonvesting']	=	250;
    }

    //-------------------------- TOKEN ADDRESS -----------------------------------
    function setTokenNFTAddress(address _tokenAddress, address _wonkabronze, address _wonkasilver, address _wonkagold) external onlyOwner {
        require(Address.isContract(_tokenAddress), "The address does not point to a contract");
        require(Address.isContract(_wonkabronze), "The address does not point to a contract");
        require(Address.isContract(_wonkasilver), "The address does not point to a contract");
        require(Address.isContract(_wonkagold), "The address does not point to a contract");

        tokenAddress 	= _tokenAddress;
        wonkacapital 	= WonkaCapital(tokenAddress);
		wonkabronze 	= WonkaNFT(_wonkabronze);
		wonkasilver 	= WonkaNFT(_wonkasilver);
		wonkagold 		= WonkaNFT(_wonkagold);
    }
	
	function setInterestValue(uint256[8] memory feeData) external onlyOwner {
        interests['gold']['vesting']		=	feeData[0];
		interests['gold']['nonvesting']		=	feeData[1];
		
		interests['silver']['vesting']		=	feeData[2];
		interests['silver']['nonvesting']	=	feeData[3];
		
		interests['bronze']['vesting']		=	feeData[4];
		interests['bronze']['nonvesting']	=	feeData[5];
		
		interests['token']['vesting']		=	feeData[6];
		interests['token']['nonvesting']	=	feeData[7];
    }
	
	function setMinStakeSmount(uint256 MIN_STAKE_AMOUNT) external onlyOwner {
        _MIN_STAKE_AMOUNT = MIN_STAKE_AMOUNT * (10**_DECIMALS);
    }

    function isTokenSet() external view returns (bool) {
        if(tokenAddress == address(0))
            return false;
        return true;
    }
	
	function lockUnlockAccount(address[] memory accounts, bool[] memory lockstatus) external onlyOwner() {
        for (uint256 i = 0; i < accounts.length; i++) {
			_isLocked[accounts[i]] = lockstatus[i];
		}
    }
	
	function pauseEverything(bool pausestatus) external onlyOwner() {
        isPaused	=	pausestatus;
    }

    function getTokenAddress() external view returns (address){
        return tokenAddress;
    }

    //-------------------------- CLIENTS -----------------------------------
    /**
    *   @dev Stake token verifying all the contraint
    *   @notice Stake tokens
    *   @param _amount Amoun to stake
     */
    function stakeToken(uint256 _amount) external nonReentrant {

        require(!isPaused, "System Paused");
        require(!_isLocked[_msgSender()], "Account Locked");
        require(tokenAddress != address(0), "No contract set");

        require(_amount >= _MIN_STAKE_AMOUNT, "You must stake at least 100 tokens");
        require(wonkacapital.balanceOf(_msgSender())>=_amount, "You do not have enough balance");

        address staker = _msgSender();
        Stake memory newStake;

        newStake.deposit_amount = _amount;
        newStake.returned = false;
        newStake.stake_creation_time = block.timestamp;
        newStake.alreadyWithdrawedAmount = 0;
        newStake.interest = getInterestValue(_msgSender());
        stake[staker].push(newStake);
		_total_token_staked	+=	_amount;	
        if(wonkacapital.transferFrom(_msgSender(), address(this), _amount)){
            emit NewStake(_amount, stake[staker].length-1);
        }else{
            revert("Unable to transfer funds");
        }
    }
	
    /**
    *   @dev Reinvst as Stake token verifying all the contraint
    *   @notice Stake tokens
    *   @param _stakeID reInvest from stake reward
     */
    function reInvest(uint256 _stakeID) external nonReentrant {
		
		address staker	=	_msgSender();
		require(!isPaused, "System Paused");
		require(!_isLocked[staker], "Account Locked");
		require(!stake[staker][_stakeID].returned, "Already Unstacked");
        Stake memory _stake = stake[staker][_stakeID];

        uint256 rewardToWithdraw = calculateRewardToWithdraw(staker, _stakeID);
		require(rewardToWithdraw>0, "Amount must be greater then 0");
        stake[staker][_stakeID].alreadyWithdrawedAmount = _stake.alreadyWithdrawedAmount.add(rewardToWithdraw);
        
        Stake memory newStake;
        newStake.deposit_amount = rewardToWithdraw;
        newStake.returned = false;
        newStake.stake_creation_time = block.timestamp;
        newStake.alreadyWithdrawedAmount = 0;
        newStake.interest = getInterestValue(staker);
        stake[staker].push(newStake);
		_total_token_staked	+=	rewardToWithdraw;
		emit NewStake(rewardToWithdraw, stake[staker].length-1);
    }

    function withdrawReward(uint256 _stakeID) public nonReentrant returns (bool){
		
		address _account	=	_msgSender();
		require(!stake[_account][_stakeID].returned, "Already Unstacked");
        Stake memory _stake = stake[_account][_stakeID];

        uint256 rewardToWithdraw = calculateRewardToWithdraw(_account, _stakeID);
		require(rewardToWithdraw>0, "Amount must be greater then 0");
        stake[_account][_stakeID].alreadyWithdrawedAmount = _stake.alreadyWithdrawedAmount.add(rewardToWithdraw);
        if(wonkacapital.transfer(_account, rewardToWithdraw)){
            emit rewardWithdrawed(_account, _stakeID);
        }else{
            revert("Unable to transfer funds");
        }
        return true;
    }
	
	/**
    *   @dev Unstake, requiring that the stake was
    *   not alreay withdrawed
    *   @notice Return staked token
    *   @param _stakeID The ID of the stake to be returned
     */
    function unStake(uint256 _stakeID) external nonReentrant returns (bool){
		
		require(!isPaused, "System Paused");
		require(!_isLocked[_msgSender()], "Account Locked");
		require(!stake[_msgSender()][_stakeID].returned, "Already Unstacked");
        Stake memory selectedStake = stake[_msgSender()][_stakeID];
		
        //Check if the stake were already withdraw
        require(selectedStake.returned == false, "Stake were already returned");
        require(block.timestamp - selectedStake.stake_creation_time > _LOCK_PERIOD, "Stake is in locked period");
		
		uint256 rewardToWithdraw = calculateRewardToWithdraw(_msgSender(), _stakeID);
        stake[_msgSender()][_stakeID].alreadyWithdrawedAmount = selectedStake.alreadyWithdrawedAmount.add(rewardToWithdraw);
        
		uint256 deposited_amount = selectedStake.deposit_amount;

        //Only set the withdraw flag in order to disable further withdraw
        stake[_msgSender()][_stakeID].returned = true;
		_total_token_staked	-=	deposited_amount;
        if(wonkacapital.transfer(_msgSender(), deposited_amount + rewardToWithdraw)){
            emit StakeWithdraw(_stakeID, deposited_amount);
        }else{
            revert("Unable to transfer funds");
        }
        return true;
    }

    //-------------------------- VIEWS -----------------------------------
    /**
    * @dev Return the amount of token in the provided caller's stake
    * @param _stakeID The ID of the stake of the caller
     */
    function getCurrentStakeAmount(uint256 _stakeID) external view returns (uint256)  {
        require(tokenAddress != address(0), "No contract set");

        return stake[_msgSender()][_stakeID].deposit_amount;
    }

    /**
    * @dev Return sum of all the caller's stake amount
    * @return Amount of stake
     */
    function getTotalStakeAmount() external view returns (uint256) {
        require(tokenAddress != address(0), "No contract set");

        Stake[] memory currentStake = stake[_msgSender()];
        uint256 nummberOfStake = stake[_msgSender()].length;
        uint256 totalStake = 0;
        uint256 tmp;
        for (uint256 i = 0; i<nummberOfStake; i++){
			if(!currentStake[i].returned){
				tmp = currentStake[i].deposit_amount;
				totalStake = totalStake.add(tmp);
			}
        }
        return totalStake;
    }
	
	/**
    *   @dev Return all the available stake info for user
    *   @notice Return staked info
    */
    function getAllStakeInfo(address _account) external view returns(Stake[] memory){
		return stake[_account];
    }
	
	/**
    *   @dev Return all the available stake info for user
    *   @notice Return staked info
    */
    function getAllStakeDetails(uint256 _start, uint256 _end) external view returns(
		uint256[] memory,
		uint256[] memory,
		bool[] memory,
		uint256[] memory,
		uint256[] memory,
		uint256[] memory
	){
		
		address _account	=	_msgSender();

		uint256[] memory _mydeposits 			= 	new uint256[](stake[_account].length);
		uint256[] memory _mydepositstimes 		= 	new uint256[](stake[_account].length);
		bool[] memory _mydepositsstatus 		= 	new bool[](stake[_account].length);
		uint256[] memory _mydepositswithdrans 	= 	new uint256[](stake[_account].length);
		uint256[] memory _mydepositsinterest 	= 	new uint256[](stake[_account].length);
		uint256[] memory _mydepositsrewards 	= 	new uint256[](stake[_account].length);
		
		_end	=	_end==0?stake[_account].length:_end;
		
        for( uint256 i = _start; i < _end; i++){
			
			_mydeposits[i]			=	stake[_account][i].deposit_amount;
			_mydepositstimes[i]		=	stake[_account][i].stake_creation_time;
			_mydepositsstatus[i]	=	stake[_account][i].returned;
			_mydepositswithdrans[i]	=	stake[_account][i].alreadyWithdrawedAmount;
			_mydepositsinterest[i]	=	stake[_account][i].interest;
			_mydepositsrewards[i]	=	calculateRewardToWithdraw(_account, i);
        }

        return (
				_mydeposits,
				_mydepositstimes,
				_mydepositsstatus,
				_mydepositswithdrans,
				_mydepositsinterest,
				_mydepositsrewards
			);
    }
	
	
    /**
    *   @dev Return all the available stake info
    *   @notice Return stake info
    *   @param _stakeID ID of the stake which info is returned
    *
    *   @return 1) Amount Deposited
    *   @return 2) Bool value that tells if the stake was withdrawed
    *   @return 3) Stake creation time (Unix timestamp)
    *   @return 5) The current amount
    */
    function getStakeInfo(uint256 _stakeID) external view returns(uint256, bool, uint256, uint256){

		address _account	=	_msgSender();
        Stake memory selectedStake = stake[_account][_stakeID];

        uint256 amountToWithdraw = calculateRewardToWithdraw(_account, _stakeID);

        return (
            selectedStake.deposit_amount,
            selectedStake.returned,
            selectedStake.stake_creation_time,
            amountToWithdraw
        );
    }

    /**
    * @dev Get the number of active stake of the caller
    * @return Number of active stake
     */
    function getStakeCount() external view returns (uint256){
        return stake[_msgSender()].length;
    }


    function getActiveStakeCount() external view returns(uint256){
        uint256 stakeCount = stake[_msgSender()].length;

        uint256 count = 0;

        for(uint256 i = 0; i<stakeCount; i++){
            if(!stake[_msgSender()][i].returned){
                count = count + 1;
            }
        }
        return count;
    }

    function getAlreadyWithdrawedAmount(uint256 _stakeID) external view returns (uint256){
        return stake[_msgSender()][_stakeID].alreadyWithdrawedAmount;
    }

    function calculateRewardToWithdraw(address _account, uint256 _stakeID) internal view returns (uint256){
        Stake memory _stake = stake[_account][_stakeID];
		uint256 reward	=	0;
		if(!_stake.returned){
		
			uint256 amount_staked = _stake.deposit_amount;
			uint256 already_withdrawed = _stake.alreadyWithdrawedAmount;

			uint256 periods = calculateAccountStakePeriods(_account, _stakeID);  //Periods for interest calculation
			uint256 interestvalue   =   _stake.interest;
			uint256 interest = amount_staked.mul(interestvalue.div(365*24)).div(1000);
			
			uint256 total_interest 	= interest.div(1e9).mul(periods);
			reward 			= total_interest.sub(already_withdrawed); //Subtract the already withdrawed amount
		}
        return reward;

    }

    function calculateTotalRewardToWithdraw(address _account) internal view returns (uint256){
        Stake[] memory accountStakes = stake[_account];

        uint256 stakeNumber = accountStakes.length;
        uint256 amount = 0;

        for( uint256 i = 0; i<stakeNumber; i++){
            amount = amount.add(calculateRewardToWithdraw(_account, i));
        }

        return amount;
    }

    function calculateCompoundInterest(uint256 _stakeID) external view returns (uint256){

		address _account	=	_msgSender();
        Stake memory _stake = stake[_account][_stakeID];

        uint256 periods = calculatePeriods(_stakeID);
        uint256 amount_staked = _stake.deposit_amount;

		uint256 interestvalue   =   _stake.interest;
        //Calculate reward
        for(uint256 i = 0; i < periods; i++){
            uint256 period_interest;
            period_interest = amount_staked.mul(interestvalue.div(365).div(24)).div(1000);
            amount_staked = amount_staked.add(period_interest.div(1e9));
        }
        return amount_staked;
    }

    function calculatePeriods(uint256 _stakeID) public view returns (uint256){
		
		address _account	=	_msgSender();
        Stake memory _stake = stake[_account][_stakeID];
		
        uint256 creation_time = _stake.stake_creation_time;
        uint256 current_time = block.timestamp;

        uint256 total_period = current_time.sub(creation_time);

        uint256 periods = total_period.div(_INTEREST_PERIOD);

        return periods;
    }

    function calculateAccountStakePeriods(address _account, uint256 _stakeID) public view returns (uint256){
        Stake memory _stake = stake[_account][_stakeID];
		
        uint256 creation_time = _stake.stake_creation_time;
        uint256 current_time = block.timestamp;

        uint256 total_period = current_time.sub(creation_time);

        uint256 periods = total_period.div(_INTEREST_PERIOD);

        return periods;
    }

    function getInterestValue(address _account) internal view returns (uint256 interest){
        
		uint256 bronzebalance 	=	wonkabronze.balanceOf(_account);
		uint256 silverbalance 	=	wonkasilver.balanceOf(_account);
		uint256 goldbalance 	=	wonkagold.balanceOf(_account);
		uint256 tokenbalance 	=	wonkacapital.balanceOf(_account);
		uint256 vesting 		=	wonkacapital.getVestingFee(_account);
		string memory is_vesting=	"nonvesting";
		if(vesting>0){// is vesting
			is_vesting 	=	"vesting";	
		}
		if(goldbalance>0){
			return interests['gold'][is_vesting] * 1e9;
		}
		if(silverbalance>0){
			return interests['silver'][is_vesting] * 1e9;
		}
		if(bronzebalance>0){
			return interests['bronze'][is_vesting] * 1e9;
		}
		if(tokenbalance>0){
			return interests['token'][is_vesting] * 1e9;
		}
    }
}