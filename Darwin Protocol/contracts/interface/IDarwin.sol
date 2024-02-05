pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

import {IStakedDarwin} from "./IStakedDarwin.sol";

interface IDarwin {

    /// @notice Accumulatively log sold tokens
    struct TokenSellLog {
        uint40 lastSale;
        uint216 amount;
    }

    event ExcludedFromReflection(address account, bool isExcluded);
    event ExcludedFromSellLimit(address account, bool isExcluded);

    // PUBLIC
    function distributeRewards(uint256 amount) external;
    function bulkTransfer(address[] calldata recipients, uint256[] calldata amounts) external;

    // COMMUNITY
    // function upgradeTo(address newImplementation) external; RESTRICTED
    // function upgradeToAndCall(address newImplementation, bytes memory data) external payable; RESTRICTED
    function setMinter(address user_, bool canMint_) external; // RESTRICTED
    function setMaintenance(address _addr, bool _hasRole) external; // RESTRICTED
    function setSecurity(address _addr, bool _hasRole) external; // RESTRICTED
    function setUpgrader(address _account, bool _hasRole) external; // RESTRICTED
    function setReceiveRewards(address account, bool shouldReceive) external; // RESTRICTED
    function communityPause() external; // RESTRICTED
    function communityUnPause() external;

    // FACTORY
    function registerDarwinSwapPair(address _pair) external;

    // MAINTENANCE
    function setDarwinSwapFactory(address _darwinSwapFactory) external;
    function setPauseWhitelist(address _addr, bool value) external;
    function setPresaleAddress(address _addr) external;
    function setLive() external;

    // SECURITY
    function emergencyPause() external;
    function emergencyUnPause() external;

    // MINTER
    function mint(address account, uint256 amount) external;

    // VIEW
    function isPaused() external view returns (bool);
    function stakedDarwin() external view returns(IStakedDarwin);
    function MAX_SUPPLY() external pure returns(uint256);

    /// TransferFrom amount is greater than allowance
    error InsufficientAllowance();
    /// Only the DarwinCommunity can call this function
    error OnlyDarwinCommunity();

    /// Input cannot be the zero address
    error ZeroAddress();
    /// Amount cannot be 0
    error ZeroAmount();
    /// Arrays must be the same length
    error InvalidArrayLengths();

    /// Holding limit exceeded
    error HoldingLimitExceeded();
    /// Sell limit exceeded
    error SellLimitExceeded();
    /// Paused
    error Paused();
    error AccountAlreadyExcluded();
    error AccountNotExcluded();

    /// Max supply reached, cannot mint more Darwin
    error MaxSupplyReached();
}
