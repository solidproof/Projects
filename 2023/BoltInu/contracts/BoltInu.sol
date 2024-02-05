// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "./Dividend/DividendTracker.sol";

interface IRouter {
    function WETH() external view returns (address);
    function factory() external view returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

interface IFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract BoltInu is ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address payable;

    address public constant zeroAddr = address(0);

    IRouter public immutable router;
    address public swapPair;
    IERC20 public usdt;

    bool private swapping;

    address public marketing;

    uint256 private supply = 420 * 1e6 * 1e9 * 1e9;

    uint256 public fee = 10;
    uint256 private startBlock;
    bool private starting;
    uint256 private maxBuy = supply;

    uint256 private constant reward = 3;
    uint256 private transferFeeAt = supply * 5 / 10000; // 0.05%

    mapping(address => bool) public isExcludedFromFee;

    DividendTracker public dividendTracker;
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );
    uint256 public gasForProcessing = 300000;
    uint256 private miniumForDividend = supply / 1000; // 0.1%

    constructor(IRouter router_, IERC20 usdt_, address marketing_) ERC20("Bolt Inu", "$Bolt") {
        router = router_;
        swapPair = IFactory(router.factory()).createPair(address(this), router.WETH());
        marketing = marketing_;
        usdt = usdt_;

        dividendTracker = new DividendTracker(address(usdt), miniumForDividend);

        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(msg.sender);
        dividendTracker.excludeFromDividends(address(router));
        dividendTracker.excludeFromDividends(swapPair);

        excludeFromFee(marketing, true);
        excludeFromFee(owner(), true);
        excludeFromFee(address(this), true);

        _approve(address(this), address(router), ~uint256(0));

        _mint(owner(), supply);
    }

    receive() external payable {}

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns (uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function withdrawableDividendOf(address account) public view returns (uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function excludeFromDividends(address account) external onlyOwner {
        dividendTracker.excludeFromDividends(account);
    }

    function getAccountDividendsInfo(address account)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(uint256 index)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return dividendTracker.getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(
            gas
        );
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function claim() external {
        dividendTracker.processAccount(payable(msg.sender), false);
    }

    function getLastProcessedIndex() external view returns (uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns (uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function excludeFromFee(address account, bool isExcluded) public onlyOwner {
        isExcludedFromFee[account] = isExcluded;
    }

    function _firstBlocksProcess(address to) private {
        if (startBlock == 0 && to == swapPair) {
            starting = true;
            fee = 15;
            startBlock = block.number;
            maxBuy = supply / 100;
        } else if (starting == true && block.number > (startBlock + 2)) {
            fee = 10;
            starting = false;
            maxBuy = supply;
        }
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != zeroAddr, "ERC20: transfer from the zero address");
        require(to != zeroAddr, "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        _firstBlocksProcess(to);

        uint256 feeInContract = balanceOf(address(this));
        bool canSwap = feeInContract >= transferFeeAt;
        if (
            canSwap &&
            from != swapPair &&
            !swapping &&
            !isExcludedFromFee[from] &&
            !isExcludedFromFee[to]
        ) {
            swapping = true;
            _swapAndTransferFee(feeInContract);
            swapping = false;
        }

        bool takeFee = !swapping;

        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 feeAmount = 0;
            if(from == swapPair) {
                require(amount <= maxBuy, "can not buy");
                feeAmount = amount.mul(fee).div(100);
            } else if(to == swapPair) {
                feeAmount = amount.mul(fee).div(100);
            }

            if (feeAmount > 0) {
                super._transfer(from, address(this), feeAmount);
                amount = amount.sub(feeAmount);
            }
        }

        super._transfer(from, to, amount);

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

        if (!swapping) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }

    function _swapAndTransferFee(uint256 feeAmount) private {
        _swapForETH(feeAmount);
        uint256 ethAmount = address(this).balance;

        uint256 rewardAmount = ethAmount.mul(reward).div(fee);

        payable(marketing).sendValue(ethAmount.sub(rewardAmount));

        _swapForToken(rewardAmount);
        uint256 usdtAmount = usdt.balanceOf(address(this));
        usdt.transfer(address(dividendTracker), usdtAmount);
        dividendTracker.distributeRewardDividends(usdtAmount);
    }

    function _swapForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp);
    }

    function _swapForToken(uint256 ethAmount) private {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(usdt);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
            0,
            path,
            address(this),
            block.timestamp);
    }
}