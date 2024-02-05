// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LBM is ERC20 {
    constructor(
        address treasuryReserve, // Treasury Wallet
        address coreTeam, // Vesting Wallet
        address presaleExchange, // Presale Exchange Wallet (sent to presale exchange contract after)
        address cexListing, // CEX Listing Wallet
        address liquidity, // Liquidity Wallet
        address stakingRewards, // Staking Rewards Wallet (sent to staking contract after)
        address ambassadorProgram, // Vesting Wallet
        address marketing, // Vesting Wallet
        address airdrop, // Vesting Wallet
        address advisors, // Vesting Wallet
        address projectDevelopment, // Project Development Wallet
        address privateInvestment // Vesting Wallet
    ) ERC20("Libertum", "LBM") {
        _mint(treasuryReserve, 70_000_000 * 10 ** decimals());
        _mint(coreTeam, 50_000_000 * 10 ** decimals());
        _mint(presaleExchange, 12_000_000 * 10 ** decimals());
        _mint(cexListing, 20_000_000 * 10 ** decimals());
        _mint(liquidity, 2_000_000 * 10 ** decimals());
        _mint(stakingRewards, 8_000_000 * 10 ** decimals());
        _mint(ambassadorProgram, 6_000_000 * 10 ** decimals());
        _mint(marketing, 4_000_000 * 10 ** decimals());
        _mint(airdrop, 2_000_000 * 10 ** decimals());
        _mint(advisors, 2_000_000 * 10 ** decimals());
        _mint(projectDevelopment, 4_000_000 * 10 ** decimals());
        _mint(privateInvestment, 20_000_000 * 10 ** decimals());
    }
}
