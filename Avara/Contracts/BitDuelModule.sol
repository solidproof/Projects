/**
    ***********************************************************
    * Copyright (c) Avara Dev. 2022. (Telegram: @avara_cc)  *
    ***********************************************************

     ▄▄▄·  ▌ ▐· ▄▄▄· ▄▄▄   ▄▄▄·
    ▐█ ▀█ ▪█·█▌▐█ ▀█ ▀▄ █·▐█ ▀█
    ▄█▀▀█ ▐█▐█•▄█▀▀█ ▐▀▀▄ ▄█▀▀█
    ▐█ ▪▐▌ ███ ▐█ ▪▐▌▐█•█▌▐█ ▪▐▌
     ▀  ▀ . ▀   ▀  ▀ .▀  ▀ ▀  ▀  - Ethereum Network

    Avara - Always Vivid, Always Rising Above
    https://avara.cc/
    https://github.com/avara-cc
    https://github.com/avara-cc/AvaraETH/wiki
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./abstract/AvaraModule.sol";
import "./library/SafeMath.sol";

contract BitDuelModule is AvaraModule {
    using SafeMath for uint256;

    mapping(address => bool) public _isGameMaster;

    event GameMasterAdded(address gmAddress);
    event GameMasterRemoved(address gmAddress);
    event PlayerMigrated(address oldAddress, address newAddress);
    event PlayerBalanceChangedByGM(address gmAddress, address playerAddress, uint256 oldBalance, uint256 newBalance, string action);

    constructor(address cOwner, address baseContract) AvaraModule(cOwner, baseContract, "BitDuel", "0.0.2") {
        _isGameMaster[cOwner] = true;
    }

    modifier onlyGM() {
        require(_isGameMaster[_msgSender()], "The caller is not a Game Master!");
        _;
    }

    /**
    * @dev Occasionally called (only) by the server to make sure that the connection with the module and main contract is granted.
    */
    function ping() external view onlyOwner returns (string memory) {
        return getBaseContract().ping();
    }

    /**
    * @dev Called by a BitDuel GM after a won / lost game, to add to the balance of a user in the player pool.
    * The gas price is provided by BitDuel.
    */
    function addToPlayerBalance(address playerAddress, uint256 amount) external onlyGM {
        uint256 oldBalance = getBaseContract().balanceInPlayerPool(playerAddress);
        uint256 newBalance = oldBalance + amount;

        getBaseContract().setPlayerBalance(playerAddress, newBalance);

        emit PlayerBalanceChangedByGM(_msgSender(), playerAddress, oldBalance, newBalance, "Add");
    }

    /**
    * @dev Called by a BitDuel GM after a won / lost game, to deduct from the balance of a user in the player pool.
    * The gas price is provided by BitDuel.
    */
    function deductFromPlayerBalance(address playerAddress, uint256 amount) external onlyGM {
        require(amount <= getBaseContract().balanceInPlayerPool(playerAddress), "Insufficient funds!");

        uint256 oldBalance = getBaseContract().balanceInPlayerPool(playerAddress);
        uint256 newBalance = oldBalance - amount;

        getBaseContract().setPlayerBalance(playerAddress, newBalance);

        emit PlayerBalanceChangedByGM(_msgSender(), playerAddress, oldBalance, newBalance, "Deduct");
    }

    /**
    * @dev Called by BitDuel to migrate the user onto another address.
    */
    function migratePlayerToAddress(address from, address newAddress) external {
        require(_msgSender() == from || _msgSender() == owner(), "Invalid old address!");
        getBaseContract().setPlayerBalance(newAddress, getBaseContract().balanceInPlayerPool(newAddress) + getBaseContract().balanceInPlayerPool(from));
        getBaseContract().setPlayerBalance(from, uint256(0));

        emit PlayerMigrated(from, newAddress);
    }

    /**
    * @dev Called by BitDuel to add an address to the Game Masters.
    */
    function addGameMaster(address gmAddress) public onlyOwner {
        require(!_isGameMaster[gmAddress], "The address is already a Game Master!");
        _isGameMaster[gmAddress] = true;

        emit GameMasterAdded(gmAddress);
    }

    /**
    * @dev Called by BitDuel to remove an address from the Game Masters.
    */
    function removeGameMaster(address gmAddress) public onlyOwner {
        require(_isGameMaster[gmAddress], "The address is not a Game Master!");
        _isGameMaster[gmAddress] = false;

        emit GameMasterRemoved(gmAddress);
    }

}
