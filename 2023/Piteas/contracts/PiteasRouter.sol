// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./libraries/PitERC20.sol";
import "./EthReceiver.sol";
import "./errors/Errors.sol";

contract PiteasRouter is Ownable, EthReceiver {
    using PitERC20 for IERC20;
    using SafeMath for uint256;

    bool private status = true;
    address private swapManager;

    struct Detail {
        IERC20 srcToken;
        IERC20 destToken;
        address payable destAccount;
        uint256 srcAmount;
        uint256 destMinAmount;
    }

    event ChangedStatus(bool indexed status);
    event ChangedSwapManager(address indexed manager);
    event SwapEvent(
        address swapManager,
        IERC20 srcToken,
        IERC20 destToken,
        address indexed sender,
        address destReceiver,
        uint256 srcAmount,
        uint256 destAmount
    );

    modifier checkStatus() {
        if (status == false) {
            revert Errors.HasBeenStopped();
        }
        _;
    }

    function swap(Detail memory detail, bytes calldata data) public payable checkStatus returns (uint256 returnAmount)  {
        if (detail.srcAmount == 0) revert Errors.ZeroSrcAmount();
        if (detail.destMinAmount == 0) revert Errors.ZeroDestAmount();
        if (data.length == 0) revert Errors.ZeroData();

        IERC20 srcToken = detail.srcToken;
        IERC20 destToken = detail.destToken;
       
        bool srcETH = srcToken.isETH();
        if (msg.value < (srcETH ? detail.srcAmount : 0)) revert Errors.InvalidMsgValue();

        uint256 beginBalance = destToken.pbalanceOf(address(this));
        srcToken.execute(payable(msg.sender), swapManager, detail.srcAmount, data);
        returnAmount = destToken.pbalanceOf(address(this)).sub(beginBalance,"Error");
        
        address payable destReceiver = (detail.destAccount == address(0)) ? payable(msg.sender) : detail.destAccount;
        
        if (returnAmount >= detail.destMinAmount) {
            destToken.pTransfer(destReceiver, returnAmount);
        }else{
            revert Errors.ReturnAmountIsNotEnough();
        }

        emit SwapEvent(address(swapManager), srcToken, destToken, msg.sender, destReceiver, detail.srcAmount, returnAmount);
    }
    
    function changeStatus(bool _status) external onlyOwner {
        status = _status;
        emit ChangedStatus(_status);
    }

    function changeSwapManager(address _manager) external onlyOwner {
        if (_manager == address(0)) {
            revert Errors.ZeroAddress();
        }
        swapManager = _manager;
        emit ChangedSwapManager(_manager);
    }

    function withdrawFunds(IERC20 token, uint256 amount) external onlyOwner {
        token.pTransfer(payable(msg.sender), amount);
    }
}
