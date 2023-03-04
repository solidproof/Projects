// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

error TransferFailed();
error NeedsMoreThanZero();

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Staking is ReentrancyGuard {
    struct Stake {
        uint256 nftId;
        uint256 amount;
        uint48 timestamp;
        bool haveNFT;
        uint48 stakeTime;
    }

    mapping(address => Stake) public stakes;
    IERC20 public s_rewardsToken;
    IERC20 public s_stakingToken;
    IERC1155 public s_nft;

    mapping(address => uint256) public vestings;

    address public owner;
    uint256 public constant REWARD_RATE = 100;
    uint256 public s_lastUpdateTime;
    uint256 public s_rewardPerTokenStored;

    uint256[] public nftValue = [5, 25, 40, 50];

    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    uint256 private s_totalSupply;
    mapping(address => uint256) public s_balances;

    event Staked(address indexed user, uint256 indexed amount);
    event WithdrewStake(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);

    constructor(address rewardsToken, address stakingToken, address nft) {
        owner = msg.sender;
        s_rewardsToken = IERC20(rewardsToken);
        s_stakingToken = IERC20(stakingToken);
        s_nft = IERC1155(nft);
    }

    /**
     * @notice How much reward a token gets based on how long it's been in and during which "snapshots"
     */
    function rewardPerToken(
        bool haveNft,
        uint256 nftId
    ) public view returns (uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        if (haveNft) {
            return
                s_rewardPerTokenStored +
                (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) /
                    s_totalSupply) +
                (((block.timestamp - s_lastUpdateTime) *
                    nftValue[nftId] *
                    1e18) / s_totalSupply);
        } else {
            return
                s_rewardPerTokenStored +
                (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) /
                    s_totalSupply);
        }
    }

    /**
     * @notice How much reward a user has earned
     */
    function earned(address account) public view returns (uint256) {
        return
            (s_balances[account] *
                (rewardPerToken(
                    stakes[account].haveNFT,
                    stakes[account].nftId
                ) - s_userRewardPerTokenPaid[account])) /
            1e18 +
            s_rewards[account];
    }

    /**
     * @notice Deposit tokens into this contract or with Nft
     * @param amount | How much to stake
     * @param _haveNft | Stake with Nft
     * @param _nftId | Nft id
     * @param stakeTime | how long will it be staked
     */
    function stake(
        uint256 amount,
        bool _haveNft,
        uint256 _nftId,
        uint48 stakeTime
    )
        external
        updateReward(msg.sender, _haveNft, _nftId)
        nonReentrant
        moreThanZero(amount)
    {
        require(!(stakes[msg.sender].amount > 0),"You already have a stake");
        if(
           stakeTime >block.timestamp
        ){
            revert NeedsMoreThanZero();
        }
        if (_haveNft) {
            s_nft.safeTransferFrom(msg.sender, address(this), _nftId, 1, "");
            stakes[msg.sender].haveNFT = true;
            stakes[msg.sender].nftId = _nftId;
        }

        s_stakingToken.transferFrom(msg.sender, address(this), amount);
        s_totalSupply = s_totalSupply + amount;
        s_balances[msg.sender] = s_balances[msg.sender] + amount;
        stakes[msg.sender].amount = stakes[msg.sender].amount + amount;
        stakes[msg.sender].timestamp = uint48(block.timestamp);
        stakes[msg.sender].stakeTime = stakeTime;
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraw tokens from this contract
     */
    function withdraw()
        external
        updateReward(msg.sender, stakes[msg.sender].haveNFT, stakes[msg.sender].nftId)
        nonReentrant
    {
        if (
            block.timestamp - stakes[msg.sender].timestamp <
            stakes[msg.sender].stakeTime
        ) {
            withdrawWithPenalty();
        } else {
            if (stakes[msg.sender].haveNFT) {
                s_nft.safeTransferFrom(
                    address(this),
                    msg.sender,
                    stakes[msg.sender].nftId,
                    1,
                    ""
                );
                stakes[msg.sender].haveNFT = false;
                stakes[msg.sender].nftId = 0;
            }

            uint256 amount = s_balances[msg.sender];
            s_totalSupply = s_totalSupply - amount;
            s_balances[msg.sender] = 0;
            s_stakingToken.transfer(msg.sender, amount);
            emit WithdrewStake(msg.sender, amount);
        }
    }

    /**
     * @notice Claim rewards
     */
    function claimReward()
        external
        updateReward(msg.sender, stakes[msg.sender].haveNFT, stakes[msg.sender].nftId)
        nonReentrant
    {
        uint relasableAmount = calculateRelasableAmount();
        if (relasableAmount > 0) {
            s_rewards[msg.sender] -= relasableAmount;
            s_stakingToken.transfer(msg.sender, relasableAmount);
            emit RewardsClaimed(msg.sender, relasableAmount);
        }

    }

    /**
     * @notice Withdraw tokens with penalty
     */
    function withdrawWithPenalty()
        internal
        updateReward(msg.sender,stakes[msg.sender].haveNFT, stakes[msg.sender].nftId)
    {
        uint256 amount = s_balances[msg.sender];
        uint256 penalty = (amount * 10) / 100;
        s_totalSupply = s_totalSupply - amount;
        s_balances[msg.sender] = 0;
        s_stakingToken.transfer(msg.sender, amount - penalty);
        emit WithdrewStake(msg.sender, amount);
    }

    /**
     * @notice Calculate open stake time
     */
    function calculateRelasableAmount() public view returns (uint) {
        uint currentTime = block.timestamp;
        uint vestingStart = stakes[msg.sender].timestamp + 604800;
        uint vestingEnd = calculateOpenStakeTime(msg.sender);
        uint earnedToken = s_rewards[msg.sender];
        uint relasableAmount = 0;
        uint interval = stakes[msg.sender].stakeTime / 5;

        if (currentTime < vestingStart) {
            relasableAmount = 0;
        }
        uint256 counter = 0;
        while (counter < 5) {
            if (currentTime >= vestingStart + (interval * counter) && currentTime < vestingStart + (interval * (counter + 1))) {
                relasableAmount = earnedToken;
            }
            counter++;
        }
        if (currentTime >= vestingEnd) {
            relasableAmount = earnedToken;
        }
        return relasableAmount;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    /********************/
    /* Modifiers Functions */
    /********************/
    modifier updateReward(
        address account,
        bool haveNft,
        uint256 nftId
    ) {
        if (haveNft) {
            s_rewardPerTokenStored = rewardPerToken(haveNft, nftId);
        } else {
            s_rewardPerTokenStored = rewardPerToken(false, 0);
        }

        s_lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            s_rewards[account] = earned(account);
            s_userRewardPerTokenPaid[account] = s_rewardPerTokenStored;
        }
        _;
    }
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    /********************/
    /* Getter Functions */
    /********************/

    //calculate for special timestamp prize

    function rewardPerTokenStored() public view returns (uint256) {
        return s_rewardPerTokenStored;
    }

    //  reward with finish stake lock time

    function calculateReward(address account) public view returns (uint256) {
        return earned(account);
    }

    function calculateOpenStakeTime(
        address account
    ) public view returns (uint256) {
        return stakes[account].stakeTime + stakes[account].timestamp;
    }

    function getStaked(address account) public view returns (uint256) {
        return s_balances[account];
    }

    function getStakedNft(address account) public view returns (uint256) {
        return stakes[account].nftId;
    }

    function changePercentNFTs(
        uint256 _bronze,
        uint256 _silver,
        uint256 _gold,
        uint256 _platinium
    ) public onlyOwner returns (uint256[] memory) {
        nftValue[0] = _bronze;
        nftValue[1] = _silver;
        nftValue[2] = _gold;
        nftValue[3] = _platinium;
        return nftValue;
    }
}
