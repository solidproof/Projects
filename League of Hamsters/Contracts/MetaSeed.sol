// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract MetaSeed is Initializable, ERC20Upgradeable, ERC20CappedUpgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address=>bool) public whitelist;
    mapping(address=>bool) public blocklist;

    bool public paused;

    modifier notBlocked(address _recipient) {
        require(!blocklist[_msgSender()] && !blocklist[_recipient], "You are in blocklist");
        _;
    }

    /// @notice allows transfer only for whitelisted users while paused
    modifier pausable(address _recipient) {
        if (paused) {
            require(whitelist[_msgSender()] || whitelist[_recipient], "Only whitelisted users can transfer while token paused!");
        }
        _;
    }

    constructor() initializer {
    }

    function initialize() public initializer {
        __ERC20_init("Metaseed", "METASEED");
        __ERC20Capped_init(2000000000*10**18);
        __ERC20Burnable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
    }

    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function _mint(address _to, uint256 _amount) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._mint(_to, _amount);
    }

    function _beforeTokenTransfer(address _from, address _to, uint256 _amount)
        internal
        notBlocked(_to)
        pausable(_to)
        override
    {
        super._beforeTokenTransfer(_from, _to, _amount);
    }

    /// @notice sets pause state (eg for initial adding liquidity)
    /// @param _state pause state
    function setPause(bool _state) public onlyRole(ADMIN_ROLE) {
        paused = _state;
    }

    /// @notice set user whitelist status
    /// @param _user address of user
    /// @param _state user status
    function setWhiteStatus(address _user, bool _state) public onlyRole(ADMIN_ROLE) {
        whitelist[_user] = _state;
    }

    /// @notice set user blocklist status
    /// @param _user address of user
    /// @param _state user status
    function setBlockStatus(address _user, bool _state) public onlyRole(ADMIN_ROLE) {
        blocklist[_user] = _state;
    }


    /// @notice unlock accidentally sent tokens on contract address
    /// @param _token address of locked tokens
    /// @param _to recipient address
    /// @param _amount amount of tokens
    function unlockERC20(address _token, address _to, uint256 _amount) public onlyRole(ADMIN_ROLE) {
        IERC20Upgradeable(_token).transfer(_to, _amount);
    }
}