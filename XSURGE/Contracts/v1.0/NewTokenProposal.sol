//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IXUSD {
    function addStable(address stable) external;
}

contract NewTokenProposal {

    // most recent token proposed
    address public pendingStableToken;

    // time token was proposed
    uint256 public proposedTimestamp;

    // wait time for proposition approval
    uint256 public constant propositionWaitTime = 400000; // 14 day approval period

    // XUSD Token
    address public XUSD;

    // owner
    address public owner;
    modifier onlyOwner(){
        require(msg.sender == owner, 'Only Owner');
        _;
    }

    // Events
    event StableProposed(address stable);
    event StableApproved(address stable);

    constructor(){
        proposedTimestamp = block.number;
        owner = msg.sender;
    }

    function approvePendingStable() external onlyOwner {
        require(pendingStableToken != address(0), 'Invalid Stable');
        require(proposedTimestamp + propositionWaitTime <= block.number, 'Insufficient Time Has Passed');

        // add stable to XUSD
        IXUSD(XUSD).addStable(pendingStableToken);
        emit StableApproved(pendingStableToken);

        // clear up data
        pendingStableToken = address(0);
        proposedTimestamp = block.number;
    }

    function proposeStable(address stable) external onlyOwner {
        require(stable != address(0));
        require(IERC20(stable).decimals() == 18);

        pendingStableToken = stable;
        proposedTimestamp = block.number;

        emit StableProposed(stable);
    }

    function pairXUSD(address XUSD_) external onlyOwner {
        require(
            XUSD == address(0) &&
            XUSD_ != address(0),
            'token paired'
        );
        XUSD = XUSD_;
    }

    function changeOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}