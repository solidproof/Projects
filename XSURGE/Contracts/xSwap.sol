//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IXSurge.sol";
import "../lib/IERC20.sol";
import "./IStableSwapRouter.sol";

/**
    xSwap Protocol Will Call SurgeV2 Tokens' exchange() function
    And Take Necessary Fees To Ensure Profitability For XSurge V2 Tokens
 */
contract xSwapRouter is IStableSwapRouter {

    // xToken Data
    struct xToken {
        bool isApproved;
        uint256 index;
        address resourceAllocator;
        uint256 totalFeesGenerated;
    }
    address[] public allXTokens;

    // XSurge Token -> Data
    mapping (address => xToken) public xTokens;

    // Sender -> Fee Rank
    mapping ( address => uint256 ) public feeRank;

    // Tokens Banned From Swap
    mapping (address => bool) public tokenDeniedFromSwap;

    // rates
    uint256 public baseRate   = 50;
    uint256 public middleRate = 25;
    uint256 public bottomRate = 0;
    uint256 public maximumFee = 1000;
    uint256 public constant maximumRate = 200;
    uint256 public constant feeDenominator = 10**5;

    // operator
    address public operator;
    modifier onlyOperator() {
        require(msg.sender == operator, 'Only Operator');
        _;
    }

    // Events
    event ChangedOperator(address newOperator);
    event SetRates(uint256 baseRate,uint256 middleRate,uint256 bottomRate,uint256 maximumFee);
    event AddXToken(address xToken, address resourceCollector);
    event RemoveXToken(address xToken);
    event SwapTokenPermissionChanged(address token, bool canSwap);
    event Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event SetFeeRank(address Contract, uint256 newRank);

    constructor() {
        operator = msg.sender;
    }

    function changeOperator( address newOperator ) external onlyOperator {
        operator = newOperator;
        emit ChangedOperator(newOperator);
    }

    function setRates(
        uint256 baseRate_,
        uint256 middleRate_,
        uint256 bottomRate_,
        uint256 maximumFee_
    ) external onlyOperator {
        // require rates are in bounds
        require(
            baseRate_ <= maximumRate &&
            middleRate_ <= maximumRate &&
            bottomRate_ <= maximumRate,
            "Rates Capped At 0.2%"
        );
        
        // set state
        baseRate = baseRate_;
        middleRate = middleRate_;
        bottomRate = bottomRate_;
        maximumFee = maximumFee_;
        emit SetRates(baseRate,middleRate,bottomRate,maximumFee);
    }

    function addXToken(
            address xtoken, 
            address resourceCollector
    ) external onlyOperator {
        // require addresses are valid
        require(
            xtoken != address(0) &&
            resourceCollector != address(0),
            "Zero Provided"
        );
        require(
            !xToken[xtoken].isApproved,
            'Token Already Approved'
        );

        // set state
        xToken[xtoken].isApproved = true;
        xToken[xtoken].resourceCollector = resourceCollector;
        xToken[xtoken].index = allXTokens.length;

        allXTokens.push(xtoken);
        emit AddXToken(xtoken, resourceCollector);
    }

    function setFeeRank(address Contract, uint256 newRank) external onlyOperator {
        require(newRank <= 2, "Invalid Rank");

        feeRank[Contract] = newRank;
        emit SetFeeRank(Contract, newRank);
    }

    function removeXToken(address xtoken) external onlyOperator {
        require(
            xToken[xtoken].isApproved,
            'Token Not Approved'
        );

        xTokens[
            allXTokens[allXTokens.length - 1]
        ].index = xTokens[xtoken].index;

        allXTokens[
            xTokens[xtoken].index
        ] = allXTokens[allXTokens.length - 1];
        allXTokens.pop();

        delete xToken[xtoken];
        emit RemoveXToken(xtoken);
    }

    function restrictTokenAccess(address token) external onlyOperator {
        tokenDeniedFromSwap[token] = true;
        emit SwapTokenPermissionChanged(token, false);
    }

    function unRestrictTokenAccess(address token) external onlyOperator {
        delete tokenDeniedFromSwap[token];
        emit SwapTokenPermissionChanged(token, true);
    }

    function exchange(address tokenIn, address tokenOut, uint256 amountTokenIn) external {
        _exchange(xTokens[0], tokenIn, tokenOut, amountTokenIn, msg.sender);
    }

    function exchange(address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) external {
        _exchange(xTokens[0], tokenIn, tokenOut, amountTokenIn, destination);
    }

    function exchange(address source, address tokenIn, address tokenOut, uint256 amountTokenIn) external {
        _exchange(source, tokenIn, tokenOut, amountTokenIn, msg.sender);
    }

    function exchange(address source, address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) external {
        _exchange(source, tokenIn, tokenOut, amountTokenIn, destination);
    }

    function expectedOut(address sender, uint256 amount) external view override returns (uint256) {
        return amount - _getFee(sender, amount);
    }

    function getFeeOut(uint256 amount) public view override returns (uint256) {
        return _getFee(address(this), amount);
    }

    function _exchange(address source, address tokenIn, address tokenOut, uint256 amountTokenIn, address destination) internal {

        require(
            xToken[source].isApproved,
            "Not Approved Source"
        );

        require(
            !tokenDeniedFromSwap[tokenIn] &&
            !tokenDeniedFromSwap[tokenOut],
            "Restricted Asset"
        );

        require(
            IXSurge(source).isUnderlyingAsset(tokenIn) &&
            IXSurge(source).isUnderlyingAsset(tokenOut),
            "Not Approved Assets"
        );

        require(
            IERC20(tokenOut).balanceOf(source) >= amountTokenIn,
            "Invalid In Amount"
        );

        // transfer in tokens
        uint256 before = IERC20(tokenIn).balanceOf(address(this));
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountTokenIn),
            "Failed TransferFrom"
        );
        uint256 received = IERC20(tokenIn).balanceOf(address(this)) - before;

        // fetch fee for received amount
        uint256 fee = _getFee(msg.sender, received);
        // calculate amount to send
        uint256 sendAmount = received - fee;

        // Sanity Check
        require(
            sendAmount > 0 && sendAmount <= amountTokenIn,
            "Failed To Receive"
        );

        // distribute the fee
        if (fee > 0) {
            uint rFee = fee / 2;
            uint bFee = fee - hFee;
            IERC20(tokenIn).transfer(xToken[source].resourceAllocator, rFee);
            IERC20(tokenIn).transfer(source, bFee);
            xToken[source].totalFeesGenerated += fee;
        }
        
        // Approve Source For Amount
        IERC20(tokenIn).approve(source, sendAmount);

        // Transfers In tokenIn in exchange for tokenOut 1:1
        IXSurge(source).exchange(tokenIn, tokenOut, sendAmount, destination);
        emit Swap(tokenIn, tokenOut, amountTokenIn, sendAmount);
    }

    function _getFee(address sender, uint256 amount) internal returns (uint256) {

        uint256 fee = 0;

        if (feeRank[sender] >= 2) {
            fee = ( ( amount * bottomRate) / feeDenominator );
        } else if (feeRank[sender] == 1) {
            fee = ( ( amount * middleRate) / feeDenominator );
        } else {
            fee = ( ( amount * baseRate) / feeDenominator );
        }

        return fee > maximumFee ? maximumFee : fee;
    }
}