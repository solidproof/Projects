// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IUVReserve.sol";

contract UVReserve is Ownable, AccessControl, IUVReserve {
    using SafeMath for uint256;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Testnet Router
    address public constant PANCAKE_ROUTER_ADDRESS =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
        // Testnet BUSD address
    address public constant stableCoin = 0x33F2534011277C09fE5Bd87D11ee3e251B2F8D1f;

    IPancakeRouter02 public pancakeRouter;
    address public factoryReserve;
    address public fundWallet;

    uint8 public orderNumber;
    address public poolStake;

    event SellToken(address indexed tokenInAddress, uint256 amountIn);

    constructor() {
        factoryReserve = msg.sender;
    }

    function initialize(uint8 _orderNumber, address _poolStake) external {
        require(msg.sender == factoryReserve, "FORBIDDEN");
        orderNumber = _orderNumber;
        poolStake = _poolStake;
        factoryReserve = msg.sender;
        pancakeRouter = IPancakeRouter02(PANCAKE_ROUTER_ADDRESS);

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
        address[] calldata _path,
        uint256 _deadline
    ) public onlyRole(MANAGER_ROLE) {
        IERC20(_path[0]).approve(PANCAKE_ROUTER_ADDRESS, _amountIn);
        pancakeRouter.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            _path,
            address(this),
            _deadline
        );
        emit SellToken(_path[0], _amountIn);
    }

    // Sell native token on pancake router
    function sellNativeToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline
    ) public onlyRole(MANAGER_ROLE) {
        pancakeRouter.swapExactETHForTokens{value: _amountIn}(
            _amountOutMin,
            _path,
            address(this),
            _deadline
        );
        emit SellToken(_path[0], _amountOutMin);
    }

    // Transfer token from reserve to pool stake token
    function transferTokenToTPPool(address token, uint256 amount)
        public
        onlyRole(MANAGER_ROLE)
    {
        require(token != address(0));
        require(amount > 0);
        IERC20 tokenInstance = IERC20(token);
        tokenInstance.transfer(poolStake, amount);
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
}
