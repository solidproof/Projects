//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Spender.sol";

/**
 * Test smart contracts
 */

contract TestSpender is IERC1363Spender {
    uint256 public number;
    string public str;
    bool public boolean;
    uint256 public amount;
    address public from;

    function onApprovalReceived(
        address _from,
        uint256 _amount,
        bytes memory data
    ) external returns (bytes4) {
        if (data.length > 0) {
            (string memory _str, uint256 _number, bool _boolean) = abi.decode(
                data,
                (string, uint256, bool)
            );
            str = _str;
            boolean = _boolean;
            number = _number;
        }
        from = _from;
        amount = _amount;
        return IERC1363Spender(this).onApprovalReceived.selector;
    }
}

contract TestReceiver is IERC1363Receiver {
    uint256 public number;
    string public str;
    bool public boolean;
    uint256 public amount;
    address public from;

    function onTransferReceived(
        address,
        address _from,
        uint256 _amount,
        bytes memory data
    ) external returns (bytes4) {
        if (data.length > 0) {
            (string memory _str, uint256 _number, bool _boolean) = abi.decode(
                data,
                (string, uint256, bool)
            );
            str = _str;
            boolean = _boolean;
            number = _number;
        }
        amount = _amount;
        from = _from;
        return IERC1363Receiver(this).onTransferReceived.selector;
    }
}
