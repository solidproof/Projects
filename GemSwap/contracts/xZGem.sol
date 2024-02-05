// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: not owner");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IXZGEM is IERC20 {
    function withdrawFee() external view returns (uint256);

    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);
}

/**
 * @dev xZGem is used to increase the release speed of tokens produced by the mining pool, 
 * and can be pledged to the vault contract to earn mining pool fees.
 * It is minted by ZGem after staking, and will be automatically destroyed when withdrawn.
 */
contract xZGem is IXZGEM, Ownable, ReentrancyGuard {
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // ZGem contract address
    IERC20 public zgem;
    // Vault contract address
    address public vault;
    // Withdraw ZGem fee
    uint256 public withdrawFee = 2;

    string public name = "x ZkSync Gem Token";
    string public symbol = "xZGEM";
    uint8  public decimals = 18;
    uint256 private _totalSupply;

    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;

    /**
     * @dev Constructor
     * @param   _token  zgem token address
     */
    constructor(address _token) {
        zgem = IERC20(_token);
    }

    /**
     * @dev Deposit ZGem to this contract and mint the same amount of xZGem.
     */
    function deposit(uint256 _amount) external override nonReentrant {
        require(_amount > 0, "Invalid amount");

        address account = _msgSender();
        zgem.transferFrom(account, address(this), _amount);

        _mint(account, _amount);
        emit Deposit(account, _amount);
    }

    /**
     * @dev When withdrawing ZGem, the corresponding amount of xZGem will be destroyed from the user account,
     * a certain amount of ZGem will be deducted and transferred to the treasury contract or destroyed,
     * and the rest will be transferred to the user.
     */
    function withdraw(uint256 _amount) external override nonReentrant {
        address account = _msgSender();
        _burn(account, _amount);

        uint256 feeAmount = _amount * withdrawFee / 100;
        if (feeAmount > 0) {
            address receiver = vault == address(0) ? DEAD : vault;
            safeTransfer(receiver, feeAmount);
        }
        uint256 withdrawAmount = _amount - feeAmount;
        if (withdrawAmount > 0) {
            safeTransfer(account, withdrawAmount);
        }

        emit Withdrawal(account, withdrawAmount);
    }

    function safeTransfer(address _to, uint256 _amount) internal {
        uint256 bal = zgem.balanceOf(address(this));
        if (_amount > bal) {
            zgem.transfer(_to, bal);
        } else {
            zgem.transfer(_to, _amount);
        }
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _beforeTokenTransfer(_msgSender(), recipient, amount);
        return transferFrom(_msgSender(), recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        returns (bool)
    {
        _beforeTokenTransfer(sender, recipient, amount);

        address spender = _msgSender();
        if (sender != spender && allowance[sender][spender] != type(uint256).max) {
            require(allowance[sender][spender] >= amount, "XZGEM: Insufficient allowance");
            allowance[sender][spender] -= amount;
        }

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address sender, address, uint256 amount) internal virtual {
        require(amount > 0, "XZGEM: Invalid amount");
        if (sender != address(0)) {
            require(balanceOf[sender] >= amount, "XZGEM: Insufficient balance");
        }
    }

    function _mint(address account, uint256 amount) internal virtual {
        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        _beforeTokenTransfer(account, address(0), amount);

        balanceOf[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 2, "Cannot too high");
        withdrawFee = _fee;
    }

    function setVault(address _treasury) external onlyOwner {
        vault = _treasury;
    }
}