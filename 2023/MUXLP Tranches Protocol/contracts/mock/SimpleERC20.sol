// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract SimpleERC20 is ERC20PresetMinterPauser {
    uint8 _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) ERC20PresetMinterPauser(name, symbol) {
        _decimals = decimals_;
    }

    function burn(address account, uint256 amount) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "sender must be minter to burn");
        _burn(account, amount);
    }

    function adminBurn(address account, uint256 amount) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "sender must be minter to burn");
        _burn(account, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
