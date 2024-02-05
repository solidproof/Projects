//***
//***
//  Website: https://zkhero.app
//  Twitter: https://twitter.com/ZkSyncHero
//  Telegram Chat: https://t.me/ZksyncHero
//  Telegram Channel: https://t.me/ZkSyncHero_ann
//  Testnet: https://testnet.zkhero.app
//***
//***

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IMuteSwitch.sol";
import "./libs/ZkHeroERC20.sol";
import "./libs/ReentrancyGuard.sol";

contract ZkHero is ZkHeroERC20, ReentrancyGuard {
    using SafeMath for uint256;

    mapping(address => bool) bots;
    uint256 public maxSupply = 300 * 10**6 * 10**18;

    IMuteSwitchRouterDynamic public muteSwitchRouter;
    address public muteSwitchPair;

    mapping(address => bool) public isBlacklisted;
    bool private blacklistEnabled = true;

    bool public antiBotEnabled;
    uint256 public antiBotDuration = 10 minutes;
    uint256 public antiBotTime;
    uint256 public antiBotAmount;

    mapping(address => bool) private _isExcludedFromFee;

    event EnableBlacklist(bool enabled);

    constructor(string memory name, string memory symbol, address _manager) ZkHeroERC20(name, symbol, _manager) {
        _mint(_msgSender(), maxSupply.sub(amountFarm).sub(amountPlayToEarn));
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function setBots(address _bots) external onlyOwner {
        require(!bots[_bots]);
        bots[_bots] = true;
    }

    function enableBlacklist(bool enabled) external onlyOwner {
        blacklistEnabled = enabled;
        emit EnableBlacklist(enabled);
    }

    function setBlacklist(address account, bool isBlacklist) external onlyOwner {
        isBlacklisted[account] = isBlacklist;
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        _isExcludedFromFee[holder] = exempt;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        if (
            antiBotTime > block.timestamp &&
            amount > antiBotAmount &&
            bots[sender]
        ) {
            revert("Anti Bot");
        }

        if(pendingLP()){ setLP(); }

        bool isLaunched = !pendingLP();

        if (isLaunched) {

            if (blacklistEnabled && !(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])) {
                require(!isBlacklisted[sender] && !isBlacklisted[recipient], "User blacklisted");
            }

            uint256 transferFeeRate;
            if ((_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) || (sender != muteSwitchPair && recipient != muteSwitchPair)) {
                transferFeeRate = 0;
            } else {
                transferFeeRate = recipient == muteSwitchPair ? sellFeeRate : (sender == muteSwitchPair ? buyFeeRate : 0);
            }

            if (
                transferFeeRate > 0 &&
                sender != address(this) &&
                recipient != address(this)
            ) {
                uint256 _fee = amount.mul(transferFeeRate).div(100);
                super._transfer(sender, address(this), _fee); // TransferFee
                amount = amount.sub(_fee);
            }
        }

        super._transfer(sender, recipient, amount);
    }

    function pendingLP() internal view returns (bool) {
        return muteSwitchPair == address(0);
    }

    function setLP() internal {
        require(pendingLP());

        IMuteSwitchRouterDynamic _muteSwitchRouter = IMuteSwitchRouterDynamic(0x8B791913eB07C32779a16750e3868aA8495F5964);
        muteSwitchRouter = _muteSwitchRouter;

        _approve(address(this), address(muteSwitchRouter), ~uint256(0));

        muteSwitchPair = IMuteSwitchFactoryDynamic(_muteSwitchRouter.factory())
                .getPair(address(this), _muteSwitchRouter.WETH(), false);
        if (muteSwitchPair != address(0)) {
            IERC20(muteSwitchPair).approve(address(muteSwitchRouter), ~uint256(0));
            _approve(address(this), address(muteSwitchPair), ~uint256(0));

            address fees = IMuteSwitchPairDynamic(muteSwitchPair).fees();
            _isExcludedFromFee[fees] = true;
        }
    }

    // receive eth from dex swap
    receive() external payable {}

    function antiBot(uint256 amount) external onlyOwner {
        require(amount > 0, "not accept 0 value");
        require(!antiBotEnabled);

        antiBotAmount = amount;
        antiBotTime = block.timestamp.add(antiBotDuration);
        antiBotEnabled = true;
    }

}
