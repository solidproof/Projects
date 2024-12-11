// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IHLAWToken {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}

interface IHLAWPrizePool {
    function addBuyer(address user, uint256 amount) external;
    function isSessionActive() external returns (bool);
}

interface IDEXRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IPulseFarm {
    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function pendingInc(
        uint256 _pid,
        address _user
    ) external view returns (uint256);
}

interface IHLAWStaking {
    function distributeInstantRewardDividends(uint256 _amount) external;

    function distributeIncentiveDividends(uint256 _amount) external;

    function autoStake(uint256 _pid, address _user, uint256 _amount) external;

    function getPidInfo(
        uint256 _pid
    )
        external
        view
        returns (
            address stakingToken,
            address dripToken,
            uint256 totalStaked,
            uint256 totalRewards,
            uint256 allocPoint,
            bool active
        );

    function getUserInfo(
        uint256 _pid,
        address _account
    )
        external
        view
        returns (
            uint256 amount,
            uint256 totalRedeemed,
            uint256 lastRewardTime,
            uint256 lastAccRewardsPerShare
        );

    function existingUser(address user) external view returns (bool);

    function addUser(address user) external;

    function teamFeeReceiver() external view returns (address);

    function treasuryFeeReceiver() external view returns (address);

    function prizePool() external view returns (address);
}

interface IHLAWReferral {
    function setReferral(address user, address referrer) external;

    function getReferrer(address user) external view returns (address);

    function addReward(address user, uint256 amount) external;
}

