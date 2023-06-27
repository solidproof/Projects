// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.


pragma solidity 0.8.17;

import "./libraries/Ownable.sol";

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IBuyBackWallet.sol";
import "./interfaces/ILPWallet.sol";
import "./interfaces/ITaxToken.sol";
import "./interfaces/IMintFactory.sol";

// add events

contract TaxHelperUniswapV2 is Ownable{
    
    IUniswapV2Router02 router;
    IUniswapV2Factory factory;
    IMintFactory mintFactory;

    // event Buy
    event CreatedLPToken(address token0, address token1, address LPToken);

    constructor(address swapV2Router, address swapV2Factory, address _mintFactory) {
    router = IUniswapV2Router02(swapV2Router);
    factory = IUniswapV2Factory(swapV2Factory);
    mintFactory = IMintFactory(_mintFactory);
 
    }

    modifier isToken() {
        require(mintFactory.tokenIsRegistered(msg.sender), "RA");
        _;
    }

    function initiateBuyBackTax(address _token, address _wallet) payable external isToken returns(bool) {
        ITaxToken token = ITaxToken(_token);
        uint256 _amount = token.balanceOf(address(this));
        address[] memory addressPaths = new address[](2);
        addressPaths[0] = _token;
        addressPaths[1] = router.WETH();
        token.approve(address(router), _amount);
        if(_amount > 0) {
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(_amount, 0, addressPaths, _wallet, block.timestamp);
        }
        IBuyBackWallet buyBackWallet = IBuyBackWallet(_wallet);
        bool res = buyBackWallet.checkBuyBackTrigger();
        if(res) {
            addressPaths[0] = router.WETH();
            addressPaths[1] = _token;
            uint256 amountEth = buyBackWallet.sendEthToTaxHelper();
            uint256 balanceBefore = token.balanceOf(address(this));
            router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amountEth}(0, addressPaths, address(this), block.timestamp);
            // burn baby burn!
            uint256 balanceAfter = token.balanceOf(address(this));
            uint256 amountToBurn = balanceAfter - balanceBefore;
            token.approve(token.owner(), amountToBurn);
            token.buyBackBurn(amountToBurn);
        }
        return true;
    }

    function initiateLPTokenTax(address _token, address _wallet) external isToken returns (bool) {
        ITaxToken token = ITaxToken(_token);
        uint256 _amount = token.balanceOf(address(this));
        address[] memory addressPaths = new address[](2);
        addressPaths[0] = _token;
        addressPaths[1] = router.WETH();
        uint256 halfAmount = _amount / 2;
        uint256 otherHalf = _amount - halfAmount;
        token.transfer(_wallet, otherHalf);
        token.approve(address(router), halfAmount);
        if(halfAmount > 0) {
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(halfAmount, 0, addressPaths, _wallet, block.timestamp);
        }
        ILPWallet lpWallet = ILPWallet(_wallet);
        bool res = lpWallet.checkLPTrigger();
        if(res) {
            lpWallet.transferBalanceToTaxHelper();
            uint256 amountEth = lpWallet.sendEthToTaxHelper();
            uint256 tokenBalance = token.balanceOf(address(this));
            token.approve(address(router), tokenBalance);
            router.addLiquidityETH{value: amountEth}(_token, tokenBalance, 0, 0, token.owner(), block.timestamp + 20 minutes);
            uint256 ethDust = address(this).balance;
            if(ethDust > 0) {
                (bool sent,) = _wallet.call{value: ethDust}("");
                require(sent, "Failed to send Ether");
            }
            uint256 tokenDust = token.balanceOf(address(this));
            if(tokenDust > 0) {
                token.transfer(_wallet, tokenDust);
            }
        }
        return true;
    }    
    
    function createLPToken() external returns(address lpToken) {
        lpToken = factory.createPair(msg.sender, router.WETH());
        emit CreatedLPToken(msg.sender, router.WETH(), lpToken);
    }

    function lpTokenHasReserves(address _lpToken) public view returns (bool) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(_lpToken).getReserves();
        return reserve0 > 0 && reserve1 > 0;
    }

    function sync(address _lpToken) public {
        IUniswapV2Pair(_lpToken).sync();
    }

    receive() payable external {
    }

} 