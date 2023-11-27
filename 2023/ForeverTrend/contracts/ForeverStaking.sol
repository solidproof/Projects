// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
 /$$$$$$$$ /$$$$$$  /$$$$$$$  /$$$$$$$$ /$$    /$$ /$$$$$$$$ /$$$$$$$
| $$_____//$$__  $$| $$__  $$| $$_____/| $$   | $$| $$_____/| $$__  $$
| $$     | $$  \ $$| $$  \ $$| $$      | $$   | $$| $$      | $$  \ $$
| $$$$$  | $$  | $$| $$$$$$$/| $$$$$   |  $$ / $$/| $$$$$   | $$$$$$$/
| $$__/  | $$  | $$| $$__  $$| $$__/    \  $$ $$/ | $$__/   | $$__  $$
| $$     | $$  | $$| $$  \ $$| $$        \  $$$/  | $$      | $$  \ $$
| $$     |  $$$$$$/| $$  | $$| $$$$$$$$   \  $/   | $$$$$$$$| $$  | $$
|__/      \______/ |__/  |__/|________/    \_/    |________/|__/  |__/

         /$$
       /$$$$$$\ /$$$$$$$$ /$$$$$$$  /$$$$$$$$ /$$   /$$ /$$$$$$$
      /$$__  $$||_  $$__/| $$__  $$| $$_____/| $$$ | $$| $$__  $$
     | $$  \__/   | $$   | $$  \ $$| $$      | $$$$| $$| $$  \ $$
     |  $$$$$$    | $$   | $$$$$$$/| $$$$$   | $$ $$ $$| $$  | $$
      \____  $$   | $$   | $$__  $$| $$__/   | $$  $$$$| $$  | $$
      /$$  \ $$   | $$   | $$  \ $$| $$      | $$\  $$$| $$  | $$
     |  $$$$$$/   | $$   | $$  | $$| $$$$$$$$| $$ \  $$| $$$$$$$/
      \_  $$_/    |__/   |__/  |__/|________/|__/  \__/|_______/
        \__/

   Contract: ForeverStaking
*/

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IForeverProfitSplitter {
    function takeBalance() external;
}

interface IWETH is IERC20 {
    function withdraw(uint256) external;
}


contract sTREND is ERC20, Ownable {
    constructor() ERC20("Staked FOREVER", "sTREND") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}

