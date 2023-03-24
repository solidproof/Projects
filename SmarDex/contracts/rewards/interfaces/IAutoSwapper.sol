// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// interfaces
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../../core/interfaces/ISmardexFactory.sol";
import "../../core/interfaces/ISmardexSwapCallback.sol";

interface IAutoSwapper is ISmardexSwapCallback {
    /**
     * @notice public function for executing swaps on tokens and send them to staking contract will be called from a
     * Smardex Pair on mint and burn, and can be forced call by anyone
     * @param _token0 token to be converted to sdex
     * @param _token1 token to be converted to sdex
     */
    function executeWork(IERC20 _token0, IERC20 _token1) external;

    /**
     * @notice transfer SDEX from here to staking contract
     */
    function transferTokens() external;

    /**
     * @notice return the factory address
     * @return factory address
     */
    function factory() external view returns (ISmardexFactory);

    /**
     * @notice return the staking address
     * @return staking address
     */
    function stakingAddress() external view returns (address);

    /**
     * @notice return the smardexToken address
     * @return smardexToken address
     */
    function smardexToken() external view returns (IERC20);
}
