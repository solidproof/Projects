//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./BridgedERC20.sol";
import "./LockContract.sol";
import "./interfaces/IFactoryERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FactoryERC20 is IFactoryERC20, AccessControl {
  address[] public Tokens;
  mapping(address=>address) internal _lockAddress;
  mapping(address=>string) internal _brc20;
  mapping(string=>address) internal _erc20;
  bytes32 public constant CREATE_BRIDGE = keccak256("CREATE_BRIDGE");
  bytes32 public constant BRIDGE_TOKEN = keccak256("BRIDGE_TOKEN");
  event TokenAdded(string indexed ticker, address token);

// updating token info might not be possible
  function CreateNewBridgeToken(string memory name, string memory symbol,address bridge,uint256 totalSupply,string memory _brc20Ticker) public onlyRole(CREATE_BRIDGE) returns(address) {
    BridgedERC20 newToken = new BridgedERC20(name,symbol);
    address token = address(newToken);
    LockContract _lock = new LockContract(bridge,token);
    newToken.initialise(address(_lock), totalSupply);
    Tokens.push(token);
    _lockAddress[token] = address(_lock);
    _brc20[token] = _brc20Ticker;
    _erc20[_brc20Ticker] = token;
    _grantRole(BRIDGE_TOKEN, token);
    emit TokenAdded(_brc20Ticker,token);
    return token;
  }

  constructor (address defaultAdmin){
    _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    _grantRole(CREATE_BRIDGE, defaultAdmin);
  }

  function lockAddress(address token) public view returns(address){
    return  _lockAddress[token];
  }

  function brc20(address token) public view returns(string memory){
    return  _brc20[token];
  }
  function erc20(string memory _brc20Ticker) public view returns(address){
    return  _erc20[_brc20Ticker];
  }

  function supportToken(address token,string memory _brc20Ticker,address bridge) public onlyRole(CREATE_BRIDGE){
    LockContract _lock = new LockContract(bridge,token);
    Tokens.push(token);
    _lockAddress[token] = address(_lock);
    _brc20[token] = _brc20Ticker;
    _erc20[_brc20Ticker] = token;
    _grantRole(BRIDGE_TOKEN, token);
    emit TokenAdded(_brc20Ticker,token);
  }

}