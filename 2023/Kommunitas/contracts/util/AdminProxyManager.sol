//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import 'hardhat-deploy/solc_0.8/proxy/Proxied.sol';

contract AdminProxyManager is Initializable, Proxied {
  address private _pendingProxyAdmin;

  function __AdminProxyManager_init(address _sender) internal onlyInitializing {
    __AdminProxyManager_init_unchained(_sender);
  }

  function __AdminProxyManager_init_unchained(address _sender) internal onlyInitializing {
    assembly {
      sstore(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, _sender)
    }
  }

  function proxyAdmin() external view virtual returns (address) {
    return _proxyAdmin();
  }

  function transferProxyAdmin(address _newProxyAdmin) external virtual proxied {
    _pendingProxyAdmin = _newProxyAdmin;
  }

  function _transferProxyAdmin(address _newProxyAdmin) internal virtual {
    delete _pendingProxyAdmin;
    assembly {
      sstore(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, _newProxyAdmin)
    }
  }

  function acceptProxyAdmin() external virtual {
    address sender = msg.sender;
    require(_pendingProxyAdmin == sender, 'bad');
    _transferProxyAdmin(sender);
  }
}
