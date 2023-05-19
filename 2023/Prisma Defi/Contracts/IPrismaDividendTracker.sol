// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPrismaDividendTracker {
  /**
   * @notice Sets the address for the token used for dividend payout
   * @dev This should be an ERC20 token
   */
  function setDividendTokenAddress(address newToken) external;

  /**
   * @notice Updates the minimum balance required to be eligible for dividends
   */
  function updateMinimumTokenBalanceForDividends(
    uint256 _newMinimumBalance
  ) external;

  /**
   * @dev Updates the amount of gas used to process dividends
   */
  function updateGasForProcessing(uint256 newValue) external;

  /**
   * @notice Makes an address ineligible for dividends
   * @dev Calls `_setBalance` and updates `tokenHoldersMap` iterable mapping
   */
  function excludeFromDividends(address account) external;

  /**
   * @notice Makes an address eligible for dividends
   */
  function includeFromDividends(address account) external;

  /**
   * @notice Returns the last processed index in the `tokenHoldersMap` iterable mapping
   * @return uint256 last processed index
   */
  function getLastProcessedIndex() external view returns (uint256);

  /**
   * @notice Returns the total number of dividend token holders
   * @return uint256 length of `tokenHoldersMap` iterable mapping
   */
  function getNumberOfTokenHolders() external view returns (uint256);

  /**
   * @notice Returns all available info about the dividend status of an account
   * @dev Uses the functions from the `IterableMapping.sol` library
   */
  function getAccount(
    address _account
  )
    external
    view
    returns (
      address account,
      int256 index,
      int256 iterationsUntilProcessed,
      uint256 withdrawableDividends,
      uint256 totalDividends
    );

  /**
   * @notice Returns all available info about the dividend status of an account using its index
   * @dev Uses the functions from the `IterableMapping.sol` library
   */
  function getAccountAtIndex(
    uint256 index
  ) external view returns (address, int256, int256, uint256, uint256);

  /**
   * @notice Sets the dividend balance of an account and processes its dividends
   * @dev Calls the `processAccount` function
   */
  function setBalance(address account, uint256 newBalance) external;

  /**
   * @dev Returns the amount of tokens owned by `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @notice Returns the total amount of dividends distributed by the contract
   *
   */
  function getTotalDividendsDistributed() external view returns (uint256);

  /**
   * @notice View the amount of dividend in wei that an address can withdraw.
   * @param account The address of a token holder.
   * @return The amount of dividend in wei that `account` can withdraw.
   */
  function withdrawableDividendOf(
    address account
  ) external view returns (uint256);

  function swapFees() external;
}