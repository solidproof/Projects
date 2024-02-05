// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract NFTStaking is Ownable {
    using SafeERC20 for IERC20;

    // Const

    uint256 public constant DENOM = 10 ** 18;

    uint256 public constant MAX_REWARD_RATE = 3;

    uint256 public constant MONTH = 30 days;

    address public constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    // Storage

    IERC721Metadata public immutable token;

    IERC20 public immutable usdt;

    uint256 public immutable claimFee;

    address public devWallet;

    mapping(bytes32 => uint256) public typePrices;

    mapping(bytes32 => uint256) public typeRates;

    mapping(uint256 => address) public staker;

    mapping(uint256 => uint256) public stakedAt;

    mapping(uint256 => uint256) public claimed;

    mapping(address => uint256[]) public stakedBy;

    // Event

    event Staked(address account, uint256 tokenId);

    event Claimed(address account, uint256 tokenId, uint256 amount);

    // Constructor

    constructor(
        IERC721Metadata token_,
        IERC20 usdt_,
        uint256 claimFee_,
        address devWallet_,
        address owner_,
        string[] memory uris,
        uint256[] memory prices,
        uint256[] memory rates
    ) {
        token = token_;
        usdt = usdt_;
        claimFee = claimFee_;
        devWallet = devWallet_;
        _transferOwnership(owner_);

        require(
            uris.length == prices.length && uris.length == rates.length,
            "Length mismatch"
        );

        for (uint256 i = 0; i < uris.length; i++) {
            bytes32 typeId = keccak256(abi.encodePacked(uris[i]));
            typePrices[typeId] = prices[i];
            typeRates[typeId] = rates[i] / MONTH;
        }
    }

    // Public mutative

    function stake(uint256 tokenId) external {
        require(typePrices[typeOf(tokenId)] > 0, "Can't stake this token");

        token.transferFrom(msg.sender, address(this), tokenId);

        staker[tokenId] = msg.sender;
        stakedAt[tokenId] = block.timestamp;
        stakedBy[msg.sender].push(tokenId);

        emit Staked(msg.sender, tokenId);
    }

    function claim(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _claim(tokenIds[i]);
        }
    }

    function burn(uint256 tokenId) external {
        _claim(tokenId);

        delete staker[tokenId];
        delete stakedAt[tokenId];
        uint256 sl = stakedBy[msg.sender].length;
        for (uint256 i = 0; i < sl; i++) {
            if (stakedBy[msg.sender][i] == tokenId) {
                stakedBy[msg.sender][i] = stakedBy[msg.sender][sl - 1];
                stakedBy[msg.sender].pop();
                break;
            }
        }

        token.transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    // Public mutative admin

    function setDevWallet(address devWallet_) external onlyOwner {
        require(devWallet_ != address(0), "Zero address");
        devWallet = devWallet_;
    }

    // Public view

    function getStakedBy(
        address account
    ) external view returns (uint256[] memory) {
        return stakedBy[account];
    }

    function getStakedState(
        uint256[] calldata tokenIds
    ) external view returns (bool[] memory states) {
        states = new bool[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            states[i] = (staker[tokenIds[i]] != address(0));
        }
    }

    function typeOf(uint256 tokenId) public view returns (bytes32) {
        return keccak256(abi.encodePacked(token.tokenURI(tokenId)));
    }

    function typeOfMany(
        uint256[] calldata tokenIds
    ) external view returns (bytes32[] memory types) {
        types = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            types[i] = typeOf(tokenIds[i]);
        }
    }

    function totalRewardOf(uint256 tokenId) public view returns (uint256) {
        if (stakedAt[tokenId] == 0) {
            return 0;
        }
        bytes32 typeId = typeOf(tokenId);
        uint256 accruedReward = (typePrices[typeId] *
            typeRates[typeId] *
            (block.timestamp - stakedAt[tokenId])) / DENOM;
        uint256 maxReward = typePrices[typeId] * MAX_REWARD_RATE;
        return Math.min(accruedReward, maxReward);
    }

    function claimableRewardOf(uint256 tokenId) public view returns (uint256) {
        return totalRewardOf(tokenId) - claimed[tokenId];
    }

    function remainingRewardShareOf(
        uint256 tokenId
    ) public view returns (uint256) {
        bytes32 typeId = typeOf(tokenId);
        uint256 maxReward = typePrices[typeId] * MAX_REWARD_RATE;
        uint256 remainingReward = maxReward - claimed[tokenId];
        return (remainingReward * DENOM) / maxReward;
    }

    function claimableRewardOfMany(
        uint256[] calldata tokenIds
    ) external view returns (uint256[] memory rewards) {
        rewards = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            rewards[i] = claimableRewardOf(tokenIds[i]);
        }
    }

    function sumOfClaimableRewardOfMany(
        uint256[] calldata tokenIds
    ) external view returns (uint256 sum) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            sum += claimableRewardOf(tokenIds[i]);
        }
    }

    function remainingRewardShareOfMany(
        uint256[] calldata tokenIds
    ) external view returns (uint256[] memory rewards) {
        rewards = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            rewards[i] = remainingRewardShareOf(tokenIds[i]);
        }
    }

    // Private

    function _claim(uint256 tokenId) private {
        require(msg.sender == staker[tokenId], "Sender is not token staker");

        uint256 amount = claimableRewardOf(tokenId);
        require(amount > 0, "Can't claim zero");

        claimed[tokenId] += amount;

        uint256 fee = (amount * claimFee) / DENOM;
        if (fee > 0) {
            usdt.safeTransfer(devWallet, fee);
        }
        usdt.safeTransfer(msg.sender, amount - fee);

        emit Claimed(msg.sender, tokenId, amount);
    }
}