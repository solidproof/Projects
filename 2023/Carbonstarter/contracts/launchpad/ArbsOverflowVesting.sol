// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IWETH.sol";
import "./LaunchpadVesting.sol";

contract ArbsOverflowVesting is Ownable, ReentrancyGuard, LaunchpadVesting {
    using SafeERC20 for IERC20;
    using Address for address;

    struct UserInfo {
        uint256 contribution; // amount spent to buy TOKEN
        bool hasClaimed; // has already claimed its allocation
    }

    IERC20 public immutable PROJECT_TOKEN; // Project token contract
    IERC20 public immutable SALE_TOKEN; // token used to participate
    IERC20 public immutable LP_TOKEN; // Project LP address

    uint256 public immutable START_TIME; // sale start time
    uint256 public immutable END_TIME; // sale end time

    mapping(address => UserInfo) public userInfo; // buyers and referrers info
    uint256 public totalRaised; // raised amount

    uint256 public immutable MAX_PROJECT_TOKENS_TO_DISTRIBUTE; // max PROJECT_TOKEN amount to distribute during the sale
    uint256 public immutable MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN; // amount to reach to distribute max PROJECT_TOKEN amount

    address public immutable treasury; // treasury multisig, will receive raised amount

    bool public forceClaimable; // safety measure to ensure that we can force claimable to true in case awaited LP token address plan change during the sale

    address public constant WETH = 0x20b28B1e4665FFf290650586ad76E977EAb90c5D;

    mapping(address => uint256) public claimable;

    constructor(
        IERC20 projectToken,
        IERC20 saleToken,
        IERC20 lpToken,
        uint256 startTime,
        uint256 endTime,
        address treasury_,
        uint256 maxToDistribute,
        uint256 minToRaise
    ) LaunchpadVesting(endTime) {
        require(startTime < endTime, "invalid dates");
        require(treasury_ != address(0), "invalid treasury");
        require(
            address(projectToken) != address(0),
            "invalid projectToken address"
        );
        require(address(saleToken) != address(0), "invalid saleToken address");
        require(address(lpToken) != address(0), "invalid lpToken address");

        PROJECT_TOKEN = projectToken;
        SALE_TOKEN = saleToken;
        LP_TOKEN = lpToken;
        START_TIME = startTime;
        END_TIME = endTime;
        treasury = treasury_;
        MAX_PROJECT_TOKENS_TO_DISTRIBUTE = maxToDistribute;
        MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN = minToRaise;
    }

    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event Buy(address indexed user, uint256 amount);
    event ClaimRefEarnings(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event EmergencyWithdraw(address token, uint256 amount);

    /***********************************************/
    /****************** MODIFIERS ******************/
    /***********************************************/

    //  receive() external payable() {
    //    require(address(saleToken) == WETH, "non ETH sale");
    //  }

    /**
     * @dev Check whether the sale is currently active
     *
     * Will be marked as inactive if PROJECT_TOKEN has not been deposited into the contract
     */
    modifier isSaleActive() {
        require(
            hasStarted() &&
                !hasEnded() &&
                PROJECT_TOKEN.balanceOf(address(this)) >=
                MAX_PROJECT_TOKENS_TO_DISTRIBUTE,
            "isActive: sale is not active"
        );
        _;
    }

    /**
     * @dev Check whether users can claim their purchased PROJECT_TOKEN
     *
     * Sale must have ended, and LP tokens must have been formed
     */
    modifier isClaimable() {
        require(hasEnded(), "isClaimable: sale has not ended");
        require(
            LP_TOKEN.totalSupply() > 0 || forceClaimable,
            "isClaimable: no LP tokens"
        );
        _;
    }

    /**************************************************/
    /****************** PUBLIC VIEWS ******************/
    /**************************************************/

    /**
     * @dev Get remaining duration before the end of the sale
     */
    function getRemainingTime() external view returns (uint256) {
        unchecked {
            if (hasEnded()) return 0;
            return END_TIME - _currentBlockTimestamp();
        }
    }

    /**
     * @dev Returns whether the sale has already started
     */
    function hasStarted() public view returns (bool) {
        return _currentBlockTimestamp() >= START_TIME;
    }

    /**
     * @dev Returns whether the sale has already ended
     */
    function hasEnded() public view returns (bool) {
        return END_TIME <= _currentBlockTimestamp();
    }

    /**
     * @dev Returns the amount of PROJECT_TOKEN to be distributed based on the current total raised
     */
    function tokensToDistribute() public view returns (uint256) {
        if (MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN > totalRaised) {
            return
                (MAX_PROJECT_TOKENS_TO_DISTRIBUTE * totalRaised) /
                MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN;
        }
        return MAX_PROJECT_TOKENS_TO_DISTRIBUTE;
    }

    /**
     * @dev Get user share times 1e5
     */
    function getExpectedClaimAmount(
        address account
    ) public view returns (uint256) {
        if (totalRaised == 0) return 0;

        UserInfo storage user = userInfo[account];
        return (user.contribution * tokensToDistribute()) / totalRaised;
    }

    function getCurrentClaimableToken(
        address user
    ) public view returns (uint256) {
        uint256 amount = getExpectedClaimAmount(user);
        return getUnlockedToken(amount, claimable[user], user);
    }

    /****************************************************************/
    /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
    /****************************************************************/

    function buyETH() external payable isSaleActive nonReentrant {
        require(address(SALE_TOKEN) == WETH, "non ETH sale");
        uint256 amount = msg.value;
        IWETH(WETH).deposit{value: amount}();
        _buy(amount);
    }

    /**
     * @dev Purchase an allocation for the sale for a value of "amount" SALE_TOKEN,
     */
    function buy(uint256 amount) external isSaleActive nonReentrant {
        SALE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        _buy(amount);
    }

    function _buy(uint256 amount) internal {
        require(amount > 0, "buy: zero amount");
        require(
            !address(msg.sender).isContract() &&
                !address(tx.origin).isContract(),
            "FORBIDDEN"
        );
        require(msg.sender == tx.origin, "FORBIDDEN");

        UserInfo storage user = userInfo[msg.sender];

        // update raised amounts
        user.contribution = user.contribution + amount;
        totalRaised = totalRaised + amount;

        emit Buy(msg.sender, amount);
        // transfer contribution to treasury
        SALE_TOKEN.safeTransfer(treasury, amount);
    }

    /**
     * @dev Claim purchased PROJECT_TOKEN during the sale
     */
    function claim() external isClaimable nonReentrant {
        UserInfo storage user = userInfo[msg.sender];

        require(
            totalRaised > 0 && user.contribution > 0,
            "claim: zero contribution"
        );

        if (!user.hasClaimed) {
            uint256 amount = getExpectedClaimAmount(msg.sender);
            user.hasClaimed = true;
            claimable[msg.sender] = amount;
        }

        uint256 claimAmount = getCurrentClaimableToken(msg.sender);
        latestClaimTime[msg.sender] = _currentBlockTimestamp();
        claimable[msg.sender] = claimable[msg.sender] - claimAmount;
        emit Claim(msg.sender, claimAmount);
        if (claimAmount > 0) {
            PROJECT_TOKEN.safeTransfer(msg.sender, claimAmount);
        }
    }

    /****************************************************************/
    /********************** OWNABLE FUNCTIONS  **********************/
    /****************************************************************/
    function setWithdrawDelay(uint24 _withdrawDelay) public onlyOwner {
        _setWithdrawTime(END_TIME + _withdrawDelay);
    }

    function setLinearVestingEndTime(
        uint256 _vestingEndTime
    ) public override onlyOwner {
        super.setLinearVestingEndTime(_vestingEndTime);
    }

    function setCliffPeriod(
        uint256[] calldata claimTimes,
        uint32[] calldata pct
    ) public onlyOwner {
        require(claimTimes.length == pct.length, "dates and pct doesn't match");
        LaunchpadVesting.Cliff[]
            memory cliffPeriod = new LaunchpadVesting.Cliff[](
                claimTimes.length
            );
        for (uint i = 0; i < claimTimes.length; i++) {
            cliffPeriod[i] = LaunchpadVesting.Cliff(claimTimes[i], pct[i]);
        }
        super.setCliffPeriod(cliffPeriod);
    }

    /********************************************************/
    /****************** /!\ EMERGENCY ONLY ******************/
    /********************************************************/

    /**
     * @dev Failsafe
     */
    function emergencyWithdrawFunds(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(block.timestamp > END_TIME, "sale has not ended");
        IERC20(token).safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(token, amount);
    }

    function setForceClaimable() external onlyOwner {
        forceClaimable = true;
    }

    /********************************************************/
    /****************** INTERNAL FUNCTIONS ******************/
    /********************************************************/

    /**
     * @dev Utility function to get the current block timestamp
     */
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
