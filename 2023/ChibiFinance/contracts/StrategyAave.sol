// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/access/Ownable.sol";
import "./lib/token/ERC20/SafeERC20.sol";
import "./lib/utils/Pausable.sol";
import "./lib/utils/ReentrancyGuard.sol";

import "./libs/IAaveStake.sol";
import "./libs/IProtocolDataProvider.sol";
import "./libs/IUniPair.sol";
import "./libs/IUniRouter02.sol";
import "./libs/IWETH.sol";

contract StrategyAave is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant aaveDataAddress = 0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654;
    address public constant aaveDepositAddress = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;
    address public constant aaveClaimAddress = 0x929EC64c34a17401F460460D4B9390518E5B473e;
    address public wantAddress;
    address public vTokenAddress; 
    address public debtTokenAddress; 
    address public earnedAddress;
    uint16 public referralCode = 0;
    
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
    uint256 public constant feeMax = 10000; // 100 = 1%

    uint256 public withdrawFeeFactor = 10000; // 0% withdraw fee
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9900;

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;
    
    /**
     * @dev Variables that can be changed to config profitability and risk:
     * {borrowRate}          - At What % of our collateral do we borrow per leverage level.
     * {borrowDepth}         - Ma How many levels of leverage do we take.
     * {BORROW_RATE_MAX}     - Cat A limit on how much we can push borrow risk.
     * {BORROW_DEPTH_MAX}    - Kevin A limit on how many steps we can leverage.
     */
    uint256 public borrowRate;
    uint256 public borrowDepth = 0;
    uint256 public minLeverage;
    uint256 public BORROW_RATE_MAX;
    uint256 public BORROW_RATE_MAX_HARD;
    uint256 public BORROW_DEPTH_MAX = 8;
    uint256 public constant BORROW_RATE_DIVISOR = 10000;

    address[] public vTokenArray;
    address[] public earnedToWantPath;

    constructor(
        address _vaultChefAddress,
        uint256 _minLeverage,
        address _wantAddress,
        address _vTokenAddress,
        address _debtTokenAddress,
        address _earnedAddress,
        address[] memory _earnedToWantPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        minLeverage = _minLeverage;

        wantAddress = _wantAddress;
        vTokenAddress = _vTokenAddress;
        vTokenArray = [vTokenAddress];
        debtTokenAddress = _debtTokenAddress;

        earnedAddress = _earnedAddress;

        earnedToWantPath = _earnedToWantPath;
        
        (, uint256 ltv, uint256 threshold, , , bool collateral, bool borrow, , , ) = 
            IProtocolDataProvider(aaveDataAddress).getReserveConfigurationData(wantAddress);
        BORROW_RATE_MAX = ltv.mul(99).div(100); // 1%
        BORROW_RATE_MAX_HARD = ltv.mul(999).div(1000); // 0.1%
        // At minimum, borrow rate always 10% lower than liquidation threshold
        if (threshold.mul(9).div(10) > BORROW_RATE_MAX) {
            borrowRate = BORROW_RATE_MAX;
        } else {
            borrowRate = threshold.mul(9).div(10);
        }
        // Only leverage if you can
        if (!(collateral && borrow)) {
            borrowDepth = 0;
            BORROW_DEPTH_MAX = 0;
        }

        transferOwnership(vaultChefAddress);
        _resetAllowances();
    }
    
    event SetSettings(
        uint256 _controllerFee,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress
    );
    
    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }
    
    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        // Call must happen before transfer
        uint256 wantLockedBefore = wantLockedTotal();

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // Proper deposit amount for tokens with fees, or vaults with deposit fees
        uint256 sharesAdded = _farm(_wantAmt);
        if (sharesTotal > 0) {
            sharesAdded = sharesAdded.mul(sharesTotal).div(wantLockedBefore);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        return sharesAdded;
    }

    function _farm(uint256 _wantAmt) internal returns (uint256) {
        uint256 wantAmt = wantLockedInHere();
        if (wantAmt == 0) return 0;
        
        uint256 sharesBefore = wantLockedTotal().sub(_wantAmt);
        _leverage(wantAmt);
        
        return wantLockedTotal().sub(sharesBefore);
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt is 0");
        
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        
        if (_wantAmt > wantAmt) {
            // Fully deleverage
            _deleverage();
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
        
        // Withdraw fee
        uint256 withdrawFee = _wantAmt
            .mul(withdrawFeeFactorMax.sub(withdrawFeeFactor))
            .div(withdrawFeeFactorMax);
        IERC20(wantAddress).safeTransfer(vaultAddress, withdrawFee);
        
        _wantAmt = _wantAmt.sub(withdrawFee);

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);

        if (!paused()) {
            // Put it all back in
            _leverage(wantLockedInHere());
        }

        return sharesRemoved;
    }
    
    function _supply(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).deposit(wantAddress, _amount, address(this), referralCode);
    }
    
    function _removeSupply(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).withdraw(wantAddress, _amount, address(this));
    }
    
    function _borrow(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).borrow(wantAddress, _amount, 2, referralCode, address(this));
    }
    
    function _repayBorrow(uint256 _amount) internal {
        IAaveStake(aaveDepositAddress).repay(wantAddress, _amount, 2, address(this));
    }
    
    /**
     * @dev Deposits token, withdraws a percentage, and deposits again
     * We stop at _borrow because we need some tokens to deleverage
     */
    function _leverage(uint256 _amount) internal {
        if (borrowDepth == 0) {
            _supply(_amount);
        } else if (_amount > minLeverage) {
            for (uint256 i = 0; i < borrowDepth; i++) {
                _supply(_amount);
                _amount = _amount.mul(borrowRate).div(BORROW_RATE_DIVISOR);
                _borrow(_amount);
            }
        }
    }
    
    /**
     * @dev Manually wind back one step in case contract gets stuck
     */
    function deleverageOnce() external onlyGov {
        _deleverageOnce();
    }
    
    function _deleverageOnce() internal {
        if (vTokenTotal() <= supplyBalTargeted()) {
            _removeSupply(vTokenTotal().sub(supplyBalMin()));
        } else {
            _removeSupply(vTokenTotal().sub(supplyBalTargeted()));
        }

        _repayBorrow(wantLockedInHere());
    }
    
    /**
     * @dev Fully deleverage
     */
    function _deleverage() internal {
        uint256 wantBal = wantLockedInHere();

        if (borrowDepth > 0) {
            while (wantBal < debtTotal()) {
                _repayBorrow(wantBal);
                _removeSupply(vTokenTotal().sub(supplyBalMin()));
                wantBal = wantLockedInHere();
            }
            
            _repayBorrow(wantBal);
        }
        _removeSupply(uint256(-1));
    }

    function _deleverageSingle(uint256 _amount) internal {
        if (borrowDepth == 0){
            _removeSupply(_amount);
        } else if (_amount > minLeverage) {
            uint256 requiredWantAmt = _amount;
            for (uint256 i = 0; i < borrowDepth; i++){
                requiredWantAmt = requiredWantAmt.mul(borrowRate).div(BORROW_RATE_DIVISOR);
            }
            for (uint256 i = 0; i < borrowDepth; i++){
                _repayBorrow(requiredWantAmt);
                requiredWantAmt.div(borrowRate).mul(BORROW_RATE_DIVISOR);
                _removeSupply(requiredWantAmt);
            }
        }
    }

    function earn() external nonReentrant whenNotPaused {
        uint256 preEarn = IERC20(earnedAddress).balanceOf(address(this));

        // Harvest farm tokens
        IAaveStake(aaveClaimAddress).claimAllRewards(vTokenArray, address(this));
        
        // Because we keep some tokens in this contract, we have to do this if earned is the same as want
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this)).sub(preEarn);

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt);
            
            if (earnedAddress != wantAddress) {
                _safeSwap(
                    earnedAmt,
                    earnedToWantPath,
                    address(this)
                );
            }
    
            lastEarnBlock = block.number;
    
            _leverage(wantLockedInHere());
        }
    }

    // To pay for earn function
    function distributeFees(uint256 _earnedAmt) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt.mul(controllerFee).div(feeMax);
            
            IWETH(wethAddress).withdraw(fee);
            safeTransferETH(feeAddress, fee);
            
            _earnedAmt = _earnedAmt.sub(fee);
        }

        return _earnedAmt;
    }

    // Emergency!!
    function pause() external onlyGov {
        _pause();
    }

    // False alarm
    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }
    
    function debtTotal() public view returns (uint256) {
        return IERC20(debtTokenAddress).balanceOf(address(this));
    }
    
    function supplyBalTargeted() public view returns (uint256) {
        return debtTotal().mul(BORROW_RATE_DIVISOR).div(borrowRate);
    }
    
    function supplyBalMin() public view returns (uint256) {
        return debtTotal().mul(BORROW_RATE_DIVISOR).div(BORROW_RATE_MAX_HARD);
    }
    
    function vTokenTotal() public view returns (uint256) {
        return IERC20(vTokenAddress).balanceOf(address(this));
    }
    
    function wantLockedInHere() public view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this));
    }
    
    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere()
            .add(vTokenTotal())
            .sub(debtTotal());
    }

    function _resetAllowances() internal {
        IERC20(wantAddress).safeApprove(aaveDepositAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            aaveDepositAddress,
            uint256(-1)
        );

        IERC20(wantAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(earnedAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }

    function panic() external onlyGov {
        _pause();
        _deleverage();
    }

    function unpanic() external onlyGov {
        _unpause();
        _leverage(wantLockedInHere());
    }
    

    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external onlyGov {
        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowRate != 0, "borrowRate is used as a divisor");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage();
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _leverage(wantLockedInHere());
    }
    
    function setSettings(
        uint256 _controllerFee,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress
    ) external onlyGov {
        require(_controllerFee <= feeMaxTotal, "Max fee of 10%");
        require(_withdrawFeeFactor >= withdrawFeeFactorLL, "_withdrawFeeFactor too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "_withdrawFeeFactor too high");
        require(_slippageFactor <= slippageFactorUL, "_slippageFactor too high");
        controllerFee = _controllerFee;
        withdrawFeeFactor = _withdrawFeeFactor;
        slippageFactor = _slippageFactor;
        uniRouterAddress = _uniRouterAddress;

        emit SetSettings(
            _controllerFee,
            _withdrawFeeFactor,
            _slippageFactor,
            _uniRouterAddress
        );
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

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }

    receive() external payable {}
}