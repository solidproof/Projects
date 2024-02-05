//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface IStakingManager {
    function getVotingPower(address _voter) external view returns (uint);
    function stake(uint _amount) external;
    function unstake(uint _amount) external;
    function withdraw() external;
    function getMaxPurchaseAmount(uint _idoId, address _user) external view returns (uint);
    function receiveReward(uint _amount) external;
}
