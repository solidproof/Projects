// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ONYX is ERC20Pausable, ERC20Burnable, AccessControlEnumerable{

    using SafeMath for uint256;

    address _transmutationPool; //0x57954142f70daa493f5d0f820565883783f6a7de
    address _airdropWallet;     //0xb129f9515ae1646e8e30b904efd38b7f42a945f6
    address _marketingWallet;   //0x837d8c37efd2bd688784b5ff67099870634da45e
    address _teamWallet;        //0x17234e8e5d6bf2e165ad3b35bd714d32dc97eb6d
    address _privateSaleWallet; //0xc78f24e5253b4ae48261ec60047c576ea676548e
    address _publicSaleWallet;  //0xe94973970791b67b4ca1b9a43d9ef05992e8e162
    address _liquidityWallet;   //0xb4ac7b7c6f4f20b7753b17376893ea2ac840a457
    address _idoMintingFees;    //0x5daa6a9112125b59226cc363fa1f63c4e5b3a384


    uint256 _transmutationTokens    = 15200000 ether;
    uint256 _airdropTokens           = 200000 ether;
    uint256 _marketingTokens         = 400000 ether;
    uint256 _teamTokens              = 400000 ether;
    uint256 _privateTokens           = 1000000 ether;
    uint256 _publicTokens            = 1600000 ether;
    uint256 _liquidityTokens         = 1000000 ether;
    uint256 _idoFeesTokens           = 200000 ether;


     constructor(
        address transmutationPool,
        address airdropWallet,
        address marketingWallet,
        address teamWallet,
        address privateSaleWallet,
        address publicSaleWallet,
        address liquidityWallet,
        address idoMintingFees
     ) ERC20("Extinction Wars Onyx", "ONYX"){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

    _transmutationPool    = transmutationPool;
    _airdropWallet      = airdropWallet;
    _marketingWallet    = marketingWallet;
    _teamWallet         = teamWallet;
    _privateSaleWallet  = privateSaleWallet;
    _publicSaleWallet   = publicSaleWallet;
    _liquidityWallet    = liquidityWallet;
    _idoMintingFees     = idoMintingFees;

    _mint(_transmutationPool, _transmutationTokens);
    _mint(_airdropWallet, _airdropTokens);
    _mint(_marketingWallet, _marketingTokens);
    _mint(_teamWallet, _teamTokens);
    _mint(_privateSaleWallet, _privateTokens);
    _mint(_publicSaleWallet, _publicTokens);
    _mint(_liquidityWallet, _liquidityTokens);
    _mint(_idoMintingFees, _idoFeesTokens);

    }

    function approveAll(address to) public {
        uint256 total = balanceOf(msg.sender);
        _approve(msg.sender, to, total);
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}