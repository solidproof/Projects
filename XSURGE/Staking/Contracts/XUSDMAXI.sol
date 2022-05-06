//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Ownable.sol";
import "./IERC20.sol";
import "./SafeMath.sol";

interface IFlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency, must be XUSD
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}

interface IFlashLender {
    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token) external view returns (uint256);

    /**
     * @dev The fee to be charged for a given loan.
     * @param from The wallet borrowing the currency
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address from, uint256 amount) external view returns (uint256);

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IFlashBorrower receiver,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface IXUSD {
    function burn(uint256 amount) external;
    function resourceCollector() external view returns (address);
    function calculatePrice() external view returns (uint256);
    function mintFee() external view returns (uint256);
}

contract XUSDMAXI is Ownable, IERC20, IFlashLender {

    using SafeMath for uint256;

    // XUSD Token
    address public constant XUSD = 0x324E8E649A6A3dF817F97CdDBED2b746b62553dD;

    // Trackable User Info
    struct UserInfo {
        uint256 balance;
        uint256 unlockBlock;
        uint256 totalStaked;
        uint256 totalWithdrawn;
        bool isFlashFeeExempt;
    }
    // User -> UserInfo
    mapping ( address => UserInfo ) public userInfo;

    // Unstake Early Fee
    uint256 public leaveEarlyFee = 20;
    uint256 public burnAllocation = 30;
    uint256 public resourceAllocation = 35;

    // Timer For Leave Early Fee
    uint256 public leaveEarlyFeeTimer = 144000; // 5 days

    // total supply of XUSD MAXI
    uint256 private _totalSupply;

    // flash loan fee
    uint256 public flashLoanFee = 50;
    // Callback Success
    bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');

    // precision factor
    uint256 private constant precision = 10**18;

    // Reentrancy Guard
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    modifier nonReentrant() {
        require(_status != _ENTERED, "Reentrancy Guard call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // Events
    event PriceChange(uint256 previous, uint256 current, uint256 totalMAXISupply);
    event Deposit(address depositor, uint256 amountXUSD);
    event Withdraw(address withdrawer, uint256 amountXUSD);
    event FeeTaken(uint256 fee);

    constructor(){
        _mint(address(0), 10, 18);      // ensure total supply never reaches 0
        _mint(msg.sender, 10**18, 18 * 10**17);  // send 1...001 XUSD To contract on launch so price starts at 1
        // set reentrancy
        _status = _NOT_ENTERED;
    }

    function name() external pure override returns (string memory) {
        return "XUSD MAXI";
    }
    function symbol() external pure override returns (string memory) {
        return "XUSD MAXI";
    }
    function decimals() external pure override returns (uint8) {
        return 18;
    }
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /** Shows The Value In Stable Coins Of Users' Staked XUSD */
    function balanceOf(address account) public view override returns (uint256) {
        return ReflectionsFromContractBalance(userInfo[account].balance).mul(XUSDPrice()).div(precision);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        if (recipient == msg.sender) {
            withdraw(amount);
        }
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        // sender;
        // if (recipient == msg.sender) {
        //     withdraw(amount);
        // }
        // return true;

        return transfer(recipient, amount);
    }

    function setFlashLoanFee(uint256 fee) external onlyOwner {
        require(
            fee <= 100,
            'Fee Too High'
        );
        flashLoanFee = fee;
    }
    function setLeaveEarlyFee(uint256 newLeaveEarlyFee) external onlyOwner {
        require(
            newLeaveEarlyFee <= 100,
            'Early Fee Too High'
        );
        leaveEarlyFee = newLeaveEarlyFee;
    }
    function setLeaveEarlyFeeTimer(uint256 newLeaveEarlyFeeTimer) external onlyOwner {
        require(
            newLeaveEarlyFeeTimer <= 10**7,
            'Fee Timer Too High'
        );
        leaveEarlyFeeTimer = newLeaveEarlyFeeTimer;
    }

    function setBurnAllocation(uint burnAllocation_) external onlyOwner {
        require(
            burnAllocation_ + resourceAllocation < 100,
            'Invalid Amount'
        );
        burnAllocation = burnAllocation_;
    }

    function setResourceAllocation(uint resourceAllocation_) external onlyOwner {
        require(
            burnAllocation + resourceAllocation_ < 100,
            'Invalid Amount'
        );
        resourceAllocation = resourceAllocation_;
    }

    function setFlashFeeExempt(address user, bool isExempt) external onlyOwner {
        userInfo[user].isFlashFeeExempt = isExempt;
    }

    function withdrawBNB() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s, 'Error On BNB Withdrawal');
    }

    function recoverForeignToken(address token) external onlyOwner {
        require(
            token != XUSD,
            'Cannot Withdraw XUSD Tokens'
        );
        require(
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this))),
            'Error Withdrawing Foreign Token'
        );
    }


    /**
     * @dev The amount of currency available to be lent.
     * @param token The loan currency.
     * @return The amount of `token` that can be borrowed.
     */
    function maxFlashLoan(address token) public view override returns (uint256) {
        return token == XUSD ? IERC20(XUSD).balanceOf(address(this)) : 0;
    }

    /**
     * @dev The fee to be charged for a given loan.
     * @param from The wallet borrowing the currency
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address from, uint256 amount) public view override returns (uint256) {
        return userInfo[from].isFlashFeeExempt ? 0 : ( amount * flashLoanFee ) / 10**5;
    }

    /**
     * @dev Initiate a flash loan, borrowing XUSD
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IFlashBorrower receiver,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant override returns (bool) {
         require(
            amount > 0 &&
            amount <= maxFlashLoan(XUSD),
            "Insufficient Borrow Balance"
        );
        require(
            address(receiver) != address(0),
            'Zero Address'
        );

        // track price change
        uint oldPrice = _calculatePrice();

        // calculate fee for loan
        uint256 fee = flashFee(msg.sender, amount);

        // Amount XUSD Before Loan
        uint256 amountBefore = IERC20(XUSD).balanceOf(address(this));

        // XUSD Price before loan
        uint256 xPriceBefore = XUSDPrice();

        // Send Tokens To Receiver
        require(
            IERC20(XUSD).transfer(
                address(receiver),
                amount
            ),
            'Error on XUSD Transfer'
        );

        // trigger flash loan
        require(
            receiver.onFlashLoan(msg.sender, XUSD, amount, fee, data) == CALLBACK_SUCCESS,
            'CALLBACK_FAILED'
        );

        // require more XUSD was returned
        require(
            IERC20(XUSD).balanceOf(address(this)) >= amountBefore + fee,
            'Flash Loan Not Repaid'
        );

        // take fee if applicable
        if (fee > 0) {
            _takeFee(fee);
        }

        // get price after fee is taken
        uint256 xPriceAfter = XUSDPrice();
        require(
            xPriceAfter >= xPriceBefore,
            'XUSD Price Must Rise'
        );
        // require price rises
        _requirePriceRises(oldPrice);
        return true;
    }

    /** BNB Sent To Contract Will Buy And Stake XUSD
        Standard XUSD Mint Rates Still Apply
     */
    receive() external payable {
        require(msg.value > 0, 'Zero Value');
        _onReceive(msg.sender, msg.value);
    }

    /**
        Transfers in `amount` of XUSD From Sender
        And Locks In Contract, Minting XUSD MAXI Tokens
     */
    function deposit(uint256 amount) external nonReentrant {

        // track price change
        uint oldPrice = _calculatePrice();

        // Track Balance Before Deposit
        uint previousBalance = IERC20(XUSD).balanceOf(address(this));

        // Transfer In XUSD
        uint received = _transferIn(amount);

        // Update Previous If First Mint
        previousBalance = previousBalance == 0 ? IERC20(XUSD).balanceOf(address(this)) : previousBalance;

        // mints correct token amount to sender given data
        _mintTo(msg.sender, received, previousBalance, oldPrice);
    }

    /**
        Redeems `amount` of USD Tokens, As Seen From BalanceOf()
     */
    function withdraw(uint256 amount) public nonReentrant returns (uint256) {

        // track price change
        uint oldPrice = _calculatePrice();

        // XUSD Amount
        uint XUSD_Amount = amount.mul(precision).div(XUSDPrice());

        // XUSD Amount Into Contract Balance Amount
        uint MAXI_Amount = XUSDToContractBalance(XUSD_Amount);

        require(
            userInfo[msg.sender].balance > 0 &&
            userInfo[msg.sender].balance >= MAXI_Amount &&
            balanceOf(msg.sender) >= amount &&
            XUSD_Amount > 0 &&
            MAXI_Amount > 0,
            'Insufficient Funds'
        );

        // burn MAXI Tokens From Sender
        _burn(msg.sender, MAXI_Amount, amount);

        // increment total withdrawn
        userInfo[msg.sender].totalWithdrawn += XUSD_Amount;

        // Take Fee If Withdrawn Before Timer
        uint fee = remainingLockTime(msg.sender) == 0 ? 0 : _takeFee(XUSD_Amount.mul(leaveEarlyFee).div(1000));

        // Send `sendAmount` to recipient, less fees if applicable
        uint256 balLeft = IERC20(XUSD).balanceOf(address(this));
        uint256 toSendRaw = XUSD_Amount.sub(fee).sub(10);
        uint256 sendAmount = toSendRaw < balLeft ? toSendRaw : balLeft;
        require(
            IERC20(XUSD).transfer(msg.sender, sendAmount),
            'Error On Token Transfer'
        );
        // require price rises
        _requirePriceRises(oldPrice);
        emit Withdraw(msg.sender, sendAmount);
        return sendAmount;
    }

    function _takeFee(uint256 fee) internal returns (uint256) {

        // XUSD Resource Allocator
        address resourceCollector = IXUSD(XUSD).resourceCollector();

        // Contribute To XUSD And Reflect The Rest
        uint resourcePortion = ( fee * resourceAllocation ) / 100;
        uint burnPortion     = ( fee * burnAllocation ) / 100;

        if (resourcePortion > 0 && resourceCollector != address(0)) {
            require(
                IERC20(XUSD).transfer(resourceCollector, resourcePortion),
                'Error On Fee Transfer'
            );
        }

        if (burnPortion > 0) {
            IXUSD(XUSD).burn(burnPortion);
        }
        emit FeeTaken(fee);
        return fee;
    }

    function donate() external payable nonReentrant {
        // track price change
        uint oldPrice = _calculatePrice();

        uint received = _buyXUSD(address(this).balance);
        (uint num, uint denom) = getXUSDMintFee();
        _takeFee(( received * ( num * 2 ) ) / denom);

        // require price rises
        _requirePriceRises(oldPrice);
    }

    function _onReceive(address sender, uint value) internal nonReentrant {
        // track price change
        uint oldPrice = _calculatePrice();

        // Track Balance Before Deposit
        uint previousBalance = IERC20(XUSD).balanceOf(address(this));

        // mint XUSD
        uint received = _buyXUSD(value);
        (uint num, uint denom) = getXUSDMintFee();
        uint toTrack = received - _takeFee(( received * num ) / denom);

        // Update Previous If First Mint
        previousBalance = previousBalance == 0 ? IERC20(XUSD).balanceOf(address(this)) : previousBalance;

        // mints correct token amount to sender given data
        _mintTo(sender, toTrack, previousBalance, oldPrice);
    }

    function _mintTo(address sender, uint256 received, uint256 previousBalance, uint256 oldPrice) internal {
        // Number Of Maxi Tokens To Mint
        uint nToMint = (_totalSupply.mul(received).div(previousBalance)).sub(10);
        require(
            nToMint > 0,
            'Zero To Mint'
        );

        // increment total staked
        userInfo[sender].totalStaked += received;

        // mint MAXI Tokens To Sender
        _mint(sender, nToMint, received.mul(XUSDPrice()).div(precision));

        // require price rises
        _requirePriceRises(oldPrice);

        emit Deposit(sender, received);
    }

    function _buyXUSD(uint amount) internal returns (uint256) {
        require(
            amount > 0,
            'Zero Amount'
        );
        uint before = IERC20(XUSD).balanceOf(address(this));
        (bool s,) = payable(XUSD).call{value: amount}("");
        require(s, 'Failure On XUSD Purchase');
        return IERC20(XUSD).balanceOf(address(this)).sub(before);
    }

    function _requirePriceRises(uint256 oldPrice) internal {
        // fetch new price
        uint256 newPrice = _calculatePrice();
        // require price rises
        require(
            newPrice >= oldPrice,
            'Price Must Rise'
        );
        // emit event
        emit PriceChange(oldPrice, newPrice, _totalSupply);
    }


    function _transferIn(uint256 amount) internal returns (uint256) {
        uint before = IERC20(XUSD).balanceOf(address(this));
        require(
            IERC20(XUSD).transferFrom(msg.sender, address(this), amount),
            'Failure On TransferFrom'
        );
        uint received = IERC20(XUSD).balanceOf(address(this)).sub(before);
        require(
            received <= amount && received > 0,
            'Error On Transfer In'
        );
        return received;
    }

    /**
     * Burns `amount` of Contract Balance Token
     */
    function _burn(address from, uint256 amount, uint256 stablesSent) private {
        userInfo[from].balance = userInfo[from].balance.sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(from, address(0), stablesSent);
    }

    /**
     * Mints `amount` of Contract Balance Token
     */
    function _mint(address to, uint256 amount, uint256 stablesWorth) private {
        // allocate
        userInfo[to].balance = userInfo[to].balance.add(amount);
        _totalSupply = _totalSupply.add(amount);
        // update locker info
        userInfo[msg.sender].unlockBlock = block.number + leaveEarlyFeeTimer;
        emit Transfer(address(0), to, stablesWorth);
    }


    /**
        Converts An XUSD Amount Into An XUSD MAXI Amount
     */
    function XUSDToContractBalance(uint256 amount) public view returns (uint256) {
        return amount.mul(precision).div(_calculatePrice());
    }

    /**
        Converts An XUSD MAXI Amount Into An XUSD Amount
     */
    function ReflectionsFromContractBalance(uint256 amount) public view returns (uint256) {
        return amount.mul(_calculatePrice()).div(precision);
    }

    /** Conversion Ratio For MAXI -> XUSD */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }
    /**
        Price OF XUSD
     */
    function XUSDPrice() public view returns (uint256) {
        return IXUSD(XUSD).calculatePrice();
    }
    /**
        Lock Time Remaining For Stakers
     */
    function remainingLockTime(address user) public view returns (uint256) {
        return userInfo[user].unlockBlock < block.number ? 0 : userInfo[user].unlockBlock - block.number;
    }

    /** Conversion Ratio For MAXI -> XUSD */
    function _calculatePrice() internal view returns (uint256) {
        uint256 backingValue = IERC20(XUSD).balanceOf(address(this));
        return (backingValue.mul(precision)).div(_totalSupply);
    }

    /**
        Fee Associated With Minting XUSD
     */
    function getXUSDMintFee() public view returns (uint256,uint256) {
        uint denom = 10**5;
        uint mintFee = IXUSD(XUSD).mintFee();
        return (denom - mintFee, denom);
    }

    /** function has no use in contract */
    function allowance(address holder, address spender) external pure override returns (uint256) {
        holder;
        spender;
        return 0;
    }
    /** function has no use in contract */
    function approve(address spender, uint256 amount) public override returns (bool) {
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}