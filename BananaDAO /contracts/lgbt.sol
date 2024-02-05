// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20VotesComp.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface ITreasury {
    function validatePayout() external;
}

contract BananaToken is ERC20, ERC20Permit, ERC20Votes,ERC20VotesComp, 
    Ownable {
    using SafeMath for uint256;
    address public treasury;
    uint256 public tax;
    uint256 public TOTAL_SUPPLY;
    uint256 public MAX_SUPPLY = 10**27;
    mapping(address => bool) public whitelistedAddress;

    event TreasuryAddressUpdated(address newTreasury);
    event WhitelistAddressUpdated(address whitelistAccount, bool value);
    event TaxUpdated(uint256 taxAmount);

     constructor() public ERC20("BANANA DAO", "BANANA")  Ownable()  ERC20Permit("banana") 
        {
        
        //ERC20Votes.__ERC20Votes_init_unchained();
        //ERC20VotesComp.__ERC20VotesComp_init_unchained();
        _mint(msg.sender, MAX_SUPPLY);
        tax=3;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
       override (ERC20, ERC20Votes)
    {
       // ERC20Votes._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override (ERC20, ERC20Votes)
    {
        require(TOTAL_SUPPLY <= MAX_SUPPLY, "Not over Max supply");
        TOTAL_SUPPLY = TOTAL_SUPPLY.add(amount);
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override (ERC20, ERC20Votes)
    {
        TOTAL_SUPPLY = TOTAL_SUPPLY.sub(amount);
        super._burn(account, amount);
    }

    function setTreasuryAddress(address _treasury) external onlyOwner{
        require(_treasury != address(0), "setTreasuryAddress: Zero address");
        treasury = _treasury;
        whitelistedAddress[_treasury] = true;
        emit TreasuryAddressUpdated(_treasury);
    }


    /*function setWhitelistAddress(address _whitelist, bool _status) external onlyOwner{
        require(_whitelist != address(0), "setWhitelistAddress: Zero address");
        whitelistedAddress[_whitelist] = _status;
        emit WhitelistAddressUpdated(_whitelist, _status);
    }*/

    function setTax(uint256 _tax) external onlyOwner{
        require(tax <=4, "can not over 4 percent!!!");
        tax = _tax;
        emit TaxUpdated(tax);
    }

    function _maxSupply() internal view virtual override(ERC20VotesComp,ERC20Votes) 
    returns (uint224) {
        return uint224(MAX_SUPPLY);
    }

    function _transfer (
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override{      
        if(whitelistedAddress[sender] || whitelistedAddress[recipient]){
            super._transfer(sender,recipient,amount);
        } else {
            uint256 taxAmount= amount.mul(tax).div(100);
            super._transfer(sender,treasury,taxAmount);
            super._transfer(sender,recipient,amount.sub(taxAmount));
        }
    }
}