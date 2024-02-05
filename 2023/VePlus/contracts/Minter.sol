// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./libraries/Math.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IRewardsDistributor.sol";
import "./interfaces/IVePlus.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 7 days; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant EMISSION = 990; // @audit-info - uint to uint256
    uint internal constant TAIL_EMISSION = 2;
    uint internal constant PRECISION = 1000;
    uint public constant TEAM_RATE = 20; // 2%
    IVePlus public immutable vep;
    IVoter public immutable voter;
    IVotingEscrow public immutable ve;
    IRewardsDistributor public immutable rewardsDistributor;
    uint public weekly = 2_600_000 * 1e18; // represents a starting weekly emission of 2.6M VEP (VEP has 18 decimals)
    uint public active_period;
    uint internal constant LOCK = WEEK * 52 * 2;
    uint internal constant MAX = 50 * 1e6 * 1e18;

    address internal initializer;
    address public team;
    address public governor;

    event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);

    constructor(
        address _voter, // the voting & distribution system
        address _ve, // the ve(3,3) system that will be locked into
        address _rewardsDistributor, // the distribution system that ensures users aren't diluted
        address _team,
        address _governor
    ) {
        initializer = msg.sender;
        team = _team;
        governor = _governor;
        vep = IVePlus(IVotingEscrow(_ve).token());
        voter = IVoter(_voter);
        ve = IVotingEscrow(_ve);
        rewardsDistributor = IRewardsDistributor(_rewardsDistributor);
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    // TOTAL 50M VEP in tokenomics
    // 5M TreeNFT airdrop (community)
    // 10M Community airdrop (community)
    // 9M Grants
    // 2.5M Marketing
    // 2M Genesis liquidity
    // 12.5M for 25 Protocols -> veVEP locked 2 years
    // 9M for Team -> veVEP locked 2 years
    function initialize(address community, address treasury) external {
        require(initializer == msg.sender); // @audit-info - missing message
        vep.mint(address(this), MAX);
        vep.approve(address(ve), MAX);

        require(vep.transfer(community, 15 * 1e6 * 1e18));
        require(vep.transfer(treasury, 13_500_000 * 1e18));
        for (uint i = 0; i < 25; i++) {
            ve.create_lock_for(500_000 * 1e18, LOCK, treasury);
        }
        ve.create_lock_for(9 * 1e6 * 1e18, LOCK, team);

        initializer = address(0);
        active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions THIS Thursday
    }

    function setTeam(address _team) external {
        require(msg.sender == governor, "not team");
        team = _team;
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return vep.totalSupply() - ve.totalSupply();
    }

    // emission calculation is 1% of available supply to mint adjusted by circulating / total supply
    function calculate_emission() public view returns (uint) {
        return (weekly * EMISSION) / PRECISION;
    }

    // weekly emission takes the max of calculated (aka target) emission versus circulating tail end emission
    function weekly_emission() public view returns (uint) {
        return Math.max(calculate_emission(), circulating_emission());
    }

    // calculates tail end (infinity) emissions as 0.2% of total supply
    function circulating_emission() public view returns (uint) {
        return (circulating_supply() * TAIL_EMISSION) / PRECISION;
    }

    // calculate inflation and adjust ve balances accordingly
    function calculate_growth(uint _minted) public view returns (uint) {
        uint veTotal = ve.totalSupply();
        uint vepTotal = vep.totalSupply();
        return
            (((((_minted * veTotal) / vepTotal) * veTotal) / vepTotal) *
                veTotal) /
            vepTotal /
            2;
    }

    // update period can only be called once per cycle (1 week)
    function update_period() external returns (uint) {
        uint _period = active_period;
        if (block.timestamp >= _period + WEEK && initializer == address(0)) { // only trigger if new week
            _period = (block.timestamp / WEEK) * WEEK;
            active_period = _period;
            weekly = weekly_emission();

            uint _growth = calculate_growth(weekly);
            uint _teamEmissions = (TEAM_RATE * (_growth + weekly)) /
                (PRECISION - TEAM_RATE);
            uint _required = _growth + weekly + _teamEmissions;
            uint _balanceOf = vep.balanceOf(address(this));
            if (_balanceOf < _required) {
                vep.mint(address(this), _required - _balanceOf);
            }

            require(vep.transfer(team, _teamEmissions));
            require(vep.transfer(address(rewardsDistributor), _growth));
            rewardsDistributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            rewardsDistributor.checkpoint_total_supply(); // checkpoint supply

            vep.approve(address(voter), weekly);
            voter.notifyRewardAmount(weekly);

            emit Mint(msg.sender, weekly, circulating_supply(), circulating_emission());
        }
        return _period;
    }
}