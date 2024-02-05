// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IResource.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";

contract UnicowTreasury is
    Ownable
{
    using SafeERC20 for IERC20;
    using Address for address;

    address public nftManager;
    address public resource;
    address public masterchef;

    bool private liquifyEnabled = false;
    bool private isSwapping = false;

    address public weth;

    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Pair public uniswapV2Pair;

    uint256 public swapTokensToLiquidityThreshold;

    uint256 private constant MAX_UINT256 =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    address public feeAddress;

    modifier onlyNFTOrChef() {
        address sender = _msgSender();
        require(
            sender == address(nftManager) || sender == address(masterchef),
            "Treasury: Not NFTManager or Masterchef"
        );
        _;
    }

    receive() external payable {
        payable(feeAddress).transfer(msg.value);
    }

    constructor(
        address _resource,
        address _nftManager,
        address _chef,
        uint256 _swapTokensToLiquidityThreshold,
        address _feeAddress
    ) {
        require(_resource.isContract(), "Treasury: resource is contract");
        require(_nftManager.isContract(), "Treasury: nftManager is contract");
        require(_chef.isContract(), "Treasury: masterchef is contract");

        resource = _resource;
        nftManager = _nftManager;
        masterchef = _chef;
        feeAddress = _feeAddress;

        //uniswap : 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        //baseswap: 0x327Df1E6de05895d2ab08513aaDD9313Fe505d86
        uniswapV2Router = IUniswapV2Router02(0x327Df1E6de05895d2ab08513aaDD9313Fe505d86);
        weth = uniswapV2Router.WETH();
        uniswapV2Pair = createPairWith(resource, weth);

        updateSwapTokensToLiquidityThreshold(_swapTokensToLiquidityThreshold);

        shouldLiquify(true);
    }

    function swapTokenForETH(address account, uint256 amount)
        external
        onlyNFTOrChef
    {
        if (uniswapV2Pair.totalSupply() > 0 && !isSwapping) {
            isSwapping = true;
            IResource(resource).mintByTreasury(address(this), amount);
            address[] memory path = new address[](2);
            path[0] = resource;
            path[1] = weth;
            uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                amount,
                0, // accept any amount of ETH
                path,
                account,
                block.timestamp
            );
            isSwapping = false;
        }
    }

    function rewardByNFTOrChef(address account, uint256 amount)
        external
        onlyNFTOrChef
    {
        IResource(resource).mintByTreasury(account, amount);
    }

    function burnByNFTOrChef(address account, uint256 amount)
        external
        onlyNFTOrChef
    {
        IResource(resource).burnByTreasury(account, amount);
    }

    function excludeFromFee(address account, bool status) external onlyOwner {
        require(account != address(0), "Treasury: zero address!");
        IResource(resource).excludeFromFee(account, status);
    }

    function setSellFee(uint256 _fee) external onlyOwner() {
        require(_fee >= 0 && _fee <= 25, "Treasury: 0 <= fee <= 25");
        IResource(resource).setSellFee(_fee);
    }

    function addLiquidity()
        external
        onlyNFTOrChef
    {
        uint256 leftSideBalance = IERC20(resource).balanceOf(address(this));
        bool shouldSwap = leftSideBalance >= swapTokensToLiquidityThreshold;
        if (
            shouldSwap &&
            liquifyEnabled &&
            uniswapV2Pair.totalSupply() > 0 &&
            !isSwapping
        ) {
            // This prevents inside calls from triggering this function again (infinite loop)
            // It's ok for this function to be reentrant since it's protected by this check
            isSwapping = true;

            // To prevent bigger sell impact we only sell in batches with the threshold as a limit
            uint256 totalLP = swapAndLiquify(swapTokensToLiquidityThreshold);

            sendLPTokensTo(feeAddress, totalLP);

            // Keep it healthy
            uniswapV2Pair.sync();

            // This prevents inside calls from triggering this function again (infinite loop)
            isSwapping = false;
        }
    }

    function swapAndLiquify(uint256 tokens) private returns (uint256) {
        uint256 half = tokens / 2;
        uint256 initialRightBalance = IERC20(weth).balanceOf(address(this));

        swapLeftSideForRightSide(half);

        uint256 newRightBalance = IERC20(weth).balanceOf(address(this)) -
            initialRightBalance;

        addLiquidityToken(half, newRightBalance);

        // Return the number of LP tokens this contract have
        return uniswapV2Pair.balanceOf(address(this));
    }

    function sendLPTokensTo(address to, uint256 tokens) private {
        uniswapV2Pair.transfer(to, tokens);
    }

    function createPairWith(address _resource, address _weth) private returns (IUniswapV2Pair) {
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2Router.factory());
        address _pair;
        address _currentPair = factory.getPair(_resource, _weth);
        if (_currentPair != address(0)) {
            _pair = _currentPair;
        } else {
            _pair = factory.createPair(_resource, _weth);
        }
        return IUniswapV2Pair(_pair);
    }

    function swapLeftSideForRightSide(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(resource);
        path[1] = address(weth);

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidityToken(uint256 leftAmount, uint256 rightAmount)
        private
    {
        uniswapV2Router.addLiquidity(
            address(resource),
            address(weth),
            leftAmount,
            rightAmount,
            0, // Slippage is unavoidable
            0, // Slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    function isPair(address _pair) public view returns (bool) {
        return _pair == address(uniswapV2Pair);
    }

    function isRouter(address _router) public view returns (bool) {
        return _router == address(uniswapV2Router);
    }

    function setAllowance(bool active) public onlyOwner {
        // Gas optimization - Approval
        // There is no risk in giving unlimited allowance to the router
        // As long as it's a trusted one
        IERC20(resource).safeApprove(address(uniswapV2Router), (active ? MAX_UINT256 : 0));
        IERC20(weth).safeApprove(address(uniswapV2Router), (active ? MAX_UINT256 : 0));
    }

    function shouldLiquify(bool _liquifyEnabled) public onlyOwner {
        liquifyEnabled = _liquifyEnabled;
        setAllowance(_liquifyEnabled);
    }

    function updateSwapTokensToLiquidityThreshold(
        uint256 _swapTokensToLiquidityThreshold
    ) public onlyOwner {
        require(
            _swapTokensToLiquidityThreshold > 0,
            "Treasury: Number of coins to swap to liquidity must be defined"
        );
        swapTokensToLiquidityThreshold = _swapTokensToLiquidityThreshold;
    }

    function setFeeAddresses(
        address _feeAddress
    ) public onlyOwner {
        require(feeAddress != address(0), "Treasury: address is not 0");
        feeAddress = _feeAddress;
    }

    function recoverLostETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverLostTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(resource != _token, "Treasury: !resource!");
        IERC20(_token).transfer(_to, _amount);
    }
}