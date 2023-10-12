// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GoldDigger is Ownable, ReentrancyGuard {

    uint256 private INIT_SECOND_PERCENT = 320600;
    uint256 public INIT_MIN_DEPOSIT = 5; // 0.05 bnb 
    uint256 public INIT_MIN_REINVEST = 10; // 10 pickaxes
    uint256 public INIT_MIN_WITHDRAWAL = 1; // 0.01 bnb 
    uint128 private INIT_REF_INCREASED = 940;
    uint256 private INIT_REF_LIMIT = 116000;
    uint256[2] private AFFILIATE_PERCENTS_pickaxe = [60, 15];
    uint256[2] private AFFILIATE_PERCENTS_BNB = [40, 10];



    bool public gameStarted;
    uint256 public timestampGameStarted;

    address public defaultRef = 0xaAb5cf19B0D0002221C5723c5616a09F434fc036;
    uint256 public totalInvested;
    uint256 public totalInvestors;

    struct User {
        uint256 deposit;
        uint256 reinvested;
        uint256 earned;
        uint256 withdrawn;
        uint256 gold;
        uint256 pickaxe;
        uint256 timestamp;
        address partner;
        uint256 refsTotal;
        uint256 refs1level;
        uint256 refearnBNB;
        uint256 refearnpickaxe; 
        uint256 percentage;
        uint256 leaderBonus;

    }
    
    mapping(address => User) public user;


    constructor() {
        renounceOwnership();
    }

    event ChangeUser(address indexed user, address indexed partner, uint256 amount);

    receive() external payable {}

    function _calcInitMaxDeposit() public view returns(uint) {
        if(block.timestamp >= timestampGameStarted && block.timestamp <= timestampGameStarted + 7 days  ) return 500;
        if(block.timestamp >= timestampGameStarted && block.timestamp <= timestampGameStarted + 14 days  ) return 1000;
        if(block.timestamp >= timestampGameStarted && block.timestamp <= timestampGameStarted + 21 days  ) return 2000;
        if(block.timestamp >= timestampGameStarted && block.timestamp <= timestampGameStarted + 28 days  ) return 100000000;
    }

    function HireMiner(address partner) external payable nonReentrant {
        uint amount = msg.value;
        require(_msgSender() == tx.origin, "Function can only be called by a user account");
        require(amount >= (INIT_MIN_DEPOSIT * 10000000000000000), "Min deposit is 0.05 bnb");
        if(!gameStarted) {
            timestampGameStarted = block.timestamp;
            gameStarted = true;
        }
        require((user[_msgSender()].deposit + amount) < (_calcInitMaxDeposit() * 10000000000000000), "Max deposit limit has been exceeded");
    
        _updateprePayment(_msgSender());
        totalInvested += amount;
        totalInvestors += 1;
        user[_msgSender()].deposit += amount;

        if (user[_msgSender()].percentage == 0) {
            require(partner != _msgSender(), "Cannot set your own address as partner");
            address ref = partner;
            user[ref].refs1level++;
            user[ref].refsTotal++;
            user[user[ref].partner].refsTotal++;
            user[_msgSender()].partner = ref;
            user[_msgSender()].percentage = INIT_SECOND_PERCENT;
            _updatePercentage(ref);
        }

        emit ChangeUser(_msgSender(), user[_msgSender()].partner, user[_msgSender()].deposit);

        // REF
        _traverseTree(user[_msgSender()].partner, amount);
        
        // OWNER FEE
        uint256 feepickaxe = (amount * 3) / 100 * 10;
        user[defaultRef].pickaxe += feepickaxe;
        uint256 feeBNB = (amount * 5) / 100;
         (bool sent,) = defaultRef.call{value: feeBNB}("");
        require(sent, "Failed to send Ether");
        
        
    }
    function Reinvest(uint256 amount) external nonReentrant {
        require(_msgSender() == tx.origin, "Function can only be called by a user account");
        require(amount >= (INIT_MIN_REINVEST * 1000000000000000000), "Min reinvest is 10 pickaxe"); // do equal for 005 bnb
        _updateprePayment(_msgSender());
        require(amount <= user[_msgSender()].pickaxe, "Insufficient funds");
        user[_msgSender()].pickaxe -= amount;
        user[_msgSender()].deposit += amount / 10;
        user[_msgSender()].reinvested += amount / 10;
        emit ChangeUser(_msgSender(), user[_msgSender()].partner, user[_msgSender()].deposit);
    }

    function ReinvestGold(uint256 amount) external nonReentrant {
        require(_msgSender() == tx.origin, "Function can only be called by a user account");
        require(amount >= (INIT_MIN_REINVEST * 1000000000000000000), "Min reinvest is 10 gold");
        _updateprePayment(_msgSender());
        require(amount <= user[_msgSender()].gold, "Insufficient funds");
        user[_msgSender()].gold -= amount;
        user[_msgSender()].deposit += amount;
        user[_msgSender()].reinvested += amount;
        emit ChangeUser(_msgSender(), user[_msgSender()].partner, user[_msgSender()].deposit);
    }

    function Withdraw(uint256 amount) external nonReentrant {
        require(_msgSender() == tx.origin, "Function can only be called by a user account");
        require(amount > (INIT_MIN_WITHDRAWAL * 10000000000000000), "Min withdrawal is 0.01 bnb");
        _updateprePayment(_msgSender());
        require(amount <= user[_msgSender()].gold, "Insufficient funds");
        user[_msgSender()].gold -= amount;
        user[_msgSender()].withdrawn += amount;
         (bool sent,) = _msgSender().call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    function checkReward(address account) public view returns(uint256) {
        uint256 RewardTime = block.timestamp - user[account].timestamp;
        return (((user[account].deposit / 100 * user[account].percentage) / 10000000000) * RewardTime);

    }


    function _updateprePayment(address account) internal {
        uint256 pending = checkReward(_msgSender());
        user[account].timestamp = block.timestamp;
        user[account].gold += pending;
        user[account].earned += pending;
    }

    function _traverseTree(address account, uint256 value) internal {
        if (value != 0) {
            for (uint8 i; i < 2; i++) {

                uint256 feeBNB = ((value * AFFILIATE_PERCENTS_BNB[i]) / 1000);
                uint256 feepickaxe = ((value * AFFILIATE_PERCENTS_pickaxe[i]) / 1000) * 10;

                user[account].gold += feeBNB;
                user[account].pickaxe += feepickaxe;

                user[account].refearnBNB += feeBNB;
                user[account].refearnpickaxe += feepickaxe;

                account = user[account].partner;
            }
        }
    }

    function _updatePercentage(address account) internal {
        if((user[account].leaderBonus + INIT_REF_INCREASED) < INIT_REF_LIMIT) {
            if(user[account].percentage > 0) {
                user[account].percentage += INIT_REF_INCREASED;
                user[account].leaderBonus += INIT_REF_INCREASED;
            }
        }
    }


}