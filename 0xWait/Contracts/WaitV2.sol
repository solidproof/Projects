//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import './wait_stuff.sol';


contract WaitV2 is ERC20, ERC20Burnable, ERC20Permit {

    //Address of WaitV1
    IWAIT public waitV1_contract;
    address WAITV1_ADDRESS;
    address manager;

    address timeKeeper = 0xAb4A5B6fEF07d25F9b841E38cE247fB325a9fCd2;
    uint256 public totalSacs = 8;
    bool public minting = false;

    //True if user has claimed their Midnight bonus
    mapping (address => bool) public claimedMidnight;

    //Total number of people eligible for Wait from each sac
    mapping(uint => uint) public totalPeople;

    //Total number of people who have minted their Midnight bonus Wait per sac
    mapping(uint => uint) public mintedPeopleV2;
    //Number of people who minted Midnight bonus each day since launch per sac;
    mapping(uint => mapping(uint => uint)) public dailyMintedPeopleV2;


    //Amount of Midnight bonus Wait minted for each sac
    mapping(uint => uint) public totalWaitV2;

    //Amount of WaitV1 minted before launch
    mapping(uint => uint) public totalWaitV1;

	//Amount of unclaimed Wait (this is the midnight bonus) per sac
    mapping(uint => uint) public unclaimedWaitV2;

	//Timestamps of when each sacrifice ended
    mapping(uint => uint) public sacTimes;

	//Maximum amount of Wait minted for each sac before pulse launched
    mapping(uint => uint) public maxWait;

	//Number of people in each sac who didn't claim their wait
    mapping(uint => uint) public unclaimedPeople;

	//Timestamp when MidnightBonus is called
    uint MidnightBonusTime;

	//Amount of WaitV1 exchanged for WaitV2
    uint WaitV1Exchanged;

	//Amount of WaitV1 exchanged for WaitV2 each day since launched
    mapping(uint => uint) dailyWaitV1Exchanged;


    //Total amount of Midnight Bonus each person got per sac
    //Not sure if we actually need to store this (we technically already know the math)
    mapping(uint => mapping(address => uint)) public claimedAmountV2;

	event mintedMidnight(uint amount, address user);
	event waitExchanged(uint amount, address user);
	event waitV2Burned(uint amount, address user);


    constructor(address v1) ERC20("WaitV2", "WAITV2") ERC20Permit("WaitV2"){
		WAITV1_ADDRESS = v1;
        waitV1_contract = IWAIT(WAITV1_ADDRESS);
        manager = 0xAb4A5B6fEF07d25F9b841E38cE247fB325a9fCd2;

        //Setting the total number of eligible people in each sac
        totalPeople[0] = 79404; //Pulse
        totalPeople[1] = 152701; //PulseX
        totalPeople[2] = 9553; //Liquid Loans
        totalPeople[3] = 3125; //Hurricash
        totalPeople[4] = 847; //Genius
        totalPeople[5] = 292; //Mintra
        totalPeople[6] = 875; //Phiat
        totalPeople[7] = 1247; //Internet Money Dividend

        //Setting timestamps of the end of each sac
        sacTimes[0] = 1627948800; //Pulse
        sacTimes[1] = 1645660800; //PulseX
        sacTimes[2] = 1647907200; //Liquid Loans
        sacTimes[3] = 1646092800; //Hurricash
        sacTimes[4] = 1654041600; //Genius
        sacTimes[5] = 1647561600; //Mintra
        sacTimes[6] = 1654387200; //Phiat
        sacTimes[7] = 1647734400; //Internet Money Dividend

    }

    //Function can only be called by manager
    modifier manager_function(){
        require(msg.sender==manager,"Only the manager can call this function");
    _;}

    //Function can only be called after MidnightBonus() is called
    modifier minting_on(){
        require(minting == true,"Minting Wait has been turned off, go claim the unclaimed Wait");
    _;}

    //Makes WaitV2 divisible
    function decimals() public pure override returns (uint8) {
        return 8;
    }

    //Amount of people that minted WaitV1 for each sac
    function V1mintedPeople(uint i) public view returns(uint) {
        return waitV1_contract.mintedPeople(i);
    }

    //Amount of Midnight bonus shares person has in each sac
    function V1ClaimedAmount(uint i, address addy) public view returns(uint) {
        return waitV1_contract.ClaimedAmount(i,addy);
    }

    //Total amount of Midnight bonus shares for each sac
    function V1totalWait(uint i) public view returns(uint) {
        return waitV1_contract.totalWait(i);
    }

    //WaitV1 balance of msg.sender
    function V1waitBalance() public view returns(uint) {
        return waitV1_contract.balanceOf(msg.sender);
    }

    //Number of days passed since MidnightBonus() is called / Pulsechain launches
    function daysPassedSinceLaunch() public view minting_on returns (uint) {
        return (block.timestamp - MidnightBonusTime) / 86400;
    }

    //Function that turns minting of Midnight bonus on
    //Sets the amount of unclaimed Wait for each sac
    //Sets the time the function is called
    function midnightBonus() public manager_function {

        require(minting == false, "Pulse hasn't launched yet");
        minting = true;
        MidnightBonusTime = block.timestamp;
        uint waitAmount;

        for(uint i; i < totalSacs; i++) {
            totalWaitV1[i] = V1totalWait(i);
            maxWait[i] = (block.timestamp - sacTimes[i]) / 3600;
            if (totalPeople[i] < V1mintedPeople(i)) {
                unclaimedPeople[i] = 0;
            }
            else {
                unclaimedPeople[i] = totalPeople[i] - V1mintedPeople(i);
            }

            unclaimedWaitV2[i] = unclaimedPeople[i] * maxWait[i] * 10**decimals() / 2;
            waitAmount += unclaimedWaitV2[i];
        }

        _mint(timeKeeper, waitAmount);
		// 8 here can just mean 'all'. It's good that we have this control over the data now, we can
		// format this however we want
    }

    //Function that returns amount of Midnight bonus user can mint for specific sac / useful for front end
    function mintableUnclaimedWait(uint sac) public view  minting_on returns (uint waitAmount) {

        require(sac<totalSacs, "not an accurate sacrifice");
        require(claimedMidnight[msg.sender] == false, "You already claimed your midnight Bonus");
        require(V1ClaimedAmount(sac, msg.sender) > 0, "You never claimed your wait or already claimed the unclaimed wait");
        require(V1ClaimedAmount(sac, msg.sender) <= maxWait[sac], "You claimed too late");

        waitAmount = unclaimedWaitV2[sac] * V1ClaimedAmount(sac, msg.sender) / totalWaitV1[sac];

    }

    //Funtion that returns total amount Midnight bonus user can mint
    function mintableAllUnclaimedWait() public view minting_on returns(uint waitAmount) {

        require(claimedMidnight[msg.sender] == false, "You already claimed your midnight Bonus");

        for(uint i; i < totalSacs; i++) {
            if ((V1ClaimedAmount(i, msg.sender) > 0) && (V1ClaimedAmount(i, msg.sender) <= maxWait[i])) {
                waitAmount += unclaimedWaitV2[i] * V1ClaimedAmount(i, msg.sender) / totalWaitV1[i];
            }
        }
    }

    //Function that mints user total amount of eligible Midnight bonus
    function mintAllUnclaimedWait() minting_on public {

        require(claimedMidnight[msg.sender] == false, "You already claimed your midnight Bonus");
        claimedMidnight[msg.sender] = true;

        uint waitAmount = 0;
        for(uint i; i < totalSacs; i++) {
            if ((V1ClaimedAmount(i, msg.sender) > 0) && (V1ClaimedAmount(i, msg.sender) <= maxWait[i])) {
                uint temp = unclaimedWaitV2[i] * V1ClaimedAmount(i, msg.sender) / totalWaitV1[i];
                waitAmount += temp;
                mintedPeopleV2[i]++;
                dailyMintedPeopleV2[i][daysPassedSinceLaunch()]++;
                totalWaitV2[i] += temp;
                claimedAmountV2[i][msg.sender] += temp;
            }
        }

        _mint(msg.sender, waitAmount);
		emit mintedMidnight(waitAmount, msg.sender);

    }

    //Current percent user gets for exchanging WaitV1 for WaitV2
    function currentPercent() public view minting_on returns (uint) {

        uint daysPassed = daysPassedSinceLaunch();

        if (daysPassed < 11) {
            return 100;
        }
        else if (daysPassed < 31) {
            return (100 - (5 * (daysPassed - 11)));
        }
        else {
            return 0;
        }
    }

    //Current amount of WaitV2 user would get for their WaitV1
    function currentExchange() public view minting_on returns(uint) {

        uint daysPassed = daysPassedSinceLaunch();

        require(daysPassed < 31, "It's too late to exchange your V1 Wait for V2");

        uint userBalance = V1waitBalance();

        if (daysPassed < 11) {
            //Sould get 1 (* 10**decimals()) V2 Wait for every V1 Wait
            return userBalance * 10**decimals();
        }
        else {
            //Should get 100 - (5 * daysPassed - 10) (* 10**decimals())/ 100 V2 Wait for every V1 Wait
            //Currently get 100% on day 11, 50% on day 21, 5% on day 30, and 0% on day 31
            uint owedAmount = (100 - (5 * (daysPassed - 11))) * userBalance * 10**decimals() / 100;
            return owedAmount;
        }
    }

    //Function that swaps WaitV1 for WaitV2 based on
    // - user balance
    // - days passed since launch
    // - uncallable if 0% as of right now
    function exchangeV1forV2() public minting_on {

        uint daysPassed = daysPassedSinceLaunch();

        require(daysPassed < 31, "It's too late to exchange your V1 Wait for V2");

        uint userBalance = V1waitBalance();

        if (daysPassed < 11) {
            //Should get 1 (* 10**decimals()) V2 Wait for every V1 Wait
            //Need to burn that Wait now
            waitV1_contract.burnFrom(msg.sender, userBalance);
            _mint(msg.sender, userBalance * 10**decimals());
        }
        else {
            //Should get 100 - (5 * daysPassed - 10) (* 10**decimals())/ 100 V2 Wait for every V1 Wait
            //Need to burn that Wait now
            waitV1_contract.burnFrom(msg.sender, userBalance);
            //Currently get 100% on day 11, 50% on day 21, 5% on day 30, and 0% on day 31
            uint owedAmount = (100 - (5 * (daysPassed - 11))) * userBalance * 10**decimals() / 100;
            _mint(msg.sender, owedAmount);
        }

        dailyWaitV1Exchanged[daysPassed] += userBalance;
        WaitV1Exchanged += userBalance;

		emit waitExchanged(userBalance,msg.sender);
    }

/*

These are all optional functions that just give us more information

*/

    //Function that returns current Midnight bonus user would recieve pre-launch for sac
    function preMidnightBonus(uint sac) public view returns (uint waitAmount) {

        require(sac<totalSacs, "not an accurate sacrifice");
        require(minting == false, "Midnight Bonus can now be claimed");

        uint unclaimedUsers;
        if (totalPeople[sac] > V1mintedPeople(sac)) {
            unclaimedUsers = totalPeople[sac] - V1mintedPeople(sac);
        }
        else {
            unclaimedUsers = 0;
        }
        uint currentWait = (block.timestamp - sacTimes[sac]) / 3600;
        uint unclaimedWait = unclaimedUsers * currentWait * 10**decimals() / 2;
        waitAmount += unclaimedWait * V1ClaimedAmount(sac, msg.sender) / V1totalWait(sac);

    }

    //Function that returns total current Midnight bonus user would recieve pre-launch
    function preMidnightBonusAll() public view returns (uint waitAmount) {

        require(minting == false, "Midnight Bonus can now be claimed");

        uint unclaimedUsers;
        for (uint i; i < totalSacs; i++) {
            if (totalPeople[i] > V1mintedPeople(i)) {
                unclaimedUsers = totalPeople[i] - V1mintedPeople(i);
            }
            else {
                unclaimedUsers = 0;
            }
            uint currentWait = (block.timestamp - sacTimes[i]) / 3600;
            uint unclaimedWait = unclaimedUsers * currentWait * 10**decimals() / 2;
            waitAmount += unclaimedWait * V1ClaimedAmount(i, msg.sender) / V1totalWait(i);
        }

    }

    //Function to update totalPeople with accurate numbers based on new and improving eligibility databases :)
    function updateTotalPeople(uint Pulse, uint PulseX, uint Liquid, uint Hurricash, uint Genius, uint Mintra, uint Phiat, uint IMD) public manager_function {

        require(minting == false, "Pulse has launched");
        totalPeople[0] = Pulse;
        totalPeople[1] = PulseX;
        totalPeople[2] = Liquid;
        totalPeople[3] = Hurricash;
        totalPeople[4] = Genius;
        totalPeople[5] = Mintra;
        totalPeople[6] = Phiat;
        totalPeople[7] = IMD;

    }

	function proofOfBenevolence (uint256 amount)external{
        require (balanceOf(msg.sender) >= amount,
            "Insufficient balance to facilitate PoB");
		require(block.timestamp >= MidnightBonusTime,"Contract not yet active");
		uint256 currentAllowance = allowance(msg.sender, address(this));
        require(currentAllowance >= amount,
            "Burn amount exceeds allowance");
		_burn(msg.sender, amount);
		emit waitV2Burned(amount,msg.sender);
    }

}