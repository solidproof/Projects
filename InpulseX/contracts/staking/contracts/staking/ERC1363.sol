// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../Base.sol";
import "../rewards/ERC20.sol";
import "../rewards/ERC1155.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1363.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";

abstract contract ERC1363Staking is BaseStaking, IERC165, IERC1363Receiver {
    IERC1363 private _stakeToken;

    /**
     * @dev Set the token used for staking
     * @param token Address of the token contract
     *
     * Reverts if the token is set to address(0)
     */
    function setStakingToken(address token) external onlyOwner {
        require(token != address(0), "Can't set token to address(0)");
        require(
            address(_stakeToken) == address(0),
            "Staking token is already set"
        );
        _stakeToken = IERC1363(token);
        emit StakingTokenChanged(token);
    }

    /**
     * @dev Get the address of the token used for staking
     * @return address Address of the token contract
     */
    function getStakingToken() external view returns (address) {
        return address(_stakeToken);
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
                require(
                    _stakeToken.transfer(_penaltyAddress, penalty),
                    "Transfer failed!"
                );
            }

            require(
                _stakeToken.transfer(user, amount - penalty),
                "Transfer failed!"
            );
        } else {
            emit UnStaked(user, amount);
            uint256 reward = getRewardSize(user);
            _stakeWeight[user] = 0;
            require(_stakeToken.transfer(user, amount), "Transfer failed!");
            sendRewards(user, reward);
        }
    }

    /**
     * @dev Handle incoming transfers of staking tokens
     * @param user Address of the user staking tokens
     * @param amount Amount of tokens being staked
     * @return bytes4 Signature of the method in the receiver contract
     *
     * Reverts if `amount` is not bigger than 0
     * Reverts if staking window is smaller than the block timestamp
     * Reverts if the message sender is not the staking token
     */
    function onTransferReceived(
        address,
        address user,
        uint256 amount,
        bytes memory
    ) external returns (bytes4) {
        require(block.timestamp <= _unlockTime, "Cannot stake anymore");
        require(_unlockTime > 0, "Cannot stake yet");
        require(amount > 0, "Cannot stake 0 tokens");
        require(
            _msgSender() == address(_stakeToken),
            "Message sender is not the stake token"
        );

        recordStakeWeight(user, amount);
        _stake[user] += amount;

        emit Staked(user, amount);
        return IERC1363Receiver(this).onTransferReceived.selector;
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
        return interfaceId == type(IERC1363Receiver).interfaceId;
    }
}

contract ERC1363StakerERC20Rewarder is ERC1363Staking, ERC20Rewards {}

contract ERC1363StakerERC1155Rewarder is ERC1363Staking, ERC1155Rewards {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(ERC1363Staking, ERC1155Rewards)
        returns (bool)
    {
        return
            ERC1363Staking.supportsInterface(interfaceId) ||
            ERC1155Rewards.supportsInterface(interfaceId);
    }
}
