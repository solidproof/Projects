// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ICOVesting is Ownable {
    using SafeMath for uint256;
    struct Vesting {
        uint256 amount;
        uint256 cliff;
        uint256 TGEUnlockPercentage;
        uint256 monthlyUnlockPercentage;
        uint256 lastClaimTime;
        uint256 totalClaimed;
    }
    mapping(address => Vesting) public vesting;
    mapping(address => bool) public TGEClaimed;
    IERC20 public token;
    bool isLocked;
    uint256 public tgeLaunchTime;
    
    

    constructor()  {
       token = IERC20(0xd9145CCE52D386f254917e481eB44e9943F39138); // replace with PNS address
       tgeLaunchTime = 1674398553;
    }

    /// Reentrancy Gaurd modifier
    
    modifier nonReentrant (){
       isLocked = true;
       _;
       isLocked = false;
    }

    /// _user: wallet address to assign total tokens. eg. 100 (100 tokens), 
    /// _amount: Total Amount that will distributed to above _user. 100 (means 100 tokens with 6 decimals)
    /// _cliff: cliff amount in days. for 1 year input will be 365.
    /// _monthlyUnlockPercentage: percentage of total amount unlocked per quarter once cliff is over. eg 20(20 percent)

    function addVesting(address  _user, uint256 _amount, uint256 _cliff, uint256 _TGEUnlockPercentage, uint256 _monthlyUnlockPercentage) external onlyOwner {
        vesting[_user] = Vesting(_amount*1e6, tgeLaunchTime + _cliff * 1 days , _TGEUnlockPercentage, _monthlyUnlockPercentage, 0, 0);

    }

    /// does the same as add vesting (used to add multiple accounts, 
    ///amounts at same time with same cliff time and same unlock percentage)


    function addVestingMultiple (address [] calldata _users, uint256 [] calldata _amounts, uint256 _cliff, uint256 _TGEUnlockPercentage, uint256 _monthlyUnlockPercentage) external onlyOwner {
        require(_users.length == _amounts.length, "users and amounts array length should be same");
        for (uint256 i=0; i<_users.length; i++){
         vesting[_users[i]] = Vesting(_amounts[i] * 1e6, tgeLaunchTime + _cliff * 1 days, _TGEUnlockPercentage, _monthlyUnlockPercentage, 0, 0);
        }
    }
    
    /// function to claimTGEAmount

    function claimTGEAmount (address _recipient ) public nonReentrant {
                Vesting memory user = vesting[_recipient];
                require (block.timestamp > tgeLaunchTime, "Not Launched yet" );
                require (!TGEClaimed[_recipient], "TGE amount already claimed");
                uint256 lockedAmount = user.amount.mul(100 - user.TGEUnlockPercentage).div(100);
                uint256 unlockedAmount =user.amount.sub(lockedAmount);
                TGEClaimed[_recipient] = true;
                user.totalClaimed += unlockedAmount;
                vesting[_recipient] = user;
                token.transfer(_recipient, unlockedAmount);


    }

    /// function to change TGE Amount 
    function setTGE(uint256 timestamp) external onlyOwner {
        require (timestamp > block.timestamp, "TGE can be set in future time only");
        tgeLaunchTime = timestamp;
    }

    /// user can claim unlocked tokens as soon as cliff time passes.
    /// it's compatible with chainlink automation, to automate the distribution
    /// so users don't need to claim manually.

    function claim (address [] calldata users) external nonReentrant {
        for (uint256 i = 0; i < users.length; i++) {
            _claim(users[i]);
        }       
    }

    function _claim(address  _recipient) internal {
        Vesting memory user = vesting[_recipient];
        require(block.timestamp >= user.cliff, "Cliff has not passed yet");
        uint256 lockedAmount = user.amount.mul(100 - user.monthlyUnlockPercentage).div(100);
        uint256 unlockedAmount =user.amount.sub(lockedAmount);
        uint256 months = 30 days;
        require(block.timestamp >= user.lastClaimTime + 1 * months, "You can claim once only per month");
        require(user.amount - user.totalClaimed >= 0, "Already claimed all tokens");
        user.lastClaimTime = block.timestamp;
        user.totalClaimed += unlockedAmount;
        vesting[_recipient] = user;
        token.transfer(_recipient,unlockedAmount);
    }
}
