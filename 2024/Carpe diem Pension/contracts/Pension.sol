// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/** @notice CDP Token contract interface */
interface ICDPToken is IERC20 {
    /**
     * @notice Create new CDP tokens
     * @param to Address of the recipient
     * @param amount Amount of CDP tokens to create
     */
    function mint(
        address to,
        uint256 amount
    ) external;

    /**
     * @notice Destroy CDP tokens from existence
     * @param amount Amount to destroy
     * @dev Keeps track of destroyed CDP tokens 
     */    
    function burn(
        uint256 amount
    ) external;

    /**
     * @notice Destroy CDP tokens from existence from `account`
     * @param account Address to destroy CDP tokens from
     * @param amount Amount of CDP tokens to destroy
     * @dev Requirement: The caller must have a sufficient allowance
     */    
    function burnFrom(
        address account,
        uint256 amount
    ) external;
}


/**
 * @title Carpe Diem Pension
 * @author Carpe Diem
 * @notice Deposit and destroy CDP Tokens to get a share of the daily minted inflation
 * @dev Part of a system of three contracts. The other two are called Auction and CDPToken
 */
contract Pension is Ownable, Initializable {
    /** 
     * @notice Amount of shares in the system
     */
    uint256 public totalShares;

    /** 
     * @notice Pool of shares for the auction
     * @dev These shares cannot claim rewards
     */
    uint256 public auctionShares;

    /**
     * @notice Shares that are pending in the auction
     * @dev These shares cannot claim rewards
     */
    uint256 public activeAuctionShares;

    /** @notice Total amount of CDP rewards claimed */
    uint256 public totalCDPClaimed;

    /** @notice Total amount of shares distributed to referrers */
    uint256 public totalRefShares;

    /** 
     * @notice Number of unique addresses that have deposited
     * @dev Also includes users with destroyed shares 
     */
    uint256 public NoUsers;

    /** @notice Total amount of CDP deposited */
    uint256 public totalDeposited;

    /** 
     * @notice Value that only increases used to calculate users rewards 
     * @dev Increases every time CDP is minted
     */
    uint256 public rewardPerShare;

    /** @notice CDP Token */
    ICDPToken public CDP;
   
    struct UserInfo {
        address referral; // The referrer of the user
        uint256 shares; // How many tokens the user has provided
        uint256 lastInteraction; // last time user interacted
        uint256 CDPCollected; // Rewards collected by the user
        uint256 snapshot; // Saved snapshot of rewardPerShare
        uint256 storedReward; // Stored reward from before the snapshot that the user hasn't claimed yet
    }
    /** @notice Information about the user */
    mapping(address => UserInfo) public userInfo;

    /** @notice Total number of users mapped per day */
    mapping(uint256 => uint256) public NoUsersPerDay;

    struct dayInfo {
        uint256 CDPRewards; // CDP Minted on the day
        uint256 totalShares; // Total amount of shares on the day
    }
    /** @notice Total Rewards per day */
    mapping(uint256 => dayInfo) public dayInfoMap; // Info updated from Auction contract

    /** @notice Address of the Auction contract */
    address public AuctionContractAddress;

    address[] public UsersInfo;

    /** 
     * @notice Deposit by the user 
     * @param user Address of the user
     * @param timestamp Time of the event
     * @param amount Amount deposited
     */
    event DepositCDP(
        address indexed user,
        uint256 timestamp,
        uint256 amount
    );

    /**
     * @notice Shares given to the user
     * @param user Recipient of the shares
     * @param amount Amount of shares given
     */
    event MintShares(
        address indexed user,
        uint256 amount
    );

    /**
     * @notice Claimed rewards by the user
     * @param user Address of the user
     * @param timestamp Time of the event
     * @param amount Amount claimed
     */
    event ClaimCDP(
        address indexed user,
        uint256 timestamp,
        uint256 amount
    );

    /**
     * @notice Compounded rewards by the user
     * @param user Address of the user
     * @param timestamp Time of the event
     * @param amount Amount compounded
     */
    event CompoundCDP(
        address indexed user,
        uint256 timestamp,
        uint256 amount
    );

    /**
     * @notice Constuct the contract
     * @dev Needs to appoint the owner
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Connect to the other contracts
     * @dev Renounce ownership after configuration
     * @param _CDP Address of the CDPToken contract
     * @param _auctionAddress Address of the Auction contract
     */
    function initialize(
        address _CDP,
        address _auctionAddress
    ) public onlyOwner initializer {
        CDP = ICDPToken(_CDP);
        AuctionContractAddress = _auctionAddress;
        renounceOwnership();
    }

    /**
     * @notice Deposit CDP
     * @param _amount Amount of CDP to deposit
     * @param _referral Address of the (new) referrer, not necessary
     * @dev If no referral address is stored nor inserted, the shares go to the Auction pool
     */
    function depositCDP(
        uint256 _amount,
        address _referral
    ) external {
        require(msg.sender != _referral, "No self-referring");
        require(_amount >= 1e15, "Minimum deposit is 0.001 CDP");

        UserInfo storage user = userInfo[msg.sender];

        // Registers the user if the user interacts for the first time
        if (user.lastInteraction == 0) {
            UsersInfo.push(msg.sender);
            NoUsers += 1;
        }

        address ref;

        if (
            // Case 1: No referral is entered (_referral == address(0)) nor is stored for the user (user.referral == address(0))
            _referral == address(0) && user.referral == address(0)
        ) {
            // Set the ref to the auction address
            ref = AuctionContractAddress;
        } else if (
            // Case 2: No referral is entered (_referral == address(0)) but a referral is stored for the user (user.referral != address(0))
            _referral == address(0) && user.referral != address(0)
        ) {
            // Set the ref to the stored referral
            ref = user.referral;
        } else {
            // Case 3: A referral is entered
            // Update the user's referral to the provided referral
            user.referral = _referral;
            // Set the ref to the provided referral
            ref = _referral;
        }

        UserInfo storage userRef = userInfo[ref];
        uint256 snapshot = user.snapshot;
        uint256 userShares = user.shares;
        uint256 refSnapshot = userRef.snapshot;
        uint256 refShares = userRef.shares;
            
        user.storedReward += ((rewardPerShare - snapshot) * userShares) / 1e18; // Stores rewards before taking a new snapshot
        user.snapshot = rewardPerShare; // Takes a new snapshot for the user
        user.shares += _amount;

        if (ref == AuctionContractAddress) {
            auctionShares += (_amount) / 10;
        } else {
            // Registers the referral if the referral has no interactions
            if (userRef.lastInteraction == 0) {
                UsersInfo.push(ref);
                NoUsers += 1;
                userRef.lastInteraction = block.timestamp;
            }            
            // Stores rewards, takes a new snapshot, and adds shares for referral
            userRef.storedReward += ((rewardPerShare - refSnapshot) * refShares) / 1e18; 
            userRef.snapshot = rewardPerShare;
            userRef.shares += _amount / 10;
            totalRefShares += _amount / 10;
        }

        totalDeposited += _amount;
        auctionShares += (_amount * 2) / 10;
        totalShares += (_amount * 13) / 10;
        user.lastInteraction = block.timestamp;
        
        CDP.burnFrom(msg.sender, _amount);

        emit DepositCDP(msg.sender, block.timestamp, _amount);
    }

    /**
     * @notice Claim CDP rewards
     * @dev Compares the current rewardPerShare value with the user's snapshot to calculate the rewards
     */
    function claimCDP() external {
        UserInfo storage user = userInfo[msg.sender];

        uint256 pending;
        uint256 snapshot = user.snapshot;
        uint256 storedReward = user.storedReward;
        uint256 userShares = user.shares;

        pending += (((rewardPerShare - snapshot) * userShares) / 1e18) + storedReward;
        user.snapshot = rewardPerShare; // Takes a new snapshot for the user
        user.storedReward = 0; // Delete stored reward
        totalCDPClaimed += pending;
        user.CDPCollected += pending;
        user.lastInteraction = block.timestamp;

        CDP.transfer(msg.sender, pending);

        emit ClaimCDP(msg.sender, block.timestamp, pending);
    }

    /**
     * @notice Compound CDP rewards and get 15% more shares
     * @dev Referral and Auction shares are cut in half, so the total amount of shares created per CDP deposited remains at 1.3
     */
    function compoundCDP() external {
        UserInfo storage user = userInfo[msg.sender];
        UserInfo storage userRef = userInfo[user.referral];
        uint256 pending;
        uint256 snapshot = user.snapshot;
        uint256 storedReward = user.storedReward;
        uint256 userShares = user.shares;
        uint256 refSnapshot = userRef.snapshot;
        uint256 refShares = userRef.shares;

        pending += (((rewardPerShare - snapshot) * userShares) / 1e18) + storedReward;
        user.storedReward = 0; // Delete stored reward
        user.snapshot = rewardPerShare; // Takes a new snapshot for the user
        user.shares += (pending * 115) / 100;

        if (user.referral == address(0)) {
            // Add referral shares to auctionShares when no referral is stored
            auctionShares += (pending * 5) / 100;
        } else {
            // Stores rewards, takes a new snapshot, and adds shares for referral
            userRef.storedReward += ((rewardPerShare - refSnapshot) * refShares) / 1e18;
            userRef.snapshot = rewardPerShare;
            userRef.shares += (pending * 5) / 100;
            totalRefShares += (pending * 5) / 100;
        }

        totalDeposited += pending;
        auctionShares += (pending * 10) / 100;
        totalShares += (pending * 130) / 100;
        totalCDPClaimed += pending;
        user.CDPCollected += pending;
        user.lastInteraction = block.timestamp;

        CDP.burn(pending);

        emit CompoundCDP(msg.sender, block.timestamp, pending);
    }

    /**
     * @notice Transfer shares from auction to user
     * @dev Called by auction contract to collect shares for the user/day
     * @param _recipient Address to transfer the shares to
     * @param _amount Amount of shares to transfer
     */
    function mintShares(
        address _recipient,
        uint256 _amount
    ) external {
        require(msg.sender == AuctionContractAddress, "No permission");
        UserInfo storage user = userInfo[_recipient];

        uint256 snapshot = user.snapshot;
        uint256 userShares = user.shares;

        user.storedReward += ((rewardPerShare - snapshot) * userShares) / 1e18; // Stores rewards before taking a new snapshot
        user.snapshot = rewardPerShare; // Takes a new snapshot for the user
        user.shares += (_amount);
        user.lastInteraction = block.timestamp;
        activeAuctionShares -= (_amount);
        emit MintShares(_recipient, _amount);
    }

    /**
     * @notice Create daily inflation and add it to the rewards pool
     * @dev Called by auction contract to mint daily distribution and update daily rewards
     * @param _amount Amount of CDP to create
     * @param _day The day for which the inflation is created
     */
    function mintCDP(
        uint256 _amount,
        uint256 _day
    ) external {
        require(msg.sender == AuctionContractAddress, "No permission");
        uint256 denom = totalShares - auctionShares - activeAuctionShares;

        NoUsersPerDay[_day] = NoUsers;
        dayInfoMap[_day].totalShares = totalShares;

        // Only mint and distribute when there are active user shares
        if (denom != 0) {
            rewardPerShare += (_amount * 1e18) / denom;
            dayInfoMap[_day].CDPRewards = _amount;
            CDP.mint(address(this), _amount);
        }
    }

    /**
     * @notice 5% of the shares in the auction pool are transferred to the auction daily
     * @dev Called by auction contract to update Auction shares balance
     */
    function BurnSharesfromAuction() external returns (uint256) {
        require(msg.sender == AuctionContractAddress, "No permission");
        uint256 sharesDistributedinAuction = (5 * auctionShares) / 100;
        activeAuctionShares += sharesDistributedinAuction;
        auctionShares -= sharesDistributedinAuction;

        return sharesDistributedinAuction;
    }

    /**
     * @notice View function to see the pending reward for a user
     * @param _user: Address of the user
     * @return totalPending Pending reward for a given user
     */
    function pendingRewardCDP(
        address _user
    ) public view returns (uint256 totalPending) {
        UserInfo storage user = userInfo[_user];
        uint256 snapshot = user.snapshot;
        uint256 storedReward = user.storedReward;
        uint256 userShares = user.shares;

        totalPending += (((rewardPerShare - snapshot) * userShares) / 1e18) + storedReward; // Could be 0
    }

    /**
     * @notice Delete a user's shares if he hasn't interacted for 1111 days
     * @notice Claims and sends pending rewards to the targetted user
     * @param _target: Address of whom its shares are being destroyed
     */
    function Destroyshares(
        address _target
    ) external {
        UserInfo storage user = userInfo[_target];

        // Require that the current timestamp is greater than the user's last interaction plus 1111 days
        require(
            block.timestamp > user.lastInteraction + 1111 days,
            "Time requirement not met"
        );
        uint256 pending;
        uint256 snapshot = user.snapshot;
        uint256 storedReward = user.storedReward;
        uint256 userShares = user.shares;

        pending += (((rewardPerShare - snapshot) * userShares) / 1e18) + storedReward;
        user.storedReward = 0; // Delete stored reward
        totalCDPClaimed += pending;
        user.CDPCollected += pending;
        totalShares -= user.shares; // Reduce the total shares
        user.shares = 0; // Set the user's shares to 0

        CDP.transfer(_target, pending);

        emit ClaimCDP(_target, block.timestamp, pending);
    }

    /**
     * @notice Prove your presence
     */
    function Iamhere() external {
        UserInfo storage user = userInfo[msg.sender];
        require(
            user.lastInteraction != 0, 
            "Activate your account with depositCDP()"
        );
        user.lastInteraction = block.timestamp;
    }

    /**
     * @notice Get the total number of shares in the system
     * @return totalShares Total amount of shares
     */
    function gettotalShares() external view returns (uint256) {
        return totalShares;
    }
}