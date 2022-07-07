

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }


    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}


contract CITY is ERC20
{

  constructor() ERC20("SecondCity","CITY"){
    admin = 0x69a63958C872f0a8faf3C936352Be385E2b51B19;
  }
  address private admin;

  modifier ADMIN(){
    require(admin == msg.sender,"admin only");_;
  }

  function set_admin() public {
    require(admin == address(0), "admin not null");
    admin = msg.sender;
  }

  function check_admin(address i) public view returns(bool) {
    return admin == i;
  }

  function set_admin(address i) public ADMIN {
    admin = i;
  }

  //mint_completed GET SET
  bool private mint_completed = false;
  function set_mint_completed(bool i) public ADMIN{
    require(!mint_completed,"mint completed");
    mint_completed = i;
  }
  function get_mint_completed() public view returns(bool){
    return mint_completed;
  }

  function mint(uint256 amount) public ADMIN{
    require(!mint_completed,"mint completed");
    _mint(msg.sender,amount);
  }

  function mint(address to, uint256 amount) public ADMIN{
    require(!mint_completed,"mint completed");
    _mint(to,amount);
  }

  function mint_with_lock(address to, uint256 amount) public ADMIN{
    require(!mint_completed,"mint completed");
    _mint(to,amount);
    locked_account[to] = true;
  }

  mapping(address => bool) private locked_account;
  function get_locked_account(address to) public view returns (bool){
    return locked_account[to];
  }

  mapping(address => uint256) private withdrawal_limit;
  uint256 private total_withdrawal_limit;

  function mint_withdrawal_limit(address to, uint256 amount) public ADMIN {
    locked_account[to] = true;
    withdrawal_limit[to] = withdrawal_limit[to] + amount;
    total_withdrawal_limit = total_withdrawal_limit + amount;
  }

  function get_withdrawal_limit(address to) public view returns (uint256){
    return withdrawal_limit[to];
  }

  function get_total_withdrawal_limit() public view returns (uint256){
    return total_withdrawal_limit;
  }

  function _check_withdrawable(address to, uint256 amount)
  private view returns (bool) {
    if(locked_account[to])
    {
      if(withdrawal_limit[to] >= amount) return true;
      return false;
    }
    return true;
  }

  function _sub_withdrawal(address to, uint256 amount) internal{
      if(locked_account[to])
      {
        withdrawal_limit[to] = withdrawal_limit[to] - amount;
        total_withdrawal_limit = total_withdrawal_limit - amount;
      }
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
      require(_check_withdrawable(msg.sender,amount),"cannot withdraw");
      address owner = _msgSender();
      _transfer(owner, to, amount);
      _sub_withdrawal(msg.sender, amount);
      return true;
  }

  function transferFrom(
      address from,
      address to,
      uint256 amount
  ) public override returns (bool) {

      require(_check_withdrawable(from,amount),"cannot withdraw");
      address spender = _msgSender();
      _spendAllowance(from, spender, amount);
      _transfer(from, to, amount);
      _sub_withdrawal(from, amount);

      return true;
  }

  function burn(uint256 amount) public {
    require(_check_withdrawable(msg.sender,amount),"cannot burn");
    _burn(msg.sender,amount);
    _sub_withdrawal(msg.sender, amount);
  }
}