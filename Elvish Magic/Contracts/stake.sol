// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

error TransferFailed();
error NeedsMoreThanZero();

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

interface IERC1155Receiver is IERC165 {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC1155 is IERC165 {
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );
    event URI(string value, uint256 indexed id);

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

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
        uint256 interest;
        uint48 stakeTime;
    }

    mapping(address => Stake) public stakes;
    IERC20 public immutable s_rewardsToken;
    IERC20 public immutable s_stakingToken;
    IERC1155 public immutable s_nft;

    address public owner;
    uint256 public constant REWARD_RATE = 1000;
    uint256 public s_lastUpdateTime;
    uint256 public s_rewardPerTokenStored;

    uint256[] public nftValues = [5, 10, 15, 20];
    uint256[] public timeValues = [5, 10];

    mapping(address => uint256) public s_userRewardPerTokenPaid;
    mapping(address => uint256) public s_rewards;

    uint256 public s_totalSupply;
    uint256 public s_totalStaker;
    mapping(address => uint256) public s_balances;

    event Staked(address indexed user, uint256 indexed amount);
    event WithdrewStake(address indexed user, uint256 indexed amount);
    event RewardsClaimed(address indexed user, uint256 indexed amount);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor(address rewardsToken, address stakingToken, address nft) {
        owner = msg.sender;
        s_rewardsToken = IERC20(rewardsToken);
        s_stakingToken = IERC20(stakingToken);
        s_nft = IERC1155(nft);
    }

    /**
     * @notice How much reward a token gets based on how long it's been in and during which "snapshots"
     */
    function rewardPerToken(address account) public view returns (uint256) {
        uint256 totalSupply = s_totalSupply;
        uint256 apr = stakes[account].interest;
        uint256 totalApr = REWARD_RATE + ((REWARD_RATE * apr) / 100);

        if (totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        return
            s_rewardPerTokenStored +
            ((block.timestamp - s_lastUpdateTime) * totalApr * 1e18) /
            totalSupply;
    }

    /**
     * @notice How much reward a user has earned
     */
    function earned(address account) public view returns (uint256) {
        return
            (s_balances[account] *
                (rewardPerToken(account) - s_userRewardPerTokenPaid[account])) /
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
    ) external updateReward(msg.sender) nonReentrant moreThanZero(amount) {
        require(_nftId < 4, "Nft id must smaller than 4");
        require(!(stakes[msg.sender].amount > 0), "You already have a stake");
        require(
            stakeTime == 90 days || stakeTime == 30 days,
            "Stake time must be 30 or 90 days"
        );
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
        stakes[msg.sender].interest = calculateInterest(
            _haveNft,
            _nftId,
            stakeTime
        );
        s_totalStaker = s_totalStaker + 1;
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Withdraw tokens from this contract
     */
    function withdraw() external updateReward(msg.sender) nonReentrant {
        require(stakes[msg.sender].amount > 0, "You don't have a stake");
        require(
            block.timestamp - stakes[msg.sender].timestamp > 1 days,
            "You can't withdraw yet"
        );
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
            delete (stakes[msg.sender]);
            s_stakingToken.transfer(msg.sender, amount);
            s_totalStaker = s_totalStaker - 1;
            emit WithdrewStake(msg.sender, amount);
        }
    }

    /**
     * @notice Claim rewards
     */
    function claimReward() external updateReward(msg.sender) nonReentrant {
        uint relasableAmount = calculateRelasableAmount();
        if (relasableAmount > 0) {
            s_rewards[msg.sender] -= relasableAmount;
            s_stakingToken.transfer(msg.sender, relasableAmount);
            emit RewardsClaimed(msg.sender, relasableAmount);
        } else {
            revert("You don't have any rewards");
        }
    }

    /**
     * @notice Withdraw tokens with penalty
     */
    function withdrawWithPenalty() internal updateReward(msg.sender) {
        require(stakes[msg.sender].amount > 0, "You don't have a stake");
        require(
            block.timestamp - stakes[msg.sender].timestamp > 1 days,
            "You can't withdraw yet"
        );
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
        uint256 penalty = (amount * 20) / 100;
        s_totalSupply = s_totalSupply - amount;
        s_balances[msg.sender] = 0;
        delete (stakes[msg.sender]);
        s_stakingToken.transfer(msg.sender, amount - penalty);
        s_totalStaker = s_totalStaker - 1;
        emit WithdrewStake(msg.sender, amount);
    }

    /**
     * @notice Calculate open stake time
     */
    function calculateRelasableAmount() public view returns (uint) {
        uint currentTime = block.timestamp;
        uint vestingStart = stakes[msg.sender].timestamp + 1 days;
        uint earnedToken = s_rewards[msg.sender];
        uint relasableAmount = 0;

        if (currentTime < vestingStart) {
            relasableAmount = 0;
        } 
        else{
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

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function removeStuckToken(address _address) external onlyOwner {
        require(_address != address(this), "Can't withdraw tokens destined for liquidity");
        require(IERC20(_address).balanceOf(address(this)) > 0, "Can't withdraw 0");

        IERC20(_address).transfer(owner, IERC20(_address).balanceOf(address(this)));
    }
    /********************/
    /* Modifiers Functions */
    /********************/
    modifier updateReward(address account) {
        s_rewardPerTokenStored = rewardPerToken(account);

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
    function calculateOpenStakeTime(
        address account
    ) public view returns (uint256) {
        return stakes[account].stakeTime + stakes[account].timestamp;
    }

    function getStaked(address account) public view returns (uint256) {
        return s_balances[account];
    }

    function changePercentNFTs(
        uint256 _bronze,
        uint256 _silver,
        uint256 _gold,
        uint256 _platinum
    ) public onlyOwner returns (uint256[] memory) {
        nftValues[0] = _bronze;
        nftValues[1] = _silver;
        nftValues[2] = _gold;
        nftValues[3] = _platinum;
        return nftValues;
    }

    function changePercentTimeValues(
        uint256 _oneMonth,
        uint256 _threeMonth
    ) public onlyOwner returns (uint256[] memory) {
        timeValues[0] = _oneMonth;
        timeValues[1] = _threeMonth;
        return timeValues;
    }

    function calculateInterest(
        bool _haveNft,
        uint256 _nftId,
        uint256 lockTime
    ) public view returns (uint256) {
        require(_nftId < 4, "Nft id must smaller than 4");
        require(
            lockTime == 90 days || lockTime == 30 days,
            "Stake time must be 30 or 90 days"
        );
        uint256 apr = 0;
        if (_haveNft) {
            uint256 nftType = _nftId;
            apr = nftValues[nftType];
        }
        if (lockTime == 30 days) {
            apr = apr + timeValues[0];
        } else if (lockTime == 90 days) {
            apr = apr + timeValues[1];
        }
        return apr;
    }
}
