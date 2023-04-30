// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../ShareholderRegistry/IShareholderRegistry.sol";
import "../GovernanceToken/IGovernanceToken.sol";
import "../Voting/IVoting.sol";
import "hardhat/console.sol";

abstract contract ResolutionManagerBase {
    event ResolutionCreated(address indexed from, uint256 indexed resolutionId);

    event ResolutionUpdated(address indexed from, uint256 indexed resolutionId);

    event ResolutionApproved(
        address indexed from,
        uint256 indexed resolutionId
    );

    event ResolutionRejected(
        address indexed from,
        uint256 indexed resolutionId
    );

    event ResolutionVoted(
        address indexed from,
        uint256 indexed resolutionId,
        uint256 votingPower,
        bool isYes
    );

    event ResolutionExecuted(
        address indexed from,
        uint256 indexed resolutionId
    );

    event ResolutionTypeCreated(
        address indexed from,
        uint256 indexed typeIndex
    );

    event DelegateLostVotingPower(
        address indexed from,
        uint256 indexed resolutionId,
        uint256 amount
    );

    struct ResolutionType {
        string name;
        uint256 quorum;
        uint256 noticePeriod;
        uint256 votingPeriod;
        bool canBeNegative;
    }

    struct Resolution {
        string dataURI;
        uint256 resolutionTypeId;
        uint256 approveTimestamp;
        uint256 snapshotId;
        uint256 yesVotesTotal;
        bool isNegative;
        uint256 rejectionTimestamp;
        // Transaction fields
        address[] executionTo;
        bytes[] executionData;
        uint256 executionTimestamp;
        address addressedContributor;
        mapping(address => bool) hasVoted;
        mapping(address => bool) hasVotedYes;
        mapping(address => uint256) lostVotingPower;
    }

    uint256 internal _currentResolutionId;

    IShareholderRegistry internal _shareholderRegistry;
    IGovernanceToken internal _governanceToken;
    IVoting internal _voting;

    ResolutionType[] public resolutionTypes;

    mapping(uint256 => Resolution) public resolutions;

    function _initialize(
        IShareholderRegistry shareholderRegistry,
        IGovernanceToken governanceToken,
        IVoting voting
    ) internal {
        _shareholderRegistry = shareholderRegistry;
        _governanceToken = governanceToken;
        _voting = voting;

        // TODO: check if there are any rounding errors
        _addResolutionType("amendment", 66, 14 days, 6 days, false);
        _addResolutionType("capitalChange", 66, 14 days, 6 days, false);
        _addResolutionType("preclusion", 75, 14 days, 6 days, false);
        _addResolutionType("fundamentalOther", 51, 14 days, 6 days, false);
        _addResolutionType("significant", 51, 6 days, 4 days, false);
        _addResolutionType("dissolution", 66, 14 days, 6 days, false);
        _addResolutionType("routine", 51, 3 days, 2 days, true);
        _addResolutionType("genesis", 100, 0 days, 4 days, false);

        _currentResolutionId = 1;
    }

    modifier onlyPending(uint256 resolutionId) {
        Resolution storage resolution = resolutions[resolutionId];
        require(
            resolution.approveTimestamp == 0,
            "Resolution: already approved"
        );
        require(
            resolution.rejectionTimestamp == 0,
            "Resolution: already rejected"
        );

        _;
    }

    modifier exists(uint256 resolutionId) {
        require(
            resolutionId < _currentResolutionId,
            "Resolution: does not exist"
        );

        _;
    }

    function _setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) internal virtual {
        _shareholderRegistry = shareholderRegistry;
    }

    function _setGovernanceToken(
        IGovernanceToken governanceToken
    ) internal virtual {
        _governanceToken = governanceToken;
    }

    function _setVoting(IVoting voting) internal virtual {
        _voting = voting;
    }

    function _snapshotAll() internal virtual returns (uint256) {
        uint256 snapshotId = _shareholderRegistry.snapshot();
        require(
            _governanceToken.snapshot() == snapshotId &&
                _voting.snapshot() == snapshotId,
            "ResolutionManager: snapshot ids are inconsistent"
        );

        return snapshotId;
    }

    function _createResolution(
        string calldata dataURI,
        uint256 resolutionTypeId,
        bool isNegative,
        address[] memory executionTo,
        bytes[] memory executionData,
        address addressedContributor
    ) internal virtual returns (uint256) {
        ResolutionType storage resolutionType = resolutionTypes[
            resolutionTypeId
        ];
        require(
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.CONTRIBUTOR_STATUS(),
                msg.sender
            ),
            "Resolution: only contributor can create"
        );
        require(
            !isNegative || resolutionType.canBeNegative,
            "Resolution: cannot be negative"
        );
        require(
            executionTo.length == executionData.length,
            "Resolution: length mismatch"
        );
        uint256 resolutionId = _currentResolutionId++;
        emit ResolutionCreated(msg.sender, resolutionId);

        Resolution storage resolution = resolutions[resolutionId];

        resolution.dataURI = dataURI;
        resolution.resolutionTypeId = resolutionTypeId;
        resolution.isNegative = isNegative;
        resolution.executionTo = executionTo;
        resolution.executionData = executionData;
        resolution.addressedContributor = addressedContributor;

        return resolutionId;
    }

    function _approveResolution(
        uint256 resolutionId
    ) internal virtual onlyPending(resolutionId) exists(resolutionId) {
        emit ResolutionApproved(msg.sender, resolutionId);
        require(
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.MANAGING_BOARD_STATUS(),
                msg.sender
            ),
            "Resolution: only managing board can approve"
        );

        Resolution storage resolution = resolutions[resolutionId];
        resolution.approveTimestamp = block.timestamp;

        // In case of a vote with addreeable contributor, we want the voting power of the contributor
        // that addressed contributor to be removed from the total voting
        // power. Hence we are forcing the the contributor to have no delegation for this
        // resolution so to have the voting power "clean". Delegation is restored
        // after the snapshot.
        address delegated;
        if (resolution.addressedContributor != address(0)) {
            delegated = _voting.getDelegate(resolution.addressedContributor);
            if (delegated != resolution.addressedContributor) {
                _voting.delegateFrom(
                    resolution.addressedContributor,
                    resolution.addressedContributor
                );
            }
        }

        resolution.snapshotId = _snapshotAll();

        if (resolution.addressedContributor != address(0)) {
            if (delegated != resolution.addressedContributor) {
                _voting.delegateFrom(
                    resolution.addressedContributor,
                    delegated
                );
            }
        }
    }

    function _rejectResolution(
        uint256 resolutionId
    ) internal virtual onlyPending(resolutionId) exists(resolutionId) {
        emit ResolutionRejected(msg.sender, resolutionId);

        require(
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.MANAGING_BOARD_STATUS(),
                msg.sender
            ),
            "Resolution: only managing board can reject"
        );

        Resolution storage resolution = resolutions[resolutionId];

        resolution.rejectionTimestamp = block.timestamp;
    }

    function _updateResolution(
        uint256 resolutionId,
        string calldata dataURI,
        uint256 resolutionTypeId,
        bool isNegative,
        address[] memory executionTo,
        bytes[] memory executionData
    ) internal virtual onlyPending(resolutionId) {
        emit ResolutionUpdated(msg.sender, resolutionId);

        Resolution storage resolution = resolutions[resolutionId];
        require(
            executionTo.length == executionData.length,
            "Resolution: length mismatch"
        );

        require(
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.MANAGING_BOARD_STATUS(),
                msg.sender
            ),
            "Resolution: only managing board can update"
        );

        ResolutionType storage resolutionType = resolutionTypes[
            resolutionTypeId
        ];
        require(
            !isNegative || resolutionType.canBeNegative,
            "Resolution: cannot be negative"
        );

        resolution.dataURI = dataURI;
        resolution.resolutionTypeId = resolutionTypeId;
        resolution.isNegative = isNegative;
        resolution.executionTo = executionTo;
        resolution.executionData = executionData;
    }

    function _executeResolution(uint256 resolutionId) internal virtual {
        emit ResolutionExecuted(msg.sender, resolutionId);

        Resolution storage resolution = resolutions[resolutionId];
        require(
            resolution.executionTo.length > 0,
            "Resolution: nothing to execute"
        );
        require(resolution.approveTimestamp > 0, "Resolution: not approved");
        require(
            resolution.executionTimestamp == 0,
            "Resolution: already executed"
        );

        (, uint256 votingEnd) = _votingWindow(resolution);

        require(block.timestamp >= votingEnd, "Resolution: not ended");

        require(getResolutionResult(resolutionId), "Resolution: not passed");

        address[] memory to = resolution.executionTo;
        bytes[] memory data = resolution.executionData;

        // Set timestamp before execution as a re-entrancy guard.
        resolution.executionTimestamp = block.timestamp;

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < to.length; i++) {
            // slither-disable-next-line low-level-calls
            (bool success, ) = to[i].call(data[i]);
            require(success, "Resolution: execution failed");
        }
        // slither-disable-end calls-loop
    }

    function _vote(uint256 resolutionId, bool isYes) internal virtual {
        Resolution storage resolution = resolutions[resolutionId];
        require(resolution.approveTimestamp > 0, "Resolution: not approved");
        require(
            msg.sender != resolution.addressedContributor,
            "Resolution: account cannot vote"
        );

        require(
            _voting.canVoteAt(msg.sender, resolution.snapshotId),
            "Resolution: account cannot vote"
        );

        require(
            isYes != resolution.hasVotedYes[msg.sender] ||
                !resolution.hasVoted[msg.sender],
            "Resolution: can't repeat same vote"
        );

        (uint256 votingStart, uint256 votingEnd) = _votingWindow(resolution);

        require(
            block.timestamp >= votingStart && block.timestamp < votingEnd,
            "Resolution: not votable"
        );

        uint256 votingPower = _voting.getVotingPowerAt(
            msg.sender,
            resolution.snapshotId
        );
        address delegate = _voting.getDelegateAt(
            msg.sender,
            resolution.snapshotId
        );

        // If sender has a delegate load voting power from GovernanceToken
        if (delegate != msg.sender) {
            votingPower =
                _governanceToken.balanceOfAt(
                    msg.sender,
                    resolution.snapshotId
                ) +
                _shareholderRegistry.balanceOfAt(
                    msg.sender,
                    resolution.snapshotId
                );
            // If sender didn't vote before and has a delegate
            //if (!resolution.hasVoted[msg.sender]) {
            // Did sender's delegate vote?
            if (
                resolution.hasVoted[delegate] &&
                resolution.hasVotedYes[delegate]
            ) {
                resolution.yesVotesTotal -= votingPower;
            }
            resolution.lostVotingPower[delegate] += votingPower;
            emit DelegateLostVotingPower(delegate, resolutionId, votingPower);
            //}
        }

        // votingPower is set
        // delegate vote has been cleared
        votingPower -= resolution.lostVotingPower[msg.sender];

        if (isYes && !resolution.hasVotedYes[msg.sender]) {
            // If sender votes yes and hasn't voted yes before
            resolution.yesVotesTotal += votingPower;
        } else if (resolution.hasVotedYes[msg.sender]) {
            // If sender votes no and voted yes before
            resolution.yesVotesTotal -= votingPower;
        }

        emit ResolutionVoted(msg.sender, resolutionId, votingPower, isYes);

        resolution.hasVoted[msg.sender] = true;
        resolution.hasVotedYes[msg.sender] = isYes;
    }

    function _votingWindow(
        Resolution storage resolution
    ) internal view virtual returns (uint256 _votingStart, uint256 _votingEnd) {
        ResolutionType storage resolutionType = resolutionTypes[
            resolution.resolutionTypeId
        ];

        _votingStart =
            resolution.approveTimestamp +
            resolutionType.noticePeriod;
        _votingEnd = _votingStart + resolutionType.votingPeriod;
    }

    function _addResolutionType(
        string memory name,
        uint256 quorum,
        uint256 noticePeriod,
        uint256 votingPeriod,
        bool canBeNegative
    ) internal virtual {
        resolutionTypes.push(
            ResolutionType(
                name,
                quorum,
                noticePeriod,
                votingPeriod,
                canBeNegative
            )
        );

        emit ResolutionTypeCreated(msg.sender, resolutionTypes.length - 1);
    }

    // Views

    function getExecutionDetails(
        uint256 resolutionId
    ) public view virtual returns (address[] memory, bytes[] memory) {
        Resolution storage resolution = resolutions[resolutionId];

        return (resolution.executionTo, resolution.executionData);
    }

    function getVoterVote(
        uint256 resolutionId,
        address voter
    )
        public
        view
        virtual
        returns (bool isYes, bool hasVoted, uint256 votingPower)
    {
        Resolution storage resolution = resolutions[resolutionId];
        require(
            msg.sender != resolution.addressedContributor &&
                _voting.canVoteAt(voter, resolution.snapshotId),
            "Resolution: account cannot vote"
        );

        isYes = resolution.hasVotedYes[voter];
        hasVoted = resolution.hasVoted[voter];

        if (
            _voting.getDelegateAt(voter, resolution.snapshotId) != voter &&
            hasVoted
        ) {
            votingPower =
                _governanceToken.balanceOfAt(voter, resolution.snapshotId) +
                _shareholderRegistry.balanceOfAt(voter, resolution.snapshotId);
        } else {
            votingPower =
                _voting.getVotingPowerAt(voter, resolution.snapshotId) -
                resolution.lostVotingPower[voter];
        }
    }

    function getResolutionResult(
        uint256 resolutionId
    ) public view virtual returns (bool) {
        Resolution storage resolution = resolutions[resolutionId];
        ResolutionType storage resolutionType = resolutionTypes[
            resolution.resolutionTypeId
        ];
        uint256 totalVotingPower = _voting.getTotalVotingPowerAt(
            resolution.snapshotId
        );

        if (resolution.addressedContributor != address(0)) {
            totalVotingPower -=
                _governanceToken.balanceOfAt(
                    resolution.addressedContributor,
                    resolution.snapshotId
                ) +
                _shareholderRegistry.balanceOfAt(
                    resolution.addressedContributor,
                    resolution.snapshotId
                );
        }

        bool hasQuorum = resolution.yesVotesTotal * 100 >=
            resolutionType.quorum * totalVotingPower;

        return resolution.isNegative ? !hasQuorum : hasQuorum;
    }
}
