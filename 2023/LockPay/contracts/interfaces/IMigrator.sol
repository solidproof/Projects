pragma solidity ^0.8.0;

interface IMigrator {
    function migrate(address token, uint256 sharesDeposited, uint256 sharesWithdrawn, uint256 startEmission, uint256 endEmission, uint256 lockID, address owner, address condition, uint256 amountInTokens, uint256 option) external returns (bool);
}
