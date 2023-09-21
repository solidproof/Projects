// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IResource.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/INFTDescriptor.sol";

contract NFTManager is
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard
{
    using Address for address;
    struct NFTEntity {
        uint256 id;
        uint256 amount;
        uint256 lastProcessingTimestamp;
        uint256 lastReward;
    }

    struct UserInfo {
        uint256 lastProcessingTimestamp;
        uint256 amount;
    }

    mapping(address => uint256) public userTotalStakedAmount;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => uint256[]) public nftsOfUser;
    mapping(uint256 => address[]) public usersOfNft;

    mapping(address => mapping(address => uint256)) public stakeReferralAmount;
    mapping(address => mapping(address => uint256)) public nftReferralAmount;
    mapping(address => address[]) public nftReferralsOfUser;
    mapping(address => address[]) public stakeReferralsOfUser;
    uint256 public totalStakeReferralAmount;
    uint256 public totalNftReferralAmount;

    mapping(uint256 => NFTEntity) private _nfts;

    mapping(address => bool) private whitelist;

    uint256 public constant initialLockValue = 2000 * 1e18;
    uint256 public constant maxSupply = 333;

    uint256 public constant processingFee = 10;

    uint256 public totalValueLocked;

    uint256 public mintPrice;
    uint256 public mintPriceWhitelisted;

    IResource public resource;
    ITreasury public treasury;

    address private immutable _descriptor;

    uint256 public startTime = type(uint256).max;

    modifier treasurySet() {
        require(address(treasury) != address(0), "NFTManager: Treasury is 0");
        _;
    }

    modifier whenStarted() {
        require(startTime < block.timestamp, "NFTManager: Not started");
        _;
    }

    receive() external payable {}

    constructor(address _descriptor_, address _resource) ERC721("Unicow", "Unicow") {
        _descriptor = _descriptor_;
        resource = IResource(_resource);
        
        changeMintPrice(1 * 1e17);
        changeMintPriceWhitelisted(67 * 1e15);

        for (uint256 index = 1; index <= 33; index++) {
            _nfts[index] = NFTEntity({
                id: index,
                amount: 0,
                lastProcessingTimestamp: block.timestamp,
                lastReward: 0
            });
            _mint(owner(), index);
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
        NFTEntity storage nft = _nfts[tokenId];
        address[] memory users = usersOfNft[tokenId];
        (uint8 level, , ) = getNftLevelAndRewardRates(nft.amount);
        return INFTDescriptor(_descriptor).tokenURI(
            INFTDescriptor.ConstructTokenURIParams({
                tokenId: tokenId,
                level: level,
                tvl: nft.amount,
                lockers: users.length,
                ownerAddress: ownerOf(tokenId)
            })
        );
    }

    function createNFT(uint256 nftNumber, address _referrer) external payable nonReentrant whenStarted treasurySet {
        address sender = _msgSender();

        require(nftNumber > 0 && nftNumber < 101, "NFTManager: NFT Number should set between 1-100");
        require(mintPrice * nftNumber == msg.value, "NFTManager: msg.value == mint_price * number");

        for (uint256 index = 0; index < nftNumber; index++) {
            uint256 newNFTId = totalSupply() + 1;

            require(maxSupply >= newNFTId, "NFTManager: total supply can never exceed max supply");

            _nfts[newNFTId] = NFTEntity({
                id: newNFTId,
                amount: initialLockValue,
                lastProcessingTimestamp: block.timestamp,
                lastReward: 0
            });

            _mint(sender, newNFTId);
            totalValueLocked += initialLockValue;
        }

        address referrer = _referrer;
        if (_referrer == sender || _referrer.isContract()) {
            referrer = treasury.feeAddress();
        } else {
            uint256 nftAmount = nftReferralAmount[referrer][sender];
            if (nftAmount == 0) {
                address[] storage _referralUsers = nftReferralsOfUser[referrer];
                _referralUsers.push(sender);
            }
            nftReferralAmount[referrer][sender] = nftAmount + msg.value;
            totalNftReferralAmount += msg.value;
        }

        uint balance = address(this).balance;
        uint referralAmount = balance / 10;
        payable(treasury.feeAddress()).transfer(balance - referralAmount);
        payable(referrer).transfer(referralAmount);
    }

    function createNFTWhitelisted() external payable nonReentrant treasurySet {
        address sender = _msgSender();

        require(whitelist[sender], "NFTManager: not whitelisted");
        require(mintPriceWhitelisted == msg.value, "NFTManager: msg.value == mint_price");

        uint256 newNFTId = totalSupply() + 1;

        require(maxSupply >= newNFTId, "NFTManager: total supply can never exceed max supply");

        _nfts[newNFTId] = NFTEntity({
            id: newNFTId,
            amount: initialLockValue,
            lastProcessingTimestamp: block.timestamp,
            lastReward: 0
        });

        _mint(sender, newNFTId);
        totalValueLocked += initialLockValue;

        payable(treasury.feeAddress()).transfer(msg.value);

        whitelist[sender] = false;
    }

    function stakeTokens(uint256 _nftId, uint256 _amount, address _referrer) external nonReentrant whenStarted treasurySet {
        address sender = _msgSender();
        require(resource.balanceOf(sender) >= _amount, "NFTManager: Balance too low to stake");

        NFTEntity storage nft = _nfts[_nftId];

        UserInfo storage user = userInfo[_nftId][sender];

        if (user.amount > 0) {
            uint256 reward = _getNFTRewards(_nftId, sender, false);
            uint256 fee = (reward * processingFee) / 100;
            
            require(reward > 0, "NFTManager: no reward to compound");
            treasury.rewardByNFTOrChef(address(treasury), fee);
            totalValueLocked += reward;
        }

        if (_amount > 0) {
            if (user.amount == 0) {
                uint256[] storage _nftsOfUser = nftsOfUser[sender];
                _nftsOfUser.push(_nftId);
                address[] storage _usersOfNft = usersOfNft[_nftId];
                _usersOfNft.push(sender);
            }
            treasury.burnByNFTOrChef(sender, _amount);
            totalValueLocked += _amount;
            uint256 delayedTimestamp = block.timestamp - nft.lastProcessingTimestamp;
            ( , uint256 ownerRewardRate, ) = getNftLevelAndRewardRates(nft.amount);
            nft.lastReward += calculateRewardsFromValue(nft.amount, delayedTimestamp, ownerRewardRate);
            nft.amount += _amount;
            nft.lastProcessingTimestamp = block.timestamp;
            user.lastProcessingTimestamp = block.timestamp;
            user.amount += _amount;
            userTotalStakedAmount[sender] += _amount;

            address referrer = _referrer;
            if (_referrer == sender) {
                referrer = address(treasury);
            } else {
                uint256 stakedAmount = stakeReferralAmount[referrer][sender];
                if (stakedAmount == 0) {
                    address[] storage _referralUsers = stakeReferralsOfUser[referrer];
                    _referralUsers.push(sender);
                }
                stakeReferralAmount[referrer][sender] = stakedAmount + _amount;
                totalStakeReferralAmount += _amount;
            }
            treasury.rewardByNFTOrChef(referrer, _amount / 10);
        }
        treasury.addLiquidity();
    }

    function cashoutReward(uint256 _nftId, bool _swapping) external nonReentrant whenStarted treasurySet {
        address account = _msgSender();
        uint256 reward = _getNFTRewards(_nftId, account, true);
        _cashoutReward(reward, _swapping);
    }

    function cashoutAll(bool _swapping) external nonReentrant whenStarted treasurySet {
        address account = _msgSender();
        uint256 rewardsTotal = 0;

        uint256[] memory nfts = nftsOfUser[account];
        for (uint256 i = 0; i < nfts.length; i++) {
            rewardsTotal += _getNFTRewards(nfts[i], account, true);
        }
        uint256[] memory nftsOwned = getOwnedNFTIdsOf(account);
        for (uint256 i = 0; i < nftsOwned.length; i++) {
            rewardsTotal += _getNFTRewards(nftsOwned[i], account, true);
        }
        _cashoutReward(rewardsTotal, _swapping);
    }

    function _cashoutReward(uint256 amount, bool swapping) private {
        require(amount > 0, "NFTManager: no reward to claim");
        address to = _msgSender();
        uint256 feeAmount = (amount * processingFee) / 100;
        if (swapping) {
            treasury.swapTokenForETH(to, amount);
        } else {
            treasury.rewardByNFTOrChef(to, amount);
        }
        treasury.rewardByNFTOrChef(address(treasury), feeAmount);
        treasury.addLiquidity();
    }

    function compoundAll() external nonReentrant whenStarted treasurySet {
        address account = _msgSender();
        uint256 fees = 0;
        uint256 rewards = 0;
        uint256[] memory nfts = nftsOfUser[account];

        for (uint256 i = 0; i < nfts.length; i++) {
            uint256 reward = _getNFTRewards(nfts[i], account, false);
            uint256 fee = (reward * processingFee) / 100;
            if (reward > 0) {
                fees += fee;
                rewards += reward;
            }
        }

        require(rewards > 0, "NFTManager: no reward to compound");
        treasury.rewardByNFTOrChef(address(treasury), fees);
        totalValueLocked += rewards;
        treasury.addLiquidity();
    }

    function _getNFTRewards(uint256 _nftId, address _account, bool _cashout) private returns (uint256) {
        UserInfo storage user = userInfo[_nftId][_account];
        NFTEntity storage nft = _nfts[_nftId];

        uint256 userDelayedTimestamp = block.timestamp - user.lastProcessingTimestamp;
        uint256 nftDelayedTimestamp = block.timestamp - nft.lastProcessingTimestamp;

        uint256 userRewardRate = getUserRewardRate(user.amount);
        ( , uint256 ownerRewardRate, uint256 extraRewardRate) = getNftLevelAndRewardRates(nft.amount);

        uint256 reward = calculateRewardsFromValue(user.amount, userDelayedTimestamp, userRewardRate + extraRewardRate);
        uint256 ownerReward = calculateRewardsFromValue(nft.amount, nftDelayedTimestamp, ownerRewardRate);

        if (_cashout) {
            if (isOwnerOfNFT(_account, _nftId)) {
                reward += nft.lastReward + ownerReward;
                nft.lastReward = 0;
                nft.lastProcessingTimestamp = block.timestamp;
            }
        } else {
            user.amount += reward;
            userTotalStakedAmount[_account] += reward;
            nft.lastReward += ownerReward;
            nft.lastProcessingTimestamp = block.timestamp;
            nft.amount += reward;
        }

        user.lastProcessingTimestamp = block.timestamp;
        return reward;
    }

    function calculateRewardsFromValue(
        uint256 _amount,
        uint256 _duration,
        uint256 _rewardRate
    ) public pure returns (uint256) {
        return (_amount * _duration * _rewardRate) / 100000000000;
    }

    function getNftReferralsOfUser(address _account) external view returns (address[] memory) {
        return nftReferralsOfUser[_account];
    }

    function getStakeReferralsOfUser(address _account) external view returns (address[] memory) {
        return stakeReferralsOfUser[_account];
    }

    function isOwnerOfNFT(address account, uint256 _nftId) public view returns (bool) {
        return ownerOf(_nftId) == account;
    }

    function getUserRewardRate(uint256 _amount) public pure returns (uint256) {
        if (_amount >= 20000 * (10**18)) {
            return 28935; // 2.5%
        } else if (_amount >= 5000 * (10**18)) {
            return 25463; // 2.2%
        } else if (_amount >= 1000 * (10**18)) {
            return 24305; // 2.1%
        } else {
            return 23148; // 2.0%
        }
    }

    function getNftLevelAndRewardRates(uint256 _amount) public pure returns (uint8, uint256, uint256) {
        if (_amount >= 100000 * (10**18)) {
            return (3, 4051, 5787); // (0.35%, 0.5%)
        } else if (_amount >= 50000 * (10**18)) {
            return (2, 3588, 2315); // (0.31%, 0.2%)
        } else if (_amount >= 5000 * (10**18)) {
            return (1, 3241, 1157); // (0.28%, 0.1%)
        } else {
            return (0, 2894, 0); // (0.25%, 0%)
        }
    }

    function getOwnedNFTIdsOf(address account) public view returns (uint256[] memory) {
        uint256 numberOfNFTs = balanceOf(account);
        uint256[] memory nftIds = new uint256[](numberOfNFTs);
        for (uint256 i = 0; i < numberOfNFTs; i++) {
            uint256 nftId = tokenOfOwnerByIndex(account, i);
            nftIds[i] = nftId;
        }
        return nftIds;
    }

    function getAvailableNFTIdsOf(address account) external view returns (uint256[] memory) {
        uint256[] memory nftIds = nftsOfUser[account];
        return nftIds;
    }

    function getUsersOf(uint256[] memory _nftIds) external view returns (address[][] memory) {
        address[][] memory users_list = new address[][](_nftIds.length);
        for (uint256 i = 0; i < _nftIds.length; i++) {
            uint256 nftId = _nftIds[i];
            address[] memory users = usersOfNft[nftId];
            users_list[i] = users;
        }
        return users_list;
    }

    function getNFTsByIds(uint256[] memory _nftIds) external view returns (NFTEntity[] memory) {
        NFTEntity[] memory nftsInfo = new NFTEntity[](_nftIds.length);

        for (uint256 i = 0; i < _nftIds.length; i++) {
            uint256 nftId = _nftIds[i];
            NFTEntity memory nft = _nfts[nftId];
            nftsInfo[i] = nft;
        }
        return nftsInfo;
    }

    function setStartTime(uint256 _startTime) external onlyOwner {
        require(block.timestamp < startTime && block.timestamp < _startTime, "!_startTime!");
        startTime = _startTime;
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "NFTManager: !_treasury");
        require(address(treasury) == address(0), "NFTManager: treasury");
        treasury = ITreasury(_treasury);
    }

    function changeMintPrice(uint256 _mintPrice) public onlyOwner {
        require(_mintPrice > 0 && _mintPrice <= 2 * 1e17, "NFTManager: !mintPrice!");
        mintPrice = _mintPrice;
    }

    function changeMintPriceWhitelisted(uint256 _mintPrice) public onlyOwner {
        require(_mintPrice > 0 && _mintPrice <= 2 * 1e17, "NFTManager: !mintPrice");
        mintPriceWhitelisted = _mintPrice;
    }

    function setWhitelisted(address[] memory accounts, bool status) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "NFTManager: an account is 0");
            whitelist[accounts[i]] = status;
        }
    }

    function recoverLostETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverLostTokens(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(address(resource) != _token, "NFTManager: !resource");
        IERC20(_token).transfer(_to, _amount);
    }
}