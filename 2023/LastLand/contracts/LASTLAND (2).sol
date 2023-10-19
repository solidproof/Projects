/**
 *Submitted for verification at BscScan.com on 2023-10-17
*/

// SPDX-License-Identifier: MIT
//9ecc02a53f8032a599c51cbc7f7c474835c40cb0e92543f7995708cce9e06df9

pragma solidity ^0.8.0;


contract ForgeManager {

    using SafeMath for uint256;

    struct Forge {
        uint256 checkpoint;
        uint256 depositedAmount;
        uint256 harvestableAmount;
        uint256 lockedAmount;
        uint256 unlockTime;
    }

    uint256 constant public DAILY_ROI = 8; //0.8%
    uint256 constant public PERCENT_DIVIDER = 1000;

    uint256 constant public TIME_STEP = 24 hours;

    mapping(address => Forge) public forges; 

    event onDeposit(address indexed userAddr, uint256 amount, uint256 time);
    event onUnlock(address indexed userAddr, uint256 amount, uint256 time);
    event onHarvest(address indexed userAddr, uint256 amount, uint256 time);
    event onUnstake(address indexed userAddr, uint256 amount, uint256 time);


    function deposit(uint256 amount, address userAddr) internal {
        syncForge(userAddr);

        forges[userAddr].depositedAmount = forges[userAddr].depositedAmount.add(amount);
        forges[userAddr].checkpoint = block.timestamp;

        emit onDeposit(userAddr,amount,block.timestamp);
    }

    function syncForge(address userAddr) internal {
        uint256 dividends = getForgeDividends(userAddr);

        if(dividends > 0) {
            forges[userAddr].harvestableAmount = forges[userAddr].harvestableAmount.add(dividends);
        }
    }

    function unlock(address userAddr) internal {
        require(forges[userAddr].depositedAmount > 0, "nothing to unlock");

        syncForge(userAddr);

        Forge storage forge = forges[userAddr];

        forge.lockedAmount = forge.lockedAmount.add(forge.depositedAmount);
        forge.depositedAmount = 0;

        forge.unlockTime = block.timestamp.add(24 hours);

        emit onUnlock(userAddr, forge.lockedAmount,block.timestamp);

    }

    function harvest(address userAddr) internal returns(uint256){
        uint256 dividends = getForgeDividends(userAddr);
        uint256 claimableAmount = getClaimableAmount(userAddr);
        uint256 harvestableAmount = forges[userAddr].harvestableAmount;

        require(dividends.add(claimableAmount).add(harvestableAmount) > 0, "nothing to harvest");

        forges[userAddr].checkpoint = block.timestamp;
        
        if(harvestableAmount > 0) {
            dividends = dividends.add(harvestableAmount);
            forges[userAddr].harvestableAmount = 0;
        }

        if(claimableAmount > 0) {
            uint256 unstakedAmount = unstake(userAddr);
            dividends = dividends.add(unstakedAmount);
        }


        emit onHarvest(userAddr, dividends, block.timestamp);

        return dividends;

    }

    function unstake(address userAddr) internal returns(uint256){
        uint256 claimableAmount = getClaimableAmount(userAddr);

        forges[userAddr].lockedAmount = 0;

        emit onUnstake(userAddr, claimableAmount, block.timestamp);

        return claimableAmount;

    }

    function getClaimableAmount(address userAddr) public view returns(uint256){
        return block.timestamp >= forges[userAddr].unlockTime ? forges[userAddr].lockedAmount : 0; 
    }

    function getForgeDividends(address userAddr) public view returns(uint256 totalAmount){
        Forge memory forge = forges[userAddr];
        uint256 share = forge.depositedAmount.mul(DAILY_ROI).div(PERCENT_DIVIDER);

        uint256 from = forge.checkpoint;
        uint256 to = block.timestamp;

        totalAmount = share.mul(to.sub(from)).div(TIME_STEP);

    }

    function getHarvestableAmount(address userAddr) public view returns(uint256) {
        uint256 dividends = getForgeDividends(userAddr);
        uint256 claimableAmount = getClaimableAmount(userAddr);

        uint256 totalAmount = dividends.add(claimableAmount).add(forges[userAddr].harvestableAmount);

        return totalAmount;
    }

    function getUnlockTimer(address userAddr) public view returns(uint256) {
        return block.timestamp >= forges[userAddr].unlockTime ? 0 : forges[userAddr].unlockTime.sub(block.timestamp);
    }

    function getForgeData(address userAddr) public view returns(uint256 metalInForge, uint256 harvestableMetal, uint256 lockedMetal, uint256 timer) {
        metalInForge = forges[userAddr].depositedAmount;
        harvestableMetal = getHarvestableAmount(userAddr);
        lockedMetal = forges[userAddr].lockedAmount;
        timer = getUnlockTimer(userAddr);

    }





}


