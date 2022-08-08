// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PWS is ERC20, Ownable {

  // Play2Earn Contract
  address public PoliticianEarn = 0x30844ad328bb8d048a9F74EE63B851b8019F0982;
  // Dev Wallet
  address public DevWallet = 0x2cAb4855f51E7D552811035F1E9f66c86487e414;


  constructor() ERC20("PWS", "PWS") {
      _mint(PoliticianEarn, 250000000 * 10 ** decimals());
      _mint(DevWallet, 250000000 * 10 ** decimals());
   }



}