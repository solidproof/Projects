// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract researchAndDevelopmentVesting is Ownable {
    using SafeMath for uint256;
    struct Vesting {
        uint256 amount;
        uint256 cliff;
        uint256 quarterlyUnlockPercentage;
        uint256 lastClaimTime;
        uint256 totalClaimed;
    }
    mapping(address => Vesting) public vesting;
    IERC20 public token;
    bool isLocked;
    event QuartelyAmountClaimed (address indexed user, uint256 amount);

    constructor()  {
       token = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // replace with PNS address
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
    /// _quarterlyUnlockPercentage: percentage of total amount unlocked per quarter once cliff is over. eg 20(20 percent)

    function addVesting(address  _user, uint256 _amount, uint256 _cliff, uint256 _quarterlyUnlockPercentage) external onlyOwner {
        require (_user != address(0), "Can't add zero address");
        vesting[_user] = Vesting(_amount*1e6, block.timestamp + _cliff * 1 days, _quarterlyUnlockPercentage, 0, 0);

    }

    /// does the same as add vesting (used to add multiple accounts, 
    ///amounts at same time with same cliff time and same unlock percentage)


    function addVestingMultiple (address [] calldata _users, uint256 [] calldata _amounts, uint256 _cliff, uint256 _quarterlyUnlockPercentage) external onlyOwner {
        require(_users.length == _amounts.length, "users and amounts array length should be same");
        for (uint256 i=0; i<_users.length; i++){
            require (_users[i] != address(0), "Can't add zero address");
         vesting[_users[i]] = Vesting(_amounts[i] * 1e6, block.timestamp + _cliff * 1 days, _quarterlyUnlockPercentage, 0, 0);
        }
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
        uint256 lockedAmount = user.amount.mul(100 - user.quarterlyUnlockPercentage).div(100);
        uint256 unlockedAmount = user.amount.sub(lockedAmount);
        uint256 months = 30 days;
        require(block.timestamp >= user.lastClaimTime + 3 * months, "You can claim only every quarter");
        require(user.amount - user.totalClaimed >= 0, "Already claimed all tokens");
        user.lastClaimTime = block.timestamp;
        user.totalClaimed += unlockedAmount;
        vesting[_recipient] = user;  
        token.transfer(_recipient,unlockedAmount);
        emit QuartelyAmountClaimed(_recipient, unlockedAmount);
    }
}
