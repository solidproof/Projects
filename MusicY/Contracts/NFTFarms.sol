// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./library/SafeMathExt.sol";
import "./HashRate.sol";

contract NFTFarms is
    HashRateUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721HolderUpgradeable,
    ERC1155HolderUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserRewardInfo {
        uint128 userHashrateFixed;
        uint128 userHashratePercent;
        uint128 userRewardPerTokenPaid;
        uint128 userReward;
    }

    struct NftInfo {
        address owner;
        uint256 hashrate;
    }

    struct StakedNFT {
        address tokenContract;
        uint256 tokenId;
    }

    struct UserHashRateParams {
        address owner;
        NftNewHashRate[] nftsHashRates;
    }

    struct NftNewHashRate {
        address tokenContract;
        uint256 tokenId;
        uint256 hashRate;
    }

    uint256 public rewardStartHeight;
    uint256 public periodFinishHeight;

    uint256 public lastUpdateHeight;
    uint256 public rewardPerTokenStored;

    uint256 public initRewardPerBlock;
    uint256 public firstRewardPeriod;
    uint256 public oneYearBlockNum;

    uint256 public rewardPerBlock;
    uint256 public maxHalvingYears;

    uint256 public totalHashRate;
    uint256 public singleNFTMaxHashRate;

    bytes4 public ERC721InterfaceId;
    bytes4 public ERC1155InterfaceId;

    mapping(address => UserRewardInfo) public userRewardInfoMap;
    mapping(address => mapping(uint256 => NftInfo)) public stakedNFTInfoMap; // token contract => (tokenId => owner)
    mapping(address => StakedNFT[]) public userNFTs;
    mapping(address => bool) public isManagers;
    mapping(address => bool) public nftWhiteMap;

    IERC20Upgradeable public vMYT;
    IERC20Upgradeable public rewardToken;

    event stake1155NFT(
        address indexed _user,
        address indexed _tokenContract,
        uint256 _tokenId,
        uint256 _amount
    );
    event stake721NFT(
        address indexed _user,
        address indexed _tokenContract,
        uint256 _tokenId
    );
    event withdraw1155NFT(
        address indexed _user,
        address indexed _tokenContract,
        uint256 _tokenId,
        uint256 _amount
    );
    event withdraw721NFT(
        address indexed _user,
        address indexed _tokenContract,
        uint256 _tokenId
    );
    event rewardUser(address indexed _user, uint256 _amount);

    event updateHashRate(
        address indexed _user,
        address indexed _tokenContract,
        uint256 _tokenId,
        uint256 _hashRate
    );
    event SetManager(address indexed _manager, bool flag);
    event SetNftWhite(address indexed _manager, bool flag);

    modifier checkSlot(address _user) {
        (, uint128 slotNum) = getWeightByVMYT(_user);
        require(
            slotNum > 0 && slotNum <= 5,
            "NFTFarms#checkSlot: the slotNum <=0 or the slotNum > 5"
        );
        require(
            userNFTs[_user].length < slotNum,
            "NFTFarms#checkSlot: the slots is full"
        );
        _;
    }

    modifier onlyEOA() {
        require(
            msg.sender == tx.origin,
            "NFTFarms#onlyEOA: only the EOA address"
        );
        _;
    }

    modifier onlyManagers() {
        require(
            isManagers[msg.sender],
            "NFTFarms#onlyManagers: only the managers address"
        );
        _;
    }

    function initialize(
        address _myt,
        address _vmyt,
        address _hrSigner,
        uint256 _startHeight,
        uint256 _rewardPerBlock,
        uint256 _initRewardPerBlock,
        uint256 _firstRewardPeriod,
        uint256 _maxHalvingYears,
        uint256 _oneYearBlockNum,
        uint256 _singleNFTMaxHashRate
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __HashRate_init(_hrSigner);

        rewardStartHeight = _startHeight;
        rewardPerBlock = _rewardPerBlock;

        singleNFTMaxHashRate = _singleNFTMaxHashRate;
        initRewardPerBlock = _initRewardPerBlock;
        firstRewardPeriod = _firstRewardPeriod;

        maxHalvingYears = _maxHalvingYears;
        oneYearBlockNum = _oneYearBlockNum;
        periodFinishHeight = ~uint256(0);

        ERC721InterfaceId = type(IERC721Upgradeable).interfaceId;
        ERC1155InterfaceId = type(IERC1155Upgradeable).interfaceId;
        vMYT = IERC20Upgradeable(_vmyt);
        rewardToken = IERC20Upgradeable(_myt);
        isManagers[msg.sender] = true;
    }

    /****************************   external onlyOwner function        *******************************/
    function setHashRateSigner(address _hrSigner) external onlyOwner {
        hrSigner = _hrSigner;
    }

    function setRewardConfig(
        uint256 _firstRewardPeriod,
        uint256 _maxHalvingYears,
        uint256 _oneYearBlockNum,
        uint256 _periodFinishHeight
    ) external onlyOwner {
        _updateReward(address(0));
        maxHalvingYears = _maxHalvingYears;
        firstRewardPeriod = _firstRewardPeriod;
        oneYearBlockNum = _oneYearBlockNum;
        periodFinishHeight = _periodFinishHeight;
    }

    function setRewardStartHeight(uint256 _rewardStartHeight)
        external
        onlyOwner
    {
        require(
            rewardStartHeight > block.number,
            "NFTFarms#setRewardStartHeight: Reward has been started"
        );
        require(
            _rewardStartHeight > block.number,
            "NFTFarms#setRewardStartHeight: new reward should be after now"
        );
        rewardStartHeight = _rewardStartHeight;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        _updateReward(address(0));
        rewardPerBlock = _rewardPerBlock;
    }

    function setSingleNFTMaxHashRate(uint256 _singleNFTMaxHashRate)
        external
        onlyOwner
    {
        singleNFTMaxHashRate = _singleNFTMaxHashRate;
    }

    function setGovToken(address _vMYT) external onlyOwner {
        vMYT = IERC20Upgradeable(_vMYT);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20Upgradeable(_rewardToken);
    }

    function setManagers(address[] memory _managers, bool flag)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _managers.length; i++) {
            require(_managers[i] != address(0), "_manager is zero address");
            isManagers[_managers[i]] = flag;
            emit SetManager(_managers[i], flag);
        }
    }

    function setNFTWhiteMap(address[] memory _nfts, bool flag)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _nfts.length; i++) {
            require(_nfts[i] != address(0), "nft is zero address");
            nftWhiteMap[_nfts[i]] = flag;
            emit SetNftWhite(_nfts[i], flag);
        }
    }

    function transferToken(
        IERC20Upgradeable tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        tokenAddress.safeTransfer(to, amount);
    }

    /****************************   external manager operate function        *******************************/
    function updateAllHashRate(UserHashRateParams[] calldata _userNewHashRates)
        external
        onlyEOA
        onlyManagers
    {
        require(
            _userNewHashRates.length > 0,
            "NFTFarms#updateAllHashRate: params should not be null"
        );
        for (uint256 i = 0; i < _userNewHashRates.length; i++) {
            require(
                _userNewHashRates[i].owner != address(0),
                "NFTFarms#updateAllHashRate: nft has not staked "
            );
            _updateReward(_userNewHashRates[i].owner);
            NftNewHashRate[] calldata nftsHashRates = _userNewHashRates[i]
                .nftsHashRates;
            for (uint256 j = 0; j < nftsHashRates.length; j++) {
                NftInfo storage nftInfo = stakedNFTInfoMap[
                    nftsHashRates[j].tokenContract
                ][nftsHashRates[j].tokenId];
                require(
                    nftInfo.owner == _userNewHashRates[i].owner,
                    "NFTFarms#updateAllHashRate: nft owner not equal params"
                );
                uint256 subHashRate = nftInfo.hashrate -
                    nftsHashRates[j].hashRate;
                nftInfo.hashrate = nftsHashRates[j].hashRate;
                _calcHashRate(nftInfo.owner, 0, subHashRate);

                emit updateHashRate(
                    nftInfo.owner,
                    nftsHashRates[j].tokenContract,
                    nftsHashRates[j].tokenId,
                    nftsHashRates[j].hashRate
                );
            }
        }
    }

    /****************************   external user operate function        *******************************/

    function stake(
        address _contract,
        uint256 _tokenId,
        uint256 _vNonceValue,
        bytes32 _r,
        bytes32 _s
    ) external checkSlot(msg.sender) onlyEOA nonReentrant {
        _updateReward(msg.sender);
        _stakeNft(msg.sender, _contract, _tokenId, _vNonceValue, _r, _s);
        userNFTs[msg.sender].push(
            StakedNFT({tokenContract: _contract, tokenId: _tokenId})
        );
        _getReward(msg.sender);
    }

    function withdraw(address _contract, uint256 _tokenId)
        external
        onlyEOA
        nonReentrant
    {
        _updateReward(msg.sender);
        _withdrawNFT(msg.sender, _contract, _tokenId);

        StakedNFT[] storage stakedNfts = userNFTs[msg.sender];
        uint256 stakeNums = stakedNfts.length;
        for (uint256 i = 0; i < stakeNums; i++) {
            if (
                stakedNfts[i].tokenContract == _contract &&
                stakedNfts[i].tokenId == _tokenId
            ) {
                stakedNfts[i] = stakedNfts[stakeNums - 1];
                stakedNfts.pop();
                break;
            }
        }
        require(
            userNFTs[msg.sender].length == (stakeNums - 1),
            "NFTFarms#withdraw: staked info mismatch"
        );
        _getReward(msg.sender);
    }

    function getReward() external nonReentrant onlyEOA {
        _updateReward(msg.sender);
        _getReward(msg.sender);
    }

    function boost() external nonReentrant onlyEOA {
        _updateReward(msg.sender);
        _calcHashRate(msg.sender, 0, 0);
    }

    /****************************   internal write function        *******************************/

    function _updateReward(address _user) internal {
        uint256 lastHeightReward = latestHeightReward();
        rewardPerTokenStored = _rewardPerHashRate(lastHeightReward);
        lastUpdateHeight = lastHeightReward;

        if (_user != address(0)) {
            UserRewardInfo storage info = userRewardInfoMap[_user];
            info.userReward = SafeMathExt.safe128(
                _pendingReward(_user, rewardPerTokenStored)
            );
            info.userRewardPerTokenPaid = SafeMathExt.safe128(
                rewardPerTokenStored
            );
        }
    }

    function _calcHashRate(
        address _user,
        uint256 _hashrateFixedAdd,
        uint256 _hashrateFixedSub
    ) internal {
        UserRewardInfo storage info = userRewardInfoMap[_user];
        uint256 oldHashRate = _userHashRate(
            uint256(info.userHashrateFixed),
            uint256(info.userHashratePercent)
        );

        if (_hashrateFixedSub > 0) {
            info.userHashrateFixed = SafeMathExt.sub128(
                info.userHashrateFixed,
                SafeMathExt.safe128(_hashrateFixedSub)
            );
        }

        if (_hashrateFixedAdd > 0) {
            info.userHashrateFixed = SafeMathExt.add128(
                info.userHashrateFixed,
                SafeMathExt.safe128(_hashrateFixedAdd)
            );
        }

        (uint128 percent, ) = getWeightByVMYT(_user);
        info.userHashratePercent = percent;
        uint256 newHashRate = _userHashRate(
            uint256(info.userHashrateFixed),
            uint256(info.userHashratePercent)
        );
        totalHashRate = totalHashRate + newHashRate - oldHashRate;
    }

    function _stakeNft(
        address _user,
        address _contract,
        uint256 _tokenId,
        uint256 _vNonceValue,
        bytes32 _r,
        bytes32 _s
    ) internal {
        require(
            nftWhiteMap[_contract],
            "NFTFarms#stake: nft contract is not in white list"
        );
        uint256 hashrate = setNftHashRate(
            _contract,
            _tokenId,
            _vNonceValue,
            _r,
            _s
        );
        hashrate = (hashrate > singleNFTMaxHashRate)
            ? singleNFTMaxHashRate
            : hashrate;

        require(hashrate > 0, "NFTFarms#_stakeNft: invalid hashrate");
        // 0xd9b67a26
        if (
            IERC165Upgradeable(_contract).supportsInterface(ERC1155InterfaceId)
        ) {
            // _stake1155Nft
            require(
                IERC1155Upgradeable(_contract).balanceOf(_user, _tokenId) == 1,
                "NFTFarms#_stakeNft: invalid erc1155 amount"
            );
            _stake1155Nft(_user, _contract, _tokenId, hashrate);
        } else if (
            IERC165Upgradeable(_contract).supportsInterface(ERC721InterfaceId)
        ) {
            _stake721Nft(_user, _contract, _tokenId, hashrate);
        } else {
            revert("NFTFarms#_stakeNft: unsupported nft");
        }
    }

    function _withdrawNFT(
        address _user,
        address _contract,
        uint256 _tokenId
    ) internal {
        if (
            IERC165Upgradeable(_contract).supportsInterface(ERC1155InterfaceId)
        ) {
            require(
                IERC1155Upgradeable(_contract).balanceOf(_user, _tokenId) == 0,
                "NFTFarms#_withdrawNFT: invalid erc1155 amount"
            );
            _withdraw1155Nft(_user, _contract, _tokenId);
        } else if (
            IERC165Upgradeable(_contract).supportsInterface(ERC721InterfaceId)
        ) {
            _withdraw721Nft(_user, _contract, _tokenId);
        } else {
            revert("NFTFarms#_withdrawNFT: unsupported nft");
        }
    }

    function _stake1155Nft(
        address _user,
        address _contract,
        uint256 _tokenId,
        uint256 _hashrate
    ) internal {
        NftInfo storage nftInfo = stakedNFTInfoMap[_contract][_tokenId];
        require(
            nftInfo.owner == address(0) && nftInfo.hashrate == 0,
            "NFTFarms#_stake1155Nft: erc1155 token can stake only once"
        );
        IERC1155Upgradeable(_contract).safeTransferFrom(
            _user,
            address(this),
            _tokenId,
            1,
            ""
        );
        nftInfo.owner = _user;
        nftInfo.hashrate = _hashrate;
        _calcHashRate(_user, _hashrate, 0);

        emit stake1155NFT(_user, _contract, _tokenId, 1);
    }

    function _stake721Nft(
        address _user,
        address _contract,
        uint256 _tokenId,
        uint256 _hashrate
    ) internal {
        NftInfo storage nftInfo = stakedNFTInfoMap[_contract][_tokenId];

        require(
            nftInfo.owner == address(0) && nftInfo.hashrate == 0,
            "NFTFarms#_stake721Nft: erc721 can stake only once"
        );
        IERC721Upgradeable(_contract).safeTransferFrom(
            _user,
            address(this),
            _tokenId
        );
        nftInfo.owner = _user;
        nftInfo.hashrate = _hashrate;
        _calcHashRate(_user, _hashrate, 0);

        emit stake721NFT(_user, _contract, _tokenId);
    }

    function _withdraw1155Nft(
        address _user,
        address _contract,
        uint256 _tokenId
    ) internal {
        NftInfo storage nftInfo = stakedNFTInfoMap[_contract][_tokenId];
        require(
            nftInfo.owner == _user && nftInfo.hashrate <= singleNFTMaxHashRate,
            "NFTFarms#_withdraw1155Nft: invalid withdraw 1155 token"
        );
        uint256 hashrate = nftInfo.hashrate;
        IERC1155Upgradeable(_contract).safeTransferFrom(
            address(this),
            _user,
            _tokenId,
            1,
            ""
        );
        delete stakedNFTInfoMap[_contract][_tokenId];
        _calcHashRate(_user, 0, hashrate);
        emit withdraw1155NFT(_user, _contract, _tokenId, 1);
    }

    function _withdraw721Nft(
        address _user,
        address _contract,
        uint256 _tokenId
    ) internal {
        NftInfo storage nftInfo = stakedNFTInfoMap[_contract][_tokenId];
        require(
            nftInfo.owner == _user &&
                nftInfo.hashrate > 0 &&
                nftInfo.hashrate <= singleNFTMaxHashRate,
            "NFTFarms#_withdraw721Nft: invalid withdraw 721 token"
        );
        uint256 hashrate = nftInfo.hashrate;
        IERC721Upgradeable(_contract).safeTransferFrom(
            address(this),
            _user,
            _tokenId
        );
        delete stakedNFTInfoMap[_contract][_tokenId];
        _calcHashRate(_user, 0, hashrate);
        emit withdraw721NFT(_user, _contract, _tokenId);
    }

    function _getReward(address _user) internal {
        UserRewardInfo storage info = userRewardInfoMap[_user];
        uint256 userReward = uint256(info.userReward);
        if (userReward > 0) {
            info.userReward = 0;
            rewardToken.transfer(_user, userReward);
            emit rewardUser(_user, userReward);
        }
    }

    /****************************   internal pure function        *******************************/

    function _userHashRate(uint256 _fixed, uint256 _percent)
        internal
        pure
        returns (uint256)
    {
        return (_fixed * _percent) / (10000);
    }

    /****************************   internal view function        *******************************/

    function _pendingReward(address _user, uint256 _rewardPerHashrate)
        internal
        view
        returns (uint256)
    {
        UserRewardInfo memory info = userRewardInfoMap[_user];
        uint256 userHashRate = (uint256(info.userHashrateFixed) *
            uint256(info.userHashratePercent));
        return
            (userHashRate *
                (_rewardPerHashrate - (uint256(info.userRewardPerTokenPaid)))) /
            (10000) +
            (uint256(info.userReward));
    }

    function _rewardPerHashRate(uint256 _rewardHeight)
        internal
        view
        returns (uint256)
    {
        if (totalHashRate == 0 || block.number <= rewardStartHeight) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            ((_getStagedReward(_rewardHeight)) / (totalHashRate));
    }

    function _getStagedReward(uint256 _rewardHeight)
        internal
        view
        returns (uint256)
    {
        uint256 x = lastUpdateHeight;
        uint256 y = _rewardHeight;
        uint256 firstStaged = rewardStartHeight + firstRewardPeriod;
        /*  if ( x < firstStaged ) {
              if (y < firstStaged) {
                 return (y - x) * initRewardPerBlock
              } else {
                 return (firstStaged - x) * initRewardPerBlock + (y - firstStaged) * getRewardPerBlock() + sum[ getRewardPerBlock() * (2**i - 1) * oneYearBlockNum]
              }
            } else {
                 return  (y - firstStaged) * getRewardPerBlock() + sum[ getRewardPerBlock() * (2**i - 1) * oneYearBlockNum] - (x - firstStaged) * getRewardPerBlock() - sum[ getRewardPerBlock() * (2**i - 1) * oneYearBlockNum]
            }
        */
        if (x < firstStaged) {
            if (y < firstStaged) {
                return (y - x) * initRewardPerBlock;
            } else {
                return
                    (firstStaged - x) *
                    initRewardPerBlock +
                    _getIntervalRewards(y);
            }
        } else {
            return _getIntervalRewards(y) - _getIntervalRewards(x);
        }
    }

    function _getIntervalRewards(uint256 _height)
        internal
        view
        returns (uint256)
    {
        uint256 firstStaged = rewardStartHeight + firstRewardPeriod;
        uint256 spendYears = (_height - firstStaged) / oneYearBlockNum;
        if (spendYears > maxHalvingYears) {
            spendYears = maxHalvingYears;
        }
        uint256 rewards = (_height - firstStaged) * getRewardPerBlock();
        for (uint256 i = spendYears; i > 0; i--) {
            rewards =
                rewards +
                getRewardPerBlock() *
                (2**i - 1) *
                oneYearBlockNum;
        }
        return rewards;
    }

    /****************************   public view function        *******************************/

    function pendingReward(address _user) public view returns (uint256) {
        return _pendingReward(_user, _rewardPerHashRate(latestHeightReward()));
    }

    function latestHeightReward() public view returns (uint256) {
        if (block.number < rewardStartHeight) {
            return rewardStartHeight;
        } else {
            return SafeMathExt.min(block.number, periodFinishHeight);
        }
    }

    function getRewardPerBlock() public view returns (uint256) {
        uint256 firstStaged = rewardStartHeight + firstRewardPeriod;
        if (block.number < rewardStartHeight) {
            return 0;
        } else if (block.number < firstStaged) {
            return initRewardPerBlock;
        }
        uint256 spendYears = (block.number - firstStaged) / oneYearBlockNum;
        if (spendYears > maxHalvingYears) {
            spendYears = maxHalvingYears;
        }
        return rewardPerBlock / (2**spendYears);
    }

    function getWeightByVMYT(address _account)
        public
        view
        returns (uint128, uint128)
    {
        uint256 balance = vMYT.balanceOf(_account);
        uint256 multiplier = 1e18;

        if (balance < 10000 * multiplier) {
            return (10000, 1);
        } else if (
            balance >= 10000 * multiplier && balance < 50000 * multiplier
        ) {
            return (11000, 2);
        } else if (
            balance >= 50000 * multiplier && balance < 500000 * multiplier
        ) {
            return (13000, 3);
        } else if (
            balance >= 500000 * multiplier && balance < 2500000 * multiplier
        ) {
            return (16000, 4);
        } else {
            return (20000, 5);
        }
    }

    function getNFTFarmsInfo()
        public
        view
        returns (
            uint256 nftRewardStartHeight,
            uint256 nftPeriodFinishHeight,
            uint256 nftInitRewardPerBlock,
            uint256 nftFirstRewardPeriod,
            uint256 nftOneYearBlockNum,
            uint256 nftRewardPerBlock,
            uint256 nftActualRewardPerBlock,
            uint256 nftTotalHashRate,
            uint256 nftSingleNFTMaxHashRate,
            uint256 nftSendRewards,
            address nftRewardToken
        )
    {
        uint256 firstStaged = rewardStartHeight + firstRewardPeriod;
        if (block.number < rewardStartHeight) {
            nftSendRewards = 0;
        } else if (block.number < firstStaged) {
            nftSendRewards =
                initRewardPerBlock *
                (block.number - rewardStartHeight);
        } else {
            nftSendRewards =
                initRewardPerBlock *
                firstRewardPeriod +
                _getIntervalRewards(block.number);
        }

        return (
            rewardStartHeight,
            periodFinishHeight,
            initRewardPerBlock,
            firstRewardPeriod,
            oneYearBlockNum,
            rewardPerBlock,
            getRewardPerBlock(),
            totalHashRate,
            singleNFTMaxHashRate,
            nftSendRewards,
            address(rewardToken)
        );
    }

    function getUserNftFarmsInfo(address _user)
        public
        view
        returns (
            NftNewHashRate[] memory userStakedNfts,
            uint256 vMYTBalance,
            uint256 claimableRewards,
            uint128 currentPercent,
            uint128 actualPercent,
            uint128 soltNum
        )
    {
        StakedNFT[] memory stakedNfts = userNFTs[_user];
        userStakedNfts = new NftNewHashRate[](stakedNfts.length);
        for (uint256 i = 0; i < stakedNfts.length; i++) {
            address tokenContract = stakedNfts[i].tokenContract;
            uint256 tokenId = stakedNfts[i].tokenId;
            userStakedNfts[i] = NftNewHashRate({
                tokenContract: tokenContract,
                tokenId: tokenId,
                hashRate: stakedNFTInfoMap[tokenContract][tokenId].hashrate
            });
        }
        claimableRewards = pendingReward(_user);
        (actualPercent, soltNum) = getWeightByVMYT(_user);
        currentPercent = userRewardInfoMap[_user].userHashratePercent;

        return (
            userStakedNfts,
            vMYT.balanceOf(_user),
            claimableRewards,
            currentPercent,
            actualPercent,
            soltNum
        );
    }
}
