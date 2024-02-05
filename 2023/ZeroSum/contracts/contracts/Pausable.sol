// SPDX-License-Identifier: Unlicensed
// ZeroSum Contract

pragma solidity 0.8.7;
import {Adminable} from "./Adminable.sol";


contract Pausable is Adminable {
    bool private _paused = false;

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() external whenNotPaused onlyAdminHierarchy(AdminRole.Developer) {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external whenPaused onlyAdminHierarchy(AdminRole.Developer) {
        _paused = false;
        emit Unpaused(msg.sender);
    }
// ++++++++++ Events ++++++++++
    event Paused(address account);
    event Unpaused(address account);
}