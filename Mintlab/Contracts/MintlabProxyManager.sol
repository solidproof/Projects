// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;



import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';

interface NFT {
  function pause() external;

  function unpause() external;

  function paused() external returns (bool);

  function DEFAULT_ADMIN_ROLE() external returns (bytes32);

  function proxyManager() external returns (address);

  function setProxyManager(address _proxyManager) external;

  struct usersRoleInfo {
    string contractName;
    address contractAddr;
    bytes32 roleHash;
    string roleName;
    address user;
  }

  function getUserRoles() external view returns (usersRoleInfo[] memory);

  function blackListAddress(address _addr, bool _blackList) external;

  function blackListTokenId(uint256 _tokenId, bool _blackList) external;
}

contract MintlabProxyManager is
  Initializable,
  AccessControlUpgradeable,
  UUPSUpgradeable,
  OwnableUpgradeable
{
  bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
  bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
  bytes32 public constant PAUSER_ROLE = keccak256('PAUSER_ROLE');
  bytes32 public constant UPGRADER_ROLE = keccak256('UPGRADER_ROLE');

  struct proxyInfo {
    address proxyAdd;
    string name;
  }
  struct usersRoleInfo {
    string contractName;
    address contractAddr;
    bytes32 roleHash;
    string roleName;
    address user;
  }
  proxyInfo[] public proxyDetails;
  usersRoleInfo[] managerUsersRole;
  usersRoleInfo[] proxyUsersRole;
  mapping(address => bool) public isRegisteredProxy;
  uint256 public loopProxyCall;
  mapping(bytes32 => string) public roleNames;
  mapping(bytes => uint256) encodedUserToManagerIndex;
  mapping(bytes => uint256) encodedUserToProxyIndex;

  event ProxyRegistered(address proxy, string name, address caller);
  event ProxyUpgraded(address proxy, address newImplementation, address caller);
  event ProxyPaused(address proxy, address caller, bool paused);
  event ProxyUnpaused(address proxy, address caller, bool unpaused);
  event LoopProxyCallUpdated(uint256 previousValue, uint256 newValue);
  event ProxyRoleGranted(address proxy, bytes32 role, address account);
  event ProxyRoleRevoked(address proxy, bytes32 role, address account);
  event ProxyManagerChanged(
    address proxy,
    address oldProxyManager,
    address newProxyManager
  );
  event ProxyBlackListAddress(
    address proxy,
    address blackListedAddress,
    bool blackList,
    address caller
  );
  event ProxyBlackListTokenId(
    address proxy,
    uint256 blackListedTokenId,
    bool blackList,
    address caller
  );

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {}

  function initialize(address _owner) public initializer {
    __Ownable_init(_owner);
    __AccessControl_init();
    __UUPSUpgradeable_init();

    _grantRole(DEFAULT_ADMIN_ROLE, owner());
    _grantRole(ADMIN_ROLE, owner());

    roleNames[DEFAULT_ADMIN_ROLE] = 'DEFAULT_ADMIN_ROLE';
    roleNames[ADMIN_ROLE] = 'ADMIN_ROLE';
    roleNames[PAUSER_ROLE] = 'PAUSER_ROLE';
    roleNames[UPGRADER_ROLE] = 'UPGRADER_ROLE';
    roleNames[MINTER_ROLE] = 'MINTER_ROLE';
    loopProxyCall = 100;

    _pushRole(
      managerUsersRole,
      'ProxyManager',
      address(this),
      DEFAULT_ADMIN_ROLE,
      owner(),
      0
    );
    _pushRole(
      managerUsersRole,
      'ProxyManager',
      address(this),
      ADMIN_ROLE,
      owner(),
      1
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
    encodedUserToManagerIndex[encUser] = _index;
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
    index = encodedUserToManagerIndex[encUser];
    if (index == _arr.length - 1) {
      _arr.pop();
    } else {
      _arr[index] = _arr[_arr.length - 1];
      encodedUserToManagerIndex[encLastUser] = index;
      _arr.pop();
    }
  }

  modifier validProxy(address _proxy) {
    require(_proxy != address(0), 'Proxy address cannot be zero address');
    require(
      isRegisteredProxy[_proxy] == true,
      'Provided proxy is not registered'
    );
    _;
  }

  modifier validImplementation(address _implementation) {
    require(
      _implementation != address(0),
      'Implementation cannot be zero address'
    );
    _;
  }

  function __Ownable_init(address _owner) internal onlyInitializing {
    __Context_init_unchained();
    __Ownable_init_unchained(_owner);
  }

  function __Ownable_init_unchained(address _owner) internal onlyInitializing {
    _transferOwnership(_owner);
  }

  function setLoopProxyCall(uint256 _loopProxyCall)
    public
    onlyRole(ADMIN_ROLE)
  {
    uint256 previousValue = loopProxyCall;
    loopProxyCall = _loopProxyCall;
    emit LoopProxyCallUpdated(previousValue, _loopProxyCall);
  }

  function registerProxy(address[] memory _proxyAdd)
    public
    onlyRole(ADMIN_ROLE)
  {
    for (uint256 i = 0; i < _proxyAdd.length; i++) {
      require(
        _proxyAdd[i] != address(0),
        'Proxy Address cannot be zero address'
      );
      proxyInfo memory newProxy;
      newProxy.name = ERC721Upgradeable(_proxyAdd[i]).name();
      newProxy.proxyAdd = _proxyAdd[i];
      proxyDetails.push(newProxy);
      isRegisteredProxy[newProxy.proxyAdd] = true;

      emit ProxyRegistered(newProxy.proxyAdd, newProxy.name, msg.sender);
    }
  }

  function getAllProxies() public view returns (proxyInfo[] memory) {
    return proxyDetails;
  }

  function fetchManagerUserList() public view returns (usersRoleInfo[] memory) {
    return managerUsersRole;
  }

  function fetchAllProxyUserList()
    public
    view
    returns (NFT.usersRoleInfo[] memory)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    uint256 listLength = 0;
    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      NFT.usersRoleInfo[] memory rolesList = NFT(proxy).getUserRoles();
      listLength += rolesList.length;
    }

    NFT.usersRoleInfo[] memory res = new NFT.usersRoleInfo[](listLength);
    uint256 k = 0;

    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      NFT.usersRoleInfo[] memory rolesList = NFT(proxy).getUserRoles();
      for (uint256 j = 0; j < rolesList.length; j++) {
        res[k] = rolesList[j];
        k++;
      }
    }
    return res;
  }

  function fetchSingleProxyUserList(address _proxy)
    public
    view
    validProxy(_proxy)
    returns (NFT.usersRoleInfo[] memory)
  {
    return NFT(_proxy).getUserRoles();
  }

  function setManagerInAllProxies(address _newProxyManager)
    public
    onlyRole(ADMIN_ROLE)
  {
    require(
      _newProxyManager != address(0),
      'ProxyManager address cannot be zero address'
    );

    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;

    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      address oldPM = NFT(proxy).proxyManager();
      NFT(proxy).setProxyManager(_newProxyManager);
      emit ProxyManagerChanged(proxy, oldPM, _newProxyManager);
    }
  }

  function setManagerInSingleProxy(address _proxy, address _newProxyManager)
    public
    onlyRole(ADMIN_ROLE)
    validProxy(_proxy)
  {
    require(
      _newProxyManager != address(0),
      'ProxyManager address cannot be zero address'
    );
    address oldPM = NFT(_proxy).proxyManager();
    NFT(_proxy).setProxyManager(_newProxyManager);
    emit ProxyManagerChanged(_proxy, oldPM, _newProxyManager);
  }

  function upgradeAllProxies(address _implementation)
    public
    onlyRole(ADMIN_ROLE)
    validImplementation(_implementation)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;

    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      _upgradeProxy(proxy, _implementation, msg.sender);
    }
  }

  function upgradeSingleProxy(address _proxy, address _implementation)
    public
    onlyRole(ADMIN_ROLE)
    validProxy(_proxy)
    validImplementation(_implementation)
  {
    _upgradeProxy(_proxy, _implementation, msg.sender);
  }

  function _upgradeProxy(
    address _proxy,
    address _implementation,
    address caller
  ) internal {
    UUPSUpgradeable(_proxy).upgradeTo(_implementation);
    emit ProxyUpgraded(_proxy, _implementation, caller);
  }

  function pauseAllProxies() public onlyRole(ADMIN_ROLE) {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      if (!NFT(proxy).paused()) {
        _pauseProxy(proxy, msg.sender);
      }
    }
  }

  function pauseSingleProxy(address _proxy)
    public
    onlyRole(ADMIN_ROLE)
    validProxy(_proxy)
  {
    _pauseProxy(_proxy, msg.sender);
  }

  function _pauseProxy(address _proxy, address caller) internal {
    NFT(_proxy).pause();
    emit ProxyPaused(_proxy, caller, true);
  }

  function unpauseAllProxies() public onlyRole(ADMIN_ROLE) {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      if (NFT(proxy).paused()) {
        _unpauseProxy(proxy, msg.sender);
      }
    }
  }

  function unpauseSingleProxy(address _proxy)
    public
    onlyRole(ADMIN_ROLE)
    validProxy(_proxy)
  {
    _unpauseProxy(_proxy, msg.sender);
  }

  function _unpauseProxy(address _proxy, address caller) internal {
    NFT(_proxy).unpause();
    emit ProxyUnpaused(_proxy, caller, true);
  }

  function grantRoleToAllProxies(bytes32 _role, address _account)
    public
    onlyRole(ADMIN_ROLE)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      IAccessControlUpgradeable(proxy).grantRole(_role, _account);
      emit ProxyRoleGranted(proxy, _role, _account);
    }
  }

  function grantRoleToSingleProxy(
    address _proxy,
    bytes32 _role,
    address _account
  ) public onlyRole(ADMIN_ROLE) validProxy(_proxy) {
    IAccessControlUpgradeable(_proxy).grantRole(_role, _account);
    emit ProxyRoleGranted(_proxy, _role, _account);
  }

  function revokeRoleToAllProxies(bytes32 _role, address _account)
    public
    onlyRole(ADMIN_ROLE)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address proxy = proxyDetails[i].proxyAdd;
      if (
        (_role == NFT(proxy).DEFAULT_ADMIN_ROLE() &&
          _account == address(this)) && (_msgSender() != owner())
      ) {
        revert(
          'Restricted: ProxyManager cannot revoke its MINTLAB_DEFAULT_ADMIN_ROLE'
        );
      }
      IAccessControlUpgradeable(proxy).revokeRole(_role, _account);
      emit ProxyRoleRevoked(proxy, _role, _account);
    }
  }

  function revokeRoleToSingleProxy(
    address _proxy,
    bytes32 _role,
    address _account
  ) public onlyRole(ADMIN_ROLE) validProxy(_proxy) {
    if (
      (_role == NFT(_proxy).DEFAULT_ADMIN_ROLE() &&
        _account == address(this)) && (_msgSender() != owner())
    ) {
      revert(
        'Restricted: ProxyManager cannot revoke its MINTLAB_DEFAULT_ADMIN_ROLE'
      );
    }
    IAccessControlUpgradeable(_proxy).revokeRole(_role, _account);
    emit ProxyRoleRevoked(_proxy, _role, _account);
  }

  function accountHasRoleInProxy(
    address _proxy,
    bytes32 _role,
    address _account
  ) public view validProxy(_proxy) returns (bool) {
    return IAccessControlUpgradeable(_proxy).hasRole(_role, _account);
  }

  function transferOwnership(address newOwner) public override onlyOwner {
    require(newOwner != address(0), 'Ownable: new owner is the zero address');
    _revokeRole(DEFAULT_ADMIN_ROLE, owner());
    _revokeRole(ADMIN_ROLE, owner());
    _transferOwnership(newOwner);
    _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    _grantRole(ADMIN_ROLE, newOwner);

    managerUsersRole[0] = usersRoleInfo(
      'ProxyManager',
      address(this),
      DEFAULT_ADMIN_ROLE,
      'DEFAULT_ADMIN_ROLE',
      newOwner
    );
    managerUsersRole[1] = usersRoleInfo(
      'ProxyManager',
      address(this),
      ADMIN_ROLE,
      'ADMIN_ROLE',
      newOwner
    );
    bytes memory encUser = abi.encode(
      'ProxyManager',
      address(this),
      DEFAULT_ADMIN_ROLE,
      'DEFAULT_ADMIN_ROLE',
      newOwner
    );
    encodedUserToManagerIndex[encUser] = 0;
    bytes memory encUser1 = abi.encode(
      'ProxyManager',
      address(this),
      ADMIN_ROLE,
      'ADMIN_ROLE',
      newOwner
    );
    encodedUserToManagerIndex[encUser1] = 1;
  }

  function renounceOwnership() public override onlyOwner {
    revert('Restricted: Cannot renounce ownership');
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
    if (role == DEFAULT_ADMIN_ROLE && _msgSender() != owner()) {
      revert('Restricted: Only owner can grant DEFAULT_ADMIN_ROLE');
    }
    if (!hasRole(role, account)) {
      _grantRole(role, account);

      _pushRole(
        managerUsersRole,
        'ProxyManager',
        address(this),
        role,
        account,
        managerUsersRole.length
      );
    }
  }

  function revokeRole(bytes32 role, address account)
    public
    override
    onlyRole(getRoleAdmin(role))
  {
    if (role == ADMIN_ROLE && account == owner()) {
      revert('Restricted: Owner cannot revoke his ADMIN_ROLE');
    }
    if (role == DEFAULT_ADMIN_ROLE && account == owner()) {
      revert('Restricted: Owner cannot revoke his DEFAULT_ADMIN_ROLE');
    }

    if (hasRole(role, account)) {
      _revokeRole(role, account);

      _popRole(managerUsersRole, 'ProxyManager', address(this), role, account);
    }
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(ADMIN_ROLE)
  {}

  function blackListAddressInAllProxies(address _addr, bool _blackList)
    public
    onlyRole(ADMIN_ROLE)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address _proxy = proxyDetails[i].proxyAdd;
      NFT(_proxy).blackListAddress(_addr, _blackList);
      emit ProxyBlackListAddress(_proxy, _addr, _blackList, msg.sender);
    }
  }

  function blackListAddressInSingleProxy(
    address _proxy,
    address _addr,
    bool _blackList
  ) public onlyRole(ADMIN_ROLE) validProxy(_proxy) {
    NFT(_proxy).blackListAddress(_addr, _blackList);
    emit ProxyBlackListAddress(_proxy, _addr, _blackList, msg.sender);
  }

  function blackListTokenIdInAllProxies(uint256 _tokenId, bool _blackList)
    public
    onlyRole(ADMIN_ROLE)
  {
    uint256 loopLimit = proxyDetails.length < loopProxyCall
      ? proxyDetails.length
      : loopProxyCall;
    for (uint256 i = 0; i < loopLimit; i++) {
      address _proxy = proxyDetails[i].proxyAdd;
      NFT(_proxy).blackListTokenId(_tokenId, _blackList);
      emit ProxyBlackListTokenId(_proxy, _tokenId, _blackList, msg.sender);
    }
  }

  function blackListTokenIdInSingleProxy(
    address _proxy,
    uint256 _tokenId,
    bool _blackList
  ) public onlyRole(ADMIN_ROLE) validProxy(_proxy) {
    NFT(_proxy).blackListTokenId(_tokenId, _blackList);
    emit ProxyBlackListTokenId(_proxy, _tokenId, _blackList, msg.sender);
  }
}
