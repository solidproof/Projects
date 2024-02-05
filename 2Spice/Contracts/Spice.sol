// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

//holders reward contract interface
interface IHoldersReward {
    function transferTo(address rec, uint256 amount) external;
}

//RFV contract interface
interface IRFV {
    function transferTo(address rec, uint256 amount) external;
}

//treasury contract interface
interface ITreasury {
    function transferTo(address rec, uint256 amount) external;
}

contract Spice is ERC20, AccessControl, ERC20Burnable, ReentrancyGuard {
    //access role
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");

    //the busd address used by the contract
    address public busdAddress;

    //wallets/contract wallet addresses
    address public holdersRewardContract;
    address public rfvContract;
    address public treasuryContract;
    address public devContract;

    //the ROI value
    uint256 public ROI;

    //wallets to boolean mapping
    //necessary to control wallet transfers
    mapping(address => bool) public wallets;

    //taxes
    //buy

    uint256 public TreasuryBuyTax = 3;
    uint256 public LPBuyTax = 5;
    uint256 public rfvBuyTax = 5;
    uint256 public devBuyTax = 2;

    uint256 private weiValue = 1000000000000000000;
    //sales taxes
    uint256 public holdersSellTax = 5;
    uint256 public TreasurySellTax = 3;
    uint256 public LPSellTax = 5;
    uint256 public rfvSellTax = 5;
    uint256 public devSellTax = 2;

    //pool value boolean
    bool public poolValueSet;
    //locks rewards for 30 minutes
    uint256 public timeLock;

    //the owner of the contract
    address public owner;

    //holder struct
    struct Holder {
        address holder;
        uint256 id;
    }

    //an array of all holders of 2spice
    address[] public holders;

    //address mapping to holder struct
    mapping(address => Holder) public mapping_holders;

    //mapping of holders to rewards
    mapping(address => uint256) public rewards;

    //buy event
    event Bought(
        uint256 indexed timeStamp,
        address indexed buyer,
        uint256 amount
    );

    //sell event
    event Sold(
        uint256 indexed timeStamp,
        address indexed seller,
        uint256 amount
    );

    //emits when the pool value is set (only once).
    event PoolValueSet(address setter);

    //emits when holder reward
    event Rewarded(address user, uint256 amount);

    //new price event(buy/sell)
    event NewPrice(uint256 indexed timeStamp, uint256 price);

    constructor(
        uint256 _initialSupply,
        address _holdersContract,
        address _rfvContract,
        address _treasuryContract,
        address _dev,
        address _busdAddress,
        address _adminAddress,
        uint256 _ROI
    ) ERC20("2spice", "Spice") {
        _mint(msg.sender, _initialSupply);
        holdersRewardContract = _holdersContract;
        rfvContract = _rfvContract;
        treasuryContract = _treasuryContract;
        devContract = _dev;
        busdAddress = _busdAddress;
        timeLock = block.timestamp;
        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddress);
        _setupRole(DEV_ROLE, msg.sender);
        ROI = 102;
        owner = _adminAddress;
        wallets[holdersRewardContract] = true;
        wallets[devContract] = true;
        wallets[rfvContract] = true;
        wallets[treasuryContract] = true;
    }

    //modifier to check status of initial pool value
    modifier isPoolValueSet() {
        require(poolValueSet == true, "pool has not yet been opened");
        _;
    }

    //sets the initial value of the pool can happen only once
    function setInitialPoolValue(uint256 busdAmount) public onlyRole(DEV_ROLE) {
        require(poolValueSet == false, "the pool value has already been set");
        IERC20 spiceToken = IERC20(address(this));
        uint256 spiceAmount = spiceToken.balanceOf(msg.sender);
        require(busdAmount >= spiceAmount, "Not enough busd to set value");
        IERC20 busdToken = IERC20(busdAddress);
        busdToken.transferFrom(msg.sender, address(this), busdAmount);
        _transfer(msg.sender, address(this), spiceAmount);
        poolValueSet = true;
        emit PoolValueSet(msg.sender);
    }

    //allows users to buy  spice with busd
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
        // transferToWallet(address(this), LPAmount);
        transferToWallet(treasuryContract, TreasuryAmount);
        transferToWallet(rfvContract, rfvAmount);

        //calculates the buying value of busd after taxes
        uint256 purchaseValueBusd = busdAmount -
            (rfvAmount + TreasuryAmount + devAmount + LPAmount);

        // The value of XUSD purchased
        uint256 spiceValuePurchased = (purchaseValueBusd * weiValue) /
            xusdPrice;

        //adds user to the array if this is their first purchase
        if (!HolderExist(msg.sender)) {
            mapping_holders[msg.sender] = Holder(msg.sender, holders.length);
            holders.push(msg.sender);
        }

        //updates the amount of xusd held by the contract

        _mint(msg.sender, (spiceValuePurchased));
        //mint new dev contract tokens
        _mint(devContract, ((devAmount * weiValue) / xusdPrice));
        //update amounts
        uint256 newPrice = priceOfXusdInBusd();
        emit Bought(block.timestamp, msg.sender, spiceValuePurchased);
        emit NewPrice(block.timestamp, newPrice);
    }

    //allows holders of spice to sell
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

        transferToWallet(
            holdersRewardContract,
            ((holdersRewardAmount * xusdPrice) / weiValue)
        );
        transferToWallet(
            treasuryContract,
            ((TreasuryAmount * xusdPrice) / weiValue)
        );
        transferToWallet(rfvContract, ((rfvAmount * xusdPrice) / weiValue));
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

    //issues rewards to holders of the xusd token from the holders reward / other wallets
    function reward() public {
        require(block.timestamp > timeLock, "Cannot issue rewards now");
        for (
            uint256 buyersIndex = 0;
            holders.length > buyersIndex;
            buyersIndex++
        ) {
            address recipient = holders[buyersIndex];
            uint256 userTotalValue = IERC20(address(this)).balanceOf(recipient);

            if (userTotalValue > 0) {
                uint256 rewardPercentage = calculateROI30Minutes(
                    userTotalValue
                );
                //send them a token reward based on their total staked value
                rewards[recipient] = rewardPercentage;
                claimReward(recipient);
            }
        }
        timeLock = block.timestamp + 30 minutes;
    }

    //claim rewards for each user
    function claimReward(address _recipient) private {
        uint256 xusdPrice = priceOfXusdInBusd(); //gets the xusd price
        uint256 rewardAmount = rewards[_recipient]; //sets the reward percentage
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
                rewards[_recipient] = 0;
                _mint(_recipient, rewardAmount);
            } else if (RFVBalance >= rewardBusdToLP) {
                rfvFunds.transferTo(address(this), rewardBusdToLP);
                rewards[_recipient] = 0;
                _mint(_recipient, rewardAmount);
            } else if (TreasuryBalance >= rewardBusdToLP) {
                treasuryFunds.transferTo(address(this), rewardBusdToLP);
                rewards[_recipient] = 0;
                _mint(_recipient, rewardAmount);
            }

            emit Rewarded(_recipient, rewardAmount);
        }
    }

    //Helper functions

    //allows the contract to transfer taxes to the pools
    function transferToWallet(address _pool, uint256 _amount) private {
        //verifies that it transfers only to wallets
        require(wallets[_pool] == true, "transfer prohibited, not a wallet");
        IERC20(busdAddress).transfer(_pool, _amount);
    }

    //calculates percentages to nearest whole number
    function calculatePercentage(uint256 _percent, uint256 amount)
        public
        pure
        returns (uint256)
    {
        require(_percent >= 1, "percentage is less than one");
        require(amount >= 100, "Amount is less than 100");
        return (_percent * amount) / 100;
    }

    //calculates the ROI rewards every 30 minutes
    function calculateROI30Minutes(uint256 _amountHeldXusd)
        public
        view
        returns (uint256)
    {
        //this function calculates the ROI every for 30 minutes
        // 365*48 = 17520
        require(_amountHeldXusd >= 100000);
        uint256 interval = 48;
        uint256 dailyReward = (_amountHeldXusd * ROI) / 10000;
        uint256 amount = dailyReward / interval;
        return amount;
    }

    //check if holder exists if no adds holder to mapping
    function HolderExist(address holderAddress) public view returns (bool) {
        if (holders.length == 0) return false;

        return (holders[mapping_holders[holderAddress].id] == holderAddress);
    }

    /** setter functions **/
    //update wallet address
    function updateAddresses(
        address _holders,
        address _rfv,
        address _treasury,
        address _dev
    ) public onlyRole(DEV_ROLE) {
        require(_holders != address(0), "address not correct");
        require(_rfv != address(0), "address not correct");
        require(_treasury != address(0), "address not correct");
        require(_dev != address(0), "address not correct");
        holdersRewardContract = _holders;
        rfvContract = _rfv;
        treasuryContract = _treasury;
        devContract = _dev;
        wallets[_holders] = true;
        wallets[_rfv] = true;
        wallets[_dev] = true;
        wallets[_treasury] = true;
    }

    //returns the price of xusd in busd (value in wei)
    function priceOfXusdInBusd() public view returns (uint256) {
        uint256 contractBusdBalance = IERC20(busdAddress).balanceOf(
            address(this)
        );

        uint256 contractXusdBalance = IERC20(address(this)).totalSupply();
        return (contractBusdBalance * weiValue) / contractXusdBalance;
    }
}
