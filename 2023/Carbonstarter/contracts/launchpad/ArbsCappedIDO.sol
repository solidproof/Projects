// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IWETH.sol";

contract ArbsCappedIDO is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    struct UserInfo {
        uint256 allocation; // amount taken into account to obtain TOKEN (amount spent + discount)
        uint256 contribution; // amount spent to buy TOKEN
        bool hasClaimed; // has already claimed its allocation
    }

    IERC20 public immutable PROJECT_TOKEN; // Project token contract
    IERC20 public immutable SALE_TOKEN; // token used to participate
    IERC20 public immutable LP_TOKEN; // Project LP address

    uint256 public immutable START_TIME; // sale start time
    uint256 public immutable END_TIME; // sale end time

    mapping(address => UserInfo) public userInfo; // buyers and referrers info
    uint256 public totalRaised; // raised amount, does not take into account referral shares
    uint256 public totalAllocation; // takes into account discounts

    uint256 public immutable MAX_PROJECT_TOKENS_TO_DISTRIBUTE; // max PROJECT_TOKEN amount to distribute during the sale
    uint256 public immutable MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN; // amount to reach to distribute max PROJECT_TOKEN amount

    uint256 public immutable MAX_RAISE_AMOUNT;
    uint256 public CAP_PER_WALLET;

    address public immutable treasury; // treasury multisig, will receive raised amount

    bool public unsoldTokensBurnt;

    bool public forceClaimable; // safety measure to ensure that we can force claimable to true in case awaited LP token address plan change during the sale

    bool public hardCapReached;

    bool public noLimits;

    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    constructor(
        IERC20 projectToken,
        IERC20 saleToken,
        IERC20 lpToken,
        uint256 startTime,
        uint256 endTime,
        address treasury_,
        uint256 maxToDistribute,
        uint256 minToRaise,
        uint256 maxToRaise,
        uint256 capPerWallet
    ) {
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
        if (maxToRaise == 0) {
            maxToRaise = type(uint256).max;
        }
        MAX_RAISE_AMOUNT = maxToRaise;
        require(
            minToRaise <= maxToRaise,
            "Min. raise value is larger than max. raise value"
        );
        if (capPerWallet == 0) {
            capPerWallet = type(uint256).max;
        }
        CAP_PER_WALLET = capPerWallet;
    }

    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event Buy(address indexed user, uint256 amount);
    event ClaimRefEarnings(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event NewRefEarning(address referrer, uint256 amount);
    event DiscountUpdated();
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
        if (hasEnded()) return 0;
        unchecked {
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
        if (totalAllocation == 0) return 0;

        UserInfo storage user = userInfo[account];
        return (user.allocation * tokensToDistribute()) / totalAllocation;
    }

    /****************************************************************/
    /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
    /****************************************************************/

    function buyETH() external payable isSaleActive nonReentrant {
        require(address(SALE_TOKEN) == WETH, "non ETH sale");
        uint256 amount = msg.value;
        IWETH(WETH).deposit{value: amount}();
        _buy(amount, false);
    }

    /**
     * @dev Purchase an allocation for the sale for a value of "amount" SALE_TOKEN, referred by "referralAddress"
     */
    function buy(uint256 amount) external isSaleActive nonReentrant {
        _buy(amount, true);
    }

    function _buy(uint256 amount, bool transferToTreasury) internal {
        require(amount > 0, "buy: zero amount");
        require(!hardCapReached, "buy: hardcap reached");
        uint256 excessAmount;
        if (totalRaised + amount >= MAX_RAISE_AMOUNT) {
            excessAmount = amount - (MAX_RAISE_AMOUNT - totalRaised);
            unchecked {
                amount = MAX_RAISE_AMOUNT - totalRaised;
            }
            hardCapReached = true;
        }
        require(
            !address(msg.sender).isContract() &&
                !address(tx.origin).isContract(),
            "FORBIDDEN"
        );
        require(msg.sender == tx.origin, "FORBIDDEN");

        uint256 participationAmount = amount;

        UserInfo storage user = userInfo[msg.sender];

        require(
            user.contribution + amount <= CAP_PER_WALLET,
            "buy: wallet cap reached"
        );

        uint256 allocation = amount;

        // update raised amounts
        user.contribution = user.contribution + amount;
        totalRaised = totalRaised + amount;

        // update allocations
        user.allocation = user.allocation + allocation;
        totalAllocation = totalAllocation + allocation;

        emit Buy(msg.sender, participationAmount);

        // transfer contribution to treasury
        if (transferToTreasury) {
            SALE_TOKEN.safeTransferFrom(
                msg.sender,
                treasury,
                participationAmount
            );
        }
        if (address(SALE_TOKEN) == WETH && excessAmount > 0) {
            SALE_TOKEN.safeTransfer(msg.sender, excessAmount);
        }
    }

    /**
     * @dev Claim purchased PROJECT_TOKEN during the sale
     */
    function claim() external isClaimable {
        UserInfo storage user = userInfo[msg.sender];

        require(
            totalAllocation > 0 && user.allocation > 0,
            "claim: zero allocation"
        );
        require(!user.hasClaimed, "claim: already claimed");
        user.hasClaimed = true;

        uint256 amount = getExpectedClaimAmount(msg.sender);

        emit Claim(msg.sender, amount);

        // send PROJECT_TOKEN allocation
        PROJECT_TOKEN.safeTransfer(msg.sender, amount);
    }

    /****************************************************************/
    /********************** OWNABLE FUNCTIONS  **********************/
    /****************************************************************/

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

    /**
     * @dev Burn unsold PROJECT_TOKEN if MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN has not been reached
     *
     * Must only be called by the owner
     */
    function burnUnsoldTokens() external onlyOwner {
        require(hasEnded(), "burnUnsoldTokens: presale has not ended");
        require(!unsoldTokensBurnt, "burnUnsoldTokens: already burnt");

        uint256 totalSold = tokensToDistribute();
        require(
            totalSold < MAX_PROJECT_TOKENS_TO_DISTRIBUTE,
            "burnUnsoldTokens: no token to burn"
        );

        unsoldTokensBurnt = true;
        unchecked {
            PROJECT_TOKEN.safeTransfer(
                0x000000000000000000000000000000000000dEaD,
                MAX_PROJECT_TOKENS_TO_DISTRIBUTE - totalSold
            );
        }
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
