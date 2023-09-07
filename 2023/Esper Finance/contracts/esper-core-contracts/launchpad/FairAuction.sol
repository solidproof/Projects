// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/tokens/IWETH.sol";

contract FairAuction is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using Address for address;

  struct UserInfo {
    uint256 contribution; // amount spent to buy TOKEN
    bool whitelisted;
    uint256 whitelistCap;
    bool hasClaimed; // has already claimed its contribution
  }

  IERC20 public immutable PROJECT_TOKEN; // Project token contract
  IERC20 public immutable PROJECT_TOKEN_2; // Project token contract (eg. vested tokens)
  IERC20 public immutable SALE_TOKEN; // token used to participate
  IERC20 public immutable LP_TOKEN; // Project LP address

  uint256 public immutable START_TIME; // max PROJECT_TOKEN amount to distribute during the sale
  uint256 public immutable END_TIME; // max PROJECT_TOKEN amount to distribute during the sale

  mapping(address => UserInfo) public userInfo; // buyers info
  uint256 public totalRaised; // raised amount

  uint256 public immutable MAX_PROJECT_TOKENS_TO_DISTRIBUTE; // max PROJECT_TOKEN amount to distribute during the sale
  uint256 public immutable MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE; // max PROJECT_TOKEN_2 amount to distribute during the sale
  uint256 public immutable MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN; // amount to reach to distribute max PROJECT_TOKEN amount

  uint256 public immutable MAX_RAISE_AMOUNT;
  uint256 public immutable CAP_PER_WALLET;

  address public treasury; // treasury multisig, will receive raised amount

  bool public whitelistOnly;
  bool public unsoldTokensWithdrew;

  bool public forceClaimable; // safety measure to ensure that we can force claimable to true in case awaited LP token address plan change during the sale
  bool public isPaused;

  address public constant OPERATOR = 0x222Da5f13D800Ff94947C20e8714E103822Ff716;
  address public constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

  constructor
  (
    address projectToken, address projectToken2, address saleToken, address lpToken,
    uint256 startTime, uint256 endTime, address treasury_,
    uint256 maxToDistribute, uint256 maxToDistribute2, uint256 minToRaise, uint256 maxToRaise, uint256 capPerWallet
  ) {
    require(startTime < endTime, "invalid dates");
    require(treasury_ != address(0), "invalid treasury");

    transferOwnership(OPERATOR);
    PROJECT_TOKEN = IERC20(projectToken);
    PROJECT_TOKEN_2 = IERC20(projectToken2);
    SALE_TOKEN = IERC20(saleToken);
    LP_TOKEN = IERC20(lpToken);
    START_TIME = startTime;
    END_TIME = endTime;
    treasury = treasury_;
    MAX_PROJECT_TOKENS_TO_DISTRIBUTE = maxToDistribute;
    MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE = maxToDistribute2;
    MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN = minToRaise;
    if(maxToRaise == 0) {
      maxToRaise = type(uint256).max;
    }
    MAX_RAISE_AMOUNT = maxToRaise;
    if(capPerWallet == 0) {
      capPerWallet = type(uint256).max;
    }
    CAP_PER_WALLET = capPerWallet;

    whitelistOnly = true;
  }

  /********************************************/
  /****************** EVENTS ******************/
  /********************************************/

  event Buy(address indexed user, uint256 amount);
  event Claim(address indexed user, uint256 amount, uint256 amount2);
  event DiscountUpdated();
  event WhitelistUpdated();
  event EmergencyWithdraw(address token, uint256 amount);
  event SetWhitelistOnly(bool status);
  event SetPause(bool status);

  /***********************************************/
  /****************** MODIFIERS ******************/
  /***********************************************/

  /**
   * @dev Check whether the sale is currently active
   *
   * Will be marked as inactive if PROJECT_TOKEN has not been deposited into the contract
   */
  modifier isSaleActive() {
    require(hasStarted() && !hasEnded(), "isActive: sale is not active");
    require(PROJECT_TOKEN.balanceOf(address(this)) >= MAX_PROJECT_TOKENS_TO_DISTRIBUTE, "isActive: sale not filled");
    if(address(PROJECT_TOKEN_2) != address(0)) {
        require(PROJECT_TOKEN_2.balanceOf(address(this)) >= MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE, "isActive: sale not filled 2");
    }
    _;
  }

  /**
   * @dev Check whether the sale is currently paused
   */
  modifier isNotPaused() {
    require(!isPaused, "isNotPaused: sale is paused");
    _;
  }

  /**
   * @dev Check whether users can claim their purchased PROJECT_TOKEN
   *
   * Sale must have ended, and LP tokens must have been formed
   */
  modifier isClaimable() {
    require(hasEnded(), "isClaimable: sale has not ended");
    require(forceClaimable || LP_TOKEN.totalSupply() > 0, "isClaimable: no LP tokens");
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
  * @dev Returns the amount of PROJECT_TOKEN to be distributed based on the current total raised
  */
  function projectTokensToDistribute() public view returns (uint256){
    if (MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN > totalRaised) {
      return MAX_PROJECT_TOKENS_TO_DISTRIBUTE.mul(totalRaised).div(MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN);
    }
    return MAX_PROJECT_TOKENS_TO_DISTRIBUTE;
  }

  /**
  * @dev Returns the amount of PROJECT_TOKEN_2 to be distributed based on the current total raised
  */
  function projectTokens2ToDistribute() public view returns (uint256){
    if(address(PROJECT_TOKEN_2) == address(0)) {
      return 0;
    }
    if (MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN > totalRaised) {
      return MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE.mul(totalRaised).div(MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN);
    }
    return MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE;
  }

  /**
  * @dev Returns the amount of PROJECT_TOKEN + PROJECT_TOKEN_2 to be distributed based on the current total raised
  */
  function tokensToDistribute() public view returns (uint256){
    return projectTokensToDistribute().add(projectTokens2ToDistribute());
  }

  /**
  * @dev Get user tokens amount to claim
    */
  function getExpectedClaimAmount(address account) public view returns (uint256 projectTokenAmount, uint256 projectToken2Amount) {
    if(totalRaised == 0) return (0, 0);

    UserInfo memory user = userInfo[account];
    projectTokenAmount = user.contribution.mul(projectTokensToDistribute()).div(totalRaised);
    projectToken2Amount = user.contribution.mul(projectTokens2ToDistribute()).div(totalRaised);
  }

  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  function buyETH() external isSaleActive isNotPaused nonReentrant payable {
    require(address(SALE_TOKEN) == weth, "non ETH sale");
    uint256 amount = msg.value;
    IWETH(weth).deposit{value: amount}();
    _buy(amount);
  }

  /**
   * @dev Contribution to the sale
   */
  function buy(uint256 amount) external isSaleActive isNotPaused nonReentrant {
    SALE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
    _buy(amount);
  }

  function _buy(uint256 amount) internal {
    require(amount > 0, "buy: zero amount");
    require(totalRaised.add(amount) <= MAX_RAISE_AMOUNT, "buy: hardcap reached");

    UserInfo storage user = userInfo[msg.sender];

    if(whitelistOnly) {
      require(user.whitelisted, "buy: not whitelisted");
      require(user.contribution.add(amount) <= user.whitelistCap, "buy: whitelist wallet cap reached");
    }
    else{
      uint256 userWalletCap = CAP_PER_WALLET > user.whitelistCap ? CAP_PER_WALLET : user.whitelistCap;
      require(user.contribution.add(amount) <= userWalletCap, "buy: wallet cap reached");
    }

    // update raised amounts
    user.contribution = user.contribution.add(amount);
    totalRaised = totalRaised.add(amount);

    emit Buy(msg.sender, amount);

    // transfer contribution to treasury
    SALE_TOKEN.safeTransfer(treasury, amount);
  }

  /**
   * @dev Claim purchased PROJECT_TOKEN during the sale
   */
  function claim() external isClaimable {
    UserInfo storage user = userInfo[msg.sender];

    require(totalRaised > 0 && user.contribution > 0, "claim: zero contribution");
    require(!user.hasClaimed, "claim: already claimed");
    user.hasClaimed = true;

    (uint256 token1Amount, uint256 token2Amount) = getExpectedClaimAmount(msg.sender);

    emit Claim(msg.sender, token1Amount, token2Amount);

    if(token1Amount > 0) {
      _safeClaimTransfer(PROJECT_TOKEN, msg.sender, token1Amount);
    }
    if(token2Amount > 0) {
      _safeClaimTransfer(PROJECT_TOKEN_2, msg.sender, token2Amount);
    }
  }

  /****************************************************************/
  /********************** OWNABLE FUNCTIONS  **********************/
  /****************************************************************/

  struct WhitelistSettings {
    address account;
    bool whitelisted;
    uint256 whitelistCap;
  }

  /**
   * @dev Assign whitelist status and cap for users
   */
  function setUsersWhitelist(WhitelistSettings[] calldata users) public onlyOwner {
    for (uint256 i = 0; i < users.length; ++i) {
      WhitelistSettings memory userWhitelist = users[i];
      UserInfo storage user = userInfo[userWhitelist.account];
      user.whitelisted = userWhitelist.whitelisted;
      user.whitelistCap = userWhitelist.whitelistCap;
    }

    emit WhitelistUpdated();
  }

  function setWhitelistOnly(bool value) external onlyOwner {
    whitelistOnly = value;
    emit SetWhitelistOnly(value);
  }

  function setPause(bool value) external onlyOwner {
    isPaused = value;
    emit SetPause(value);
  }

  /**
   * @dev Withdraw unsold PROJECT_TOKEN + PROJECT_TOKEN_2 if MIN_TOTAL_RAISED_FOR_MAX_PROJECT_TOKEN has not been reached
   *
   * Must only be called by the owner
   */
  function withdrawUnsoldTokens() external onlyOwner {
    require(hasEnded(), "withdrawUnsoldTokens: presale has not ended");
    require(!unsoldTokensWithdrew, "withdrawUnsoldTokens: already burnt");

    uint256 totalTokenSold = projectTokensToDistribute();
    uint256 totalToken2Sold = projectTokens2ToDistribute();

    unsoldTokensWithdrew = true;
    if(totalTokenSold > 0) PROJECT_TOKEN.transfer(msg.sender, MAX_PROJECT_TOKENS_TO_DISTRIBUTE.sub(totalTokenSold));
    if(totalToken2Sold > 0) PROJECT_TOKEN_2.transfer(msg.sender, MAX_PROJECT_TOKENS_2_TO_DISTRIBUTE.sub(totalToken2Sold));
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

  function setForceClaimable() external onlyOwner {
    forceClaimable = true;
  }

  /********************************************************/
  /****************** INTERNAL FUNCTIONS ******************/
  /********************************************************/

  /**
   * @dev Safe token transfer function, in case rounding error causes contract to not have enough tokens
   */
  function _safeClaimTransfer(IERC20 token, address to, uint256 amount) internal {
    uint256 balance = token.balanceOf(address(this));
    bool transferSuccess = false;

    if (amount > balance) {
      transferSuccess = token.transfer(to, balance);
    } else {
      transferSuccess = token.transfer(to, amount);
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
