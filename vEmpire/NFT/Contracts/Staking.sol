// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract StakeNFT is
    Initializable,
    UUPSUpgradeable,
    IERC721ReceiverUpgradeable,
    OwnableUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Keep track of user deposited tokens.
     */
    mapping(address => EnumerableSetUpgradeable.UintSet) private _deposits;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public userAmount;

    /**
     * @dev Keep track of rewards distributed.
     */
    uint256 public accPerShare;
    uint256 public lastRewardBalance;
    uint256 public totalReward;
    uint256 public lastTotalReward;
    uint256 public totalStaked;

    /**
     * @dev Contract addresses.
     */
    address public ERC20_CONTRACT;
    address public ERC721_CONTRACT;

    /**
     * @dev Events
     */
    event Deposit(uint256 indexed amount, uint256[] tokenIds);
    event Withdraw(uint256 indexed amount, uint256[] tokenIds);
    event ClaimReward(uint256 indexed amount);

    /**
     * @dev Initialize function. Only called one time at time of deployment.
     */
    function initialize(address _erc20Token, address _erc721Token)
        public
        initializer
    {
        require(_erc20Token != address(0), "initialize: zero address");
        require(_erc721Token != address(0), "initialize: zero address");
        OwnableUpgradeable.__Ownable_init();
        ERC20_CONTRACT = _erc20Token;
        ERC721_CONTRACT = _erc721Token;
    }

    /**
     * @dev Authorize upgrade so that only owner can upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Function to claim reward and update total claimed rewards details.
     */
    function claimRewards() public {
        uint256 rewardBalance = IERC20Upgradeable(ERC20_CONTRACT).balanceOf(
            address(this)
        );
        uint256 _totalReward = totalReward.add(
            rewardBalance.sub(lastRewardBalance)
        );
        lastRewardBalance = rewardBalance;
        totalReward = _totalReward;

        uint256 supply = totalStaked;
        if (supply == 0) {
            accPerShare = 0;
            lastTotalReward = 0;
            rewardDebt[msg.sender] = 0;
            lastRewardBalance = 0;
            totalReward = 0;
            return;
        }

        uint256 reward = _totalReward.sub(lastTotalReward);
        accPerShare = accPerShare.add(reward.mul(10000).div(supply));
        lastTotalReward = _totalReward;

        uint256 userReward = userAmount[msg.sender]
            .mul(accPerShare)
            .div(10000)
            .sub(rewardDebt[msg.sender]);

        IERC20Upgradeable(ERC20_CONTRACT).transfer(msg.sender, userReward);
        lastRewardBalance = IERC20Upgradeable(ERC20_CONTRACT).balanceOf(
            address(this)
        );

        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(
            10000
        );
        emit ClaimReward(userReward);
    }

    /**
     * @dev Check how many token user can claim.
     *
     * @param userAddress. User address to check reward.
     */
    function claimableRewards(address userAddress)
        external
        view
        returns (uint256)
    {
        uint256 totalNftSupply = totalStaked;
        uint256 accTokenPerShare = accPerShare;
        if (totalNftSupply != 0) {
            uint256 rewardBalance = IERC20Upgradeable(ERC20_CONTRACT).balanceOf(
                address(this)
            );
            uint256 _totalReward = rewardBalance.sub(lastRewardBalance);
            accTokenPerShare = accPerShare.add(
                _totalReward.mul(10000).div(totalNftSupply)
            );
        }
        return
            userAmount[userAddress].mul(accTokenPerShare).div(10000).sub(
                rewardDebt[userAddress]
            );
    }

    /**
     * @notice Deposit/Stake NFT token.
     *
     * @dev Deposit token by passing array of token Ids.
     *
     * @param tokenIds. Token Ids to deposit.
     */
    function deposit(uint256[] calldata tokenIds) external {
        claimRewards();

        for (uint256 i; i < tokenIds.length; i++) {
            IERC721Upgradeable(ERC721_CONTRACT).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i],
                ""
            );
            _deposits[msg.sender].add(tokenIds[i]);
        }
        totalStaked = totalStaked.add(tokenIds.length);
        userAmount[msg.sender] = userAmount[msg.sender].add(tokenIds.length);
        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(
            10000
        );
        emit Deposit(tokenIds.length, tokenIds);
    }

    /**
     * @notice Withdraw/Unstake NFT token.
     *
     * @dev Withdraw token by passing array of token Ids.
     *
     * @param tokenIds. Token Ids to withdraw.
     */
    function withdraw(uint256[] calldata tokenIds) external {
        claimRewards();

        for (uint256 i; i < tokenIds.length; i++) {
            require(
                _deposits[msg.sender].contains(tokenIds[i]),
                "withdraw: Token not deposited"
            );

            _deposits[msg.sender].remove(tokenIds[i]);

            IERC721Upgradeable(ERC721_CONTRACT).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds[i],
                ""
            );
        }
        userAmount[msg.sender] = userAmount[msg.sender].sub(tokenIds.length);
        totalStaked = totalStaked.sub(tokenIds.length);
        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(
            10000
        );
        emit Withdraw(tokenIds.length, tokenIds);
    }

    /**
     * @dev Get list of total deposited tokens.
     *
     * @param account. User address to check list of token.
     */
    function depositsOf(address account)
        external
        view
        returns (uint256[] memory)
    {
        EnumerableSetUpgradeable.UintSet storage depositSet = _deposits[
            account
        ];
        uint256[] memory tokenIds = new uint256[](depositSet.length());

        for (uint256 i; i < depositSet.length(); i++) {
            tokenIds[i] = depositSet.at(i);
        }

        return tokenIds;
    }

    /**
     * @dev Function to receive the ERC721 tokens.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}