// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;


import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libs/SushiLibs.sol";


contract MPCKT is Ownable, IERC20, IERC20Metadata, AccessControlEnumerable, Pausable {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // standard ERC20 vars
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    uint256 private _totalBurned;
    uint256 private _totalMinted;
    string private _name;
    string private _symbol;


    // role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant CAN_TRANSFER_ROLE = keccak256("CAN_TRANSFER_ROLE");
    bytes32 public constant TEAM_ROLE = keccak256("TEAM_ROLE");

    // flag to stop swaps before there is LP 
    bool tradingActive;

    // The burn address
    address public constant burnAddress = address(0xdead);

    // the max tokens that can ever exist
    uint256 public maxSupply;

    // Ops address 
    address payable operationsWallet;

    // Derv address 
    address payable devWallet;

    // Vault address
    address payable vaultAddress;

    bool private _isSwapping;

    EnumerableSet.AddressSet private _amms;
    EnumerableSet.AddressSet private _systemContracts;
    EnumerableSet.AddressSet private _excludeTaxes;
    EnumerableSet.AddressSet private _excludeLocks;

    // TAX SETTINGS
    bool public normalTax; 

    uint256 public initialBuyTax=20;
    uint256 public initialSellTax=40;
    uint256 private finalTaxAt=30;

    uint256 private reduceEvery=5;
    uint256 private reduceBuyBy=2;
    uint256 private reduceSellBy=5;

    uint256 public buyCount=0;
    uint256 public sellCount=0;

    // Main Taxes
    // hard coded max tax limit for normal taxes
    // this tax amount is what is taken from the tx
    uint256 constant _maxTax = 25;

    // % taxed on sells
    uint256 public sellTax = 7;

    // % taxed and burned on buys
    uint256 public buyTax = 7;


    // Sub-Taxes
    // the main tax is broken down into sub-taxes
    // % of post taxed amount that is sent to the vault contract
    uint256 vaultTax = 43;
    // % of post taxed amount that is sent to operations wallet
    uint256 operationsTax = 14;
    // % of post taxed amount that sent to the dev
    uint256 devTax = 14;
    // % of post taxed amount that is burned
    uint256 burnTax = 29;
    
    /**
     * Anti-Dump & Anti-Bot Settings
     **/

    // a hard capped number on the max tokens that can be sold in one TX
    uint256 maxSell;

    // max % sell of total supply that can be sold in one TX, default 1%
    uint256 maxSellPercent = 100; 

    // min tokens to collect before swapping for fees
    uint256 private swapThresh;

    // max tokens a wallet can hold, defaults to 1% initial supply
    uint256 public maxWallet;

    // seconds to lock transactions to aything but system contracts after a sell
    uint256 txLockTime;
    mapping (address => uint256) private txLock;

    // router
    address public immutable lpAddress; 
    IUniswapV2Router02 private  _swapRouter; 

    address private immutable Router;

    constructor(
        string memory name_, 
        string memory symbol_,
        uint256 _maxSupply,
        address payable _operationsWallet,
        address payable _devWallet,
        address payable _vaultAddress,
        address _router
    ) {
        
        require(_router != address(0), "ERC20: router not set");
        require(_operationsWallet != address(0), "ERC20: operations address not set");

        _name = name_;
        _symbol = symbol_;

        Router = _router;

        operationsWallet = _operationsWallet;
        devWallet = _devWallet;
        vaultAddress = _vaultAddress;

        maxSupply = _maxSupply;

        _swapRouter = IUniswapV2Router02(Router);
        lpAddress = IUniswapV2Factory(_swapRouter.factory()).createPair(address(this), _swapRouter.WETH());

        _amms.add(lpAddress);

        require(
            _excludeTaxes.add(address(0)) && 
            _excludeTaxes.add(msg.sender) && 
            _excludeTaxes.add(address(this)) && 

            _excludeLocks.add(address(0)) &&
            _excludeLocks.add(msg.sender) && 
            _excludeLocks.add(address(this)) &&
        
            _systemContracts.add(address(0)) &&
            _systemContracts.add(address(this)) &&
            _systemContracts.add(_vaultAddress) &&
            _systemContracts.add(_operationsWallet) &&
            _systemContracts.add(_devWallet), "error adding to lists");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(CAN_TRANSFER_ROLE, msg.sender);
        _grantRole(CAN_TRANSFER_ROLE, address(_operationsWallet));
        _grantRole(CAN_TRANSFER_ROLE, address(_devWallet));
        _grantRole(CAN_TRANSFER_ROLE, address(_vaultAddress));

    }

    // modifier for functions only the team can call
    modifier onlyTeam() {
        require(hasRole(TEAM_ROLE,  msg.sender) || msg.sender == owner(), "Caller not in Team");
        _;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the a minter.
    function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE) {
        require(hasRole(MINTER_ROLE, msg.sender), "ERC20: must have minter role to mint");
        require(_totalSupply + _amount <= maxSupply, 'ERC20: Max Supply Reached');
        _mint(_to, _amount);
    }

     /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    
    function burn(uint256 _amount) external virtual {
        _burn(msg.sender, _amount);
    }

    /**
     * @dev pause the token for transfers other than addresses with the CanTransfer Role
     */
    function pause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "ERC20: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev unpause the token for anyone to transfer
     */
    function unpause() external {
        require(hasRole(PAUSER_ROLE, msg.sender), "ERC20: must have pauser role to unpause");
        _unpause();
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {

        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        bool isBuy = _amms.contains(sender);
        bool isSell = _amms.contains(recipient);
        bool isToSystem = _systemContracts.contains(recipient);
        bool isFromSystem = _systemContracts.contains(sender) || sender == address(_swapRouter);
        uint256 postTaxAmount = amount;

        require(isToSystem || isSell || ( _balances[recipient] + amount) <= maxWallet, 'Max Wallet' );

        require(tradingActive || isToSystem || isFromSystem || (!isSell && !isBuy), 'Trading not started' );

        if(recipient == burnAddress){
            _burn(sender,amount);
        } else {

            require(isFromSystem || isToSystem || txLock[sender] <= block.timestamp, "ERC20: Transactions Locked");

            unchecked {
                _balances[sender] -= amount;
            }
            
            uint256 toBurn;
            if(tradingActive){
                if(isSell){
                    // make sure we we aren't getting dumpped on
                    if(!isToSystem && !isFromSystem){
                        uint256 maxPercentAmount = (_totalSupply * maxSellPercent)/10000;
                        if(maxPercentAmount < maxSell){
                            maxPercentAmount = maxSell;
                        }
                        require(
                            (maxSell == 0 || amount <= maxSell) && 
                            (maxPercentAmount == 0 || amount <= maxPercentAmount), 
                            'ERC20: Y Dump?');
                    }

                    
                    // see if we need to tax 
                    if(!_isSwapping && !isToSystem && !isFromSystem && !_excludeTaxes.contains(sender) && sellTax > 0){
                         // lock the sells for the cool down peirod
                        _setTxLock(sender);
                        
                        (postTaxAmount, toBurn) = _takeTax(amount, (normalTax || buyCount>finalTaxAt)?sellTax:initialSellTax, true);
                        // (postTaxAmount, toBurn) = _takeTax(amount, sellTax, true);
                        sellCount++;
                    }
                    
                }

                if(isBuy){
                    if(!normalTax && buyCount>finalTaxAt){
                        normalTax = true;
                    }

                    // see if we need to tax 
                    if(!_isSwapping && !isToSystem && !isFromSystem && !_excludeTaxes.contains(recipient) && buyTax > 0){
                        (postTaxAmount, toBurn) = _takeTax(amount, (normalTax || buyCount>finalTaxAt)?buyTax:initialBuyTax, true);
                        // (postTaxAmount, toBurn) = _takeTax(amount, buyTax, false);
                        buyCount++;

                        if(!normalTax && buyCount%reduceEvery == 0){
                            initialBuyTax -= reduceBuyBy;
                            initialSellTax -= reduceSellBy;
                        }
                    }
                    

                    
                }
            }
            
            
            // burn
            if(toBurn > 0){
                _burn(address(this),toBurn);    
            }

            _balances[recipient] += postTaxAmount;

            emit Transfer(sender, recipient, postTaxAmount);

        }
    }

    function _takeTax(uint256 _amount, uint256 _tax, bool _doSwap) private returns(uint256, uint256){
       // calc the taxes 
        uint256 taxAmount = _calculateTax(_amount,_tax,100);
        
        // send the tax to the contract
        _balances[address(this)] += taxAmount;

        uint256 _postTax = _amount - taxAmount;
        uint256 _toBurn;
        uint256 _toDev;
        uint256 _toVault;
        uint256 _toOperations;

        if(_doSwap && _balances[address(this)] >= swapThresh){

            uint256 _toSwap = _balances[address(this)];

            uint256 _operationsTax = operationsTax;

            // if we are in launch mode, don't burn
            if(!normalTax){
                _operationsTax += burnTax;
            }

            // see if we have a burn tax before we swap
            if(normalTax && burnTax > 0){
                _toBurn = _calculateTax(_balances[address(this)], burnTax, 100);
                _toSwap -= _toBurn;
            }

            if(_toSwap > 0){
                _swapTokenForNative(_toSwap); 

                // breakdown the balance and distribute
                uint256 bal = address(this).balance;
                if(bal > 0){
                    uint256 remain = bal;
                    uint256 t = vaultTax + _operationsTax + devTax;

                    _toVault = _calculateTax(bal, vaultTax, t);
                    remain -= _toVault;

                    _toDev = _calculateTax(bal, devTax, t);
                    remain -= _toDev;

                    

                    if(_toVault > 0){
                        (bool vaultSent,) =address(vaultAddress).call{value: _toVault}("");
                        require(vaultSent,"dev send failed");
                    }

                    if(_toDev > 0){
                        (bool devSent,) =address(devWallet).call{value: _toDev}("");
                        require(devSent,"vault send failed");
                    }

                    _toOperations = address(this).balance;
                    if(_toOperations > 0){
                        (bool opsSent,) =address(devWallet).call{value: _toOperations}("");
                        require(opsSent,"ops send failed");
                    }

                }
            }
        }

        return (_postTax, _toBurn);
    }

    function _setTxLock(address _addr) private {    
        if(!_excludeLocks.contains(_addr) && txLockTime > 0){
            txLock[_addr] = block.timestamp + txLockTime;
        }
    }

    //Calculates the token that should be taxed
    function _calculateTax(uint256 amount, uint256 tax, uint256 taxPercent) private pure returns (uint256) {
        return (amount*tax*taxPercent) / 10000;
    }

    //swaps tokens for Native
    function _swapTokenForNative(uint256 amount) private {
        _isSwapping = true;
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();

        _approve(address(this), address(_swapRouter), amount);

        _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
       _isSwapping = false;
    }

    /**
     * Set the various taxes.
     * No tax can ever be higher than the global max
     **/
    event SetTaxes(uint256 sellTax, uint256 _buyTax);
    function setTaxes(
        uint256 _sellTax, 
        uint256 _buyTax
    ) external onlyTeam {
        require(
            _sellTax <= _maxTax && 
            _buyTax <= _maxTax, 'Tax too high'
        );

        sellTax = _sellTax;
        buyTax = _buyTax;

        emit SetTaxes(_sellTax, _buyTax);
    }


    event SetSubTaxes(uint256 vaultTax, uint256 devTax, uint256 operationsTax, uint256 burnTax);
    function setSubTaxes(
        uint256 _vaultTax,
        uint256 _devTax,
        uint256 _operationsTax,
        uint256 _burnTax
    ) external onlyTeam {
        require(_vaultTax + _devTax + _operationsTax + _burnTax  <= 100,'tax too high');
        vaultTax = _vaultTax;
        devTax = _devTax;
        operationsTax = _operationsTax;
        burnTax = _burnTax;

        emit SetSubTaxes(_vaultTax, _devTax, _operationsTax, _burnTax );
    }

    // update the sell protection settings
    event SetSellProtection(uint256 maxSell, uint256 maxSellPercent, uint256 txLock);
    function setSellProtection(uint256 _maxSell, uint256 _maxSellPercent, uint256 _txLockTime) external onlyTeam {
        // must be higher than 0.1% 
        require(_maxSellPercent > 10, 'Sell Percent too low');

        // must be lower or equal to 10% 
        require(_maxSellPercent <= 1000, 'Sell Percent too high');

        // lock time must a day or less
        require(_txLockTime <= 86400, 'lock time too long');
        
        maxSell = _maxSell;
        maxSellPercent = _maxSellPercent;
        txLockTime = _txLockTime;
        emit SetSellProtection(_maxSell, _maxSellPercent, _txLockTime);
    }

    event LimitsRemoved();
    function removeLimits() external onlyOwner{
        maxSell = 0;
        maxWallet = maxSupply;
        maxSellPercent = 10000;
        txLockTime = 0;
        normalTax=true;
        emit LimitsRemoved();
    }

    // when we want to push any loose change in the contract to the vault
    // we want to pause it while we do this
    function cleanupLeftovers() external onlyTeam {
        _pause();
        (bool sent, ) = payable(address(vaultAddress)).call{value: address(this).balance}("");
        require(sent, "Failed to send");
        _unpause();
    }

    // set max wallet to a given percent
    event SetMaxWallet(uint256 maxWallet);
    function setMaxWallet(uint256 _maxWallet) external onlyTeam {
        maxWallet = _maxWallet;
        emit SetMaxWallet(maxWallet);
    }

    event SetSwapThresh(uint256 swapThresh);
    function setSwapThresh(uint256 _swapThresh) external onlyTeam {
        swapThresh = _swapThresh;
        emit SetSwapThresh(_swapThresh);
    }
    
    // one time use, will enable trading after LP is setup
    event SetTradingActive();
    function setTradingActive() external onlyTeam {
        require(!tradingActive,"trading is already active");
        tradingActive = true;

        if(paused()){
            _unpause();
        }
        uint256 tokenBal = balanceOf(address(this));
        _approve(address(this), address(_swapRouter), tokenBal);

        _swapRouter.addLiquidityETH{value: address(this).balance}(address(this),tokenBal,0,0,owner(),block.timestamp);

        IERC20(lpAddress).approve(address(_swapRouter), type(uint256).max);
        emit SetTradingActive();
    }

    // manage the Enumerable Sets
    event AddAmmAddress(address amm);
    function addAmmAddress(address _amm) external onlyTeam {
        require(_amm != address(0), "Invalid Address");
        require(_amms.add(_amm), 'list error');
        emit AddAmmAddress(_amm);
    }

    event RemoveAmmAddress(address amm);
    function removeAmmAddress(address _amm) external onlyTeam {
        require(_amms.remove(_amm), 'list error');
        emit RemoveAmmAddress(_amm);
    }

    event AddSystemContract(address addr);
    function addSystemContractAddress(address _addr) external onlyTeam {
        require(_addr != address(0), "Invalid Address");
        require(_systemContracts.add(_addr), 'list error');
        emit AddSystemContract(_addr);
    }

    event RemoveSystemContract(address addr);
    function removeSystemContractAddress(address _addr) external onlyTeam {
        require(_systemContracts.remove(_addr), 'list error');
        emit RemoveSystemContract(_addr);
    }

    event AddExcludeTaxes(address addr);
    function addExcludeTaxesAddress(address _addr) external onlyTeam {
        require(_addr != address(0), "Invalid Address");
        require(_excludeTaxes.add(_addr), 'list error');
        emit AddExcludeTaxes(_addr);
    }

    event RemoveExcludeTaxes(address addr);
    function removeExcludeTaxesAddress(address _addr) external onlyTeam {
        require(_excludeTaxes.remove(_addr), 'list error');
        emit RemoveExcludeTaxes(_addr);
    }

    event AddExcludedLocks(address addr);
    function addExcludedLocksAddress(address _addr) external onlyTeam {
        require(_addr != address(0), "Invalid Address");
        require(_excludeLocks.add(_addr), 'list error');
        emit AddExcludedLocks(_addr);
    }

    event RemoveExcludedLocks(address addr);
    function removeExcludedLocksAddress(address _addr) external onlyTeam {
       require(_excludeLocks.remove(_addr), 'list error');
       emit RemoveExcludedLocks(_addr);
    }

    event SetVaultAddress(address oldAddress, address newAddress);
    function setVaultContract(address payable _vaultAddress) external onlyTeam {
        require(_vaultAddress != address(0), "ERC20: vault address not set");
        emit SetVaultAddress(_vaultAddress, vaultAddress);
        vaultAddress = _vaultAddress;
        _systemContracts.add(address(_vaultAddress));

    }

    event SetOperationsAddress(address oldAddress, address newAddress);
    function setOperationsAddress(address payable _operationsWallet) external onlyTeam {
        require(_operationsWallet != address(0), "ERC20: operationsWallet address not set");
        _systemContracts.remove(address(operationsWallet));
        emit SetOperationsAddress(operationsWallet, _operationsWallet);
        operationsWallet = _operationsWallet;
        _systemContracts.add(address(_operationsWallet));
    }

    event SetDevAddress(address oldAddress, address newAddress);
    function setDevAddress(address payable _devWallet) external onlyTeam {
        require(_devWallet != address(0), "ERC20: devWallet address not set");
        _systemContracts.remove(address(devWallet));
        emit SetDevAddress(devWallet, _devWallet);
        devWallet = _devWallet;
        _systemContracts.add(address(_devWallet));
    }



    /**
     * @dev Returns the name of the token.
     */
    function name() external view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }


    function decimals() external view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function totalBurned() external view returns (uint256) {
        return _totalBurned;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external virtual override returns (bool) {
       
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }

         _transfer(sender, recipient, amount);

        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    event MintTokens(address from, address to, uint256 amount);
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _totalMinted += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
        emit MintTokens(msg.sender, account, amount);

        
    }

    event BurnTokens(address from, address to, uint256 amount);
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

       _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
       require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;
        _totalBurned += amount;


        emit Transfer(account, address(0), amount);
        emit BurnTokens(msg.sender, account, amount);
        
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 
    ) internal virtual {
        // super._beforeTokenTransfer(from, to, amount);
        require(!paused() || hasRole(CAN_TRANSFER_ROLE, from) || hasRole(CAN_TRANSFER_ROLE, to) || _systemContracts.contains(from) || _systemContracts.contains(to), "ERC20Pausable: token transfer while paused");
    }

    // move any tokens sent to the contract
    function teamTransferToken(address tokenAddress, address recipient, uint256 amount) external onlyTeam {
        require(tokenAddress != address(0), "Invalid Address");
        IERC20 _token = IERC20(tokenAddress);
        _token.safeTransfer(recipient, amount);
    }


    // pull all the native out of the contract, needed for migrations/emergencies and transfers to other chains
    function withdrawETH() external onlyTeam {
         (bool sent,) =address(owner()).call{value: (address(this).balance)}("");
        require(sent,"withdraw failed");
    }

    receive() external payable {}
}