// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Fixed Ratio Changeblock token.
/// @author Theo Dale & Peter Whitby.
/// @notice CBLKFixed tokens represents a share of an underlying index of CBTs.
contract CBLKFixed is ERC20 {
    // -------------------------------- STATE VARIABLES --------------------------------

    /// @notice The in order addresses of the CBLKFixed's underlying CBT tokens.
    address[] public climateBackedTonnes;

    /// @notice The in order ratio shares of each consituent CBT token.
    uint256[] public ratios;

    /// @notice the number of tokens in the CBLK
    uint256 public numTokens;

    /// @notice The balances of the CBLKs underlying CBTs.
    mapping(address => uint256) public balances;

    // Denominator for ratio share calculations.
    uint256 immutable ratioSum;

    // -------------------------------- EVENTS --------------------------------

    /// @notice CBT to CBLKFixed conversion.
    /// @param depositor The account depositing the CBTs.
    /// @param amounts In order amounts of CBT deposited.
    event Deposit(address indexed depositor, uint256[] amounts);

    /// @notice CBLK to CBT conversion.
    /// @param withdrawer The account redeeming their CBLKFixed.
    /// @param amount Amount of CBLKFixed converted.
    event Withdrawal(address indexed withdrawer, uint256 amount);

    // -------------------------------- CONSTRUCTOR --------------------------------

    /// @notice Contract constructor.
    /// @dev Establish underlying tokens and their ratio shares.
    /// @param name Name of CBLK.
    /// @param symbol Symbol of CBLK.
    /// @param tokens In order addresses of constituent underlying CBTs.
    /// @param ratios_ In order ratio shares of constituent underlying CBTs.
    constructor(
        string memory name,
        string memory symbol,
        address[] memory tokens,
        uint256[] memory ratios_
    ) ERC20(name, symbol) {
        climateBackedTonnes = tokens;
        ratios = ratios_;
        uint256 ratioSum_ = 0;
        for (uint256 i = 0; i < ratios_.length; i++) {
            ratioSum_ += ratios_[i];
        }
        ratioSum = ratioSum_;
        numTokens = tokens.length;
    }

    // -------------------------------- METHODS --------------------------------

    /// @notice Deposit CBTs in established ratio and gain CBLKFixed.
    /// @dev CBT approval required for the CBLKFixed contract.
    /// @param amounts The in order CBT amounts to deposit.
    function deposit(uint256[] memory amounts) public {
        uint256 total = amounts[0];
        uint256[] memory ratios_ = ratios;
        for (uint256 i = 1; i < ratios_.length; i++) {
            require(
                amounts[i] * ratios_[i - 1] == ratios_[i] * amounts[i - 1],
                'Incorrect ratio of deposited amounts'
            );
            total += amounts[i];
        }
        for (uint256 i = 0; i < ratios_.length; i++) {
            address token = climateBackedTonnes[i];
            IERC20(token).transferFrom(msg.sender, address(this), amounts[i]);
            balances[token] += amounts[i];
        }
        _mint(msg.sender, total);
        emit Deposit(msg.sender, amounts);
    }

    /// @notice Swap CBLKFixed into its underlying CBTs
    /// @dev Burns CBLKFixed from the callers wallet.
    /// @param amount The amount of CBLKFixed to be converted into underlying CBTs.
    function withdraw(uint256 amount) public {
        uint256 l = climateBackedTonnes.length;
        if (amount == totalSupply()) {
            for (uint256 i = 0; i < l; i++) {
                address token = climateBackedTonnes[i];
                IERC20(token).transfer(msg.sender, balances[token]);
                delete balances[token];
            }
        } else {
            for (uint256 i = 0; i < l; i++) {
                uint256 withdrawal = (amount * ratios[i]) / ratioSum;
                address token = climateBackedTonnes[i];
                IERC20(token).transfer(msg.sender, withdrawal);
                balances[token] -= withdrawal;
            }
        }
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }
}
