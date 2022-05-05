//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface ITreasury {
    function contributions(address _contributor) external view returns (uint);

    function claimed(address _contributor) external view returns (uint);

    function refunded(address _contributor) external view returns (uint);

    function contributed() external view returns (uint);

    function contribute(address _contributor, uint _amount) external payable;

    function claim(address _recipient) external;

    function refund(address _recipient) external;

    function addToLP(uint _tokenAmount, uint _bnbAmount) external;

    function transferDevRewards() external;

    function transferStakingRewards() external;
}
