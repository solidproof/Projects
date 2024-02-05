// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Interfaces/IRektLock.sol";
import "./Interfaces/IWentokens.sol";

/**
 * @title Liquidity Lock
 * @notice Gain the trust of your community by locking the liquidity for a set period of time
 * @notice Avoid getting $REKT by actively engaging in locked liquidity tokens
 * @author Buildorz | www.buildorz.com
 */
contract LiquidityLock is Ownable {

    // errors
    error InvalidAmount ();
    error InvalidDuration();
    error InvalidShares();
    error InsufficientFunds (uint256 _amount, uint256 _balance);
    error TransferFailed();
    error NotLocked();
    error NotOwner();
    error NotDeadline();
    error Deadline();
    error Claimed();
    error NotVeNFTHolder();
    error NoVotingPower();
    error NotExecuted();
    error AlreadyExecuted();
    error LTPaused();
    error NoProposal();

    // events
    event Locked (
        uint256 lockLTID, address indexed tokenAddress, address indexed locker, 
        uint256 indexed tokenAmount, uint256 startTime, uint256 unlockTime
    );
    event Unlocked (uint256 lockLTID, uint256 unlockAmount, address caller);
    event ProposalSuggested (uint256 lockLTID, bytes32 reason, address user);
    event ProposalCreated (uint256 proposalID, uint256 lockLTID);
    event ProposalVoted (uint256 proposalID, address voter, Vote vote);
    event ProposalExecuted (uint256 proposalID);


    struct LockLT {
        address tokenAddress; // Address of ERC20 token locked
        // State of the claimed status
        // 0 == Not claimed; 1 == Claimed;
        uint96 claimed;
        address locker; // Address that locked the tokens
        uint96 ltPaused; // 0 == Not Paused; 1 == Paused;
        uint256 tokenAmount; // Amount of tokens locked
        uint256 startTime;
        uint256 unlockTime; // When tokens would be available to be transferred.
    }

    struct Proposals {
        uint256 lockLTID; // ID of the locked liquidity token
        uint256 created; // proposal creation date
        uint256 deadline; // proposal deadline
        uint256 executed; // Execution status of proposal 0 == Not Executed; 1 == Executed;
        bytes32 proposalReason;
        uint256 yayVotes;
        uint256 nayVotes;
        uint256 totalVotingPower;
        // mapping of NFT token IDs that voted
        mapping (uint256 tokenID => bool voted) voters;
        mapping (uint256 tokenID => bool) claimed;
        mapping (uint256 tokenID => uint256 votingPower) tokenIDVotingPower;
    }

    uint256 public numLLT; // number of locked liquidity token
    uint256 public numProposals;

    address private treasury;
    uint32 private holdersShare = 8000; // 80% = 8000;
    uint32 private treasuryShare = 1000; //10% = 1000
    uint32 private votersShare = 1000; // 10% = 1500;

    uint64 private MINLOCKDURATION = 0; //3 Months = 7_776_000;
    uint64 private MAXLOCKDURATION = 31_560_000_000_000; //12 Months = 31_104_000; Default at 1000 years.
    uint64 private VOTINGPERIOD = 604_800; //7 Days = 604_800;
    // No proposal can be created after PROPOSALPERIOD to the unlock time.
    uint64 private PROPOSALPERIOD = 1_814_400; // 21 Days = 1_814_400


    mapping (uint256 lockLTID => LockLT) public detailsLockID;
    mapping (uint256 proposalID => Proposals) public detailsProposalID;

    address public wenTokenAddress;

    IRektLock veNFT;
    IWentokens airdrop;

    constructor (address _veNFT, address _treasury, address _wenTokenAddr) payable {
        veNFT = IRektLock(_veNFT);
        airdrop = IWentokens(_wenTokenAddr);
        treasury = _treasury;
        wenTokenAddress = _wenTokenAddr;
    }

    modifier validateDuration (uint256 _duration) {
        if (_duration < MINLOCKDURATION || _duration > MAXLOCKDURATION) {
            revert InvalidDuration();
        }
        _;
    }

    modifier veNftHolderOnly() {
        if (veNFT.balanceOf(msg.sender) == 0) revert NotVeNFTHolder();
        _;
    }

    modifier activeProposalOnly(uint256 proposalID) {
        Proposals storage proposal = detailsProposalID[proposalID];
        if (proposal.created == 0) revert NoProposal();
        if (block.timestamp > proposal.deadline) {
            revert Deadline();
        }
        _;
    }

    modifier inactiveProposalOnly(uint256 proposalID) {
        Proposals storage proposal = detailsProposalID[proposalID];
        if (proposal.created == 0) revert NoProposal();
        if (proposal.deadline >= block.timestamp) revert NotDeadline();
        if (proposal.executed == 1) revert AlreadyExecuted();
        _;
    }

    enum Vote {
        YAY, // YAY = 0
        NAY // NAY = 1
    }

    /// @notice Lock up the Liquidity tokens
    /// @dev After locking up the Liquidity tokens, proposals can be made by $REKT NFT holders 
    /// @dev to decide if the tokens would go back to the community or not.
    /// @param _amount - The amount of tokens to lock up
    /// @param _duration - The duration to lock up tokens
    function ltLock(uint _amount, uint256 _duration, address _lt) external
        validateDuration(_duration) {

        if (_amount == 0) revert InvalidAmount();
        IERC20 lt = IERC20(_lt);
        address locker = msg.sender;
        uint256 balance = lt.balanceOf(locker);
        if (_amount > balance) revert InsufficientFunds(balance, _amount);
        uint256 _numLLT = numLLT;
        uint256 timestamp = block.timestamp;
        detailsLockID[_numLLT].startTime = timestamp;
        detailsLockID[_numLLT].unlockTime = timestamp + _duration;
        detailsLockID[_numLLT].tokenAmount = _amount;
        detailsLockID[_numLLT].tokenAddress = _lt;
        detailsLockID[_numLLT].locker = locker;
        numLLT = numLLT + 1;
        // Approve contract to transfer tokens
        // lt.approve(address(this), type(uint256).max);
        bool success = lt.transferFrom(locker, address(this), _amount);
        if (!success) revert TransferFailed();
        
        emit Locked(_numLLT, _lt, locker, _amount, timestamp, timestamp + _duration);
    }

    /// @notice Unlocks the locked liquidity token
    /// @dev Can only be unlocked by the address that locked it
    /// @dev Cannot be unlocked before the deadline OR if there's an active proposal OR if a proposal passes
    /// @param lockLTID - The ID of the Locked Liquidity token
    function ltUnlock(uint256 lockLTID) external {
        address caller = msg.sender;
        LockLT memory lockLTdetails = detailsLockID[lockLTID];
        if (lockLTdetails.locker != caller) revert NotOwner();
        if (lockLTdetails.unlockTime > block.timestamp) revert NotDeadline();
        if (lockLTdetails.claimed == 1) revert Claimed();
        if (lockLTdetails.ltPaused == 1) revert LTPaused();
        detailsLockID[lockLTID].claimed = 1;

        _ltUnlock(lockLTID, caller, lockLTdetails.tokenAmount);

    }

    /// @notice veNFT holders can suggest a proposal, as only the admins can create proposals.
    /// @notice A link pointing to a detailed explanation of the reason for the suggestion can be hashed and used as `_proposalReason` 
    function suggestProposal(uint256 lockLTID, bytes32 _proposalReason)
        external
        veNftHolderOnly
    {
        emit ProposalSuggested(lockLTID, _proposalReason, msg.sender);
    }

    /// @notice Creates a proposal with the locked liquidity token ID and the reason
    /// @notice The reason can be a link, hashed and converted to bytes32
    /// @dev Only the admin is allowed to create a proposal
    /// @dev Proposals cannot be created `PROPOSALPERIOD` to the unlock time
    function createProposal(uint256 lockLTID, bytes32 _proposalReason)
        external
        onlyOwner
        returns (uint256)
    {
        LockLT memory lockLTdetails = detailsLockID[lockLTID];
        uint256 startTime = block.timestamp;
        if (lockLTdetails.tokenAddress == address(0)) revert NotLocked();
        if (lockLTdetails.ltPaused == 1) revert LTPaused();
        if (startTime > (lockLTdetails.unlockTime - PROPOSALPERIOD)) {
            revert Deadline();
        }
        Proposals storage proposal = detailsProposalID[numProposals];
        proposal.lockLTID = lockLTID;
        proposal.created = startTime;
        proposal.deadline = startTime + VOTINGPERIOD;
        proposal.proposalReason = _proposalReason;
        detailsLockID[proposal.lockLTID].ltPaused = 1;

        emit ProposalCreated (numProposals, lockLTID);
        numProposals = numProposals + 1;
        return numProposals - 1;
    }

    /// @notice veNFT holders only are allowed to vote on active proposals
    /// @param proposalID - The proposal ID to vote on
    /// @param vote - 0 - Yay; 1 - Nay.
    function voteOnProposal(uint256 proposalID, Vote vote)
        external
        veNftHolderOnly
        activeProposalOnly(proposalID) {
        Proposals storage proposal = detailsProposalID[proposalID];

        address caller = msg.sender;
        uint256 voterNFTBalance = veNFT.balanceOf(caller);
        uint256 votingPower;

        // Calculate how many NFTs are owned by the voter and their voting power
        for (uint256 i; i < voterNFTBalance;) {
            uint256 tokenId = veNFT.tokenOfOwnerByIndex(caller, i);
            if (!proposal.voters[tokenId]) {
                uint256 tokenIdVotingPower = veNFT.getVotingPower(tokenId);
                votingPower += tokenIdVotingPower;
                proposal.voters[tokenId] = true;
                proposal.tokenIDVotingPower[tokenId] += votingPower;
            }
            unchecked {
                ++i;
            }
        }
        if (votingPower == 0) revert NoVotingPower();
        proposal.totalVotingPower += votingPower;

        if (vote == Vote.YAY) {
            proposal.yayVotes += votingPower;
        } else {
            proposal.nayVotes += votingPower;
        }
        emit ProposalVoted(proposalID, caller, vote);
    }

    /// Only ADMIN can execute the proposal after the deadline
    /// @param proposalID - Proposal ID to execute
    function executeProposal(uint256 proposalID, address[] calldata tokenHolders, uint256[] calldata amounts)
        external
        onlyOwner
        inactiveProposalOnly(proposalID) {

        Proposals storage proposal = detailsProposalID[proposalID];
        proposal.executed = 1;
        bool proposalPassed = checkProposalResult(proposalID);
        // If the proposal passes, transfer the locked Liquidity Token.
        if (proposalPassed) {
            uint256 tokenAmount = detailsLockID[proposal.lockLTID].tokenAmount;
            (uint256 _holdersAmount, ,uint256 _treasuryAmount) = calcShares(tokenAmount);

            _ltUnlock(proposal.lockLTID, treasury, _treasuryAmount);
            LockLT memory lockLTdetails = detailsLockID[proposal.lockLTID];
            IERC20 lt = IERC20(lockLTdetails.tokenAddress);
            lt.approve(wenTokenAddress, _holdersAmount);
            airdrop.airdropERC20(lt, tokenHolders, amounts, _holdersAmount);

        } else {
            detailsLockID[proposal.lockLTID].ltPaused = 0;
        }
        
        emit ProposalExecuted(proposalID);
    }

    /// @notice If a proposal passes, veNFT token IDs that voted are allowed to get a share from the VOTERSSHARE allocation
    /// @notice The total allocation is shared according to the voting power at the time of the voting
    /// @dev Only veNFTHolders that voted are allowed to claim the reward
    /// @param proposalID - Proposal ID to claim
    function claim(uint256 proposalID) external veNftHolderOnly {

        Proposals storage proposal = detailsProposalID[proposalID];
        if (proposal.executed == 0) revert NotExecuted();
        bool proposalPassed = checkProposalResult(proposalID);
        address caller = msg.sender;
        if (proposalPassed) {
            uint256 voterNFTBalance = veNFT.balanceOf(caller);
            uint256 votingPower;
            // Calculate how many NFTs are owned by the voter and their voting power
            for (uint256 i; i < voterNFTBalance;) {
                uint256 tokenId = veNFT.tokenOfOwnerByIndex(caller, i);
                if (!proposal.claimed[tokenId]) {
                uint256 tokenIDVotingPower = proposal.tokenIDVotingPower[tokenId];
                votingPower += tokenIDVotingPower;
                proposal.claimed[tokenId] = true;
                }
                unchecked {
                    ++i;
                }
            }

            if (votingPower == 0) revert NoVotingPower();
            uint256 tokenAmount = detailsLockID[proposal.lockLTID].tokenAmount;
            (, uint256 votersAmount,) = calcShares(tokenAmount);

            uint256 amount = votersAmount * votingPower / proposal.totalVotingPower;

            _ltUnlock(proposal.lockLTID, caller, amount);
        } else revert();

    }

    function checkProposalResult (uint256 proposalID) public view returns (bool passed) {
        Proposals storage proposal = detailsProposalID[proposalID];
        passed = proposal.yayVotes > proposal.nayVotes ? true : false;
    }

    /// @notice Calculate the different allocations from a given amount
    /// @param amount - Total amount to be split
    /// @return _holdersAmount for the holders
    /// @return _votersAmount for the voters
    /// @return _treasuryAmount for the treasury
    function calcShares (uint256 amount) internal view returns 
        (uint256 _holdersAmount, uint256 _votersAmount,
        uint256 _treasuryAmount) {
            _holdersAmount = amount * holdersShare / 10000;
            _votersAmount = amount * votersShare / 10000;
            _treasuryAmount = amount * treasuryShare / 10000;
    }


    /// @notice Unlock the liquidity token and distribute to the given address
    /// @param lockLTID - Locked liquidity token ID
    /// @param caller - Address to send the unlocked token
    /// @param amount - Amount to be unlocked
    function _ltUnlock (uint256 lockLTID, address caller, uint256 amount) internal {
        LockLT memory lockLTdetails = detailsLockID[lockLTID];
        IERC20 lt = IERC20(lockLTdetails.tokenAddress);
        uint256 balance = lt.balanceOf(address(this));

        if (balance < amount) revert InsufficientFunds(amount, balance);

        bool success = lt.transfer(caller, amount);
        if (!success) revert TransferFailed();

        emit Unlocked (lockLTID, amount, caller);
    }

    function distributeToken (address tokenAddr, address[] calldata _receipients,
    uint256[] calldata _amounts, uint256 total ) public onlyOwner {
        IERC20 token = IERC20(tokenAddr);
        token.approve(wenTokenAddress, total);
        airdrop.airdropERC20(token, _receipients, _amounts, total);
    }

    /// ----------------ADMIN SETTER FUNCTIONS ------------------------///

    function setDuration(uint64 _minDuration, uint64 _maxDuration) external payable onlyOwner {
        MINLOCKDURATION = _minDuration;
        MAXLOCKDURATION = _maxDuration;
    }

    function setPeriods(uint64 _votingPeriod, uint64 _proposalPeriod) external payable onlyOwner {
        VOTINGPERIOD = _votingPeriod;
        PROPOSALPERIOD = _proposalPeriod;
    }

    function setShares (uint32 _holdersShare, uint32 _votersShare, uint32 _treasuryShare) external payable onlyOwner{
        if (_holdersShare + _votersShare + _treasuryShare != 10_000) revert InvalidShares();
        holdersShare = _holdersShare;
        votersShare = _votersShare;
        treasuryShare = _treasuryShare;
    }

    function setAddresses(address _treasury) external payable onlyOwner {
        treasury = _treasury;
    }

    /// ----------------GETTER FUNCTIONS ------------------------///
    function getNumLockedLiquidityTokens() external view returns (uint256 _numLLT) {
        _numLLT = numLLT;
    }

    function getNumProposals() external view returns (uint256 _numProposals) {
        _numProposals = numProposals;
    }

    function getTreasuryAddress() external view returns (address _treasury) {
        _treasury = treasury;
    }

    function getShares() external view returns (uint32 _holdersShare, uint32 _votersShare, uint32 _treasuryShare) {
        _holdersShare = holdersShare;
        _votersShare = votersShare;
        _treasuryShare = treasuryShare;
    }

    function getLockDurations() external view returns (uint64 _minDuration, uint64 _maxDuration) {
        _minDuration = MINLOCKDURATION;
        _maxDuration = MAXLOCKDURATION;
    }

    function getPeriods() external view returns (uint64 _votingPeriod, uint64 _proposalPeriod) {
        _votingPeriod = VOTINGPERIOD;
        _proposalPeriod = PROPOSALPERIOD;
    }

    function getLLTById(uint256 lockLTID) external view returns (LockLT memory _lockLt) {
        _lockLt = detailsLockID[lockLTID];
    }

    function getProposalRemainingTime (uint256 proposalID) public view returns (uint256 timeleft) {
        uint256 deadline = detailsProposalID[proposalID].deadline;
        timeleft = block.timestamp > deadline ? 0 : deadline - block.timestamp;
    }

    // getTotalUnclaimedReward
    // getAllVotedProposal
    // getAllUnclaimedProposalId

    function getAllVotedProposal(uint256 _tokenId) public view returns(uint256[] memory) {
        uint256 _numProposals = numProposals;
        uint256 _numVotedProposals;
        for (uint256 i; i < _numProposals; ) {
            bool voted = detailsProposalID[i].voters[_tokenId];
            if (voted) {
                ++_numVotedProposals;
            }
            unchecked {
                ++i;
            }
        }
        uint256[] memory votedProposals = new uint256[](_numVotedProposals);

        for (uint256 i; i < _numVotedProposals; ) {
            for (uint256 j; j < _numProposals; ) {
                bool voted = detailsProposalID[j].voters[_tokenId];
                if (voted) {
                    votedProposals[i] = j;
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        return votedProposals;
    }

    function getAllUnclaimedProposalId (uint256 _tokenId) public view returns (uint256[] memory) {
        uint256[] memory votedProposals = getAllVotedProposal(_tokenId);
        uint256 _numVotedProposals = votedProposals.length;
        uint256 _numUnclaimedProposals;

        for (uint256 i; i < _numVotedProposals; ) {
            if (detailsProposalID[i].executed == 0) revert NotExecuted();
            bool proposalPassed = checkProposalResult(i);
            if (proposalPassed) {
                bool claimed = detailsProposalID[i].claimed[_tokenId];
                if (!claimed) {
                    ++_numUnclaimedProposals;
                }
            }

            unchecked {
                ++i;
            }
            
        }
        uint256[] memory unclaimedProposals = new uint256[](_numUnclaimedProposals);

        for (uint256 i; i < _numUnclaimedProposals; ) {
            if (detailsProposalID[i].executed == 0) revert NotExecuted();
            bool proposalPassed = checkProposalResult(i);
            if (proposalPassed) {
                for (uint256 j; j < _numVotedProposals; ) {
                    bool claimed = detailsProposalID[j].claimed[_tokenId];
                    if (!claimed) {
                        unclaimedProposals[i] = j;
                    }
                    unchecked {
                        ++j;
                    }
                }
            }
            unchecked {
                ++i;
            }
        }

        return unclaimedProposals;

    }

    function getTotalUnclaimedRewards(uint256 _tokenId) external view returns (uint256 unclaimedRewards) {
        uint256[] memory unclaimedProposalId = getAllUnclaimedProposalId(_tokenId);
        for (uint256 i; i < unclaimedProposalId.length; ) {
            uint256 proposalId = unclaimedProposalId[i];
            uint256 tokenAmount = detailsLockID[detailsProposalID[proposalId].lockLTID].tokenAmount;
            uint256 tokenIDVotingPower = detailsProposalID[proposalId].tokenIDVotingPower[_tokenId];

            (, uint256 votersAmount,) = calcShares(tokenAmount);

            uint256 amount = votersAmount * tokenIDVotingPower / detailsProposalID[proposalId].totalVotingPower;
            unclaimedRewards += amount;

            unchecked {
                ++i;
            }
        }
    }

}