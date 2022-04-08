// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

contract NFTStake is
    Initializable,
    UUPSUpgradeable,
    IERC1155ReceiverUpgradeable,
    OwnableUpgradeable
{
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using SafeMathUpgradeable for uint256;

    mapping(bytes4 => bool) private _supportedInterfaces;
    mapping(address => mapping(uint256 => uint256)) public deposits;
    mapping(address => EnumerableSetUpgradeable.UintSet) private _ids;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public userAmount;
    mapping(uint256 => bool) public whiteListNFTs;
    uint256 public accPerShare;
    uint256 public lastRewardBalance;
    uint256 public lastRewardBlock;
    uint256 public totalReward;
    uint256 public lastTotalReward;
    uint256 public totalStaked;

    address public ERC20_CONTRACT;
    address public ERC1155_CONTRACT;

    function initialize(address _erc20Token, address _erc1155Token)
        public
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        require(address(_erc20Token) != address(0), "Invalid erc20Token address");
        require(
            address(_erc1155Token) != address(0),
            "Invalid erc1155Token address"
        );
        ERC20_CONTRACT = _erc20Token;
        ERC1155_CONTRACT = _erc1155Token;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function whiteListNFT(uint256[] memory _tokenId, bool _status)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _tokenId.length; i++) {
            require(whiteListNFTs[_tokenId[i]] != _status, "Already in same status");
            whiteListNFTs[_tokenId[i]] = _status;
        }
    }

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

        uint256 userReward = userAmount[msg.sender].mul(accPerShare).div(10000).sub(
            rewardDebt[msg.sender]
        );
        IERC20Upgradeable(ERC20_CONTRACT).transfer(msg.sender, userReward);
        lastRewardBalance = IERC20Upgradeable(ERC20_CONTRACT).balanceOf(
            address(this)
        );

        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(10000);
    }

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

    function deposit(uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        claimRewards();

        require(tokenIds.length == amounts.length, "Invalid Data");
        for (uint256 i; i < tokenIds.length; i++) {
            require(whiteListNFTs[tokenIds[i]] != false, "Invalid token NFT");
            IERC1155Upgradeable(ERC1155_CONTRACT).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i],
                amounts[i],
                ""
            );
            deposits[msg.sender][tokenIds[i]] = deposits[msg.sender][tokenIds[i]].add(amounts[i]);
            _ids[msg.sender].add(tokenIds[i]);
            totalStaked = totalStaked.add(amounts[i]);
            userAmount[msg.sender] = userAmount[msg.sender].add(amounts[i]);
        }
        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(10000);
    }

    function withdraw(uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        claimRewards();

        require(tokenIds.length == amounts.length, "Invalid Data");
        for (uint256 i; i < tokenIds.length; i++) {
            require(
                deposits[msg.sender][tokenIds[i]] >= amounts[i],
                "StakeSeals: Token not deposited"
            );
            require(amounts[i] > 0, "Invalid amounts Data");

            deposits[msg.sender][tokenIds[i]] = deposits[msg.sender][tokenIds[i]].sub(amounts[i]);
            if(deposits[msg.sender][tokenIds[i]] == 0) {
                _ids[msg.sender].remove(tokenIds[i]);
            }

            IERC1155Upgradeable(ERC1155_CONTRACT).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds[i],
                amounts[i],
                ""
            );
            userAmount[msg.sender] = userAmount[msg.sender].sub(amounts[i]);
            totalStaked = totalStaked.sub(amounts[i]);
        }
        rewardDebt[msg.sender] = userAmount[msg.sender].mul(accPerShare).div(10000);
    }

    function depositsOf(address account)
        external
        view
        returns (uint256[] memory)
    {
        EnumerableSetUpgradeable.UintSet storage depositSet = _ids[account];
        uint256[] memory tokenIds = new uint256[](depositSet.length());

        for (uint256 i; i < depositSet.length(); i++) {
            tokenIds[i] = depositSet.at(i);
        }

        return tokenIds;
    }

    function emergencyWithdrawRewardTokens(uint256 _amount) public onlyOwner {
        uint256 contractBalance = IERC20Upgradeable(ERC20_CONTRACT).balanceOf(
            address(this)
        );
        if (_amount > contractBalance) {
            IERC20Upgradeable(ERC20_CONTRACT).transfer(owner(), contractBalance);
        } else {
            IERC20Upgradeable(ERC20_CONTRACT).transfer(owner(), _amount);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _supportedInterfaces[interfaceId];
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}