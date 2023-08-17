/*
    ░█████╗░██████╗░██╗░░░██╗██████╗░████████╗░█████╗░███████╗██╗██╗░░██╗███████╗
    ██╔══██╗██╔══██╗╚██╗░██╔╝██╔══██╗╚══██╔══╝██╔══██╗██╔════╝██║╚██╗██╔╝██╔════╝
    ██║░░╚═╝██████╔╝░╚████╔╝░██████╔╝░░░██║░░░██║░░██║█████╗░░██║░╚███╔╝░█████╗░░
    ██║░░██╗██╔══██╗░░╚██╔╝░░██╔═══╝░░░░██║░░░██║░░██║██╔══╝░░██║░██╔██╗░██╔══╝░░
    ╚█████╔╝██║░░██║░░░██║░░░██║░░░░░░░░██║░░░╚█████╔╝██║░░░░░██║██╔╝╚██╗███████╗
    ░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░░░░░░░╚═╝░░░░╚════╝░╚═╝░░░░░╚═╝╚═╝░░╚═╝╚══════╝
                            https://CryptoFixe.com
*/                              
/********************************************************************************
 *              It's a registered trademark of the Nespinker                    *
 *                           https://Nespinker.com                              *
 ********************************************************************************/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

string constant NAME = "CryptoFixe";
string constant SYMBOL = "CoinFixe";


uint256 constant MAX_SUPPLY = 1_000_000_000;
uint8 constant DECIMALS = 18;
uint32 constant DENOMINATOR = 100000;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    error OwnableUnauthorizedAccount(address account);
    error OwnableInvalidOwner(address owner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }
    modifier onlyOwner() {
        _checkOwner();
        _;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract AccessControl is Ownable {
    mapping(address => bool) private _admins;
    mapping(address => bool) private _bridges;

    event removeBridgeEvent(address account);
    event addBridgeEvent(address account);
    event addAdminEvent(address account);
    event removeAdminEvent(address account);

    constructor() {
        _admins[_msgSender()] = true;
    }
    modifier onlyAdmin() {
        require(owner() != address(0), "AccessControl: the contract is renounced.");
        require(_admins[_msgSender()], "AccessControl: caller is not an admin");
        _;
    }
    modifier onlyBridge() {
        require(owner() != address(0), "AccessControl: the contract is renounced.");
        require(_bridges[_msgSender()] || owner() == _msgSender(), "AccessControl: caller is not a bridge or owner");
        _;
    }
    function removeBridge(address account) external onlyOwner {
        _bridges[account] = false;
        emit removeBridgeEvent(account);
    }
    function addBridge(address account) external onlyOwner {
        _bridges[account] = true;
        emit addBridgeEvent(account);
    }
    function addAdmin(address account) external onlyOwner {
        require(!isContract(account), "AccessControl: Admin wallet cannot be a contract");
        _admins[account] = true;
        emit addAdminEvent(account);
    }
    function _addAdmin(address account) internal {
        _admins[account] = true;
    }
    function removeAdmin(address account) external onlyOwner {
         _admins[account] = false;
        emit removeAdminEvent(account);
    }
    function isAdmin(address account) public view returns (bool) {
        return _admins[account];
    }
    function renounceAdminship() external onlyAdmin {
        _admins[_msgSender()] = false;
    }
    function isBridge(address account) public view returns (bool) {
        return _bridges[account];
    }
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
}

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    error ERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return DECIMALS;
    }
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 requestedDecrease) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < requestedDecrease) {
            revert ERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
        }
        unchecked {
            _approve(owner, spender, currentAllowance - requestedDecrease);
        }

        return true;
    }
    function _transfer(address from, address to, uint256 value) internal virtual{
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                _balances[from] = fromBalance - value;
            }
        }
        if (to == address(0)) {
            unchecked {
                _totalSupply -= value;
            }
        } else {
            unchecked {
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }
    function _approve(address owner, address spender, uint256 value) internal virtual {
        _approve(owner, spender, value, true);
    }
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

abstract contract TradeManagedToken is ERC20, AccessControl {
    bool private _trading = false;

    event enableTradingEvent(bool isTrading);

    function isTrading() external view returns (bool) {
        return _trading;
    }
    function enableTrading() external onlyOwner {
        _trading = true;
        emit enableTradingEvent(_trading);
    }
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(
            _trading || isAdmin(sender),
            "TradeManagedToken: CryptoFixe has not been released."
        );
        super._transfer(sender, recipient, amount);
    }
    function mint(address account, uint256 amount) external onlyBridge {
        require((totalSupply() + amount) <= (MAX_SUPPLY * 10**DECIMALS) ,"TradeManagedToken: Cannot mint more than the maximum supply" );
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyBridge{
        require(
            allowance(account, _msgSender()) >= amount,"TradeManagedToken: Burn amount exceeds allowance"
        );
        _approve(
            account,
            _msgSender(),
            allowance(account, _msgSender()) - amount
        );
        _burn(account, amount);
    }
}

library Address {
    error AddressInsufficientBalance(address account);
    error AddressEmptyCode(address target);
    error FailedInnerCall();

    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, defaultRevert);
    }
    function functionCall(
        address target,
        bytes memory data,
        function() internal view customRevert
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, customRevert);
    }
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, defaultRevert);
    }
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        function() internal view customRevert
    ) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, defaultRevert);
    }
    function functionStaticCall(
        address target,
        bytes memory data,
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, defaultRevert);
    }
    function functionDelegateCall(
        address target,
        bytes memory data,
        function() internal view customRevert
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                if (target.code.length == 0) {
                    revert AddressEmptyCode(target);
                }
            }
            return returndata;
        } else {
            _revert(returndata, customRevert);
        }
    }
    function verifyCallResult(bool success, bytes memory returndata) internal view returns (bytes memory) {
        return verifyCallResult(success, returndata, defaultRevert);
    }
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        function() internal view customRevert
    ) internal view returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, customRevert);
        }
    }
    function defaultRevert() internal pure {
        revert FailedInnerCall();
    }
    function _revert(bytes memory returndata, function() internal view customRevert) private view {
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            customRevert();
            revert FailedInnerCall();
        }
    }
}

interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
    function nonces(address owner) external view returns (uint256);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

library SafeERC20 {
    using Address for address;

    error SafeERC20FailedOperation(address token);
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        if (nonceAfter != nonceBefore + 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

struct Fees {
    uint64 liquidityBuyFee;
    uint64 marketingBuyFee;
    uint64 rewardsBuyFee;
    uint64 liquiditySellFee;
    uint64 marketingSellFee;
    uint64 rewardsSellFee;
    uint64 transferFee;
}

contract CryptoFixe is TradeManagedToken {
    using SafeERC20 for IERC20;

    Fees private _fees = Fees(0,0,0,0,0,0,0);
    Fees private _especialNftFees = Fees(0,0,0,0,0,0,0);

    uint256 public totalBuyFee = 0;
    uint256 public totalSellFee = 0;
    uint256 public totalEspecialNftBuyFee = 0;
    uint256 public totalEspecialNftSellFee = 0;
    bool public especialNftFeesEnable = true;
    
    address[] public nftList;

    mapping(address => bool) public lpPairList;
    mapping(address => bool) public isExcludedFromFees;

    uint256 public liquidityReserves;
    uint256 public marketingReserves;
    uint256 public rewardsReserves;

    address public marketingAddress;
    address public liquidityAddress;
    address public rewardsAddress;

    uint16 public maxFee = 5000;

    event nftCollectionForFeesEvent(address collection, bool enabled);
    event marketingAddressChangedEvent(address marketingAddress);
    event liquidityAddressChangedEvent(address liquidityAddress);
    event rewardsAddressChangedEvent(address rewardsAddress);
    event excludedFromFeesEvent(address indexed account, bool isExcluded);
    event setLPPairEvent(address indexed pair, bool indexed value);
    event processFeeReservesEvent(uint256 liquidityReserves, uint256 marketingReserves, uint256 rewardsReserves);
    event feesChangedEvent(uint64 liqBuyFee, uint64 marketingBuyFee, uint64 rewardsBuyFee, uint64 liqSellFee, 
                            uint64 marketingSellFee, uint64 rewardsSellFee, uint64 transferFee, bool isNftFees);

    constructor() ERC20(NAME, SYMBOL) {
        isExcludedFromFees[_msgSender()] = true;
        isExcludedFromFees[address(this)] = true;
        _addAdmin(address(this));
    }

    receive() external payable {
    }

    function claimStuckTokens(address token) external onlyOwner {
        require(token != address(this), "Owner cannot claim native tokens");
        if (token == address(0x0)) {
            payable(msg.sender).transfer(address(this).balance);
            return;
        }
        IERC20 ERC20token = IERC20(token);
        uint256 balance = ERC20token.balanceOf(address(this));
        ERC20token.transfer(msg.sender, balance);
    }

    function _verifyNftOwnerForEspecialFees(address account) private view returns(bool) {
        uint256 l = nftList.length;
        for(uint8 i=0; i < l; i++){
           if(IERC721(nftList[i]).balanceOf(account) > 0){
               return true;
           }
        }
        return false;
    }
    
    function setLPPair(address lpPair, bool enable) external onlyOwner {
        require(lpPairList[lpPair] != enable, "LP is already set to that state");
        lpPairList[lpPair] = enable;
        emit setLPPairEvent(lpPair, enable);
    }

    function excludedFromFees(address account, bool excluded) external onlyOwner {
        require(isExcludedFromFees[account] != excluded, "Account is already set to that state");
        isExcludedFromFees[account] = excluded;
        emit excludedFromFeesEvent(account, excluded);
    }

    function setRewardsAddress(address newRewardsAddress) external onlyOwner{
        require(rewardsAddress != newRewardsAddress, "Rewards Address is already that address");
        require(newRewardsAddress != address(0), "Rewards Address cannot be the zero address");
        rewardsAddress = newRewardsAddress;
        isExcludedFromFees[newRewardsAddress] = true;
        emit rewardsAddressChangedEvent(rewardsAddress);
    }

    function setMarketingAddress(address newMarketingAddress) external onlyOwner{
        require(newMarketingAddress != address(0), "Marketing Address cannot be the zero address");
        require(marketingAddress != newMarketingAddress, "Marketing Address is already that address");
        marketingAddress = newMarketingAddress;
        isExcludedFromFees[marketingAddress] = true;
        emit marketingAddressChangedEvent(marketingAddress);
    }

    function setLiquidityAddress(address newLiquidityAddress) external onlyOwner{
        require(newLiquidityAddress != address(0), "Liquididy Address cannot be the zero address");
        require(liquidityAddress != newLiquidityAddress, "Liquidity Address is already that address");
        liquidityAddress = newLiquidityAddress;
        isExcludedFromFees[liquidityAddress] = true;
        emit liquidityAddressChangedEvent(liquidityAddress);
    }

    function updateMaxFee(uint16 newValue) external onlyOwner{
        require(newValue < maxFee, "Token: Max fee cannot increase");
        maxFee = newValue;
        if(newValue == 0){
            _removeFeeForever();
        }
    }

    function _removeFeeForever() private{
        maxFee = 0;
        _setFees(0, 0, 0, 0, 0, 0, 0, false);
        _setFees(0, 0, 0, 0, 0, 0, 0, true);
    }
    
    function enableEspecialNftFees(bool enable) external onlyOwner{
        especialNftFeesEnable = enable;
    }

    function setFees(
        uint64 liqBuyFee,
        uint64 marketingBuyFee,
        uint64 rewardsBuyFee,
        uint64 liqSellFee,
        uint64 marketingSellFee,
        uint64 rewardsSellFee,
        uint64 transferFee,
        bool isNftFees
    ) external onlyOwner {
        _setFees(liqBuyFee, marketingBuyFee, rewardsBuyFee, liqSellFee, marketingSellFee, rewardsSellFee, transferFee, isNftFees);
    }

    function _setFees(
        uint64 liqBuyFee,
        uint64 marketingBuyFee,
        uint64 rewardsBuyFee,
        uint64 liqSellFee,
        uint64 marketingSellFee,
        uint64 rewardsSellFee,
        uint64 transferFee,
        bool isNftFees
    ) internal {
        require(
            ((liqBuyFee + marketingBuyFee + rewardsBuyFee) <= maxFee ) 
            && ((liqSellFee + marketingSellFee + rewardsSellFee) <= maxFee)
            && (transferFee <= maxFee),"Token: fees are too high");
        if(isNftFees){
            _especialNftFees = Fees(liqBuyFee, marketingBuyFee, rewardsBuyFee, liqSellFee, marketingSellFee, rewardsSellFee, transferFee);
            totalEspecialNftBuyFee = liqBuyFee + marketingBuyFee + rewardsBuyFee;
            totalEspecialNftSellFee = liqSellFee + marketingSellFee + rewardsSellFee;
        }else{
            _fees = Fees(liqBuyFee, marketingBuyFee, rewardsBuyFee, liqSellFee, marketingSellFee, rewardsSellFee, transferFee);
            totalBuyFee = liqBuyFee + marketingBuyFee + rewardsBuyFee;
            totalSellFee = liqSellFee + marketingSellFee + rewardsSellFee;
        }
        emit feesChangedEvent(liqBuyFee, marketingBuyFee, rewardsBuyFee, liqSellFee, marketingSellFee, rewardsSellFee, transferFee, isNftFees);
    }

    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount) 
        public override returns (bool) {
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()) - amount
        );
        if(totalBuyFee > 0 || totalSellFee > 0){
            return _customTransfer(sender, recipient, amount);
        }else{
            super._transfer(sender, recipient, amount);
            return true;
        }
    }

    function transfer(
        address recipient, 
        uint256 amount) 
        public virtual override returns (bool){
        if(totalBuyFee > 0 || totalSellFee > 0){
           return _customTransfer(_msgSender(), recipient, amount);
        }else{
            super._transfer(_msgSender(), recipient, amount);
            return true;
        }
    }

    function _customTransfer(
        address sender, 
        address recipient, 
        uint256 amount) 
        private returns (bool) {
        require(amount > 0, "Token: Cannot transfer zero(0) tokens");
        uint256 totalFees = 0;
        uint256 left = 0;
        bool isBuy = lpPairList[sender];
        bool isSell = lpPairList[recipient];
        if (
            (!isBuy && !isSell) ||
            (isBuy && isExcludedFromFees[recipient]) ||
            (isSell && isExcludedFromFees[sender])
        ){
            if(_fees.transferFee > 0 && !isExcludedFromFees[recipient] && !isExcludedFromFees[sender]) {
                bool hasNFT = false;
                if(especialNftFeesEnable){
                    hasNFT = (_verifyNftOwnerForEspecialFees(sender) || _verifyNftOwnerForEspecialFees(recipient));
                }
                if(hasNFT){
                    totalFees = (amount * _especialNftFees.transferFee) / DENOMINATOR;
                }else{
                    totalFees = (amount * _fees.transferFee) / DENOMINATOR;
                }
                marketingReserves += totalFees;
            }
        }else{
            totalFees = _calculateDexFees(isBuy, amount, (isBuy ? recipient : sender )) ;
        }
        left = amount - totalFees;
        super._transfer(sender, recipient, left);
        if(totalFees > 0){
            super._transfer(sender, address(this), totalFees);
        }
        return true;
    }

    function _calculateDexFees(bool isBuy, uint256 amount, address toNftCheck) private returns(uint256) {
        uint256 liquidityFeeAmount = 0;
        uint256 marketingFeeAmount = 0;
        uint256 rewardsFeeAmount = 0;
        uint256 totalFees = 0;
        bool hasNft = false;

        if (especialNftFeesEnable){
            hasNft = _verifyNftOwnerForEspecialFees(toNftCheck);
        }

        if (isBuy) {
            if(hasNft){
                    if(_especialNftFees.liquidityBuyFee > 0){
                        liquidityFeeAmount = (amount * _especialNftFees.liquidityBuyFee) / DENOMINATOR;
                    }
                    if(_especialNftFees.marketingBuyFee > 0){
                        marketingFeeAmount = (amount * _especialNftFees.marketingBuyFee) / DENOMINATOR;
                    }
                    if(_especialNftFees.rewardsBuyFee > 0){
                        rewardsFeeAmount = (amount * _especialNftFees.rewardsBuyFee) / DENOMINATOR;
                    }
            }else{
                    if(_fees.liquidityBuyFee > 0){
                        liquidityFeeAmount = (amount * _fees.liquidityBuyFee) / DENOMINATOR;
                    }
                    if(_fees.marketingBuyFee > 0){
                        marketingFeeAmount = (amount * _fees.marketingBuyFee) / DENOMINATOR;
                    }
                    if(_fees.rewardsBuyFee > 0){
                        rewardsFeeAmount = (amount * _fees.rewardsBuyFee) / DENOMINATOR;
                    }
            }
        } else{
            if(hasNft){
                if(_especialNftFees.liquiditySellFee > 0){
                    liquidityFeeAmount = (amount * _especialNftFees.liquiditySellFee) / DENOMINATOR;
                }
                if(_especialNftFees.marketingSellFee > 0){
                    marketingFeeAmount = (amount * _especialNftFees.marketingSellFee) / DENOMINATOR;
                }
                if(_fees.rewardsSellFee > 0){
                    rewardsFeeAmount = (amount * _especialNftFees.rewardsSellFee) / DENOMINATOR;
                }
            }else{
                if(_fees.liquiditySellFee > 0){
                    liquidityFeeAmount = (amount * _fees.liquiditySellFee) / DENOMINATOR;
                }
                if(_fees.marketingSellFee > 0){
                    marketingFeeAmount = (amount * _fees.marketingSellFee) / DENOMINATOR;
                }
                if(_fees.rewardsSellFee > 0){
                    rewardsFeeAmount = (amount * _fees.rewardsSellFee) / DENOMINATOR;
                }
            }
        }
        totalFees = liquidityFeeAmount + marketingFeeAmount + rewardsFeeAmount;
        if(totalFees > 0){
            liquidityReserves += liquidityFeeAmount;
            marketingReserves += marketingFeeAmount;
            rewardsReserves += rewardsFeeAmount;
        }
        return totalFees;
    }

    function setNFTCollectionForFees(address collection, bool enabled) external onlyOwner{
        uint256 l = nftList.length;
        for (uint256 i = 0; i < l; i++)
        {
            if(nftList[i] == collection){
                if(enabled){
                    require(nftList[i] != collection, "Collection is already exist");      
                }
                if(!enabled){
                    delete(nftList[i]);
                    for (uint i2 = i; i2 < nftList.length - 1; i2++) {
                        nftList[i2] = nftList[i2 + 1];
                    }
                    nftList.pop();
                    return;
                }
            }
        }
        if(enabled){
            nftList.push(collection);
        }
        emit nftCollectionForFeesEvent(collection, enabled);
    }

    function processFeeReserves() external onlyAdmin {
        if(liquidityReserves > 0){
            super._transfer(address(this), liquidityAddress, liquidityReserves);
            liquidityReserves = 0;
        }
        if(marketingReserves > 0){
            super._transfer(address(this), marketingAddress, marketingReserves);
            marketingReserves = 0;
        }
        if(rewardsReserves > 0){
            super._transfer(address(this), rewardsAddress, rewardsReserves);
            rewardsReserves = 0;
        }
        emit processFeeReservesEvent(liquidityReserves, marketingReserves, rewardsReserves);
    }
}