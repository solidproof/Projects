//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IBroErrors {
    error AboveMaxTxAmount(uint256 amount, uint256 maxTxAmount);
    error AccountIsAlreadyExcludedFromRewards();
    error AccountIsAlreadyIncludedInRewards();
    error AmountMustBeLessThanSupply();
    error AmountMustBeGreaterThanZero();
    error AmountIsGreaterThanMaxFee(string valueType, uint256 amount);
    error AmountCannotBeHigherThanTotal(uint256 amount, uint256 total);
    error AmountCannotBeHigherThanMaxTxAmount(uint256 amount, uint256 maxTxAmount);
    error AmountCannotBeLessThanMinMaxTxAmount(uint256 amount, uint256 minTxAmount);
    error AmountCannotBeLessThanMinHolderThreshold(uint256 amount, uint256 minHolderThreshold);
    error AmountMustBeLessThanTotalReflection(uint256 amount, uint256 totalReflection);
    error AmountCannotBeLessThanNumTokensSellToAddLiquidity(uint256 amount, uint256 numTokensSellToAddToLiquidity);
    error AmountCannotBeLessThanMinNumTokensSellToAddLiquidity(uint256 amount, uint256 minNumTokensSellToAddToLiquidity);
    error CannotBeZeroAddress();
    error CannotBeDeadAddress();
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidApprover(address approver);
    error ForbiddenFunctionCallForExcludedAddresses();
    error PercentageCannotBeHigherThan100Percent(uint256 percentage, uint256 maxPercentage);
    error PercentagesDoNotCorrespondToSetFee();
    error CannotWithdrawFromOwnContractAddress();
}