contract LASTLAND is ForgeManager {
    using SafeMath for uint256;

    struct FuelTank {
        uint256 cost;
        uint256 capacity;
    }

    struct Car {
        uint8 _type;
        uint256 cost;
        uint256 productivity; //per hour
    }

    struct Partners {
        uint256[3] referrals;
        uint256[3] coinRewards;
        uint256[3] metalRewards;
        address referrer;
    }

    struct Balance {
        uint256 coins;
        uint256 metal;
    }

    struct Stats {
        uint256 totalDeposited;
        uint256 totalWithdrawn;
    }

    struct Wastelands {
        uint256 checkpoint;
        uint256 metalToGet;
        uint256 time;
    }

    struct Equipment {
        uint8 _type;
        uint256 cost;
        uint256 bonus;
    }

    struct User {
        Stats stats;
        Balance balance;
        Partners partners;
        Car[] cars;
        Equipment[] equipment;
        Wastelands wastelands;
        uint256 metalStorage;
        uint256 fuelTankLevel;
    }

    uint256 constant public PERCENTS_DIVIDER = 10_000;

    uint256 constant public MARKETING_FEE = 700; //7%
    uint256 constant public DEV_FEE = 300; // 3%

    uint256 constant public MIN_PURCHASE = 0.05 ether;

    uint256 constant public COINS_PRICE = 0.001 ether; // 1 BNB = 1000 COINS
    uint256 constant public METAL_PRICE = 0.00001 ether; // 1 BNB = 100000 METAL

    uint256 constant public REINVESTMENT_BONUS = 500; //5%

    mapping(address => User) public users;

    uint256 public totalStaked;
    uint256 public totalCars;
    uint256 public totalUsers;

    uint256 public launchTime;

    address private marketingFund;
    address private dev;

    event coinsBought(uint256 coins, address indexed userAddr, uint256 time);
    event carBought(uint8 _type, address indexed userAddr, uint256 time);
    event enteredInWastelands(address indexed userAddr, uint256 metalToGet, uint256 _hours);
    event metalClaimed(address indexed userAddr, uint256 amount, uint256 time);
    event fuelTankUpgraded(address indexed userAddr, uint256 lvl, uint256 time);
    event equipmentBought(address indexed userAddr, uint8 _type, uint256 time);
    event metalSold(address indexed userAddr, uint256 amount, uint256 time);


    constructor(uint256 time, address marketingAddr, address devAddr) {
        require(!isContract(marketingAddr));
        require(!isContract(devAddr));

        marketingFund = marketingAddr;
        dev = devAddr;

        launchTime = time;
    }


    function buyCoins(address referrer) public payable {
        require(isLaunched(), "contract hasn`t launched yet");
        require(msg.sender == tx.origin, "not allowed");
        require(msg.value >= MIN_PURCHASE,'insufficient amount');
        require(referrer != msg.sender, "wrong referrer"); 

        User storage user = users[msg.sender];

        payFee(msg.value);
        recordReferral(referrer,msg.sender);
        payRefFee(msg.sender,msg.value);

        if(user.stats.totalDeposited == 0) {
            totalUsers = totalUsers.add(1);
        }

        uint256 coinsAmount = fromBnbToCoins(msg.value);

        user.balance.coins = user.balance.coins.add(coinsAmount);
        user.stats.totalDeposited = user.stats.totalDeposited.add(msg.value);

        totalStaked = totalStaked.add(msg.value);

        emit coinsBought(coinsAmount, msg.sender, block.timestamp);

    }

    function buyCar(uint8 _type) public {
        require(_type > 0 && _type < 8, "wrong car type");

        Car memory car = getCarByType(_type);
        User storage user = users[msg.sender];

        require(user.balance.coins >= car.cost, "insufficient coins amount");

        user.balance.coins = user.balance.coins.sub(car.cost);
        user.cars.push(car);

        totalCars = totalCars.add(1);

        emit carBought(_type, msg.sender, block.timestamp);
    }  

    function enterWastelands(uint256 _hours) public {
        require(users[msg.sender].cars.length > 0, "user doesn`t have cars");
        require(!inWastelands(msg.sender), "cars are already in wastelands");
        require(_hours > 0, "wrong time");

        User storage user = users[msg.sender];

        FuelTank memory fuelTank = getFuelTankByLvl(user.fuelTankLevel);

        uint256 unixTimeInWastelands = _hours.mul(1 hours);

        require(unixTimeInWastelands <= fuelTank.capacity, "capacity not enough");

        syncStorage(msg.sender);

        (,,uint256 metalToGet) = getUserTotalProductivity(msg.sender,_hours); 

        user.wastelands.checkpoint = block.timestamp.add(unixTimeInWastelands);
        user.wastelands.metalToGet = metalToGet;
        user.wastelands.time = unixTimeInWastelands;


        emit enteredInWastelands(msg.sender, user.wastelands.metalToGet,_hours);



    }  

    function buyEquipment(uint8 _type) public {
        require(_type > 0 && _type < 13, "wrong equipment type");
        require(users[msg.sender].stats.totalDeposited != 0, "user not found");
        require(!hasEquipment(msg.sender, _type), "user already has an equipment of this type");

        Equipment memory equipment = getEquipmentByType(_type);

        require(users[msg.sender].balance.coins >= equipment.cost, "insufficient balance");

        users[msg.sender].balance.coins = users[msg.sender].balance.coins.sub(equipment.cost);
        users[msg.sender].equipment.push(equipment);


        emit equipmentBought(msg.sender, _type, block.timestamp);


    }

    function buyCoinsForMetal(uint256 amount) public {
        require(users[msg.sender].balance.metal >= amount, "amount exceeds balance");

        uint256 coins = fromMetalToCoins(amount);
        uint256 bonusCoins = coins.mul(REINVESTMENT_BONUS).div(PERCENTS_DIVIDER);

        users[msg.sender].balance.metal = users[msg.sender].balance.metal.sub(amount);
        users[msg.sender].balance.coins = users[msg.sender].balance.coins.add(coins).add(bonusCoins);

        uint256 bnbAmount = fromCoinsToBnb(coins);

        payFee(bnbAmount);

        emit coinsBought(coins.add(bonusCoins), msg.sender, block.timestamp);
    }

    function sellMetal(uint256 amount) public {
        require(users[msg.sender].balance.metal >= amount, "amount exceeds balance");

        uint256 payout = fromMetalToBnb(amount);

        users[msg.sender].balance.metal = users[msg.sender].balance.metal.sub(amount);
        users[msg.sender].stats.totalWithdrawn = users[msg.sender].stats.totalWithdrawn.add(payout);


        payable(msg.sender).transfer(payout);

        emit metalSold(msg.sender,amount,block.timestamp);

    }


    function claimMetal() public {

        uint256 claimableMetal = getClaimableMetalAmount(msg.sender);

        require( claimableMetal > 0, "nothing to claim");

        User storage user = users[msg.sender];

        user.metalStorage = 0;

        if(!inWastelands(msg.sender)) {
            user.wastelands.metalToGet = 0;
        }

        user.balance.metal = user.balance.metal.add(claimableMetal);

        emit metalClaimed(msg.sender, claimableMetal, block.timestamp);

    }

    function forgeMetal(uint256 amount) public {
        require(amount > 0, "wrong amount"); 
        require(users[msg.sender].balance.metal >= amount, "insufficient amount");

        users[msg.sender].balance.metal = users[msg.sender].balance.metal.sub(amount);
        
        deposit(amount,msg.sender);
    }

    function harvestForgedMetal() public {
        uint256 harvestedAmount = harvest(msg.sender);

        users[msg.sender].balance.metal = users[msg.sender].balance.metal.add(harvestedAmount);
    }

    function unlockMetal() public {
        unlock(msg.sender);
    }


    function syncStorage(address userAddr) internal {
        if(users[userAddr].wastelands.metalToGet > 0) {
            users[userAddr].metalStorage = users[userAddr].metalStorage.add(users[userAddr].wastelands.metalToGet);
        }
    }


    function upgradeFuelTank() public {

        User storage user = users[msg.sender];

        require(user.stats.totalDeposited != 0, "user not found");
        require(user.fuelTankLevel < 2, "fuel tank has max lvl");
        
        FuelTank memory fuelTank = getFuelTankByLvl(user.fuelTankLevel.add(1));

        require(user.balance.coins >= fuelTank.cost, "insufficient coins balance");

        user.balance.coins = user.balance.coins.sub(fuelTank.cost);
        user.fuelTankLevel = user.fuelTankLevel.add(1);

        emit fuelTankUpgraded(msg.sender,user.fuelTankLevel,block.timestamp);
    }

    function recordReferral(address referrer, address sender) internal {

        if(users[sender].partners.referrer == address(0)) {
            
            if(referrer != address(0) && users[referrer].stats.totalDeposited != 0) {
                users[sender].partners.referrer = referrer;
            } 

            address upline = users[sender].partners.referrer;


            for(uint8 i = 0; i < 3; i++) {
                    if(upline != address(0)) {
                        users[upline].partners.referrals[i] = users[upline].partners.referrals[i].add(1);
                        upline = users[upline].partners.referrer;
                    } else break;
            }
        }
    }

    function payRefFee(address sender, uint256 value) internal {

        if (users[sender].partners.referrer != address(0)) {

			address upline = users[sender].partners.referrer;

			for (uint8 i = 0; i < 3; i++) {  
				if (upline != address(0)) {
				
    					uint256 amount = value.mul(getRefRewards(i)).div(PERCENTS_DIVIDER);

                        uint256 coinsAmount = fromBnbToCoins(amount).div(2); //50% in coins
                        uint256 metalAmount = fromBnbToMetal(amount).div(2); //50% in metal

    					
    					users[upline].partners.coinRewards[i] = users[upline].partners.coinRewards[i].add(coinsAmount); 
                        users[upline].partners.metalRewards[i] = users[upline].partners.metalRewards[i].add(metalAmount); 
                        users[upline].balance.coins = users[upline].balance.coins.add(coinsAmount);
                        users[upline].balance.metal = users[upline].balance.metal.add(metalAmount);
				    
					
					upline = users[upline].partners.referrer;
				} else break;
			}

		}
    }


    function payFee(uint256 amount) internal {

        uint256 marketingFee = amount.mul(MARKETING_FEE).div(PERCENTS_DIVIDER);
        uint256 devFee = amount.mul(DEV_FEE).div(PERCENTS_DIVIDER);

        payable(marketingFund).transfer(marketingFee);
        payable(dev).transfer(devFee);

    }

    function getClaimableMetalAmount(address userAddr) public view returns(uint256) {


        return !inWastelands(userAddr) ? users[userAddr].metalStorage.add(users[userAddr].wastelands.metalToGet) : users[userAddr].metalStorage;
        
    }


    function getUserCarsProductivity(address userAddr, uint256 _hours) public view returns(uint256) {
        uint256 totalMetal;
        User memory user = users[userAddr];

        for(uint256 i = 0; i < user.cars.length; i++) {
            uint256 carRevenue = user.cars[i].productivity.mul(_hours);
            totalMetal = totalMetal.add(carRevenue);
        }

        return totalMetal;
    } 

    function getUserEquipmentBonus(address userAddr) public view returns(uint256) {
        uint256 totalBonus;
        User memory user = users[userAddr];

        for(uint256 i = 0; i < user.equipment.length; i++) {
            uint256 bonus = user.equipment[i].bonus;
            totalBonus = totalBonus.add(bonus);
        }

        return totalBonus;
    }

    function getUserTotalProductivity(address userAddr, uint256 _hours) public view returns(uint256 carsProductivity, uint256 bonusesProductivity, uint256 totalProductivity) {

        uint256 bonuses = getUserEquipmentBonus(userAddr);

        carsProductivity = getUserCarsProductivity(userAddr,_hours);
        bonusesProductivity = carsProductivity.mul(bonuses).div(PERCENTS_DIVIDER);
        totalProductivity = carsProductivity.add(bonusesProductivity);

    }


    function hasEquipment(address userAddr, uint8 _type) public view returns(bool){

        bool flag = false;

        for(uint256 i = 0; i < users[userAddr].equipment.length; i++) {
            if(users[userAddr].equipment[i]._type == _type) {
                flag = true;
                break;
            }
        }

        return flag;
    }


    function inWastelands(address userAddr) public view returns(bool) {
        return users[userAddr].wastelands.checkpoint >= block.timestamp;
    }

    function getRefRewards(uint8 index) internal pure returns(uint256) {
        return[700, 300, 100][index];
    }
     
    function isLaunched() public view returns(bool) {
        return block.timestamp >= launchTime;
    }

    function fromBnbToCoins(uint256 amount) public pure returns(uint256) {
        return amount.div(COINS_PRICE);
    }

    function fromBnbToMetal(uint256 amount) public pure returns(uint256) {
        return amount.div(METAL_PRICE);
    }

    function fromMetalToBnb(uint256 amount) public pure returns(uint256) {
        return amount.mul(METAL_PRICE);
    }

    function fromCoinsToBnb(uint256 amount) public pure returns(uint256) {
        return amount.mul(COINS_PRICE);
    }

    function fromMetalToCoins(uint256 amount) public pure returns(uint256) {
        return amount.div(100);
    }

    function getFuelTankByLvl(uint256 lvl) public pure returns(FuelTank memory) {
        if(lvl == 0) {
            return FuelTank(0, 4 hours);
        } else if(lvl == 1) {
            return FuelTank(150, 6 hours);
        } else {
            return FuelTank(300, 8 hours);
        }
    }

    function getEquipmentByType(uint8 _type) public pure returns(Equipment memory) {
        if(_type == 1) {
            return Equipment(_type, 25, 50); //type 1, cost 25 COINS, bonus +0.5% productivity
        } else if (_type == 2) {
            return Equipment(_type, 30, 60); //type 2, cost 30 COINS, bonus +0.6% productivity
        } else if (_type == 3) {
            return Equipment(_type, 45, 90); //type 3, cost 45 COINS, bonus +0.9% productivity
        } else if(_type == 4){
            return Equipment(_type, 35, 92); //type 4, cost 35 COINS, bonus +0.92% productivity
        } else if(_type == 5){
            return Equipment(_type, 45, 132); //type 5, cost 45 COINS, bonus +1.32% productivity
        } else if(_type == 6){
            return Equipment(_type, 65, 172); //type 6, cost 65 COINS, bonus +1.72% productivity
        } else if(_type == 7){
            return Equipment(_type, 50, 150); //type 7, cost 50 COINS, bonus +1.5% productivity
        } else if(_type == 8){
            return Equipment(_type, 60, 180); //type 8, cost 60 COINS, bonus +1.8% productivity
        } else if(_type == 9){
            return Equipment(_type, 90, 270); //type 9, cost 90 COINS, bonus +2.7% productivity
        } else if(_type == 10){
            return Equipment(_type, 140, 200); //type 10, cost 140 COINS, bonus +2% productivity
        } else if(_type == 11){
            return Equipment(_type, 165, 240); //type 11, cost 165 COINS, bonus +2.4% productivity
        } else {
            return Equipment(_type, 250, 360); //type 12, cost 250 COINS, bonus +3.6% productivity
        }
    }
    

    function getCarByType(uint8 _type) public pure returns(Car memory) {
        if(_type == 1) {
            return Car(_type,100,8); // type 1, cost 100 COINS, productivity 8 METAL per hour
        } else if(_type == 2) {
            return Car(_type, 250, 21); // type 2, cost 250 COINS, productivity 21 METAL per hour
        } else if(_type == 3) {
            return Car(_type, 500, 44); // type 3, cost 500 COINS, productivity 44 METAL per hour
        } else if(_type == 4) {
            return Car(_type, 1000, 91); // type 4, cost 1000 COINS, productivity 91 METAL per hour
        } else if(_type == 5) {
            return Car(_type, 3000, 287); // type 5, cost 3000 COINS, productivity 287 METAL per hour
        } else if(_type == 6) {
            return Car(_type, 5000, 500); // type 6, cost 5000 COINS, productivity 500 METAL per hour
        } else {
            return Car(_type  , 10000, 1040); // type 7, cost 10000 COINS, productivity 1040 METAL per hour
        }
    }

    function getUserBalance(address userAddr) public view returns(Balance memory balance) {
        balance = users[userAddr].balance;
    }


    function getUserCars(address userAddr) public view returns(Car[] memory) {
        return users[userAddr].cars;
    }

    function getUserEquipment(address userAddr) public view returns(Equipment[] memory) {
        return users[userAddr].equipment;
    }

    function getUserFuelTank(address userAddr) public view returns(FuelTank memory,uint256) {
        uint256 level = users[userAddr].fuelTankLevel;

        return(getFuelTankByLvl(level),level);
    }

    function getUserPartners(address userAddr) public view returns(Partners memory) {
        return users[userAddr].partners;
    }

    function getUserStats(address userAddr) public view returns(Stats memory) {
        return users[userAddr].stats;
    } 

    function getUserFullData(address userAddr) public view returns(Stats memory stats, Partners memory partners, FuelTank memory tank, uint256 tankLevel, Equipment[] memory equipment, Car[] memory cars, Balance memory balance) {
        stats = getUserStats(userAddr);
        partners = getUserPartners(userAddr);
        (tank,tankLevel) = getUserFuelTank(userAddr);
        equipment = getUserEquipment(userAddr);
        cars = getUserCars(userAddr);
        balance = getUserBalance(userAddr);
    }

    function getContractStats() public view returns(uint256 _staked, uint256 _users, uint256 _cars ) {
        _staked = totalStaked;
        _users = totalUsers;
        _cars = totalCars;
    }
 
    function getWastelandsTimer(address userAddr) public view returns(uint256) {
        return inWastelands(userAddr) ? users[userAddr].wastelands.checkpoint.sub(block.timestamp) : 0 ;
    }

    function getWastelandsInfo(address userAddr) public view returns(uint256 timer, uint256 metalToGet, uint256 timeInWastelands) {
        timer = getWastelandsTimer(userAddr);

        metalToGet = users[userAddr].wastelands.metalToGet;

        timeInWastelands = users[userAddr].wastelands.time;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

   

}


library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
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
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
    
     function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}