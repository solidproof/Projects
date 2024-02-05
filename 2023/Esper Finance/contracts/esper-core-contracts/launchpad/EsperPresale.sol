// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/tokens/IXEsperToken.sol";

contract EsperPresale is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  struct UserInfo {
    uint256 contribution; // amount spent to buy ESPER
    address ref; // referral for this account
    uint256 refEarnings; // referral earnings made by this account
    uint256 claimedRefEarnings; // amount of claimed referral earnings
    bool hasClaimed; // has already claimed its contribution
  }

  IERC20 public immutable ESPER; // ESPER token contract
  IXEsperToken public immutable XESPER; // xESPER token contract
  IERC20 public immutable SALE_TOKEN; // token used to participate
  IERC20 public immutable LP_TOKEN; // ESPER LP address

  uint256 public immutable START_TIME; // sale start time
  uint256 public immutable END_TIME; // sale end time

  uint256 public constant REFERRAL_SHARE = 3; // 3%

  mapping(address => UserInfo) public userInfo; // buyers and referrers info
  uint256 public totalRaised; // raised amount, does not take into account referral shares

  uint256 public constant MAX_ESPER_TO_DISTRIBUTE = 15000 ether; // max ESPER amount to distribute during the sale

  // (=200,000 USDC, with USDC having 6 decimals ) amount to reach to distribute max ESPER amount
  uint256 public constant MIN_TOTAL_RAISED_FOR_MAX_ESPER = 200000000000;

  uint256 public constant XESPER_SHARE = 35; // ~1/3 of ESPER bought is returned as xESPER

  address public immutable treasury; // treasury multisig, will receive raised amount

  bool public unsoldTokensBurnt;


  constructor(address esperToken, address xEsperToken, address saleToken, address lpToken, uint256 startTime, uint256 endTime, address treasury_) {
    require(startTime < endTime, "invalid dates");
    require(treasury_ != address(0), "invalid treasury");

    ESPER = IERC20(esperToken);
    XESPER = IXEsperToken(xEsperToken);
    SALE_TOKEN = IERC20(saleToken);
    LP_TOKEN = IERC20(lpToken);
    START_TIME = startTime;
    END_TIME = endTime;
    treasury = treasury_;

    emit EsperPresaleSync(address(this), esperToken, "Esper Presale", 0, MAX_ESPER_TO_DISTRIBUTE, saleToken, startTime, endTime);
  }

  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event EsperPresaleSync(
    address fairAuction,
    address fairAuctionFor,
    string fairAuctionType,
    uint256 hardcap,
    uint256 maxTokenToDistribute,
    address saleToken,
    uint256 startTime,
    uint256 endTime
  );
  event Buy(address indexed user, uint256 amount);
  event ClaimRefEarnings(address indexed user, uint256 amount);
  event Claim(address indexed user, uint256 esperAmount, uint256 xEsperAmount);
  event NewRefEarning(address referrer, uint256 amount);
  event EmergencyWithdraw(address token, uint256 amount);

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /**
   * @dev Check whether the sale is currently active
   *
   * Will be marked as inactive if ESPER has not been deposited into the contract
   */
  modifier isSaleActive() {
    require(hasStarted() && !hasEnded() && ESPER.balanceOf(address(this)) >= MAX_ESPER_TO_DISTRIBUTE, "isActive: sale is not active");
    _;
  }

  /**
   * @dev Check whether users can claim their purchased ESPER
   *
   * Sale must have ended, and LP tokens must have been formed
   */
  modifier isClaimable(){
    require(hasEnded(), "isClaimable: sale has not ended");
    require(LP_TOKEN.totalSupply() > 0, "isClaimable: no LP tokens");
    _;
  }

  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
  * @dev Get remaining duration before the end of the sale
  */
  function getRemainingTime() external view returns (uint256){
    if (hasEnded()) return 0;
    return END_TIME.sub(_currentBlockTimestamp());
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
  function hasEnded() public view returns (bool){
    return END_TIME <= _currentBlockTimestamp();
  }

  /**
  * @dev Returns the amount of ESPER to be distributed based on the current total raised
  */
  function esperToDistribute() public view returns (uint256){
    if (MIN_TOTAL_RAISED_FOR_MAX_ESPER > totalRaised) {
      return MAX_ESPER_TO_DISTRIBUTE.mul(totalRaised).div(MIN_TOTAL_RAISED_FOR_MAX_ESPER);
    }
    return MAX_ESPER_TO_DISTRIBUTE;
  }

  /**
  * @dev Get user share times 1e5
    */
  function getExpectedClaimAmounts(address account) public view returns (uint256 esperAmount, uint256 xEsperAmount) {
    if(totalRaised == 0) return (0, 0);

    UserInfo memory user = userInfo[account];
    uint256 totalEsperAmount = user.contribution.mul(esperToDistribute()).div(totalRaised);

    xEsperAmount = totalEsperAmount.mul(XESPER_SHARE).div(100);
    esperAmount = totalEsperAmount.sub(xEsperAmount);
  }

  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  /**
   * @dev Contribution to the sale
   */
  function buy(uint256 amount, address referralAddress) external isSaleActive nonReentrant {
    require(amount > 0, "buy: zero amount");

    uint256 participationAmount = amount;
    UserInfo storage user = userInfo[msg.sender];

    // handle user's referral
    if (user.contribution == 0 && user.ref == address(0) && referralAddress != address(0) && referralAddress != msg.sender) {
      // If first buy, and does not have any ref already set
      user.ref = referralAddress;
    }
    referralAddress = user.ref;

    if (referralAddress != address(0)) {
      UserInfo storage referrer = userInfo[referralAddress];

      // compute and send referrer share
      uint256 refShareAmount = REFERRAL_SHARE.mul(amount).div(100);
      SALE_TOKEN.safeTransferFrom(msg.sender, address(this), refShareAmount);

      referrer.refEarnings = referrer.refEarnings.add(refShareAmount);
      participationAmount = participationAmount.sub(refShareAmount);

      emit NewRefEarning(referralAddress, refShareAmount);
    }

    // update raised amounts
    user.contribution = user.contribution.add(amount);
    totalRaised = totalRaised.add(amount);

    emit Buy(msg.sender, amount);

    // transfer contribution to treasury
    SALE_TOKEN.safeTransferFrom(msg.sender, treasury, participationAmount);
  }

  /**
   * @dev Claim referral earnings
   */
  function claimRefEarnings() public {
    UserInfo storage user = userInfo[msg.sender];
    uint256 toClaim = user.refEarnings.sub(user.claimedRefEarnings);

    if(toClaim > 0){
      user.claimedRefEarnings = user.claimedRefEarnings.add(toClaim);

      emit ClaimRefEarnings(msg.sender, toClaim);
      SALE_TOKEN.safeTransfer(msg.sender, toClaim);
    }
  }

  /**
   * @dev Claim purchased ESPER during the sale
   */
  function claim() external isClaimable {
    UserInfo storage user = userInfo[msg.sender];

    require(totalRaised > 0 && user.contribution > 0, "claim: zero contribution");
    require(!user.hasClaimed, "claim: already claimed");
    user.hasClaimed = true;

    (uint256 esperAmount, uint256 xEsperAmount) = getExpectedClaimAmounts(msg.sender);

    emit Claim(msg.sender, esperAmount, xEsperAmount);

    // approve ESPER conversion to xESPER
    if (ESPER.allowance(address(this), address(XESPER)) < xEsperAmount) {
      ESPER.safeApprove(address(XESPER), 0);
      ESPER.safeApprove(address(XESPER), type(uint256).max);
    }

    // send ESPER and xESPER contribution
    if(xEsperAmount > 0) XESPER.convertTo(xEsperAmount, msg.sender);
    _safeClaimTransfer(msg.sender, esperAmount);
  }

  /********************************************************/
  /****************** /!\ EMERGENCY ONLY ******************/
  /********************************************************/

  /**
   * @dev Failsafe
   */
  function emergencyWithdrawFunds(address token, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(msg.sender, amount);

    emit EmergencyWithdraw(token, amount);
  }

  /**
   * @dev Burn unsold ESPER tokens if MIN_TOTAL_RAISED_FOR_MAX_ESPER has not been reached
   *
   * Must only be called by the owner
   */
  function burnUnsoldTokens() external onlyOwner {
    require(hasEnded(), "burnUnsoldTokens: presale has not ended");
    require(!unsoldTokensBurnt, "burnUnsoldTokens: already burnt");

    uint256 totalSold = esperToDistribute();
    require(totalSold < MAX_ESPER_TO_DISTRIBUTE, "burnUnsoldTokens: no token to burn");

    unsoldTokensBurnt = true;
    ESPER.transfer(0x000000000000000000000000000000000000dEaD, MAX_ESPER_TO_DISTRIBUTE.sub(totalSold));
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Safe token transfer function, in case rounding error causes contract to not have enough tokens
   */
  function _safeClaimTransfer(address to, uint256 amount) internal {
    uint256 esperBalance = ESPER.balanceOf(address(this));
    bool transferSuccess = false;

    if (amount > esperBalance) {
      transferSuccess = ESPER.transfer(to, esperBalance);
    } else {
      transferSuccess = ESPER.transfer(to, amount);
    }

    require(transferSuccess, "safeClaimTransfer: Transfer failed");
  }

  /**
   * @dev Utility function to get the current block timestamp
   */
  function _currentBlockTimestamp() internal view virtual returns (uint256) {
    return block.timestamp;
  }
}
