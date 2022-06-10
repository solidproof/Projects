// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function WETH() external pure returns (address);

    function factory() external pure returns (address);
}

contract InversteeDetailsStruct {
    struct InversteeDetails {
        address _investee;
        uint _fundAmount;
    }
}

interface IGovernance {
    function _fundInvestee() external returns(InversteeDetailsStruct.InversteeDetails memory);
    function nextInvesteeFund() external pure returns(uint256);
    function nextInvestee() external pure returns(uint256);
}

interface IURevolt {
    function updateCultMandorsReward(uint256 _reward) external;
}

contract Treasury is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public rvlt;
    address public dao;
    address public uRvlt;
    address public multSignWallet;
    address public router;

    address[] private path;
    address[] private pathUSDC;
    address public USDC;
    function initialize(        
        address _rvlt,
        address _router,
        address _usdc
        ) public initializer {
        require(_rvlt != address(0),"initialize: Invalid address");
        require(_router != address(0),"initialize: Invalid address");
        rvlt = _rvlt;
        router = _router;
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        __Context_init_unchained();
        __Pausable_init_unchained();
        path.push(rvlt);
        path.push(IUniswapV2Router(router).WETH());
        USDC = _usdc;
        pathUSDC.push(rvlt);
        pathUSDC.push(IUniswapV2Router(router).WETH());
        pathUSDC.push(USDC);
    }

    function _authorizeUpgrade(address) internal view override {
        require(owner() == msg.sender, "Only owner can upgrade implementation");
    }

    function setDAOAddress(address _dao) external onlyOwner {
        require(_dao != address(0),"setDAOAddress: Invalid address");
        dao = _dao;
    }

    function setuRVLTAddress(address _urvlt) external onlyOwner {
        require(_urvlt != address(0),"setDAOAddress: Invalid address");
        uRvlt = _urvlt;
    }

    function setMultiSignAddress(address _multiSignAddress) external onlyOwner {
        require(_multiSignAddress != address(0),"setMultiSignAddress: Invalid address");
        multSignWallet = _multiSignAddress;
    }

    function revoltPriceInUSD(uint256 _amount) public view returns (uint256) {
        uint256[] memory revoltAmount = IUniswapV2Router(router).getAmountsOut(_amount, pathUSDC);
        return revoltAmount[2];
    }

    function validatePayout() external {
        uint256 balance = IERC20Upgradeable(rvlt).balanceOf(address(this));
        if(balance > 0) {
            uint256[] memory getRvltAmountOneETH = IUniswapV2Router(router).getAmountsOut(balance, path);
            if(IGovernance(dao).nextInvesteeFund()<IGovernance(dao).nextInvestee()){
                fundInvestee(getRvltAmountOneETH[1]);
            }
        }
    }

    function fundInvestee(uint256 totalAmount) internal nonReentrant{
        InversteeDetailsStruct.InversteeDetails memory investee = IGovernance(dao)._fundInvestee();
        if(investee._fundAmount <= totalAmount) {
            IERC20Upgradeable(rvlt).transfer(DEAD_ADDRESS, investee._fundAmount.mul(25).div(100));
            IERC20Upgradeable(rvlt).transfer(investee._investee, investee._fundAmount.mul(40).div(100));
            IERC20Upgradeable(rvlt).transfer(uRvlt, investee._fundAmount.mul(25).div(100));
            IERC20Upgradeable(rvlt).transfer(multSignWallet, investee._fundAmount.mul(5).div(100));
            IERC20Upgradeable(rvlt).approve(uRvlt, investee._fundAmount.mul(5).div(100));
            IURevolt(uRvlt).updateCultMandorsReward(investee._fundAmount.mul(5).div(100));
        }
    }
}
