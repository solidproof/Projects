//  $$$$$$$$\ $$$$$$$$\  $$$$$$\  $$\      $$\       $$$$$$$$\  $$$$$$\  $$\   $$\ $$$$$$$$\ $$\   $$\
//  \__$$  __|$$  _____|$$  __$$\ $$$\    $$$ |      \__$$  __|$$  __$$\ $$ | $$  |$$  _____|$$$\  $$ |
//     $$ |   $$ |      $$ /  $$ |$$$$\  $$$$ |         $$ |   $$ /  $$ |$$ |$$  / $$ |      $$$$\ $$ |
//     $$ |   $$$$$\    $$$$$$$$ |$$\$$\$$ $$ |         $$ |   $$ |  $$ |$$$$$  /  $$$$$\    $$ $$\$$ |
//     $$ |   $$  __|   $$  __$$ |$$ \$$$  $$ |         $$ |   $$ |  $$ |$$  $$<   $$  __|   $$ \$$$$ |
//     $$ |   $$ |      $$ |  $$ |$$ |\$  /$$ |         $$ |   $$ |  $$ |$$ |\$$\  $$ |      $$ |\$$$ |
//     $$ |   $$$$$$$$\ $$ |  $$ |$$ | \_/ $$ |         $$ |    $$$$$$  |$$ | \$$\ $$$$$$$$\ $$ | \$$ |
//     \__|   \________|\__|  \__|\__|     \__|         \__|    \______/ \__|  \__|\________|\__|  \__|

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TeamToken is ERC20, ERC20Permit {
    constructor(
        address _gnosisSafe
    ) ERC20("TeamToken", "TT") ERC20Permit("TeamToken") {
        _mint(_gnosisSafe, 100000000 * 10 ** decimals());
    }
}