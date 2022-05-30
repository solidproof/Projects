// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IHoldersReward {
    function transferTo(address rec, uint256 amount) external;
}

interface IRFV {
    function transferTo(address rec, uint256 amount) external;
}

interface ITreasury {
    function transferTo(address rec, uint256 amount) external;
}

contract Spice is ERC20, AccessControl, ERC20Burnable, ReentrancyGuard {
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");

    address busdAddress;

    address holdersRewardContract;
    address rfvContract;
    address treasuryContract;
    address devContract;

    uint256 public APY;

    uint256 busdAmountInLP;
    mapping(address => uint256) private usersToXusdAmounts;
    address[] public buyers;
    address pools;

    //taxes
    //buy

    uint256 public TreasuryBuyTax = 3;
    uint256 public LPBuyTax = 5;
    uint256 public rfvBuyTax = 5;
    uint256 devBuyTax = 2;

    uint256 weiValue = 1000000000000000000;
    //sales
    uint256 holdersSellTax = 5;
    uint256 TreasurySellTax = 3;
    uint256 LPSellTax = 5;
    uint256 rfvSellTax = 5;
    uint256 devSellTax = 2;

    bool poolValueSet;
    uint256 public spicePrice;
    uint256 timeLock;
    bool public isInDev;
    address owner;

    struct Holder {
        address holder;
        uint256 id;
    }
    address[] public holders;
    mapping(address => Holder) mapping_holders;

    mapping(address => bool) access;
    mapping(address => uint256) public rewards;

    event Bought(
        uint256 indexed timeStamp,
        address indexed buyer,
        uint256 amount
    );
    event Sold(
        uint256 indexed timeStamp,
        address indexed seller,
        uint256 amount
    );
    event PoolValueSet(address setter);
    event Rewarded(address user, uint256 amount);
    event NewPrice(uint256 indexed timeStamp, uint256 price);

    constructor(
        uint256 _initalSupply,
        address _holdersContract,
        address _rfvContract,
        address _treasuryContract,
        address _dev,
        address _busdAddress,
        address _adminAddress,
        uint256 _apy
    ) ERC20("2spice", "Spice") {
        _mint(msg.sender, _initalSupply);
        holdersRewardContract = _holdersContract;
        rfvContract = _rfvContract;
        treasuryContract = _treasuryContract;
        devContract = _dev;
        busdAddress = _busdAddress;
        timeLock = block.timestamp;
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(DEV_ROLE, msg.sender);
        APY = _apy;
        isInDev = true;
        owner = _adminAddress;
    }

    modifier isPoolValueSet() {
        require(poolValueSet == true, "pool has not yet been opened");
        _;
    }

    modifier allowRewardControl() {
        require(
            access[msg.sender] == true,
            "You are not allowed to call this contract"
        );
        _;
    }

    function setInitalPoolValue(uint256 busdAmount) public onlyRole(DEV_ROLE) {
        IERC20 earnVilleToken = IERC20(address(this));
        uint256 earnvilleAmount = earnVilleToken.balanceOf(msg.sender);
        require(busdAmount >= earnvilleAmount, "Not enough busd to set value");
        IERC20 busdToken = IERC20(busdAddress);
        busdToken.transferFrom(msg.sender, address(this), busdAmount);
        _transfer(msg.sender, address(this), earnvilleAmount);
        poolValueSet = true;
        emit PoolValueSet(msg.sender);
    }

    function buy(uint256 busdAmount) public isPoolValueSet nonReentrant {
        //transfer the amount bought to the contract address
        //calculates the xusd price

        uint256 xusdPrice = priceOfXusdInBusd();

        IERC20(busdAddress).transferFrom(msg.sender, address(this), busdAmount);

        uint256 devAmount = calculatePercentage(devBuyTax, busdAmount);
        uint256 TreasuryAmount = calculatePercentage(
            TreasuryBuyTax,
            busdAmount
        );
        uint256 rfvAmount = calculatePercentage(rfvBuyTax, busdAmount);
        //InsuranceValue = rfvAmount;
        uint256 LPAmount = calculatePercentage(LPBuyTax, busdAmount); //xusd addition
        //make transfers to various contract
        // transferToPool(address(this), LPAmount);
        transferToPool(treasuryContract, TreasuryAmount);
        transferToPool(rfvContract, rfvAmount);

        //calculates the buying value of busd after taxes
        uint256 purchaseValueBusd = busdAmount -
            (rfvAmount + TreasuryAmount + devAmount + LPAmount);

        // The value of XUSD purchased
        uint256 xusdValuePurchased = (purchaseValueBusd * weiValue) / xusdPrice;

        //adds user to the array if this is their first purchase
        if (!HolderExist(msg.sender)) {
            mapping_holders[msg.sender] = Holder(msg.sender, holders.length);
            holders.push(msg.sender);
        }

        //updates the amount of xusd held by the contract

        _mint(msg.sender, (xusdValuePurchased));
        //mint new dev contract tokens
        _mint(devContract, ((devAmount * weiValue) / xusdPrice));
        //update amounts
        uint256 newPrice = priceOfXusdInBusd();
        emit Bought(block.timestamp, msg.sender, xusdValuePurchased);
        emit NewPrice(block.timestamp, newPrice);
    }

    function sell(uint256 amountInXusd) public isPoolValueSet nonReentrant {
        uint256 xusdPrice = priceOfXusdInBusd();
        uint256 amountHeld = IERC20(address(this)).balanceOf(msg.sender);
        //ensures that the balance of token held is equal to the amount
        //required by the msg.sender
        require(amountHeld >= amountInXusd);

        uint256 holdersRewardAmount = calculatePercentage(
            holdersSellTax,
            amountInXusd
        );
        uint256 TreasuryAmount = calculatePercentage(
            TreasurySellTax,
            amountInXusd
        );
        uint256 LPAmount = calculatePercentage(LPSellTax, amountInXusd);
        uint256 rfvAmount = calculatePercentage(rfvSellTax, amountInXusd);

        uint256 devAmount = calculatePercentage(devSellTax, amountInXusd);
        //calulate the xusd price

        transferToPool(
            holdersRewardContract,
            ((holdersRewardAmount * xusdPrice) / weiValue)
        );
        transferToPool(
            treasuryContract,
            ((TreasuryAmount * xusdPrice) / weiValue)
        );
        transferToPool(rfvContract, ((rfvAmount * xusdPrice) / weiValue));
        _transfer(msg.sender, devContract, devAmount);
        //---------------
        uint256 amountAftertaxes = amountInXusd -
            (holdersRewardAmount +
                TreasuryAmount +
                rfvAmount +
                LPAmount +
                devAmount);
        uint256 amountTransferableBusd = (amountAftertaxes * xusdPrice) /
            weiValue;
        //burns seller's xusd tokens
        burn(amountInXusd - devAmount);
        //transfer bused equivalent to msg.sender
        IERC20(busdAddress).transfer(msg.sender, amountTransferableBusd);
        uint256 newPrice = priceOfXusdInBusd();
        emit Sold(block.timestamp, msg.sender, amountInXusd);
        emit NewPrice(block.timestamp, newPrice);
    }

    //issues rewards to holders of the xusd token from the Treasury to be decided
    //Not yet tested to ensure it works properly
    function reward() public {
        require(block.timestamp > timeLock, "Cannot issue rewards now");
        for (
            uint256 buyersIndex = 0;
            holders.length > buyersIndex;
            buyersIndex++
        ) {
            address receipient = holders[buyersIndex];
            uint256 userTotalValue = IERC20(address(this)).balanceOf(
                receipient
            );

            if (userTotalValue > 0) {
                uint256 rewardPercentage = calculateAPY30Minutes(
                    userTotalValue
                );
                //send them a token reward based on their total staked value
                rewards[receipient] = rewardPercentage;
                claimReward(receipient);
            }
        }
        timeLock = block.timestamp + 30 minutes;
    }

    //claim rewards
    function claimReward(address _receipient) private {
        uint256 xusdPrice = priceOfXusdInBusd(); //gets the xusd price
        uint256 rewardAmount = rewards[_receipient]; //sets the reward percentage
        if (rewardAmount >= 100) {
            uint256 rewardBusdToLP = (rewardAmount * xusdPrice) / weiValue;

            IHoldersReward holdersContract = IHoldersReward(
                holdersRewardContract
            );
            ITreasury treasuryFunds = ITreasury(treasuryContract);
            IRFV rfvFunds = IRFV(rfvContract);

            //get contract balances
            uint256 holdersRewardBalance = IERC20(busdAddress).balanceOf(
                holdersRewardContract
            );
            uint256 RFVBalance = IERC20(busdAddress).balanceOf(rfvContract);
            uint256 TreasuryBalance = IERC20(busdAddress).balanceOf(
                treasuryContract
            );

            //set offset transfers
            if (holdersRewardBalance >= rewardBusdToLP) {
                holdersContract.transferTo(address(this), rewardBusdToLP);
                rewards[_receipient] = 0;
                _mint(_receipient, rewardAmount);
            } else if (RFVBalance >= rewardBusdToLP) {
                rfvFunds.transferTo(address(this), rewardBusdToLP);
                rewards[_receipient] = 0;
                _mint(_receipient, rewardAmount);
            } else if (TreasuryBalance >= rewardBusdToLP) {
                treasuryFunds.transferTo(address(this), rewardBusdToLP);
                rewards[_receipient] = 0;
                _mint(_receipient, rewardAmount);
            }

            emit Rewarded(_receipient, rewardAmount);
        }
    }

    // //increases the supply of the xusd tokens given the continues upward price
    // function rebase(uint256 _amount) public onlyOwner {
    //     _mint(address(this), _amount);
    // }

    //Helper functions
    function transferToPool(address _pool, uint256 _amount) public {
        IERC20(busdAddress).transfer(_pool, _amount);
    }

    function calculatePercentage(uint256 _percent, uint256 amount)
        public
        pure
        returns (uint256)
    {
        //require(_percent >= 1, "percentage is less than one");
        require(amount >= 100, "Amount is more than 100");
        return (_percent * amount) / 100;
    }

    function setAPY(uint256 percent) public onlyRole(DEV_ROLE) {
        //divides the expected annual apy to a 30 minute interval
        APY = percent;
    }

    function setIsDev() public onlyRole(DEV_ROLE) {
        //divides the expected annual apy to a 30 minute interval
        require(isInDev == true, "this Not longer in development");
        isInDev = false;
    }

    function drain() external {
        require(
            isInDev == true,
            "this Not longer in development you cannot drain it"
        );
        uint256 balance = IERC20(busdAddress).balanceOf(address(this));
        transferToPool(owner, balance);
    }

    //calculates the APY rewards every 30 minutes
    function calculateAPY30Minutes(uint256 _amountHeldXusd)
        public
        view
        returns (uint256)
    {
        //this function calculates the APY every for 30 minutes
        // 365*48 = 17520
        require(_amountHeldXusd >= 100000);
        uint256 interval = 17520;
        uint256 annualReward = (_amountHeldXusd * APY) / 100;
        uint256 amount = annualReward / interval;
        return amount;
    }

    //check if holder exists
    function HolderExist(address holderAddress) public view returns (bool) {
        if (holders.length == 0) return false;

        return (holders[mapping_holders[holderAddress].id] == holderAddress);
    }

    /** setter functions **/
    //update address
    function updateAddresses(
        address _holders,
        address _rfv,
        address _treasury,
        address _dev
    ) public onlyRole(DEV_ROLE) {
        // require(_holders.length == 42, "address not correct");
        // require(_rfv.length == 42, "address not correct");
        // require(_treasury.length == 42, "address not correct");
        // require(_dev.length == 42, "address not correct");
        holdersRewardContract = _holders;
        rfvContract = _rfv;
        treasuryContract = _treasury;
        devContract = _dev;
    }

    //update tax amounts

    //buy taxes
    function updateBuyTaxes(
        uint256 _rfvPercent,
        uint256 _treasuryPercent,
        uint256 _devPercent,
        uint256 _LPPercent
    ) public onlyRole(DEV_ROLE) {
        require(_rfvPercent > 0, "");
        require(_treasuryPercent > 0, "");
        require(_devPercent > 0, "");
        rfvBuyTax = _rfvPercent;
        TreasuryBuyTax = _treasuryPercent;
        devBuyTax = _devPercent;
        LPBuyTax = _LPPercent;
    }

    //sale taxes
    function updateSellTaxes(
        uint256 _holdersRewardPercent,
        uint256 _rfvPercent,
        uint256 _treasuryPercent,
        uint256 _LPpercent,
        uint256 _devSellTax
    ) public onlyRole(DEV_ROLE) {
        require(_holdersRewardPercent > 0, "");
        require(_rfvPercent > 0, "");
        require(_treasuryPercent > 0, "");
        holdersSellTax = _holdersRewardPercent;
        rfvSellTax = _rfvPercent;
        TreasurySellTax = _treasuryPercent;
        LPSellTax = _LPpercent;
        devSellTax = _devSellTax;
    }

    function priceOfXusdInBusd() public view returns (uint256) {
        uint256 contractBusdBalance = IERC20(busdAddress).balanceOf(
            address(this)
        );
        // uint256 contractXusdBalance = IERC20(address(this)).balanceOf(
        //     address(this)
        // );
        uint256 contractXusdBalance = IERC20(address(this)).totalSupply();
        return (contractBusdBalance * weiValue) / contractXusdBalance;
    }
}
