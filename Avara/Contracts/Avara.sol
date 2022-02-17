/**
    ***********************************************************
    * Copyright (c) Avara Dev. 2022. (Telegram: @avara_cc)  *
    ***********************************************************

     ▄▄▄·  ▌ ▐· ▄▄▄· ▄▄▄   ▄▄▄·
    ▐█ ▀█ ▪█·█▌▐█ ▀█ ▀▄ █·▐█ ▀█
    ▄█▀▀█ ▐█▐█•▄█▀▀█ ▐▀▀▄ ▄█▀▀█
    ▐█ ▪▐▌ ███ ▐█ ▪▐▌▐█•█▌▐█ ▪▐▌
     ▀  ▀ . ▀   ▀  ▀ .▀  ▀ ▀  ▀  - Ethereum Network

    Avara - Always Vivid, Always Rising Above
    https://avara.cc/
    https://github.com/avara-cc
    https://github.com/avara-cc/AvaraETH/wiki
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./abstract/Context.sol";
import "./interface/common/IERC20.sol";
import "./abstract/Ownable.sol";
import "./library/SafeMath.sol";
import "./interface/uniswap/IUniswapV3Pool.sol";
import "./interface/uniswap/IUniswapV3Router.sol";
import "./interface/common/IERC20Metadata.sol";

contract Avara is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;

    //
    // Reward, fee and wallet related variables.
    //
    mapping(address => uint256) private _rewardOwned;
    mapping(address => uint256) private _tokenOwned;
    mapping(address => bool)    private _isExcludedFromFee;
    mapping(address => bool)    private _isExcluded;
    mapping(address => mapping(address => uint256)) private _allowances;

    address[] private _excluded;
    address public _devWallet;

    //
    // Summary of the fees
    //
    uint256 private _bitDuelServiceFeeTotal;
    uint256 private _developerFeeTotal;
    uint256 private _eventFeeTotal;
    uint256 private _feeTotal;
    uint256 private _marketingFeeTotal;

    //
    // AvaraToken metadata
    //
    string private constant _name = "AVARA";
    string private constant _symbol = "AVR";
    uint8 private constant _decimals = 9;

    // 20% Maximum Total Fee (used for validation)
    uint256 public constant MAX_TOTAL_FEE = 2000;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _totalSupply = 500000000 * 10 ** uint256(_decimals);
    uint256 private _rewardSupply = (MAX - (MAX % _totalSupply));

    // 0.2% is going to the be the founding of the upcoming Events
    uint256 public _eventFee = 20;
    // 0.4% is going to Marketing.
    uint256 public _marketingFee = 40;
    // 0.4% is going to the Developers.
    uint256 public _developerFee = 40;
    // 1% service fee on BitDuel.
    uint256 public _bitDuelServiceFee = 100;

    // Sell pressure reduced by 15x
    uint256 public _sellPressureReductor = 1500;
    uint8 public _sellPressureReductorDecimals = 2;

    uint256 public _maxTxAmount = 250000000 * 10 ** uint256(_decimals);
    bool public _rewardEnabled = true;

    //
    // BitDuel
    //
    mapping(address => uint256) private _playerPool;
    address public _playerPoolWallet;

    // A constant, used for checking the connection between the server and the contract.
    string private constant _pong = "PONG";

    //
    // Liquidity related fields.
    //

    IUniswapV3Pool public _uniswapV3Pool;
    IUniswapV3Router public _uniswapV3Router;

    event BitDuelServiceFeeChanged(uint256 oldFee, uint256 newFee);
    event DeveloperFeeChanged(uint256 oldFee, uint256 newFee);
    event DevWalletChanged(address oldAddress, address newAddress);
    event EventFeeChanged(uint256 oldFee, uint256 newFee);
    event FallBack(address sender, uint value);
    event MarketingFeeChanged(uint256 oldFee, uint256 newFee);
    event MaxTransactionAmountChanged(uint256 oldAmount, uint256 newAmount);
    event PlayerPoolChanged(address oldAddress, address newAddress);
    event Received(address sender, uint value);
    event RewardEnabledStateChanged(bool oldState, bool newState);
    event SellPressureReductorChanged(uint256 oldReductor, uint256 newReductor);
    event SellPressureReductorDecimalsChanged(uint8 oldDecimals, uint8 newDecimals);
    event UniswapPoolChanged(address oldAddress, address newAddress);
    event UniswapRouterChanged(address oldAddress, address newAddress);

    /**
    * @dev Executed on a call to the contract with empty call data.
    */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
    * @dev Executed on a call to the contract that does not match any of the contract functions.
    */
    fallback() external payable {
        emit FallBack(msg.sender, msg.value);
    }

    //
    // The token constructor.
    //

    constructor (address cOwner, address devWallet, address playerPoolWallet) Ownable(cOwner) {
        _devWallet = devWallet;
        _playerPoolWallet = playerPoolWallet;

        _rewardOwned[cOwner] = _rewardSupply;
        _uniswapV3Router = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        // Exclude the system addresses from the fee.
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_devWallet] = true;

        emit Transfer(address(0), cOwner, _totalSupply);
    }

    //
    // Contract Modules
    //

    struct Module {
        string moduleName;
        string moduleVersion;
        address moduleAddress;
    }

    Module[] private modules;

    event ModuleAdded(address moduleAddress, string moduleName, string moduleVersion);
    event ModuleRemoved(string moduleName);

    /**
    * @dev Adds a module to the contract with the given ModuleName and Version on the given ModuleAddress.
    */
    function addModule(string memory moduleName, string memory moduleVersion, address moduleAddress) external onlyOwner {
        Module memory module;
        module.moduleVersion = moduleVersion;
        module.moduleAddress = moduleAddress;
        module.moduleName = moduleName;

        bool added = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (keccak256(abi.encodePacked(modules[i].moduleName)) == keccak256(abi.encodePacked(moduleName))) {
                modules[i] = module;
                added = true;
            }
        }

        if (!added) {
            modules.push(module);

            emit ModuleAdded(moduleAddress, moduleName, moduleVersion);
        }
    }

    /**
    * @dev Removes a module from the contract.
    */
    function removeModule(string memory moduleName) external onlyOwner {
        uint256 index;
        bool found = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (keccak256(abi.encodePacked(modules[i].moduleName)) == keccak256(abi.encodePacked(moduleName))) {
                index = i;
                found = true;
            }
        }

        if (found) {
            modules[index] = modules[modules.length - 1];
            delete modules[modules.length - 1];
            modules.pop();

            emit ModuleRemoved(moduleName);
        }
    }

    /**
    * @dev Retrieves a 2-tuple (success? + search result) by the given ModuleName.
    */
    function getModule(string memory moduleName) external view returns (bool, Module memory) {
        Module memory result;
        bool found = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (keccak256(abi.encodePacked(modules[i].moduleName)) == keccak256(abi.encodePacked(moduleName))) {
                result = modules[i];
                found = true;
            }
        }
        return (found, result);
    }

    /**
    * @dev A modifier that requires the message sender to be the owner of the contract or a Module on the contract.
    */
    modifier onlyOwnerOrModule() {
        bool isModule = false;
        for (uint256 i = 0; i < modules.length; i++) {
            if (modules[i].moduleAddress == _msgSender()) {
                isModule = true;
            }
        }

        require(isModule || owner() == _msgSender(), "The caller is not the owner nor an authenticated Avara module!");
        _;
    }

    //
    // BitDuel functions
    //

    /**
    * @dev Occasionally called (only) by the server to make sure that the connection with the contract is granted.
    */
    function ping() external view onlyOwnerOrModule returns (string memory) {
        return _pong;
    }

    /**
    * @dev A function used to withdraw from the player pool.
    */
    function withdraw(uint256 amount) external {
        require(_playerPool[_msgSender()] >= amount, "Invalid amount!");
        _transfer(_playerPoolWallet, _msgSender(), amount);
        _playerPool[_msgSender()] -= amount;
    }

    /**
    * @dev Retrieve the balance of a player from the player pool.
    */
    function balanceInPlayerPool(address playerAddress) external view returns (uint256) {
        return _playerPool[playerAddress];
    }

    /**
    * @dev Called by BitDuel after a won / lost game, to set the new balance of a user in the player pool.
    * The gas price is provided by BitDuel.
    */
    function setPlayerBalance(address playerAddress, uint256 balance) external onlyOwnerOrModule {
        _playerPool[playerAddress] = balance;
    }

    //
    // Reward and Token related functionalities
    //

    struct RewardValues {
        uint256 rAmount;
        uint256 rTransferAmount;
        uint256 rewardMarketingFee;
        uint256 rewardDeveloperFee;
        uint256 rewardEventFee;
        uint256 rewardBitDuelServiceFee;
    }

    struct TokenValues {
        uint256 tTransferAmount;
        uint256 bitDuelServiceFee;
        uint256 marketingFee;
        uint256 developerFee;
        uint256 eventFee;
    }

    /**
    * @dev Retrieves the Reward equivalent of the given Token amount. (With the Fees optionally included or excluded.)
    */
    function rewardFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= _totalSupply, "The amount must be less than the supply!");

        if (!deductTransferFee) {
            uint256 currentRate = _getRate();
            (TokenValues memory tv) = _getTokenValues(tAmount, address(0));
            (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

            return rv.rAmount;
        } else {
            uint256 currentRate = _getRate();
            (TokenValues memory tv) = _getTokenValues(tAmount, address(0));
            (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

            return rv.rTransferAmount;
        }
    }

    /**
    * @dev Retrieves the Token equivalent of the given Reward amount.
    */
    function tokenFromReward(uint256 rAmount) public view returns (uint256) {
        require(rAmount <= _rewardSupply, "The amount must be less than the total rewards!");

        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    /**
    * @dev Excludes an address from the Reward process.
    */
    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "The account is already excluded!");

        if (_rewardOwned[account] > 0) {
            _tokenOwned[account] = tokenFromReward(_rewardOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
    * @dev Includes an address in the Reward process.
    */
    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "The account is already included!");

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tokenOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    /**
    * @dev Retrieves the Total Fees deducted to date.
    */
    function totalFees() public view returns (uint256) {
        return _feeTotal;
    }

    /**
    * @dev Retrieves the Total Marketing Fees deducted to date.
    */
    function totalMarketingFees() public view returns (uint256) {
        return _marketingFeeTotal;
    }

    /**
    * @dev Retrieves the Total Event Fees deducted to date.
    */
    function totalEventFees() public view returns (uint256) {
        return _eventFeeTotal;
    }

    /**
    * @dev Retrieves the Total Development Fees deducted to date.
    */
    function totalDevelopmentFees() public view returns (uint256) {
        return _developerFeeTotal;
    }

    /**
    * @dev Retrieves the Total BitDuel Service Fees deducted to date.
    */
    function totalBitDuelServiceFees() public view returns (uint256) {
        return _bitDuelServiceFeeTotal;
    }

    /**
    * @dev Excludes an address from the Fee process.
    */
    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    /**
    * @dev Includes an address in the Fee process.
    */
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    /**
    * @dev Sets the given address as the Developer Wallet.
    */
    function setDevWallet(address devWallet) external onlyOwner {
        address oldAddress = _devWallet;
        _isExcludedFromFee[oldAddress] = false;
        _devWallet = devWallet;
        _isExcludedFromFee[_devWallet] = true;

        emit DevWalletChanged(oldAddress, _devWallet);
    }

    /**
    * @dev Sets the given address as the Player Pool Hot Wallet.
    */
    function setPlayerPoolWallet(address playerPoolWallet) external onlyOwner {
        address oldAddress = _playerPoolWallet;
        _playerPoolWallet = playerPoolWallet;

        emit PlayerPoolChanged(oldAddress, _playerPoolWallet);
    }

    /**
    * @dev Sets the Marketing Fee percentage.
    */
    function setMarketingFeePercent(uint256 marketingFee) external onlyOwner {
        require(marketingFee.add(_developerFee).add(_eventFee) <= MAX_TOTAL_FEE, "Too high fees!");
        require(marketingFee.add(_developerFee).add(_eventFee).mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals)) <= MAX_TOTAL_FEE, "Too harsh sell pressure reductor!");

        uint256 oldFee = _marketingFee;
        _marketingFee = marketingFee;

        emit MarketingFeeChanged(oldFee, _marketingFee);
    }

    /**
    * @dev Sets the Developer Fee percentage.
    */
    function setDeveloperFeePercent(uint256 developerFee) external onlyOwner {
        require(developerFee.add(_marketingFee).add(_eventFee) <= MAX_TOTAL_FEE, "Too high fees!");
        require(developerFee.add(_marketingFee).add(_eventFee).mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals)) <= MAX_TOTAL_FEE, "Too harsh sell pressure reductor!");

        uint256 oldFee = _developerFee;
        _developerFee = developerFee;

        emit DeveloperFeeChanged(oldFee, _developerFee);
    }

    /**
    * @dev Sets the BitDuel Service Fee percentage.
    */
    function setBitDuelServiceFeePercent(uint256 bitDuelServiceFee) external onlyOwner {
        require(bitDuelServiceFee <= MAX_TOTAL_FEE, "Too high fee!");

        uint256 oldFee = _bitDuelServiceFee;
        _bitDuelServiceFee = bitDuelServiceFee;

        emit BitDuelServiceFeeChanged(oldFee, _bitDuelServiceFee);
    }

    /**
    * @dev Sets the Event Fee percentage.
    */
    function setEventFeePercent(uint256 eventFee) external onlyOwner {
        require(eventFee.add(_marketingFee).add(_developerFee) <= MAX_TOTAL_FEE, "Too high fees!");
        require(eventFee.add(_marketingFee).add(_developerFee).mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals)) <= MAX_TOTAL_FEE, "Too harsh sell pressure reductor!");

        uint256 oldFee = _eventFee;
        _eventFee = eventFee;

        emit EventFeeChanged(oldFee, _eventFee);
    }

    /**
    * @dev Sets the value of the Sell Pressure Reductor.
    */
    function setSellPressureReductor(uint256 reductor) external onlyOwner {
        require(_eventFee.add(_marketingFee).add(_developerFee).mul(reductor).div(10 ** uint256(_sellPressureReductorDecimals)) <= MAX_TOTAL_FEE, "Too harsh sell pressure reductor!");

        uint256 oldReductor = _sellPressureReductor;
        _sellPressureReductor = reductor;

        emit SellPressureReductorChanged(oldReductor, _sellPressureReductor);
    }

    /**
    * @dev Sets the decimal points of the Sell Pressure Reductor.
    */
    function setSellPressureReductorDecimals(uint8 reductorDecimals) external onlyOwner {
        require(_eventFee.add(_marketingFee).add(_developerFee).mul(_sellPressureReductor).div(10 ** uint256(reductorDecimals)) <= MAX_TOTAL_FEE, "Too harsh sell pressure reductor!");

        uint8 oldReductorDecimals = _sellPressureReductorDecimals;
        _sellPressureReductorDecimals = reductorDecimals;

        emit SellPressureReductorDecimalsChanged(oldReductorDecimals, _sellPressureReductorDecimals);
    }

    /**
    * @dev Sets the maximum transaction amount. (calculated by the given percentage)
    */
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        uint256 oldAmount = _maxTxAmount;
        _maxTxAmount = _totalSupply.mul(maxTxPercent).div(100);

        emit MaxTransactionAmountChanged(oldAmount, _maxTxAmount);
    }

    /**
    * @dev Sets the value of the `_rewardEnabled` variable.
    */
    function setRewardEnabled(bool enabled) external onlyOwner {
        bool oldState = _rewardEnabled;
        _rewardEnabled = enabled;

        emit RewardEnabledStateChanged(oldState, _rewardEnabled);
    }

    /**
    * @dev Retrieves if the given address is excluded from the Fee process.
    */
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
    * @dev Retrieves if the given address is excluded from the Reward process.
    */
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    /**
    * @dev Sets the given address as the Uniswap Router.
    */
    function setUniswapRouter(address r) external onlyOwner {
        address oldRouter = address(_uniswapV3Router);
        _uniswapV3Router = IUniswapV3Router(r);

        emit UniswapRouterChanged(oldRouter, address(_uniswapV3Router));
    }

    /**
    * @dev Sets the given address as the Uniswap Pool.
    */
    function setUniswapPool(address p) external onlyOwner {
        address oldPool = address(_uniswapV3Pool);
        _uniswapV3Pool = IUniswapV3Pool(p);

        emit UniswapPoolChanged(oldPool, address(_uniswapV3Pool));
    }

    //
    // The Implementation of the IERC20 Functions
    //

    /**
    * @dev A function used to retrieve the stuck eth from the contract.
    */
    function unstickEth(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Invalid amount!");
        payable(_msgSender()).transfer(amount);
    }

    /**
    * @dev A function used to retrieve the stuck tokens from the contract.
    */
    function unstickTokens(uint256 amount) external onlyOwner {
        require(balanceOf(address(this)) >= amount, "Invalid amount!");
        _transfer(address(this), _msgSender(), amount);
    }

    /**
    * @dev Retrieves the Total Supply of the token.
    */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Retrieves the Name of the token.
    */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
    * @dev Retrieves the Symbol of the token.
    */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
    * @dev Retrieves the Decimals of the token.
    */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
    * @dev Retrieves the Balance Of the given address.
    * Note: If the address is included in the Reward process, retrieves the Token equivalent of the held Reward amount.
    */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tokenOwned[account];
        return tokenFromReward(_rewardOwned[account]);
    }

    /**
    * @dev Transfers the given Amount of tokens (minus the fees, if any) from the
    * Message Senders wallet to the Recipients wallet.
    *
    * Note: If the Recipient is the Player Pool Hot Wallet, the Message Sender will be able to play with
    * the transferred amount of Tokens on BitDuel.
    */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        if (recipient == _playerPoolWallet) {
            _playerPool[_msgSender()] += _transfer(_msgSender(), recipient, amount);
        } else {
            _transfer(_msgSender(), recipient, amount);
        }
        return true;
    }

    /**
    * @dev Retrieves the Allowance of the given Spender address in the given Owner wallet.
    */
    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
    * @dev Approves the given amount for the given Spender address in the Message Sender wallet.
    */
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
    * @dev Transfers the given Amount of tokens from the Sender to the Recipient address
    * if the Sender approved on the Message Sender allowances.
    */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: The transfer amount exceeds the allowance."));
        return true;
    }

    //
    // Transfer and Approval processes
    //

    /**
    * @dev Approves the given amount for the given Spender address in the Owner wallet.
    */
    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: Cannot approve from the zero address.");
        require(spender != address(0), "ERC20: Cannot approve to the zero address.");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Transfers from and to the given address the given amount of token.
     */
    function _transfer(address from, address to, uint256 amount) private returns (uint256) {
        require(from != address(0), "ERC20: Cannot transfer from the zero address.");
        require(to != address(0), "ERC20: Cannot transfer to the zero address.");
        require(amount > 0, "The transfer amount must be greater than zero!");

        if (from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "The transfer amount exceeds the maxTxAmount.");
        }

        bool takeFee = !(_isExcludedFromFee[from] || _isExcludedFromFee[to] || from == _playerPoolWallet);
        return _tokenTransfer(from, to, amount, takeFee);
    }

    /**
    * @dev Transfers the given Amount of tokens (minus the fees, if any) from the
    * Senders wallet to the Recipients wallet.
    */
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private returns (uint256) {
        uint256 previousBitDuelServiceFee = _bitDuelServiceFee;
        uint256 previousDeveloperFee = _developerFee;
        uint256 previousEventFee = _eventFee;
        uint256 previousMarketingFee = _marketingFee;

        if (!takeFee) {
            _bitDuelServiceFee = 0;
            _developerFee = 0;
            _eventFee = 0;
            _marketingFee = 0;
        }

        uint256 transferredAmount;
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            transferredAmount = _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            transferredAmount = _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            transferredAmount = _transferBothExcluded(sender, recipient, amount);
        } else {
            transferredAmount = _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) {
            _bitDuelServiceFee = previousBitDuelServiceFee;
            _developerFee = previousDeveloperFee;
            _eventFee = previousEventFee;
            _marketingFee = previousMarketingFee;
        }

        return transferredAmount;
    }

    /**
    * @dev The Transfer function used when both the Sender and Recipient is included in the Reward process.
    */
    function _transferStandard(address sender, address recipient, uint256 tAmount) private returns (uint256) {
        uint256 currentRate = _getRate();
        (TokenValues memory tv) = _getTokenValues(tAmount, recipient);
        (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

        _rewardOwned[sender] = _rewardOwned[sender].sub(rv.rAmount);
        _rewardOwned[recipient] = _rewardOwned[recipient].add(rv.rTransferAmount);

        takeTransactionFee(_devWallet, tv, currentRate, recipient);
        if (_rewardEnabled) {
            _rewardFee(rv);
        }
        _countTotalFee(tv);
        emit Transfer(sender, recipient, tv.tTransferAmount);

        return tv.tTransferAmount;
    }

    /**
    * @dev The Transfer function used when both the Sender and Recipient is excluded from the Reward process.
    */
    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private returns (uint256) {
        uint256 currentRate = _getRate();
        (TokenValues memory tv) = _getTokenValues(tAmount, recipient);
        (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

        _tokenOwned[sender] = _tokenOwned[sender].sub(tAmount);
        _rewardOwned[sender] = _rewardOwned[sender].sub(rv.rAmount);
        _tokenOwned[recipient] = _tokenOwned[recipient].add(tv.tTransferAmount);
        _rewardOwned[recipient] = _rewardOwned[recipient].add(rv.rTransferAmount);

        takeTransactionFee(_devWallet, tv, currentRate, recipient);
        if (_rewardEnabled) {
            _rewardFee(rv);
        }
        _countTotalFee(tv);
        emit Transfer(sender, recipient, tv.tTransferAmount);

        return tv.tTransferAmount;
    }

    /**
    * @dev The Transfer function used when the Sender is included and the Recipient is excluded in / from the Reward process.
    */
    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private returns (uint256) {
        uint256 currentRate = _getRate();
        (TokenValues memory tv) = _getTokenValues(tAmount, recipient);
        (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

        _rewardOwned[sender] = _rewardOwned[sender].sub(rv.rAmount);
        _tokenOwned[recipient] = _tokenOwned[recipient].add(tv.tTransferAmount);
        _rewardOwned[recipient] = _rewardOwned[recipient].add(rv.rTransferAmount);

        takeTransactionFee(_devWallet, tv, currentRate, recipient);
        if (_rewardEnabled) {
            _rewardFee(rv);
        }
        _countTotalFee(tv);
        emit Transfer(sender, recipient, tv.tTransferAmount);

        return tv.tTransferAmount;
    }

    /**
    * @dev The Transfer function used when the Sender is excluded and the Recipient is included from / in the Reward process.
    */
    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private returns (uint256) {
        uint256 currentRate = _getRate();
        (TokenValues memory tv) = _getTokenValues(tAmount, recipient);
        (RewardValues memory rv) = _getRewardValues(tAmount, tv, currentRate);

        _tokenOwned[sender] = _tokenOwned[sender].sub(tAmount);
        _rewardOwned[sender] = _rewardOwned[sender].sub(rv.rAmount);
        _rewardOwned[recipient] = _rewardOwned[recipient].add(rv.rTransferAmount);

        takeTransactionFee(_devWallet, tv, currentRate, recipient);
        if (_rewardEnabled) {
            _rewardFee(rv);
        }
        _countTotalFee(tv);
        emit Transfer(sender, recipient, tv.tTransferAmount);

        return tv.tTransferAmount;
    }

    /**
    * @dev Takes the Reward Fees from the Reward Supply.
    */
    function _rewardFee(RewardValues memory rv) private {
        _rewardSupply = _rewardSupply.sub(rv.rewardMarketingFee).sub(rv.rewardDeveloperFee).sub(rv.rewardEventFee).sub(rv.rewardBitDuelServiceFee);
    }

    /**
    * @dev Updates the Fee Counters by the Taken Fees.
    */
    function _countTotalFee(TokenValues memory tv) private {
        _marketingFeeTotal = _marketingFeeTotal.add(tv.marketingFee);
        _developerFeeTotal = _developerFeeTotal.add(tv.developerFee);
        _eventFeeTotal = _eventFeeTotal.add(tv.eventFee);
        _bitDuelServiceFeeTotal = _bitDuelServiceFeeTotal.add(tv.bitDuelServiceFee);
        _feeTotal = _feeTotal.add(tv.marketingFee).add(tv.developerFee).add(tv.eventFee).add(tv.bitDuelServiceFee);
    }

    /**
    * @dev Calculates the Token Values after taking the Fees.
    */
    function _getTokenValues(uint256 tAmount, address recipient) private view returns (TokenValues memory) {
        TokenValues memory tv;
        uint256 tTransferAmount = tAmount;

        if (recipient == _playerPoolWallet) {
            uint256 bitDuelServiceFee = tAmount.mul(_bitDuelServiceFee).div(10000);
            tTransferAmount = tTransferAmount.sub(bitDuelServiceFee);

            tv.tTransferAmount = tTransferAmount;
            tv.bitDuelServiceFee = bitDuelServiceFee;

            return (tv);
        }

        uint256 marketingFee = tAmount.mul(_marketingFee).div(10000);
        uint256 developerFee = tAmount.mul(_developerFee).div(10000);
        uint256 eventFee = tAmount.mul(_eventFee).div(10000);

        if (recipient == address(_uniswapV3Pool)) {
            marketingFee = marketingFee.mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals));
            developerFee = developerFee.mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals));
            eventFee = eventFee.mul(_sellPressureReductor).div(10 ** uint256(_sellPressureReductorDecimals));
        }

        tTransferAmount = tTransferAmount.sub(marketingFee).sub(developerFee).sub(eventFee);

        tv.tTransferAmount = tTransferAmount;
        tv.marketingFee = marketingFee;
        tv.developerFee = developerFee;
        tv.eventFee = eventFee;

        return (tv);
    }

    /**
    * @dev Calculates the Reward Values after taking the Fees.
    */
    function _getRewardValues(uint256 tAmount, TokenValues memory tv, uint256 currentRate) private pure returns (RewardValues memory) {
        RewardValues memory rv;

        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rewardBitDuelServiceFee = tv.bitDuelServiceFee.mul(currentRate);
        uint256 rewardMarketingFee = tv.marketingFee.mul(currentRate);
        uint256 rewardDeveloperFee = tv.developerFee.mul(currentRate);
        uint256 rewardEventFee = tv.eventFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rewardMarketingFee).sub(rewardDeveloperFee).sub(rewardEventFee).sub(rewardBitDuelServiceFee);

        rv.rAmount = rAmount;
        rv.rTransferAmount = rTransferAmount;
        rv.rewardBitDuelServiceFee = rewardBitDuelServiceFee;
        rv.rewardMarketingFee = rewardMarketingFee;
        rv.rewardDeveloperFee = rewardDeveloperFee;
        rv.rewardEventFee = rewardEventFee;

        return (rv);
    }

    /**
    * @dev Retrieves the Rate between the Reward and Token Supply.
    */
    function _getRate() private view returns (uint256) {
        (uint256 rewardSupply, uint256 tokenSupply) = _getCurrentSupply();
        return rewardSupply.div(tokenSupply);
    }

    /**
    * @dev Retrieves the current Reward and Token Supply.
    */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rewardSupply = _rewardSupply;
        uint256 tokenSupply = _totalSupply;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rewardOwned[_excluded[i]] > rewardSupply || _tokenOwned[_excluded[i]] > tokenSupply) return (_rewardSupply, _totalSupply);
            rewardSupply = rewardSupply.sub(_rewardOwned[_excluded[i]]);
            tokenSupply = tokenSupply.sub(_tokenOwned[_excluded[i]]);
        }
        if (rewardSupply < _rewardSupply.div(_totalSupply)) return (_rewardSupply, _totalSupply);
        return (rewardSupply, tokenSupply);
    }

    /**
    * @dev Takes the given Fees.
    */
    function takeTransactionFee(address to, TokenValues memory tv, uint256 currentRate, address recipient) private {
        uint256 totalFee = recipient == _playerPoolWallet ? (tv.bitDuelServiceFee) : (tv.marketingFee + tv.developerFee + tv.eventFee);

        if (totalFee <= 0) {return;}

        uint256 rAmount = totalFee.mul(currentRate);
        _rewardOwned[to] = _rewardOwned[to].add(rAmount);
        if (_isExcluded[to]) {
            _tokenOwned[to] = _tokenOwned[to].add(totalFee);
        }
    }
}
