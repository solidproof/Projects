// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract GRYD is ERC20 {
    constructor() ERC20("GRYD", "GRD") {
        _mint(msg.sender, 5000000000 * 10 ** decimals());
    }
}

contract GRYDPresale {
    address public owner;              // Владелец контракта
    bool public presaleActive = true; // Флаг активности presale
    GRYD public tokenContract;  
    uint rate = 15000000;      
    uint256 public tokenPrice = 15000000;    // Цена токена (за упрощение принимаем, что 1 ETH = 150 000 000 токенов)

    // Конструктор
    constructor(address _tokenAddress) {
        owner = msg.sender;                   // Владелец контракта
        tokenContract = GRYD(_tokenAddress);  // Адрес контракта токена
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function!");
        _;
    }

    modifier isPresaleActive() {
        require(presaleActive == true, "Presale is active!");
        _;
    }
    modifier isPresaleEnded() {
        require(presaleActive == false, "Presale is active!");
        _;
    }
// Покупка токенов
    function buyTokens(address buyer) public payable isPresaleActive {
        require(msg.value >= 0.007 ether, "min sum - 0.007 ETH");
        
        uint256 tokensToBuy = msg.value * rate; // Расчет количества токенов
        require(tokenContract.balanceOf(address(this)) >= tokensToBuy, "mot enough tokens");

        // 5% комиссия
        uint256 commission = msg.value / 20;
        address commissionAddress = 0xa0729DC0F4Fbc335F6cab10b5F1B4b4664d5D495; // Адрес для комиссии
        payable(commissionAddress).transfer(commission);
        require(tokenContract.transfer(buyer, tokensToBuy), "Error while transfering tokens");
    }

    // Функция для вывода баланса контракта
    function withdrawFunds() external onlyOwner isPresaleEnded {
        payable(owner).transfer(address(this).balance);
    }

    // Функция для завершения presale
    function endPresale() external onlyOwner {
        presaleActive = false;

    }
}