// SPDX-License-Identifier: MIT LICENSE

pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC {
    // from IERC20
    function transfer(address recipient, uint256 amount) external;

    // from IERC721
    function ownerOf(uint256 tokenId) external returns (address);

    function totalSupply() external returns (uint256);
}

contract CultPool is Ownable {
    using SafeMath for uint256;

    uint256 internal nftSupply = 666;
    uint256 public coinReward = 100 ether; //equivalent to 1 coin reward per day (divided by denomValue)
    uint256 internal denomValue = 86400; //total seconds per day

    // reference to the NFT & token contract
    address public nftContract;
    address public tokenContract;

    // maps tokenId to claimVault with claimReceipt struct
    mapping(uint256 => ClaimReceipt) public claimVault;

    uint256 public deployedBlock;

    // struct to store a claimed's token, last claim timestamp, owner, and earning values
    struct ClaimReceipt {
        uint24 tokenId;
        uint256 timestamp;
        address owner;
        uint256 amount;
    }

    // event emitted whenever a token is claimed
    event Claimed(
        address owner,
        uint256 tokenId,
        uint256 timestamp,
        uint256 amount
    );

    constructor(address _nftContract, address _tokenContract) {
        nftContract = _nftContract;
        tokenContract = _tokenContract;
        setDeployedBlock(uint256(block.timestamp));
    }

    function setDeployedBlock(uint256 _deployedBlock) internal {
        deployedBlock = _deployedBlock;
    }

    function claim(uint256[] calldata tokenIds) external {
        _claim(msg.sender, tokenIds);
    }

    function _claim(address account, uint256[] calldata tokenIds) internal {
        uint256 tokenId;
        uint256 earned = 0;
        uint256 rewardmath = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            // check if tokenId has been claimed before
            // if no, get difference by comparing current timestamp with deployedBlock timestamp
            if (claimVault[tokenId].tokenId == 0) {
                require(
                    IERC(nftContract).ownerOf(tokenId) == msg.sender,
                    "not your NFT"
                );
                rewardmath =
                    (coinReward * (block.timestamp - deployedBlock)) /
                    denomValue;

                earned += rewardmath / 100;

                // maps tokenId to claimVault with claimReceipt struct
                claimVault[tokenId] = ClaimReceipt({
                    owner: account,
                    tokenId: uint24(tokenId),
                    timestamp: uint256(block.timestamp),
                    amount: rewardmath / 100
                });

                emit Claimed(
                    msg.sender,
                    uint24(tokenId),
                    uint256(block.timestamp),
                    rewardmath / 100
                );
            }
            // if yes, get difference by comparing current timestamp with last claimed timestamp
            else {
                ClaimReceipt memory claimed = claimVault[tokenId];
                require(
                    IERC(nftContract).ownerOf(tokenId) == msg.sender,
                    "not your NFT"
                );
                uint256 claimedAt = claimed.timestamp;

                rewardmath =
                    (coinReward * (block.timestamp - claimedAt)) /
                    denomValue;

                earned += rewardmath / 100;

                // maps tokenId to claimVault with claimReceipt struct
                claimVault[tokenId] = ClaimReceipt({
                    owner: account,
                    tokenId: uint24(tokenId),
                    timestamp: uint256(block.timestamp),
                    amount: rewardmath / 100
                });

                emit Claimed(
                    msg.sender,
                    uint24(tokenId),
                    uint256(block.timestamp),
                    rewardmath / 100
                );
            }
        }
        if (earned > 0) {
            // transfer $CULT to tokenId's owner
            IERC(tokenContract).transfer(account, earned);
        }
    }

    // to return claimable $CULT
    function claimableInfo(uint256[] calldata tokenIds)
        external
        view
        returns (uint256 earnedTotal)
    {
        uint256 tokenId;
        uint256 earned = 0;
        uint256 rewardmath = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];

            // check if tokenId is within nftSupply

            if (tokenId < nftSupply) {
                // check if tokenId has been claimed before
                // if no, get difference by comparing current timestamp with deployedBlock timestamp
                if (claimVault[tokenId].tokenId == 0) {
                    rewardmath =
                        (coinReward * (block.timestamp - deployedBlock)) /
                        denomValue;

                    earned += rewardmath / 100;
                }
                // if yes, get difference by comparing current timestamp with last claimed timestamp
                else {
                    ClaimReceipt memory claimed = claimVault[tokenId];

                    uint256 claimedAt = claimed.timestamp;

                    rewardmath =
                        (coinReward * (block.timestamp - claimedAt)) /
                        denomValue;

                    earned += rewardmath / 100;
                }
            }
        }
        if (earned > 0) {
            return earned;
        }
    }

    // onlyOwner functions

    function setNftContract(address _nftContract) external onlyOwner {
        nftContract = _nftContract;
    }

    function setNftSupply(uint256 _nftSupply) external onlyOwner {
        nftSupply = _nftSupply;
    }

    function setCoinReward(uint256 _coinReward) external onlyOwner {
        require(
            _coinReward > 0 && _coinReward < 100001,
            "Please set the reward to the range of 1-10,000"
        );
        coinReward = _coinReward;
    }
}
