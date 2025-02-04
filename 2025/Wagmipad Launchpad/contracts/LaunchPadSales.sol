// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LaunchPadData.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IStakingRewards.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title LaunchPadSales
 * @dev Contract handling sales logic for the LaunchPad.
 */
contract LaunchPadSales is
    LaunchPadData,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using ECDSAUpgradeable for bytes32;

    modifier onlySigner() {
        require(msg.sender == signer, "Unauthorised");
        _;
    }

    // --------------------------------------------------
    // Admin Functions
    // --------------------------------------------------

    /**
     * @dev Creates a new project.
     * @param project The project information.
     * @param tiers The tier information.
     * @param publicSale The public sale information.
     * @param gtdInfo The GTD sale information.
     */
    function create(
        Project memory project,
        TiersInfo memory tiers,
        PublicSaleInfo memory publicSale,
        GTDInfo memory gtdInfo
    ) external whenNotPaused onlyOwner {
        require(
            project.projectOwner != address(0),
            "Create:: Invalid project owner address"
        );
        require(
            project.saleToken != address(0),
            "Create:: Invalid sale token address"
        );
        require(
            project.paymentToken != address(0),
            "Create:: Invalid payment token address"
        );
        require(project.minCap > 0, "Create:: Invalid min cap");
        require(
            project.totalSaleTokens > 0,
            "Create:: Invalid total sale tokens"
        );

        bool isPublicSale = stakingContract == address(0);

        if (isPublicSale) {
            _validatePublicSaleInfo(
                publicSale.startTime,
                publicSale.endTime,
                tiers.tokenPrice,
                tiers.maxAllowed
            );
        } else {
            _validateTierInfo(
                tiers.maxAllowed,
                tiers.tokenPrice,
                publicSale.startTime,
                publicSale.endTime,
                tiers.startTime,
                tiers.endTime,
                gtdInfo.startTime,
                gtdInfo.endTime
            );
        }

        TransferHelper.safeTransferFrom(
            project.saleToken,
            msg.sender,
            address(this),
            project.totalSaleTokens
        );

        projectInfos[projectCount] = ProjectInfo({
            projectOwner: project.projectOwner,
            saleToken: project.saleToken,
            paymentToken: project.paymentToken,
            minCap: project.minCap,
            totalSaleTokens: project.totalSaleTokens,
            totalTokensSold: 0,
            totalAmountMade: 0,
            claimStartTime: 0,
            isReachedMinCap: false,
            isSaleEnded: false,
            isClaimStarted: false
        });

        tiersInfos[projectCount] = TiersInfo({
            startTime: tiers.startTime,
            endTime: tiers.endTime,
            tokenPrice: tiers.tokenPrice,
            maxAllowed: isPublicSale
                ? [uint256(0), uint256(0), uint256(0), uint256(0)]
                : tiers.maxAllowed
        });

        publicSalesInfo[projectCount] = PublicSaleInfo({
            tokenPrice: publicSale.tokenPrice,
            startTime: publicSale.startTime,
            endTime: publicSale.endTime
        });

        gtdsInfos[projectCount] = GTDInfo({
            startTime: gtdInfo.startTime,
            endTime: gtdInfo.endTime
        });

        emit ProjectCreated(
            projectCount,
            project.projectOwner,
            project.saleToken,
            project.paymentToken,
            project.minCap,
            project.totalSaleTokens,
            publicSale.tokenPrice,
            publicSale.startTime,
            publicSale.endTime,
            chainId,
            tiers.startTime,
            tiers.endTime
        );

        projectCount++;
    }

    function emergencyWithdraw(
        uint256 projectId
    ) external nonReentrant onlyOwner {
        require(
            projectId < projectCount,
            "EmergencyWithdraw:: Invalid project id"
        );
        ProjectInfo storage projectInfo = projectInfos[projectId];
        TransferHelper.safeTransfer(
            projectInfo.saleToken,
            msg.sender,
            projectInfo.totalSaleTokens
        );
        TransferHelper.safeTransfer(
            projectInfo.paymentToken,
            msg.sender,
            projectInfo.totalAmountMade
        );
        projectInfo.isSaleEnded = true;
        emit EmergencyWithdraw(projectId, msg.sender, chainId);
    }

    function updateProjectSaleEndTime(
        uint256 projectId,
        uint256 newEndTime
    ) external onlyOwner {
        require(
            projectId < projectCount,
            "UpdateProjectSaleEndTime:: Invalid project id"
        );
        PublicSaleInfo storage publicSaleInfo = publicSalesInfo[projectId];
        ProjectInfo storage projectInfo = projectInfos[projectId];
        require(!projectInfo.isSaleEnded, "Sale has ended");
        publicSaleInfo.endTime = newEndTime;
        emit PublicSaleEndTimeUpdated(projectId, newEndTime, chainId);
    }

    function setClaimStartedStatus(
        uint256 projectId,
        uint256 claimTime
    ) external onlyOwner {
        require(
            projectId < projectCount,
            "SetClaimStartedStatus:: Invalid project id"
        );

        ProjectInfo storage projectInfo = projectInfos[projectId];
        require(
            projectInfo.isSaleEnded,
            "SetClaimStartedStatus:: Sale not ended"
        );
        require(
            claimTime > block.timestamp,
            "Claim time must be in the future"
        );
        projectInfo.claimStartTime = claimTime;
        projectInfo.isClaimStarted = true;
        emit ClaimStarted(projectId, claimTime, chainId);
    }

    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid signer address");
        signer = _signer;
        emit SignerUpdated(_signer, chainId);
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee >= 0 && _fee <= 25, "Invalid fee");
        fee = _fee;
        emit FeeUpdated(_fee, chainId);
    }

    // --------------------------------------------------
    // External Functions
    // --------------------------------------------------

    function buy(
        uint256 projectId,
        uint256 amount,
        SaleType saleType,
        bytes memory signature,
        uint256 limit
    ) external whenNotPaused nonReentrant {
        require(projectId < projectCount, "Buy:: Invalid project id");
        require(amount > 0, "Buy:: Amount must be greater than zero");

        ProjectInfo storage projectInfo = projectInfos[projectId];
        uint256 amountBuying = amount *
            (10 ** IERC20(projectInfo.saleToken).decimals());
        uint256 amountPaying;

        require(
            projectInfo.totalSaleTokens >=
                projectInfo.totalTokensSold + amountBuying,
            "Buy:: Exceeds total sale tokens"
        );

        uint256 userTier = getUserTier(msg.sender);
        TiersInfo storage tierInfo = tiersInfos[projectId];

        // Handle different sale types and calculate amountPaying
        if (saleType == SaleType.GTD) {
            _handleGTDSale(projectId, userTier, amountBuying, tierInfo);
            amountPaying = amount * tierInfo.tokenPrice;
        } else if (saleType == SaleType.TIER) {
            _handleTierSale(projectId, userTier, amountBuying, tierInfo);
            amountPaying = amount * tierInfo.tokenPrice;
        } else if (saleType == SaleType.WHITELIST) {
            _handleWhitelistSale(
                projectId,
                limit,
                amountBuying,
                limit * (10 ** IERC20(projectInfo.saleToken).decimals()),
                signature
            );
            amountPaying = amount * tierInfo.tokenPrice;
        } else if (saleType == SaleType.PUBLIC) {
            PublicSaleInfo storage publicSaleInfo = publicSalesInfo[projectId];
            require(
                publicSaleInfo.startTime < block.timestamp &&
                    publicSaleInfo.endTime > block.timestamp,
                "Buy:: PUBLIC:: Too Early or Too Late"
            );
            amountPaying = amount * publicSaleInfo.tokenPrice;
        } else {
            revert("Buy:: Invalid sale type");
        }

        // Update state
        projectInfo.totalTokensSold += amountBuying;
        projectInfo.totalAmountMade += amountPaying;
        shares[projectId][msg.sender] += amountBuying;
        contributions[projectId][msg.sender] += amountPaying;

        // Transfer tokens
        TransferHelper.safeTransferFrom(
            projectInfo.paymentToken,
            msg.sender,
            address(this),
            amountPaying
        );

        bool isMinCap = isMinimumCapReached(projectId);
        if (isMinCap) {
            projectInfo.isReachedMinCap = true;
        }

        emit TokensPurchased(
            projectId,
            msg.sender,
            amountBuying,
            amountPaying,
            projectInfo.isReachedMinCap,
            projectInfo.totalTokensSold,
            projectInfo.totalAmountMade,
            chainId
        );
    }

    function _handleGTDSale(
        uint256 projectId,
        uint256 userTier,
        uint256 amountBuying,
        TiersInfo storage tierInfo
    ) private view {
        GTDInfo storage gtdInfo = gtdsInfos[projectId];
        require(
            gtdInfo.startTime < block.timestamp &&
                gtdInfo.endTime > block.timestamp,
            "Buy:: GTD:: Too Early or Too Late"
        );
        require(userTier >= 2, "Buy:: GTD:: Not eligible for GTD");
        require(
            shares[projectId][msg.sender] + amountBuying <=
                tierInfo.maxAllowed[userTier],
            "Buy:: GTD:: Exceeds tier purchase limit"
        );
    }

    function _handleTierSale(
        uint256 projectId,
        uint256 userTier,
        uint256 amountBuying,
        TiersInfo storage tierInfo
    ) private view {
        require(
            tierInfo.startTime < block.timestamp &&
                tierInfo.endTime > block.timestamp,
            "Buy:: TIER:: Too Early or Too Late"
        );
        require(userTier < 4, "Buy:: TIER:: Not eligible for any tier");
        require(
            shares[projectId][msg.sender] + amountBuying <=
                tierInfo.maxAllowed[userTier],
            "Buy:: TIER:: Exceeds tier purchase limit"
        );
    }

    function _handleWhitelistSale(
        uint256 projectId,
        uint256 amount,
        uint256 amountBuying,
        uint256 maxLimit,
        bytes memory signature
    ) private {
        require(
            tiersInfos[projectId].startTime < block.timestamp &&
                tiersInfos[projectId].endTime > block.timestamp,
            "Buy:: WHITELIST:: Too Early or Too Late"
        );

        if (getWhitelistAmount(projectId, msg.sender) == 0) {
            bytes32 messageHash = keccak256(
                abi.encodePacked(
                    msg.sender,
                    projectId,
                    amount,
                    chainId,
                    address(this)
                )
            );
            bytes32 ethSignedMessageHash = ECDSAUpgradeable
                .toEthSignedMessageHash(messageHash);
            address recoveredSigner = ECDSAUpgradeable.recover(
                ethSignedMessageHash,
                signature
            );
            require(
                recoveredSigner == signer,
                "Buy:: WHITELIST:: Invalid signature"
            );
            whitelistAmount[projectId][msg.sender] = maxLimit;
        } else {
            require(
                shares[projectId][msg.sender] + amountBuying <=
                    getWhitelistAmount(projectId, msg.sender),
                "Buy:: WHITELIST:: Exceeds whitelist purchase limit"
            );
        }
    }

    function claimRefund(uint256 projectId) external nonReentrant {
        require(projectId < projectCount, "ClaimRefund:: Invalid project id");
        ProjectInfo storage projectInfo = projectInfos[projectId];

        require(!projectInfo.isReachedMinCap, "ClaimRefund:: Min cap reached");
        require(projectInfo.isSaleEnded, "ClaimRefund:: Sale has not ended");
        uint256 amount = contributions[projectId][msg.sender];
        require(amount > 0, "ClaimRefund:: No contribution found");
        contributions[projectId][msg.sender] = 0;
        if (projectInfo.paymentToken == address(0)) {
            TransferHelper.safeTransferETH(msg.sender, amount);
        } else {
            TransferHelper.safeTransfer(
                projectInfo.paymentToken,
                msg.sender,
                amount
            );
        }
        emit RefundClaimed(projectId, msg.sender, amount, chainId);
    }

    function claimTokens(uint256 projectId) external nonReentrant {
        _validateClaimConditions(projectId);

        uint256 amount = shares[projectId][msg.sender];
        require(amount > 0, "ClaimTokens: No contribution found");

        VestingInfo storage vestingInfo = vestingsInfo[projectId];

        if (vestingInfo.isSet) {
            require(
                vestingSchedule[projectId][msg.sender].length == 0,
                "ClaimTokens: Vesting schedule already initialized"
            );
            _initializeUserVesting(projectId, msg.sender, amount);
            shares[projectId][msg.sender] = 0;
            uint256 totalClaimableAmount = _calculateTotalClaimableAmount(
                projectId,
                msg.sender
            );
            if (totalClaimableAmount > 0) {
                TransferHelper.safeTransfer(
                    projectInfos[projectId].saleToken,
                    msg.sender,
                    totalClaimableAmount
                );
                tokensClaimed[projectId][msg.sender] += totalClaimableAmount;
                emit TokensClaimed(
                    projectId,
                    msg.sender,
                    totalClaimableAmount,
                    chainId
                );
            }
        } else {
            TransferHelper.safeTransfer(
                projectInfos[projectId].saleToken,
                msg.sender,
                amount
            );
            shares[projectId][msg.sender] = 0;
            tokensClaimed[projectId][msg.sender] += amount;
            emit TokensClaimed(projectId, msg.sender, amount, chainId);
        }
    }

    function vestTokens(uint256 projectId) external nonReentrant {
        _validateClaimConditions(projectId);
        require(
            vestingSchedule[projectId][msg.sender].length > 0,
            "VestTokens: Vesting schedule not initialized"
        );
        uint256 totalClaimableAmount = _calculateTotalClaimableAmount(
            projectId,
            msg.sender
        );
        require(
            totalClaimableAmount > 0,
            "VestTokens: No tokens available for vest"
        );
        TransferHelper.safeTransfer(
            projectInfos[projectId].saleToken,
            msg.sender,
            totalClaimableAmount
        );

        tokensClaimed[projectId][msg.sender] += totalClaimableAmount;

        emit TokensClaimed(
            projectId,
            msg.sender,
            totalClaimableAmount,
            chainId
        );
    }

    // --------------------------------------------------
    // Internal Functions
    // --------------------------------------------------

    function _validatePublicSaleInfo(
        uint256 _publicSaleStartTime,
        uint256 _publicSaleEndTime,
        uint256 _tierTokenPrice,
        uint256[4] memory _tierMaxAllowed
    ) internal view {
        require(
            _publicSaleStartTime > block.timestamp,
            "Public sale start time must be in the future"
        );
        require(
            _publicSaleEndTime > _publicSaleStartTime,
            "Public sale end time must be after start time"
        );
        require(
            _tierTokenPrice == 0,
            "Tier token price must be zero in public sale"
        );
        for (uint256 i = 0; i < 4; i++) {
            require(
                _tierMaxAllowed[i] == 0,
                "Tier max allowed must be zero in public sale"
            );
        }
    }

    function _validateTierInfo(
        uint256[4] memory _tierMaxAllowed,
        uint256 _tierTokenPrice,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleEndTime,
        uint256 _tierSaleStartTime,
        uint256 _tierSaleEndTime,
        uint256 _gtdStartTime,
        uint256 _gtdEndTime
    ) internal view {
        require(_tierMaxAllowed.length == 4, "Invalid tier max allowed array");
        require(_tierTokenPrice > 0, "Tier token price cannot be zero");
        for (uint256 i = 0; i < 4; i++) {
            require(_tierMaxAllowed[i] > 0, "Tier max allowed cannot be zero");
        }

        require(
            _gtdStartTime > block.timestamp &&
                _gtdEndTime > _gtdStartTime &&
                _tierSaleStartTime > _gtdEndTime &&
                _tierSaleEndTime > _tierSaleStartTime &&
                _publicSaleStartTime > _tierSaleEndTime &&
                _publicSaleEndTime > _publicSaleStartTime,
            "Invalid sale times"
        );
    }

    function _distributeSuccessSale(uint256 projectId) internal {
        ProjectInfo storage projectInfo = projectInfos[projectId];
        uint256 paymentTokenBalance = projectInfo.totalAmountMade;
        uint256 feeAmount = (paymentTokenBalance * fee) / 100;
        uint256 projectOwnerBalance = paymentTokenBalance - feeAmount;

        TransferHelper.safeTransfer(
            projectInfo.paymentToken,
            owner(),
            feeAmount
        );
        TransferHelper.safeTransfer(
            projectInfo.paymentToken,
            projectInfo.projectOwner,
            projectOwnerBalance
        );

        uint256 unsoldTokens = getUnsoldTokens(projectId);
        if (unsoldTokens > 0) {
            TransferHelper.safeTransfer(
                projectInfo.saleToken,
                projectInfo.projectOwner,
                unsoldTokens
            );
        }
    }

    function _distributeFailedSale(uint256 projectId) internal {
        ProjectInfo storage projectInfo = projectInfos[projectId];
        TransferHelper.safeTransfer(
            projectInfo.saleToken,
            projectInfo.projectOwner,
            projectInfo.totalSaleTokens
        );
    }

    function _validateClaimConditions(uint256 projectId) internal view {
        require(projectId < projectCount, "Claim:: Invalid project id");
        ProjectInfo storage projectInfo = projectInfos[projectId];

        require(projectInfo.isReachedMinCap, "Claim:: Min cap not reached");
        require(projectInfo.isSaleEnded, "Claim:: Sale not ended yet");
        require(projectInfo.isClaimStarted, "Claim:: Claim not started yet");
        require(
            projectInfo.claimStartTime <= block.timestamp,
            "Claim:: Claim time not reached"
        );
    }

    function _initializeVestingIfNeeded(
        uint256 projectId,
        address user,
        uint256 amount
    ) internal {
        if (vestingSchedule[projectId][user].length == 0) {
            _initializeUserVesting(projectId, user, amount);
            // Contributions made to the project are now 0, as they are vested
            shares[projectId][user] = 0;
        }
    }

    function _calculateTotalClaimableAmount(
        uint256 projectId,
        address user
    ) internal returns (uint256) {
        uint256 totalClaimableAmount = 0;

        uint256[] storage claimTimes = vestingSchedule[projectId][user];
        uint256[] storage claimAmounts = vestingAmounts[projectId][user];
        bool[] storage claimedStatuses = vestingClaimed[projectId][user];

        for (uint256 i = 0; i < claimTimes.length; i++) {
            if (block.timestamp >= claimTimes[i] && !claimedStatuses[i]) {
                totalClaimableAmount += claimAmounts[i];
                claimedStatuses[i] = true; // Update claim status
            }
        }

        return totalClaimableAmount;
    }

    function _initializeUserVesting(
        uint256 projectId,
        address user,
        uint256 amount
    ) internal {
        VestingInfo storage vestingInfo = vestingsInfo[projectId];
        uint256[] memory percentages = vestingInfo.percentages;
        uint256[] memory intervals = vestingInfo.intervals;
        uint256 totalPercentage = 0;

        for (uint256 i = 0; i < intervals.length; i++) {
            totalPercentage += percentages[i];
            // Calculate the exact timestamp for this vesting interval
            uint256 claimTime = projectInfos[projectId].claimStartTime +
                intervals[i];
            vestingSchedule[projectId][user].push(claimTime);

            // Calculate the claimable amount for this interval
            uint256 claimAmount = (amount * percentages[i]) / 100;
            vestingAmounts[projectId][user].push(claimAmount);

            // Initialize claim status as false
            vestingClaimed[projectId][user].push(false);
        }
    }

    // --------------------------------------------------
    // View Functions
    // --------------------------------------------------

    function getUserTier(address user) public view returns (uint256) {
        uint256 stakedAmount = getStakedAmount(user);

        for (uint256 i = 4; i > 0; i--) {
            uint256 tierIndex = i - 1;
            if (stakedAmount >= requiredStakingPerTier[tierIndex]) {
                return tierIndex;
            }
        }

        return 4; // Not eligible for any tier
    }

    function getWhitelistAmount(
        uint256 projectId,
        address wallet
    ) public view returns (uint256) {
        return whitelistAmount[projectId][wallet];
    }

    function isMinimumCapReached(uint256 projectId) public view returns (bool) {
        ProjectInfo storage projectInfo = projectInfos[projectId];
        return projectInfo.totalTokensSold >= projectInfo.minCap;
    }

    function getStakedAmount(address user) public view returns (uint256) {
        return
            stakingContract == address(0)
                ? 0
                : IStakingRewards(stakingContract).balanceOf(user);
    }

    function getCurrentTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    function isSaleReadyToFinalize(
        uint256 projectId
    ) public view returns (bool) {
        if (projectId >= projectCount) {
            return false;
        }
        ProjectInfo storage projectInfo = projectInfos[projectId];
        PublicSaleInfo storage publicSaleInfo = publicSalesInfo[projectId];
        bool saleEndedTimeReached = block.timestamp >= publicSaleInfo.endTime;
        bool saleSoldOut = projectInfo.totalTokensSold >=
            projectInfo.totalSaleTokens;
        bool notFinalized = !projectInfo.isSaleEnded;
        return notFinalized && (saleEndedTimeReached || saleSoldOut);
    }

    function getRequiredStakeForTier(
        uint256 tier
    ) public view returns (uint256) {
        return requiredStakingPerTier[tier];
    }

    function getUserShareInfo(
        uint256 projectId,
        address user
    ) public view returns (uint256, uint256) {
        return (shares[projectId][user], contributions[projectId][user]);
    }

    function getTotalTokensSold(
        uint256 projectId
    ) public view returns (uint256) {
        ProjectInfo storage projectInfo = projectInfos[projectId];
        return projectInfo.totalTokensSold;
    }

    function getTotalAmountMade(
        uint256 projectId
    ) public view returns (uint256) {
        ProjectInfo storage projectInfo = projectInfos[projectId];
        return projectInfo.totalAmountMade;
    }

    function getRemainingAllowedToBuy(
        uint256 projectId,
        address user
    ) public view returns (uint256) {
        TiersInfo storage tierInfo = tiersInfos[projectId];
        uint256 tier = getUserTier(user);
        uint256 userShares = shares[projectId][user];
        if (tier == 4) {
            return getUnsoldTokens(projectId);
        } else {
            uint256 maxAllowed = tierInfo.maxAllowed[tier];
            if (userShares >= maxAllowed) {
                return 0;
            }
            return maxAllowed - userShares;
        }
    }

    function getUnsoldTokens(uint256 projectId) public view returns (uint256) {
        require(
            projectId < projectCount,
            "GetUnsoldTokens:: Invalid project id"
        );
        ProjectInfo storage projectInfo = projectInfos[projectId];
        return projectInfo.totalSaleTokens - projectInfo.totalTokensSold;
    }

    function maxAmountLeftToBuyForWhitelisted(
        uint256 projectId,
        address wallet
    ) external view returns (uint256) {
        uint256 maxLimit = getWhitelistAmount(projectId, wallet);
        uint256 amountBought = shares[projectId][wallet];
        if (amountBought >= maxLimit) {
            return 0;
        }
        return maxLimit - amountBought;
    }

    function finalizeSale(uint256 projectId) external onlySigner {
        require(projectId < projectCount, "FinalizeSale:: Invalid project id");

        ProjectInfo storage projectInfo = projectInfos[projectId];

        require(
            isSaleReadyToFinalize(projectId),
            "FinalizeSale:: Sale not finalized yet"
        );
        require(!projectInfo.isSaleEnded, "FinalizeSale:: Sale already ended");

        projectInfo.isSaleEnded = true;

        if (projectInfo.totalTokensSold >= projectInfo.minCap) {
            projectInfo.isReachedMinCap = true;
            emit SaleEnded(projectId, chainId);
            _distributeSuccessSale(projectId);
        } else {
            emit SaleEnded(projectId, chainId);
            _distributeFailedSale(projectId);
        }
    }
}
