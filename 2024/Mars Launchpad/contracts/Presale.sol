/**
 *Submitted for verification at BscScan.com on 2024-09-10
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IERC20 {
    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Ownable {
    address internal _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "!owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "new 0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract AbsPreSale is Ownable {
    struct UserInfo {
        uint256 buyUsdt;
        uint256 teamAmount;
        uint256 invitorUsdt;
        uint256 claimed;
    }

    uint256 public _tokenAmountPerUsdt;

    address public _cashAddress;
    address public _tokenAddress;
    address public immutable _usdt;

    mapping(address => UserInfo) public _userInfo;
    address[] public _userList;
    bool public _pauseBuy = false;

    mapping(address => address) public _invitor;
    mapping(address => address[]) public _binder;
    uint256 public _inviteFee = 1000;
    uint256 public _totalInviteUsdt;
    uint256 public _totalSaleUsdt;
    uint256 public _totalSaleToken;
    uint256 public _qtyToken;

    uint256 public immutable _usdtUnit;
    uint256 public _min;
    uint256 public _max;
    uint256 public _endTime;
    mapping(address => uint256) public _teamAmount;
    uint256 public constant _teamLen = 50;

    constructor(address USDT, address TokenAddress, address CashAddress) {
        _usdt = USDT;
        _cashAddress = CashAddress;
        _tokenAddress = TokenAddress;
        _usdtUnit = 10 ** IERC20(_usdt).decimals();
        _min = 100 * _usdtUnit;
        _max = 2000 * _usdtUnit;
        _endTime = block.timestamp + 7 days;
        _qtyToken = 40000000 * 10 ** IERC20(TokenAddress).decimals();
    }

    function buy(address invitor, uint256 usdtAmount) external payable {
        require(!_pauseBuy, "pauseBuy");
        require(block.timestamp <= _endTime, "end");
        require(usdtAmount <= _max && usdtAmount >= _min, "err amount");
        address account = msg.sender;
        UserInfo storage userInfo = _userInfo[account];
        require(0 == userInfo.buyUsdt, "bought");
        _userList.push(account);

        _takeToken(_usdt, account, address(this), usdtAmount);
        userInfo.buyUsdt += usdtAmount;
        _totalSaleUsdt += usdtAmount;
        _tokenAmountPerUsdt = (_qtyToken * _usdtUnit) / _totalSaleUsdt;

        _totalSaleToken = _qtyToken;
        require(_totalSaleToken <= _qtyToken, "soldout");
        uint256 cashUsdt = usdtAmount;

        UserInfo storage invitorInfo = _userInfo[invitor];
        if (0 < invitorInfo.buyUsdt) {
            _invitor[account] = invitor;
            _binder[invitor].push(account);
            uint256 invitorUsdt = (usdtAmount * _inviteFee) / 10000;
            cashUsdt -= invitorUsdt;
            _totalInviteUsdt += invitorUsdt;
            invitorInfo.teamAmount += usdtAmount;
            invitorInfo.invitorUsdt += invitorUsdt;
            _giveToken(_usdt, invitor, invitorUsdt);
        }

        _giveToken(_usdt, _cashAddress, cashUsdt);

        uint256 teamLen = _teamLen;
        address current = account;
        for (uint256 i = 0; i < teamLen; ++i) {
            invitor = _invitor[current];
            if (address(0) == invitor) {
                break;
            }
            current = invitor;
            _teamAmount[invitor] += usdtAmount;
        }
    }

    bool public pauseClaim = true;
    function claim() public {
        require(!pauseClaim, "pauseClaim");
        require(block.timestamp >= _endTime, "not end");
        address account = msg.sender;
        UserInfo storage userInfo = _userInfo[account];
        require(0 == userInfo.claimed, "claimed");
        uint256 usdtAmount = userInfo.buyUsdt;
        uint256 tokenAmount = (_tokenAmountPerUsdt * usdtAmount) / _usdtUnit;
        userInfo.claimed = tokenAmount;
        _giveToken(_tokenAddress, account, tokenAmount);
    }

    function _giveToken(
        address tokenAddress,
        address account,
        uint256 tokenNum
    ) private {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(account, tokenNum);
    }

    function _takeToken(
        address tokenAddress,
        address from,
        address to,
        uint256 tokenNum
    ) private {
        IERC20 token = IERC20(tokenAddress);
        uint256 toBalance = token.balanceOf(to);
        IERC20(tokenAddress).transferFrom(from, to, tokenNum);
        require(
            token.balanceOf(address(to)) >= toBalance + tokenNum,
            "err take"
        );
    }

    function getTokenInfo()
        external
        view
        returns (
            address usdtAddress,
            uint256 usdtDecimals,
            string memory usdtSymbol,
            address tokenAddress,
            uint256 tokenDecimals,
            string memory tokenSymbol
        )
    {
        usdtAddress = _usdt;
        usdtDecimals = IERC20(usdtAddress).decimals();
        usdtSymbol = IERC20(usdtAddress).symbol();
        tokenAddress = _tokenAddress;
        tokenDecimals = IERC20(tokenAddress).decimals();
        tokenSymbol = IERC20(tokenAddress).symbol();
    }

    function getSaleInfo()
        external
        view
        returns (
            uint256 tokenAmountPerUsdt,
            uint256 min,
            uint256 max,
            bool pauseBuy,
            uint256 totalSaleUsdt,
            uint256 totalInviteUsdt,
            uint256 qtyToken,
            uint256 totalSaleToken,
            uint256 endTime,
            uint256 blockTime,
            uint256 userSize
        )
    {
        tokenAmountPerUsdt = _tokenAmountPerUsdt;
        pauseBuy = _pauseBuy;
        totalSaleUsdt = _totalSaleUsdt;
        totalInviteUsdt = _totalInviteUsdt;
        min = _min;
        max = _max;
        qtyToken = _qtyToken;
        totalSaleToken = _totalSaleToken;
        endTime = _endTime;
        blockTime = block.timestamp;
        userSize = _userList.length;
    }

    function getUserInfo(
        address account
    )
        external
        view
        returns (
            uint256 buyUsdt,
            uint256 teamAmount,
            uint256 usdtBalance,
            uint256 usdtAllowance,
            uint256 binderLength,
            address invitor,
            uint256 invitorUsdt,
            uint256 claimed
        )
    {
        UserInfo storage userInfo = _userInfo[account];
        buyUsdt = userInfo.buyUsdt;
        teamAmount = userInfo.teamAmount;
        usdtBalance = IERC20(_usdt).balanceOf(account);
        usdtAllowance = IERC20(_usdt).allowance(account, address(this));
        binderLength = _binder[account].length;
        invitor = _invitor[account];
        invitorUsdt = userInfo.invitorUsdt;
        claimed = userInfo.claimed;
    }

    function getBinderLength(address account) public view returns (uint256) {
        return _binder[account].length;
    }

    function _unitTeamAmount(address account) public view returns (uint256) {
        return _teamAmount[account] / _usdtUnit;
    }

    function getUserListLength() public view returns (uint256) {
        return _userList.length;
    }

    function setTokenAddress(address adr) external onlyOwner {
        _tokenAddress = adr;
    }

    function setCashAddress(address adr) external onlyOwner {
        _cashAddress = adr;
    }

    function claimToken(
        address erc20Address,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20 erc20 = IERC20(erc20Address);
        erc20.transfer(to, amount);
    }

    function setPauseBuy(bool pause) external onlyOwner {
        _pauseBuy = pause;
    }

    function setPauseClaim(bool pause) external onlyOwner {
        pauseClaim = pause;
    }

    function setInviteFee(uint256 fee) external onlyOwner {
        _inviteFee = fee;
    }

    function setMin(uint256 min) external onlyOwner {
        _min = min;
    }

    function setMax(uint256 max) external onlyOwner {
        _max = max;
    }

    function setEndTime(uint256 end) external onlyOwner {
        _endTime = end;
    }

    function setQtyToken(uint256 qty) external onlyOwner {
        _qtyToken = qty;
        if (0 != _totalSaleUsdt) {
            _tokenAmountPerUsdt = (_qtyToken * _usdtUnit) / _totalSaleUsdt;
        }
    }

    //userList
    function getUserList(
        uint256 start,
        uint256 len
    )
        external
        view
        returns (address[] memory userList, uint256[] memory teamAmount)
    {
        if (start > _userList.length) {
            start = _userList.length;
        }
        if (0 == len || len > _userList.length - start) {
            len = _userList.length - start;
        }
        userList = new address[](len);
        teamAmount = new uint256[](len);
        uint256 index = 0;
        for (uint256 i = start; i < start + len; i++) {
            address u = _userList[i];
            userList[index] = u;
            teamAmount[index] = _userInfo[u].teamAmount;
            index++;
        }
    }
}

contract PreSale is AbsPreSale {
    constructor()
        AbsPreSale(
            //USDT
            address(0x55d398326f99059fF775485246999027B3197955),
            //Token
            address(0x145335c5fD3D53e2A361d995015A055484167666),
            //Cash
            address(0x4378b301A094c87824C119bA18C227474fdbbc32)
        )
    {}
}