contract ForeverStaking is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    bool public stakingEnabled = false;

    uint256 public minimumStakeAmount = 1000 * 1e18;

    address public weth;
    IERC20 public immutable trendContract;
    sTREND public sTrendContract;

    IForeverProfitSplitter public profitSplitter;

    uint256 trendContractMaxWallet = 2500000 * 1e18;

    EnumerableSet.AddressSet private stakerAddresses;
    mapping(address => bool) public isStaking;
    mapping(address => uint256) public amountOfTRENDStaked;
    mapping(address => uint256) public amountOfEthOwed;

    event MinimumStakeAmountSet(uint256 newMinimumStakeAmount);
    event MinimumStakeDurationSet(uint newMinimumStakeDuration);
    event MaximumStakeDurationSet(uint newMaximumStakeDuration);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event UnstakedAll(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event PaymentDistributed(uint256 ethAmount);
    event PaymentReceivedButNotDistributed(uint256 ethAmount);
    event ProfitSplitterSet(address _profitSplitter);
    event ProfitSplitterBalanceTaken();
    event WethSet(address weth);
    event StakingEnabled();

    constructor(address _trendAddress) {
        trendContract = IERC20(_trendAddress);
        sTrendContract = new sTREND();
    }

    receive() external payable {
        uint256 numberOfEthInTransaction = msg.value;
        uint256 stakerAddressLength = stakerAddresses.length();

        if (stakerAddressLength > 0) {
            uint256 _amountOfTrendInContract = trendContract.balanceOf(address(this));

            for (uint256 i = 0; i < stakerAddressLength; i++) {
                address staker = stakerAddresses.at(i);
                if (isStaking[staker]) {
                    amountOfEthOwed[staker] += (numberOfEthInTransaction * ((amountOfTRENDStaked[staker] * 1000000000) / _amountOfTrendInContract)) / 1000000000;
                }
            }
            emit PaymentDistributed(numberOfEthInTransaction);
        } else {
            emit PaymentReceivedButNotDistributed(numberOfEthInTransaction);
        }
    }

    function enableStaking() external onlyOwner {
        require(!stakingEnabled, "Staking is already enabled");
        stakingEnabled = true;
        emit StakingEnabled();
    }

    function setWETH(address _weth) external onlyOwner {
        require(_weth != address(0) && _weth != address(0x000000000000000000000000000000000000dEaD), "New weth address can not be address 0x");
        weth = _weth;
        emit WethSet(_weth);
    }

    function setProfitSplitter(address _profitSplitter) external onlyOwner {
        require(_profitSplitter != address(0) && _profitSplitter != address(0x000000000000000000000000000000000000dEaD), "New ProfitSplitter can not be address 0x");
        require(_profitSplitter != address(profitSplitter), "ProfitSplitter already set to this address");

        profitSplitter = IForeverProfitSplitter(_profitSplitter);

        emit ProfitSplitterSet(_profitSplitter);
    }

    function setMinimimStakeAmount(uint256 _newMinimumStakeAmount) external onlyOwner {
        require(_newMinimumStakeAmount != minimumStakeAmount, "The new amount is the same as the current amount");
        require(_newMinimumStakeAmount <= 100000000, "The new amount is bigger then the TREND total supply");

        minimumStakeAmount = _newMinimumStakeAmount;

        emit MinimumStakeAmountSet(_newMinimumStakeAmount);
    }

    function takeBalanceFromProfitSplitter() external onlyOwner {
        profitSplitter.takeBalance();
        emit ProfitSplitterBalanceTaken();
    }

    function stake(uint256 _amount) external {
        require(stakingEnabled, "Staking is not yet enabled.");
        require(_amount >= minimumStakeAmount, "Stake amount is too small");
        require(trendContract.allowance(_msgSender(), address(this)) >= _amount, "Stake amount exceeds allowance");
        require(trendContract.transferFrom(_msgSender(), address(this), _amount), "Failed to transfer tokens");

        stakerAddresses.add(_msgSender());

        isStaking[_msgSender()] = true;

        amountOfTRENDStaked[_msgSender()] += _amount;
        sTrendContract.mint(_msgSender(), _amount);

        emit Staked(_msgSender(), _amount);
    }

    function unstake(uint256 _amount) public {
        require(isStaking[_msgSender()], "Address is not staking at the moment");
        require(sTrendContract.balanceOf(_msgSender()) >= _amount, "Address is not staking that many tokens");
        uint256 _amountOfTRENDStaked = amountOfTRENDStaked[_msgSender()];

        if (_amountOfTRENDStaked == _amount) {
            unstakeAll();
            return;
        }

        require(trendContract.transfer(_msgSender(), _amount), "Failed to transfer the tokens back");

        amountOfTRENDStaked[_msgSender()] -= _amount;
        sTrendContract.burn(_msgSender(), _amount);

        emit Unstaked(_msgSender(), _amount);
    }

    function unstakeAll() public {
        require(isStaking[_msgSender()], "Address is not staking at the moment");
        uint256 _amountOfTRENDStaked = amountOfTRENDStaked[_msgSender()];
        require(sTrendContract.balanceOf(_msgSender()) == _amountOfTRENDStaked, "Address is not staking that many tokens, or moved the sTREND tokens");
        require(trendContract.transfer(_msgSender(), _amountOfTRENDStaked), "Failed to transfer the tokens back");

        amountOfTRENDStaked[_msgSender()] = 0;
        isStaking[_msgSender()] = false;
        sTrendContract.burn(_msgSender(), _amountOfTRENDStaked);
        stakerAddresses.remove(_msgSender());

        (bool ethSendSuccess,) = address(_msgSender()).call{value : amountOfEthOwed[_msgSender()]}("");
        require(ethSendSuccess, "Transfer failed.");

        amountOfEthOwed[_msgSender()] = 0;

        emit UnstakedAll(_msgSender(), _amountOfTRENDStaked);
    }

    function claim() public {
        require(isStaking[_msgSender()], "Address is not staking at the moment");
        uint256 _amountOfEthOwed = amountOfEthOwed[_msgSender()];
        require(_amountOfEthOwed != 0, "Address has nothing to claim");

        (bool ethSendSuccess,) = address(_msgSender()).call{value : _amountOfEthOwed}("");
        require(ethSendSuccess, "Transfer failed.");

        amountOfEthOwed[_msgSender()] = 0;

        emit Claimed(_msgSender(), _amountOfEthOwed);
    }

    function rescueWETH() external {
        IWETH(weth).withdraw(IERC20(weth).balanceOf(address(this)));
    }

    function rescueETH() external onlyOwner {
        uint256 _balance = address(this).balance;
        require(_balance > 0, "No ETH to withdraw");

        (bool success,) = owner().call{value : _balance}("");
        require(success, "ETH transfer failed");
    }

    function rescueTokens() external onlyOwner {
        uint256 _stakerCount = stakerAddresses.length();
        for (uint256 i = 0; i < _stakerCount; i++) {
            address _staker = stakerAddresses.at(i);
            uint256 stakedAmount = amountOfTRENDStaked[_staker];
            if (stakedAmount > 0) {
                amountOfTRENDStaked[_staker] = 0;
                isStaking[_staker] = false;

                trendContract.transfer(_staker, stakedAmount);

                emit Unstaked(_staker, stakedAmount);
            }
        }

        while (stakerAddresses.length() > 0) {
            stakerAddresses.remove(stakerAddresses.at(0));
        }
    }
}
