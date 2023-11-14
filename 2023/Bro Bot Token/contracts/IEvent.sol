//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IBroEvents  {
    event DevelopmentWalletUpdated(address oldAddress, address newAddress);
    event ManualSwapExecuted(uint256 timestamp);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event MarketingWalletUpdated(address oldAddress, address newAddress);
    event UpdatedEnabledMaxTx(bool status);
    event UpdatedThresholdEnabled(bool enabled);
    event UpdateExcludedFromFee(address addr, bool flag);
    event UpdateExcludedFromMaxTx(address addr, bool flag);
    event UpdateExcludedFromRewards(address addr, bool flag);
    event UpdatedMaxTxAmount(uint256 oldValue, uint256 newValue);
    event UpdateExcludedFromHolderThreshold(address addr, bool flag);
    event UpdatedFee(string valueType, uint256 oldFee, uint256 newFee);
    event UpdatedNumTokensSellToAddToLiquidity(uint256 oldValue, uint256 newValue);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event UpdatedHolderThreshold(uint256 old, uint256 threshold);
}