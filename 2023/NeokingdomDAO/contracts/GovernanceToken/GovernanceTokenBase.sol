// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "../RedemptionController/IRedemptionController.sol";
import "../Voting/IVoting.sol";
import "../InternalMarket/InternalMarket.sol";
import "../extensions/DAORoles.sol";
import "./IGovernanceToken.sol";

abstract contract GovernanceTokenBase is ERC20Upgradeable, IGovernanceToken {
    event VestingSet(address to, uint256 amount);

    IVoting internal _voting;
    IRedemptionController internal _redemptionController;
    INeokingdomToken public tokenExternal;

    function _initialize(
        string memory name,
        string memory symbol
    ) internal virtual {
        __ERC20_init(name, symbol);
    }

    // TODO: what happens to vesting tokens when someone loses the contributor status?
    // In theory they should be burned or added to a pool
    mapping(address => uint256) internal _vestingBalance;

    // mapping(address => uint256) internal _unlockedBalance;
    function _setVoting(IVoting voting) internal {
        _voting = voting;
    }

    function _setRedemptionController(
        IRedemptionController redemptionController
    ) internal virtual {
        _redemptionController = redemptionController;
    }

    function _setTokenExternal(address tokenExternalAddress) internal {
        tokenExternal = INeokingdomToken(tokenExternalAddress);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        _voting.afterTokenTransfer(from, to, amount);

        if (from == address(0)) {
            _redemptionController.afterMint(to, amount);
        }

        // Invariants
        require(
            balanceOf(from) >= _vestingBalance[from],
            "GovernanceToken: transfer amount exceeds vesting"
        );
    }

    // TODO: ask Marko whether vesting tokens can be given only to contributors
    function _mintVesting(address to, uint256 amount) internal virtual {
        _vestingBalance[to] += amount;
        emit VestingSet(to, _vestingBalance[to]);
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual override {
        tokenExternal.mint(address(this), amount);
        super._mint(to, amount);
    }

    function _wrap(address from, uint amount) internal virtual {
        tokenExternal.transferFrom(from, address(this), amount);
        super._mint(from, amount);
    }

    function _unwrap(address from, address to, uint amount) internal virtual {
        tokenExternal.transfer(to, amount);
        super._burn(from, amount);
    }

    function _burn(address from, uint amount) internal virtual override {
        tokenExternal.burn(amount);
        super._burn(from, amount);
    }

    function _setVesting(address account, uint256 amount) internal virtual {
        require(
            amount < _vestingBalance[account],
            "GovernanceToken: vesting can only be decreased"
        );
        emit VestingSet(account, amount);
        _vestingBalance[account] = amount;
    }

    // Tokens that are still in the vesting phase
    function vestingBalanceOf(
        address account
    ) public view virtual returns (uint256) {
        return _vestingBalance[account];
    }
}
