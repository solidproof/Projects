// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev MCT is the governance token contract
/// @notice fixed supply token
contract MCT is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 6000000000 * 10 ** 18;
    uint256 public immutable START_TIME;

    uint256 public constant RESERVE_POOL_LOCKUP = 104 weeks;
    uint256 public constant TEAM_LOCKUP = 52 weeks;

    uint256 public constant MINING_POOL_ALLOCATION = 3600000000 * 10 ** 18;
    uint256 public constant AIRDROP_ALLOCATION = 600000000 * 10 ** 18;
    uint256 public constant RESERVE_POOL_ALLOCATION = 720000000 * 10 ** 18;
    uint256 public constant OPERATIONAL_POOL_ALLOCATION = 420000000 * 10 ** 18;
    uint256 public constant TEAM_ALLOCATION = 420000000 * 10 ** 18;
    uint256 public constant INVESTOR_ALLOCATION = 180000000 * 10 ** 18;

    uint256 public constant MINING_POOL_VESTING = 520;
    uint256 public constant AIRDROP_VESTING = 52;
    uint256 public constant RESERVE_POOL_VESTING = 104;
    uint256 public constant OPERATIONAL_POOL_VESTING = 156;
    uint256 public constant TEAM_VESTING = 156;

    address public constant MINING_POOL_RECEIVER =
        0xb54E1c4B3927f4489Ead5c149b7895ecd03a5CE0;
    address public constant AIRDROP_POOL_RECEIVER =
        0xF32fB437A2768f02FaDA4d97aBe76D8f306F44Fe;
    address public constant RESERVE_POOL_RECEIVER =
        0xd1e532C785deEC90c1c69c7c5A7DcD28a8f74248;
    address public constant OPERATIONAL_POOL_RECEIVER =
        0xA0B9Fe04F0E6E44E42C90CfE30507769E91C1919;
    address public constant TEAM_RECEIVER =
        0x8A83d34fa97910B0786d8dAB29C5F3ACA5C1Cc76;

    address public constant INVESTOR_POOL =
        0x910bBe8B14dbe813eA3F0e268058b024Bf5301D9;

    mapping(uint256 => uint256) public poolLastClaimTime; /// maps pool id to last claim time
    mapping(uint256 => uint256) public poolClaimedAmount; /// maps pool id to total claim amount

    mapping(address => bool) public isInvestor;
    mapping(address => uint256) public investment;
    mapping(address => uint256) public investedAt;

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @dev mints the initial supply to the contract deployer
    /// @param initialSupply_ is the initial Supply of the token
    /// @param name_ is the name of the token
    /// @param symbol_ is the ticker of the token
    constructor(
        uint256 initialSupply_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        require(
            MINING_POOL_ALLOCATION +
                AIRDROP_ALLOCATION +
                RESERVE_POOL_ALLOCATION +
                OPERATIONAL_POOL_ALLOCATION +
                TEAM_ALLOCATION +
                initialSupply_ +
                INVESTOR_ALLOCATION ==
                MAX_SUPPLY
        );
        START_TIME = block.timestamp;

        /// @dev mint to the initial supply address provided here
        _mintNow(0x8824fE9FA03d3716A762375867FAC2052Cd54A8C, initialSupply_);
        _mintNow(INVESTOR_POOL, INVESTOR_ALLOCATION);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev allows owner to claim unvested mining pool tokens
    function claimUnvestedMiningPoolTokens() external onlyOwner {
        _claim(1, 0, MINING_POOL_ALLOCATION, MINING_POOL_VESTING);
    }

    /// @dev allows owner to claim unvested airdrop tokens
    function claimUnvestedAirdropTokens() external onlyOwner {
        _claim(2, 0, AIRDROP_ALLOCATION, AIRDROP_VESTING);
    }

    /// @dev allows owner to claim unvested reserve pool tokens
    function claimUnvestedReservePoolTokens() external onlyOwner {
        _claim(
            3,
            RESERVE_POOL_LOCKUP,
            RESERVE_POOL_ALLOCATION,
            RESERVE_POOL_VESTING
        );
    }

    /// @dev allows owner to claim unvested operational pool tokens
    function claimUnvestedOperationalPoolTokens() external onlyOwner {
        _claim(4, 0, OPERATIONAL_POOL_ALLOCATION, OPERATIONAL_POOL_VESTING);
    }

    /// @dev allows owner to claim unvested team tokens
    function claimUnvestedTeamTokens() external onlyOwner {
        _claim(4, TEAM_LOCKUP, TEAM_ALLOCATION, TEAM_VESTING);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _claim(
        uint256 poolId,
        uint256 lockIn,
        uint256 poolAllocation,
        uint256 vestingPeriod
    ) internal {
        uint256 weeksElapsed;
        uint256 timeDiff;

        /// check for lock-in
        require(block.timestamp >= START_TIME + lockIn, "MCT: Lock-in Period");

        /// check weeks elapse
        if (poolLastClaimTime[poolId] == 0) {
            timeDiff = block.timestamp - START_TIME;
        } else {
            timeDiff = block.timestamp - poolLastClaimTime[poolId];
        }

        weeksElapsed = timeDiff / 1 weeks;
        require(weeksElapsed > 0, "MCT: Claim Period Invalid");

        uint256 weeklyReward = poolAllocation / vestingPeriod;
        uint256 totalReward = weeksElapsed * weeklyReward;
        require(
            poolClaimedAmount[poolId] + totalReward <= poolAllocation,
            "MCT: Claim Limit Reached"
        );

        poolClaimedAmount[poolId] += totalReward;
        poolLastClaimTime[poolId] = block.timestamp;

        /// mint each week rewards until reward pool is empty
        _mintNow(owner(), totalReward);
    }

    function _mintNow(address to_, uint256 amount_) internal {
        require(
            totalSupply() + amount_ <= MAX_SUPPLY,
            "MCT: Max Supply Reached"
        );
        _mint(to_, amount_);
    }

    /// @dev overrides native ERC20-{_beforeTokenTransfer} to accomodate for
    /// the investor pool transfer logic
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        /// @dev transfer from investor pool
        if (from == INVESTOR_POOL) {
            isInvestor[to] = true;
            investedAt[to] = block.timestamp; /// @dev locktime overrides on successive investment
            investment[to] += amount;
        }

        /// @dev transfer from vested investor account
        if (isInvestor[from]) {
            uint256 timeDiff = block.timestamp - (investedAt[from] + 26 weeks);
            uint256 weeksElapsed = timeDiff / 1 weeks; /// @dev solidity handles overflow

            if (weeksElapsed >= 52) {
                isInvestor[from] = false;
                investment[from] = 0;
                investedAt[from] = 0;
            } else {
                /// @dev investor can transfer freely aquired tokens
                if (amount <= balanceOf(from) - investment[from]) {
                    require(
                        block.timestamp >= investedAt[from] + 26 weeks,
                        "MCT: Lock-in Period"
                    );

                    require(weeksElapsed > 0, "MCT: Vesting Period");

                    uint256 weeklyVesting = investment[from] / 52 weeks;
                    uint256 amountVested = weeklyVesting * weeksElapsed;

                    require(
                        amount <= amountVested,
                        "MCT: Transfer exceeds Vest"
                    );
                }
            }
        }
    }
}