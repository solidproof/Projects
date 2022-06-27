// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesCompUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

interface ITreasury {
    function validatePayout() external;
}

contract RVLT is Initializable,UUPSUpgradeable,ERC20Upgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable,ERC20VotesCompUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeMathUpgradeable for uint256;
    // treasury address
    address public treasury;
    // tax fee percent
    uint256 public tax;
    // mapping to whitelist address
    mapping(address => bool) public whitelistedAddress;

    event TreasuryAddressUpdated(address newTreasury);
    event WhitelistAddressUpdated(address whitelistAccount, bool value);
    event TaxUpdated(uint256 taxAmount);

    /**
      * @notice initialize params
      * @param initialHolder address to hold tokens
      * @param initialSupply initial supply
      */
    function initialize(
        address initialHolder,
        uint256 initialSupply
        ) public initializer {
        require(initialHolder != address(0),"initialize: Invalid address");
        OwnableUpgradeable.__Ownable_init();
        ERC20Upgradeable.__ERC20_init("Revolt 2 Earn", "RVLT");
        ERC20PermitUpgradeable.__ERC20Permit_init("RVLT");
        ERC20VotesUpgradeable.__ERC20Votes_init_unchained();
        __Pausable_init_unchained();
        ERC20VotesCompUpgradeable.__ERC20VotesComp_init_unchained();
        _mint(initialHolder, initialSupply);
        tax=4;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        ERC20VotesUpgradeable._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }

    /**
      * @notice Set treasury address
      * @param _treasury The address of treasury
      */
    function setTreasuryAddress(address _treasury) external onlyOwner{
        require(_treasury != address(0), "setTreasuryAddress: Zero address");
        treasury = _treasury;
        whitelistedAddress[_treasury] = true;
        emit TreasuryAddressUpdated(_treasury);
    }

    /**
      * @notice Whitelist address to make address tax free
      * @param _whitelist address for whitelist
      * @param _status Bool status of whitelist
      */
    function setWhitelistAddress(address _whitelist, bool _status) external onlyOwner{
        require(_whitelist != address(0), "setWhitelistAddress: Zero address");
        whitelistedAddress[_whitelist] = _status;
        emit WhitelistAddressUpdated(_whitelist, _status);
    }

    /**
      * @notice Set Tax Fee value
      * @param _tax The value for tax fee to transfer token
      */
    function setTax(uint256 _tax) external onlyOwner{
        tax = _tax;
        emit TaxUpdated(tax);
    }

    function _maxSupply() internal view virtual override(ERC20VotesCompUpgradeable,ERC20VotesUpgradeable) returns (uint224) {
        return type(uint224).max;
    }


    function _authorizeUpgrade(address) internal view override {
        require(owner() == msg.sender, "Only owner can upgrade implementation");
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override{
        if(whitelistedAddress[sender] || whitelistedAddress[recipient]){
            super._transfer(sender,recipient,amount);
        }else{
            uint256 taxAmount= amount.mul(tax).div(1000);
            super._transfer(sender,treasury,taxAmount);
            super._transfer(sender,recipient,amount.sub(taxAmount));
            ITreasury(treasury).validatePayout();
        }
    }
}