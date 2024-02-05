pragma solidity 0.8.17;

interface IPriceFeed {
    function fetchPrice() external returns (uint256);
}
