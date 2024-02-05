// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract T99NFTToken is Context, ERC20, Ownable {
    mapping(address => bool) public isExcludedFromFee;

    uint256 public marketingFee = 25;
    uint256 public developmentFee = 25;
    uint256 public burntFee = 25;
    uint256 public poolFee = 25;

    uint256 public startLock;

    address public immutable marketingAddr;
    address public immutable developmentAddr;
    address public immutable burntAddr;
    address public immutable poolAddr;
    address public immutable contributorsAddr;
    address public immutable stakingAddr;

    uint256 private constant PERCENT_BASE = 10000;

    constructor(
        address[] memory _startWallets,
        uint256[] memory _amounts,
        address _burntAddrs
    ) ERC20("T99NFT Token", "T99NFT") {
        require(
            _startWallets.length == _amounts.length &&
                _startWallets.length == 8,
            "Wrong addresses!"
        );

        marketingAddr = _startWallets[0];
        developmentAddr = _startWallets[1];
        stakingAddr = _startWallets[2];
        contributorsAddr = _startWallets[4];
        poolAddr = _startWallets[7];
        burntAddr = _burntAddrs;

        for (uint256 i = 0; i < _startWallets.length; i++) {
            isExcludedFromFee[_startWallets[i]] = true;
            _mint(_startWallets[i], _amounts[i] * 10**18);
        }
        startLock = block.timestamp;
    }

    function changeExcludedFromFee(address account) public onlyOwner {
        isExcludedFromFee[account] = !isExcludedFromFee[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        address user = _msgSender();
        require(user != burntAddr, "Not available for burn address!");
        if (user == contributorsAddr) {
            require(
                block.timestamp > startLock + 730 days,
                "Lock up period is not over"
            );
        }
        if (user == stakingAddr || user == developmentAddr) {
            require(
                block.timestamp > startLock + 91 days,
                "Lock up period is not over"
            );
        }
        if (isExcludedFromFee[_msgSender()] == true) {
            _transfer(_msgSender(), recipient, amount);
        } else _tokenTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        require(from != burntAddr, "Not available for burn address!");
        if (from == contributorsAddr) {
            require(
                block.timestamp > startLock + 730 days,
                "Lock up period is not over"
            );
        }
        if (from == stakingAddr || from == developmentAddr) {
            require(
                block.timestamp > startLock + 91 days,
                "Lock up period is not over"
            );
        }
        _spendAllowance(from, _msgSender(), amount);
        if (isExcludedFromFee[from] == true) {
            _transfer(from, to, amount);
        } else _tokenTransfer(from, to, amount);
        return true;
    }

    function burn(uint256 amount) public {
        require(_msgSender() == burntAddr, "ERC20: Only for burn address");
        require(
            balanceOf(burntAddr) >= amount,
            "ERC20: burn amount exceeds balance"
        );
        _burn(burntAddr, amount);
    }

    function _tokenTransfer(
        address from,
        address to,
        uint256 amount
    ) private {
        uint256 burnAmt = (amount * burntFee) / PERCENT_BASE;
        uint256 poolAmt = (amount * poolFee) / PERCENT_BASE;
        uint256 marketingAmt = (amount * marketingFee) / PERCENT_BASE;
        uint256 developmentAmt = (amount * developmentFee) / PERCENT_BASE;
        _transfer(
            from,
            to,
            amount - burnAmt - poolAmt - marketingAmt - developmentAmt
        );
        _transfer(from, burntAddr, burnAmt);
        _transfer(from, poolAddr, poolAmt);
        _transfer(from, marketingAddr, marketingAmt);
        _transfer(from, developmentAddr, developmentAmt);
    }
}