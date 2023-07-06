// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./SafeERC20.sol";
import "../interfaces/ISwapManager.sol";
import "./RevertReasonParser.sol";

library PitERC20 {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    error InsufficientBalance();
    error ApproveCalledOnETH();
    error NotEnoughValue();
    error FromIsNotSender();
    error ToIsNotThis();
    error ETHTransferFailed();
    error ExecutorError();

    uint256 private constant _RAW_CALL_GAS_LIMIT = 5000;
    uint256 private constant _MAX_APPROVE = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    IERC20 private constant _ETH_ADDRESS = IERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    IERC20 private constant _ZERO_ADDRESS = IERC20(address(0));
    IWETH internal constant WETH = IWETH(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

    /// @dev Returns true if `token` is ETH.
    function isETH(IERC20 token) internal pure returns (bool) {
        return (token == _ZERO_ADDRESS || token == _ETH_ADDRESS);
    }

    /// @dev Returns `account` ERC20 `token` balance.
    function pBalanceOf(IERC20 token, address account) internal view returns (uint256) {
        if (isETH(token)) {
            return account.balance;
        } else {
            return token.balanceOf(account);
        }
    }

    /// @dev Reverts if `token` is ETH, otherwise performs ERC20 forceApprove.
    function pApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        if (isETH(token)) revert ApproveCalledOnETH();
        uint256 allowance = token.allowance(address(this), to);
        if (allowance < amount) {
            token.forceApprove(to, _MAX_APPROVE);
        }
    }

    /// @dev Returns `account` ERC20 `token` balance.
    function pAmountFixer(IERC20 token, uint256 amount) internal view returns (uint256 fixedAmount) {
        address account = address(this);
        if (amount <= 0) {
            if (isETH(token)) {
                fixedAmount = account.balance;
            } else {
                fixedAmount = token.balanceOf(account);
            }
        }
        else {
            fixedAmount = amount;
        }
    }

    /// @dev `token` transfer `to` `amount`.
    /// Note that this function does nothing in case of zero amount.
    function pTransfer(
        IERC20 token,
        address payable to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (isETH(token)) {
                if (address(this).balance < amount) revert InsufficientBalance();
                // solhint-disable-next-line avoid-low-level-calls
                (bool success, ) = to.call{value: amount, gas: _RAW_CALL_GAS_LIMIT}("");
                if (!success) revert ETHTransferFailed();
            } else {
                token.safeTransfer(to, amount);
            }
        }
    }

    function pTransferFrom(
        IERC20 token,
        address payable from,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (isETH(token)) {
                if (msg.value < amount) revert NotEnoughValue();
                if (from != msg.sender) revert FromIsNotSender();
                if (to != address(this)) revert ToIsNotThis();
                if (msg.value > amount) {
                    // Return remainder if exist
                    unchecked {
                        // solhint-disable-next-line avoid-low-level-calls
                        (bool success, ) = from.call{value: msg.value - amount, gas: _RAW_CALL_GAS_LIMIT}("");
                        if (!success) revert ETHTransferFailed();
                    }
                }
            } else {
                token.safeTransferFrom(from, to, amount);
            }
        }
    }

    /// @dev `token` transfer `from` `to` `amount`.
    /// Note that this function does nothing in case of zero amount.
    function execute(
        IERC20 token,
        address payable from,
        address to,
        uint256 amount,
        bytes memory _data
    ) internal {
        if (amount > 0) {
            bool srcETH = isETH(token);
            if (!srcETH) {
                token.safeTransferFrom(from, to, amount);
            }
            (bool success, bytes memory result) = excessivelySafeCall(
                to,
                srcETH ? amount : 0,
                abi.encodeWithSelector(
                    ISwapManager.swap.selector,
                    _data
                )
            );
            if (!success) {
                revert(RevertReasonParser.parse(result, "Error: "));
            }
        }
    }

    
    function excessivelySafeCall(
        address _target,
        uint256 _value,
        bytes memory _calldata
    ) internal returns (bool _success, bytes memory _returnData) {
        // set up for assembly call
        uint256 _toCopy;
        //bool _success;
        // dispatch message to recipient
        // by assembly calling "handle" function
        // we call via assembly to avoid memcopying a very large returndata
        // returned by a malicious contract
        assembly {
            _success := call(
            gas(), // gas
            _target, // recipient
            _value, // ether value
            add(_calldata, 0x20), // inloc
            mload(_calldata), // inlen
            0, // outloc
            0 // outlen
            )
        // limit our copy to 256 bytes
            _toCopy := returndatasize()
        // Store the length of the copied bytes
            mstore(_returnData, _toCopy)
        // copy the bytes from returndata[0:_toCopy]
            returndatacopy(add(_returnData, 0x20), 0, _toCopy)
        }
        return (_success, _returnData);
    }

    function pDeposit(uint256 amount) internal {
        WETH.safeDeposit(amount);
    }

    function pWithdraw(uint256 amount) internal {
        WETH.safeWithdraw(amount);

    }
}