// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./interfaces/IUVReserve.sol";

contract UVReserve is Ownable, AccessControl, IUVReserve {
    using SafeMath for uint256;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public constant SWAP_ROUTER_ADDRESS =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant stableCoin =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint24 public constant poolFee = 3000;

    ISwapRouter public swapRouter;
    address public factoryReserve;
    address public fundWallet;

    uint8 public orderNumber;
    address public tpPool;

    event SellToken(address indexed tokenInAddress, uint256 amountIn);

    constructor() {
        factoryReserve = msg.sender;
    }

    function initialize(uint8 _orderNumber, address _tpPool) external {
        require(msg.sender == factoryReserve, "FORBIDDEN");
        orderNumber = _orderNumber;
        tpPool = _tpPool;
        factoryReserve = msg.sender;
        swapRouter = ISwapRouter(SWAP_ROUTER_ADDRESS);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    // important to receive BNB
    receive() external payable {}

    fallback() external payable {}

    // Sell token on pancake router
    function sellToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        bytes calldata _path,
        uint256 _deadline
    ) public onlyRole(MANAGER_ROLE) {
        TransferHelper.safeApprove(_tokenIn, address(swapRouter), _amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: _path,
                recipient: address(this),
                deadline: _deadline,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin
            });

        // Executes the swap.
        uint256 realAmount = swapRouter.exactInput(params);

        emit SellToken(_tokenIn, realAmount);
    }

    // Transfer token from reserve to pool tp
    function transferTokenToTPPool(address token, uint256 amount)
        public
        onlyRole(MANAGER_ROLE)
    {
        require(token != address(0));
        require(amount > 0);
        IERC20 tokenInstance = IERC20(token);
        tokenInstance.transfer(tpPool, amount);
    }

    // get pool reserve address
    function getPoolReserve() public view returns (address) {
        return address(this);
    }

    // Add wallet to manager role
    function addManager(address _manager) public onlyOwner {
        _setupRole(MANAGER_ROLE, _manager);
    }

    // Remove wallet from manager role
    function removeManager(address _manager) public onlyOwner {
        revokeRole(MANAGER_ROLE, _manager);
    }

    // Set the fund wallet
    function setFundWallet(address _fundWallet) public onlyOwner {
        fundWallet = _fundWallet;
    }
}
