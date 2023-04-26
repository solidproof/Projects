// SPDX-License-Identifier: MIT



pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./test.sol";
import "./ITEST.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TestFarm is Ownable {
    // emit payment events

    event IERC20TransferEvent(IERC20 indexed token, address to, uint256 amount);
    event IERC20TransferFromEvent(IERC20 indexed token, address from, address to, uint256 amount);

    //safeMathuse
    using SafeMath for uint256;


    //variables

    ITEST private test;
    IERC20 private usdc;

    address private pair;
    address public treasury;
    address private burn;

    uint256 private dailyInterest;
    uint256 private nodeCost;
    uint256 private nodeBase;
    uint256 public bondDiscount;

    uint256 public claimTaxTest = 8;
    uint256 public claimTaxBond = 12;
    uint256 public bondNodeStartTime;

    bool public isLive = false;
    uint256 totalNodes = 0;

    //Array

    address [] public farmersAddresses;

    //Farmers Struct

    struct Farmer {
        bool exists;
        uint256 testNodes;
        uint256 bondNodes;
        uint256 claimsTest;
        uint256 claimsBond;
        uint256 lastUpdate;
        
    }

    //mappings

    mapping(address => Farmer) private farmers;

    //constructor

    constructor (
        address _test, //address of a standard erc20 to use in the platform
        address _usdc, //address of an erc20 stablecoin
        address _pair, //address of potential liquidity pool 
        address _treasury, //address of a treasury wallet to hold fees and taxes
        uint256 _dailyInterest, //dailyInterest
        uint256 _nodeCost, //Cost of a node in $TEST
        uint256 _bondDiscount //% of discount of the bonding      
    ) {
        test = ITEST(_test);
        usdc = IERC20(_usdc);
        pair = _pair;
        treasury = _treasury;
        dailyInterest = _dailyInterest;
        nodeCost = _nodeCost.mul(1e18);
        nodeBase = SafeMath.mul(10, 1e18);
        bondDiscount = _bondDiscount;
    }

    //Price Checking Functions

    function getTestBalance() external view returns (uint256) {
	return test.balanceOf(pair);
    }

    function getUSDCBalance() external view returns (uint256) {
	return usdc.balanceOf(pair);
    }

    function getPrice() public view returns (uint256) {
        uint256 testBalance = test.balanceOf(pair);
        uint256 usdcBalance = usdc.balanceOf(pair);
        require(testBalance > 0, "divison by zero error");
        uint256 price = usdcBalance.mul(1e30).div(testBalance);
        return price;
    }

    //Bond Setup

    function getBondCost() private view returns (uint256) {
        uint256 tokenPrice = getPrice();
        uint256 basePrice = nodeCost.mul(tokenPrice).div(1e18).div(1e12);
        uint256 discount = SafeMath.sub(100, bondDiscount);
        uint256 bondPrice = basePrice.mul(discount).div(100);
        return bondPrice;
    }

    function setBondDiscount(uint256 newDiscount) public onlyOwner {
        require(newDiscount <= 75, "Discount above limit");
        bondDiscount = newDiscount;
    }

    //Set Addresses

    function setTreasuryAddr(address treasuryAddress) public onlyOwner {
        treasury = treasuryAddress;
    }
    function setTestAddr(address testaddress) public onlyOwner {
        test = ITEST(testaddress);
    }
    function setTestTax(uint256 _claimTaxTest) public onlyOwner {
        claimTaxTest = _claimTaxTest;
    }

    function setBondTax(uint256 _claimTaxBond) public onlyOwner {
        claimTaxBond = _claimTaxBond;
    }

    //Platform Settings

    function setPlatformState(bool _isLive) public onlyOwner {
        isLive = _isLive;
    }
    function setDailyInterest(uint256 _dailyInterest) public onlyOwner {
        dailyInterest = _dailyInterest;
    }


    function updateAllClaims() internal {
        uint256 i;
        for(i=0; i<farmersAddresses.length; i++){
            address _address = farmersAddresses[i];
            updateClaims(_address);
        }
    }
    

    function setBondNodeStartTime(uint256 _newStartTime) external onlyOwner {
    bondNodeStartTime = _newStartTime;
}

    //Node management - Buy - Claim - Bond - User front

    function buyNode(uint256 _amount) external payable {  
        require(isLive, "Platform is offline");
        uint256 nodesOwned = farmers[msg.sender].testNodes + farmers[msg.sender].bondNodes + _amount;
        require(nodesOwned < 101, "Max Rabbits Owned");
        Farmer memory farmer;
        if(farmers[msg.sender].exists){
            farmer = farmers[msg.sender];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(msg.sender);
        }
        uint256 transactionTotal = nodeCost.mul(_amount);
        test.burn(msg.sender , transactionTotal);
        farmers[msg.sender] = farmer;
        updateClaims(msg.sender);
        farmers[msg.sender].testNodes += _amount;
        totalNodes += _amount;
    }

    function bondNode(uint256 _amount) external payable {
        require(isLive, "Platform is offline");
        require(block.timestamp >= bondNodeStartTime, "BondNode not available yet");
        uint256 nodesOwned = farmers[msg.sender].testNodes + farmers[msg.sender].bondNodes + _amount;
        require(nodesOwned < 101, "Max Rabbits Owned");
        Farmer memory farmer;
        if(farmers[msg.sender].exists){
            farmer = farmers[msg.sender];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(msg.sender);
        }
        uint256 usdcAmount = getBondCost(); 
        uint256 transactionTotal = usdcAmount.mul(_amount);
        _transferFrom(usdc, msg.sender, address(treasury), transactionTotal);
        farmers[msg.sender] = farmer;
        updateClaims(msg.sender);
        farmers[msg.sender].bondNodes += _amount;
        totalNodes += _amount;
    }

    function awardNode(address _address, uint256 _amount) public onlyOwner {
        uint256 nodesOwned = farmers[_address].testNodes + farmers[_address].bondNodes + _amount;
        require(nodesOwned < 101, "Max Rabbits Owned");
        Farmer memory farmer;
        if(farmers[_address].exists){
            farmer = farmers[_address];
        } else {
            farmer = Farmer(true, 0, 0, 0, 0, 0);
            farmersAddresses.push(_address);
        }
        farmers[_address] = farmer;
        updateClaims(_address);
        farmers[_address].testNodes += _amount;
        totalNodes += _amount;
        farmers[_address].lastUpdate = block.timestamp;
    }

    function compoundNode() public {
        uint256 pendingClaims = getTotalClaimable();
        uint256 nodesOwned = farmers[msg.sender].testNodes + farmers[msg.sender].bondNodes;
        require(pendingClaims>nodeCost, "Not enough pending Test to compound");
        require(nodesOwned < 100, "Max Rabbits Owned");
        updateClaims(msg.sender);
        if (farmers[msg.sender].claimsTest > nodeCost) {
            farmers[msg.sender].claimsTest -= nodeCost;
            farmers[msg.sender].testNodes++;
        } else {
            uint256 difference = nodeCost - farmers[msg.sender].claimsTest;
            farmers[msg.sender].claimsTest = 0;
            farmers[msg.sender].claimsBond -= difference;
            farmers[msg.sender].bondNodes++;
        }
        totalNodes++;
    }

    function updateClaims(address _address) internal {
        uint256 time = block.timestamp;
        uint256 timerFrom = farmers[_address].lastUpdate;
        if (timerFrom > 0)
            farmers[_address].claimsTest += farmers[_address].testNodes.mul(nodeBase).mul(dailyInterest).mul((time.sub(timerFrom))).div(8640000);
            farmers[_address].claimsBond += farmers[_address].bondNodes.mul(nodeBase).mul(dailyInterest).mul((time.sub(timerFrom))).div(8640000);
            farmers[_address].lastUpdate = time;
    }

    function getTotalClaimable() public view returns (uint256) {
        uint256 time = block.timestamp;
        uint256 pendingTest = farmers[msg.sender].testNodes.mul(nodeBase).mul(dailyInterest).mul((time.sub(farmers[msg.sender].lastUpdate))).div(8640000);
        uint256 pendingBond = farmers[msg.sender].bondNodes.mul(nodeBase.mul(dailyInterest.mul((time.sub(farmers[msg.sender].lastUpdate))))).div(8640000);
        uint256 pending = pendingTest.add(pendingBond);
        return farmers[msg.sender].claimsTest.add(farmers[msg.sender].claimsBond).add(pending);
	}

    function getTaxEstimate() external view returns (uint256) {
        uint256 time = block.timestamp;
        uint256 pendingTest = farmers[msg.sender].testNodes.mul(nodeBase).mul(dailyInterest).mul((time.sub(farmers[msg.sender].lastUpdate))).div(8640000);
        uint256 pendingBond = farmers[msg.sender].bondNodes.mul(nodeBase).mul(dailyInterest).mul((time.sub(farmers[msg.sender].lastUpdate))).div(8640000);
        uint256 claimableTest = pendingTest.add(farmers[msg.sender].claimsTest); 
        uint256 claimableBond = pendingBond.add(farmers[msg.sender].claimsBond); 
        uint256 taxTest = claimableTest.div(100).mul(claimTaxTest);
        uint256 taxBond = claimableBond.div(100).mul(claimTaxBond);
        return taxTest.add(taxBond);
	}

    function calculateTax() public returns (uint256) {
        updateClaims(msg.sender); 
        uint256 taxTest = farmers[msg.sender].claimsTest.div(100).mul(claimTaxTest);
        uint256 taxBond = farmers[msg.sender].claimsBond.div(100).mul(claimTaxBond);
        uint256 tax = taxTest.add(taxBond);
        return tax;
    }


    function claim() external payable {

        // ensure msg.sender is sender

        require(farmers[msg.sender].exists, "sender must be registered farmer to claim yields");

        uint256 tax = calculateTax();
		uint256 reward = farmers[msg.sender].claimsTest.add(farmers[msg.sender].claimsBond);
        uint256 toBurn = tax;
        uint256 toFarmer = reward.sub(tax);
		if (reward > 0) {
            farmers[msg.sender].claimsTest = 0;		
            farmers[msg.sender].claimsBond = 0;
            test.mint(msg.sender, toFarmer);
            test.burn(msg.sender, toBurn);
		}
	}

    //Platform Info

    function currentDailyRewards() external view returns (uint256) {
        uint256 dailyRewards = nodeBase.mul(dailyInterest).div(100);
        return dailyRewards;
    }

    function getOwnedNodes() external view returns (uint256) {
        uint256 ownedNodes = farmers[msg.sender].testNodes.add(farmers[msg.sender].bondNodes);
        return ownedNodes;
    }

    function getTotalNodes() external view returns (uint256) {
        return totalNodes;
    }
    // SafeERC20 transferFrom 
    function _transferFrom(IERC20 token, address from, address to, uint256 amount) private {
        SafeERC20.safeTransferFrom(token, from, to, amount);
        // log transferFrom to blockchain
        emit IERC20TransferFromEvent(token, from, to, amount);
    }

}