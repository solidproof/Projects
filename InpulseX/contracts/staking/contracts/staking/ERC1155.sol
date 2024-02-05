// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../Base.sol";
import "../rewards/ERC20.sol";
import "../rewards/ERC1155.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";

abstract contract ERC1155Staking is BaseStaking, IERC165, IERC1155Receiver {
    IERC1155 private _stakeToken;
    uint256 private _stakeNftId;

    event StakingNftTokenChanged(address token, uint256 nftId);

    /**
     * @dev Set the token used for staking
     * @param token Address of the token contract
     * @param nftId Id of the NFT to accept for stake
     *
     * Reverts if the token is set to address(0)
     */
    function setStakingToken(address token, uint256 nftId) external onlyOwner {
        require(token != address(0), "Can't set token to address(0)");
        require(
            address(_stakeToken) == address(0),
            "Staking token is already set"
        );
        _stakeToken = IERC1155(token);
        _stakeNftId = nftId;
        emit StakingNftTokenChanged(token, nftId);
    }

    /**
     * @dev Get the address of the token used for staking
     * @return (address, uint256) Address of the token contract and the NFT ID
     */
    function getStakingToken() external view returns (address, uint256) {
        return (address(_stakeToken), _stakeNftId);
    }

    /**
     * @dev Transfers `amount` tokens from the user to this contract
     * @param amount Amount of tokens being staked
     *
     * Reverts if `amount` is not greater than 0
     * Reverts if staking window is smaller than the block timestamp
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 tokens");
        require(_unlockTime > 0, "Cannot stake yet");
        require(block.timestamp <= _unlockTime, "Cannot stake anymore");

        address user = _msgSender();
        recordStakeWeight(user, amount);
        _stake[user] += amount;

        emit Staked(user, amount);
        _stakeToken.safeTransferFrom(
            user,
            address(this),
            _stakeNftId,
            amount,
            ""
        );
    }

    /**
     * @dev Unstake tokens
     *
     * Reverts if user stake amount is not greater than 0
     * Reverts if block timestamp is not bigger than the unlock time
     * or the user is not allowed to unstake early
     *
     * A penalty may be applied if the user removes their stake early
     */
    function unstake() external {
        address user = _msgSender();
        require(_stake[user] > 0, "Cannot unstake 0 tokens");
        require(canUnstake(user), "Cannot unstake yet");

        uint256 amount = _stake[user];
        _stake[user] = 0;

        if (block.timestamp < _unlockTime) {
            uint256 penalty = (amount * _penalties[user]) / 100;
            emit UnStaked(user, amount - penalty);
            /**
             * No reward distributed, decrease the stake pool size
             */
            _stakePoolWeight -= _stakeWeight[user];
            _stakeWeight[user] = 0;

            if (penalty > 0) {
                _stakeToken.safeTransferFrom(
                    address(this),
                    _penaltyAddress,
                    _stakeNftId,
                    penalty,
                    ""
                );
            }
            _stakeToken.safeTransferFrom(
                address(this),
                user,
                _stakeNftId,
                amount - penalty,
                ""
            );
        } else {
            emit UnStaked(user, amount);
            _stakeToken.safeTransferFrom(
                address(this),
                user,
                _stakeNftId,
                amount,
                ""
            );
            uint256 reward = getRewardSize(user);
            _stakeWeight[user] = 0;
            sendRewards(user, reward);
        }
    }

    /* ERC1155 methods */

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

    /* ERC1155 methods */

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

contract ERC1155StakerERC20Rewarder is ERC1155Staking, ERC20Rewards {}

contract ERC1155StakerERC1155Rewarder is
    ERC1155Staking,
    ERC1155RewardsNonReceiver
{}
