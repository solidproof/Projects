//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/Ownable.sol";
import "./IERC3156FlashBorrower.sol";
import "./IERC3156FlashLender.sol";

interface IXUSD {
    function isUnderlyingAsset(address stable) external view returns (bool);
    function flashLoan(
        address stable,
        uint256 amount
    ) external returns (bool);
}

contract FlashLoanProvider is IERC3156FlashLender, Ownable {

    using SafeMath for uint256;
    using Address for address;

    // Data Structure
    struct Data {
        IERC3156FlashBorrower receiver;
        address stable;
        uint256 amount;
        bytes memory _data;
        address sender;
        uint256 fee;
    }

    // Callback Success
    bytes32 public constant CALLBACK_SUCCESS = keccak256('ERC3156FlashBorrower.onFlashLoan');

    // last saved data
    Data data;

    // XUSD Contract
    address public immutable XUSD;

    // Address => Fee Rank
    mapping ( address => uint8 ) public feeRank;

    uint8 public bottomRank = 20;
    uint8 public middleRank = 10;
    uint8 public topRank    = 0;
    uint public maxLoanRate = 1000 * 10**18;
    uint public feeDenominator = 10**5;

    constructor(address XUSD_) {
        XUSD = XUSD_;
    }

    function setXUSD(address XUSD_) external onlyOwner {
        require(
            XUSD == address(0) &&
            XUSD_ != address(0),
            'Already Paired'
        );
        XUSD = XUSD_;
    }

    function setFeeRank(address user, uint8 rank) external onlyOwner {
        require(rank <= uint8(2));
        feeRank[user] = rank;
    }

    /**
        Max Flash Loan Capable
     */
    function maxFlashLoan(address token) public view returns (uint256) {
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
        IERC3156FlashBorrower receiver,
        address stable,
        uint256 amount,
        bytes calldata data_
    ) external override returns (bool) {
        require(
            amount > 0 &&
            amount <= maxFlashLoan(stable),
            "Insufficient Token Balance"
        );
        require(
            address(receiver).isContract(),
            "Borrower must be a deployed contract"
        );

        // calculate fee for loan
        uint256 fee = flashFee(msg.sender, amount);

        data = Data({
            receiver: receiver,
            stable: stable,
            amount: amount,
            _data: data_,
            sender: msg.sender,
            fee: fee;
        });

        // get tokens from XUSD
        require(
            IXUSD(XUSD).requestFlashLoan(stable, amount),
            'Flash Loan Request Failed'
        );

        delete data;
        return true;
    }

    function fulfillFlashLoanRequest() external returns (bool) {
        require(msg.sender == XUSD, 'Only XUSD');
        require(data.amount > 0, 'Data Not Set');

        // transfer amount to sender
        IERC20(data.stable).transfer(address(data.receiver), data.amount);

        // trigger functionality on external contract
        require(
            receiver.onFlashLoan(data.sender, data.stable, data.amount, data.fee, data._data) == CALLBACK_SUCCESS,
            'CALLBACK_FAILED'
        );

        // require more stable has been acquired
        require(
            IERC20(data.stable).balanceOf(address(this)) >= ( data.amount + data.fee ),
            "Flash loan not paid back"
        );

        // send tokens back to XUSD
        require(
            IERC20(data.stable).transfer(
                XUSD,
                data.amount + data.fee/2
            ),
            'Failure on XUSD Repayment'
        );

        // send tokens to XUSD Resource Collector
        if (IERC20(data.stable).balanceOf(address(this)) > 0) {
            require(
                IERC20(data.stable).transfer(
                    IXUSD(XUSD).resourceCollector(),
                    IERC20(data.stable).balanceOf(address(this))
                ),
                'Failure On Collector Repayment'
            );
        }
        return true;
    }

}