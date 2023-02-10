// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./Owned.sol";
import "./TokensRecoverable.sol";

contract Click is
    ERC20,
    ERC20Burnable,
    ERC20Snapshot,
    Owned,

    TokensRecoverable
{
     mapping (address => bool) private _isBlackList;
    uint public lastPauseTime;
    bool public paused;


    /**
     * @dev Sets the values for {name} and {symbol} and mint the tokens to the address set.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor()
        ERC20("Click", "CLK")
        Owned(0x59F39C2c7Fa9445F22E99559eF31027863d7E30b)
    {
        _mint(0x59F39C2c7Fa9445F22E99559eF31027863d7E30b, 5000000000000 ether);
    }

    /**
     * @dev Creates a new snapshot and returns its snapshot id.
     *
     * Emits a {Snapshot} event that contains the same id.
     *
     * {_snapshot} is `internal` and you have to decide how to expose it externally. Its usage may be restricted to a
     * set of accounts, for example in our contract, only Owner can call it.
     *
     */
    function snapshot() public onlyOwner {
        _snapshot();
    }





    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */







function addBlackList (address _evilUser) public onlyOwner {

        _isBlackList[_evilUser] = true;
    }

    function removeBlackList (address _clearedUser) public onlyOwner {

        _isBlackList[_clearedUser] = false;
    }

    function _getBlackStatus(address _maker) private view returns (bool) {
        return _isBlackList[_maker];
    }





   function setPaused(bool _paused) external onlyOwner {
        // Ensure we're actually changing the state before we do anything

        if (_paused == paused) {
            return;
        }

        // Set our paused state.
        paused = _paused;

        // If applicable, set the last pause time.
        if (paused) {
            lastPauseTime = block.timestamp;
        }

        // Let everyone know that our pause state has changed.
        emit PauseChanged(paused);
    }

    event PauseChanged(bool isPaused);

    modifier notPaused {
        require(!paused, "This action cannot be performed while the contract is paused");
        _;
    }















  function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Snapshot)

    {
        require(paused== false, "This action cannot be performed while the contract is paused");
        require(_getBlackStatus(msg.sender) == false , "Address in blacklist");
        super._beforeTokenTransfer(from, to, amount);
    }


}