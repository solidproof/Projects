// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import 'hardhat/console.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @title Unfixed Ratio Changeblock token.
/// @author Theo Dale & Peter Whitby.
/// @notice CBLKUnfixed tokens represents a share of an index of CBTs curated by an owner.
contract CBLKUnfixed is ERC20, Ownable {
    // -------------------------------- STATE VARIABLES --------------------------------

    /// @notice The balances of the CBLK's underlying CBTs.
    mapping(address => uint256) public balances;

    /// @notice the number of tokens in the CBLK
    uint256 public numTokens;

    /// @notice The addresses of the CBLKs underlying CBT tokens.
    address[] public climateBackedTonnes;

    // Maps CBT to their index in climateBackedTonnes array.
    mapping(address => uint256) indexes;

    // -------------------------------- EVENTS --------------------------------

    /// @notice Chage in the underlying CBT distribtion.
    /// @param inputTokens The addresses of the deposited CBTs in order.
    /// @param inputAmounts In order CBT additions.
    /// @param outputTokens The addresses of the removed CBTs in order.
    /// @param outputAmounts In order CBT removal.
    event Rebalance(
        address[] inputTokens,
        uint256[] inputAmounts,
        address[] outputTokens,
        uint256[] outputAmounts
    );

    /// @notice CBLK to underlying CBT conversion.
    /// @param withdrawer The account redeeming their CBLK.
    /// @param amounts In order amounts of CBT withdrawn.
    event Withdrawal(address indexed withdrawer, uint256[] amounts);

    // -------------------------------- CONSTRUCTOR --------------------------------

    /// @dev Follow CBLK naming conventions.
    /// @param name Name of CBLK.
    /// @param symbol Symbol of CBLK.
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // -------------------------------- METHODS --------------------------------

    /// @notice Add or remove CBTs to the CBLK's underlying tokens.
    /// @param inputTokens In order addresses of the CBTs to add.
    /// @param inputAmounts In order amounts to add.
    /// @param outputTokens In order addresses of the CBTs to remove.
    /// @param outputAmounts In order amounts to remove.
    function rebalance(
        address[] calldata inputTokens,
        uint256[] calldata inputAmounts,
        address[] calldata outputTokens,
        uint256[] calldata outputAmounts
    ) external onlyOwner {
        uint256 totalInput = 0;
        for (uint256 i = 0; i < inputTokens.length; i++) {
            if (balances[inputTokens[i]] == 0) {
                indexes[inputTokens[i]] == climateBackedTonnes.length;
                climateBackedTonnes.push(inputTokens[i]);
            }
            IERC20(inputTokens[i]).transferFrom(msg.sender, address(this), inputAmounts[i]);
            balances[inputTokens[i]] += inputAmounts[i];
            totalInput += inputAmounts[i];
        }
        uint256 totalOutput = 0;
        for (uint256 i = 0; i < outputTokens.length; i++) {
            IERC20(outputTokens[i]).transfer(msg.sender, outputAmounts[i]);
            balances[outputTokens[i]] -= outputAmounts[i];
            if (balances[outputTokens[i]] == 0) {
                _unregisterToken(outputTokens[i]);
            }
            totalOutput += outputAmounts[i];
        }
        if (totalOutput > totalInput) {
            _burn(msg.sender, totalOutput - totalInput);
        } else if (totalInput > totalOutput) {
            _mint(msg.sender, totalInput - totalOutput);
        }

        numTokens = outputTokens.length;
        emit Rebalance(inputTokens, inputAmounts, outputTokens, outputAmounts);
    }

    /// @notice Convert an amount of CBLK into pro-rata amounts of its current underlying tokens.
    /// @dev Burns withdrawn CBLK directly from the converter's wallet.
    /// @param amount The amount of CBLK to convert.
    function withdraw(uint256 amount) public {
        address[] memory climateBackedTonnes_ = climateBackedTonnes;
        uint256[] memory withdrawals = new uint256[](climateBackedTonnes_.length);
        uint256 supply = totalSupply();
        for (uint256 i = 0; i < climateBackedTonnes_.length; i++) {
            address token = climateBackedTonnes_[i];
            uint256 balance = balances[climateBackedTonnes_[i]];
            uint256 withdrawal = (balance * amount) / supply;
            withdrawals[i] = withdrawal;
            IERC20(token).transfer(msg.sender, withdrawal);
            balances[token] -= withdrawal;
            if (balance == withdrawal) {
                _unregisterToken(token);
            }
        }
        _burn(msg.sender, amount);
        emit Withdrawal(msg.sender, withdrawals);
    }

    // Removes a token from climateBackedTonnes and indexes.
    function _unregisterToken(address token) internal {
        climateBackedTonnes[indexes[token]] = climateBackedTonnes[climateBackedTonnes.length - 1];
        climateBackedTonnes.pop();
    }
}
