// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./Math.sol";
import "./IMinter.sol";
import "./IRewardsDistributor.sol";
import "./IAuragi.sol";
import "./IVoter.sol";
import "./IVotingEscrow.sol";

// codifies the minting rules as per ve(3,3), abstracted from the token to support any token that allows minting

contract Minter is IMinter {
    uint internal constant WEEK = 86400 * 7; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant EMISSION = 990;
    uint internal constant TAIL_EMISSION = 2;
    uint internal constant PRECISION = 1000;
    uint public constant TEAM_RATE = 30; // 3%
    IAuragi public immutable _agi;
    IVoter public immutable _voter;
    IVotingEscrow public immutable _ve;
    IRewardsDistributor public immutable _rewards_distributor;
    uint public weekly = 15_000_000 * 1e18; // represents a starting weekly emission of 15M AURI (AURI has 18 decimals)
    uint public active_period;
    uint internal constant LOCK = 86400 * 7 * 52 * 4;
    uint internal constant MAX = 78 * 1e6 * 1e18;

    address internal initializer;
    address public team;
    address public governor;

    event Mint(address indexed sender, uint weekly, uint circulating_supply, uint circulating_emission);

    constructor(
        address __voter, // the voting & distribution system
        address __ve, // the ve(3,3) system that will be locked into
        address __rewards_distributor, // the distribution system that ensures users aren't diluted
        address _team,
        address _governor
    ) {
        initializer = msg.sender;
        team = _team;
        governor = _governor;
        _agi = IAuragi(IVotingEscrow(__ve).token());
        _voter = IVoter(__voter);
        _ve = IVotingEscrow(__ve);
        _rewards_distributor = IRewardsDistributor(__rewards_distributor);
        active_period = ((block.timestamp + (2 * WEEK)) / WEEK) * WEEK;
    }

    //  48M for Partnership lock veNFT 4 years
    //  20M for Arbitrum lock veNFT 4 years
    //  10 for Team lock veNFT 4 years
    function initialize(
        address[] memory claimants,
        uint[] memory amounts
    ) external {
        require(initializer == msg.sender);
        _agi.mint(address(this), MAX);
        _agi.approve(address(_ve), MAX);

        for (uint i = 0; i < claimants.length; i++) {
            _ve.create_lock_for(amounts[i], LOCK, claimants[i]);
        }

        initializer = address(0);
        active_period = ((block.timestamp) / WEEK) * WEEK; // allow minter.update_period() to mint new emissions THIS Thursday
    }

    function setTeam(address _team) external {
        require(msg.sender == governor, "not team");
        team = _team;
    }

    // calculate circulating supply as total token supply - locked supply
    function circulating_supply() public view returns (uint) {
        return _agi.totalSupply() - _ve.totalSupply();
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
        uint _veTotal = _ve.totalSupply();
        uint _agiTotal = _agi.totalSupply();
        return
            (((((_minted * _veTotal) / _agiTotal) * _veTotal) / _agiTotal) *
                _veTotal) /
            _agiTotal /
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
            uint _balanceOf = _agi.balanceOf(address(this));
            if (_balanceOf < _required) {
                _agi.mint(address(this), _required - _balanceOf);
            }

            require(_agi.transfer(team, _teamEmissions));
            require(_agi.transfer(address(_rewards_distributor), _growth));
            _rewards_distributor.checkpoint_token(); // checkpoint token balance that was just minted in rewards distributor
            _rewards_distributor.checkpoint_total_supply(); // checkpoint supply

            _agi.approve(address(_voter), weekly);
            _voter.notifyRewardAmount(weekly);

            emit Mint(msg.sender, weekly, circulating_supply(), circulating_emission());
        }
        return _period;
    }
}