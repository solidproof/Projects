// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../contrib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../../contrib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "../../contrib/openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol";

contract USDR is ERC20Pausable, AccessControlEnumerable {
    uint256 private _minerReward = 0;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant REWARD_ROLE = keccak256("REWARD_ROLE");

    constructor() ERC20("Testnet Remitt USD (v0.0.3)","USDR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _mintMinerReward() internal {
        _mint(block.coinbase, _minerReward);
    }

    function _beforeTokenTransfer(address from, address to, uint256 value) internal virtual override {
        if (!(from == address(0) && to == block.coinbase) && _minerReward > 0) {
            _mintMinerReward();
        }
        super._beforeTokenTransfer(from, to, value);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function minerReward() public view returns (uint256) {
        return _minerReward;
    }

    function setMinerReward(uint256 reward) public onlyRole(REWARD_ROLE) {
        _minerReward = reward;
    }
}