// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// PancakeRouter address is 0x10ED43C718714eb63d5aA57B78B54704E256024E in mainnet

import "./ITokenomicsStrategy.sol";
import "../token/IFCKToken.sol";
import "../pancake/IPancakeRouter02.sol";
import "../pancake/IPancakePair.sol";
import "../pancake/IPancakeFactory.sol";

contract AutomaticTokenomicsStrategy is ITokenomicsStrategy {
    IFCKToken private _token;
    address private _tokenomicsWallet;
    address private _charityWallet;
    address private _operationalWallet;
    address private _PancakeRouterAddress;
    address private _PancakePairAddress;
    uint256 private amountToBurn;
    uint256 private charityAmount;
    uint256 private operationalAmount;

    IPancakeRouter02 private router;
    IPancakeFactory private factory;
    IPancakePair private pair;
    address[] private path;

    constructor(
        IFCKToken token,
        address tokenomicsWallet,
        address charityWallet,
        address operationalWallet,
        address PancakeRouterAddress
    ) {
        _token = token;
        _tokenomicsWallet = tokenomicsWallet;
        _charityWallet = charityWallet;
        _operationalWallet = operationalWallet;
        _PancakeRouterAddress = PancakeRouterAddress;
        router = IPancakeRouter02(_PancakeRouterAddress);
        factory = IPancakeFactory(router.factory());
        factory.createPair(address(_token), router.WETH());
        _PancakePairAddress = factory.getPair(address(_token), router.WETH());
        pair = IPancakePair(_PancakePairAddress);
        path = [address(_token), router.WETH()];
    }

    function SwapAndSendTokens(uint256 _amountToConvert, address recipient)
        private
        returns (uint256[] memory _amounts)
    {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves(); // getting reserves of token and BNB from Pancakeswap
        uint256 maxAmountOut = router.getAmountOut(
            _amountToConvert,
            reserve0,
            reserve1
        ); // maximum amount of BNB we can get exchanging tokens we have
        _token.approve(_PancakeRouterAddress, maxAmountOut); // approve sending tokens
        return
            router.swapExactTokensForETH(
                _amountToConvert,
                (maxAmountOut / 100) * 95,
                path,
                recipient,
                3600
            ); // swap tokens and send minimum 95% of maximum BNB in maximum an hour
    }

    function process() external override {
        _token.transferFrom(
            address(_token),
            address(this),
            _token.balanceOf(address(_token))
        );
        // charityAmount = (amount * (_token.shouldBurnFee() ? 10 : 33)) / 100;
        // operationalAmount = amount - (amountToBurn + charityAmount);
        // if (_token.shouldBurnFee()) {
        //     _token.burnFrom(address(this), amountToBurn);                                                       // burning
        // }
        // SwapAndSendTokens(charityAmount, _charityWallet);
        // SwapAndSendTokens(operationalAmount, _operationalWallet);
    }
}
