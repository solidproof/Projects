//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Address.sol";
import "./Ownable.sol";
import "./IERC20.sol";

interface IFlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param tokenToBorrow The loan currency, must be an approved stable coin.
     * @param tokenToRepay The repayment currency, must be an approved stable coin.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address tokenToBorrow,
        address tokenToRepay,
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
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @return The amount of `token` to be charged for the loan, on top of the returned principal.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256);

    /**
     * @dev Initiate a flash loan.
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param tokenToBorrow The loan currency, must be an approved stable coin
     * @param tokenToRepay The Repayment currency, must be an approved stable coin
     * @param amount The amount of tokens lent.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     */
    function flashLoan(
        IFlashBorrower receiver,
        address tokenToBorrow,
        address tokenToRepay,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface IXUSD {
    function isUnderlyingAsset(address stable) external view returns (bool);
    function requestFlashLoan(
        address stable,
        address stableToRepay,
        uint256 amount
    ) external returns (bool);
    function resourceCollector() external view returns (address);
}

contract FlashLoanProvider is IFlashLender, Ownable {

    using Address for address;

    // Data Structure
    struct Data {
        IFlashBorrower receiver;
        address stableToBorrow;
        address stableToRepay;
        uint256 amount;
        bytes _data;
        address sender;
        uint256 fee;
    }

    // Callback Success
    bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');

    // last saved data
    Data private data;

    // XUSD Contract
    address public XUSD;

    // Address => Fee Rank
    mapping ( address => uint8 ) public feeRank;

    uint8 public bottomRank                = 25;
    uint8 public constant middleRank       = 10;
    uint8 public constant topRank          = 0;
    uint256 public maxLoanRate             = 1000 * 10**18;
    uint256 public constant feeDenominator = 10**5;

    constructor(address XUSD_) {
        require(XUSD_ != address(0), 'Zero Address');
        XUSD = XUSD_;
    }

    function setXUSD(address XUSD_) external onlyOwner {
        require(XUSD_ != address(0), 'Zero Address');
        XUSD = XUSD_;
    }

    function setFeeRank(address user, uint8 rank) external onlyOwner {
        require(rank <= uint8(2), 'Invalid Rank');
        feeRank[user] = rank;
    }

    function withdraw(address token) external onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function setMaxLoanRate(uint newMaxRate) external onlyOwner {
        require(newMaxRate >= 10**18, 'Max Rate Too Low');
        maxLoanRate = newMaxRate;
    }

    function setBottomRate(uint8 newBottomRate) external onlyOwner {
        require(newBottomRate <= 100 && newBottomRate >= middleRank, 'Bottom Rate Too High Or Lower Than Middle Rank');
        bottomRank = newBottomRate;
    }

    /**
        Max Flash Loan Capable
     */
    function maxFlashLoan(address token) public view override returns (uint256) {
        return IXUSD(XUSD).isUnderlyingAsset(token) ? IERC20(token).balanceOf(XUSD) : 0;
    }

    function getFeeForUser(address user) public view returns (uint256) {
        return feeRank[user] >= 2 ? uint256(topRank) : feeRank[user] == 1 ? uint256(middleRank) : uint256(bottomRank);
    }

    /**
        Flash Fee Taken From Transaction, capped at Maximum Rate
     */
    function flashFee(address borrower, uint256 amount) public view override returns (uint256) {
        uint256 fee = ( getFeeForUser(borrower) * amount ) / feeDenominator;
        return fee >= maxLoanRate ? maxLoanRate : fee;
    }

    /**
        Allows receiver to borrow amount stable from XUSD
        As long as it repays amount stable + fee within the same transaction
        When flashloan is initiated, all token functionality is halted
     */
    function flashLoan(
        IFlashBorrower receiver,
        address tokenToBorrow,
        address tokenToRepay,
        uint256 amount,
        bytes calldata data_
    ) external override returns (bool) {
        require(
            amount > 0 &&
            amount <= maxFlashLoan(tokenToBorrow),         
            "Insufficient Borrow Balance"
        );
        require(
            IXUSD(XUSD).isUnderlyingAsset(tokenToRepay),
            'Repayment Token Not Approved'
        );
        require(
            address(receiver) != address(0) &&
            tokenToBorrow != address(0) &&
            tokenToRepay != address(0),
            'Zero Address'
        );
        require(
            address(receiver).isContract(),
            "Borrower must be a deployed contract"
        );

        // calculate fee for loan
        uint256 fee = flashFee(msg.sender, amount);

        data = Data({
            receiver: receiver,
            stableToBorrow: tokenToBorrow,
            stableToRepay: tokenToRepay,
            amount: amount,
            _data: data_,
            sender: msg.sender,
            fee: fee
        });

        // get tokens from XUSD
        require(
            IXUSD(XUSD).requestFlashLoan(tokenToBorrow, tokenToRepay, amount),
            'Flash Loan Request Failed'
        );
        
        delete data;
        return true;
    }
    
    function fulfillFlashLoanRequest() external returns (bool) {
        require(msg.sender == XUSD, 'Only XUSD');
        require(data.amount > 0 && data.stableToBorrow != address(0) && data.stableToRepay != address(0), 'Data Not Set');

        // transfer amount to sender
        IERC20(data.stableToBorrow).transfer(address(data.receiver), data.amount);

        // trigger functionality on external contract
        require(
            data.receiver.onFlashLoan(data.sender, data.stableToBorrow, data.stableToRepay, data.amount, data.fee, data._data) == CALLBACK_SUCCESS,
            'CALLBACK_FAILED'
        );
        
        // require more stable has been acquired
        require(
            IERC20(data.stableToRepay).balanceOf(address(this)) >= ( data.amount + data.fee ), 
            "Flash loan not paid back"
        );

        // send tokens back to XUSD
        require(
            IERC20(data.stableToRepay).transfer(
                XUSD,
                data.amount + data.fee/2
            ),
            'Failure on XUSD Repayment'
        );

        // send tokens to XUSD Resource Collector
        uint256 remainderToRepay = IERC20(data.stableToRepay).balanceOf(address(this));
        address collector = IXUSD(XUSD).resourceCollector();
        if (remainderToRepay > 0 && collector != address(0)) {
            require(
                IERC20(data.stableToRepay).transfer(
                    collector,
                    remainderToRepay
                ),
                'Failure On Collector Repayment'
            );
        }
        return true;
    }

}