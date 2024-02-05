/**
    ***********************************************************
    * Copyright (c) Avara Dev. 2022. (Telegram: @avara_cc)  *
    ***********************************************************

     ▄▄▄·  ▌ ▐· ▄▄▄· ▄▄▄   ▄▄▄·
    ▐█ ▀█ ▪█·█▌▐█ ▀█ ▀▄ █·▐█ ▀█
    ▄█▀▀█ ▐█▐█•▄█▀▀█ ▐▀▀▄ ▄█▀▀█
    ▐█ ▪▐▌ ███ ▐█ ▪▐▌▐█•█▌▐█ ▪▐▌
     ▀  ▀ . ▀   ▀  ▀ .▀  ▀ ▀  ▀  - Ethereum Network

    Avara - Always Vivid, Always Rising Above
    https://avara.cc/
    https://github.com/avara-cc
    https://github.com/avara-cc/AvaraETH/wiki
*/

// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.8.4;

import "./abstract/AvaraModule.sol";
import "./library/SafeMath.sol";

contract StakingModule is AvaraModule {
    using SafeMath for uint256;

    uint32 public constant _1_MONTH_IN_SEC = 2629743;

    uint public stakeCounter;
    IUniswapV3Pool public uniswapPool;

    /**
    * @dev The type of the Stake.
    *
    * `TIME`       - The Stake Holder cannot withdraw until the chosen time period elapses.
    * `MARKET_CAP` - The Stake Holder cannot withdraw until the Market Cap is multiplied by the chosen multiplier.
    * `COMBINED`   - The Stake Holder cannot withdraw until the TIME or MARKET_CAP requirement is fulfilled.
    */
    enum StakeType {
        TIME,
        MARKET_CAP,
        COMBINED
    }

    /**
    * @dev The choosable time periods for the Stake.
    */
    enum TimePeriod {
        _OFF_,
        _1_MONTH,
        _3_MONTHS,
        _6_MONTHS,
        _12_MONTHS
    }

    /**
    * @dev The choosable multipliers for the Stake.
    */
    enum MarketCapX {
        _OFF_,
        _1_5_X,
        _2_X,
        _4_X,
        _10_X,
        _25_X,
        _100_X
    }

    /**
    * @dev The Stake Struct.
    *
    * `id`          - A unique identifier for the Stake.
    * `startTime`   - The timestamp of the block when the stake was made.
    * `value`       - The value of the stake.
    * `rewardValue` - The rewards received for the stake.
    * `startRate`   - The ETH/AVR rate when the stake was made.
    * `stakeType`   - The type of the stake. @see `StakeType`
    * `timePeriod`  - The time period of the stake. @see `TimePeriod`
    * `marketCapX`  - The multiplier of the stake. @see `MarketCapX`
    */
    struct Stake {
        bytes32 id;
        uint32 startTime;
        uint256 value;
        uint256 rewardValue;
        uint256 startRate;
        StakeType stakeType;
        TimePeriod timePeriod;
        MarketCapX marketCapX;
    }

    event UniswapPoolUpdated(address indexed oldAddress, address indexed newAddress);
    event NewStakeHolder(address indexed stakeHolder);
    event NewStake(address indexed stakeHolder, Stake stake);
    event StakeWithdraw(address indexed stakeHolder, uint256 value);
    event RewardDistribution(uint256 rewardValue, uint256 totalStakeAmount, uint256 numberOfStakeHolders, uint256 numberOfStakes);
    event FundsRefilled(uint256 value);
    event FundsUsed(uint256 value);
    event StakeReverted(bytes32 stakeId, address indexed stakeHolder);

    address[] public stakeHolders;

    mapping(address => Stake[]) private _stakes;

    /**
    * @dev Sets the AvaraModule standards and the `uniswapPool` of the Main contract in the StakingModule.
    */
    constructor(address cOwner, address baseContract) AvaraModule(cOwner, baseContract, "Staking", "0.0.1") {
        uniswapPool = IUniswapV3Pool(getBaseContract()._uniswapV3Pool());
    }

    /**
    * @dev Updates the `uniswapPool` to be the same as in the Main contract.
    */
    function updateUniswapPool() external onlyOwner {
        address oldPool = address(uniswapPool);
        uniswapPool = IUniswapV3Pool(getBaseContract()._uniswapV3Pool());

        emit UniswapPoolUpdated(oldPool, address(uniswapPool));
    }

    /**
    * @dev Creates an unique identifier for a Stake.
    */
    function createStakeId() internal returns (bytes32) {
        stakeCounter++;
        return keccak256(abi.encodePacked(stakeCounter));
    }

    /**
    * @dev Retrieves the ETH/AVR rate.
    */
    function getRate() public view returns (uint256, uint32) {
        (uint160 sqrtPriceX96, , , , , , ) = uniswapPool.slot0();
        return (uint256(sqrtPriceX96), uint32(block.timestamp));
    }

    /**
    * @dev Retrieves the Stake structs for the given `stakeHolder`. (if any)
    */
    function getStakes(address stakeHolder) external view returns (Stake[] memory) {
        return _stakes[stakeHolder];
    }

    /**
    * @dev Retrieves a summary of the Module.
    */
    function getStakeSummary() public view returns (uint256 totalStakeValue, uint256 totalRewardValue, uint256 stakeHolderCount, uint256 stakeCount) {
        totalStakeValue = uint256(0);
        totalRewardValue = uint256(0);
        stakeHolderCount = uint256(0);
        stakeCount = uint256(0);
        for (uint256 i = 0; i < stakeHolders.length; i++) {
            if (_stakes[stakeHolders[i]].length > 0) {
                stakeHolderCount++;
                for (uint256 j = 0; j < _stakes[stakeHolders[i]].length; j++) {
                    stakeCount++;
                    totalStakeValue += _stakes[stakeHolders[i]][j].value;
                    totalRewardValue += _stakes[stakeHolders[i]][j].rewardValue;
                }
            }
        }
    }

    /**
    * @dev Retrieves a Stake by the given `stakeId` and `stakeHolder` address.
    */
    function getStakeById(bytes32 stakeId, address stakeHolder) public view returns (bool, Stake memory, uint256) {
        bool stakeFound;
        uint256 index;
        Stake memory stake;

        for (uint256 i = 0; i < _stakes[stakeHolder].length; i++) {
            if (_stakes[stakeHolder][i].id == stakeId) {
                stakeFound = true;
                stake = _stakes[stakeHolder][i];
                index = i;
                break;
            }
        }

        return (stakeFound, stake, index);
    }

    /**
    * @dev Creates a Time Stake for the `_msgSender` for the given value in the Module.
    */
    function addTimeStake(uint256 value, TimePeriod timePeriod) external {
        require(timePeriod <= TimePeriod._12_MONTHS && timePeriod > TimePeriod._OFF_, "Invalid Time Period Value!");

        getBaseContract().transferFrom(_msgSender(), address(this), value);

        (uint256 rate, uint32 timeStamp) = getRate();

        Stake memory stake;
        stake.id = createStakeId();
        stake.value = value;
        stake.marketCapX = MarketCapX._OFF_;
        stake.timePeriod = timePeriod;
        stake.stakeType = StakeType.TIME;
        stake.startTime = timeStamp;
        stake.startRate = rate;

        addStake(stake);
    }

    /**
    * @dev Creates a Multiplier Stake for the `_msgSender` for the given value in the Module.
    */
    function addMultiplierStake(uint256 value, MarketCapX marketCapX) external {
        require(marketCapX <= MarketCapX._100_X && marketCapX > MarketCapX._OFF_, "Invalid Market Cap X Value!");

        getBaseContract().transferFrom(_msgSender(), address(this), value);

        (uint256 rate, uint32 timeStamp) = getRate();

        Stake memory stake;
        stake.id = createStakeId();
        stake.value = value;
        stake.marketCapX = marketCapX;
        stake.timePeriod = TimePeriod._OFF_;
        stake.stakeType = StakeType.MARKET_CAP;
        stake.startTime = timeStamp;
        stake.startRate = rate;

        addStake(stake);
    }

    /**
    * @dev Creates a Combined Stake for the `_msgSender` for the given value in the Module.
    */
    function addCombinedStake(uint256 value, MarketCapX marketCapX, TimePeriod timePeriod) external {
        require(timePeriod <= TimePeriod._12_MONTHS && timePeriod > TimePeriod._OFF_, "Invalid Time Period Value!");
        require(marketCapX <= MarketCapX._100_X && marketCapX > MarketCapX._OFF_, "Invalid Market Cap X Value!");

        getBaseContract().transferFrom(_msgSender(), address(this), value);

        (uint256 rate, uint32 timeStamp) = getRate();

        Stake memory stake;
        stake.id = createStakeId();
        stake.value = value;
        stake.marketCapX = marketCapX;
        stake.timePeriod = timePeriod;
        stake.stakeType = StakeType.COMBINED;
        stake.startTime = timeStamp;
        stake.startRate = rate;

        addStake(stake);
    }

    /**
    * @dev Adds a new Stake to the `_stakes` mapping.
    *
    * Adds the address of the `stakeHolder` to the `stakeHolders` array if it's not already in it.
    */
    function addStake(Stake memory stake) internal {
        bool newStakeHolder = isNewStakeHolder();

        if (newStakeHolder) {
            stakeHolders.push(_msgSender());
            emit NewStakeHolder(_msgSender());
        }

        _stakes[_msgSender()].push(stake);
        emit NewStake(_msgSender(), stake);
    }

    /**
    * @dev Withdraws a Stake by the given Id if the
    * - `_msgSender` is a `stakeHolder`.
    * - The `stakeId` belongs to the `_msgSender`.
    * - The stake conditions are fulfilled.
    * - The Module is supplied with the required amount of tokens to withdraw.
    */
    function withdraw(bytes32 stakeId) external {
        require(!isNewStakeHolder(), "The message sender is not a Stake Holder!");

        (bool stakeFound, Stake memory stake, uint256 index) = getStakeById(stakeId, _msgSender());

        for (uint256 i = 0; i < _stakes[_msgSender()].length; i++) {
            if (_stakes[_msgSender()][i].id == stakeId) {
                stakeFound = true;
                stake = _stakes[_msgSender()][i];
                index = i;
                break;
            }
        }

        require(stakeFound, "The message sender is not the Holder of the given Stake!");
        require(getStakeCondition(stake), "The stake conditions are not fulfilled yet!");

        uint256 withdrawAmount = stake.value + stake.rewardValue;
        require(getBaseContract().balanceOf(address(this)) >= withdrawAmount, "The Stake Module is currently out of supply! Please contact the AVR team!");

        getBaseContract().approve(address(this), withdrawAmount);
        getBaseContract().transferFrom(address(this), _msgSender(), withdrawAmount);

        _stakes[_msgSender()][index] = _stakes[_msgSender()][_stakes[_msgSender()].length - 1];
        delete _stakes[_msgSender()][_stakes[_msgSender()].length - 1];
        _stakes[_msgSender()].pop();

        emit StakeWithdraw(_msgSender(), withdrawAmount);
    }

    /**
    * @dev Returns `true` if the stake conditions are fulfilled, otherwise `false`.
    */
    function getStakeCondition(Stake memory stake) internal view returns (bool) {
        (uint256 rate, uint32 timeStamp) = getRate();

        if (stake.stakeType == StakeType.TIME) {
            return timeStamp >= getFutureTime(stake.startTime, stake.timePeriod);
        } else if (stake.stakeType == StakeType.MARKET_CAP) {
            return getExpectedMarketCap(stake.startRate, stake.marketCapX) <= rate;
        }
        return timeStamp >= getFutureTime(stake.startTime, stake.timePeriod) || getExpectedMarketCap(stake.startRate, stake.marketCapX) <= rate;
    }

    /**
    * @dev Calculates the `endTime` of the stake.
    */
    function getFutureTime(uint32 startTime, TimePeriod timePeriod) internal pure returns (uint32) {
        if (timePeriod == TimePeriod._1_MONTH) {
            return startTime + _1_MONTH_IN_SEC;
        } else if (timePeriod == TimePeriod._3_MONTHS) {
            return startTime + (_1_MONTH_IN_SEC * 3);
        } else if (timePeriod == TimePeriod._6_MONTHS) {
            return startTime + (_1_MONTH_IN_SEC * 6);
        } else {
            return startTime + (_1_MONTH_IN_SEC * 12);
        }
    }

    /**
    * @dev Calculates the expected market cap according to the stake multiplier.
    */
    function getExpectedMarketCap(uint256 startRate, MarketCapX marketCapX) internal pure returns (uint256) {
        if (marketCapX == MarketCapX._1_5_X) {
            return startRate.mul(15).div(10);
        } else if (marketCapX == MarketCapX._2_X) {
            return startRate.mul(2);
        } else if (marketCapX == MarketCapX._4_X) {
            return startRate.mul(4);
        } else if (marketCapX == MarketCapX._10_X) {
            return startRate.mul(10);
        } else if (marketCapX == MarketCapX._25_X) {
            return startRate.mul(25);
        } else {
            return startRate.mul(100);
        }
    }

    /**
    * @dev Returns true if the `_msgSender` is not included in the `stakeHolders` array.
    */
    function isNewStakeHolder() internal view returns (bool) {
        bool newStakeHolder = true;
        for (uint256 i = 0; i < stakeHolders.length; i++) {
            if (stakeHolders[i] == _msgSender()) {
                newStakeHolder = false;
                break;
            }
        }
        return newStakeHolder;
    }

    /**
    * @dev Transfers the given amount of tokens from the Module to the owner.
    */
    function useFunds(uint256 amount) external onlyOwner {
        require(getBaseContract().balanceOf(address(this)) >= amount, "The Stake Module is currently out of supply!");
        getBaseContract().approve(address(this), amount);
        getBaseContract().transferFrom(address(this), owner(), amount);
        emit FundsUsed(amount);
    }

    /**
    * @dev Reverts a stake by the given `stakeId` and `stakeHolder` address.
    */
    function revertStake(bytes32 stakeId, address stakeHolder) external onlyOwner {
        (, , uint256 index) = getStakeById(stakeId, stakeHolder);

        _stakes[stakeHolder][index] = _stakes[stakeHolder][_stakes[stakeHolder].length - 1];
        delete _stakes[stakeHolder][_stakes[stakeHolder].length - 1];
        _stakes[stakeHolder].pop();

        emit StakeReverted(stakeId, stakeHolder);
    }

    /**
    * @dev Transfers the given amount of tokens from the `_msgSender` to the Module.
    */
    function refillFunds(uint256 amount) external {
        getBaseContract().transferFrom(_msgSender(), address(this), amount);
        emit FundsRefilled(amount);
    }

    /**
    * @dev Transfer the given `amount` of tokens to the Module and distribute it between the `stakeHolders` as rewards for their Stakes.
    */
    function distributeRewards(uint256 amount) external {
        (uint256 totalStakeValue, /*uint256 totalRewardValue*/, uint256 stakeHolderCount, uint256 stakeCount) = getStakeSummary();

        require(stakeCount > 0 && stakeHolderCount > 0 && totalStakeValue > 0, "The rewards cannot be distributed, as there aren't any Stakes yet!");
        getBaseContract().transferFrom(_msgSender(), address(this), amount);

        for (uint256 i = 0; i < stakeHolders.length; i++) {
            if (_stakes[stakeHolders[i]].length > 0) {
                for (uint256 j = 0; j < _stakes[stakeHolders[i]].length; j++) {
                    _stakes[stakeHolders[i]][j].rewardValue += amount.mul(_stakes[stakeHolders[i]][j].value.mul(1000).div(totalStakeValue)).div(1000);
                }
            }
        }

        emit RewardDistribution(amount, totalStakeValue, stakeHolderCount, stakeCount);
    }

    /**
    * @dev Occasionally called (only) by the server to make sure that the connection with the module and main contract is granted.
    */
    function ping() external view onlyOwner returns (string memory) {
        return getBaseContract().ping();
    }
}