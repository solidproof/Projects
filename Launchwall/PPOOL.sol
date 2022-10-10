// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.17;

// ===== Start: Imports =====

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "ZERO ADDRESS");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}

// ===== End: Imports =====


contract PPool is Context, Ownable {
    using SafeMath for uint256;

    receive() external payable {}
    fallback() external payable {}

    // DATA STRUCTURES
    struct User {
        uint256 predictionAmount; //
        uint256 claimedAmount;
        uint256 predictionType; // 0:empty, 1:yes, 2:no
    }

    struct UserStats {
        uint256 totalAmountPredicted;
        uint256 totalAmountClaimed;
        uint256[] predictionsAped;
    }

    struct TotalStats {
        uint256 totalAmountPredicted;
        uint256 totalTimesPredicted;
        uint256 totalAmountToBuyback;
        uint256 percentBuyback;
        uint256 nextId;
    }

    struct Prediction {
        uint256 id;

        string link;
        string name;

        uint256 yesAmount;
        uint256 noAmount;
        uint256 totalAmount;

        uint256 status; // 0:accepting, 1:closed, 2:yes, 3:no, 4:cancelled
        uint256 contributors; // number of contributors

        uint256 creationTime;

        mapping (address => User) usersAped;
    }

    mapping (uint256 => Prediction) public predictions;
    mapping (address => UserStats) public users;
    TotalStats public totalStats;
    
    constructor() {
        totalStats = TotalStats(0,0,0,10,0); // init values of totalStats
    }

    // EVENTS
    event updateBuybackPercentEvent(uint256 percentBuyback_);
    event createPredictionEvent(string link_, string name_, uint256 id_);
    event updatePredictionStatusEvent(uint256 id_, uint256 status_);
    event apePredictionEvent(uint256 id_, uint256 amount_, bool type_, address user_);
    event claimPredictionEvent(uint256 id_, uint256 amount_, address user_);

    // FUNCTIONS

    // ===== Start: Owner Functions =====
    function updateBuybackPercent(uint256 percentBuyback_) external onlyOwner {
        totalStats.percentBuyback = percentBuyback_;
        emit updateBuybackPercentEvent(percentBuyback_);
    }

    function createPrediction(string memory link_, string memory name_) external onlyOwner {
        Prediction storage newPrediction = predictions[totalStats.nextId];
        newPrediction.id = totalStats.nextId;
        newPrediction.link = link_;
        newPrediction.name = name_;
        newPrediction.creationTime = block.timestamp;

        emit createPredictionEvent(link_, name_, totalStats.nextId);
        totalStats.nextId++;
    }

    function updatePredictionStatus(uint256 id_, uint256 status_) external onlyOwner {
        require(predictions[id_].status < 2, "prediction over");
        require(status_ < 5, "too high");

        if (status_ == 2 || status_ == 3) {
            require(predictions[id_].yesAmount != 0 && predictions[id_].noAmount != 0, "0-side"); // check for no empty side
            predictions[id_].status = status_;

            uint256 toBuyback = predictions[id_].totalAmount.mul(totalStats.percentBuyback).div(100);
            totalStats.totalAmountToBuyback += toBuyback; // update app stats for total amount to buyback
            payable(owner()).transfer(toBuyback);
        } else {
            predictions[id_].status = status_;
        }

        emit updatePredictionStatusEvent(id_, status_);
    }
    // ===== End: Owner Functions =====


    // ===== Start: User Functions =====
    function apePrediction(uint256 id_, uint256 amount_, bool type_) external payable {
        require(id_ < totalStats.nextId, "id"); // check prediction exists
        require(predictions[id_].status == 0, "status"); // check prediction accepting
        require(msg.sender.balance >= amount_, "insuff"); // check sufficient user balance
        require(msg.value == amount_, "incorrect sent"); // check amount_ sent
        
        if (type_) { // if aping "yes"
            require(predictions[id_].usersAped[msg.sender].predictionType != 2, "single-side no"); // check didn't predict "no" prior
            predictions[id_].yesAmount += amount_; // update prediction "yes" amount

            if (predictions[id_].usersAped[msg.sender].predictionType == 0) { // if 1st user ape for this prediction
                predictions[id_].usersAped[msg.sender].predictionType = 1; // update predction type for user
                users[msg.sender].predictionsAped.push(id_); // add prediction id to history of user predictions
                predictions[id_].contributors++ ; // update contributor number
            }
        } else { // if aping "no"
            require(predictions[id_].usersAped[msg.sender].predictionType != 1, "single-side yes"); // check didn't predict "yes" prior
            predictions[id_].noAmount += amount_; // update prediction "no" amount

            if (predictions[id_].usersAped[msg.sender].predictionType == 0) { // if 1st user ape for this prediction
                predictions[id_].usersAped[msg.sender].predictionType = 2; // update predction type for user
                users[msg.sender].predictionsAped.push(id_); // add prediction id to history of user predictions
                predictions[id_].contributors++ ; // update contributor number
            }
        }

        predictions[id_].usersAped[msg.sender].predictionAmount += amount_; // update user prediction amount
        predictions[id_].totalAmount += amount_; // update prediction amount
        users[msg.sender].totalAmountPredicted += amount_; // update user stats for total amount predicted

        totalStats.totalAmountPredicted += amount_; // updated app stats for total amount predicted
        totalStats.totalTimesPredicted++; // update app stats for total times predicted
        emit apePredictionEvent(id_, amount_, type_, msg.sender);
    }

    function claimPrediction(uint256 id_) external {
        require(predictions[id_].status > 1, "not claimable");
        require(predictions[id_].usersAped[msg.sender].claimedAmount == 0, "already claimed"); // check if already claimed
        require(predictions[id_].usersAped[msg.sender].predictionAmount > 0, "no contribution"); // check if participated
        require( // require claimable only if user won / or if cancelled
            (predictions[id_].status == 2 && predictions[id_].usersAped[msg.sender].predictionType == 1) || // if YES won & user aped YES
            (predictions[id_].status == 3 && predictions[id_].usersAped[msg.sender].predictionType == 2) || // if NO won & user aped NO
            (predictions[id_].status == 4), // if cancelled
            "lost"            
        ); 

        uint256 total = predictions[id_].totalAmount.mul(100-totalStats.percentBuyback).div(100);

        // if YES won & user aped YES
        if (predictions[id_].status == 2 && predictions[id_].usersAped[msg.sender].predictionType == 1) {
            // (user prediction / yes amount) * total
            uint256 claimed = predictions[id_].usersAped[msg.sender].predictionAmount.mul(total).div(predictions[id_].yesAmount);
            predictions[id_].usersAped[msg.sender].claimedAmount = claimed;

            payable(msg.sender).transfer(claimed);
            emit claimPredictionEvent(id_, claimed, msg.sender);
        }

        // if NO won & user aped NO
        if (predictions[id_].status == 3 && predictions[id_].usersAped[msg.sender].predictionType == 2) {
            // (user prediction / no amount) * total
            uint256 claimed = predictions[id_].usersAped[msg.sender].predictionAmount.mul(total).div(predictions[id_].noAmount);
            predictions[id_].usersAped[msg.sender].claimedAmount = claimed;

            payable(msg.sender).transfer(claimed);
            emit claimPredictionEvent(id_, claimed, msg.sender);
        }
        
        // if cancelled
        if (predictions[id_].status == 4) {
            uint256 claimed = predictions[id_].usersAped[msg.sender].predictionAmount;
            predictions[id_].usersAped[msg.sender].claimedAmount = claimed;

            payable(msg.sender).transfer(claimed);
            emit claimPredictionEvent(id_, claimed, msg.sender);
        }
    }

    // for safety, pools open longer than 4 weeks can be cancelled by anyone
    function fallbackCancel(uint256 id_) external {
        require(predictions[id_].creationTime + 4 weeks < block.timestamp, "Too early");
        require(predictions[id_].status <=2, "Already concluded");

        predictions[id_].status = 4;
    }
    // ===== End: User Functions =====


    // ===== Start: Data Functions =====
    // user data for given prediction
    function getUserPredictionData(uint256 id_, address user_) external view returns (User memory) {
        return predictions[id_].usersAped[user_];
    }

    // ===== End: Data Functions =====
} 