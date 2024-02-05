// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.9;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./TransferHelper.sol";
import "./IBridgeVault.sol";

contract BridgeVault is Context, AccessControl, IBridgeVault {
    bytes32 public constant WITHDRAWER = keccak256("WITHDRAWER");
    address public multiSignWallet;

    event BridgeVaultTransfer(
        uint256 _amount,
        uint256 _when,
        address _token,
        address _to
    );

    constructor(address _multiSignWallet, address _withdrawer) {
        require(
            _multiSignWallet != address(0),
            "BridgeVault:: Multi Sign Wallet Can not to be Zero Wallet"
        );
        multiSignWallet = _multiSignWallet;
        _setupRole(DEFAULT_ADMIN_ROLE, multiSignWallet);
        _setupRole(WITHDRAWER, _withdrawer);
    }

    function bridgeWithdrawal(
        address token,
        address recipient,
        uint256 amount
    ) public {
        require(
            hasRole(WITHDRAWER, _msgSender()),
            "BridgeVault :: bridgeWithdrawal :: Unauthorized Access, Only Bridge allowed to withdraw"
        );
        TransferHelper.safeTransfer(token, recipient, amount);
        emit BridgeVaultTransfer(amount, block.timestamp, token, recipient);
    }
}