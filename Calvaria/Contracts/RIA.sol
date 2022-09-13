// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./lib/ERC20Capped.sol";
import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";

contract RIA is ERC20Capped, Ownable {
    using SafeMath for uint;

    bool public antiBotEnabled = true;
    uint public constant maxTxAmount = 10 * (10 ** 18);
    uint private constant coolDownInterval = 60;
    mapping (address => bool) private dexPairs;
    mapping (address => bool) private dexRouters;
    mapping (address => uint) private coolDownTimer;
    mapping (address => bool) private excludedFromLimits;

    event Mint(uint indexed amount);
    event Burn(uint indexed amount);

    constructor() ERC20("Calvaria: Duels of Eternity", "RIA") ERC20Capped(1000000000 * (10 ** 18)) {
        setExcludedFromLimits(owner(), true);
        setExcludedFromLimits(address(this), true);
    }

    receive() external payable {}

    function _transfer(address from, address to, uint amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(
            antiBotEnabled &&
            !excludedFromLimits[to] &&
            !excludedFromLimits[from] &&
            (dexPairs[from] || dexRouters[to])
        ) {
            require(maxTxAmount >= amount, "Anti bot: too big amount");
            address trader;
            if(dexPairs[from]) trader = to;
            else trader = from;
            require(block.timestamp > coolDownTimer[trader], "Anti bot: too many trades for the last minute");
            coolDownTimer[trader] = block.timestamp.add(coolDownInterval);
        }

        super._transfer(from, to, amount);
    }

    function mint(uint amount) external onlyOwner {
        super._mint(owner(), amount);
        emit Mint(amount);
    }

    function burn(uint amount) external onlyOwner {
        super._burn(_msgSender(), amount);
        emit Burn(amount);
    }

    function setAntiBot(bool value) external onlyOwner {
        require(antiBotEnabled != value, "Attempt to set the same value");
        antiBotEnabled = value;
    }

    function setDexPair(address pair, bool value) external onlyOwner {
        require(dexPairs[pair] != value, "Attempt to set the same value");
        dexPairs[pair] = value;
    }

    function setDexRouter(address addr, bool value) public onlyOwner {
        require(dexRouters[addr] != value, "Attempt to set the same value");
        dexRouters[addr] = value;
    }

    function setExcludedFromLimits(address account, bool value) public onlyOwner {
        require(excludedFromLimits[account] != value, "Attempt to set the same value");
        excludedFromLimits[account] = value;
    }

    function withdrawTokens(address token, uint amount) external onlyOwner {
        require(token != address(0), "Cannot be zero address");
        require(token != address(this), "Cannot be RIA address");
        IERC20(token).transfer(owner(), amount);
    }

    function withdrawEthers() external onlyOwner {
        (bool success,) = owner().call{value: address(this).balance}("");
        require(success, "Failed to withdraw");
    }
}