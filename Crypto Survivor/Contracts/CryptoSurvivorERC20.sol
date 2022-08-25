// SPDX-License-Identifier: MIT 
pragma solidity 0.8.7; 
 
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/utils/math/SafeMath.sol"; 
 
/// @custom:security-contact security@cryptosurvivornft.com 
contract TokenWithTax is ERC20, Ownable { 
    uint256 taxPercentage; 
    uint256 maxTransfer; 
    address rewardPool; 
 
    using SafeMath for uint256; 
 
    mapping(address => bool) private isIncludeFromFee; 
    mapping(address => bool) private isExcludedFromMaxTransfer; 
 
    //EVENTS 
    event taxChanged(uint256 tax); 
    event maxTransferChanged(uint256 amount); 
    event rewardPoolChanged(address rewardPool); 
    event newPairAddress(address wallet); 
    event removePairAddress(address wallet); 
    event walletsExcludedMaxTransfer(address wallet); 
 
    constructor() ERC20("VaccineZombieBlood", "VZBL") { 
        _mint(msg.sender, 50000000 * 10**decimals()); 
        taxPercentage = 0; 
        maxTransfer = 100000 * 10**decimals(); 
        rewardPool = owner(); 
    } 
 
    //EXECUTE IS TOKEN IS LISTED IN EXCHANGE 
    function setTax(uint256 percent) external onlyOwner { 
        require(percent <= 30, "Percent can't be > 30"); 
        taxPercentage = percent; 
        emit taxChanged(percent); 
    } 
 
    function setMaxTransfer(uint256 amount) external onlyOwner { 
        require( 
            amount * 10**decimals() >= 100000 * 10**decimals(), 
            "You cannot place less than 100,000 tokens." 
        ); 
        maxTransfer = amount * 10**decimals(); 
        emit maxTransferChanged(maxTransfer); 
    } 
 
    function setRewardPool(address wallet) external onlyOwner { 
        require(wallet != address(0), "address variable can not be zero address"); 
        require(wallet != owner(), "Pool Reward can't be the owner"); 
        rewardPool = wallet; 
        emit rewardPoolChanged(rewardPool); 
    } 
 
 
    function setPairAddressFee(address wallet) external onlyOwner { 
        require(wallet != address(0), "address variable can not be zero address"); 
        require(!isIncludeFromFee[wallet], "This pair address is included"); 
        isIncludeFromFee[wallet] = true; 
        emit newPairAddress(wallet); 
    } 
 
    function removePairAddressFee(address wallet) external onlyOwner { 
        require(wallet != address(0), "address variable can not be zero address"); 
        require(isIncludeFromFee[wallet], "This pair address is not included"); 
        isIncludeFromFee[wallet] = false; 
        emit removePairAddress(wallet); 
    } 
 
    function setWalletsExcludedFromMaxTransfer(address wallet) external onlyOwner { 
        require(wallet != address(0), "address variable can not be zero address"); 
        require(!isExcludedFromMaxTransfer[wallet], "This wallet is excluded"); 
        isExcludedFromMaxTransfer[wallet] = true; 
        emit walletsExcludedMaxTransfer(wallet);(wallet); 
    } 
 
    function _transfer( 
        address from, 
        address to, 
        uint256 amount 
    ) internal override { 
        require(from != address(0), "ERC20: transfer from the zero address"); 
        require(to != address(0), "ERC20: transfer to the zero address"); 
 
        bool hasFee = false; 
        bool hasMaxTransfer = true; 
 
        /* Maximum transfer protection */ 
         if(isExcludedFromMaxTransfer[from]) { 
            hasMaxTransfer = false;     
        } 
 
        require(amount <= maxTransfer || !hasMaxTransfer, "You cannot exceed the maximum transfer rate"); 
 
        if (isIncludeFromFee[to]) { 
            hasFee = true; 
        } 
 
        if (hasFee) { 
            uint256 taxAmount = amount.mul(taxPercentage).div(100); 
            super._transfer(from, rewardPool, taxAmount); 
            amount -= taxAmount; 
            super._transfer(from, to, amount); 
        } else { 
            //It has tax 
            super._transfer(from, to, amount); 
        } 
    } 
}
