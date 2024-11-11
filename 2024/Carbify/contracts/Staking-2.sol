// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@cryptoalgebra/core/contracts/interfaces/pool/IAlgebraPoolState.sol";
import "./interfaces/ILandplot.sol";
import "./interfaces/INftree.sol";
import "./StakingPool.sol";

contract Staking is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    IERC20 public cbyToken; // CBY token contract
    ILandplot public landplots; // Standard Landplots contract
    ILandplot public landplotsV3; // Genesis Landplots contract
    ILandplot public landplotsV5; // Rare Landplots contract
    StakingPool public stakingPool; // Staking Pool contract
    IAlgebraPoolState private algebraPool; // Algebra Pool contract

    bytes32 public merkleRoot; // Merkle root for the aCO2 claims

    bytes32 public constant CARBIFY_ADMIN_ROLE = keccak256("CARBIFY_ADMIN_ROLE");
    bytes32 public constant NFTREE_BATCH_ROLE = keccak256("NFTREE_BATCH_ROLE");
    bytes32 public constant LANDPLOT_ROLE = keccak256("LANDPLOT_ROLE");

    struct Stake {
        uint256 tokenId;
        address nftreeAddress; 
        uint256 stakingTime; // = $CBY lock time
        uint256 lastClaimTime;
        uint256 remainingReward;
        uint256 lockedCBYAmount;
        address owner;
        bool isLocked;
        bool isStaked;
        uint256 plotId;
        address plotAddress;
    }

    mapping(address => mapping(uint256 => Stake)) public stakes;
    mapping(bytes32 => bool) public claimed;
    mapping(bytes32 => uint256) public merkleClaimRemainingRewards;
    mapping(address => uint256) public userRemainingRewards;

    address public unlockFeeReceiver;

    event Staked(address indexed user, address indexed nftreeAddress,  uint256 tokenId, address indexed plotAddress, uint256 plotId, uint256 time);
    event Unstaked(address indexed user, address indexed nftreeAddress,  uint256 tokenId, uint256 indexed time, uint256 aco2Reward);
    event Locked(address indexed user, address indexed nftreeAddress,  uint256 tokenId, uint256 time, uint256 amount);
    event Unlocked(address indexed user, address indexed nftreeAddress,  uint256 tokenId, uint256 feeAmount, uint256 time, uint256 amount);
    event Claimed(address indexed user, address indexed nftreeAddress,  uint256 tokenId, address indexed plotAddress, uint256 plotId, uint256 time, uint256 aco2Reward);
    event PartialClaim(address indexed user, address indexed nftreeAddress,  uint256 tokenId, uint256 indexed time, uint256 remainingReward);
    event ClaimedStakingMerkle(address indexed user, uint256 amount);
    event PartialClaimStakingMerkle(address indexed user, uint time, uint256 remainingReward);
    event ClaimedRemainingRewards(address indexed user, uint256 time, uint256 amount);

    function initialize(
        address _cbyTokenAddress,
        address _landplotsAddress,
        address _landplotsV3Address,
        address _landplotsV5Address,
        address _algebraPoolAddress,
        address _stakingPoolAddress
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CARBIFY_ADMIN_ROLE, msg.sender);
        cbyToken = IERC20(_cbyTokenAddress);
        landplots = ILandplot(_landplotsAddress);
        landplotsV3 = ILandplot(_landplotsV3Address);
        landplotsV5 = ILandplot(_landplotsV5Address);
        algebraPool = IAlgebraPoolState(_algebraPoolAddress);
        stakingPool = StakingPool(_stakingPoolAddress);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // Function to grant CARBIFY_ADMIN_ROLE
    function grantCarbifyAdminRole(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(CARBIFY_ADMIN_ROLE, _user);
    }

    // Function to revoke CARBIFY_ADMIN_ROLE
    function revokeCarbifyAdminRole(address _user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(CARBIFY_ADMIN_ROLE, _user);
    }

    function setStakingPoolAddress(address _stakingPoolAddress) external onlyRole(CARBIFY_ADMIN_ROLE) { //@audit Missing is contract check
        stakingPool = StakingPool(_stakingPoolAddress);
    }

    function setAlgebraPoolAddress(address _algebraPoolAddress) external onlyRole(CARBIFY_ADMIN_ROLE) { //@audit Missing is contract check
        algebraPool = IAlgebraPoolState(_algebraPoolAddress);
    }

    function setUnlockFeeReceiver(address _unlockFeeReceiver) external onlyRole(CARBIFY_ADMIN_ROLE) { ///@audit missing zero or dead address check
        unlockFeeReceiver = _unlockFeeReceiver;
    }

    function getPrice() public view returns (uint256 finalPrice) {
        (uint160 price,,,,,,) = algebraPool.globalState();
        
        uint256 sqrtPriceX96Pow = uint256(price * 10**12);

        uint256 priceFromSqrtX96 = sqrtPriceX96Pow / 2**96;
        
        priceFromSqrtX96 = priceFromSqrtX96**2; 

        uint256 priceAdj = priceFromSqrtX96 * 10**6; 

        finalPrice = (1 * 10**48) / priceAdj;
    }

    function calculateFiveDollarsWorthCBY() public view returns (uint256) {
        uint256 pricePerCBY = getPrice();
        // Convert 5 USDC to CBY, and adjust the final amount to 18 decimal places
        // Since pricePerCBY is in 6 decimal places, we use 5 * 10**6 for $5 with 6 decimal places
        // Then, we multiply by 10**12 to convert to 18 decimal places
        return (5 * 10**6 * 10**18) / pricePerCBY;
    }

    function isStaked(uint256 _tokenId, address _nftreeAddress) public view returns (bool) {
        return stakes[_nftreeAddress][_tokenId].isStaked;
    }

    // Function to get the total amount of CBY tokens staked by a user within a range of token IDs
    function getTotalLockedAmountPerUser(address _user, address _nftreeAddress, uint256 startTokenId, uint256 endTokenId) public view returns (uint256) {
        uint256 totalStakedAmount = 0;

        // Ensure that the startTokenId is less than or equal to endTokenId
        require(startTokenId <= endTokenId, "Invalid token ID range: startTokenId should be less than or equal to endTokenId");

        // Ensure that the token IDs are within the valid range of the total supply
        require(startTokenId > 0 && endTokenId <= INftree(_nftreeAddress).totalSupply(), "Token ID range is out of bounds");

        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            if (stakes[_nftreeAddress][i].owner == _user && stakes[_nftreeAddress][i].isLocked) {
                totalStakedAmount += stakes[_nftreeAddress][i].lockedCBYAmount;
            }
        }

        return totalStakedAmount;
    }

    // Function to get the locked amount of CBY tokens per NFTree
    function getLockedAmountPerNFTree(uint256 _tokenId, address _nftreeAddress) public view returns (uint256) {
        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];
        if (stakeInfo.isLocked) {
            return stakeInfo.lockedCBYAmount;
        }
        return 0;
    }

    // Function to calculate the current USD value of locked CBY for a specific NFTree
    function getLockedCBYValueInUSD(uint256 _tokenId, address _nftreeAddress) public view returns (uint256) {
        uint256 lockedCBYAmount = getLockedAmountPerNFTree(_tokenId, _nftreeAddress);
        uint256 currentPrice = getPrice(); // Assuming getPrice returns the price of 1 CBY in USD
        return (lockedCBYAmount * currentPrice) / 1e18;
    }

    // Function for calculating aCO2 rewards for a single NFTree
    function calculateRewards(uint256 _tokenId, address _nftreeAddress) public view returns (uint256) {
        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];

        // Ensure the NFTree is currently staked
        require(stakeInfo.isStaked, "NFTree is not staked");

        // 175 aCO2 per year
        uint256 pendingReward = (block.timestamp - stakeInfo.lastClaimTime) * uint256(uint256(175 ether) / uint256(365)) / 86400; //@audit why divided by 24 hours

        uint256 reward;
        if (stakeInfo.plotAddress == address(landplots)) {
            // 80% of the pending reward for standard plots
            reward = (pendingReward * 80) / 100;
        } else if (stakeInfo.plotAddress == address(landplotsV5)) {
            // 90% of the pending reward for rare plots
            reward = (pendingReward * 90) / 100;
        } else if (stakeInfo.plotAddress == address(landplotsV3)) {
            // 100% of the pending reward for genesis plots
            reward = pendingReward;
        } else {
            // Default case, if none of the conditions are met (you may want to handle this differently)
            reward = 0;
        }

        // Add the remaining reward to the total reward (we can also pass this code before the if-else block - in that case the multiplier will be applied to the total reward)
        reward += stakeInfo.remainingReward;

        return reward;
    }

    // Function for calculating aCO2 rewards for multiple NFTrees
    function calculateRewardsMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external view returns (uint256[] memory) {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        uint256[] memory rewards = new uint256[](_tokenIds.length);

        for (uint i = 0; i < _tokenIds.length; i++) {
            rewards[i] = calculateRewards(_tokenIds[i], _nftreeAddresses[i]);
        }

        return rewards;
    }

    // Function to lock a single NFTree
    function lock(uint256 _tokenId, address _nftreeAddress) public {
        require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");

        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];
        uint256 fiveDollarsInCBYTokens = calculateFiveDollarsWorthCBY();

        require(INftree(_nftreeAddress).ownerOf(_tokenId) == msg.sender, "Not the owner of the NFTree");
        
        // Check that the locked amount is less than $5 worth of CBY tokens
        require(stakeInfo.lockedCBYAmount < fiveDollarsInCBYTokens, "NFTree already locked with sufficient CBY");

        require(stakeInfo.isStaked == false, "NFTree is staked");

        uint256 requiredAdditionalLockValue = fiveDollarsInCBYTokens - stakeInfo.lockedCBYAmount;
        require(cbyToken.transferFrom(msg.sender, address(this), requiredAdditionalLockValue), "CBY transfer failed"); //@audit Missing Approve check

        stakeInfo.lockedCBYAmount += requiredAdditionalLockValue;
        stakeInfo.isLocked = true;
        stakeInfo.owner = INftree(_nftreeAddress).ownerOf(_tokenId);

        // Emit an event when the lock is successful
        emit Locked(msg.sender, _nftreeAddress, _tokenId, block.timestamp, requiredAdditionalLockValue);

        // Reset stakingTime (= lock time) if this is the first lock
        if (stakeInfo.stakingTime == 0) {
            stakeInfo.stakingTime = block.timestamp;
        }
    }

    // Function to lock multiple NFTrees
    function lockMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            lock(_tokenIds[i], _nftreeAddresses[i]);
        }
    }

    // Function to unlock a single NFTree
    function unlock(uint256 _tokenId, address _nftreeAddress) public {
        require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");

        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];

        // Additional checks and fee calculations
        require(INftree(_nftreeAddress).ownerOf(_tokenId) == msg.sender, "Not the owner of the NFTree");
        require(stakeInfo.isStaked == false, "NFTree is staked");
        require(stakeInfo.isLocked, "Not locked");
        
        uint256 lockDuration = block.timestamp - stakeInfo.stakingTime;
        uint256 feePercentage = getUnlockFeePercentage(lockDuration);
        uint256 feeAmount = stakeInfo.lockedCBYAmount * feePercentage / 10000; // Correct division for basis points
        uint256 returnAmount = stakeInfo.lockedCBYAmount - feeAmount;

        // Burn the fee and transfer the remaining amount
        cbyToken.transfer(unlockFeeReceiver, feeAmount);
        cbyToken.transfer(msg.sender, returnAmount);

        // Update stake info
        stakeInfo.isLocked = false;
        stakeInfo.lockedCBYAmount = 0;
        stakeInfo.owner = address(0);

        emit Unlocked(msg.sender, _nftreeAddress, _tokenId, feeAmount, block.timestamp, returnAmount);
    }

    // Function to unlock multiple NFTrees
    function unlockMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            unlock(_tokenIds[i], _nftreeAddresses[i]);
        }
    }
    
    function unlockMultipleForUser(address _user, uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external onlyRole(CARBIFY_ADMIN_ROLE) {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            address _nftreeAddress = _nftreeAddresses[i];

            require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");

            Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];

            // Additional checks and fee calculations
            require(_user == stakeInfo.owner, "Not the owner of the NFTree");
            require(stakeInfo.isStaked == false, "NFTree is staked");
            require(stakeInfo.isLocked, "Not locked");
            
            cbyToken.transfer(msg.sender, stakeInfo.lockedCBYAmount);

            emit Unlocked(stakeInfo.owner, _nftreeAddress, _tokenId, 0, block.timestamp, stakeInfo.lockedCBYAmount);

            // Update stake info
            stakeInfo.isLocked = false;
            stakeInfo.lockedCBYAmount = 0;
            stakeInfo.owner = address(0);
        }
    }

    // Function to stake a single NFTree
    function stake(uint256 _tokenId, address _nftreeAddress, uint256 _plotId, address _plotAddress) public {
        require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");
        require(hasRole(LANDPLOT_ROLE, _plotAddress), "_plotAddress not authorized");
        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];
        
        if (!stakeInfo.isLocked) {
            lock(_tokenId, _nftreeAddress);
        }

        require(stakeInfo.isLocked, "NFTree not locked with CBY"); 

        uint256 correctLockAmount = calculateFiveDollarsWorthCBY();
        
        require(!stakeInfo.isStaked, "NFTree already staked");
        require(INftree(_nftreeAddress).ownerOf(_tokenId) == msg.sender, "Not the owner of the NFTree");
        require(_plotAddress == address(landplots) || _plotAddress == address(landplotsV3) || _plotAddress == address(landplotsV5), "Invalid plot address");

        if (stakeInfo.lockedCBYAmount < correctLockAmount) {
            uint256 additionalLockAmount = correctLockAmount - stakeInfo.lockedCBYAmount;
            require(cbyToken.transferFrom(msg.sender, address(this), additionalLockAmount), "CBY transfer failed"); //@audit missing allowance check
            stakeInfo.lockedCBYAmount += additionalLockAmount;
        }

        // Update plot capacity in Landplots contract
        // TODO: we can make this code simpler by using a common interface
        if (_plotAddress == address(landplots)) {
            require(landplots.isPlotAvailable(_plotId), "Plot is not available for staking");
            require(landplots.ownerOf(_plotId) == msg.sender, "Not the owner of the plot");

            landplots.incrementPlotCapacity(_plotId);
        } else if (_plotAddress == address(landplotsV3)) {
            require(landplotsV3.isPlotAvailable(_plotId), "Plot is not available for staking");
            require(landplotsV3.ownerOf(_plotId) == msg.sender, "Not the owner of the plot");

            landplotsV3.incrementPlotCapacity(_plotId);
        } else if (_plotAddress == address(landplotsV5)) {
            require(landplotsV5.isPlotAvailable(_plotId), "Plot is not available for staking");
            require(landplotsV5.ownerOf(_plotId) == msg.sender, "Not the owner of the plot");
            
            landplotsV5.incrementPlotCapacity(_plotId);
        }

        stakes[_nftreeAddress][_tokenId] = Stake({
            tokenId: _tokenId,
            nftreeAddress: _nftreeAddress,
            stakingTime: stakeInfo.stakingTime,
            lastClaimTime: block.timestamp,
            remainingReward: 0,
            owner: msg.sender,
            lockedCBYAmount: stakeInfo.lockedCBYAmount,
            isLocked: true,
            isStaked: true,
            plotId: _plotId,
            plotAddress: _plotAddress
        });

        emit Staked(msg.sender, _nftreeAddress, _tokenId, _plotAddress, _plotId, block.timestamp);
    }

    // Function to stake multiple NFTrees
    function stakeMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses, uint256[] calldata _plotIds, address[] calldata _plotAddresses) external {
        require(_tokenIds.length == _plotIds.length, "Mismatched arrays length");
        require(_tokenIds.length == _plotAddresses.length, "Mismatched arrays length");
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            stake(_tokenIds[i], _nftreeAddresses[i], _plotIds[i], _plotAddresses[i]);
        }
    }

    // Function to unstake a single NFTree
    function unstake(uint256 _tokenId, address _nftreeAddress, bool _shouldUnlock) public {
        require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");

        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];

        require(stakeInfo.isLocked, "NFTree not locked with CBY");
        require(stakeInfo.isStaked, "NFTree not staked");
        require(msg.sender == _nftreeAddress || stakeInfo.owner == msg.sender, "Caller is not authorized");

        // Update plot capacity in Landplots contract
        uint256 plotId = stakeInfo.plotId;
        if (stakeInfo.plotAddress == address(landplots)) {
            landplots.decreasePlotCapacity(plotId);
        } else if (stakeInfo.plotAddress == address(landplotsV3)) {
            landplotsV3.decreasePlotCapacity(plotId);
        } else if (stakeInfo.plotAddress == address(landplotsV5)) {
            landplotsV5.decreasePlotCapacity(plotId);
        }

        // Calculate the total reward considering remainingReward and new rewards
        uint256 totalReward = calculateRewards(_tokenId, _nftreeAddress);
        uint256 totalaCO2Pooled = stakingPool.getaCO2Balance();
        uint256 claimableReward = (totalReward <= totalaCO2Pooled) ? totalReward : totalaCO2Pooled;

        // Only claim if there is a claimable reward
        if (claimableReward > 0) {
            stakingPool.claimStakingaCO2(stakeInfo.owner, claimableReward);
        }

        // Update remainingReward for the NFTree
        userRemainingRewards[stakeInfo.owner] += (totalReward - claimableReward);

        // Update staking status
        stakeInfo.isStaked = false;
        stakeInfo.lastClaimTime = 0;
        stakeInfo.remainingReward = 0;
        stakeInfo.plotAddress = address(0);
        stakeInfo.plotId = 0;

        // Emit an event for unstaking
        emit Unstaked(stakeInfo.owner, _nftreeAddress, _tokenId, block.timestamp, claimableReward);

        // Emit an event for partial claims if there is a remaining reward
        if (stakeInfo.remainingReward > 0) {
            emit PartialClaim(stakeInfo.owner, _nftreeAddress, _tokenId, block.timestamp, stakeInfo.remainingReward); 
        }

        // Unlock CBY tokens if required
        if (msg.sender != _nftreeAddress && _shouldUnlock) {
            unlock(_tokenId, _nftreeAddress);
        }
    }

    // Function to unstake multiple NFTrees
    function unstakeMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddress, bool _shouldUnlock) external {
        require(_tokenIds.length == _nftreeAddress.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            unstake(_tokenIds[i], _nftreeAddress[i], _shouldUnlock);
        }
    }

    // Function to unstake multiple NFTrees for a user
    function unstakeMultipleForUser(
        address _user,
        uint256[] calldata _tokenIds,
        address[] calldata _nftreeAddress
    ) external onlyRole(CARBIFY_ADMIN_ROLE) {
        require(_tokenIds.length == _nftreeAddress.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            address nftreeAddress = _nftreeAddress[i]; // Renamed to avoid shadowing

            require(hasRole(NFTREE_BATCH_ROLE, nftreeAddress), "nftreeAddress not authorized");

            Stake storage stakeInfo = stakes[nftreeAddress][_tokenId];

            require(stakeInfo.isLocked, "NFTree not locked with CBY");
            require(stakeInfo.isStaked, "NFTree not staked");
            require(stakeInfo.owner == _user, "Caller is not authorized");

            // Update plot capacity in Landplots contract
            uint256 plotId = stakeInfo.plotId;
            if (stakeInfo.plotAddress == address(landplots)) {
                landplots.decreasePlotCapacity(plotId);
            } else if (stakeInfo.plotAddress == address(landplotsV3)) {
                landplotsV3.decreasePlotCapacity(plotId);
            } else if (stakeInfo.plotAddress == address(landplotsV5)) {
                landplotsV5.decreasePlotCapacity(plotId);
            }

            // Calculate the total reward considering remainingReward and new rewards
            uint256 totalReward = calculateRewards(_tokenId, nftreeAddress);
            uint256 totalaCO2Pooled = stakingPool.getaCO2Balance();
            uint256 claimableReward = (totalReward <= totalaCO2Pooled) ? totalReward : totalaCO2Pooled;

            // Only claim if there is a claimable reward
            if (claimableReward > 0) {
                stakingPool.claimStakingaCO2(stakeInfo.owner, claimableReward);
            }

            // Update remainingReward for the NFTree
            userRemainingRewards[stakeInfo.owner] += (totalReward - claimableReward);

            // Update staking status
            stakeInfo.isStaked = false;
            stakeInfo.lastClaimTime = 0;
            stakeInfo.remainingReward = 0;
            stakeInfo.plotAddress = address(0);
            stakeInfo.plotId = 0;

            // Emit an event for unstaking
            emit Unstaked(stakeInfo.owner, nftreeAddress, _tokenId, block.timestamp, claimableReward);

            // Emit an event for partial claims if there is a remaining reward
            if (stakeInfo.remainingReward > 0) {
                emit PartialClaim(stakeInfo.owner, nftreeAddress, _tokenId, block.timestamp, stakeInfo.remainingReward); 
            }
        }
    }

    // Internal function to handle claiming logic
    function _claim(
        address _user,
        uint256 _tokenId,
        address _nftreeAddress
    ) internal {
        require(hasRole(NFTREE_BATCH_ROLE, _nftreeAddress), "_nftreeAddress not authorized");

        Stake storage stakeInfo = stakes[_nftreeAddress][_tokenId];

        // Ensure the NFTree is currently staked
        require(stakeInfo.isStaked, "NFTree is not staked");

        // Ensure the provided _user is the owner of the staked NFTree
        require(stakeInfo.owner == _user, "Caller is not the NFTree owner");

        // Check if the user has any remaining rewards
        uint256 remainingReward = userRemainingRewards[_user];
        if (remainingReward > 0) {
            // Claim remaining rewards logic
            uint256 totalaCO2Pooled = stakingPool.getaCO2Balance();
            uint256 claimableReward = (remainingReward <= totalaCO2Pooled) ? remainingReward : totalaCO2Pooled;

            if (claimableReward > 0) {
                stakingPool.claimStakingaCO2(_user, claimableReward);
            }

            // Update the remaining rewards for the user
            userRemainingRewards[_user] = remainingReward - claimableReward;

            // Emit event for claiming remaining rewards
            emit ClaimedRemainingRewards(_user, block.timestamp, claimableReward);
        } else {
            // Proceed with the current _claim logic if no remaining rewards
            require(stakeInfo.lastClaimTime + 1 days <= block.timestamp, "NFTree has no pending reward");

            // Calculate the total reward considering remainingReward and new rewards
            uint256 totalReward = calculateRewards(_tokenId, _nftreeAddress);
            uint256 totalaCO2Pooled = stakingPool.getaCO2Balance();
            uint256 claimableReward = (totalReward <= totalaCO2Pooled) ? totalReward : totalaCO2Pooled;

            // Only claim if there is a claimable reward
            if (claimableReward > 0) {
                stakingPool.claimStakingaCO2(_user, claimableReward);
            }

            // Update remainingReward for the NFTree
            stakeInfo.remainingReward = totalReward - claimableReward;

            // Update the last claim time
            stakeInfo.lastClaimTime = block.timestamp;

            // Emit an event for claiming
            emit Claimed(_user, _nftreeAddress, _tokenId, stakeInfo.plotAddress, stakeInfo.plotId, block.timestamp, claimableReward);

            // Emit an event for partial claims if there is a remaining reward
            if (stakeInfo.remainingReward > 0) {
                emit PartialClaim(_user, _nftreeAddress, _tokenId, block.timestamp, stakeInfo.remainingReward);
            }
        }
    }

    // Function to claim aCO2 tokens for a single NFTree
    function claim(uint256 _tokenId, address _nftreeAddress) public {
        _claim(msg.sender, _tokenId, _nftreeAddress);
    }

    // Function for claiming aCO2 tokens for multiple NFTrees
    function claimMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        for (uint i = 0; i < _tokenIds.length; i++) {
            claim(_tokenIds[i], _nftreeAddresses[i]);
        }
    }

    // Function for claiming aCO2 tokens on behalf of another user
    function claimForUser(address _user, uint256 _tokenId, address _nftreeAddress) external {
        require(hasRole(CARBIFY_ADMIN_ROLE, msg.sender), "Caller is not authorized");
        _claim(_user, _tokenId, _nftreeAddress);
    }

    // Function to claim rewards
    function claimStakingMerkleReward(uint256 amount, bytes32[] calldata merkleProof) public {
        require(merkleRoot != bytes32(0), "Merkle root not set");

        // Create a composite key from msg.sender and amount
        bytes32 claimKey = keccak256(abi.encodePacked(msg.sender, amount));

        require(!claimed[claimKey], "Reward already claimed");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        require(verify(merkleProof, merkleRoot, leaf), "Invalid proof");

        // Calculate the total claimable reward (initially based on the amount provided)
        uint256 remainingReward = (merkleClaimRemainingRewards[claimKey] > 0) 
            ? merkleClaimRemainingRewards[claimKey] 
            : amount;

        // Check the available balance in the staking pool
        uint256 totalaCO2Pooled = stakingPool.getaCO2Balance(); // stakingPool.getaCO2Balance(); || 0;
        
        // Adjust the claimable reward based on the pool's current balance
        uint256 claimableReward = (remainingReward <= totalaCO2Pooled) ? remainingReward : totalaCO2Pooled;

        // Claim the reward from the StakingPool
        stakingPool.claimStakingaCO2(msg.sender, claimableReward);

        // Update the remaining reward if this was a partial claim
        if (remainingReward > totalaCO2Pooled) {
            merkleClaimRemainingRewards[claimKey] = remainingReward - claimableReward;
            
            // Emit an event for partial claims
            emit PartialClaimStakingMerkle(msg.sender, block.timestamp, merkleClaimRemainingRewards[claimKey]);
        } else {
            // Full claim has been made, mark as claimed
            claimed[claimKey] = true;
        }

        // Emit an event for successful claim
        emit ClaimedStakingMerkle(msg.sender, claimableReward);
    }

    // Function to claim multiple merkle rewards
    function claimMultipleStakingMerkleRewards(uint256[] calldata amounts, bytes32[][] calldata merkleProofs) external {
        require(amounts.length == merkleProofs.length, "Mismatched amounts and merkleProofs length");

        for (uint256 i = 0; i < amounts.length; i++) {
            claimStakingMerkleReward(amounts[i], merkleProofs[i]);
        }
    }

    // Function to see if a leaf has been claimed
    function isClaimed(address walletAddress, uint256 amount) external view returns (bool) {
        bytes32 claimKey = keccak256(abi.encodePacked(walletAddress, amount));
        return claimed[claimKey];
    }

    // Function to see if a lead has been claimed batch
    function isClaimedBatch(address walletAddress, uint256[] calldata amounts) external view returns (bool[] memory) {
        bool[] memory results = new bool[](amounts.length);

        for (uint256 i = 0; i < amounts.length; i++) {
            bytes32 claimKey = keccak256(abi.encodePacked(walletAddress, amounts[i]));
            results[i] = claimed[claimKey];
        }

        return results;
    }

    function getStakedNFTreesOfUser(address _user, address _nftreeAddress) external view returns (uint256[] memory) {
        uint256 totalNFTrees = INftree(_nftreeAddress).totalSupply();
        uint256[] memory stakedNFTrees;
        uint256 count = 0;

        // First, count the number of NFTrees staked by the user
        for (uint256 i = 0; i < totalNFTrees; i++) {
            if (stakes[_nftreeAddress][i].owner == _user && stakes[_nftreeAddress][i].isStaked) {
                count++;
            }
        }

        stakedNFTrees = new uint256[](count);
        count = 0;

        // Then, populate the array with the IDs of the staked NFTrees
        for (uint256 i = 0; i < totalNFTrees; i++) {
            if (stakes[_nftreeAddress][i].owner == _user && stakes[_nftreeAddress][i].isStaked) {
                stakedNFTrees[count] = i;
                count++;
            }
        }

        return stakedNFTrees;
    }

    // Get remaining Merkle rewards for a single NFTree
    function getRemainingMerkleReward(address walletAddress, uint256 amount) external view returns (uint256) {
        bytes32 claimKey = keccak256(abi.encodePacked(walletAddress, amount));
        return merkleClaimRemainingRewards[claimKey];
    }

    function getUserStakes(address _user, address _nftreeAddress) external view returns (uint256[] memory, uint256[] memory) {
        uint256 totalNFTrees = INftree(_nftreeAddress).totalSupply();
        uint256 count = 0;

        // Count the number of NFTrees staked by the user
        for (uint256 i = 1; i <= totalNFTrees; i++) {
            if (stakes[_nftreeAddress][i].owner == _user && stakes[_nftreeAddress][i].isStaked) {
                count++;
            }
        }

        uint256[] memory stakedNFTrees = new uint256[](count);
        uint256[] memory plotIds = new uint256[](count);
        count = 0;

        // Populate arrays with the IDs of the staked NFTrees and their plot IDs
        for (uint256 i = 1; i <= totalNFTrees; i++) {
            if (stakes[_nftreeAddress][i].owner == _user && stakes[_nftreeAddress][i].isStaked) {
                stakedNFTrees[count] = i;
                plotIds[count] = stakes[_nftreeAddress][i].plotId;
                count++;
            }
        }

        return (stakedNFTrees, plotIds);
    }

    // Fetch stakesInfo for a single NFTree
    function getStakeInfo(uint256 _tokenId, address _nftreeAddress) external view returns (Stake memory) {
        return stakes[_nftreeAddress][_tokenId];
    }

    // Fetch stakesInfo for multiple NFTrees
    function getStakeInfoMultiple(uint256[] calldata _tokenIds, address[] calldata _nftreeAddresses) external view returns (Stake[] memory) {
        require(_tokenIds.length == _nftreeAddresses.length, "Mismatched arrays length");

        Stake[] memory stakeInfo = new Stake[](_tokenIds.length);

        for (uint i = 0; i < _tokenIds.length; i++) {
            stakeInfo[i] = stakes[_nftreeAddresses[i]][_tokenIds[i]];
        }

        return stakeInfo;
    }
    
    // Helper function to get unlock fee percentage in basis points
    function getUnlockFeePercentage(uint256 duration) private pure returns (uint256) {
        if (duration < 365 days) {
            return 750; // 7.5% represented as 750 basis points
        } else if (duration < 2 * 365 days) {
            return 375; // 3.75% represented as 375 basis points
        } else {
            return 175; // 1.75% represented as 175 basis points
        }
    }

    // Function to update the Merkle root (callable by owner or admin)
    function setMerkleRoot(bytes32 _merkleRoot) external onlyRole(CARBIFY_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
    }

    // Function to get the Merkle root
    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }

    // Function to verify Merkle proof
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        return computedHash == root;
    }

    // Function to get the remaining aCO2 rewards for a user
    function getRemainingRewards(address _user) external view returns (uint256) {
        return userRemainingRewards[_user];
    }
}