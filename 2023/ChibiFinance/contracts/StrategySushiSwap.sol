// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/access/Ownable.sol";
import "./lib/token/ERC20/SafeERC20.sol";
import "./lib/utils/Pausable.sol";
import "./lib/utils/ReentrancyGuard.sol";

import "./libs/ISushiStake.sol";
import "./libs/IUniPair.sol";
import "./libs/IUniRouter02.sol";
import "./libs/IWETH.sol";

contract StrategySushiSwap is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public pid;
    address public constant sushiYieldAddress = 0xF4d73326C13a4Fc5FD7A064217e12780e9Bd62c3;
    address public wantAddress;
    address public token0Address;
    address public token1Address;
    address public earnedAddress;
    
    address public uniRouterAddress = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address public constant wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant vaultAddress = 0x4879712c5D1A98C0B88Fb700daFF5c65d12Fd729;
    address public constant feeAddress = 0x1cb757f1eB92F25A917CE9a92ED88c1aC0734334;
    address public vaultChefAddress;
    address public govAddress;

    uint256 public lastEarnBlock = block.number;
    uint256 public sharesTotal = 0;

    uint256 public controllerFee = 50;
    uint256 public constant feeMaxTotal = 1000;
    uint256 public constant feeMax = 10000;

    uint256 public withdrawFeeFactor = 10000;
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9900;

    uint256 public slippageFactor = 950;
    uint256 public constant slippageFactorUL = 995;

    address[] public earnedToWethPath;
    address[] public earnedToToken0Path;
    address[] public earnedToToken1Path;
    address[] public wethToToken0Path;
    address[] public wethToToken1Path;
    address[] public token0ToEarnedPath;
    address[] public token1ToEarnedPath;

    constructor(
        address _vaultChefAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address[] memory _earnedToWethPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _wethToToken0Path,
        address[] memory _wethToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        pid = _pid;
        earnedAddress = _earnedAddress;

        earnedToWethPath = _earnedToWethPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        wethToToken0Path = _wethToToken0Path;
        wethToToken1Path = _wethToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        transferOwnership(vaultChefAddress);
        _resetAllowances();
    }
    
    modifier onlyGov() {
        require(msg.sender == govAddress);
        _;
    }
    
    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        uint256 wantLockedBefore = wantLockedTotal();

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        uint256 sharesAdded = _farm();
        if (sharesTotal > 0) {
            sharesAdded = sharesAdded.mul(sharesTotal).div(wantLockedBefore);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        return sharesAdded;
    }

    function _farm() internal returns (uint256) {
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        if (wantAmt == 0) return 0;
        
        uint256 sharesBefore = vaultSharesTotal();
        ISushiStake(sushiYieldAddress).deposit(pid, wantAmt, address(this));
        uint256 sharesAfter = vaultSharesTotal();
        
        return sharesAfter.sub(sharesBefore);
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0);
        
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        
        if (_wantAmt > wantAmt) {
            ISushiStake(sushiYieldAddress).withdraw(pid, _wantAmt.sub(wantAmt), address(this));
            wantAmt = IERC20(wantAddress).balanceOf(address(this));
        }

        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (_wantAmt > wantLockedTotal()) {
            _wantAmt = wantLockedTotal();
        }

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal());
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);
        
        uint256 withdrawFee = _wantAmt
            .mul(withdrawFeeFactorMax.sub(withdrawFeeFactor))
            .div(withdrawFeeFactorMax);
        IERC20(wantAddress).safeTransfer(vaultAddress, withdrawFee);
        
        _wantAmt = _wantAmt.sub(withdrawFee);

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);

        return sharesRemoved;
    }

    function earn() external nonReentrant whenNotPaused {
        ISushiStake(sushiYieldAddress).harvest(pid, address(this));

        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));
        uint256 wethAmt = IERC20(wethAddress).balanceOf(address(this));

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt, earnedAddress);
    
            if (earnedAddress != token0Address) {
                _safeSwap(
                    earnedAmt.div(2),
                    earnedToToken0Path,
                    address(this)
                );
            }
    
            if (earnedAddress != token1Address) {
                _safeSwap(
                    earnedAmt.div(2),
                    earnedToToken1Path,
                    address(this)
                );
            }
        }
        
        if (wethAmt > 0) {
            wethAmt = distributeFees(wethAmt, wethAddress);
    
            if (wethAddress != token0Address) {
                _safeSwap(
                    wethAmt.div(2),
                    wethToToken0Path,
                    address(this)
                );
            }
    
            if (wethAddress != token1Address) {
                _safeSwap(
                    wethAmt.div(2),
                    wethToToken1Path,
                    address(this)
                );
            }
        }
        
        if (earnedAmt > 0 || wethAmt > 0) {
            uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
            uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
            if (token0Amt > 0 && token1Amt > 0) {
                IUniRouter02(uniRouterAddress).addLiquidity(
                    token0Address,
                    token1Address,
                    token0Amt,
                    token1Amt,
                    0,
                    0,
                    address(this),
                    now.add(600)
                );
            }

            lastEarnBlock = block.number;
    
            _farm();
        }
    }

    function distributeFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt.mul(controllerFee).div(feeMax);
            
            if (_earnedAddress == wethAddress) {
                IWETH(wethAddress).withdraw(fee);
                safeTransferETH(feeAddress, fee);
            } else {
                _safeSwapWeth(
                    fee,
                    earnedToWethPath,
                    feeAddress
                );
            }
            
            _earnedAmt = _earnedAmt.sub(fee);
        }

        return _earnedAmt;
    }

    function convertDustToEarned() external nonReentrant whenNotPaused {

        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
        if (token0Amt > 0 && token0Address != earnedAddress) {
            _safeSwap(
                token0Amt,
                token0ToEarnedPath,
                address(this)
            );
        }

        uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
        if (token1Amt > 0 && token1Address != earnedAddress) {
            _safeSwap(
                token1Amt,
                token1ToEarnedPath,
                address(this)
            );
        }
    }

    function pause() external onlyGov {
        _pause();
    }

    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }
    
    
    function vaultSharesTotal() public view returns (uint256) {
        (uint256 balance,) = ISushiStake(sushiYieldAddress).userInfo(pid, address(this));
        return balance;
    }
    
    function wantLockedTotal() public view returns (uint256) {
        (uint256 balance,) = ISushiStake(sushiYieldAddress).userInfo(pid, address(this));
        return IERC20(wantAddress).balanceOf(address(this)).add(balance);
    }

    function _resetAllowances() internal {
        
        IERC20(wantAddress).safeApprove(sushiYieldAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            sushiYieldAddress,
            uint256(-1)
        );

        IERC20(earnedAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(wethAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(wethAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );
        
        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token0Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token0Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token1Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token1Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }

    function panic() external onlyGov {
        _pause();
        ISushiStake(sushiYieldAddress).emergencyWithdraw(pid, address(this));
    }

    function unpanic() external onlyGov {
        _unpause();
        _farm();
    }
    
    function setSettings(
        uint256 _controllerFee,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress
    ) external onlyGov {
        require(_controllerFee <= feeMaxTotal);
        require(_withdrawFeeFactor >= withdrawFeeFactorLL);
        require(_withdrawFeeFactor <= withdrawFeeFactorMax);
        require(_slippageFactor <= slippageFactorUL);
        controllerFee = _controllerFee;
        withdrawFeeFactor = _withdrawFeeFactor;
        slippageFactor = _slippageFactor;
        uniRouterAddress = _uniRouterAddress;
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }
    
    function _safeSwap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IUniRouter02(uniRouterAddress).swapExactTokensForTokens(
            _amountIn,
            amountOut.mul(slippageFactor).div(1000),
            _path,
            _to,
            now.add(600)
        );
    }
    
    function _safeSwapWeth(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IUniRouter02(uniRouterAddress).swapExactTokensForETH(
            _amountIn,
            amountOut.mul(slippageFactor).div(1000),
            _path,
            _to,
            now.add(600)
        );
    }
    
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success);
    }

    receive() external payable {}
}