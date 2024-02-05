// SPDX-License-Identifier: UNLICENSED

//contracts/StakepoolStorage.sol

pragma solidity 0.8.16;

contract StakePoolStorage {
    // structs
    struct Tier {
        string name;
        address collection;
        uint256 stake;
        uint256 weight;
    }

    //===================Mapping & Arrays==================

    //map to store the alocpoints allocated to each staker
    mapping(address => uint256) internal allocPoints;

    //map to store the staking time of each staker
    mapping(address => uint256) internal timeLocks;

    //map to store the staking balance of each staker
    mapping(address => uint256) internal tokenBalances;

    //map to store nft owner of each nft
    mapping(address => mapping(uint256 => address)) internal nftOwners;

    //map to store nft balance of each staker
    mapping(address => mapping(address => uint256)) internal nftBalances;

    //map to store nft allocation points of each staker
    mapping(address => uint256) internal nftAllocPoints;

    //map to store promo allocs of each staker. promo allocs are the allocs given to the users by admin for free for a limited time period. They don't have to stake tokens or nfts to get these allocs
    mapping(address => uint256) internal promoAllocPoints;

    // Arrays

    //array to store all the tiers
    Tier[] internal tiers;

    //map to store the users who have staked
    address[] internal userAdresses;

    // =======================State Vars===================

    //variable to keep track of total allocpoints
    uint256 public totalAllocPoint;

    //variable to keep track of total collected fee
    uint256 public collectedFee;

    //variable to keep track of total no of tokens staked
    uint256 public totalStaked;

    //
    uint256 public totalStakedNft;

    //boolean representing whether the staking is paused or not
    bool public stakeOn;

    //boolean representing whether the withdraw is paused or not
    bool public withdrawOn;

    //helper var
    uint8 public decimals;

    //
    uint256 public maxStakeOrWithdrawNft;

    uint256 public minStakingAmount;

    ///@dev This is an upgradeable contract. This variable is used to avoid storage clashes while upgrading the contract. It 'll take next 50 slots from the storage
    uint256[50] private gap;
}