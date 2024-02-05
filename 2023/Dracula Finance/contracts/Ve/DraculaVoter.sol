// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IVe.sol";
import "../interface/IVoter.sol";
import "../interface/IERC20.sol";
import "../interface/IERC721.sol";
import "../interface/IGauge.sol";
import "../interface/IFactory.sol";
import "../interface/IPair.sol";
import "../interface/IBribeFactory.sol";
import "../interface/IGaugeFactory.sol";
import "../interface/IMinter.sol";
import "../interface/IBribe.sol";
import "../interface/IBribeBond.sol";
import "../interface/IMultiRewardsPool.sol";
import "../Reentrancy.sol";
import "../lib/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DraculaVoter is IVoter, Reentrancy, Ownable {
    using SafeERC20 for IERC20;

    bool public isLocked;

    /// @dev The ve token that governs these contracts
    address public immutable override ve;
    /// @dev DraculaFactory
    address public immutable factory;
    address public immutable token;
    address public immutable gaugeFactory;
    address public immutable bribeFactory;
    /// @dev Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;
    /// @dev Delay period for votes. 6 days for keep compatibility.
    uint256 internal constant VOTE_DELAY = 6 days;

    uint256 internal constant PRECISION = 1 * 10 ** 9;
    uint256 internal constant WEEK = 86400 * 7;
    uint256 internal constant FOUR_HOURS = 3600 * 4;

    address public minter;

    IBribeBond public bribeBond;

    /// @dev Total voting weight
    uint256 public totalWeight;

    uint256 public cursor = 0;

    uint256 public chunkForSnapshot = 20;

    SnapshotGauges internal snapshotGauges;

    /// @dev All pools viable for incentives
    address[] public pools;

    /// @dev pool => gauge
    mapping(address => address) public gauges;
    /// @dev gauge => pool
    mapping(address => address) public poolForGauge;
    /// @dev gauge => bribe
    mapping(address => address) public bribes;
    /// @dev pool => weight
    mapping(address => int256) public weights;
    /// @dev nft => pool => votes
    mapping(uint256 => mapping(address => int256)) public votes;
    /// @dev nft => pools
    mapping(uint256 => address[]) public poolVote;
    /// @dev nft => total voting weight of user
    mapping(uint256 => uint256) public usedWeights;
    mapping(address => bool) public isGauge;
    mapping(address => bool) public isWhitelisted;

    uint256 public index;
    mapping(address => uint256) public supplyIndex;
    mapping(address => uint256) public claimable;
    mapping(uint256 => uint256) public lastVote;

    /// @dev activePeriod => isSnapshot
    mapping(uint256 => bool) public isSnapshot;

    /// @dev tokenId => pool => isGaugeClaimed
    mapping(uint256 => mapping(address => bool)) internal isGaugeClaimed;

    event GaugeCreated(
        address indexed gauge,
        address creator,
        address indexed bribe,
        address indexed pool
    );
    event Voted(address indexed voter, uint256 tokenId, int256 weight);
    event Abstained(uint256 tokenId, int256 weight);
    event Deposit(
        address indexed lp,
        address indexed gauge,
        uint256 tokenId,
        uint256 amount
    );
    event Withdraw(
        address indexed lp,
        address indexed gauge,
        uint256 tokenId,
        uint256 amount
    );
    event NotifyReward(
        address indexed sender,
        address indexed reward,
        uint256 amount
    );
    event DistributeReward(
        address indexed sender,
        address indexed gauge,
        uint256 amount
    );
    event Attach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Detach(address indexed owner, address indexed gauge, uint256 tokenId);
    event Whitelisted(address indexed whitelister, address indexed token);

    struct GaugeReward {
        address gauge;
        uint256 reward;
    }

    struct GaugeInfo {
        uint256 reward;
        uint256 weight;
    }

    struct SnapshotGauges {
        uint256 totalGaugeWeight;
        uint256 nbOfGauges;
        uint256 totalBondRewards;
        mapping(address => GaugeInfo) gaugesInfo;
    }

    constructor(
        address _ve,
        address _factory,
        address _gaugeFactory,
        address _bribeFactory
    ) {
        ve = _ve;
        factory = _factory;
        token = IVe(_ve).token();
        gaugeFactory = _gaugeFactory;
        bribeFactory = _bribeFactory;
        minter = msg.sender;
    }

    function initialize(address[] memory _tokens, address _minter) external {
        require(msg.sender == minter, "!minter");
        for (uint256 i = 0; i < _tokens.length; i++) {
            _whitelist(_tokens[i]);
        }
        minter = _minter;
    }

    /// @dev Amount of tokens required to be hold for whitelisting.
    function listingFee() external view returns (uint256) {
        return _listingFee();
    }

    /// @dev 0.5% of circulation supply.
    function _listingFee() internal view returns (uint256) {
        return (IERC20(token).totalSupply() - IERC20(ve).totalSupply()) / 200;
    }

    /// @dev Remove all votes for given tokenId.
    function reset(uint256 _tokenId) external {
        require(IVe(ve).isApprovedOrOwner(msg.sender, _tokenId), "!owner");
        _reset(_tokenId);
        IVe(ve).abstain(_tokenId);
    }

    function _reset(uint256 _tokenId) internal {
        address[] storage _poolVote = poolVote[_tokenId];
        uint256 _poolVoteCnt = _poolVote.length;
        int256 _totalWeight = 0;

        for (uint256 i = 0; i < _poolVoteCnt; i++) {
            address _pool = _poolVote[i];
            int256 _votes = votes[_tokenId][_pool];
            _updateFor(gauges[_pool]);
            weights[_pool] -= _votes;
            votes[_tokenId][_pool] -= _votes;
            delete isGaugeClaimed[_tokenId][_pool];
            if (_votes > 0) {
                IBribe(bribes[gauges[_pool]])._withdraw(
                    uint256(_votes),
                    _tokenId
                );
                _totalWeight += _votes;
            } else {
                _totalWeight -= _votes;
            }
            emit Abstained(_tokenId, _votes);
        }
        totalWeight -= uint256(_totalWeight);
        usedWeights[_tokenId] = 0;
        delete poolVote[_tokenId];
    }

    /// @dev Resubmit exist votes for given token. For internal purposes.
    function poke(uint256 _tokenId) external {
        require(IVe(ve).isApprovedOrOwner(msg.sender, _tokenId), "!owner");
        address[] memory _poolVote = poolVote[_tokenId];
        uint256 _poolCnt = _poolVote.length;
        int256[] memory _weights = new int256[](_poolCnt);

        for (uint256 i = 0; i < _poolCnt; i++) {
            _weights[i] = votes[_tokenId][_poolVote[i]];
        }

        _vote(_tokenId, _poolVote, _weights);
        lastVote[_tokenId] = block.timestamp;
    }

    function _vote(
        uint256 _tokenId,
        address[] memory _poolVote,
        int256[] memory _weights
    ) internal {
        _reset(_tokenId);
        uint256 _poolCnt = _poolVote.length;
        int256 _weight = int256(IVe(ve).balanceOfNFT(_tokenId));
        int256 _totalVoteWeight = 0;
        int256 _totalWeight = 0;
        int256 _usedWeight = 0;

        for (uint256 i = 0; i < _poolCnt; i++) {
            _totalVoteWeight += _weights[i] > 0 ? _weights[i] : -_weights[i];
        }

        for (uint256 i = 0; i < _poolCnt; i++) {
            address _pool = _poolVote[i];
            address _gauge = gauges[_pool];

            int256 _poolWeight = (_weights[i] * _weight) / _totalVoteWeight;
            require(votes[_tokenId][_pool] == 0, "duplicate pool");
            require(_poolWeight != 0, "zero power");
            _updateFor(_gauge);

            poolVote[_tokenId].push(_pool);

            weights[_pool] += _poolWeight;
            votes[_tokenId][_pool] += _poolWeight;
            if (_poolWeight > 0) {
                IBribe(bribes[_gauge])._deposit(uint256(_poolWeight), _tokenId);
            } else {
                _poolWeight = -_poolWeight;
            }
            _usedWeight += _poolWeight;
            _totalWeight += _poolWeight;
            emit Voted(msg.sender, _tokenId, _poolWeight);
        }
        if (_usedWeight > 0) IVe(ve).voting(_tokenId);
        totalWeight += uint256(_totalWeight);
        usedWeights[_tokenId] = uint256(_usedWeight);
    }

    /// @dev Vote for given pools using a vote power of given tokenId. Reset previous votes.
    function vote(
        uint256 tokenId,
        address[] calldata _poolVote,
        int256[] calldata _weights
    ) external {
        require(IVe(ve).isApprovedOrOwner(msg.sender, tokenId), "!owner");
        require(_poolVote.length == _weights.length, "!arrays");
        require(lastVote[tokenId] + VOTE_DELAY < block.timestamp, "delay");
        _vote(tokenId, _poolVote, _weights);
        lastVote[tokenId] = block.timestamp;
    }

    /// @dev Add token to whitelist. Only pools with whitelisted tokens can be added to gauge.
    function whitelist(address _token, uint256 _tokenId) external {
        require(_tokenId > 0, "!token");
        require(msg.sender == IERC721(ve).ownerOf(_tokenId), "!owner");
        require(IVe(ve).balanceOfNFT(_tokenId) > _listingFee(), "!power");
        _whitelist(_token);
    }

    function _whitelist(address _token) internal {
        require(!isWhitelisted[_token], "already whitelisted");
        isWhitelisted[_token] = true;
        emit Whitelisted(msg.sender, _token);
    }

    /// @dev Add a token to a gauge/bribe as possible reward.
    function registerRewardToken(
        address _token,
        address _gaugeOrBribe,
        uint256 _tokenId
    ) external {
        require(_tokenId > 0, "!token");
        require(msg.sender == IERC721(ve).ownerOf(_tokenId), "!owner");
        require(IVe(ve).balanceOfNFT(_tokenId) > _listingFee(), "!power");
        IMultiRewardsPool(_gaugeOrBribe).registerRewardToken(_token);
    }

    /// @dev Remove a token from a gauge/bribe allowed rewards list.
    function removeRewardToken(
        address _token,
        address _gaugeOrBribe,
        uint256 _tokenId
    ) external {
        require(_tokenId > 0, "!token");
        require(msg.sender == IERC721(ve).ownerOf(_tokenId), "!owner");
        require(IVe(ve).balanceOfNFT(_tokenId) > _listingFee(), "!power");
        IMultiRewardsPool(_gaugeOrBribe).removeRewardToken(_token);
    }

    /// @dev Create gauge for given pool. Only for a pool with whitelisted tokens.
    function createGauge(address _pool) external returns (address) {
        require(!isLocked, "creation of gauge locked");
        require(gauges[_pool] == address(0x0), "exists");
        require(IFactory(factory).isPair(_pool), "!pool");
        (address tokenA, address tokenB) = IPair(_pool).tokens();
        require(isWhitelisted[tokenA] && isWhitelisted[tokenB], "!whitelisted");

        address[] memory allowedRewards = new address[](3);
        allowedRewards[0] = tokenA;
        allowedRewards[1] = tokenB;
        if (token != tokenA && token != tokenB) {
            allowedRewards[2] = token;
        }

        address _bribe = IBribeFactory(bribeFactory).createBribe(
            allowedRewards
        );
        address _gauge = IGaugeFactory(gaugeFactory).createGauge(
            _pool,
            _bribe,
            ve,
            allowedRewards
        );
        IERC20(token).safeIncreaseAllowance(_gauge, type(uint256).max);
        bribes[_gauge] = _bribe;
        gauges[_pool] = _gauge;
        poolForGauge[_gauge] = _pool;
        isGauge[_gauge] = true;
        _updateFor(_gauge);
        pools.push(_pool);
        emit GaugeCreated(_gauge, msg.sender, _bribe, _pool);
        return _gauge;
    }

    /// @dev A gauge should be able to attach a token for preventing transfers/withdraws.
    function attachTokenToGauge(
        uint256 tokenId,
        address account
    ) external override {
        require(isGauge[msg.sender], "!gauge");
        if (tokenId > 0) {
            IVe(ve).attachToken(tokenId);
        }
        emit Attach(account, msg.sender, tokenId);
    }

    /// @dev Emit deposit event for easily handling external actions.
    function emitDeposit(
        uint256 tokenId,
        address account,
        uint256 amount
    ) external override {
        require(isGauge[msg.sender], "!gauge");
        emit Deposit(account, msg.sender, tokenId, amount);
    }

    /// @dev Detach given token.
    function detachTokenFromGauge(
        uint256 tokenId,
        address account
    ) external override {
        require(isGauge[msg.sender], "!gauge");
        if (tokenId > 0) {
            IVe(ve).detachToken(tokenId);
        }
        emit Detach(account, msg.sender, tokenId);
    }

    /// @dev Emit withdraw event for easily handling external actions.
    function emitWithdraw(
        uint256 tokenId,
        address account,
        uint256 amount
    ) external override {
        require(isGauge[msg.sender], "!gauge");
        emit Withdraw(account, msg.sender, tokenId, amount);
    }

    /// @dev Length of pools
    function poolsLength() external view returns (uint256) {
        return pools.length;
    }

    /// @dev Add rewards to this contract. Usually it is DraculaMinter.
    function notifyRewardAmount(uint256 amount) external override {
        require(amount != 0, "zero amount");
        uint256 _totalWeight = totalWeight;
        // without votes rewards can not be added
        require(_totalWeight != 0, "!weights");
        // transfer the distro in
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // 1e18 adjustment is removed during claim
        uint256 _ratio = (amount * 1e18) / _totalWeight;
        if (_ratio > 0) {
            index += _ratio;
        }
        emit NotifyReward(msg.sender, token, amount);
    }

    /// @dev Update given gauges.
    function updateFor(address[] memory _gauges) external {
        for (uint256 i = 0; i < _gauges.length; i++) {
            _updateFor(_gauges[i]);
        }
    }

    /// @dev Update gauges by indexes in a range.
    function updateForRange(uint256 start, uint256 end) public {
        for (uint256 i = start; i < end; i++) {
            _updateFor(gauges[pools[i]]);
        }
    }

    /// @dev Update all gauges.
    function updateAll() external {
        updateForRange(0, pools.length);
    }

    /// @dev Update reward info for given gauge.
    function updateGauge(address _gauge) external {
        _updateFor(_gauge);
    }

    function _updateFor(address _gauge) internal {
        address _pool = poolForGauge[_gauge];
        int256 _supplied = weights[_pool];
        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[_gauge];
            // get global index for accumulated distro
            uint256 _index = index;
            // update _gauge current position to global position
            supplyIndex[_gauge] = _index;
            // see if there is any difference that need to be accrued
            uint256 _delta = _index - _supplyIndex;
            if (_delta > 0) {
                // add accrued difference for each supplied token
                uint256 _share = (uint256(_supplied) * _delta) / 1e18;
                claimable[_gauge] += _share;
            }
        } else {
            // new users are set to the default global state
            supplyIndex[_gauge] = index;
        }
    }

    /// @dev Batch claim rewards from given gauges.
    function claimRewards(
        address[] memory _gauges,
        address[][] memory _tokens
    ) external {
        for (uint256 i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).getReward(msg.sender, _tokens[i]);
        }
    }

    /// @dev Batch claim rewards from given bribe contracts for given tokenId.
    function claimBribes(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external {
        require(IVe(ve).isApprovedOrOwner(msg.sender, _tokenId), "!owner");
        for (uint256 i = 0; i < _bribes.length; i++) {
            IBribe(_bribes[i]).getRewardForOwner(_tokenId, _tokens[i]);
        }
    }

    /// @dev Claim fees from given bribes.
    function claimFees(
        address[] memory _bribes,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external {
        require(IVe(ve).isApprovedOrOwner(msg.sender, _tokenId), "!owner");
        for (uint256 i = 0; i < _bribes.length; i++) {
            IBribe(_bribes[i]).getRewardForOwner(_tokenId, _tokens[i]);
        }
    }

    /// @dev Move fees from deposited pools to bribes for given gauges.
    function distributeFees(address[] memory _gauges) external {
        for (uint256 i = 0; i < _gauges.length; i++) {
            IGauge(_gauges[i]).claimFees();
        }
    }

    /// @dev Get emission from minter and notify rewards for given gauge.
    function distribute(address _gauge) external override {
        _distribute(_gauge);
    }

    function _distribute(address _gauge) internal lock {
        IMinter(minter).updatePeriod();
        _updateFor(_gauge);
        uint256 _claimable = claimable[_gauge];
        if (
            _claimable > IMultiRewardsPool(_gauge).left(token) &&
            _claimable / DURATION > 0
        ) {
            claimable[_gauge] = 0;
            IGauge(_gauge).notifyRewardAmount(token, _claimable);
            emit DistributeReward(msg.sender, _gauge, _claimable);
        }
    }

    /// @dev Distribute rewards for all pools.
    function distributeAll() external {
        uint256 length = pools.length;
        for (uint256 x; x < length; x++) {
            _distribute(gauges[pools[x]]);
        }
    }

    function distributeForPoolsInRange(uint256 start, uint256 finish) external {
        for (uint256 x = start; x < finish; x++) {
            _distribute(gauges[pools[x]]);
        }
    }

    function distributeForGauges(address[] memory _gauges) external {
        for (uint256 x = 0; x < _gauges.length; x++) {
            _distribute(_gauges[x]);
        }
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        SNAPSHOT & BOND (VIEWS)
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */

    function getTotalRewards() external view returns (uint256) {
        return bribeBond.stable().balanceOf(address(bribeBond));
    }

    function getSnapshotInfo()
        external
        view
        returns (uint256, uint256, uint256)
    {
        return (
            snapshotGauges.totalGaugeWeight,
            snapshotGauges.nbOfGauges,
            snapshotGauges.totalBondRewards
        );
    }

    function getSnapshotByGauge(
        address _gauge
    ) external view returns (GaugeInfo memory) {
        return snapshotGauges.gaugesInfo[_gauge];
    }

    function getClaimableBondRewards(
        address[] calldata _gauges,
        uint256 tokenId
    ) external view returns (uint256) {
        uint256 _activePeriod = IMinter(minter).activePeriod();
        uint256 _lastVote = lastVote[tokenId];
        uint256 _claimable;
        if (
            _activePeriod - WEEK * 2 < _lastVote &&
            _lastVote < _activePeriod - WEEK
        ) {
            for (uint256 i; i < _gauges.length; i++) {
                uint256 tokenIdWeightForGauge = uint256(
                    votes[tokenId][_gauges[i]]
                );

                if (
                    tokenIdWeightForGauge != 0 &&
                    !isGaugeClaimed[tokenId][_gauges[i]]
                ) {
                    /// @dev fetch weight/rewards of the gauge
                    uint256 gaugeWeight = snapshotGauges
                        .gaugesInfo[_gauges[i]]
                        .weight;
                    uint256 rewardsOfGauge = snapshotGauges
                        .gaugesInfo[_gauges[i]]
                        .reward;

                    /// @dev calculate share/rewards of the tokenId in the gauge
                    uint256 shareOfTokenId = (tokenIdWeightForGauge *
                        PRECISION) / gaugeWeight;
                    /// @dev add to claimable
                    _claimable += (rewardsOfGauge * shareOfTokenId) / PRECISION;
                }
            }
        }
        return _claimable;
    }

    function getAllClaimableBondRewards(
        uint256 tokenId
    ) external view returns (GaugeReward[] memory) {
        uint256 _activePeriod = IMinter(minter).activePeriod();
        uint256 _lastVote = lastVote[tokenId];

        GaugeReward[] memory gaugeRewards;
        if (
            _activePeriod - WEEK * 2 < _lastVote &&
            _lastVote < _activePeriod - WEEK
        ) {
            uint256 counter;
            address[] memory _gauges = pools;
            gaugeRewards = new GaugeReward[](_gauges.length);

            for (uint256 i; i < _gauges.length; i++) {
                uint256 tokenIdWeightForGauge = uint256(
                    votes[tokenId][_gauges[i]]
                );

                if (
                    tokenIdWeightForGauge != 0 &&
                    !isGaugeClaimed[tokenId][_gauges[i]]
                ) {
                    /// @dev fetch weight/rewards of the gauge
                    uint256 gaugeWeight = snapshotGauges
                        .gaugesInfo[_gauges[i]]
                        .weight;
                    uint256 rewardsOfGauge = snapshotGauges
                        .gaugesInfo[_gauges[i]]
                        .reward;

                    /// @dev calculate share/rewards of the tokenId in the gauge
                    uint256 shareOfTokenId = (tokenIdWeightForGauge *
                        PRECISION) / gaugeWeight;

                    /// @dev add to gaugeRewards claimable
                    gaugeRewards[counter++] = GaugeReward({
                        gauge: _gauges[i],
                        reward: (rewardsOfGauge * shareOfTokenId) / PRECISION
                    });
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        /// @dev remove useless gauge without reward
                        mstore(gaugeRewards, sub(mload(gaugeRewards), 1))
                    }
                }
            }
        }
        return gaugeRewards;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        SNAPSHOT & BOND (EXTERNALS)
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    /// @notice Snapshot gauges weight & rewards infos
    function snapshot() external {
        uint256 _activePeriod = IMinter(minter).activePeriod();
        /// @dev snapshot can only be triggered 4 hours before the new epoch
        require(
            block.timestamp > _activePeriod - FOUR_HOURS,
            "not snapshot time!"
        );
        require(!isSnapshot[_activePeriod], "snapshot already done");

        uint256 _cursor = cursor;
        /// @dev lock some process (vote, updatePeriod, etc..)
        if (_cursor == 0) {
            _toggleLock(true);

            IBribeBond _bribeBond = bribeBond;
            /// @dev save important data for snapshot

            snapshotGauges.nbOfGauges = pools.length;
            snapshotGauges.totalGaugeWeight = totalWeight;

            snapshotGauges.totalBondRewards = _bribeBond.stable().balanceOf(
                address(_bribeBond)
            );
        }
        uint256 _nbOfGauges = snapshotGauges.nbOfGauges;
        uint256 _totalGaugeWeight = snapshotGauges.totalGaugeWeight;
        uint256 _totalBondRewards = snapshotGauges.totalBondRewards;

        /// @dev check if length needs to be reduced by the _nbOfGauges
        uint256 _length = chunkForSnapshot;
        if (_cursor + _length > _nbOfGauges) {
            _length = _nbOfGauges;
        }

        for (uint256 i = _cursor; i < _length; ) {
            address _pool = pools[i];
            uint256 gaugeWeight = uint256(weights[_pool]);
            /// @dev calculate share/rewards of the gauge
            uint256 shareOfGauge = (gaugeWeight * PRECISION) /
                _totalGaugeWeight;
            uint256 gaugeRewards = (_totalBondRewards * shareOfGauge) /
                PRECISION;

            snapshotGauges.gaugesInfo[_pool].weight = gaugeWeight;
            snapshotGauges.gaugesInfo[_pool].reward = gaugeRewards;
            unchecked {
                ++i;
            }
        }

        cursor = _length;

        if (cursor == _nbOfGauges) {
            _toggleLock(false);
            delete cursor;

            bribeBond.resetDepositedValueForEpoch();
            isSnapshot[_activePeriod] = true;
        }
    }

    /// @notice Called "internaly" only by bribeBond contract
    function _claimBondRewards(
        address[] calldata _gauges,
        uint256 tokenId
    ) external returns (uint256) {
        require(!isLocked, "claim locked");

        require(msg.sender == address(bribeBond), "not bribeBond");

        uint256 _activePeriod = IMinter(minter).activePeriod();
        require(!isSnapshot[_activePeriod], "period not updated yet");
        uint256 _lastVote = lastVote[tokenId];
        /// @dev check if lastVote is only on the last epoch
        require(
            _activePeriod - WEEK * 2 < _lastVote &&
                _lastVote < _activePeriod - WEEK,
            "not claimable"
        );
        uint256 _claimable;
        for (uint256 i; i < _gauges.length; i++) {
            uint256 tokenIdWeightForGauge = uint256(votes[tokenId][_gauges[i]]);

            /// @dev check presence of gauge weight and if the gauge is claimed to process calculation
            if (
                tokenIdWeightForGauge != 0 &&
                !isGaugeClaimed[tokenId][_gauges[i]]
            ) {
                /// @dev fetch weight/rewards of the gauge
                uint256 gaugeWeight = snapshotGauges
                    .gaugesInfo[_gauges[i]]
                    .weight;
                uint256 rewardsOfGauge = snapshotGauges
                    .gaugesInfo[_gauges[i]]
                    .reward;

                /// @dev calculate share/rewards of the tokenId in the gauge
                uint256 shareOfTokenId = (tokenIdWeightForGauge * PRECISION) /
                    gaugeWeight;
                /// @dev add to claimable
                _claimable += (rewardsOfGauge * shareOfTokenId) / PRECISION;

                /// @dev the gauge is now claimed
                isGaugeClaimed[tokenId][_gauges[i]] = true;
            }
        }
        return _claimable;
    }

    /* =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-=
                        SNAPSHOT & BOND (OWNER)
    =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=--=-=-=-= */
    function setBribeBond(IBribeBond _bribeBond) external onlyOwner {
        require(address(_bribeBond) != address(0), "bribeBond address zero");
        bribeBond = _bribeBond;
    }

    function toggleLockEmergency(bool _isLocked) external onlyOwner {
        _toggleLock(_isLocked);
    }

    function setChunkForSnapshot(uint256 _chunkForSnapshot) external onlyOwner {
        chunkForSnapshot = _chunkForSnapshot;
    }

    function toggleSnapshot(
        uint256 _activePeriod,
        bool _isSnapshot
    ) external onlyOwner {
        isSnapshot[_activePeriod] = _isSnapshot;
    }

    function _toggleLock(bool _isLocked) internal {
        isLocked = _isLocked;
    }
}
