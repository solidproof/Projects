//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
error notBridge();
contract LockContract{
    using SafeERC20 for IERC20;

    address public immutable bridge;
    address public immutable asset;
    constructor(address _bridge,address _asset){
        bridge = _bridge;
        asset = _asset;
    }

    function withdraw(address to, uint256 amount) external onlyBridge{
        IERC20(asset).safeTransfer(to, amount);
    }
    
    modifier onlyBridge{
        if(msg.sender!= bridge){
            revert notBridge();
        }
        _;
    }
}