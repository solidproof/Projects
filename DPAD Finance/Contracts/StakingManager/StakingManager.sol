//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./../ContractsManager/IContractsManager.sol";
import "./../IDODetails/IIDODetails.sol";
import "./../IDOFactory/IIDOFactory.sol";
import "./../Admin/IAdmin.sol";

import "./../TIERS.sol";
import "../PrivateSale/Staking2/IStaking.sol";

contract StakingManager is Initializable {
    using SafeMath for uint;
    IContractsManager contractsManager;
    IERC20 token;

    uint public constant UNSTAKE_WITHDRAWAL_WAIT_TIME = 5 days;

    struct UnStakes {
        uint amount;
        uint unstakedAt;
    }

    struct Stakes {
        uint amount;     // Stake amount
        uint rewardDebt; // Reward amount to be given
    }

    uint public totalStakeAmount;
    uint public accRewardPerShare;

    mapping (address => Stakes) public stakes;
    mapping (address => UnStakes) public unstakes;

    event Staked(address user, uint amount);
    event UnStaked(address user, uint amount);

    function initialize(address _contractsManager) public initializer {
        contractsManager = IContractsManager(_contractsManager);
    }

    function stake(uint _amount) public {
        require(IERC20(contractsManager.tokenAddress()).transferFrom(msg.sender, address(this), _amount), 'StakingManager: Token Transfer Failed');
        withdrawRewards();
        stakes[msg.sender].amount = stakes[msg.sender].amount.add(_amount);
        totalStakeAmount += _amount;
        emit Staked(msg.sender, _amount);
    }

    function unstake(uint _amount) public {
        require(stakes[msg.sender].amount >= _amount, 'StakingManager: Cannot unstake more then you have staked');
        withdrawRewards();
        stakes[msg.sender].amount = stakes[msg.sender].amount.sub(_amount);
        unstakes[msg.sender].amount = unstakes[msg.sender].amount.add(_amount);
        unstakes[msg.sender].unstakedAt = block.timestamp;
        totalStakeAmount -= _amount;
        emit UnStaked(msg.sender, _amount);
    }

    function withdraw() public {
        require(unstakes[msg.sender].amount > 0, 'StakingManager: Nothing to withdraw');
        require(unstakes[msg.sender].unstakedAt <= block.timestamp.sub(UNSTAKE_WITHDRAWAL_WAIT_TIME), 'StakingManager: Please wait for withdrawal lock period');

        require(IERC20(contractsManager.tokenAddress()).transfer(msg.sender, unstakes[msg.sender].amount), 'StakingManager: Token Transfer Failed');

        unstakes[msg.sender].amount = 0;
        unstakes[msg.sender].unstakedAt = block.timestamp;
    }

//
//    function receiveReward() payable public {
//        require(msg.value > 0, "StakingManager: reward must be greater than 0");
//        accRewardPerShare += msg.value / totalStakeAmount;
//    }
//
//    receive() external payable {
//        receiveReward();
//    }

        function receiveReward(uint _amount) public {
            require(_amount > 0, "StakingManager: reward must be greater than 0");
            require(IERC20(contractsManager.busd()).transferFrom(msg.sender, address(this), _amount), "StakingManager: ERC20 Transfer failed");
            accRewardPerShare += _amount / totalStakeAmount;
        }

        function withdrawRewards() public {
            uint amount = stakes[msg.sender].amount.mul(accRewardPerShare).sub(stakes[msg.sender].rewardDebt);
            if (amount > 0) {
                require(IERC20(contractsManager.busd()).transfer(msg.sender, amount), "StakingManager: ERC20 Transfer failed");
//                payable(msg.sender).transfer(amount);
            }
            stakes[msg.sender].rewardDebt = accRewardPerShare;
        }


    // <Voting manager>

    function getVotingPower(address _voter) public view returns(uint) {
        return stakes[_voter].amount;
    }

    // </Voting manager>

    // <Funding Manager>

    function getTier(address _user) public view returns (TIERS.TIER) {
        uint stakedAmount = stakes[_user].amount;

        if (stakedAmount >= 50000 * 1e18) {
            return TIERS.TIER.OG;
        } else if (stakedAmount >= 25000 * 1e18) {
            return TIERS.TIER.PRO;
        } else if (stakedAmount >= 10000 * 1e18) {
            return TIERS.TIER.TRADER;
        } else if (stakedAmount >= 5000 * 1e18) {
            return TIERS.TIER.NOOB;
        }

        return TIERS.TIER.NONE;
    }

    function getMaxPurchaseAmount(uint _idoId, address _user) public view returns (uint) {
        IAdmin _iAdmin = IAdmin(contractsManager.adminContract());
        TIERS.TIER _tier = getTier(_user);

        // Admin contract on all tiers of all ido's
        if (_iAdmin.tierWiseIdoMaxPurchasePerWalletOverrides(_idoId, _tier) > 0) {
            return _iAdmin.tierWiseIdoMaxPurchasePerWalletOverrides(_idoId, _tier);
        }

        IIDOFactory _idoFactory =  IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails =  IIDODetails(_idoFactory.idoIdToIDODetailsContract(_idoId));

//        IStaking staking = IStaking(contractsManager.sixMonthsContract());

//        IStaking stakingUpgradable = IStaking(contractsManager.oneMonthContract());

        uint userStakedToken = stakes[_user].amount;
//        .add(stakingUpgradable.userInfo(1, _user).amount).add(staking.userInfo(1, _user).amount);

        if (userStakedToken < 5000 * 1e18 || totalStakeAmount == 0) {
            return 0;
        }

        // max_purchase_limit = (mini_purchase_limit +  (user_staked_tokens - 5000) / ((total_staked_tokens)/(tokens_to_sale))) * x

        uint16 multiplier = _idoDetails.multiplier();

        uint baseAmount = 5000 * 1e18;

        uint y = baseAmount.mul(_idoDetails.basicIdoDetails().hardCap).div(totalStakeAmount);

        uint maxPurchaseAMount = y.add((userStakedToken.sub(baseAmount).mul(_idoDetails.basicIdoDetails().hardCap).div(totalStakeAmount)));

        if(multiplier > 0) {
            maxPurchaseAMount = maxPurchaseAMount.mul(uint(multiplier));
        }

        return maxPurchaseAMount > _idoDetails.basicIdoDetails().maxPurchasePerWallet ? _idoDetails.basicIdoDetails().maxPurchasePerWallet : maxPurchaseAMount;
    }

    // </Funding Manager>
}
