// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./IVibranium.sol";
import "./IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IStakingRewards {
    function rewardRate() external view returns (uint256);
}

contract VibraniumHelper {
    IVibranium public immutable vibranium;
    address public lido;
    AggregatorV3Interface internal priceFeed;

    constructor(address _vibranium, address _lido, address _priceFeed) {
        vibranium = IVibranium(_vibranium);
        lido = _lido;
        priceFeed =
        AggregatorV3Interface(_priceFeed);

    }

    function getEtherPrice() public view returns (uint256) {
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getCollateralRate(address user) public view returns (uint256) {
        if (vibranium.getBorrowedOf(user) == 0) return 1e22;
        return
            (vibranium.depositedEther(user) * getEtherPrice() * 1e12) /
            vibranium.getBorrowedOf(user);
    }

    function getExcessIncomeAmount()
        external
        view
        returns (uint256 vusdAmount)
    {
        if (
            IERC20(lido).balanceOf(address(vibranium)) < vibranium.totalDepositedEther()
        ) {
            vusdAmount = 0;
        } else {
            vusdAmount =
                ((IERC20(lido).balanceOf(address(vibranium)) -
                    vibranium.totalDepositedEther()) * getEtherPrice()) /
                1e8;
        }
    }

    function getOverallCollateralRate() public view returns (uint256) {
        return
            (vibranium.totalDepositedEther() * getEtherPrice() * 1e12) /
            vibranium.totalSupply();
    }

    function getLiquidateableAmount(address user)
        external
        view
        returns (uint256 etherAmount, uint256 vusdAmount)
    {
        if (getCollateralRate(user) > 150 * 1e18) return (0, 0);
        if (
            getCollateralRate(user) >= 125 * 1e18 ||
            getOverallCollateralRate() >= 150 * 1e18
        ) {
            etherAmount = vibranium.depositedEther(user) / 2;
            vusdAmount = (etherAmount * getEtherPrice()) / 1e8;
        } else {
            etherAmount = vibranium.depositedEther(user);
            vusdAmount = (etherAmount * getEtherPrice()) / 1e8;
            if (getCollateralRate(user) >= 1e20) {
                vusdAmount = (vusdAmount * 1e20) / getCollateralRate(user);
            }
        }
    }

    function getRedeemableAmount(address user) external view returns (uint256) {
        if (!vibranium.isRedemptionProvider(user)) return 0;
        return vibranium.getBorrowedOf(user);
    }

    function getRedeemableAmounts(address[] calldata users)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            if (!vibranium.isRedemptionProvider(users[i])) amounts[i] = 0;
            amounts[i] = vibranium.getBorrowedOf(users[i]);
        }
    }

    function getLiquidateFund(address user)
        external
        view
        returns (uint256 vusdAmount)
    {
        uint256 appro = vibranium.allowance(user, address(vibranium));
        if (appro == 0) return 0;
        uint256 bal = vibranium.balanceOf(user);
        vusdAmount = appro > bal ? bal : appro;
    }

    function getWithdrawableAmount(address user)
        external
        view
        returns (uint256)
    {
        if (vibranium.getBorrowedOf(user) == 0) return vibranium.depositedEther(user);
        if (getCollateralRate(user) <= 160 * 1e18) return 0;
        return
            (vibranium.depositedEther(user) *
                (getCollateralRate(user) - 160 * 1e18)) /
            getCollateralRate(user);
    }

    function getVusdMintableAmount(address user)
        external
        view
        returns (uint256 vusdAmount)
    {
        if (getCollateralRate(user) <= 160 * 1e18) return 0;
        return
            (vibranium.depositedEther(user) * getEtherPrice()) /
            1e6 /
            160 -
            vibranium.getBorrowedOf(user);
    }

    function getStakingPoolAPR(
        address poolAddress,
        address vib,
        address lpToken
    ) external view returns (uint256 apr) {
        uint256 pool_lp_stake = IERC20(poolAddress).totalSupply();
        uint256 rewardRate = IStakingRewards(poolAddress).rewardRate();
        uint256 lp_vib_amount = IERC20(vib).balanceOf(lpToken);
        uint256 lp_total_supply = IERC20(lpToken).totalSupply();
        apr =
            (lp_total_supply * rewardRate * 86400 * 365 * 1e6) /
            (pool_lp_stake * lp_vib_amount * 2);
    }

    function getTokenPrice(address token, address UniPool, address wethAddress) external view returns (uint256 price) {
        uint256 token_in_pool = IERC20(token).balanceOf(UniPool);
        uint256 weth_in_pool = IERC20(wethAddress).balanceOf(UniPool);
        price = weth_in_pool * getEtherPrice() * 1e10 / token_in_pool;
    }
}