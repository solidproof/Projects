# Dracula Finance

## https://solidlizard.gitbook.io/solidlizard/security/contracts (fork)

## https://dracula-1.gitbook.io/draculafi/ (doc draculaFi)

## Bribe Bond

The BribeBond feature allows users to bribe all veFANG voters with a stablecoin (here USDC).
All the USDC deposited for the epoch N will be redistributed in function of the gauges weight and the share votes for each veFang NFTs.
This feature is limited by default at 0.5% of the FANG circulating supply per day.
veFANG NFTs created by the bribeBond are different from the locked ones, the amount of USDC deposited is converted into a FANG amount (via the rate of the pool FANG/USDC), then the amount of veFANG is calculated via an equivalent of a maximum lock (4 years) plus a bonus of 15%.
Users can simply votes with this type of NFTs, they cannot merge, redeposit and withdraw with it (because there is no FANG deposited in the ve contract).
The gauges weight will be snapshoted at the end of an epoch (snapshot will be available 4 hours before the end exactly), anyone can trigger the snapshot when it's possible. Then users can update the period when the snapshot is finished. When the epoch N+1 is updated, all voters from the epoch N can claim USDC in function of their votes share. But if an user can claim for epoch N and he infortunately votes at the epoch N+1 before, he will lose all his claimable rewards. It's important to know that only voters who has voted at the previous epoch can claim, if the last vote is below or above he cannot claim at all.
All USDC unclaimed will be redistributed and will be claimable at the next epoch.

During the process of the snapshot, votes, deposits and claim bonds are locked. Also between the end of snapshot and the update period deposits and bonds are locked too.

### Global

#### Dex

- DraculaFactory: 104
- DraculaPair: 831
- DraculaRouter: 892
- PairFees: 40
- SwapLibrary: 394

#### Gauges

- Bribe: 95
- BribeFactory: 23
- Gauge: 165
- GaugeFactory: 41
- MultiRewardsPoolBase:599

#### Token

- Dracula: 100

#### Ve

- BribeBond: 151
- DraculaMinter: 214
- DraculaVoter: 723
- Ve: 1155
- VeDist: 413
- VeLogo: 104

#### Others

- Controller: 46
- GovernanceTreasury: 40
- Multicall: 68
- Reeantrancy: 15

#### TOTAL

- LoC: 6213

### Scope (about bribeBond feature)

- BribeBond: 151
- DraculaVoter: 723
- Ve: 1155

- TotalScope: 2029
