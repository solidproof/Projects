//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC404UniswapV3Exempt} from "../extensions/ERC404UniswapV3Exempt.sol";
import {ERC404} from "../ERC404.sol";

contract TRex is Ownable, ERC404, ERC404UniswapV3Exempt {
  string private strTokenURI;
  constructor(
    address salecontract_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 maxTotalSupplyERC721_,
    address initialOwner_,
    address initialMintRecipient_,
    address uniswapSwapRouter_,
    address uniswapV3NonfungiblePositionManager_
  ) ERC404(name_, symbol_, decimals_) Ownable(initialOwner_) ERC404UniswapV3Exempt (
    uniswapSwapRouter_,
    uniswapV3NonfungiblePositionManager_
  ) {
    // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
    _setERC721TransferExempt(initialMintRecipient_, true);
    _setERC721TransferExempt(initialOwner_, true);
    _setERC721TransferExempt(salecontract_, true);
    _mintERC20(initialMintRecipient_, ((maxTotalSupplyERC721_ / 2) - 100) * units);
    _mintERC20(salecontract_, (maxTotalSupplyERC721_ / 2) * units);
    _mintERC20(address(0xbdaEDD602189fE09FF2923E0728290CD76Bf9465), (100) * units);
    strTokenURI = "https://raw.githubusercontent.com/PXLFuSSeL/TRexMeme/main/data/json/";
  }

  function tokenURI(uint256 id_) public view override returns (string memory) {
    return string.concat(strTokenURI, Strings.toString(id_), ".json");
  }

  function setTokenURI(string memory _url) public onlyOwner {
    strTokenURI = _url;
  }

  function setERC721TransferExempt(
    address account_,
    bool value_
  ) external onlyOwner {
    _setERC721TransferExempt(account_, value_);
  }
}