// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../Base.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

abstract contract ERC1155RewardsNonReceiver is BaseStaking {
    IERC1155 internal _rewardToken;
    uint256 internal _rewardNftId;

    event RewardNftTokenChanged(address token, uint256 nftId);

    /**
     * @dev Allows setting the reward token.
     * @param token The address of the reward token.
     * @param id The ID of the reward token.
     */
    function setRewardToken(address token, uint256 id) external onlyOwner {
        require(token != address(0), "Can't set token to address(0)");
        _rewardToken = IERC1155(token);
        _rewardNftId = id;
        emit RewardNftTokenChanged(token, id);
    }

    /**
     * @dev Returns the address of the reward token.
     * @return (address, uint256) The address and ID of the reward token.
     */
    function getRewardToken() external view returns (address, uint256) {
        return (address(_rewardToken), _rewardNftId);
    }

    /**
     * @dev Allows adding rewards to the pool.
     * @param amount The amount of rewards to be added to the pool.
     */
    function addReward(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 tokens");
        _rewardPoolSize += amount;
        _rewardToken.safeTransferFrom(
            _msgSender(),
            address(this),
            _rewardNftId,
            amount,
            ""
        );
        emit RewardsAdded(amount);
    }

    /**
     * @dev Allows recovering rewards from the pool.
     * @param amount The amount of rewards to be recovered from the pool.
     */
    function recoverRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Cannot remove 0 tokens");
        require(
            _rewardPoolSize >= amount,
            "Cannot remove more than originally added"
        );
        _rewardPoolSize -= amount;
        _rewardToken.safeTransferFrom(
            address(this),
            _msgSender(),
            _rewardNftId,
            amount,
            ""
        );
        emit RewardsRecovered(amount);
    }

    /**
     * @dev Sends rewards to a user.
     * @param user The address of the user.
     * @param amount The amount of rewards to be sent to the user.
     */
    function sendRewards(address user, uint256 amount)
        internal
        override(BaseStaking)
    {
        if (amount > 0 && address(_rewardToken) != address(0)) {
            _rewardToken.safeTransferFrom(
                address(this),
                user,
                _rewardNftId,
                amount,
                ""
            );
        }
    }
}

abstract contract ERC1155Rewards is
    BaseStaking,
    IERC165,
    ERC1155RewardsNonReceiver,
    IERC1155Receiver
{
    /**
     * @dev See {IERC1155-onERC1155Received}.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view returns (bytes4) {
        return IERC1155Receiver(this).onERC1155Received.selector;
    }

    /**
     * @dev See {IERC1155-onERC1155BatchReceived}.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return 0x00000000;
    }

    /* ERC165 methods */

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
