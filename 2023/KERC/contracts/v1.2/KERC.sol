// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import { // prettier-ignore
    ERC20, ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import { // prettier-ignore
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../vesting/Vesting.sol";

/// @title The KERC token
/// @author snorkypie
contract KERC is ERC20, ERC20Permit, ERC20Burnable {
    address public teamVesting;

    /// Read more about token allocations here:
    /// https://kerc.gitbook.io/kerc/tokenomics/usdkerc-token
    constructor(
        address _multisig, address _team
    ) ERC20("KERC Token", "KERC") ERC20Permit("KERC Token") {
        require(_multisig != address(0), "ERR:ZERO:MULTISIG");
        require(_team != address(0), "ERR:ZERO:TEAM");

        /// @dev Shorthand for 1M tokens
        uint256 million = 10 ** decimals() * 1e6;

        /// @notice Total tokens to mint
        uint256 mintTokens = 500 * million;

        /// @notice 40M team + 10M advisory
        uint256 teamTokens = 50 * million;

        /// @notice Set up team vesting (40M team + 10M advisory)
        teamVesting = address(new KercVesting(_team, address(this), teamTokens));

        /// @notice Mint vesting tokens
        _mint(teamVesting, teamTokens);

        /// @notice Mint all non-team project tokens into our token multisig
        _mint(_multisig, mintTokens - teamTokens);

        /// @notice Check that we mint the right number of tokens
        require(totalSupply() == mintTokens, "ERR:TOTAL_SUPPLY");
    }
}