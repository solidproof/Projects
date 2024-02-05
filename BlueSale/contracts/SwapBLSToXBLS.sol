// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IXBLSToken {
    function mint(address _to, uint256 _amount) external;
}

contract SwapBLSToXBLS is Initializable, PausableUpgradeable, 
    OwnableUpgradeable, ReentrancyGuardUpgradeable
 {
    uint256 public totalMint;
    address public fundWallet;
    address public inToken;
    address public outToken;

  event EventDeposited(
    address indexed sender,
    uint256 amount,
    uint256 date
  );
  
  function initialize(address _inToken, address _outToken) public initializer {
    __Context_init();
    __Ownable_init();
    __ReentrancyGuard_init();
    
    inToken = _inToken;
    outToken = _outToken;
  }

  function pause() public onlyOwner {
      _pause();
  }

  function unpause() public onlyOwner {
      _unpause();
  }


  function setConfig(
    address _inToken,
    address _outToken,
    address _fundWallet
  ) 
    external onlyOwner
  {
   
    inToken = _inToken;
    outToken = _outToken;
    fundWallet = _fundWallet;
  }
  
  function swap(uint256 _amount) external whenNotPaused returns(bool) {
    totalMint += _amount;
    if (fundWallet != address(0)) {
       IERC20(inToken).transferFrom(msg.sender, fundWallet, _amount);
    } else {
       IERC20(inToken).transferFrom(msg.sender, address(this), _amount);
    }

    IXBLSToken(outToken).mint(msg.sender, _amount);

     emit EventDeposited(
          msg.sender,
          _amount,
          block.timestamp
        );
    return true;
  }
  
  function eWithdraw(
    address _token, 
    address _to, 
    uint256 _amount
  ) 
    external onlyOwner
  {
    IERC20(_token).transfer(_to, _amount);
  }
}
