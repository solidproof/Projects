// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interfaces/ITreasury.sol";

contract Resource is
    ERC20,
    ERC20Burnable,
    Ownable
{
    using SafeMath for uint256;
    using Address for address;
    
    address public treasury;

    mapping(address => bool) public _isExcludedFromFee;

    uint256 public constant _tTotal = 1200000 * 10**18;

    uint256 public sellFee;

    modifier onlyTreasury() {
        address sender = _msgSender();
        require(
            sender == address(treasury),
            "Resource: Not treasury address"
        );
        _;
    }

    constructor() ERC20("MILK", "MILK") {
        _isExcludedFromFee[owner()] = true;
        _mint(owner(), _tTotal);
        sellFee = 25;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Resource: transfer from the zero address");
        require(to != address(0), "Resource: transfer to the zero address");
        
        uint256 fees = 0;

        if (!_isExcludedFromFee[from]) {
            if (to == address(ITreasury(treasury).uniswapV2Pair())) {
                fees = amount.mul(sellFee).div(100);
            }
            amount = amount.sub(fees);
        }

        if (fees > 0) {
            super._transfer(from, treasury, fees);
        }
        super._transfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
    }

    function mintByTreasury(address account, uint256 amount) external onlyTreasury {
        super._mint(account, amount);
    }

    function burnByTreasury(address account, uint256 amount) external onlyTreasury {
        super._burn(account, amount);
    }

    function excludeFromFee(address account, bool status) external onlyTreasury {
        _isExcludedFromFee[account] = status;
    }

    function setSellFee(uint256 _fee) external onlyTreasury() {
        require(_fee >= 0 && _fee <= 25, "Resource: 0 <= fee <= 25");
        sellFee = _fee;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Resource: !_treasury!");
        require(treasury == address(0), "Resource: Treasury");
        require(_treasury.isContract(), "Resource: _treasury is not contract");
        treasury = _treasury;
        _isExcludedFromFee[treasury] = true;
        _isExcludedFromFee[ITreasury(treasury).masterchef()] = true;
        _isExcludedFromFee[ITreasury(treasury).nftManager()] = true;
    }

    function recoverLostETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverLostTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(address(this) != _token, "Resource: !resource!");
        IERC20(_token).transfer(_to, _amount);
    }
}