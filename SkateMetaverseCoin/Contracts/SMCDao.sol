/**
 *Submitted for verification at BscScan.com on 2022-06-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
    external
    returns (bool);

    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function decimals() external view returns (uint8);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract Context {
    constructor() {}

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
}

library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash =
        0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != 0x0 && codehash != accountHash);
    }
}

library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
        token.allowance(address(this), spender).add(value);
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance =
        token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

contract SMCDao is IERC20, Context {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public governance;

    address public token;

    mapping(address => uint256) public lockBlocks;
    mapping(address => bool) public isAutoDeposits;

    uint256 public lockTime;
    uint256 public rewardRatio;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => bool) public transferLimitTargets;
    bool public enableTransferLimit = true;

    bool public allowContract = false;
    bool public openWithdraw = false;

    constructor(
        string memory __name,
        string memory __symbol,
        uint256 _lockTime,
        uint256 _rewardRatio,
        address _Token
    ) {
        governance = msg.sender;
        lockTime = _lockTime;
        rewardRatio = _rewardRatio;
        token = _Token;
        _name = __name;
        _symbol = __symbol;
        _decimals = IERC20(token).decimals();

        enableTransferLimit = true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    modifier onlyHuman {
        if (!allowContract) {
            require(msg.sender == tx.origin);
            _;
        }
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function updateLockTime(uint256 _lt) public {
        require(msg.sender == governance, "!governance");
        require(_lt > 0);
        lockTime = _lt;
    }

    function toggleTransferLimit(bool _e) public {
        require(msg.sender == governance, "!governance");
        enableTransferLimit = _e;
    }

    function toggleOpenWithdraw(bool _e) public {
        require(msg.sender == governance, "!governance");
        openWithdraw = _e;
    }

    function toggleAllowContract(bool _b) public {
        require(msg.sender == governance, "!governance");
        allowContract = _b;
    }

    function toggleRewardRatio(uint256 _newRewardRatio) public {
        require(msg.sender == governance, "!governance");
        rewardRatio = _newRewardRatio;
    }

    function addLimitTarget(address _a) public {
        require(msg.sender == governance, "!governance");
        transferLimitTargets[_a] = true;
    }

    function removeLimitTarget(address _a) public {
        require(msg.sender == governance, "!governance");
        transferLimitTargets[_a] = false;
    }

    function deposit(uint256 _amount, bool _isAutoDeposit) public onlyHuman {
        require(_amount > 0, "zero deposit");
        uint256 _before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _after = IERC20(token).balanceOf(address(this));
        _amount = _after.sub(_before);
        uint256 shares = _amount;

        uint256 oldAmt = balanceOf(msg.sender);
        if (oldAmt == 0) {
            lockBlocks[msg.sender] = block.number.add(lockTime);
            isAutoDeposits[msg.sender] = _isAutoDeposit;
        } else {
            uint256 expireBlock = lockBlocks[msg.sender];
            uint256 totalAmt = oldAmt.add(_amount);
            uint256 newAmtShare = _amount.mul(lockTime);
            if (expireBlock > block.number) {
                // (oldAmt * (expireBlock - block.number) + newAmt * lockTime) / (oldAmt + newAmt)
                uint256 deltaBlocks = expireBlock.sub(block.number);
                uint256 avgLockTime =
                oldAmt.mul(deltaBlocks).add(newAmtShare).div(totalAmt);
                lockBlocks[msg.sender] = block.number.add(avgLockTime);
            } else {
                uint256 withdrawAmount = caculateWithdraw(msg.sender, oldAmt);
                uint256 currentRewardAmount = 0;
                if (isAutoDeposits[msg.sender]) {
                    uint256 currentRewardBlock = block.number.sub(expireBlock) % lockTime;
                    currentRewardAmount = withdrawAmount.mul(rewardRatio).mul(currentRewardBlock).div(lockTime).div(10**4);
                    withdrawAmount = withdrawAmount.add(currentRewardAmount);
                }
                shares = withdrawAmount.add(_amount).sub(oldAmt);
                lockBlocks[msg.sender] = block.number.add(lockTime);
            }
        }

        _mint(msg.sender, shares);
    }

    function withdraw() public onlyHuman {
        uint256 senderBalance = balanceOf(msg.sender);
        require(senderBalance > 0, "no balance to withdraw");
        if (!openWithdraw) {
            require(lockBlocks[msg.sender] < block.number);
        }
        uint256 withdrawAmount = caculateWithdraw(msg.sender, senderBalance);
        _burn(msg.sender, senderBalance);
        IERC20(token).safeTransfer(msg.sender, withdrawAmount);
    }

    function caculateWithdraw(address addr) public view returns(uint256) {
        return caculateWithdraw(addr, balanceOf(addr));
    }

    function caculateWithdraw(address addr, uint256 daoAmount) public view returns(uint256 withdrawAmount) {
        uint256 round = 0;
        uint256 addrLockBlock = lockBlocks[addr];
        if (addrLockBlock != 0 && addrLockBlock <= block.number) {
            if (isAutoDeposits[addr]) {
                round = uint256(block.number).sub(addrLockBlock).div(lockTime).add(1);
            } else {
                round = 1;
            }
        }
        uint256 _rewardRatio = rewardRatio;
        withdrawAmount = daoAmount;
        for (uint256 i = 0; i < round; i++) {
            withdrawAmount = withdrawAmount.add(withdrawAmount.mul(_rewardRatio).div(10**4));
        }
    }

    function canWithdraw(address user) public view returns (bool) {
        if (openWithdraw) {
            return true;
        }
        return block.number >= lockBlocks[user];
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
    public
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        if (enableTransferLimit) {
            require(transferLimitTargets[sender]|| transferLimitTargets[recipient], "limit transfer targets");
        }

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(
                amount,
                "ERC20: burn amount exceeds allowance"
            )
        );
    }

    function withdrawTokens(address token_, address account_, uint256 amount_) public {
        require(msg.sender == governance, "!governance");
        IERC20(token_).safeTransfer(account_, amount_);
    }
}