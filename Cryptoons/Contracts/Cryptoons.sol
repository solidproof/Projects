// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";

contract Cryptoons is Initializable,  ERC20Upgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable {
    uint8 private _decimals;
    //anti sniper storages
    uint256 private _gasPriceLimit;
    // these values are pretty much arbitrary since they get overwritten for every txn, but the placeholders make it easier to work with current contract.
   
    mapping(address => bool) public isExcludedFromMaxTransactionAmount;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 public maxTransactionAmount;
    uint256 public maxWallet;
    event UpdateMaxTransactionAmount(uint256 maxTransactionAmount);
    event UpdateMaxWallet(uint256 maxWallet);
    event SetAutomatedMarketMakerPair(address pair, bool value);
    event ExcludedMaxTransactionAmount(
        address indexed account,
        bool isExcluded
    );

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 __decimals,
        uint256[4] memory _uint_params
    ) initializer public {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __ERC20Permit_init(_name);
        __ERC20Votes_init();
        _decimals=__decimals;
        _mint(msg.sender, _uint_params[0] * (10**__decimals));
        _gasPriceLimit = _uint_params[1] * 1 gwei;    
        
        maxTransactionAmount = _uint_params[2]*(10**__decimals);
        maxWallet = _uint_params[3]*(10**__decimals);
        require(maxWallet>0,"max wallet > 0");
        require(maxTransactionAmount>0,"maxTransactionAmount > 0");

        excludeFromMaxTransaction(_msgSender(), true);
        excludeFromMaxTransaction(address(this), true);
    }

  
    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
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
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function updateMaxTransactionAmount(uint256 _maxTransactionAmount)
        external
        onlyOwner
    {
        maxTransactionAmount = _maxTransactionAmount*(10**_decimals);
        require(maxTransactionAmount>0,"maxTransactionAmount > 0");
        emit UpdateMaxTransactionAmount(_maxTransactionAmount);
    }

    function updateMaxWallet(uint256 _maxWallet) external onlyOwner {
        maxWallet = _maxWallet*(10**_decimals);
        require(maxWallet>0,"maxWallet > 0");
        emit UpdateMaxWallet(_maxWallet);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        excludeFromMaxTransaction(pair, value);

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function updateGasPriceLimit(uint256 gas) external onlyOwner {
        _gasPriceLimit = gas * 1 gwei;
    }
   
   
  
    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        isExcludedFromMaxTransactionAmount[updAds] = isEx;
        emit ExcludedMaxTransactionAmount(updAds, isEx);
    }
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(amount > 0, "Transfer amount must be greater than zero");
        if (to != address(0) && to != address(0xDead) && from != address(0)) {
            // only use to prevent sniper buys in the first blocks.
            if (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]) {
                require(
                    tx.gasprice <= _gasPriceLimit,
                    "Gas price exceeds limit."
                );
            }
            if (!isExcludedFromMaxTransactionAmount[from]) {
                require(
                    amount < maxTransactionAmount,
                    "ERC20: exceeds transfer limit"
                );
            }
            if (!isExcludedFromMaxTransactionAmount[to]) {
                require(
                    balanceOf(to) < maxWallet,
                    "ERC20: exceeds max wallet limit"
                );
            }
        }        
        super._transfer(from, to, amount);     
    }
    receive() external payable {}
}
