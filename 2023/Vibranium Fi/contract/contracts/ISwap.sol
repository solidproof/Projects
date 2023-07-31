pragma solidity 0.8.17;

interface ISwap {
    function mintSwap(address _account, uint _amount) external;
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
