/*

Wake up, Neo...
The Matrix has you...
Follow the white rabbit.
Knock, knock, Neo.

  _   _              _____                  _____           _                  _ 
 | \ | |            |  __ \                |  __ \         | |                | |
 |  \| | ___  ___   | |__) |__ _ __   ___  | |__) | __ ___ | |_ ___   ___ ___ | |
 | . ` |/ _ \/ _ \  |  ___/ _ \ '_ \ / _ \ |  ___/ '__/ _ \| __/ _ \ / __/ _ \| |
 | |\  |  __/ (_) | | |  |  __/ |_) |  __/ | |   | | | (_) | || (_) | (_| (_) | |
 |_| \_|\___|\___/  |_|   \___| .__/ \___| |_|   |_|  \___/ \__\___/ \___\___/|_|
                              | |                                                
                              |_|                      

*/
/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract NEOP is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 private constant TOTAL_SUPPLY = 1e9 * (10 ** 18); // 1B tokens
    uint256 public constant MAX_FEE = 500; // bps

    IUniswapV2Router02 public uniswapV2router;

    address public uniswapV2Pair;

    address public treasury;

    uint256 public totalBurnedAmount;

    bool public tradingEnabled;

    uint256 public fee = 250; // bps

    uint256 public burnCap = (TOTAL_SUPPLY * 5) / 100; // 5% of total supply

    mapping(address => bool) private _isExcludedFromFees;

    error TradingNotEnabled();
    error TradingAlreadyEnabled();
    error FeeSetupError();

    event TradingEnabled();
    event ExcludedFromFees(address indexed account, bool isExcluded);
    event FeeUpdated(uint256 newFee);
    event TokensBurned(uint256 amount);
    event BurnCapUpdated(uint256 cap);

    constructor(
        address _timelock,
        address _uniswapV2router,
        address presaleSafe,
        address liquiditySafe,
        address marketingSafe,
        address devSafe,
        address ecosystemSafe,
        address giveawaySafe
    ) ERC20("Neo Pepe", "$NEOP") ERC20Permit("$NEOP") Ownable(_timelock) {
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[msg.sender] = true;
        _isExcludedFromFees[address(0xdead)] = true;
        _isExcludedFromFees[presaleSafe] = true;
        _isExcludedFromFees[liquiditySafe] = true;
        _isExcludedFromFees[marketingSafe] = true;
        _isExcludedFromFees[devSafe] = true;
        _isExcludedFromFees[giveawaySafe] = true;
        _isExcludedFromFees[ecosystemSafe] = true;

        uniswapV2router = IUniswapV2Router02(_uniswapV2router);

        _mint(presaleSafe, (TOTAL_SUPPLY * 45) / 100); // 45%
        _mint(liquiditySafe, (TOTAL_SUPPLY * 10) / 100); // 10%
        _mint(marketingSafe, (TOTAL_SUPPLY * 25) / 100); // 25%
        _mint(devSafe, (TOTAL_SUPPLY * 10) / 100); // 10%
        _mint(giveawaySafe, (TOTAL_SUPPLY * 5) / 100); // 5%
        _mint(ecosystemSafe, (TOTAL_SUPPLY * 5) / 100); // 5%
    }

    function nonces(
        address owner
    ) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        bool isExcluded = _isExcludedFromFees[from] || _isExcludedFromFees[to];

        if (!isExcluded && !tradingEnabled) {
            revert TradingNotEnabled();
        }

        if (!isExcluded) {
            if (from == uniswapV2Pair || to == uniswapV2Pair) {
                uint256 fees = (value * fee) / 10000;
                value -= fees;
                super._update(from, treasury, fees);
            }
        }

        super._update(from, to, value);
    }

    function enableTrading(address _treasury) external onlyOwner {
        if (tradingEnabled) {
            revert TradingAlreadyEnabled();
        }

        address pair = IUniswapV2Factory(uniswapV2router.factory()).getPair(
            address(this),
            uniswapV2router.WETH()
        );

        uniswapV2Pair = pair;
        treasury = _treasury;

        tradingEnabled = true;
        _isExcludedFromFees[_treasury] = true;

        emit TradingEnabled();
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= MAX_FEE, "Fee cannot exceed 5%");

        fee = _fee;

        emit FeeUpdated(_fee);
    }

    function setBurnCap(uint256 _cap) external onlyOwner {
        require(
            _cap < (TOTAL_SUPPLY / 2),
            "Cap cannot be more than 50% of total supply"
        );

        burnCap = _cap;

        emit BurnCapUpdated(_cap);
    }

    function excludeFromFees(
        address account,
        bool excluded
    ) external onlyOwner {
        _isExcludedFromFees[account] = excluded;

        emit ExcludedFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function burn(uint256 value) public virtual {
        require(value > 0, "Zero amount");
        require(
            totalBurnedAmount + value <= burnCap,
            "Max burn amount reached"
        );

        totalBurnedAmount += value;

        _burn(_msgSender(), value);

        emit TokensBurned(value);
    }
}