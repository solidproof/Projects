// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGarbageSale {
    function garbageToken() external view returns (IERC20);

    function usdt() external view returns (IERC20);

    function treasury() external view returns (address);

    function currentStage() external view returns (uint256);

    function saleDeadline() external view returns (uint256);

    function claimDate() external view returns (uint256);

    function bloggerRewardPercent() external view returns (uint256);

    function userRewardPercent() external view returns (uint256);

    function totalTokensToBeDistributed() external view returns (uint256);

    function totalTokensSold() external view returns (uint256);

    function totalTokensClaimed() external view returns (uint256);

    function referralRewardsEth(address referrer) external view returns (uint256);

    function referralRewardsUsdt(address referrer) external view returns (uint256);

    function claimableTokens(address claimer) external view returns (uint256);

    function getStagesLength() external view returns (uint256);

    function getCurrentStageInfo()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getCurrencyAmountFromTokenAmount(uint256 tokens, bool isEth) external view returns (uint256 amount);

    function getTokenAmountFromCurrencyAmount(uint256 amount, bool isEth) external view returns (uint256 tokens);

    function buyTokensWithEth(address referrer) external payable;

    function buyTokensWithUsdt(uint256 amount, address referrer) external;

    function setSaleDeadline(uint256 newDeadline) external;

    function claimTokens() external;

    function pause() external;

    function unpause() external;

    function withdrawRemainder(uint256 amount) external;
}
