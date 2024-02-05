pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IMasterChef.sol";

interface IGmxRouter {
    function compound() external;

    function handleRewards(
        bool _shouldClaimGmx,
        bool _shouldStakeGmx,
        bool _shouldClaimEsGmx,
        bool _shouldStakeEsGmx,
        bool _shouldStakeMultiplierPoints,
        bool _shouldClaimWeth,
        bool _shouldConvertWethToEth
    ) external;

    function claim() external;

    function mintAndStakeGlp(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minGlp) external returns (uint256);
    function mintAndStakeGlpETH(uint256 _minUsdg, uint256 _minGlp) external payable returns (uint256);
}

contract GLPVaultV1 {
    using SafeERC20 for IERC20;

    address public immutable sGLP = 0x2F546AD4eDD93B956C8999Be404cdCAFde3E89AE;
    address public immutable fsGLP = 0x1aDDD80E6039594eE970E5872D247bf0414C8903;
    address public immutable gmxRouter = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;
    address public immutable glpManager = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
    address public immutable gmxMintGlpRouter = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
    address public immutable WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public immutable masterChef;
    uint public immutable pid;

    mapping(address => uint) public sharesOf;
    uint public totalShareBal;
    
    constructor(
        address _masterChef,
        uint _pid
    ) {      
        masterChef = _masterChef;
        pid = _pid;
    }

    function deposit(uint amount) public {
        reInvest();

        uint shareAmount;
        uint beforeBal = IERC20(fsGLP).balanceOf(address(this));
        
        if (totalShareBal == 0) {
            shareAmount = amount;
        } else {
            shareAmount = amount * totalShareBal / beforeBal;
        }

        IERC20(sGLP).safeTransferFrom(msg.sender, address(this), amount);
        IMasterChef(masterChef).deposit(pid, shareAmount, msg.sender);

        sharesOf[msg.sender] += shareAmount;
        totalShareBal += shareAmount;
        
    }

    function withdraw(uint amount) public {
        reInvest();

        uint shareAmount;
        uint beforeBal = IERC20(fsGLP).balanceOf(address(this));
        

        shareAmount = amount * totalShareBal / beforeBal;
        require(shareAmount <= sharesOf[msg.sender]);

        IMasterChef(masterChef).withdraw(pid, shareAmount, msg.sender);
        
        IERC20(sGLP).safeTransfer(msg.sender, amount);
        sharesOf[msg.sender] -= shareAmount;
        totalShareBal -= shareAmount;

    }

    function withdrawAll() public {
        reInvest();

        uint shareAmount = sharesOf[msg.sender];
        require(shareAmount > 0);

        uint beforeBal = IERC20(fsGLP).balanceOf(address(this));
        uint amount = shareAmount * beforeBal / totalShareBal;

        IMasterChef(masterChef).withdraw(pid, shareAmount, msg.sender);

        IERC20(sGLP).safeTransfer(msg.sender, amount);  
        sharesOf[msg.sender] = 0;
        totalShareBal -= shareAmount;
    }

    function getGLPBalance(address user) public view returns (uint256) {
        uint shareAmount = sharesOf[user];
        uint beforeBal = IERC20(fsGLP).balanceOf(address(this));
        uint amount = shareAmount * beforeBal / totalShareBal;

        return amount;
    }
    
    function reInvest() public {
        IGmxRouter(gmxRouter).handleRewards(true, true, true, true, true, true, false);
        uint wethBal = IERC20(WETH).balanceOf(address(this));
        if (wethBal > 0) {
            IERC20(WETH).approve(glpManager, wethBal);
            IGmxRouter(gmxMintGlpRouter).mintAndStakeGlp(WETH, wethBal, 1, 1);
        }
    }


}