contract HLAWExchange is ReentrancyGuard, Ownable {
    // Libraries
    using SafeERC20 for IERC20;

    // Structs
    struct Fees {
        uint256 rewardPoolFee;
        uint256 instantRewardFee;
        uint256 teamFee;
        uint256 prizePoolFee;
        uint256 referralFee;
    }

    // HLAW Token and Contracts
    address public immutable hlawToken;
    IHLAWStaking public hlawStaking;
    IHLAWReferral public hlawReferral;

    // Private Variables & Mappings
    IERC20 private constant daiWplsLpToken =
        IERC20(0xE56043671df55dE5CDf8459710433C10324DE0aE);
    IERC20 private constant wplsToken =
        IERC20(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);
    IERC20 private constant incToken =
        IERC20(0x2fa878Ab3F87CC1C9737Fc071108F904c0B0C95d);
    IERC20 private constant daiToken =
        IERC20(0xefD766cCb38EaF1dfd701853BFCe31359239F305);
    IDEXRouter private constant pulseRouter =
        IDEXRouter(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02);
    IPulseFarm private constant pulseFarm =
        IPulseFarm(0xB2Ca4A66d3e57a5a9A12043B6bAD28249fE302d4);
    uint256 private constant PID = 1;
    uint256 private constant FEE_DENOMINATOR = 10000;
    bool private initialized;

    // Public Variables
    uint256 public refStakeRequired;
    uint256 public refMax = 1000000e18;
    uint256 public totalUsers;
    bool public buysPaused;

    // Fee Receivers
    address public rewardFeeReceiver;

    // Global Fees
    uint256 public totalBuyFee = 1000;
    uint256 public totalSellFee = 1000;
    uint256 public treasuryIncFee = 5000;
    mapping(bool => Fees) public fees;

    // Events
    event Initialized();
    event HLAWBought(address user, uint256 amount);
    event HLAWBoughtFromFee(uint256 amount);
    event HLAWBoughtFromFeeProtocol(uint256 amount);
    event HLAWSold(address user, uint256 amount);
    event FeesUpdated(
        bool isSell,
        uint256 rewardPoolFee,
        uint256 instantRewardFee,
        uint256 teamFee,
        uint256 prizePoolFee,
        uint256 referralFee
    );
    event GlobalFeesUpdated(uint256 totalBuyFee, uint256 totalSellFee);
    event RefRequirementUpdated(uint256 newRefRequirement);
    event RefMaxUpdated(uint256 newMaximum);
    event BuysPaused(bool paused);

    constructor(address _hlawToken) Ownable(msg.sender) {
        hlawToken = _hlawToken;

        daiWplsLpToken.approve(address(pulseFarm), type(uint256).max);
        wplsToken.approve(address(pulseRouter), type(uint256).max);
        daiToken.approve(address(pulseRouter), type(uint256).max);
        incToken.approve(address(pulseRouter), type(uint256).max);

        refStakeRequired = 100000000000000000000;

        fees[false].rewardPoolFee = 4000;
        fees[false].instantRewardFee = 1000;
        fees[false].teamFee = 2000;
        fees[false].prizePoolFee = 2000;
        fees[false].referralFee = 1000;
        fees[true].rewardPoolFee = 4000;
        fees[true].instantRewardFee = 1000;
        fees[true].teamFee = 4000;
        fees[true].prizePoolFee = 1000;
        fees[true].referralFee = 0;
    }

    /*
     **********************************************************************************
     ***************************** User Functions ************************************
     **********************************************************************************
     */

    function buy(uint256 amount, address referral, bool autoStake) public nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(!buysPaused, "New buys are currently paused.");
        // Set initial variables
        uint256 netAmount = amount;
        uint256 fee = 0;

        // Check if new user and increment if new
        if (hlawStaking.existingUser(msg.sender) == false) {
            hlawStaking.addUser(msg.sender);
        }

        // Set referral
        if (referral != address(0)) {
            (uint256 refStaked, , , ) = hlawStaking.getUserInfo(PID, referral);
            if (refStaked >= refStakeRequired) {
                hlawReferral.setReferral(msg.sender, referral);
            }
        }

        if (msg.sender != hlawStaking.treasuryFeeReceiver() && totalBuyFee > 0) {
            // Calculate fee
            fee = (amount * totalBuyFee) / FEE_DENOMINATOR;
            netAmount = amount - fee;
        }

        // Transfer DAI/WPLS LP tokens from sender to this contract
        daiWplsLpToken.safeTransferFrom(msg.sender, address(this), amount);

        // Check if INC will be claimed
        uint256 claimAmount = pulseFarm.pendingInc(PID, address(this));

        // Deposit netAmount DAI/WPLS LP tokens into the PulseX Farm contract
        pulseFarm.deposit(PID, amount);

        // Distribute Incentives Gained
        if (claimAmount > 0) {
            (, , uint256 totalStaked, , , ) = hlawStaking.getPidInfo(PID);

            uint256 amountToDistribute = claimAmount * totalStaked / IERC20(hlawToken).totalSupply();
            uint256 amountToTreasury = (claimAmount - amountToDistribute) * treasuryIncFee / FEE_DENOMINATOR;

            if (totalStaked > 0) {
                if (amountToDistribute > 0) {
                    hlawStaking.distributeIncentiveDividends(amountToDistribute);
                }

                if (amountToTreasury > 0) {
                    _incentiveSwap(amountToTreasury);
                }
            }
        }

        if (incToken.balanceOf(address(this)) > 0) {
            incToken.safeTransfer(hlawStaking.teamFeeReceiver(), incToken.balanceOf(address(this)));
        }

        // Mint and distribute fees
        if (msg.sender != hlawStaking.treasuryFeeReceiver() && totalBuyFee > 0) {
            IHLAWToken(hlawToken).mint(address(this), fee);
            uint256 toRewardPool = (fee * fees[false].rewardPoolFee) / FEE_DENOMINATOR;
            uint256 toInstantReward = (fee * fees[false].instantRewardFee) / FEE_DENOMINATOR;
            uint256 toTeam = (fee * fees[false].teamFee) / FEE_DENOMINATOR;
            uint256 toPrizePool = (fee * fees[false].prizePoolFee) / FEE_DENOMINATOR;
            uint256 toReferral = (fee * fees[false].referralFee) / FEE_DENOMINATOR;

            if (toRewardPool > 0) {
                IERC20(hlawToken).safeTransfer(rewardFeeReceiver, toRewardPool);
            }

            if (toInstantReward > 0) {
                (, , uint256 totalStaked, , , ) = hlawStaking.getPidInfo(PID);

                if (totalStaked > 0) {
                    hlawStaking.distributeInstantRewardDividends(toInstantReward);
                } else {
                    IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toInstantReward);
                }
            }

            if (toTeam > 0) {
                IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toTeam);
            }

            if (toPrizePool > 0) {
                IERC20(hlawToken).safeTransfer(hlawStaking.prizePool(), toPrizePool);
            }

            if (toReferral > 0) {
                if (hlawReferral.getReferrer(msg.sender) != address(0)) {
                    (uint256 refStaked, , , ) = hlawStaking.getUserInfo(PID, hlawReferral.getReferrer(msg.sender));

                    if (refStaked >= refStakeRequired) {
                        IERC20(hlawToken).safeTransfer(address(hlawReferral), toReferral);
                        hlawReferral.addReward(msg.sender, toReferral);
                    } else {
                        IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toReferral);
                    }
                } else {
                    IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toReferral);
                }
            }
        }

        // Mint HLAW tokens to the sender equivalent to netAmount, or auto stake if enabled
        if (!autoStake) {
            IHLAWToken(hlawToken).mint(msg.sender, netAmount);
        } else {
            IHLAWToken(hlawToken).mint(address(this), netAmount);
            hlawStaking.autoStake(PID, msg.sender, netAmount);
        }

        try    IHLAWPrizePool(hlawStaking.prizePool()).addBuyer(
                msg.sender,
                amount
            )
        {} catch {}

        emit HLAWBought(msg.sender, netAmount);
    }

    function sell(uint256 amount) public nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer HLAW tokens from the sender to this contract
        IERC20(hlawToken).safeTransferFrom(msg.sender, address(this), amount);

        // Set initial variables
        uint256 netAmount = amount;
        uint256 fee = 0;

        // Calculate fee
        if (msg.sender != hlawStaking.treasuryFeeReceiver() && totalSellFee > 0) {
            fee = (amount * totalSellFee) / FEE_DENOMINATOR;
            netAmount = amount - fee;

            // Distribute fees
            uint256 toRewardPool = (fee * fees[true].rewardPoolFee) / FEE_DENOMINATOR;
            uint256 toInstantReward = (fee * fees[true].instantRewardFee) / FEE_DENOMINATOR;
            uint256 toTeam = (fee * fees[true].teamFee) / FEE_DENOMINATOR;
            uint256 toPrizePool = (fee * fees[true].prizePoolFee) / FEE_DENOMINATOR;
            uint256 toReferral = (fee * fees[true].referralFee) / FEE_DENOMINATOR;

            if (toRewardPool > 0) {
                IERC20(hlawToken).safeTransfer(rewardFeeReceiver, toRewardPool);
            }

            if (toInstantReward > 0) {
                (, , uint256 totalStaked, , , ) = hlawStaking.getPidInfo(PID);
                if (totalStaked > 0) {
                    hlawStaking.distributeInstantRewardDividends(toInstantReward);
                } else {
                    IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toInstantReward);
                }
            }

            if (toTeam > 0) {
                IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toTeam);
            }

            if (toPrizePool > 0) {
                IERC20(hlawToken).safeTransfer(hlawStaking.prizePool(), toPrizePool);
            }

            if (toReferral > 0) {
                if (hlawReferral.getReferrer(msg.sender) == address(0)) {
                    IERC20(hlawToken).safeTransfer(hlawStaking.teamFeeReceiver(), toReferral);
                } else {
                    IERC20(hlawToken).safeTransfer(address(hlawReferral), toReferral);
                    hlawReferral.addReward(msg.sender, toReferral);
                }
            }
        }

        // Burn netAmount of HLAW
        IHLAWToken(hlawToken).burn(netAmount);

        // Check if INC will be claimed
        uint256 claimAmount = pulseFarm.pendingInc(PID, address(this));

        // Withdraw netAmount DAI/WPLS LP tokens into the PulseX Farm contract
        pulseFarm.withdraw(PID, netAmount);

        // Distribute Incentives Gained
        if (claimAmount > 0) {
            (, , uint256 totalStaked, , , ) = hlawStaking.getPidInfo(PID);
            uint256 amountToDistribute = claimAmount * totalStaked / IERC20(hlawToken).totalSupply();
            uint256 amountToTreasury = (claimAmount - amountToDistribute) * treasuryIncFee / FEE_DENOMINATOR;

            if (totalStaked > 0) {
                if (amountToDistribute > 0) {
                    hlawStaking.distributeIncentiveDividends(amountToDistribute);
                }

                if (amountToTreasury > 0) {
                    _incentiveSwap(amountToTreasury);
                }
            }
        }

        if (incToken.balanceOf(address(this)) > 0) {
            incToken.safeTransfer(hlawStaking.teamFeeReceiver(), incToken.balanceOf(address(this)));
        }

        // Transfer netAmount DAI/WPLS LP tokens from this contract to the sender
        daiWplsLpToken.safeTransfer(msg.sender, netAmount);

        emit HLAWSold(msg.sender, amount);
    }

    /*
     **********************************************************************************
     **************************** External Functions **********************************
     **********************************************************************************
     */

    function buyFromFee(uint256 amount) external {
        require(
            msg.sender == address(hlawStaking),
            "Only the HLAW Staking contract can call this function."
        );
        require(amount > 0, "Amount must be greater than 0");

        // Transfer DAI/WPLS LP tokens from sender to this contract
        daiWplsLpToken.safeTransferFrom(msg.sender, address(this), amount);

        // Check if INC will be claimed
        uint256 claimAmount = pulseFarm.pendingInc(PID, address(this));

        // Deposit netAmount DAI/WPLS LP tokens into the PulseX Farm contract
        pulseFarm.deposit(PID, amount);

        // Distribute Incentives Gained
        if (claimAmount > 0) {
            (, , uint256 totalStaked, , , ) = hlawStaking.getPidInfo(PID);
            uint256 amountToDistribute = claimAmount * totalStaked / IERC20(hlawToken).totalSupply();
            uint256 amountToTreasury = (claimAmount - amountToDistribute) * treasuryIncFee / FEE_DENOMINATOR;

            if (totalStaked > 0) {
                if (amountToDistribute > 0) {
                    hlawStaking.distributeIncentiveDividends(amountToDistribute);
                }

                if (amountToTreasury > 0) {
                    _incentiveSwap(amountToTreasury);
                }
            }
        }

        if (incToken.balanceOf(address(this)) > 0) {
            incToken.safeTransfer(hlawStaking.teamFeeReceiver(), incToken.balanceOf(address(this)));
        }

        // Mint HLAW tokens to the staking contract equivalent to amount.
        IHLAWToken(hlawToken).mint(msg.sender, amount);

        emit HLAWBoughtFromFee(amount);
    }

    /*
     **********************************************************************************
     ***************************** Internal Functions *********************************
     **********************************************************************************
     */

    function _buyFromFee(uint256 amount) internal {
        require(amount > 0, "Amount must be greater than 0");

        // Deposit netAmount DAI/WPLS LP tokens into the PulseX Farm contract
        pulseFarm.deposit(PID, amount);

        // Mint HLAW tokens to the staking contract equivalent to amount.
        IHLAWToken(hlawToken).mint(address(this), amount);
        hlawStaking.autoStake(PID, hlawStaking.treasuryFeeReceiver(), amount);

        emit HLAWBoughtFromFeeProtocol(amount);
    }

    function _incentiveSwap(uint256 amount) internal {
        // Track starting WPLS balance
        uint256 wplsBefore = wplsToken.balanceOf(address(this));

        // Swap 100% of INC to WPLS
        address[] memory path = new address[](2);
        path[0] = address(incToken);
        path[1] = address(wplsToken);

        pulseRouter.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);

        // Track WPLS gained and DAI starting balance
        uint256 wplsGained = wplsToken.balanceOf(address(this)) - wplsBefore;
        uint256 daiBefore = daiToken.balanceOf(address(this));

        // Swap 50% of WPLS to DAI
        address[] memory path2 = new address[](2);
        path2[0] = address(wplsToken);
        path2[1] = address(daiToken);

        pulseRouter.swapExactTokensForTokens(wplsGained / 2, 0, path2, address(this), block.timestamp);

        // Track DAI gained
        uint256 daiGained = daiToken.balanceOf(address(this)) - daiBefore;

        // Add LP and track the amount of LP tokens gained
        (, , uint256 lpTokenGained) = pulseRouter.addLiquidity(address(wplsToken), address(daiToken), wplsGained / 2, daiGained, 0, 0, address(this), block.timestamp);

        // Buy HLAW with DAI/WPLS LP Tokens
        _buyFromFee(lpTokenGained);

        // There may be dust remnants remaining of WPLS/DAI, we will send these to the teamFee receiver so the contract remains good accounting.
        if (wplsToken.balanceOf(address(this)) > wplsBefore) {
            uint256 wplsRefund = wplsToken.balanceOf(address(this)) - wplsBefore;
            wplsToken.safeTransfer(hlawStaking.teamFeeReceiver(), wplsRefund);
        }

        if (daiToken.balanceOf(address(this)) > daiBefore) {
            uint256 daiRefund = daiToken.balanceOf(address(this)) - daiBefore;
            daiToken.safeTransfer(hlawStaking.teamFeeReceiver(), daiRefund);
        }
    }

    /*
     **********************************************************************************
     ***************************** Admin Functions ************************************
     **********************************************************************************
     */

    function init(address _hlawStaking, address _hlawReferral, address _rewardPool) external onlyOwner {
        require(!initialized, "Can only initialize once!");
        require(
            _hlawStaking != address(0) && _hlawReferral != address(0) && _rewardPool != address(0),
            "Invalid address set."
        );
        rewardFeeReceiver = _rewardPool;
        hlawStaking = IHLAWStaking(_hlawStaking);
        hlawReferral = IHLAWReferral(_hlawReferral);
        IERC20(hlawToken).approve(_hlawStaking, type(uint256).max);
        incToken.approve(address(_hlawStaking), type(uint256).max);

        initialized = true;
        emit Initialized();
    }

    function pauseBuys(bool _paused) external onlyOwner {
        require(
            _paused == false || !IHLAWPrizePool(hlawStaking.prizePool()).isSessionActive(), 
            "Can only pause buys when there is no active prize session."
        );
        buysPaused = _paused;

        emit BuysPaused(_paused);
    }

    function setFees(
        bool _isSell,
        uint256 _rewardPoolFee,
        uint256 _instantRewardFee,
        uint256 _teamFee,
        uint256 _prizePoolFee,
        uint256 _referralFee
    ) external onlyOwner {
        fees[_isSell].rewardPoolFee = _rewardPoolFee;
        fees[_isSell].instantRewardFee = _instantRewardFee;
        fees[_isSell].teamFee = _teamFee;
        fees[_isSell].prizePoolFee = _prizePoolFee;
        fees[_isSell].referralFee = _referralFee;
        require(
            _rewardPoolFee +
                _instantRewardFee +
                _teamFee +
                _prizePoolFee +
                _referralFee ==
                10000,
            "The total must equal 10000"
        );

        emit FeesUpdated(
            _isSell,
            _rewardPoolFee,
            _instantRewardFee,
            _teamFee,
            _prizePoolFee,
            _referralFee
        );
    }

    function setGlobalFees(
        uint256 _totalBuyFee,
        uint256 _totalSellFee,
        uint256 _treasuryIncFee
    ) external onlyOwner {
        totalBuyFee = _totalBuyFee;
        totalSellFee = _totalSellFee;
        treasuryIncFee = _treasuryIncFee;
        require(treasuryIncFee <= 10000, "Max of 100 percent.");
        require(totalBuyFee <= 1000, "Maximum of 10 percent total buy fee.");
        require(totalSellFee <= 1000, "Maximum of 10 percent total sell fee.");

        emit GlobalFeesUpdated(_totalBuyFee, _totalSellFee);
    }

    function updateRefRequirement(
        uint256 _newRefRequirement
    ) external onlyOwner {
        require(
            _newRefRequirement <= refMax,
            "Over the currently set maximum."
        );
        refStakeRequired = _newRefRequirement;

        emit RefRequirementUpdated(_newRefRequirement);
    }

    function updateMaxRefRequirement(uint256 _newMaximum) external onlyOwner {
        refMax = _newMaximum;

        emit RefMaxUpdated(_newMaximum);
    }
}
