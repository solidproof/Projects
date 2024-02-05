//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./IUniswapV2Router02.sol";
import "./ReentrantGuard.sol";

contract XUSDEARN is Ownable, ReentrancyGuard, IERC20 {

    using SafeMath for uint256;

    // lock time in blocks
    uint256 public lockTime;

    // fee for leaving staking early
    uint256 public leaveEarlyFee;

    // recipient of fee
    address public feeRecipient;

    // XUSD Token
    address public constant token = 0x324E8E649A6A3dF817F97CdDBED2b746b62553dD;

    // User Info
    struct UserInfo {
        uint256 amount;
        uint256 unlockBlock;
        uint256 totalExcluded;
        address rewardToken;
        address rewardTokenDEX;
    }
    // Address => UserInfo
    mapping ( address => UserInfo ) public userInfo;

    // Tracks Dividends
    uint256 private totalShares;
    uint256 private dividendsPerShare;
    uint256 public totalRewards;
    uint256 private constant precision = 10**18;

    // Default Values
    address private constant PCS  = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private constant WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // Events
    event SetLockTime(uint LockTime);
    event SetEarlyFee(uint earlyFee);
    event SetFeeRecipient(address FeeRecipient);

    constructor(address feeRecipient_, uint256 lockTime_, uint256 leaveEarlyFee_){
        require(
            feeRecipient_ != address(0),
            'Zero Address'
        );
        require(
            lockTime_ <= 10**7,
            'Lock Time Too Long'
        );
        require(
            leaveEarlyFee_ <= 10,
            'Fee Too High'
        );
        feeRecipient = feeRecipient_;
        lockTime = lockTime_;
        leaveEarlyFee = leaveEarlyFee_;
        emit Transfer(address(0), msg.sender, 0);
    }

    /** Returns the total number of tokens in existence */
    function totalSupply() external view override returns (uint256) {
        return totalShares;
    }

    /** Returns the number of tokens owned by `account` */
    function balanceOf(address account) public view override returns (uint256) {
        return userInfo[account].amount;
    }

    /** Returns the number of tokens `spender` can transfer from `holder` */
    function allowance(address holder, address spender) external pure override returns (uint256) {
        holder; spender;
        return 0;
    }

    /** Token Name */
    function name() public pure override returns (string memory) {
        return "XUSD EARN";
    }

    /** Token Ticker Symbol */
    function symbol() public pure override returns (string memory) {
        return "XUSDE";
    }

    /** Tokens decimals */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /** Approves `spender` to transfer `amount` tokens from caller */
    function approve(address spender, uint256 amount) public override returns (bool) {
        amount;
        emit Approval(msg.sender, spender, 0);
        return true;
    }

    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external override nonReentrant returns (bool) {
        amount;
        _claimReward(msg.sender);
        emit Transfer(msg.sender, recipient, 0);
        return true;
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external override nonReentrant returns (bool) {
        sender; amount;
        _claimReward(msg.sender);
        emit Transfer(msg.sender, recipient, 0);
        return true;
    }

    /** Sets The Lock Time For The Pool, If Withdrawn Before A LeaveEarlyFee Is Applied */
    function setLockTime(uint256 newLockTime) external onlyOwner {
        require(
            newLockTime <= 10**7,
            'Lock Time Too Long'
        );
        lockTime = newLockTime;
        emit SetLockTime(newLockTime);
    }

    /** Updates The Leave Early Fee For Unstaking Before LockTime Expires */
    function setLeaveEarlyFee(uint256 newEarlyFee) external onlyOwner {
        require(
            newEarlyFee <= 10,
            'Fee Too High'
        );
        leaveEarlyFee = newEarlyFee;
        emit SetEarlyFee(newEarlyFee);
    }

    /** Sets The Recipient Of The Fees Taken From Early Withdrawers */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(
            newFeeRecipient != address(0),
            'Zero Address'
        );
        feeRecipient = newFeeRecipient;
        emit SetFeeRecipient(newFeeRecipient);
    }

    /** Withdraws Incorrectly Sent Tokens To The Sender */
    function withdraw(IERC20 token_, address to_) external onlyOwner {
        require(
            token != address(token_),
            'Cannot Withdraw Staked Token'
        );
        require(
            token_.transfer(
                to_,
                token_.balanceOf(address(this))
            ),
            'Failure On Token Withdraw'
        );
    }

    /** Donates BNB To The Pool To be Given As Rewards */
    function donate() external payable nonReentrant {
        require(msg.value > 0, 'Zero Value');
        _donate(msg.value);
    }

    /** Sets The Reward Token And DEX For A Holder */
    function setRewardToken(IERC20 token_, IUniswapV2Router02 DEX_) external nonReentrant {
        require(
            userInfo[msg.sender].amount > 0,
            'Zero Amount'
        );
        require(
            address(token_) != address(0) &&
            address(DEX_) != address(0),
            'Zero Address'
        );
        userInfo[msg.sender].rewardToken = address(token_);
        userInfo[msg.sender].rewardTokenDEX = address(DEX_);
    }

    /** Claims Pending Rewards In Specified Token For Sender */
    function claimRewards() external nonReentrant {
        _claimReward(msg.sender);
    }

    /** Withdraws `amount` of XUSD For Sender */
    function withdraw(uint256 amount) external nonReentrant {
        require(
            amount <= userInfo[msg.sender].amount,
            'Insufficient Amount'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender);
        }

        totalShares = totalShares.sub(amount);
        userInfo[msg.sender].amount = userInfo[msg.sender].amount.sub(amount);
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        uint fee = timeUntilUnlock(msg.sender) == 0 ? 0 : ( amount * leaveEarlyFee ) / 100;
        if (fee > 0) {
            require(
                IERC20(token).transfer(feeRecipient, fee),
                'Failure On Token Transfer'
            );
        }

        uint sendAmount = amount - fee;
        require(
            IERC20(token).transfer(msg.sender, sendAmount),
            'Failure On Token Transfer To Sender'
        );
        emit Transfer(msg.sender, address(0), amount);
    }

    /**
        Stakes `amount` of XUSD into pool for sender
        Pool must have allowance of at least `amount` of XUSD Before stake() is called
    */
    function stake(uint256 amount) external nonReentrant {
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender);
        }

        // transfer in tokens
        uint received = _transferIn(token, amount);

        // update data
        totalShares += received;
        userInfo[msg.sender].amount += received;
        userInfo[msg.sender].unlockBlock = block.number + lockTime;
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);
        emit Transfer(address(0), msg.sender, received);
    }

    /** Internal Function To Claim `user`s Rewards */
    function _claimReward(address user) internal {

        // exit if zero value locked
        if (userInfo[user].amount == 0) {
            return;
        }

        // fetch pending rewards
        uint256 amount = pendingRewards(user);

        // exit if zero rewards
        if (amount == 0) {
            return;
        }

        // update total excluded
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        // transfer reward to user
        _giveRewardTo(user, amount);
    }

    /** Instantiates User Reward DEX And Buys Reward Token With Pending BNB */
    function _giveRewardTo(address user, uint256 amount) internal {

        // fetch reward information
        address rToken = getRewardToken(user);
        address dex = getRewardTokenDEX(user);

        if (rToken == WETH) {
            payable(user).transfer(amount);
        } else {
            // instantiate DEX
            IUniswapV2Router02 router = IUniswapV2Router02(dex);

            // create swap path
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = rToken;

            // make swap
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(0, path, user, block.timestamp + 300);
            delete path;
        }
    }

    /** Transfers In `amount` of `_token` from msg.sender */
    function _transferIn(address _token, uint256 amount) internal returns (uint256) {
        uint before = IERC20(_token).balanceOf(address(this));
        bool s = IERC20(_token).transferFrom(msg.sender, address(this), amount);
        uint received = IERC20(_token).balanceOf(address(this)) - before;
        require(
            s && received > 0 && received <= amount,
            'Error On Transfer From'
        );
        return received;
    }

    /** Registers Increase In Global Rewards */
    function _donate(uint256 amount) internal {
        // Add To Rewards Tracking
        dividendsPerShare = dividendsPerShare.add(precision.mul(amount).div(totalShares));
        totalRewards += amount;
    }

    /** Time in blocks until User May withdraw tokens tax free */
    function timeUntilUnlock(address user) public view returns (uint256) {
        return userInfo[user].unlockBlock < block.number ? 0 : userInfo[user].unlockBlock - block.number;
    }

    /** Pending Rewards In BNB For `shareholder` */
    function pendingRewards(address shareholder) public view returns (uint256) {
        if(userInfo[shareholder].amount == 0){ return 0; }

        uint256 shareholderTotalDividends = getCumulativeDividends(userInfo[shareholder].amount);
        uint256 shareholderTotalExcluded = userInfo[shareholder].totalExcluded;

        if(shareholderTotalDividends <= shareholderTotalExcluded){ return 0; }

        return shareholderTotalDividends.sub(shareholderTotalExcluded);
    }

    /** Returns The Reward Token For `user` */
    function getRewardToken(address user) public view returns (address) {
        return userInfo[user].rewardToken == address(0) ? token : userInfo[user].rewardToken;
    }

    /** Returns The DEX To Buy The Reward Token For `user` */
    function getRewardTokenDEX(address user) public view returns (address) {
        return userInfo[user].rewardTokenDEX == address(0) ? PCS : userInfo[user].rewardTokenDEX;
    }

    /** Returns The Total Reward Variable For A User, This Is Subtracted From Their totalExcluded Value */
    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return share.mul(dividendsPerShare).div(precision);
    }

    /** BNB Sent To Contract Is Registered As A Donation */
    receive() external payable {
        require(msg.value > 0, 'Zero Value');
        _donate(msg.value);
    }
}