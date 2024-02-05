// SPDX-License-Identifier: UNLICENSED

//contracts/Stakepool.sol

pragma solidity 0.8.16;

// ==========  External imports    ==========
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC721ReceiverUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// ==========  Internal imports    ==========
import {StakePoolStorage} from "./StakePoolStorage.sol";
import {IAtpadNft} from "./interfaces/IAtpadNft.sol";

contract StakePool is
    StakePoolStorage,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // @title StakePool
    // @notice This is a Natspec commented contract by AtomPad Development Team
    // @notice Version v2.2.3 date: 20 Feb 2023

    IERC20Upgradeable public stakeToken;

    //constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _stakeToken) external initializer {
        stakeToken = IERC20Upgradeable(_stakeToken);
        decimals = 18;
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        stakeOn = true;
        withdrawOn = true;
        maxStakeOrWithdrawNft = 10;
        minStakingAmount = 10000;
    }

    //  *******************************************************
    //                    User Logic
    //  *******************************************************

    /**
        @notice This function is used to stake Atompad to the stakepool.
        @dev It can be called by anyone so it is safe against reentrancy
        attacks and can be paused or unpaused by admin.
        @param _amount - The amount of Atompad to stake.
     */

    function stake(uint256 _amount)
        external
        stakeEnabled
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        //if amount is less than required amount, throw error
        require(
            _amount > (10 * 10**decimals),
            "StakePool: Minimum stake amount is 10 tokens."
        );

        //if staked and staking amount is less than required amount, throw error
        require(
            (_amount + tokenBalances[msg.sender]) >=
                (minStakingAmount * 10**decimals),
            "StakePool: Staking amount is less than minimum staking amount."
        );

        //transfer tokens from staker to this contract.
        stakeToken.safeTransferFrom(msg.sender, address(this), _amount);

        //update staking balance of the staker in storage
        tokenBalances[msg.sender] += _amount;

        // reset totalAllocPoint
        totalAllocPoint -= allocPoints[msg.sender];

        //update the allocation point of the staker in storage
        allocPoints[msg.sender] = _reBalance(tokenBalances[msg.sender]);

        //update staking time of the staker to current time in storage
        timeLocks[msg.sender] = block.timestamp;

        //update storage variable which keeps track of total allocation points
        totalAllocPoint += allocPoints[msg.sender];

        //update storage variable which keeps track of total tokens staked
        totalStaked += _amount;

        //add user to the list of stakers
        userAdresses.push(msg.sender);

        //emit event
        emit Staked(msg.sender, _amount);

        return true;
    }

    /**
        @notice This function is used to unstake Atompad from the stakepool.
        @dev It can be called by anyone so it is safe against reentrancy
        attacks and can be paused or unpaused by admin.
        @param _amount - The amount of Atompad to unstake.
     */
    function withdraw(uint256 _amount)
        public
        withdrawEnabled
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        //if amount is less than staked amount, throw error
        require(
            tokenBalances[msg.sender] >= _amount,
            "StakePool: Insufficient staking balance!"
        );

        require(_amount > 0, "StakePool: !amount");

        //calculate the withraw fee of the staker and store it in memory
        uint256 _fee = calculateWithdrawFees(_amount, msg.sender);

        //update staking balance of the staker in storage
        tokenBalances[msg.sender] -= _amount;

        // reset totalAllocPoint
        totalAllocPoint -= allocPoints[msg.sender];

        //store new allocation point of the staker in storage
        allocPoints[msg.sender] = _reBalance(tokenBalances[msg.sender]);

        //calculate the amount to be transferred to the staker and store it in memory
        uint256 _transferAmount = _amount - _fee;

        //update storage variable which keeps track of total allocation points
        totalAllocPoint += allocPoints[msg.sender];

        //update storage variable which keeps track of total fee collected
        collectedFee += _fee;

        //update storage variable which keeps track of total tokens staked
        totalStaked -= _amount;

        //transfer tokens from this contract to staker.
        stakeToken.safeTransfer(msg.sender, _transferAmount);

        //emit event
        emit Withdrawn(msg.sender, _amount);

        return true;
    }

    /**
        @notice This function is used to withdraw all the Atompad staked by this staker.
        @dev It can be called by anyone so it is safe against reentrancy attacks and
        can be paused or unpaused by admin.
     */
    function withdrawAll()
        external
        withdrawEnabled
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        withdraw(tokenBalances[msg.sender]);
        return true;
    }

    /**
        @notice This function is used to stake single or multiple nfts to the stakepool.
        @dev It can be called by anyone so it is safe against reentrancy attacks and  can be paused or unpaused by admin.
        @param _tokenIds - The ids of the nfts to stake.
        @param _tierIndex - The index of the tier to stake nfts.
     */
    function stakeNft(uint256[] memory _tokenIds, uint256 _tierIndex)
        external
        stakeEnabled
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        uint256 _tokenIdsLength = _tokenIds.length;

        //Check if staker wants to stake any nft
        require(_tokenIdsLength > 0, "StakePool: !tokenIDs");

        //Check if staker wants to stake more than max limit
        require(
            _tokenIdsLength <= maxStakeOrWithdrawNft,
            "StakePool: Nft count exceeds max limit."
        );

        //Check if tier exists
        require(_tierIndex < tiers.length, "StakePool: Tier does not exists !");

        Tier memory _tier = tiers[_tierIndex];

        address _collection = _tier.collection;

        uint256 _weight = _tier.weight;

        //Calculate total weight of the nfts to be staked
        uint256 _totalWeight = _weight * _tokenIdsLength;

        //keep track of nft owners in this contract
        for (uint256 i; i < _tokenIds.length; i++) {
            //transfer nft from staker to this contract.
            IAtpadNft(_tier.collection).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );

            nftOwners[_collection][_tokenIds[i]] = msg.sender;
        }

        //Update nft balance of the staker in storage
        nftBalances[_collection][msg.sender] += _tokenIdsLength;

        //store new allocation point of the staker in storage
        nftAllocPoints[msg.sender] += _totalWeight;

        //update storage variable which keeps track of total allocation points
        totalAllocPoint += _totalWeight;

        //update storage variable which keeps track of total nft staked
        totalStakedNft += _tokenIdsLength;

        //add user to the list of stakers
        userAdresses.push(msg.sender);

        //emit event
        emit NFTStaked(msg.sender, _tokenIds);

        return true;
    }

    /**
        @notice This function is used to unstake nft from the stakepool.
        @dev It can be called by anyone so it is safe against reentrancy attacks and  can be paused or unpaused by admin.
        @param _tokenIds - The ids of the nfts to unstake.
        @param _tierIndex - The index of the tier to unstake nfts.
     */

    function withdrawNft(uint256[] memory _tokenIds, uint256 _tierIndex)
        external
        nonReentrant
        whenNotPaused
        withdrawEnabled
        returns (bool)
    {
        uint256 _tokenIdsLength = _tokenIds.length;

        //if token id length is invalid, throw error
        require(_tokenIdsLength > 0, "StakePool: !tokenIDs");

        //if staker requesting to unstake more than 10 nfts at a time, throw error
        require(
            _tokenIdsLength <= maxStakeOrWithdrawNft,
            "StakePool: Nft count exceeds max limit."
        );

        //if tier index is invalid, throw error
        require(_tierIndex < tiers.length, "StakePool: Tier does not exists !");

        Tier memory _tier = tiers[_tierIndex];

        address _collection = _tier.collection;

        require(
            _tokenIdsLength <= nftBalances[_collection][msg.sender],
            "StakePool: !staked"
        );

        //if staker is not the owner of the nft, throw error
        for (uint256 i; i < _tokenIdsLength; i++) {
            require(
                nftOwners[_collection][_tokenIds[i]] == msg.sender,
                "StakePool: !staked"
            );
        }

        uint256 _totalWeight = _tier.weight * _tokenIdsLength;

        //update the allocation point of the staker in storage
        nftAllocPoints[msg.sender] -= _totalWeight;

        //update nft balance of the staker
        nftBalances[_collection][msg.sender] -= _tokenIdsLength;

        //update storage variable which keeps track of total allocation points
        totalAllocPoint -= _totalWeight;

        //update storage variable which keeps track of total nft staked
        totalStakedNft -= _tokenIdsLength;

        for (uint256 i; i < _tokenIdsLength; i++) {
            //delete nft owner of this nft from this contract
            nftOwners[_collection][_tokenIds[i]] = address(0);

            //transfer nfts from this contract to staker.
            IAtpadNft(_tier.collection).safeTransferFrom(
                address(this),
                msg.sender,
                _tokenIds[i]
            );
        }

        //emit event
        emit NFTWithdrawn(msg.sender, _tokenIds);

        return true;
    }

    /**
        @dev It can be called by anyone so it is safe against reentrancy attacks and  can be paused or unpaused by admin.
        @param _tokenIds - The ids of the nfts to stake.
        @param _tierIndex - The index of the tier to stake nfts.
     */

    ///@dev Function to get balance of staker in stakepool.
    function balanceOf(address _sender) external view returns (uint256) {
        return tokenBalances[_sender];
    }

    ///@dev Function to the staking time of the staker in stakepool.
    function lockOf(address _sender) external view returns (uint256) {
        return timeLocks[_sender];
    }

    ///@dev Function to get allocation point of the staker in stakepool.
    function allocPointsOf(address _sender) public view returns (uint256) {
        return
            allocPoints[_sender] +
            nftAllocPoints[_sender] +
            promoAllocPoints[_sender];
    }

    function tokenAllocPointsOf(address _sender)
        external
        view
        returns (uint256)
    {
        return allocPoints[_sender];
    }

    function nftAllocPointsOf(address _sender) external view returns (uint256) {
        return nftAllocPoints[_sender];
    }

    function promoAllocPointsOf(address _sender)
        external
        view
        returns (uint256)
    {
        return promoAllocPoints[_sender];
    }

    ///@dev Function to get allocation perecentage of the staker in stakepool.
    function allocPercentageOf(address _sender)
        external
        view
        returns (uint256)
    {
        uint256 points = allocPointsOf(_sender) * 10**6;

        uint256 millePercentage = points / totalAllocPoint;

        return millePercentage;
    }

    ///@dev Function to get owner of the nft staked in stakepool.
    function ownerOf(uint256 _tokenId, address _collection)
        external
        view
        returns (address)
    {
        return nftOwners[_collection][_tokenId];
    }

    ///@dev Function to get all the tiers
    function getTiers() external view returns (Tier[] memory) {
        return tiers;
    }

    ///@dev Function to get all the users
    function users() external view returns (address[] memory) {
        return userAdresses;
    }

    function user(uint256 _index) external view returns (address) {
        return userAdresses[_index];
    }

    function getNfts(
        address _collection,
        address _sender,
        uint256 _limit
    ) external view returns (uint256[] memory) {
        uint256 _balance = nftBalances[_collection][_sender];
        uint256[] memory _tokenIds = new uint256[](_balance);
        uint256 j;
        for (uint256 i; i <= _limit; i++) {
            if (nftOwners[_collection][i] == _sender) {
                _tokenIds[j] = i;
                j++;
            }
        }

        return _tokenIds;
    }

    function getNftBalance(address _collection, address _sender)
        external
        view
        returns (uint256)
    {
        return nftBalances[_collection][_sender];
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    //  *******************************************************
    //                    PUBLIC FUNCTIONS
    //  *******************************************************

    ///@dev function to calculate unstaking fee
    function calculateWithdrawFees(uint256 _amount, address _account)
        public
        view
        returns (uint256 _fee)
    {
        uint256 _timeLock = timeLocks[_account];
        _fee = calculateWithdrawFees(_amount, _timeLock);
    }

    ///@dev function to calculate allocation points
    /// @dev reBalance
    /// @param _balance is the number of tokens staked
    /// @return _points this is the allocation points calculated based on number of tokens
    function _reBalance(uint256 _balance)
        public
        view
        returns (uint256 _points)
    {
        /// @dev initiate
        _points = 0;

        /// @dev uint _smallest = 1000;    // tier 4 staked
        uint256 _smallest = tiers[tiers.length - 1].stake; // use former routine if this fails

        /// @dev take the biggest tier possible
        /// @dev we can keep of numbers per tier in later stage like tier{god}++
        while (_balance >= _smallest) {
            for (uint256 i = 0; i < tiers.length; i++) {
                /// iterate over tiers, order by biggest tier
                if (_balance >= tiers[i].stake) {
                    /// check if we have enough stake left for this tier
                    _points += tiers[i].weight; /// add weight points
                    _balance -= tiers[i].stake; /// redduce balance of stakes
                    i = tiers.length; /// exit iteration loopo
                }
            }
        }
        return _points;
    }

    ///@dev function to calculate unstaking fee
    ///@param _amount - amount to withdraw
    ///@param _timeLock - time when staker last staked
    function calculateWithdrawFees(uint256 _amount, uint256 _timeLock)
        private
        view
        returns (uint256 _fee)
    {
        _fee = 0;

        uint256 _now = block.timestamp;

        if (_now > _timeLock + uint256(8 weeks)) {
            _fee = 0;
        }

        if (_now <= _timeLock + uint256(8 weeks)) {
            _fee = (_amount * 2) / 100;
        }

        if (_now <= _timeLock + uint256(6 weeks)) {
            _fee = (_amount * 5) / 100;
        }

        if (_now <= _timeLock + uint256(4 weeks)) {
            _fee = (_amount * 10) / 100;
        }

        if (_now <= _timeLock + uint256(2 weeks)) {
            _fee = (_amount * 20) / 100;
        }

        return _fee;
    }

    //  *******************************************************
    //                    Admin Logic
    //  *******************************************************
    ///@dev Admin can withdraw collected fee from the pool using it
    function withdrawCollectedFee() external onlyOwner {
        /// @dev do some checks
        require(collectedFee > 0, "StakePool: No fee to withdraw");

        uint256 _amount = collectedFee;
        collectedFee = 0;

        stakeToken.transfer(msg.sender, _amount);
        emit FeeWithdrawn(msg.sender, _amount);
    }

    //Setters
    function resetStakeToken(address _stakeToken) external onlyOwner {
        require(_stakeToken != address(0), "StakePool: !StakeToken");
        stakeToken = IERC20Upgradeable(_stakeToken);
    }

    ///@notice Warning: this function should not be called once stakepool is live for staking
    // function updateTier(Tier memory _tier, uint256 _tierIndex)
    //     external
    //     onlyOwner
    // {
    //     require(_tierIndex < tiers.length, "StakePool: !index");

    //     tiers[_tierIndex] = _tier;
    // }

    ///@dev function to update staking requirement

    // function updateStakingReq(uint256 _stake, uint256 _tierIndex)
    //     external
    //     onlyOwner
    // {
    //     require(_tierIndex < tiers.length, "StakePool: !index");
    //     require(_stake > 0, "!stake");
    //     tiers[_tierIndex].stake = _stake;
    // }

    // ///@notice Warning: this function should not be called once stakepool is live for staking
    // function updateCollection(address _collection, uint256 _tierIndex)
    //     external
    //     onlyOwner
    // {
    //     require(_tierIndex < tiers.length, "StakePool: !index");
    //     require(_collection != address(0), "StakePool: !collection");
    //     tiers[_tierIndex].collection = _collection;
    // }

    ///@dev Admin can add new tier to the pool
    ///@dev This should only called at the time of deployment, and should never be called once staking is live
    function addTier(
        string memory _name,
        address _collection,
        uint256 _stake,
        uint256 _weight
    ) external onlyOwner {
        tiers.push(
            Tier({
                name: _name,
                collection: _collection,
                stake: _stake,
                weight: _weight
            })
        );
    }

    function increasePromoAllocPoints(uint256 _points, address _account)
        external
        onlyOwner
    {
        require(_points > 0, "StakePool: !points");
        promoAllocPoints[_account] += _points;

        totalAllocPoint += _points;
    }

    ///@dev This function is used to decrease promotion allocpoints
    function decreasePromoAllocPoints(uint256 _points, address _account)
        external
        onlyOwner
    {
        require(_points > 0, "StakePool: !points");
        require(
            promoAllocPoints[_account] >= _points,
            "StakePool: Not enough points!"
        );
        promoAllocPoints[_account] -= _points;

        totalAllocPoint -= _points;
    }

    ///@dev Admin can enable or disable NFT staking
    function setEnableOrDisableStake(bool _flag) external onlyOwner {
        stakeOn = _flag;
    }

    ///@dev Admin can enable or disable NFT withdraw
    function setDisableOrWithdraw(bool _flag) external onlyOwner {
        withdrawOn = _flag;
    }

    function setDecimals(uint8 _decimals) external onlyOwner {
        require(_decimals > 0, "StakePool: !decimals");
        decimals = _decimals;
    }

    function setMaxStakeOrWithdrawNft(uint256 _max) external onlyOwner {
        require(_max > 0, "StakePool: !max");
        maxStakeOrWithdrawNft = _max;
    }

    function setMinStakingAmount(uint256 _min) external onlyOwner {
        require(_min > 0, "StakePool: !min");
        minStakingAmount = _min;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //====================Events====================
    event Staked(address indexed user, uint256 amount);
    event NFTStaked(address indexed user, uint256[] tokenIds);
    event Withdrawn(address indexed user, uint256 amount);
    event NFTWithdrawn(address indexed user, uint256[] tokenIds);
    event FeeWithdrawn(address indexed user, uint256 amount);

    //====================Modifiers====================
    modifier stakeEnabled() {
        require(stakeOn == true, "StakePool: Staking is paused !");
        _;
    }

    modifier withdrawEnabled() {
        require(withdrawOn == true, "StakePool: Withdrawing is paused !");
        _;
    }
}