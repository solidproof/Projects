// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ZenCats.sol";
import "./WhiteList.sol";


contract ZenCatsFactory is Ownable,AccessControl,WhiteList {
    using Strings for string;

    address public nftAddress;

    /*
     * Enforce the existence of only 100 OpenSea creatures.
     */
    uint256 ZENCATS_SUPPLY;

    /*
     * Three different options for minting Creatures (basic, premium, and gold).
     */
    
    uint public MAX_LEVEL = 3;

    
    bool public publicMintActive = true;
    bool public privateMintActive = true;
    
    mapping(uint => uint) public level_supply;
    mapping(uint => bool) public allowed_mint_size;
    mapping(uint => uint) public public_mint_price;
    mapping(uint => uint) public private_mint_price;
    constructor(address _nftAddress) {
        nftAddress = _nftAddress;
        level_supply[0] = 1000;
        level_supply[1] = 1000;
        level_supply[2] = 1000;
        ZENCATS_SUPPLY =  3000;

        allowed_mint_size[1] = true;
        allowed_mint_size[2] = true;
        allowed_mint_size[4] = true;
        allowed_mint_size[7] = true;

        private_mint_price[1] =  0.08 ether;
        private_mint_price[2] =  0.16 ether;
        private_mint_price[4] =  0.3 ether;
        private_mint_price[7] =  0.6 ether;

        public_mint_price[1] =  0.1 ether;
        public_mint_price[2] =  0.16 ether;
        public_mint_price[4] =  0.37 ether;
        public_mint_price[7] =  0.66 ether;
    }
    // function setSingleMintPrice(uint256 value) external onlyOwner {
    //     singleMintPrice = value;
    // }
    // function setPack2MintPrice(uint256 value) external onlyOwner {
    //     pack2MintPrice = value;
    // }
    // function setPack4MintPrice(uint256 value) external onlyOwner {
    //     pack4MintPrice = value;
    // }

    function setPrivateMintActive(bool value) external onlyOwner {
        privateMintActive = value;
    }

    function setPublicMintActive(bool value) external onlyOwner {
        publicMintActive = value;
    }
    function fundtransfer(address payable etherreceiver, uint256 amount) external onlyOwner {
        require(etherreceiver != address(0) , "Can not Send To Zero");
        etherreceiver.transfer(amount)   ;
    }
    function random(uint seed) private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty,seed,msg.sender, block.timestamp)));
    } 

    function randomMint(address _toAddress) private {
        ZenCats zencatContract = ZenCats(nftAddress);
        uint level = random(block.timestamp) % 3;
        for(uint i = 0 ; i< MAX_LEVEL ; i++)
        {
            uint temp = (level+i) % MAX_LEVEL;
            if (level_supply[temp] > 0)
            {
                level = temp;
                break;
            }
        }
        require(level_supply[level] > 0,"No Supply for this level");
        zencatContract.mintTo(_toAddress,level);
        level_supply[level]--;
        ZENCATS_SUPPLY--;
    }

    function _mint(uint256 mint_size, address _toAddress) internal {
            for (uint256 i = 0;i < mint_size; i++) {
                randomMint(_toAddress);
            }

    }
    function mint(uint mint_size, address _toAddress)  external payable {
        // Must be sent from the owner proxy or owner.
        require(publicMintActive,"PUBLIC MINT IS NOT ACTIVE");
        require(canMint(mint_size));
        initQouta(_toAddress);
        require(public_mint_price[mint_size]  <= msg.value, "wrong value");
        require(mint_size > 0);

        require(mint_size <= publicQouta[msg.sender], "NO QOUTA");
        
        publicQouta[msg.sender]-=mint_size;

        
        _mint(mint_size,_toAddress);
    }


    function mintPrivate(uint mint_size, address _toAddress)  external payable {
        // Must be sent from the owner proxy or owner.
        require(privateMintActive,"PRIVATE MINT IS NOT ACTIVE");        
        require(canMintPrivate(mint_size));
        require(mint_size > 0);
        require(0 <whiteListSecondQouta[msg.sender] || 0 <whiteListQouta[msg.sender],"You are not in any whitelist");

        if (whiteListQouta[msg.sender] > 0) {
            require(0 <whiteListQouta[msg.sender],"NO QOUTA FOR MINT");
            require(private_mint_price[mint_size]  <= msg.value, "wrong value");
            whiteListQouta[msg.sender]-=mint_size;
        } else if (whiteListSecondQouta[msg.sender] > 0) {
            require(0 <whiteListSecondQouta[msg.sender],"NO QOUTA FOR MINT");
            require(public_mint_price[mint_size]  <= msg.value, "wrong value");
            whiteListSecondQouta[msg.sender]-=mint_size;
        } 
        _mint(mint_size,_toAddress);

    }

    function mintFree(address _toAddress)  external payable {
        // Must be sent from the owner proxy or owner.
        require(privateMintActive,"PRIVATE MINT IS NOT ACTIVE");        
        require(canMintFree(1));


        require(1 <= whiteListFreeQouta[msg.sender],"NO QOUTA FOR FREE PACK MINT");
        whiteListFreeQouta[msg.sender]--;
    
        _mint(1,_toAddress);

    }
    function canMintPrivate(uint256 mint_size)  public view returns (bool) {
        return canMint(mint_size);
    }
    function canMintFree(uint256 mint_size)  public view returns (bool) {
        return canMint(mint_size);
    }
    function canMint(uint256 mint_size)  public view returns (bool) {
        if (!allowed_mint_size[mint_size]) {
            return false;
        }

        ZenCats zencatContract = ZenCats(nftAddress);
        uint256 zencatSupply = zencatContract.totalSupply();

        return zencatSupply < (ZENCATS_SUPPLY - mint_size);
    }

}