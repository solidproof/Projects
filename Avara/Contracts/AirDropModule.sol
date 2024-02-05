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

contract AirDropModule is AvaraModule {
    using SafeMath for uint256;

    mapping(address => uint256) private _airDropPool;

    event ParticipantsAdded(uint256 numberOfParticipants, uint256 totalTokenAmount);
    event TokensClaimed(address indexed participant, uint256 amount);

    constructor(address cOwner, address baseContract) AvaraModule(cOwner, baseContract, "AirDrop", "0.0.1") {}

    /**
    * @dev Adds a list of AirDrop `participants` to the AirDrop module. The `tokenAmount` is the claimable amount for the `participants`.
    */
    function addParticipants(address[] memory participants, uint256 tokenAmount) external onlyOwner {
        for (uint256 i = 0; i < participants.length; i++) {
            _airDropPool[participants[i]] += tokenAmount;
        }

        emit ParticipantsAdded(participants.length, participants.length.mul(tokenAmount));
    }

    /**
    * @dev Adds a list of AirDrop `participants` to the AirDrop module with custom token amounts for each participant.
    */
    function addUniqueParticipants(address[] memory participants, uint256[] memory tokenAmounts) external onlyOwner {
        uint256 sum = 0;

        for (uint256 i = 0; i < participants.length; i++) {
            _airDropPool[participants[i]] += tokenAmounts[i];
            sum += tokenAmounts[i];
        }

        emit ParticipantsAdded(participants.length, sum);
    }

    /**
    * @dev Retrieves the claimable token amount for a participant on address `a`.
    */
    function balanceInAirDropPool(address a) external view returns (uint256) {
        return _airDropPool[a];
    }

    /**
    * @dev Claims the given `amount` of tokens.
    */
    function claim(uint256 amount) external {
        require(_airDropPool[_msgSender()] >= amount, "Invalid amount!");
        require(getBaseContract().balanceOf(address(this)) >= amount, "The AirDrop Module is currently out of supply!");

        getBaseContract().approve(address(this), amount);
        getBaseContract().transferFrom(address(this), _msgSender(), amount);

        _airDropPool[_msgSender()] -= amount;

        emit TokensClaimed(_msgSender(), amount);
    }

    /**
    * @dev Occasionally called (only) by the server to make sure that the connection with the module and main contract is granted.
    */
    function ping() external view onlyOwner returns (string memory) {
        return getBaseContract().ping();
    }

}
