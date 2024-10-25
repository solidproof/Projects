// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

/// @title Governance token for Deelit Protocol
/// @author d0x4545lit
/// @custom:security-contact dev@deelit.net
/// @dev    ERC20 with additional functionality:
///         * AccessManaged - access control for minting
///         * Permit - single step transfers via sig
///         * Votes - delegation and voting compatible with OZ governance (using timestamp duration)
///         * Burnable - user's can burn their own tokens. Can be used by the airdrop distributor
///             after the claim period ends
contract DeeToken is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, AccessManagedUpgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable, UUPSUpgradeable {
    string private constant NAME = "DeeToken";
    string private constant SYMBOL = "DEE";

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Contract initializer
     * @param initialAuthority The initial authority (AccessManager)
     */
    function initialize(address initialAuthority) public initializer {
        __ERC20_init(NAME, SYMBOL);
        __ERC20Burnable_init();
        __AccessManaged_init(initialAuthority);
        __ERC20Permit_init(NAME);
        __ERC20Votes_init();
        __UUPSUpgradeable_init();

        // mint initial supply to the initial authority
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    /**
     * @dev Overrides IERC6372 functions to make the token & governor timestamp-based
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @inheritdoc UUPSUpgradeable
     */
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    // The following functions are overrides required by Solidity.

    /**
     * @inheritdoc ERC20Upgradeable
     */
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(from, to, value);
    }

    /**
     * @inheritdoc ERC20PermitUpgradeable
     */
    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}