// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "./MintableToken.sol";

abstract contract BaseToken is MintableToken {
    bool public inPrivateTransferMode;

    function setInPrivateTransferMode(bool _mode) external onlyOwner {
        inPrivateTransferMode = _mode;
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        if (!isHandler[msg.sender]) {
            ERC20._spendAllowance(owner, spender, amount);
        }
    }

    function _beforeTokenTransfer(
        address,
        address,
        uint256
    ) internal virtual override {
        if (inPrivateTransferMode) {
            require(
                isHandler[msg.sender] || minter[msg.sender] > 0,
                "BaseToken: msg.sender is not whitelisted"
            );
        }
    }
}
