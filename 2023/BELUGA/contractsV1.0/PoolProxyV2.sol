// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./WETHelper.sol";
import "../../lib0.8/upgrable/Ownable.sol";
import "./interfaces/IPermit.sol";


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IPool {
  function assetOf (address token) external view returns (address);

  function deposit(
    address token,
    uint256 amount,
    address to,
    uint256 deadline
  ) external returns (uint256 liquidity);

  function swap(
    address fromToken,
    address toToken,
    uint256 fromAmount,
    uint256 minimumToAmount,
    address to, 
    uint256 deadline
  ) external returns (uint256);

  function withdraw(
    address token,
    uint256 liquidity,
    uint256 minimumAmount,
    address to,
    uint256 deadline
  ) external returns (uint256 amount);
}

interface IFarm {
  function depositFor(uint256, uint256, address) external;
}

interface IERC20 {
  function approve(address, uint256) external;
  function transfer(address, uint256) external;
  function transferFrom(address, address, uint256) external;
}

contract PoolProxyV2 is Ownable {


  IFarm public farm;
  address public WETH;
  WETHelper public wethelper;

  function initialize(IFarm farm_, address weth_) public initializer {
      Ownable.__Ownable_init();
      farm = farm_;
      WETH = weth_;
      wethelper = new WETHelper();
  }

  receive() external payable {
    assert(msg.sender == WETH);
  }

  function deposit(address token, uint256 amount, uint256 pid, IPool pool_, bool isStake) 
    public payable returns (uint256 liquidity) {
      if(amount > 0) {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
      }
      if(token == WETH) {
        IWETH(WETH).deposit{value: msg.value}();
        amount += msg.value;
      }
      IERC20(token).approve(address(pool_), amount);
      if(isStake){
        liquidity = pool_.deposit(token, amount, address(this), block.timestamp + 1800);
        address asset = pool_.assetOf(token);
        IERC20(asset).approve(address(farm), liquidity);
        farm.depositFor(pid, liquidity, msg.sender); 
      }else{
        liquidity = pool_.deposit(token, amount, msg.sender, block.timestamp + 1800);
      }
  }

  function depositWithPermit(address token, uint256 amount, uint256 pid, IPool pool_, bool isStake, bytes memory signature)
     external payable
    {
        _permit(token, msg.sender, signature);
        deposit(token, amount, pid, pool_, isStake);
  }

  function stake (
    address lpToken,
    uint256 pid,
    uint256 amount
  ) public {
    IERC20(lpToken).transferFrom(msg.sender, address(this), amount);
    IERC20(lpToken).approve(address(farm), amount);
    farm.depositFor(pid, amount, msg.sender);
  }

  function stakeWithPermit(
    address lpToken,
    uint256 pid,
    uint256 amount,
    bytes memory signature
  ) external {
    _permit(lpToken, msg.sender, signature);
    stake(lpToken, pid, amount);
  }

  function swap(
      address fromToken,
      address toToken,
      uint256 fromAmount,
      uint256 minimumToAmount,
      IPool pool_
  ) public payable{
    if(fromAmount > 0) {
      IERC20(fromToken).transferFrom(msg.sender, address(this), fromAmount);
    }
    if(fromToken == WETH){
      IWETH(WETH).deposit{value: msg.value}();
      fromAmount += msg.value;
    }      
    IERC20(fromToken).approve(address(pool_), fromAmount);
    if(toToken == WETH){
      uint256 liquidity = pool_.swap(fromToken, WETH, fromAmount, minimumToAmount, address(this), block.timestamp + 1800);
      IERC20(WETH).transfer(address(wethelper), liquidity);
      wethelper.withdraw(WETH, msg.sender, liquidity);
    }else{
      pool_.swap(fromToken, toToken, fromAmount, minimumToAmount, msg.sender, block.timestamp + 1800); 
    }

  }


  function swapWithPermit(
      address fromToken,
      address toToken,
      uint256 fromAmount,
      uint256 minimumToAmount,
      IPool pool_,
      bytes memory signature  
  ) external payable{
      _permit(fromToken, msg.sender, signature);
      swap(fromToken,toToken,fromAmount,minimumToAmount,pool_);
  }


  function withdraw(
      address token,
      uint256 liquidity,
      uint256 minimumAmount,
      IPool pool_
  ) public {
      address asset = pool_.assetOf(token);
      IERC20(asset).transferFrom(msg.sender, address(this), liquidity);
      IERC20(asset).approve(address(pool_), liquidity);
      if(token == WETH){
        uint256 actualToAmount = pool_.withdraw(token, liquidity, minimumAmount, address(this), block.timestamp + 1800);
        IERC20(WETH).transfer(address(wethelper), actualToAmount);
        wethelper.withdraw(WETH, msg.sender, actualToAmount);
      }else{
        pool_.withdraw(token, liquidity, minimumAmount, msg.sender, block.timestamp + 1800);
      }
      
  }


  function withdrawWithPermit(
      address token,
      uint256 liquidity,
      uint256 minimumAmount,
      IPool pool_,
      bytes memory signature  
  ) external {
      address asset = pool_.assetOf(token);
      _permit(asset, msg.sender, signature);
      withdraw(token,liquidity,minimumAmount,pool_);

  }

  function _permit(address token, address owner, bytes memory signature) internal {
      (uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(signature,(uint256,uint256,uint8,bytes32,bytes32));
      IPermit(token).permit(owner, address(this), value, deadline, v, r, s);
  }
}