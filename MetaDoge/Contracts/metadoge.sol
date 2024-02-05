pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface IAntisnipe {
    function assureCanTransfer(
        address sender,
        address from,
        address to,
        uint256 amount
    ) external;
}

contract MetaDoge is Context, IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    address masterWallet;
    address marketingWallet;
    uint256 masterFee;
    uint256 marketingFee;

    mapping(address => bool) private isExcludedFromFee;

    event EventExcludeAddress(address indexed _address);
    event EventRemoveExcludedAddress(address indexed _address);

    constructor() {
        _name = "MetaDoge";
        _symbol = "MTDU";
        _mint(0x34A8C43b0d43d2Bd1DfbE551442e43E2a834a02a, 1000000000 * 10**18);
        marketingWallet = 0x5673337B132B0E0e7db1789d213A9b6549756c12;
        masterWallet = 0x9c6e9dEa6edfa11Da9cA30fA7df5af9A1d5a52e0;
        masterFee = 0;
        marketingFee = 1;
        excludeAddress(0x34A8C43b0d43d2Bd1DfbE551442e43E2a834a02a);
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

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: transfer amount exceeds allowance"
            );
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
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

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function setMasterFee(uint256 fee) public onlyOwner {
        masterFee = fee;
    }

    function setMarketingFee(uint256 fee) public onlyOwner {
        marketingFee = fee;
    }

    function setMasterWallet(address wallet) public onlyOwner {
        masterWallet = wallet;
    }

    function setMarketingWallet(address wallet) public onlyOwner {
        marketingWallet = wallet;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        if (isExcludedFromFee[sender] || isExcludedFromFee[recipient]) {
            _transferWithoutFee(sender, recipient, amount);
        } else {
            if (masterFee == 0 || marketingFee == 0) _transferWithoutFee(sender, recipient, amount);
            else _transferStandard(sender, recipient, amount);
        }
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _transferWithoutFee(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 feeToMaster = amount.mul(masterFee).div(100);
        uint256 feeToMarketing = amount.mul(marketingFee).div(100);
        uint256 realAmount = amount.sub(feeToMaster).sub(feeToMarketing);

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(realAmount);

        emit Transfer(sender, recipient, realAmount);

        _balances[masterWallet] = _balances[masterWallet].add(feeToMaster);
        emit Transfer(sender, masterWallet, feeToMaster);

        _balances[marketingWallet] = _balances[marketingWallet].add(
            feeToMarketing
        );
        emit Transfer(sender, masterWallet, feeToMarketing);
    }

    function excludeAddress(address _address) public onlyOwner {
        isExcludedFromFee[_address] = true;
        emit EventExcludeAddress(_address);
    }

    function removeExcludedAddress(address _address) public onlyOwner {
        delete isExcludedFromFee[_address];
        emit EventRemoveExcludedAddress(_address);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    IAntisnipe public antisnipe = IAntisnipe(address(0));
    bool public antisnipeDisable;

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        if (from == address(0) || to == address(0)) return;
        if (!antisnipeDisable && address(antisnipe) != address(0))
            antisnipe.assureCanTransfer(msg.sender, from, to, amount);
    }

    function setAntisnipeDisable() external onlyOwner {
        require(!antisnipeDisable);
        antisnipeDisable = true;
    }

    function setAntisnipeAddress(address addr) external onlyOwner {
        antisnipe = IAntisnipe(addr);
    }
}