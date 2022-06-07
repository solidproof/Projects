interface IAutoCompound {
    function deposit(uint256 _amount) external;

    function withdrawAll() external;

    function harvest() external;

    function calculateHarvestRewards() external view returns (uint256);

    function calculateTotalPendingRewards() external view returns (uint256);

    function getPricePerFullShare() external view returns (uint256);

    function withdraw(uint256 _shares) external;

    function available() external view returns (uint256);

    function balanceOf() external view returns (uint256);
}
