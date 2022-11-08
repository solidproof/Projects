// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol';
import './utils/BasicMetaTransaction.sol';

contract Mintlab is
  Initializable,
  ERC721Upgradeable,
  ERC721URIStorageUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  ERC721BurnableUpgradeable,
  UUPSUpgradeable,
  BasicMetaTransaction
{
  using CountersUpgradeable for CountersUpgradeable.Counter;

  bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
  CountersUpgradeable.Counter private _tokenIdCounter;
  bytes32 public constant UPGRADER_ROLE = keccak256('UPGRADER_ROLE');
  bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

  address public proxyManager;

  struct usersRoleInfo {
    string contractName;
    address contractAddr;
    bytes32 roleHash;
    string roleName;
    address user;
  }
  usersRoleInfo[] proxyUsersRole;
  mapping(bytes32 => string) public roleNames;
  mapping(bytes => uint256) encodedUserToProxyIndex;
  mapping(address => bool) public isBlackListedAddress;
  mapping(uint256 => bool) public isBlackListedTokenId;

  event AddressBlackListed(address caller, address _addr, bool _blackList);
  event TokenIdBlackListed(address caller, uint256 _tokenId, bool _blackList);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {}

  function initialize(
    string memory _name,
    string memory _symbol,
    address _proxyManager
  ) public initializer {
    __ERC721_init(_name, _symbol);
    __ERC721URIStorage_init();
    __Pausable_init();
    __AccessControl_init();
    __ERC721Burnable_init();
    __UUPSUpgradeable_init();

    proxyManager = _proxyManager;

    _grantRole(DEFAULT_ADMIN_ROLE, _proxyManager);
    _grantRole(ADMIN_ROLE, _proxyManager);

    _grantRole(PAUSER_ROLE, _proxyManager);
    _setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);

    _grantRole(UPGRADER_ROLE, _proxyManager);
    _setRoleAdmin(UPGRADER_ROLE, ADMIN_ROLE);

    _grantRole(MINTER_ROLE, msg.sender);
    _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);

    roleNames[DEFAULT_ADMIN_ROLE] = 'DEFAULT_ADMIN_ROLE';
    roleNames[ADMIN_ROLE] = 'ADMIN_ROLE';
    roleNames[PAUSER_ROLE] = 'PAUSER_ROLE';
    roleNames[UPGRADER_ROLE] = 'UPGRADER_ROLE';
    roleNames[MINTER_ROLE] = 'MINTER_ROLE';

    _pushRole(
      proxyUsersRole,
      name(),
      address(this),
      DEFAULT_ADMIN_ROLE,
      _proxyManager,
      0
    );
    _pushRole(
      proxyUsersRole,
      name(),
      address(this),
      ADMIN_ROLE,
      _proxyManager,
      1
    );
    _pushRole(
      proxyUsersRole,
      name(),
      address(this),
      PAUSER_ROLE,
      _proxyManager,
      2
    );
    _pushRole(
      proxyUsersRole,
      name(),
      address(this),
      UPGRADER_ROLE,
      _proxyManager,
      3
    );
    _pushRole(
      proxyUsersRole,
      name(),
      address(this),
      MINTER_ROLE,
      msg.sender,
      4
    );
  }

  function _pushRole(
    usersRoleInfo[] storage _arr,
    string memory _name,
    address addr,
    bytes32 _role,
    address _user,
    uint256 _index
  ) internal {
    _arr.push(usersRoleInfo(_name, addr, _role, roleNames[_role], _user));
    bytes memory encUser = abi.encode(
      _name,
      addr,
      _role,
      roleNames[_role],
      _user
    );
    encodedUserToProxyIndex[encUser] = _index;
  }

  function _popRole(
    usersRoleInfo[] storage _arr,
    string memory _name,
    address addr,
    bytes32 _role,
    address _user
  ) internal {
    uint256 index;
    bytes memory encLastUser = abi.encode(
      _arr[_arr.length - 1].contractName,
      _arr[_arr.length - 1].contractAddr,
      _arr[_arr.length - 1].roleHash,
      _arr[_arr.length - 1].roleName,
      _arr[_arr.length - 1].user
    );
    bytes memory encUser = abi.encode(
      _name,
      addr,
      _role,
      roleNames[_role],
      _user
    );
    index = encodedUserToProxyIndex[encUser];
    if (index == _arr.length - 1) {
      _arr.pop();
    } else {
      _arr[index] = _arr[_arr.length - 1];
      encodedUserToProxyIndex[encLastUser] = index;
      _arr.pop();
    }
  }

  function setProxyManager(address _proxyManager) public onlyRole(ADMIN_ROLE) {
    proxyManager = _proxyManager;
  }

  function getUserRoles()
    public
    view
    onlyRole(ADMIN_ROLE)
    returns (usersRoleInfo[] memory)
  {
    return proxyUsersRole;
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function safeMint(address to, string memory uri)
    public
    onlyRole(MINTER_ROLE)
  {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
  }

  function renounceRole(bytes32 role, address account) public override {
    require(
      account == _msgSender(),
      'AccessControl: can only renounce roles for self'
    );

    revert('Restricted: Cannot renounce roles');
  }

  function grantRole(bytes32 role, address account)
    public
    override
    onlyRole(getRoleAdmin(role))
  {
    if (role == DEFAULT_ADMIN_ROLE && _msgSender() != proxyManager) {
      revert('Restricted: Only ProxyManager can grant DEFAULT_ADMIN role');
    }

    if (!hasRole(role, account)) {
      _grantRole(role, account);

      _pushRole(
        proxyUsersRole,
        name(),
        address(this),
        role,
        account,
        proxyUsersRole.length
      );
    }
  }

  function revokeRole(bytes32 role, address account)
    public
    override
    onlyRole(getRoleAdmin(role))
  {
    if (role == DEFAULT_ADMIN_ROLE && account == proxyManager) {
      revert("Restricted: ProxyManager's DEFAULT_ADMIN role cannot be revoked");
    }
    if (role == ADMIN_ROLE && account == proxyManager) {
      revert("Restricted: ProxyManager's ADMIN role cannot be revoked");
    }

    if (hasRole(role, account)) {
      _revokeRole(role, account);

      _popRole(proxyUsersRole, name(), address(this), role, account);
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override whenNotPaused {
    if ((isBlackListedAddress[to] || isBlackListedAddress[from])) {
      revert('Restricted: Address is BlackListed');
    }
    require(
      isBlackListedTokenId[tokenId] == false,
      'Restricted: TokenId is BlackListed'
    );
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
  {}

  // The following functions are overrides required by Solidity.

  function _burn(uint256 tokenId)
    internal
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
  {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function _msgSender()
    internal
    view
    virtual
    override
    returns (address sender)
  {
    return msgSender();
  }

  function unApprove(uint256 tokenId) external {
    address owner = super.ownerOf(tokenId);

    require(
      _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      'ERC721: approve caller is not token owner or approved for all'
    );
    _approve(owner, tokenId);
  }

  function blackListAddress(address _addr, bool _blackList)
    public
    onlyRole(ADMIN_ROLE)
  {
    isBlackListedAddress[_addr] = _blackList;
    emit AddressBlackListed(msg.sender, _addr, _blackList);
  }

  function blackListTokenId(uint256 _tokenId, bool _blackList)
    public
    onlyRole(ADMIN_ROLE)
  {
    require(_exists(_tokenId), 'TokenId does not exists');
    isBlackListedTokenId[_tokenId] = _blackList;
    emit TokenIdBlackListed(msg.sender, _tokenId, _blackList);
  }
}
