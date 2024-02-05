/**
 * @title Manager
 * @dev Manager contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./MinterRole.sol";
import "./SafeMath.sol";
import "./Pausable.sol";

contract Manager is Pausable {
    using SafeMath for uint256;

    /**
     * @dev Outputs the `freeMintSupply` variable.
     */
    uint256 public freeMintSupply;
    mapping(address => uint256) public freeMintSupplyMinter;

    /**
     * @dev Sets the {freeMintSupply} up so that the minter can create new coins.
     *
     * The manager decides how many new coins may be created by the minter.
     * The function can only increase the amount of new free coins.
     *
     * Requirements:
     *
     * - only `manager` can update the `setFreeMintSupplyCom`
     */
    function setFreeMintSupplyCom(address _address, uint256 _supply)  // @audit - check "_address" is Minter before adding free mint
        public
        onlyManager
    {
        freeMintSupply = freeMintSupply.add(_supply);  // @audit-info - check zero/dead
        freeMintSupplyMinter[_address] = freeMintSupplyMinter[_address].add(
            _supply
        );  // @audit - Fire event for free mints
    }

    /**
     * @dev Sets the {freeMintSupply} down so that the minter can create fewer new coins.
     *
     * The manager decides how many new coins may be created by the minter.
     * The function can only downgrade the amount of new free coins.
     *
     * Requirements:
     *
     * - only `manager` can update the `setFreeMintSupplySub`
     */
    function setFreeMintSupplySub(address _address, uint256 _supply)
        public
        onlyManager
    {
        freeMintSupply = freeMintSupply.sub(_supply);
        freeMintSupplyMinter[_address] = freeMintSupplyMinter[_address].sub(
            _supply
        );// @audit - Fire event for sub free mints, maybe safe minters into a list that owner can see who is minter
    }
}
