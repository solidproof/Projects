//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract CZEmpire {

    // 12.5 days for Generals to double
    // after this period, rewards do NOT accumulate anymore though!
    uint256 private constant GENERAL_COST_IN_Soldiers = 1_080_000;
    uint256 private constant INITIAL_MARKET_Soldiers = 108_000_000_000;

    uint16 private constant PSN = 10000;
    uint16 private constant PSNH = 5000;
    uint16 private constant getMarketingFeeVal = 3;
    uint16 private constant reflectFee = 5;
    bool public isOpen;

    uint256 private totalSoldiers = INITIAL_MARKET_Soldiers;

    address public immutable owner;
    address payable private devFeeReceiver;
    address payable private marketingFeeReceiver;
    address payable private treasuryFeeReceiver;

    //Generals for each address are stored as reflections, which are converted to tokens by a rate
    mapping (address => uint256) private rAddressGenerals;

    mapping (address => uint256) private claimedSoldiers;
    mapping (address => uint256) private lastSoldiersToGeneralsConversion;
    mapping (address => address) private referrals;
    mapping (address => uint256) private lastCompoundStamp;
    mapping (address => uint256) private addressCompoundTimes;
    mapping (address => uint256) private addressToGeneralsComp;

    address public biggestDepositor;
    uint256 public biggestDepositAmount;
    uint256 public depositorRewardStamp;

    uint256 public lastDepositorReawrd;
    address public lastBigestDepositor;

    uint256 MAX = ~uint128(0);
    uint256 public _tTotal = GENERAL_COST_IN_Soldiers; //total Generals
    uint256 public _rTotal = (MAX - (MAX % _tTotal)); //total reflections
    uint256 public rTotalInit; //inital reflections
    uint256 public totalFeesReflected; //total reflections collected from fees
    uint256 public GeneralsFromSell;
    uint256 public GeneralsNoOneOwns;
    uint256 public totalCompoundTimes;
    uint256 public lastSoldiersNukeStamp;


    error OnlyOwner(address);
    error FeeTooLow();
    event Log(uint256 amt);

    //address _devFeeReceiver, address _marketingFeeReceiver, address _treasuryFeeReceiver
    constructor(address _marketingFeeReceiver) payable {
        owner = msg.sender;
        marketingFeeReceiver = payable(_marketingFeeReceiver);
        rAddressGenerals[address(this)] = _rTotal;
        rTotalInit = _rTotal;
        // lastSoldiersToGeneralsConversion[owner] = block.timestamp;
        // marketingFeeReceiver = payable(owner);
        // isOpen = true;
        isOpen = false;
        depositorRewardStamp = block.timestamp;
        lastSoldiersNukeStamp = block.timestamp;
    }

    modifier requireEmpireOpen() {
        require(isOpen, " Empire STILL CLOSED ");
        _;
    }

    //---Reflecions code start
    function _reflectFee(uint256 rFee) private {
        _rTotal -= rFee;
        if(_getRate() > 1) {
            totalFeesReflected += rFee / _getRate();
        }
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {

        return (_rTotal, _tTotal);
    }

    function _getRate() public view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        if(tSupply > rSupply ) return 1;
        return rSupply/tSupply;
    }

    //Get token and reflection values based on token amount
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 _rFee) = _getRValues(tAmount, tFee, _getRate());
        return (rAmount, rTransferAmount, _rFee, tTransferAmount, tFee);
    }

    //Get token values based on applied fees
    function _getTValues(uint256 tAmount) private pure returns (uint256, uint256) {
        uint256 tFee = tAmount * reflectFee / 100;
        uint256 tTransferAmount = tAmount - tFee;
        return (tTransferAmount, tFee);
    }
    //Get reflection values based on token amount and fees
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 _rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - _rFee;

        return (rAmount, rTransferAmount, _rFee);
    }

    //Balance in tokens (Generals) based on reflections
    function balanceOf(address account) public view returns (uint256) {

        return tokenFromReflection(rAddressGenerals[account]);
    }

    //Return token amount based on reflection amount
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount/currentRate;
    }

    //Burn seed Generals, which are needed at first to initiate total reflections
    bool isBurned = false;
    function burnInitialGenerals() external {
        if(!isBurned || msg.sender == owner) {
            _tTotal -= GENERAL_COST_IN_Soldiers;
            _rTotal -= rTotalInit;
            rAddressGenerals[address(this)] -= rTotalInit;
            isBurned = true;
        }
    }

    //---Reflections code end

    // buy Soldiers from the contract
    function trainSoldiers(address ref) public payable requireEmpireOpen {
        require(msg.value >= 1e15, "MIN AMT");
        uint256 SoldiersBought;

        if(msg.value >= address(this).balance) {
            SoldiersBought = calculateSoldiersBuy(msg.value, msg.value * 2); //nerf snipers getting too much Generals
        } else {
            SoldiersBought = calculateSoldiersBuy(msg.value, address(this).balance - msg.value);
        }

        if(msg.value > biggestDepositAmount) {
            biggestDepositAmount = msg.value;
            biggestDepositor = msg.sender;
        }

        uint256 marketingFee = getMarketingFee(SoldiersBought);

        if(marketingFee == 0) revert FeeTooLow();

        SoldiersBought = SoldiersBought - marketingFee;

        marketingFeeReceiver.transfer(getMarketingFee(msg.value));

        claimedSoldiers[msg.sender] += SoldiersBought;

        promoteGenerals(ref);
    }

    //10% bonus every 2 hours for biggest depositor
    //Paid in Generals, reflect fee is applied
    //Bonus must be equal or more than 20 Generals
    function rewardBiggestDepositor() external {
        if(block.timestamp > depositorRewardStamp + 2 hours && biggestDepositor != address(0)) {
            uint256 depositorBonus = biggestDepositAmount / 10;
            uint256 SoldiersBought = calculateSoldiersBuy(depositorBonus, address(this).balance - depositorBonus);
            uint256 newGenerals = SoldiersBought / GENERAL_COST_IN_Soldiers;
            if(newGenerals >= 20){
                 //Get reflect and token values
                (uint256 rAmount,uint256 rTransferAmount, uint256 rFee,,) = _getValues(newGenerals);

                rAddressGenerals[biggestDepositor] += rTransferAmount; //reflections minus fee
                _tTotal += newGenerals; //full token amount
                _rTotal += rAmount; //full reflection amount
                _reflectFee(rFee); //fee amount

                lastBigestDepositor = biggestDepositor;
                lastDepositorReawrd = depositorBonus;

                depositorRewardStamp = block.timestamp;
                biggestDepositAmount = 0;
                biggestDepositor = address(0);
                totalSoldiers += SoldiersBought / 10;
            }
        }
    }

    //Creates Generals + referal logic
    function promoteGenerals(address ref) public requireEmpireOpen {
        require(block.timestamp >= lastCompoundStamp[msg.sender] + 12 hours , " NOT TIME YET ");
        if(ref == msg.sender) ref = address(0);

        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }

        ++addressCompoundTimes[msg.sender];
        ++totalCompoundTimes;

        //Pending Soldiers
        uint256 SoldiersUsed = getSoldiersForAddress(msg.sender);
        uint256 mySoldiersRewards = getPendingSoldiers(msg.sender);

        claimedSoldiers[msg.sender] += mySoldiersRewards;

        // //Every 4th (2 days) compound get bonus 2% Generals of total Generals for address
        if(addressCompoundTimes[msg.sender] % 4 == 0) {

            uint256 currentGeneralsT = balanceOf(msg.sender);
            uint256 currentGeneralsR = rAddressGenerals[msg.sender];
            if(currentGeneralsT >= 50) {
                 uint256 tIncrease = currentGeneralsT * 2 / 100;
                 uint256 rIncrease = currentGeneralsR * 2 / 100;
                 uint256 _rFee = rIncrease * reflectFee / 100;
                 rAddressGenerals[msg.sender] += rIncrease - _rFee;
                 _rTotal += rIncrease;
                 _tTotal += tIncrease;
                 _reflectFee(_rFee);
            }

        }

        //Every 7 days, randomized rebase bonus between 1 - 5%
        if(addressCompoundTimes[msg.sender] % 14 == 0) {
            uint256 currentGeneralsT = balanceOf(msg.sender);
            uint256 currentGeneralsR = rAddressGenerals[msg.sender];

            if(currentGeneralsT >= 100) {
                uint256 randomPercent = (uint256(
                    keccak256(
                        abi.encode(
                            blockhash(block.number - 1),
                            blockhash(block.number),
                            block.number,
                            block.timestamp+1))) % 5) + 1;
                uint256 tIncrease = currentGeneralsT * randomPercent / 100;
                uint256 rIncrease = currentGeneralsR * randomPercent / 100;
                uint256 rFee_ = rIncrease * reflectFee / 100;
                rAddressGenerals[msg.sender] += rIncrease - rFee_;
                _rTotal += rIncrease;
                _tTotal += tIncrease;
                _reflectFee(rFee_);
            }

        }

        //Convert Soldiers To Generals
        uint256 newGenerals = claimedSoldiers[msg.sender] / GENERAL_COST_IN_Soldiers;
        require(newGenerals >= 1, "Need to compound at least 1 Generals");
        claimedSoldiers[msg.sender] -= (GENERAL_COST_IN_Soldiers * newGenerals);
        addressToGeneralsComp[msg.sender] += newGenerals;

        if(addressToGeneralsComp[msg.sender] >= 20) {
            //Get reflect and token values
            (uint256 rAmount,uint256 rTransferAmount, uint256 rFee,,) = _getValues(newGenerals);

            rAddressGenerals[msg.sender] += rTransferAmount;//reflections minus fee
            _tTotal += newGenerals; //full token amount
            _rTotal += rAmount; //full reflection amount
            _reflectFee(rFee); //fee amount

              // send referral bonus in Generals (5%)
            if(ref != address(0) && referrals[msg.sender] != address(0)) {

                rAddressGenerals[referrals[msg.sender]] += rTransferAmount / 20;
                _tTotal += newGenerals / 20;
                _rTotal += rAmount / 20;

            }

            addressToGeneralsComp[msg.sender] = 0;
        }

        lastSoldiersToGeneralsConversion[msg.sender] = block.timestamp;
        lastCompoundStamp[msg.sender] = block.timestamp;

        // nerf Generals hoarding
        totalSoldiers += SoldiersUsed * 15 / 100;

        //Burn initial Generals and reflections
        //Called only once
        this.burnInitialGenerals();
        this.rewardBiggestDepositor();

        if(totalCompoundTimes % 2500 > 0 && lastSoldiersNukeStamp + 1 days > block.timestamp) {
            uint256 currentMarketSoldiers = totalSoldiers;
            totalSoldiers -= currentMarketSoldiers / 100; //1%
            lastSoldiersNukeStamp = block.timestamp;
            totalCompoundTimes = 0;
        }
    }

     //Used on sell to convert Soldiers into Generals and fully reflect them to holders
    function SoldiersToGeneralsReflection(uint256 Soldiers) public {
        uint256 newGenerals = Soldiers / GENERAL_COST_IN_Soldiers;
        GeneralsFromSell += newGenerals;
        if(GeneralsFromSell >= 20) {
            (uint256 rAmount,,,,) = _getValues(GeneralsFromSell);
            //Reflect full rAmount
            //Increase tTotal results in bigger rate
            _tTotal += GeneralsFromSell;
            _rTotal += rAmount;
            _reflectFee(rAmount);

            GeneralsNoOneOwns += GeneralsFromSell;
            GeneralsFromSell = 0;

        }
    }

    // sells your Soldiers
    function abusePower() external requireEmpireOpen {
        require(msg.sender == tx.origin, " NON-CONTRACTS ONLY ");

        uint256 taxSoldiers;
        uint256 ownedSoldiers = getSoldiersForAddress(msg.sender);
        if(ownedSoldiers < 100 ) ownedSoldiers = 100;
        require(ownedSoldiers >= 100, " NEED TO OWN AT LEAST 100 Soldiers ");
        //Need 8 compounds to have lower sell fee
        if(addressCompoundTimes[msg.sender] < 8) {
            taxSoldiers = ownedSoldiers * 40 / 100; //40%
        } else {
            taxSoldiers = ownedSoldiers * reflectFee / 100; //5%
        }


        uint256 GeneralsBefore = balanceOf(msg.sender);

        //Reflect tax
        SoldiersToGeneralsReflection(taxSoldiers);

        uint256 GeneralsAfter = balanceOf(msg.sender);

        //Dont self-reflect from Soldiers tax
        if(GeneralsAfter > GeneralsBefore) {
            (uint256 rAmount,,,,) = _getValues(GeneralsAfter - GeneralsBefore);
            rAddressGenerals[msg.sender] -= rAmount;

        }


        claimedSoldiers[msg.sender] = 0;

        //reset compound counter on sell
        addressCompoundTimes[msg.sender] = 0;
        lastSoldiersToGeneralsConversion[msg.sender] = block.timestamp;

        // Each sell, 5% of your Generals gets deducted and reflected to others
        if(rAddressGenerals[msg.sender] >= 20) {
            uint256 sellGENERALFeeT = balanceOf(msg.sender)  / 20;
            uint256 sellGENERALFeeR = rAddressGenerals[msg.sender] / 20;
            rAddressGenerals[msg.sender] -= sellGENERALFeeR;
            _tTotal -= sellGENERALFeeT;
            _reflectFee(sellGENERALFeeR);
        }


        uint256 tokenValue = calculateSoldiersSell(ownedSoldiers - taxSoldiers);
        require(tokenValue > 10000, "MIN AMOUNT");

        totalSoldiers += (ownedSoldiers - taxSoldiers);

        uint256 marketingFee = getMarketingFee(tokenValue);
        marketingFeeReceiver.transfer(marketingFee);

        if(tokenValue > address(this).balance) {
         payable(msg.sender).transfer(tokenValue);
        } else {
         payable(msg.sender).transfer(tokenValue - marketingFee);
        }
    }

    function totalGeneralsReflected() external view returns(uint256) {
        return GeneralsNoOneOwns > totalFeesReflected ? GeneralsNoOneOwns - totalFeesReflected : totalFeesReflected - GeneralsNoOneOwns ;
    }

    function calculateSoldiersSell(uint256 Soldiers) public view returns(uint256) {
        return calculateTrade(Soldiers, totalSoldiers, address(this).balance);
    }

    function calculateSoldiersBuy(uint256 eth, uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth, contractBalance, totalSoldiers);
    }

    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

    function getMyGenerals() external view returns(uint256) {
        return balanceOf(msg.sender);
    }

    function getGeneralsForAddress(address adr) external view returns(uint256) {
        return balanceOf(adr);
    }

    function getMySoldiers() public view returns(uint256) {
        return claimedSoldiers[msg.sender] + getPendingSoldiers(msg.sender);
    }

    function getSoldiersForAddress(address adr) public view returns(uint256) {
        return claimedSoldiers[adr] + getPendingSoldiers(adr);
    }

    function getPendingSoldiers(address adr) public view returns(uint256) {
        // 1 token per second per General
        return min(GENERAL_COST_IN_Soldiers, block.timestamp - lastSoldiersToGeneralsConversion[adr]) * balanceOf(adr);
    }

    function getPendingGenerals(address adr) public view returns(uint256) {
        return getSoldiersForAddress(adr) / GENERAL_COST_IN_Soldiers;
    }

    function SoldiersRewards() external view returns(uint256) {
        // Return amount is in BNB
        return calculateSoldiersSell(getSoldiersForAddress(msg.sender));
    }

    function SoldiersRewardsForAddress(address adr) external view returns(uint256) {
        // Return amount is in BNB
        return calculateSoldiersSell(getSoldiersForAddress(adr));
    }

    // degen balance keeping formula
    function calculateTrade(uint256 rt, uint256 rs, uint256 bs) private pure returns(uint256) {
        return (PSN * bs) / (PSNH + (((rs * PSN) + (rt * PSNH)) / rt));
    }

    function getMarketingFee(uint256 amount) private pure returns(uint256) {
        return amount * getMarketingFeeVal / 100;
    }

    function minutesLeftTillNextCompound(address adr) external view returns(uint256 stamp) {
        return ((lastCompoundStamp[adr] + 12 hours) - block.timestamp) / 1 minutes;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function openEmpire() external {
        if(msg.sender != owner) revert OnlyOwner(msg.sender);
        isOpen = true;
    }

    function changeMarketingFeeReceiver(address newReceiver) external {
        if(msg.sender != owner) revert OnlyOwner(msg.sender);
        marketingFeeReceiver = payable(newReceiver);
    }

    receive() external payable {}
}