// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IVoter {
    function ve() external view returns (address);
    function governor() external view returns (address);
    function gauges(address _pair) external view returns (address);
    function factory() external view returns (address);
    function minter() external view returns(address);
    function emergencyCouncil() external view returns (address);
    function attachTokenToGauge(uint _tokenId, address account) external;
    function detachTokenFromGauge(uint _tokenId, address account) external;
    function emitDeposit(uint _tokenId, address account, uint amount) external;
    function emitWithdraw(uint _tokenId, address account, uint amount) external;
    function isWhitelisted(address token) external view returns (bool);
    function notifyRewardAmount(uint amount) external;
    function distribute(address _gauge) external;
}