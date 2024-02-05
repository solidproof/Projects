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
    address public partnerVesting;

    /// Read more about token allocations here:
    /// https://kerc.gitbook.io/kerc/tokenomics/usdkerc-token
    constructor(
        address _ecosystem,
        address _operations,
        address _reserves,
        address _vTeam,
        address _vPartner,
        uint256 _vPartnerTokens
    ) ERC20("KERC Token", "KERC") ERC20Permit("KERC Token") {
        require(_ecosystem != address(0), "ERR:ZERO:ECO");
        require(_operations != address(0), "ERR:ZERO:OPERATIONS");
        require(_reserves != address(0), "ERR:ZERO:RESERVES");
        require(_vTeam != address(0), "ERR:ZERO:vTEAM");
        require(_vPartner != address(0), "ERR:ZERO:vPARTNER");

        uint256 million = 10 ** decimals() * 1e6;

        address token = address(this);

        _vPartnerTokens *= 1 ether;
        uint256 reserveTokens = 25 * million - _vPartnerTokens;
        uint256 teamTokens = 50 * million; /// @notice 40M team + 10M advisory

        /// @notice Set up vesting contracts
        teamVesting = address(new KercVesting(_vTeam, token, teamTokens));
        partnerVesting = address(new KercVesting(_vPartner, token, _vPartnerTokens));

        /// @notice Mint project tokens
        _mint(_ecosystem, 350 * million);
        _mint(_operations, 75 * million);
        _mint(_reserves, reserveTokens);

        /// @notice Mint vesting tokens
        _mint(teamVesting, teamTokens);
        _mint(partnerVesting, _vPartnerTokens);

        require(totalSupply() == 500 * million, "ERR:TOTAL_SUPPLY");
    }
}
