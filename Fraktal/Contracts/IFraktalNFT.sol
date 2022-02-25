//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFraktalNFT {
    function fraktionalize(address _to, uint _tokenId) external;
    function setMajority(uint16 newValue) external;
    function defraktionalize() external;
    function soldBurn(address owner, uint256 _tokenId, uint256 bal) external;
    function lockSharesTransfer(address from, uint numShares, address _to) external;
    function unlockSharesTransfer(address from, address _to) external;
    function createRevenuePayment() external returns (address _clone);
    function sellItem() external;
    function cleanUpHolders() external;
    function getRevenue(uint256 index) external view returns(address);
    function getFraktions(address who) external view returns(uint);
    function getLockedShares(uint256 index, address who) external view returns(uint);
    function getLockedToTotal(uint256 index, address who) external view returns(uint);
    function getStatus() external view returns (bool);
    function getFraktionsIndex() external view returns (uint256);
}
