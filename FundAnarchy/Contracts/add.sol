// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./IUniswapV2Factory.sol";

contract Add is Initializable, ERC20Upgradeable, PausableUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable, UUPSUpgradeable {
	using SafeMathUpgradeable for uint256;
    address public treasury;
	address public marketing;
	address public staking;

    bool private swapping;
	bool public swapEnable;

	bool private initialized;

	uint256 public swapTokensAtAmount;
	uint256 public maxWalletAmount;

	uint256[] public DAOFee;
	uint256[] public stakingPoolFee;
	uint256[] public marketingFee;

	IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    mapping(address => bool) public whitelistedAddress;
	mapping(address => bool) public automatedMarketMakerPairs;
	mapping(address => bool) public isExcludedFromMaxWalletToken;

    event TreasuryAddressUpdated(address newTreasury);
	event MarketingAddressUpdated(address newMarketing);
	event StakingAddressUpdated(address newStaking);
    event WhitelistAddressUpdated(address whitelistAccount, bool value);
    event TaxUpdated(uint256 taxAmount);
	event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
	event ExcludeFromMaxWalletToken(address indexed account, bool isExcluded);
	event SwapTokenAmountUpdated(uint256 indexed amount);
	event MaxWalletAmountUpdated(uint256 indexed amount);
	event SwapStatusUpdated(bool indexed status);

    function initialize() initializer public {
	    require(!initialized, "Contract instance has already been initialized");
		initialized = true;

		__ERC20_init("Anarchist Development DAO", "ADD");
        __Pausable_init();
        __Ownable_init();
        __ERC20Permit_init("add");
        __ERC20Votes_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 100000000000 * (10**18));

		IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair   = _uniswapV2Pair;

        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);

		whitelistedAddress[address(this)] = true;
		whitelistedAddress[owner()] = true;

		isExcludedFromMaxWalletToken[uniswapV2Pair] = true;
		isExcludedFromMaxWalletToken[address(this)] = true;
		isExcludedFromMaxWalletToken[owner()] = true;

	    DAOFee.push(350);
		DAOFee.push(350);
		DAOFee.push(0);

		marketingFee.push(100);
		marketingFee.push(100);
		marketingFee.push(0);

		stakingPoolFee.push(50);
		stakingPoolFee.push(50);
		stakingPoolFee.push(0);

		swapEnable = true;
		swapTokensAtAmount = 1000000 * (10**18);
        maxWalletAmount = 1000000000 * (10**18);
    }

	function _authorizeUpgrade(address newImplementation) internal onlyOwner override {}

	function _mint(address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._burn(account, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable){
        super._afterTokenTransfer(from, to, amount);
    }

	function _beforeTokenTransfer(address from, address to, uint256 amount) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setAddress(address _treasury) external onlyOwner{
        require(_treasury != address(0), "setTreasuryAddress: Zero address");
        treasury = _treasury;
        whitelistedAddress[_treasury] = true;
        emit TreasuryAddressUpdated(_treasury);
    }

	function setMarketingAddress(address _marketing) external onlyOwner{
        require(_marketing != address(0), "setMarketingAddress: Zero address");
        marketing = _marketing;
        whitelistedAddress[_marketing] = true;
        emit MarketingAddressUpdated(_marketing);
    }

	function setStakingPoolAddress(address _staking) external onlyOwner{
        require(_staking != address(0), "setStakingPoolAddress: Zero address");
        staking = _staking;
        whitelistedAddress[_staking] = true;
        emit StakingAddressUpdated(_staking);
    }

    function setWhitelistAddress(address _whitelist, bool _status) external onlyOwner{
        require(_whitelist != address(0), "setWhitelistAddress: Zero address");
        whitelistedAddress[_whitelist] = _status;
        emit WhitelistAddressUpdated(_whitelist, _status);
    }

    function _maxSupply() internal view virtual override(ERC20VotesUpgradeable) returns (uint224) {
        return type(uint224).max;
    }

	function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
  	     require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		 swapTokensAtAmount = amount;

		 emit SwapTokenAmountUpdated(amount);
  	}

	function setMaxWalletAmount(uint256 amount) public onlyOwner {
		require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		maxWalletAmount = amount;

		emit MaxWalletAmountUpdated(amount);
	}

	function setSwapEnable(bool _enabled) public onlyOwner {
        swapEnable = _enabled;
	    emit SwapStatusUpdated(_enabled);
    }

	function setDAOFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(marketingFee[0].add(stakingPoolFee[0]).add(buy)  <= 2500 , "Max fee limit reached for 'BUY'");
		require(marketingFee[1].add(stakingPoolFee[1]).add(sell) <= 2500 , "Max fee limit reached for 'SELL'");
		require(marketingFee[2].add(stakingPoolFee[2]).add(p2p)  <= 2500 , "Max fee limit reached for 'P2P'");

		DAOFee[0] = buy;
		DAOFee[1] = sell;
		DAOFee[2] = p2p;
	}

	function setMarketingFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(DAOFee[0].add(stakingPoolFee[0]).add(buy)  <= 2500 , "Max fee limit reached for 'BUY'");
		require(DAOFee[1].add(stakingPoolFee[1]).add(sell) <= 2500 , "Max fee limit reached for 'SELL'");
		require(DAOFee[2].add(stakingPoolFee[2]).add(p2p)  <= 2500 , "Max fee limit reached for 'P2P'");

		marketingFee[0] = buy;
		marketingFee[1] = sell;
		marketingFee[2] = p2p;
	}

	function setStakingPoolFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(DAOFee[0].add(marketingFee[0]).add(buy)  <= 2500 , "Max fee limit reached for 'BUY'");
		require(DAOFee[1].add(marketingFee[1]).add(sell) <= 2500 , "Max fee limit reached for 'SELL'");
		require(DAOFee[2].add(marketingFee[2]).add(p2p)  <= 2500 , "Max fee limit reached for 'P2P'");

		stakingPoolFee[0] = buy;
		stakingPoolFee[1] = sell;
		stakingPoolFee[2] = p2p;
	}

	function excludeFromMaxWalletToken(address account, bool excluded) public onlyOwner {
        require(isExcludedFromMaxWalletToken[account] != excluded, "Account is already the value of 'excluded'");
        isExcludedFromMaxWalletToken[account] = excluded;
        emit ExcludeFromMaxWalletToken(account, excluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The Uniswap pair cannot be removed from automatedMarketMakerPairs");
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(automatedMarketMakerPairs[pair] != value, "Automated market maker pair is already set to that value");
        automatedMarketMakerPairs[pair] = value;
        emit SetAutomatedMarketMakerPair(pair, value);
    }

	function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

	function transferTokens(address tokenAddress, address to, uint256 amount) public onlyOwner {
        IERC20Upgradeable(tokenAddress).transfer(to, amount);
    }

	function migrateETH(address payable recipient) public onlyOwner {
	    require(recipient != address(0), "Zero address");
        recipient.transfer(address(this).balance);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20Upgradeable){
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

		if(!isExcludedFromMaxWalletToken[recipient] && !automatedMarketMakerPairs[recipient])
		{
            uint256 balanceRecepient = balanceOf(recipient);
            require(balanceRecepient + amount <= maxWalletAmount, "Exceeds maximum wallet token amount");
        }

		uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapTokensAtAmount;

		if (!swapping && canSwap && swapEnable && automatedMarketMakerPairs[recipient]) {
			swapping = true;

			uint256 initialBalance = address(this).balance;
			swapTokensForETH(swapTokensAtAmount);
			uint256 newBalance = address(this).balance.sub(initialBalance);

			if(newBalance > 0)
			{
			    payable(treasury).transfer(newBalance);
			}
			swapping = false;
		}

		if(whitelistedAddress[sender] || whitelistedAddress[recipient])
		{
             super._transfer(sender,recipient,amount);
        }
		else
		{
		    (uint256 _DAOfee, uint256 _marketingFee, uint256 _stakingFee) = collectFee(amount, automatedMarketMakerPairs[recipient], !automatedMarketMakerPairs[sender] && !automatedMarketMakerPairs[recipient]);
            super._transfer(sender, address(this), _DAOfee);
			super._transfer(sender, marketing, _marketingFee);
			super._transfer(sender, staking, _stakingFee);
            super._transfer(sender, recipient, amount.sub(_DAOfee).sub(_marketingFee).sub(_stakingFee));
        }
    }

	function collectFee(uint256 amount, bool sell, bool p2p) private view returns (uint256, uint256, uint256) {
        uint256 _DAOFee = amount.mul(p2p ? DAOFee[2] : sell ? DAOFee[1] : DAOFee[0]).div(10000);
		uint256 _marketingFee = amount.mul(p2p ? marketingFee[2] : sell ? marketingFee[1] : marketingFee[0]).div(10000);
		uint256 _stakingFee = amount.mul(p2p ? stakingPoolFee[2] : sell ? stakingPoolFee[1] : stakingPoolFee[0]).div(10000);
        return (_DAOFee, _marketingFee, _stakingFee);
    }

	function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}