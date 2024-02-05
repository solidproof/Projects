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

import "./Ownable.sol";
import "../Avara.sol";

abstract contract AvaraModule is Ownable {

    Avara private _baseContract;
    string private _moduleName;
    string private _moduleVersion;

    constructor(address cOwner, address baseContract, string memory name, string memory version) Ownable(cOwner) {
        _baseContract = Avara(payable(baseContract));
        require(_baseContract.owner() == cOwner, "The module deployer must be the owner of the base contract!");

        _moduleName = name;
        _moduleVersion = version;
    }

    /**
     * @dev Returns the module name.
     */
    function moduleName() external view returns (string memory) {
        return _moduleName;
    }

    /**
     * @dev Returns the module version.
     */
    function moduleVersion() external view returns (string memory) {
        return _moduleVersion;
    }

    /**
     * @dev Returns the base contract.
     */
    function getBaseContract() internal view returns (Avara) {
        return _baseContract;
    }

}
