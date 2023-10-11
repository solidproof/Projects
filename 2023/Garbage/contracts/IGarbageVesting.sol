pragma solidity 0.8.18;

interface IGarbageVesting {
    function addAmountToBeneficiary(address _beneficiary, uint256 _amount) external;
}
