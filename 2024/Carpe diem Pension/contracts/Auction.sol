// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/** @notice Pension contract Interface */
interface PensionContractInterface {
    /**
     * @notice Create CDP tokens
     * @param _amount Amount to create
     * @param _day The day for which the tokens are minted
     * @dev The Pension contracts mints the tokens from the CDPToken contract
     */
    function mintCDP(
        uint256 _amount,
        uint256 _day
    ) external;

    /**
     * @notice Create shares
     * @param _recipient Address of the recipient
     * @param _amount Amount to create
     */
    function mintShares(
        address _recipient,
        uint256 _amount
    ) external;

    /**
     * @notice View function to get the total amount of shares in the system
     * @return totalShares Total amount of shares in the system
     */
    function gettotalShares() external view returns (uint256);

    /**
     * @notice Calculate the amount of shares to be auctioned
     * @return sharesDistributedinAuction Shares to be auctioned today
     */
    function BurnSharesfromAuction() external returns (uint256);
}

/**
 * @title Auction and daily updater for the Carpe Diem Pension system
 * @author Carpe Diem
 * @notice Updates the entire system and auctions shares for PLS each 20 hours
 * @dev Part of a system of three contracts. The other two are called Pension and CDPToken
 */
contract Auction is Ownable, Initializable {
    /**
     * @notice Auction entry of the user
     * @param addr Address of the user
     * @param timestamp Time of the event
     * @param entryAmountPLS Amount of PLS deposited
     * @param day Day of the system
     */
    event UserEnterAuction(
        address indexed addr,
        uint256 timestamp,
        uint256 entryAmountPLS,
        uint256 day
    );

    /**
     * @notice Collected shares from the auction by the user
     * @param addr Address of the user
     * @param timestamp Time of the event
     * @param day Day of the system
     * @param tokenAmount Amount of shares collected
     */
    event UsercollectAuctionShares(
        address indexed addr,
        uint256 timestamp,
        uint256 day,
        uint256 tokenAmount
    );

    /**
     * @notice End mark of the auction for a certain day
     * @param timestamp Time of the event
     * @param day Day of the system
     * @param PLSTotal Amount of PLS deposited for the day
     * @param tokenTotal Amount of shares auctioned for the day
     */
    event DailyAuctionEnd(
        uint256 timestamp,
        uint256 day,      
        uint256 PLSTotal,
        uint256 tokenTotal
    );

    /** 
     * @notice Start of the system 
     * @param timestamp Time of the event
     */
    event AuctionStarted(
        uint256 timestamp
    );

    /** @notice Address that receives PLS */
    address public immutable swiss_addr;

    /** @notice Record the current day of the system */
    uint256 public currentDay;

    struct userAuctionEntry {
        uint256 totalDepositsPLS; // Total PLS deposited by the user for the day
        uint256 day; // Day of the system
        bool hasCollected; // Whether the user has collected its shares
    }
    /** 
     * @notice Information about the auction participant
     * @dev Users are allowed to enter multiple times a day
     */
    mapping(address => mapping(uint256 => userAuctionEntry))
        public mapUserAuctionEntry;

    /** @notice Total PLS deposited for the day */
    mapping(uint256 => uint256) public PLSauctionDeposits;

    /** @notice Total shares distributed for the day */
    mapping(uint256 => uint256) public shares;

    /** @notice Total CDP minted for the day */
    mapping(uint256 => uint256) public CDPMinted;

    /** @notice Start time of the system used to calculate the days */
    uint256 public launchTime;

    /** @notice CDPToken address */
    address public immutable CDP;

    /** @notice Total amount of PLS deposited */
    uint256 public totalPLSdeposited;

    /** @notice Address of the Pension contract */
    address public immutable PensionContractAddress;

    /** 
     * @notice Construct the contract
     * @param _CDP Address of the CDPToken contract
     * @param _pensionaddress Address of the pension contract
     */
    constructor(
        address _CDP,
        address _pensionaddress
    ) Ownable(msg.sender) {
        swiss_addr = msg.sender;
        CDP = _CDP;
        PensionContractAddress = _pensionaddress;
    }

    receive() external payable {}

    /** 
     * @notice Start the system
     * @dev Called when we're ready to start the auction
     */
    function startAuction() external onlyOwner initializer {
        launchTime = block.timestamp;
        currentDay = 1;

        renounceOwnership();

        emit AuctionStarted(block.timestamp);
    }

    /**
     * @notice Calculate the current day based off the start time
     */
    function calcDay() public view returns (uint256) {
        if (launchTime == 0) return 0;
        return ((block.timestamp - launchTime) / 20 hours) + 1;
    }

    /**
     * @notice Update the system for the day
     * @notice Mints daily inflation
     * @dev Called daily, can be done manually in explorer. For security, all tokens are kept inside the contract.
     */
    function doDailyUpdate() public {
        uint256 _nextDay = calcDay();
        uint256 _currentDay = currentDay;
 
        // This is true once a day
        if (_currentDay != _nextDay) {
            // Mints the CDP for the current day
            _mintDailyCDPandShares(_currentDay);

            // Mints CDP for days that were skipped
            for(uint256 i = _currentDay + 1; i < _nextDay; i++) {
                _mintPastDailyCDP(i);
            }

            emit DailyAuctionEnd(
                block.timestamp,
                currentDay,
                PLSauctionDeposits[currentDay],
                shares[currentDay]
            );

            currentDay = _nextDay;
        }
    }

    /**
     * @notice Enter the auction by depositing PLS
     * @dev Enter the Auction for the current day
     */
    function enterAuction() external payable {
        require(
            (launchTime > 0),
            "Project not launched"
        );
        require(
            msg.value > 0, 
            "Value is 0"
        );
        doDailyUpdate();

        uint256 _currentDay = currentDay;
        PLSauctionDeposits[_currentDay] += msg.value;

        mapUserAuctionEntry[msg.sender][_currentDay] = userAuctionEntry({
            totalDepositsPLS: mapUserAuctionEntry[msg.sender][_currentDay]
                .totalDepositsPLS + msg.value,
            day: _currentDay,
            hasCollected: false
        });
        totalPLSdeposited += msg.value;

        emit UserEnterAuction(
            msg.sender,
            block.timestamp,
            msg.value,
            _currentDay
        );
    }

    /**
     * @notice Collect shares for day `targetDay`
     * @dev External function for collecting shares from auction
     * @param targetDay Target day of Auction to collect
     */
    function collectAuctionShares(
        uint256 targetDay
    ) external {
        require(
            mapUserAuctionEntry[msg.sender][targetDay].hasCollected == false,
            "Tokens already collected for day"
        );
        require(
            targetDay < currentDay,
            "Cannot collect tokens for current active day"
        );

        uint256 _sharesToPay = calcTokenValue(msg.sender, targetDay);
        mapUserAuctionEntry[msg.sender][targetDay].hasCollected = true;

        PensionContractInterface(PensionContractAddress).mintShares(
            msg.sender,
            _sharesToPay
        );

        emit UsercollectAuctionShares(
            msg.sender,
            block.timestamp,
            targetDay,
            _sharesToPay
        );
    }

    /**
     * @notice Calculate the amount of shares for user `_address` for day `_Day`
     * @dev Calculating user's share from Auction based on their deposits for the day
     * @param _Day The Auction day
     * @return _tokenValue Amount of shares
     */
    function calcTokenValue(
        address _address,
        uint256 _Day
    ) public view returns (uint256 _tokenValue) {
        uint256 _entryDay = mapUserAuctionEntry[_address][_Day].day;

        if (shares[_entryDay] == 0) {
            return 0;
        }
        if (_entryDay < currentDay) {
            _tokenValue =
                (shares[_entryDay] *
                    mapUserAuctionEntry[_address][_Day].totalDepositsPLS) /
                PLSauctionDeposits[_entryDay];
        }

        return _tokenValue;
    }

    /**
     * @notice Send PLS to `swiss_addr`
     * @notice Caller pays network fees, but cannot expect to receive anything in return
     */
    function withdrawPLS() external {
        uint256 _bal = address(this).balance;
        (bool sent, ) = payable(swiss_addr).call{value: _bal}("");
        require(sent, "Failed to withdraw PLS");
    }

    /**
     * @dev Mints CDP in Pension contract and shares for the day 
     * @param _day Day to mint the CDP + shares for
     */
    function _mintDailyCDPandShares(
        uint256 _day
    ) internal {
        // CDP is minted from Pension contract every day
        uint256 MintedCDP = todayMintedCDP();
        CDPMinted[_day] = MintedCDP;
        PensionContractInterface(PensionContractAddress).mintCDP(
            MintedCDP,
            _day
        );

        if (PLSauctionDeposits[_day] != 0) {
            uint256 nextDayShares = PensionContractInterface(PensionContractAddress)
                .BurnSharesfromAuction();
            shares[_day] = nextDayShares; // Amount of shares that are for sale on _day
        }
    }

    /**
     * @dev Only mints CDP in Pension contract for days that weren't updated
     * @param _day Skipped day to mint the CDP
     */
    function _mintPastDailyCDP(
        uint256 _day
    ) internal {
        // CDP is minted from Pension from previous days
        uint256 MintedCDP = todayMintedCDP();
        CDPMinted[_day] = MintedCDP;
        PensionContractInterface(PensionContractAddress).mintCDP(
            MintedCDP,
            _day
        );
    }

    /**
     * @notice Calculate the amount of CDP Tokens to create
     * @dev Converts inflation of 4.32% a year (including compounding) to 20 hour days
     * @dev Applies inflation to the totalSupply + historicSupply
     * @dev historicSupply = totalShares / 1.3, as every CDP deposited creates a total of 1.3 shares
     */
    function todayMintedCDP() public view returns (uint256) {
        uint256 totalSupply = IERC20(CDP).totalSupply();
        uint256 totalShares = PensionContractInterface(PensionContractAddress)
            .gettotalShares();
        uint256 historicSupply = (totalShares * 10) / 13;
        return (((totalSupply + historicSupply) * 10000) / 103563452);
    }

    /**
     * @notice Get your statistics for day `_day`
     * @return yourDeposit Your total deposits of PLS for day `_day`
     * @return totalDeposits Total deposits of PLS for day `_day`
     * @return youReceive Calculate the amount of shares to receive
     * @return claimedis Boolean to know whether you have claimed your shares
     * @return sharesis Total shares auctioned for day `_day`
     */
    function getStatsLoop(
        uint256 _day
    )
        external
        view
        returns (
            uint256 yourDeposit,
            uint256 totalDeposits,
            uint256 youReceive,
            bool claimedis,
            uint256 sharesis
        )
    {
        yourDeposit = mapUserAuctionEntry[msg.sender][_day].totalDepositsPLS;
        totalDeposits = PLSauctionDeposits[_day];
        youReceive = calcTokenValue(msg.sender, _day);
        claimedis = mapUserAuctionEntry[msg.sender][_day].hasCollected;
        sharesis = shares[_day];
    }

    /**
     * @notice Get someone's statistics for multiple days
     * @param _day First day to get statistics from
     * @param numb Number of days to get statistics from
     * @param account Address to get statistics from
     */
    function getStatsLoops(
        uint256 _day,
        uint256 numb,
        address account
    )
        external
        view
        returns (
            uint256[] memory yourDeposits,
            uint256[] memory totalDeposits,
            uint256[] memory youReceives,
            bool[] memory claimedis,
            uint256[] memory sharesDay
        )
    {
        yourDeposits = new uint256[](numb);
        totalDeposits = new uint256[](numb);
        youReceives = new uint256[](numb);
        claimedis = new bool[](numb);
        sharesDay = new uint256[](numb);

        for (uint256 i = 0; i < numb; ) {
            yourDeposits[i] = mapUserAuctionEntry[account][_day + i]
                .totalDepositsPLS;
            totalDeposits[i] = PLSauctionDeposits[_day + i];
            youReceives[i] = calcTokenValue(account, _day + i);
            claimedis[i] = mapUserAuctionEntry[account][_day + i].hasCollected;
            sharesDay[i] = shares[_day + i];
            unchecked {
                ++i;
            }
        }
        
        return (yourDeposits, totalDeposits, youReceives, claimedis, sharesDay);
    }
}