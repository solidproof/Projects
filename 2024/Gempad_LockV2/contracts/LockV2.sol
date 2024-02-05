// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/ILockV2.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV3Factory.sol";
import "../interfaces/IUniswapV3Pair.sol";
import "../interfaces/INonfungiblePositionManager.sol";
import "./FullMath.sol";

contract LockV2 is
    ILockV2,
    IERC721Receiver,
    Initializable,
    OwnableUpgradeable
{
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    struct Fee {
        uint256 projectCreationFee;
        uint256 lpTokenNormalLockFee;
        uint256 lpTokenVestingLockFee;
        uint256 normalTokenNormalLockFee;
        uint256 normalTokenVestingLockFee;
    }

    struct Project {
        address owner;
        string metaData;
        EnumerableSet.AddressSet lpLockedTokens; //V3 pool addresses
    }

    struct Lock {
        uint256 id;
        address token; //if LP v3, it is a pool address
        address owner;
        uint256 amount;
        uint256 lockDate;
        uint256 tgeDate; // TGE date for vesting locks, unlock date for normal locks
        uint256 tgeBps; // In bips. Is 0 for normal locks
        uint256 cycle; // Is 0 for normal locks
        uint256 cycleBps; // In bips. Is 0 for normal locks
        uint256 unlockedAmount;
        string description;
        address nftManager;
        uint256 nftId;
    }

    struct CumulativeLockInfo {
        address projectToken;
        address factory;
        uint256 amount;
    }

    Fee public fee;
    Lock[] private _locks;
    mapping(address => EnumerableSet.UintSet) private _userLpLockIds;
    mapping(address => EnumerableSet.UintSet)
        private _userNormalLockIds;

    EnumerableSet.AddressSet private _lpLockedTokens; //if v3, pool addresses
    EnumerableSet.AddressSet private _normalLockedTokens;

    mapping(address => CumulativeLockInfo) public cumulativeLockInfo;
    mapping(address => EnumerableSet.UintSet)
        private _tokenToLockIds;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => Project) private projects;

    event LockAdded(
        uint256 indexed id,
        Lock lock,
        CumulativeLockInfo cumulativeLockInfo,
        address owner,
        string metaData,
        address referrer
    );
    event LockRemoved(
        uint256 indexed id,
        Lock lock,
        uint256 amount,
        uint256 unlockedAt
    );

    event LockUpdated(uint256 indexed id, Lock lock);

    event LockVested(
        uint256 indexed id,
        Lock lock,
        uint256 amount,
        uint256 timestamp
    );
    event LockDescriptionChanged(uint256 lockId, string description);
    event LockOwnerChanged(uint256 lockId, address owner, address newOwner);
    event LockProjectTokenMetaDataChanged(address token, string metaData);
    event ProjectOwnerChanged(address token, address owner, address newOwner);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    modifier validLock(uint256 lockId) {
        require(lockId < _locks.length, "Invalid lock ID");
        _;
    }

    function updateFee(
        uint256 projectCreationFee,
        uint256 lpTokenNormalLockFee,
        uint256 lpTokenVestingLockFee,
        uint256 normalTokenNormalLockFee,
        uint256 normalTokenVestingLockFee
    ) external onlyOwner {
        fee = Fee({
            projectCreationFee: projectCreationFee,
            lpTokenNormalLockFee: lpTokenNormalLockFee,
            lpTokenVestingLockFee: lpTokenVestingLockFee,
            normalTokenNormalLockFee: normalTokenNormalLockFee,
            normalTokenVestingLockFee: normalTokenVestingLockFee
        });
    }

    function excludeFromFee(
        address account,
        bool isExcluded
    ) external onlyOwner {
        isExcludedFromFee[account] = isExcluded;
    }

    function multipleLock(
        address[] calldata owners,
        address token,
        bool isLpToken,
        uint256[] calldata amounts,
        uint256 unlockDate,
        string memory description,
        string memory _metaData,
        address projectToken,
        address referrer
    ) external payable override returns (uint256[] memory) {
        {
            if (!isExcludedFromFee[_msgSender()]) {
                uint256 _fee = isLpToken
                    ? fee.lpTokenNormalLockFee
                    : fee.normalTokenNormalLockFee;
                if (projects[projectToken].owner == address(0)) {
                    _fee += fee.projectCreationFee;
                }
                require(msg.value >= _fee, "Not enough funds for fees");
                (bool sent, ) = payable(owner()).call{value: _fee}("");
                require(sent, "Failed to charge fee");
            }
            require(owners.length == amounts.length, "Length mismatch");
            require(
                unlockDate > block.timestamp,
                "Unlock date needs to be set to future date"
            );
        }
        return
            _multipleLock(
                owners,
                amounts,
                token,
                isLpToken,
                [unlockDate, 0, 0, 0],
                description,
                _metaData,
                projectToken,
                referrer
            );
    }

    function multipleVestingLock(
        address[] calldata owners,
        uint256[] calldata amounts,
        address token,
        bool isLpToken,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description,
        string memory _metaData,
        address projectToken,
        address referrer
    ) external payable override returns (uint256[] memory) {
        if (!isExcludedFromFee[_msgSender()]) {
            uint256 _fee = isLpToken
                ? fee.lpTokenVestingLockFee
                : fee.normalTokenVestingLockFee;
            if (projects[projectToken].owner == address(0)) {
                _fee += fee.projectCreationFee;
            }
            require(msg.value >= _fee, "Not enough funds for fees");
            (bool sent, ) = payable(owner()).call{value: _fee}("");
            require(sent, "Failed to charge fee");
        }
        {
            require(token != address(0), "Invalid token");
            require(cycle > 0, "Invalid cycle");
            require(tgeBps > 0 && tgeBps < 1000000, "Invalid bips for TGE");
            require(
                cycleBps > 0 && cycleBps < 1000000,
                "Invalid bips for cycle"
            );
            require(
                tgeBps + cycleBps <= 1000000,
                "Sum of TGE bps and cycle should be less than 10000"
            );
        }
        return
            _multipleLock(
                owners,
                amounts,
                token,
                isLpToken,
                [tgeDate, tgeBps, cycle, cycleBps],
                description,
                _metaData,
                projectToken,
                referrer
            );
    }

    function lockLpV3(
        address _owner,
        address nftManager,
        uint256 nftId,
        uint256 unlockDate,
        string memory description,
        string memory _metaData,
        address projectToken,
        address referrer
    ) external payable override returns (uint256 id) {
        {
            if (!isExcludedFromFee[_msgSender()]) {
                uint256 _fee = fee.lpTokenNormalLockFee;
                if (projects[projectToken].owner == address(0)) {
                    _fee += fee.projectCreationFee;
                }
                require(msg.value >= _fee, "Not enough funds for fees");
                (bool sent, ) = payable(owner()).call{value: _fee}("");
                require(sent, "Failed to charge fee");
            }
            require(nftManager != address(0), "Invalid V3 LP manager");
            require(
                unlockDate > block.timestamp,
                "Unlock date should be in the future"
            );
        }

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee_,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(nftManager).positions(nftId);
        require(
            projectToken == token0 || projectToken == token1,
            "Invalid project token"
        );
        address factory = INonfungiblePositionManager(nftManager).factory();
        address token = IUniswapV3Factory(factory).getPool(
            token0,
            token1,
            fee_
        );
        require(factory != address(0) && token != address(0), "Invalid V3 LP");
        id = _locks.length;
        Lock memory newLock = Lock({
            id: id,
            token: token,
            owner: _owner,
            amount: liquidity,
            lockDate: block.timestamp,
            tgeDate: unlockDate,
            tgeBps: 1000000,
            cycle: 0,
            cycleBps: 0,
            unlockedAmount: 0,
            description: description,
            nftManager: nftManager,
            nftId: nftId
        });
        _locks.push(newLock);
        _userLpLockIds[_owner].add(id);
        _lpLockedTokens.add(token);

        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[token];
        if (tokenInfo.projectToken == address(0)) {
            tokenInfo.projectToken = projectToken;
            tokenInfo.factory = factory;
        } else {
            projectToken = tokenInfo.projectToken;
        }
        tokenInfo.amount = tokenInfo.amount + liquidity;

        _tokenToLockIds[token].add(id);
        Project storage project = projects[projectToken];
        if (project.owner == address(0)) {
            project.owner = msg.sender;
            project.metaData = _metaData;
        }
        project.lpLockedTokens.add(token);

        INonfungiblePositionManager(nftManager).safeTransferFrom(
            msg.sender,
            address(this),
            nftId
        );

        emit LockAdded(
            id,
            _locks[id],
            tokenInfo,
            projects[projectToken].owner,
            projects[projectToken].metaData,
            referrer
        );
        return id;
    }

    function _multipleLock(
        address[] calldata owners,
        uint256[] calldata amounts,
        address token,
        bool isLpToken,
        uint256[4] memory vestingSettings, // avoid stack too deep
        string memory description,
        string memory _metaData,
        address projectToken,
        address referrer
    ) internal returns (uint256[] memory) {
        {
            require(owners.length == amounts.length, "Length mismatch");
            require(
                vestingSettings[0] > block.timestamp,
                "TGE date should be set in the future"
            );
            require(token != address(0), "Invalid token");
        }
        {
            uint256 sumAmount = _sumAmount(amounts);
            _safeTransferFromEnsureExactAmount(
                token,
                msg.sender,
                address(this),
                sumAmount
            );
        }
        uint256 count = owners.length;
        uint256[] memory ids = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            ids[i] = _createLock(
                owners[i],
                token,
                isLpToken,
                amounts[i],
                vestingSettings[0], // TGE date
                vestingSettings[1], // TGE bps
                vestingSettings[2], // cycle
                vestingSettings[3], // cycle bps
                description,
                _metaData,
                projectToken
            );
            emit LockAdded(
                ids[i],
                _locks[ids[i]],
                cumulativeLockInfo[token],
                projects[projectToken].owner,
                projects[projectToken].metaData,
                referrer
            );
        }

        return ids;
    }

    function _sumAmount(
        uint256[] calldata amounts
    ) internal pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) {
                revert("The amount cannot be zero");
            }
            sum += amounts[i];
        }
        return sum;
    }

    function _createLock(
        address owner,
        address token,
        bool isLpToken,
        uint256 amount,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description,
        string memory _metaData,
        address projectToken
    ) internal returns (uint256 id) {
        if (isLpToken) {
            address possibleFactoryAddress = _parseFactoryAddress(
                token,
                projectToken
            );
            id = _lockLpToken(
                owner,
                token,
                possibleFactoryAddress,
                amount,
                tgeDate,
                tgeBps,
                cycle,
                cycleBps,
                description,
                _metaData,
                projectToken
            );
        } else {
            require(token == projectToken, "This token is not the project token");
            id = _lockNormalToken(
                owner,
                token,
                amount,
                tgeDate,
                tgeBps,
                cycle,
                cycleBps,
                description,
                _metaData
            );
        }
        return id;
    }

    function _lockLpToken(
        address owner,
        address token,
        address factory,
        uint256 amount,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description,
        string memory _metaData,
        address projectToken
    ) private returns (uint256 id) {
        id = _registerLock(
            owner,
            token,
            amount,
            tgeDate,
            tgeBps,
            cycle,
            cycleBps,
            description
        );
        _userLpLockIds[owner].add(id);
        _lpLockedTokens.add(token);

        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[token];
        if (tokenInfo.projectToken == address(0)) {
            tokenInfo.projectToken = projectToken;
            tokenInfo.factory = factory;
        } else {
            projectToken = tokenInfo.projectToken;
        }
        tokenInfo.amount = tokenInfo.amount + amount;
        _tokenToLockIds[token].add(id);
        Project storage project = projects[projectToken];
        if (project.owner == address(0)) {
            project.owner = msg.sender;
            project.metaData = _metaData;
        }
        project.lpLockedTokens.add(token);
    }

    function _lockNormalToken(
        address owner,
        address token,
        uint256 amount,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description,
        string memory _metaData
    ) private returns (uint256 id) {
        id = _registerLock(
            owner,
            token,
            amount,
            tgeDate,
            tgeBps,
            cycle,
            cycleBps,
            description
        );
        _userNormalLockIds[owner].add(id);
        _normalLockedTokens.add(token);

        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[token];
        if (tokenInfo.projectToken == address(0)) {
            tokenInfo.projectToken = token;
            tokenInfo.factory = address(0);
        }
        tokenInfo.amount = tokenInfo.amount + amount;

        _tokenToLockIds[token].add(id);

        Project storage project = projects[token];
        if (project.owner == address(0)) {
            project.owner = msg.sender;
            project.metaData = _metaData;
        }
    }

    function _registerLock(
        address owner,
        address token,
        uint256 amount,
        uint256 tgeDate,
        uint256 tgeBps,
        uint256 cycle,
        uint256 cycleBps,
        string memory description
    ) private returns (uint256 id) {
        id = _locks.length;
        Lock memory newLock = Lock({
            id: id,
            token: token,
            owner: owner,
            amount: amount,
            lockDate: block.timestamp,
            tgeDate: tgeDate,
            tgeBps: tgeBps,
            cycle: cycle,
            cycleBps: cycleBps,
            unlockedAmount: 0,
            description: description,
            nftManager: address(0),
            nftId: 0
        });
        _locks.push(newLock);
    }

    function unlock(uint256 lockId) external override validLock(lockId) {
        Lock storage userLock = _locks[lockId];
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );

        if (userLock.tgeBps > 0) {
            _vestingUnlock(userLock, false);
        } else {
            _normalUnlock(userLock, false);
        }
    }

    function unlockAllAvailable() external {
        uint256 length = _userLpLockIds[msg.sender].length();
        for (uint256 i = 0; i < length; i++) {
            Lock storage userLock = _locks[_userLpLockIds[msg.sender].at(i)];
            if (userLock.tgeBps > 0) {
                _vestingUnlock(userLock, true);
            } else {
                _normalUnlock(userLock, true);
            }
        }
        length = _userNormalLockIds[msg.sender].length();
        for (uint256 i = 0; i < length; i++) {
            Lock storage userLock = _locks[
                _userNormalLockIds[msg.sender].at(i)
            ];
            if (userLock.tgeBps > 0) {
                _vestingUnlock(userLock, true);
            } else {
                _normalUnlock(userLock, true);
            }
        }
    }

    function _normalUnlock(Lock storage userLock, bool _noRevert) internal {
        if (_noRevert) {
            if (!(block.timestamp >= userLock.tgeDate)) return;
            if (!(userLock.unlockedAmount == 0)) return;
        } else {
            require(
                block.timestamp >= userLock.tgeDate,
                "The lock is not unlocked yet"
            );
            require(userLock.unlockedAmount == 0, "Nothing to unlock");
        }
        uint256 unlockAmount = userLock.amount;
        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
            userLock.token
        ];
        bool isLpToken = tokenInfo.factory != address(0);
        if (isLpToken) {
            _userLpLockIds[msg.sender].remove(userLock.id);
        } else {
            _userNormalLockIds[msg.sender].remove(userLock.id);
        }
        if (tokenInfo.amount <= unlockAmount) {
            tokenInfo.amount = 0;
        } else {
            tokenInfo.amount = tokenInfo.amount - unlockAmount;
        }
        if (tokenInfo.amount == 0) {
            if (isLpToken) {
                _lpLockedTokens.remove(userLock.token);
                projects[tokenInfo.projectToken].lpLockedTokens.remove(
                    userLock.token
                );
            } else {
                _normalLockedTokens.remove(userLock.token);
            }
        }
        _tokenToLockIds[userLock.token].remove(userLock.id);
        if (userLock.nftManager != address(0)) {
            INonfungiblePositionManager(userLock.nftManager).safeTransferFrom(
                address(this),
                msg.sender,
                userLock.nftId
            );
        } else {
            IERC20(userLock.token).safeTransfer(
                msg.sender,
                unlockAmount
            );
        }
        userLock.unlockedAmount = unlockAmount;

        emit LockRemoved(userLock.id, userLock, unlockAmount, block.timestamp);
    }

    function _vestingUnlock(Lock storage userLock, bool _noRevert) internal {
        uint256 withdrawable = _withdrawableTokens(userLock);
        uint256 newTotalUnlockAmount = userLock.unlockedAmount + withdrawable;
        if (_noRevert) {
            if (!(withdrawable > 0 && newTotalUnlockAmount <= userLock.amount))
                return;
        } else
            require(
                withdrawable > 0 && newTotalUnlockAmount <= userLock.amount,
                "Nothing to unlock"
            );

        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
            userLock.token
        ];
        bool isLpToken = tokenInfo.factory != address(0);

        if (tokenInfo.amount <= withdrawable) {
            tokenInfo.amount = 0;
        } else {
            tokenInfo.amount = tokenInfo.amount - withdrawable;
        }

        if (tokenInfo.amount == 0) {
            if (isLpToken) {
                _lpLockedTokens.remove(userLock.token);
                projects[tokenInfo.projectToken].lpLockedTokens.remove(
                    userLock.token
                );
            } else {
                _normalLockedTokens.remove(userLock.token);
            }
        }
        userLock.unlockedAmount = newTotalUnlockAmount;

        IERC20(userLock.token).safeTransfer(
            userLock.owner,
            withdrawable
        );
        emit LockVested(userLock.id, userLock, withdrawable, block.timestamp);
        if (newTotalUnlockAmount == userLock.amount) {
            if (isLpToken) {
                _userLpLockIds[msg.sender].remove(userLock.id);
            } else {
                _userNormalLockIds[msg.sender].remove(userLock.id);
            }
            _tokenToLockIds[userLock.token].remove(userLock.id);
            emit LockRemoved(
                userLock.id,
                userLock,
                newTotalUnlockAmount,
                block.timestamp
            );
        }
    }

    function withdrawableTokens(
        uint256 lockId
    ) external view returns (uint256) {
        Lock memory userLock = getLockAt(lockId);
        return _withdrawableTokens(userLock);
    }

    function _withdrawableTokens(
        Lock memory userLock
    ) internal view returns (uint256) {
        if (userLock.amount == 0) return 0;
        if (userLock.unlockedAmount >= userLock.amount) return 0;
        if (block.timestamp < userLock.tgeDate) return 0;
        if (userLock.cycle == 0) return 0;

        uint256 tgeReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.tgeBps,
            1000000
        );
        uint256 cycleReleaseAmount = FullMath.mulDiv(
            userLock.amount,
            userLock.cycleBps,
            1000000
        );
        uint256 currentTotal = 0;
        if (block.timestamp >= userLock.tgeDate) {
            currentTotal =
                (((block.timestamp - userLock.tgeDate) / userLock.cycle) *
                    cycleReleaseAmount) +
                tgeReleaseAmount; // Truncation is expected here
        }
        uint256 withdrawable = 0;
        if (currentTotal > userLock.amount) {
            withdrawable = userLock.amount - userLock.unlockedAmount;
        } else {
            withdrawable = currentTotal - userLock.unlockedAmount;
        }
        return withdrawable;
    }

    function editLock(
        uint256 lockId,
        uint256 additionalAmount,
        uint256 newUnlockDate
    ) external override validLock(lockId) {
        Lock storage userLock = _locks[lockId];
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );
        require(userLock.unlockedAmount == 0, "Lock was unlocked");

        if (newUnlockDate > 0) {
            require(
                newUnlockDate >= userLock.tgeDate &&
                    newUnlockDate > block.timestamp,
                "New unlock time needs to be after current and old lock time"
            );
            userLock.tgeDate = newUnlockDate;
        }
        if (userLock.nftManager == address(0)) {
            if (additionalAmount > 0) {
                userLock.amount += additionalAmount;
                CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
                    userLock.token
                ];
                tokenInfo.amount = tokenInfo.amount + additionalAmount;
                _safeTransferFromEnsureExactAmount(
                    userLock.token,
                    msg.sender,
                    address(this),
                    additionalAmount
                );
            }
        }

        emit LockUpdated(userLock.id, userLock);
    }

    function increaseLiquidityCurrentRange(
        uint256 lockId,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        Lock storage userLock = _locks[lockId];
        require(userLock.nftManager != address(0), "No V3 LP lock");
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );
        require(userLock.unlockedAmount == 0, "Lock was unlocked");
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(userLock.nftManager).positions(
                userLock.nftId
            );
        _safeTransferFromEnsureExactAmount(
            token0,
            msg.sender,
            address(this),
            amount0ToAdd
        );
        _safeTransferFromEnsureExactAmount(
            token1,
            msg.sender,
            address(this),
            amount1ToAdd
        );

        IERC20(token0).forceApprove(
            address(userLock.nftManager),
            amount0ToAdd
        );
        IERC20(token1).forceApprove(
            address(userLock.nftManager),
            amount1ToAdd
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: userLock.nftId,
                    amount0Desired: amount0ToAdd,
                    amount1Desired: amount1ToAdd,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = INonfungiblePositionManager(
            userLock.nftManager
        ).increaseLiquidity(params);
        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
            userLock.token
        ];
        tokenInfo.amount += liquidity;
        userLock.amount += liquidity;
        emit LockUpdated(userLock.id, userLock);
    }

    function decreaseLiquidityCurrentRange(
        uint256 lockId,
        uint128 liquidity
    ) external returns (uint256 amount0, uint256 amount1) {
        Lock storage userLock = _locks[lockId];
        require(userLock.nftManager != address(0), "No V3 LP lock");
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );
        require(
            block.timestamp >= userLock.tgeDate,
            "Not unlocked yet"
        );
        require(userLock.amount >= liquidity);
        require(userLock.unlockedAmount == 0, "Lock was unlocked");
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(userLock.nftManager).positions(
                userLock.nftId
            );
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: userLock.nftId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = INonfungiblePositionManager(userLock.nftManager)
            .decreaseLiquidity(params);
        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);
        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
            userLock.token
        ];
        if (tokenInfo.amount > liquidity) {
            tokenInfo.amount -= liquidity;
        } else {
            tokenInfo.amount = 0;
            _lpLockedTokens.remove(userLock.token);
            projects[tokenInfo.projectToken].lpLockedTokens.remove(
                userLock.token
            );
        }
        userLock.amount -= liquidity;
        emit LockUpdated(userLock.id, userLock);
    }

    function collectFees(
        uint256 lockId
    ) external returns (uint256 amount0, uint256 amount1) {
        Lock storage userLock = _locks[lockId];
        require(userLock.nftManager != address(0), "No V3 LP lock");
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );
        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: userLock.nftId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = INonfungiblePositionManager(userLock.nftManager)
            .collect(params);

        // send collected feed back to owner
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(userLock.nftManager).positions(
                userLock.nftId
            );
        IERC20(token0).safeTransfer(userLock.owner, amount0);
        IERC20(token1).safeTransfer(userLock.owner, amount1);
    }

    function editLockDescription(
        uint256 lockId,
        string memory description
    ) external validLock(lockId) {
        Lock storage userLock = _locks[lockId];
        require(
            userLock.owner == msg.sender,
            "You are not the owner of this lock"
        );
        userLock.description = description;
        emit LockDescriptionChanged(lockId, description);
    }

    function editProjectTokenMetaData(
        address token,
        string memory _metaData
    ) external {
        require(
            projects[token].owner == msg.sender,
            "You are not the owner of this project"
        );
        projects[token].metaData = _metaData;
        emit LockProjectTokenMetaDataChanged(token, _metaData);
    }

    function transferProjectOwnerShip(address token, address newOwner) public {
        require(
            projects[token].owner == msg.sender,
            "You are not the owner of this project"
        );
        projects[token].owner = newOwner;
        emit ProjectOwnerChanged(token, msg.sender, newOwner);
    }

    function transferLockOwnership(
        uint256 lockId,
        address newOwner
    ) public validLock(lockId) {
        Lock storage userLock = _locks[lockId];
        address currentOwner = userLock.owner;
        require(
            currentOwner == msg.sender,
            "You are not the owner of this lock"
        );

        userLock.owner = newOwner;
        CumulativeLockInfo storage tokenInfo = cumulativeLockInfo[
            userLock.token
        ];

        bool isLpToken = tokenInfo.factory != address(0);

        if (isLpToken) {
            _userLpLockIds[currentOwner].remove(lockId);
            _userLpLockIds[newOwner].add(lockId);
        } else {
            _userNormalLockIds[currentOwner].remove(lockId);
            _userNormalLockIds[newOwner].add(lockId);
        }

        emit LockOwnerChanged(lockId, currentOwner, newOwner);
    }

    function _safeTransferFromEnsureExactAmount(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 oldRecipientBalance = IERC20(token).balanceOf(
            recipient
        );
        IERC20(token).safeTransferFrom(sender, recipient, amount);
        uint256 newRecipientBalance = IERC20(token).balanceOf(
            recipient
        );
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token transferred"
        );
    }

    function getTotalLockCount() external view returns (uint256) {
        // Returns total lock count, regardless of whether it has been unlocked or not
        return _locks.length;
    }

    function getLockAt(uint256 index) public view returns (Lock memory) {
        return _locks[index];
    }

    function allLpTokenLockedCount() public view returns (uint256) {
        return _lpLockedTokens.length();
    }

    function allNormalTokenLockedCount() public view returns (uint256) {
        return _normalLockedTokens.length();
    }

    function getCumulativeLpTokenLockInfoAt(
        uint256 index
    ) external view returns (CumulativeLockInfo memory) {
        return cumulativeLockInfo[_lpLockedTokens.at(index)];
    }

    function getCumulativeNormalTokenLockInfoAt(
        uint256 index
    ) external view returns (CumulativeLockInfo memory) {
        return cumulativeLockInfo[_normalLockedTokens.at(index)];
    }

    function lpLockCountForUser(address user) public view returns (uint256) {
        return _userLpLockIds[user].length();
    }

    function lpLockForUserAtIndex(
        address user,
        uint256 index
    ) external view returns (Lock memory) {
        require(lpLockCountForUser(user) > index, "Invalid index");
        return getLockAt(_userLpLockIds[user].at(index));
    }

    function normalLockCountForUser(
        address user
    ) public view returns (uint256) {
        return _userNormalLockIds[user].length();
    }

    function normalLockForUserAtIndex(
        address user,
        uint256 index
    ) external view returns (Lock memory) {
        require(normalLockCountForUser(user) > index, "Invalid index");
        return getLockAt(_userNormalLockIds[user].at(index));
    }

    function totalLockCountForToken(
        address token
    ) external view returns (uint256) {
        return _tokenToLockIds[token].length();
    }

    function getLocksForToken(
        address token,
        uint256 start,
        uint256 end
    ) public view returns (Lock[] memory) {
        if (end >= _tokenToLockIds[token].length()) {
            end = _tokenToLockIds[token].length() - 1;
        }
        uint256 length = end - start + 1;
        Lock[] memory locks = new Lock[](length);
        uint256 currentIndex = 0;
        for (uint256 i = start; i <= end; i++) {
            locks[currentIndex] = getLockAt(_tokenToLockIds[token].at(i));
            currentIndex++;
        }
        return locks;
    }

    function _parseFactoryAddress(
        address token,
        address projectToken
    ) internal view returns (address) {
        address possibleFactoryAddress;
        try IUniswapV2Pair(token).factory() returns (address factory) {
            possibleFactoryAddress = factory;
        } catch {
            revert("This is not a LP token");
        }
        require(
            possibleFactoryAddress != address(0) &&
                _isValidLpToken(token, possibleFactoryAddress, projectToken),
            "This is not a LP token."
        );
        return possibleFactoryAddress;
    }

    function _isValidLpToken(
        address token,
        address factory,
        address projectToken
    ) private view returns (bool) {
        IUniswapV2Pair pair = IUniswapV2Pair(token);
        if (projectToken != pair.token0() && projectToken != pair.token1())
            return false;
        address factoryPair = IUniswapV2Factory(factory).getPair(
            pair.token0(),
            pair.token1()
        );
        return factoryPair == token;
    }

    function getProject(
        address _projectToken
    )
        external
        view
        returns (
            address owner,
            string memory metaData,
            address[] memory lpLockedTokens
        )
    {
        Project storage project = projects[_projectToken];
        owner = project.owner;
        metaData = project.metaData;
        lpLockedTokens = project.lpLockedTokens.values();
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}