// contracts/NatureGold.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract NatureGold is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Define the supply of NatureGold: 388,793,750
    uint256 constant INITIAL_SUPPLY = 388793750 * (10**18);
    string public metadataURI;

    mapping(address => uint256) private _buyBlock;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the NatureGold contract
     */
    function initialize() public initializer {
        __ERC20_init("NatureGold", "NG");
        __AccessControl_init();
        __ERC20Permit_init("NatureGold");
        __ERC20Votes_init();
        __ReentrancyGuard_init();

        _mint(msg.sender, INITIAL_SUPPLY);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Sets the metadata URI.
     */
    function setMetadataURI(string memory uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        metadataURI = uri;
    }

    /**
     * @dev Anti-bot transfer function.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override nonReentrant {
        require(_buyBlock[sender] != block.number, "Bad bot!"); // Prevent transfers from addresses that made a purchase in this block

        _buyBlock[recipient] = block.number; // Record the block number of the purchase for the recipient
        uint256 currentNonce = _getNonce();
        uint256 randomDelay = uint256(
            keccak256(
                abi.encodePacked(blockhash(block.number - 1), currentNonce)
            )
        ) % 15;

        uint256 adjustedAmount = amount;

        if (randomDelay > 0) {
            adjustedAmount = adjustedAmount - 1; // Apply a small reduction to the transferred amount
        }

        super._transfer(sender, recipient, adjustedAmount);
    }

    /**
     * @dev Returns the current nonce.
     */
    function _getNonce() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - 1), msg.sender)
                )
            );
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }
}