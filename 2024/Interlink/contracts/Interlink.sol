//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IFeeReceiver {
    function trigger() external;
}

/**
    Modular Upgradeable Token
 */
contract InterlinkToken is IERC20, Ownable {

    // total supply
    uint256 private _totalSupply = 100_000_000 * 10**18;

    // token data
    string private constant _name = 'InterLink';
    string private constant _symbol = 'ILA';
    uint8  private constant _decimals = 18;

    // balances
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    // Taxation on transfers
    uint256 public buyFee             = 500;
    uint256 public sellFee            = 500;
    uint256 public transferFee        = 0;
    uint256 public constant TAX_DENOM = 10000;

    // permissions
    struct Permissions {
        bool isFeeExempt;
        bool isLiquidityPool;
    }
    mapping ( address => Permissions ) public permissions;

    // Fee Recipients
    address public sellFeeRecipient;
    address public buyFeeRecipient;
    address public transferFeeRecipient;

    // Trigger Fee Recipients
    bool public triggerBuyRecipient = false;
    bool public triggerTransferRecipient = false;
    bool public triggerSellRecipient = false;

    // Whether or not the contract is paused
    bool public paused;
    
    constructor() {

        // exempt sender for tax-free initial distribution
        permissions[msg.sender].isFeeExempt = true;

        // initial supply allocation
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /////////////////////////////////
    /////    ERC20 FUNCTIONS    /////
    /////////////////////////////////

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
    
    function name() public pure override returns (string memory) {
        return _name;
    }

    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        require(
            _allowances[sender][msg.sender] >= amount,
            'Insufficient Allowance'
        );
        _allowances[sender][msg.sender] -= amount;
        return _transfer(sender, recipient, amount);
    }


    /////////////////////////////////
    /////   PUBLIC FUNCTIONS    /////
    /////////////////////////////////


    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external {
        require(
            _allowances[account][msg.sender] >= amount,
            'Insufficient Allowance'
        );
        _allowances[account][msg.sender] -= amount;
        _burn(account, amount);
    }

    receive() external payable {
        
    }

    /////////////////////////////////
    /////    OWNER FUNCTIONS    /////
    /////////////////////////////////

    function withdraw(address token) external onlyOwner {
        require(token != address(0), 'Zero');
        bool s = IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        require(s);
    }

    function withdrawBNB() external onlyOwner {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    function setTransferFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), 'Zero');
        transferFeeRecipient = recipient;
        permissions[recipient].isFeeExempt = true;
    }

    function setBuyFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), 'Zero');
        buyFeeRecipient = recipient;
        permissions[recipient].isFeeExempt = true;
    }

    function setSellFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), 'Zero');
        sellFeeRecipient = recipient;
        permissions[recipient].isFeeExempt = true;
    }

    function registerAutomatedMarketMaker(address account) external onlyOwner {
        require(account != address(0), 'Zero Address');
        require(!permissions[account].isLiquidityPool, 'AMM');
        permissions[account].isLiquidityPool = true;
    }

    function unRegisterAutomatedMarketMaker(address account) external onlyOwner {
        require(account != address(0), 'Zero Address');
        require(permissions[account].isLiquidityPool, 'Not AMM');
        permissions[account].isLiquidityPool = false;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unPause() external onlyOwner {
        paused = false;
    }

    function setAutoTriggers(
        bool autoBuyTrigger,
        bool autoTransferTrigger,
        bool autoSellTrigger
    ) external onlyOwner {
        triggerBuyRecipient = autoBuyTrigger;
        triggerTransferRecipient = autoTransferTrigger;
        triggerSellRecipient = autoSellTrigger;
    }

    function setFees(uint _buyFee, uint _sellFee, uint _transferFee) external onlyOwner {
        require(
            _buyFee <= 1000,
            'Buy Fee Too High'
        );
        require(
            _sellFee <= 1000,
            'Sell Fee Too High'
        );
        require(
            _transferFee <= 1000,
            'Transfer Fee Too High'
        );

        buyFee = _buyFee;
        sellFee = _sellFee;
        transferFee = _transferFee;
    }

    function setFeeExempt(address account, bool isExempt) external onlyOwner {
        require(account != address(0), 'Zero Address');
        permissions[account].isFeeExempt = isExempt;
    }

    
    /////////////////////////////////
    /////     READ FUNCTIONS    /////
    /////////////////////////////////

    function getTax(address sender, address recipient, uint256 amount) public view returns (uint256, address, bool) {
        if ( permissions[sender].isFeeExempt || permissions[recipient].isFeeExempt ) {
            return (0, address(0), false);
        }
        return permissions[sender].isLiquidityPool ? 
               ((amount * buyFee) / TAX_DENOM, buyFeeRecipient, triggerBuyRecipient) : 
               permissions[recipient].isLiquidityPool ? 
               ((amount * sellFee) / TAX_DENOM, sellFeeRecipient, triggerSellRecipient) :
               ((amount * transferFee) / TAX_DENOM, transferFeeRecipient, triggerTransferRecipient);
    }

    //////////////////////////////////
    /////   INTERNAL FUNCTIONS   /////
    //////////////////////////////////

    /** Internal Transfer */
    function _transfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(
            recipient != address(0),
            'Zero Recipient'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            amount <= balanceOf(sender),
            'Insufficient Balance'
        );
        require(
            paused == false || msg.sender == this.getOwner(),
            'Paused'
        );
        
        // decrement sender balance
        _balances[sender] -= amount;

        // fee for transaction
        (uint256 fee, address feeDestination, bool trigger) = getTax(sender, recipient, amount);

        // give amount to recipient less fee
        uint256 sendAmount = amount - fee;
        require(sendAmount > 0, 'Zero Amount');

        // allocate balance
        _balances[recipient] += sendAmount;
        emit Transfer(sender, recipient, sendAmount);

        // allocate fee if any
        if (fee > 0) {

            // if recipient field is valid
            bool isValidRecipient = feeDestination != address(0) && feeDestination != address(this);

            // allocate amount to recipient
            address feeRecipient = isValidRecipient ? feeDestination : address(this);

            // allocate fee
            _balances[feeRecipient] += fee;
            emit Transfer(sender, feeRecipient, fee);

            // if valid and trigger is enabled, trigger tokenomics mid transfer
            if (trigger && isValidRecipient) {
                IFeeReceiver(feeRecipient).trigger();
            }
        }

        return true;
    }

    function _burn(address account, uint256 amount) internal returns (bool) {
        require(
            account != address(0),
            'Zero Address'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            amount <= _balances[account],
            'Insufficient Balance'
        );

        // delete from balance and supply
        _balances[account] -= amount;
        _totalSupply -= amount;

        // emit transfer
        emit Transfer(account, address(0), amount);
        return true;
    }
}