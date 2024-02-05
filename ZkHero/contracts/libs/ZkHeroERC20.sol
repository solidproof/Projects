// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IManager.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./ERC20.sol";

contract ZkHeroERC20 is Ownable, ERC20 {
    using SafeMath for uint256;

    uint256 public amountPlayToEarn = 90 * 10**6 * 10**18;
    uint256 public amountFarm = 30 * 10**6 * 10**18;
    uint256 public playToEarnReward;
    uint256 private farmReward;

    IManager public manager;

    uint256 public sellFeeRate = 0;
    uint256 public buyFeeRate = 0;

    constructor(string memory name, string memory symbol, address _manager) ERC20(name, symbol) {
        manager = IManager(_manager);
    }

    modifier onlyFarmOwners() {
        require(manager.farmOwners(_msgSender()), "Caller is not the farmer");
        _;
    }

    modifier onlySummoner() {
        require(manager.summoners(_msgSender()), "Caller is not the summoner");
        _;
    }

    modifier onlyBattlefield() {
        require(manager.battlefields(_msgSender()), "Caller is not the battlefield");
        _;
    }

    function setManager(address _manager) public onlyOwner {
        manager = IManager(_manager);
    }

    function setTransferRate(uint256 _sellFeeRate, uint256 _buyFeeRate) public onlyOwner {
        require(_buyFeeRate <= 10);
        require(_sellFeeRate <= 10);
        sellFeeRate = _sellFeeRate;
        buyFeeRate = _buyFeeRate;
    }

    function farm(address recipient, uint256 amount) external onlyFarmOwners {
        require(amountFarm != farmReward, "Over cap farm");
        require(recipient != address(0), "0x is not accepted here");
        require(amount > 0, "Not accept 0 value");

        farmReward = farmReward.add(amount);
        if (farmReward <= amountFarm) {
            _mint(recipient, amount);
        } else {
            uint256 availableReward = farmReward.sub(amountFarm);
            _mint(recipient, availableReward);
            farmReward = amountFarm;
        }
    }

    function win(address winner, uint256 reward) external onlyBattlefield {
        require(playToEarnReward != amountPlayToEarn, "Over cap play");
        require(winner != address(0), "0x is not accepted here");
        require(reward > 0, "Not accept 0 value");

        playToEarnReward = playToEarnReward.add(reward);
        if (playToEarnReward <= amountPlayToEarn) {
            _mint(winner, reward);
        }else {
            uint256 availableReward = playToEarnReward.sub(amountPlayToEarn);
            _mint(winner, availableReward);
            playToEarnReward = amountPlayToEarn;
        }
    }
}

