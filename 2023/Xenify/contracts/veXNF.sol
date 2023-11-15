// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IAuction} from "./interfaces/IAuction.sol";
import {IVeXNF} from "./interfaces/IVeXNF.sol";

/*
 * @title veXNF Contract
 *
 * @notice Allows users to lock ERC-20 tokens and receive an ERC-721 NFT in return.
 * The NFT's earning power decays over time and is influenced by the lock duration,
 * with a maximum lock time of 1 year (`_MAXTIME`).
 *
 * Co-Founders:
 * - Simran Dhillon: simran@xenify.io
 * - Hardev Dhillon: hardev@xenify.io
 * - Dayana Plaz: dayana@xenify.io
 *
 * Official Links:
 * - Twitter: https://twitter.com/xenify_io
 * - Telegram: https://t.me/xenify_io
 * - Website: https://xenify.io
 *
 * Disclaimer:
 * This contract aligns with the principles of the Fair Crypto Foundation, promoting self-custody, transparency, consensus-based
 * trust, and permissionless value exchange. There are no administrative access keys, underscoring our commitment to decentralization.
 * Engaging with this contract involves technical and legal risks. Users must conduct their own due diligence and ensure compliance
 * with local laws and regulations. The software is provided "AS-IS," without warranties, and the co-founders and developers disclaim
 * all liability for any vulnerabilities, exploits, errors, or breaches that may occur. By using this contract, users accept all associated
 * risks and this disclaimer. The co-founders, developers, or related parties will not bear liability for any consequences of non-compliance.
 *
 * Redistribution and Use:
 * Redistribution, modification, or repurposing of this contract, in whole or in part, is strictly prohibited without express written
 * approval from all co-founders. Approval requests must be sent to the official email addresses of the co-founders, ensuring responses
 * are received directly from these addresses. Proposals for redistribution, modification, or repurposing must include a detailed explanation
 * of the intended changes or uses and the reasons behind them. The co-founders reserve the right to request additional information or
 * clarification as necessary. Approval is at the sole discretion of the co-founders and may be subject to conditions to uphold the
 * project’s integrity and the values of the Fair Crypto Foundation. Failure to obtain express written approval prior to any redistribution,
 * modification, or repurposing will result in a breach of these terms and immediate legal action.
 *
 * Copyright and License:
 * Copyright © 2023 Xenify (Simran Dhillon, Hardev Dhillon, Dayana Plaz). All rights reserved.
 * This software is primarily licensed under the Business Source License 1.1 (BUSL-1.1).
 * Please refer to the BUSL-1.1 documentation for complete license details.
 */
contract veXNF is
    IVeXNF,
    IERC721,
    IERC721Metadata,
    ReentrancyGuard
{

    /// ------------------------------------- LIBRARYS ------------------------------------- \\\

    /**
     * @notice Library for converting uint256 to string.
     */
    using Strings for uint256;

    /**
     * @notice Library for safe ERC20 transfers.
     */
    using SafeERC20 for IERC20;

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Address of the XNF token.
     */
    address public xnf;

    /**
     * @notice Address of the Auction contract, set during deployment and cannot be changed.
     */
    address public Auction;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Name of the NFT token.
     */
    string constant public name = "veXNF";

    /**
     * @notice Symbol of the NFT token.
     */
    string constant public symbol = "veXNF";

    /**
     * @notice Version of the contract.
     */
    string constant public version = "1.0.0";

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Number of decimals the token uses.
     */
    uint8 constant public decimals = 18;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Current epoch number.
     */
    uint public epoch;

    /**
     * @notice Current total supply.
     */
    uint public supply;

    /**
     * @notice Counter for new token ids.
     */
    uint internal _tokenID;

    /**
     * @notice Number of seconds in 1 day.
     */
    uint internal constant _DAY = 1 days;

    /**
     * @notice Number of seconds in 1 week.
     */
    uint internal constant _WEEK = 1 weeks;

    /**
     * @notice Maximum lock duration of 1 year.
     */
    uint internal constant _MAXTIME = 31536000; // 365 * 86400

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Scaled maximum lock duration of 1 year (for calculations).
     */
    int128 internal constant _iMAXTIME = 31536000; // 365 * 86400

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Interface ID for ERC165.
     */
    bytes4 internal constant _ERC165_INTERFACE_ID = 0x01ffc9a7;

    /**
     * @notice Interface ID for ERC721.
     */
    bytes4 internal constant _ERC721_INTERFACE_ID = 0x80ac58cd;

    /// ------------------------------------ MAPPINGS --------------------------------------- \\\

    /**
     * @notice Maps epoch to total supply point.
     */
    mapping (uint => Point) public pointHistory;

    /**
     * @notice Maps time to signed slope change.
     */
    mapping(uint => int128) public slope_changes;

    /**
     * @notice Maps token ID to owner address.
     */
    mapping (uint => address) internal _idToOwner;

    /**
     * @notice Maps token ID to lock info.
     */
    mapping (uint => LockedBalance) public locked;

    /**
     * @notice Maps user address to epoch count.
     */
    mapping (uint => uint) public user_point_epoch;

    /**
     * @notice Maps token ID to approved address.
     */
    mapping (uint => address) internal _idToApprovals;

    /**
     * @notice Maps owner address to token ids owned.
     */
    mapping (address => uint256[]) internal _ownerToIds;

    /**
     * @notice Interface support lookup.
     */
    mapping (bytes4 => bool) internal _supportedInterfaces;

    /**
     * @notice Maps address to number of tokens owned.
     */
    mapping (address => uint) internal _ownerToNFTokenCount;

    /**
     * @notice Maps token ID and epoch to user point.
     */
    mapping (uint => mapping (uint => Point)) public userPointHistory;

    /**
     * @notice Maps owner and operator addresses to approval.
     */
    mapping (address => mapping (address => bool)) internal _ownerToOperators;

    /// -------------------------------------- ERRORS --------------------------------------- \\\

    /**
     * @notice This error is thrown when the lock has already expired.
     */
    error LockExpired();

    /**
     * @notice This error is thrown when sum of weights is zero.
     */
    error WeightIsZero();

    /**
     * @notice This error is thrown when the caller attempts to clear the allowance from an NFT that does not belong to them.
     */
    error NotOwnerOfNFT();

    /**
     * @notice This error is thrown when NFT does not exist.
     */
    error NFTDoesNotExist();

    /**
     * @notice This error is thrown when trying to mint to the zero address.
     */
    error ZeroAddressMint();

    /**
    * @notice This error is thrown when the locked amount is zero.
    */
    error LockedAmountZero();

    /**
     * @notice This error is thrown when the deposit value is zero.
     */
    error ZeroValueDeposit();

    /**
     * @notice This error is thrown when a contract attempts to record an NFT owner that already exists.
     */
    error NFTAlreadyHasOwner();

    /**
     * @notice This error is thrown when the lock duration is too long.
     */
    error LockDurationTooLong();

    /**
     * @notice This error is thrown when the lock duration is too short.
     */
    error LockDurationTooShort();

    /**
     * @notice This error is thrown when the ERC721 receiver is missing.
     */
    error MissingERC721Receiver();

    /**
     * @notice This error is thrown when the receiver of the NFT does not implement the expected function.
     */
    error InvalidERC721Receiver();

    /**
     * @notice This error is thrown when the owner of the NFT tries to give allowance to his address.
     */
    error ApprovingToSameAddress();

    /**
     * @notice This error is thrown when the token is not owned.
     */
    error TokenNotOwned(uint tokenId);

    /**
     * @notice This error is thrown when not all tokens in the list are owned by the sender.
     */
    error NotAllTokensOwnedBySender();

    /**
     * @notice This error is thrown when trying to withdraw before the lock expires.
     */
    error LockNotExpiredYet(uint lockedEnd);

    /**
     * @notice Error thrown when the contract is already initialised.
     */
    error ContractInitialised(address contractAddress);

    /**
     * @notice This error is thrown when the sender is neither the owner nor an operator for the NFT.
     */
    error NotOwnerOrOperator(address sender, uint tokenId);

    /**
     * @notice This error is thrown when the sender is neither the owner nor approved for the NFT.
     */
    error NotApprovedOrOwner(address sender, uint tokenId);

    /**
     * @notice This error is thrown when the unlock time is set too short.
     */
    error UnlockTimeTooShort(uint unlockTime, uint minTime);

    /**
     * @notice This error is thrown when the token's owner does not match the expected owner.
     */
    error NotTokenOwner(address expectedOwner, uint tokenId);

    /**
     * @notice This error is thrown when the unlock time is set too early.
     */
    error UnlockTimeTooEarly(uint unlockTime, uint lockedEnd);

    /**
     * @notice This error is thrown when the unlock time exceeds the maximum allowed time.
     */
    error UnlockTimeExceedsMax(uint unlockTime, uint maxTime);

    /**
     * @notice This error is thrown when trying to approve the current owner of the NFT.
     */
    error ApprovingCurrentOwner(address approved, uint tokenId);

    /**
     * @notice This error is thrown when the sender is neither the owner nor approved for the NFT.
     */
    error NotTokenOwnerOrApproved(address sender, uint tokenId);

    /**
     * @notice This error is thrown when the sender is neither the owner nor approved for the NFT split.
     */
    error NotApprovedOrOwnerForSplit(address sender, uint tokenId);

    /**
     * @notice This error is thrown when the sender is neither the owner nor approved for the NFT withdrawal.
     */
    error NotApprovedOrOwnerForWithdraw(address sender, uint tokenId);

    /// --------------------------------------- ENUM ---------------------------------------- \\\

    /**
     * @notice Deposit type enum.
     */
    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE,
        SPLIT_TYPE
    }

    /// ------------------------------------- STRUCTURES ------------------------------------ \\\

    /**
     * @notice Point structure for slope and bias.
     * @param bias Integer bias component.
     * @param slope Integer slope component.
     * @param ts Timestamp.
     */
    struct Point {
        int128 bias;
        int128 slope;
        uint ts;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Represents a locked balance for a user's NFT.
     * @param amount Amount of tokens locked.
     * @param end Timestamp when tokens unlock.
     * @param decayEnd Timestamp when decay ends.
     * @param daysCount Number of days tokens are locked for.
     */
    struct LockedBalance {
        int128 amount;
        uint end;
        uint decayEnd;
        uint256 daysCount;
    }

    /// -------------------------------------- EVENTS --------------------------------------- \\\

    /**
     * @notice Emitted when supply changes.
     * @param prevSupply Previous total supply.
     * @param supply New total supply.
     */
    event Supply(
        uint prevSupply,
        uint supply
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Emitted on token deposit.
     * @param provider Account making the deposit.
     * @param tokenId ID of deposited token.
     * @param value Amount deposited.
     * @param locktime New unlock timestamp.
     * @param deposit_type Type of deposit.
     */
    event Deposit(
        address indexed provider,
        uint tokenId,
        uint value,
        uint locktime,
        DepositType deposit_type
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Emitted when tokens are withdrawn.
     * @param provider Account making withdrawal.
     * @param tokenId ID of withdrawn token.
     * @param value Amount withdrawn.
     */
    event Withdraw(
        address indexed provider,
        uint tokenId,
        uint value
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Emitted when a token is minted.
     * @param to Address minting token.
     * @param id Token id.
     * @param lockedAmount Amount of locked XNF tokens.
     * @param lockEnd Timestamp when lock will be ended.
     */
    event Mint(
        address indexed to,
        uint id,
        uint256 lockedAmount,
        uint256 lockEnd
    );

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Emitted when a token is burnt.
     * @param user Address of user.
     * @param tokenID ID of the token that will be burnt.
     */
    event Burn(
        address indexed user,
        uint256 tokenID
    );

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Initialises the contract with the given `XNF` token address and storage contract address.
     * @param _xnf Address of the `XNF` token.
     * @param _Auction Address of the `Auction` contract.
     */
    function initialise(
        address _xnf,
        address _Auction
    ) external {
        if (xnf != address(0))
            revert ContractInitialised(xnf);
        xnf = _xnf;
        pointHistory[0].ts = block.timestamp;
        _supportedInterfaces[_ERC165_INTERFACE_ID] = true;
        _supportedInterfaces[_ERC721_INTERFACE_ID] = true;
        Auction = _Auction;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sets approval for a third party to manage all of the sender's NFTs.
     * @param _operator The address to grant or revoke operator rights.
     * @param _approved Whether to approve or revoke the operator's rights.
     */
    function setApprovalForAll(
        address _operator,
        bool _approved
    )
        external
        override
    {
        if (_operator == msg.sender) {
            revert ApprovingToSameAddress();
        }
        _ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Transfers a specific NFT from one address to another.
     * @param _from Address currently owning the NFT.
     * @param _to Address to receive the NFT.
     * @param _tokenId ID of the NFT to be transferred.
     */
    function transferFrom(
        address _from,
        address _to,
        uint _tokenId
    )
        external
        override
    {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Safely transfers a specific NFT, ensuring the receiver is capable of handling it.
     * @param _from Address currently owning the NFT.
     * @param _to Address to receive the NFT.
     * @param _tokenId ID of the NFT to be transferred.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint _tokenId
    )
        external
        override
    {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Records a global checkpoint for data tracking.
     */
    function checkpoint() external override {
        _checkpoint(0, LockedBalance(0, 0, 0, 0), LockedBalance(0, 0, 0, 0));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Deposits tokens into a specific NFT lock.
     * @param _tokenId ID of the NFT where tokens will be deposited.
     * @param _value Amount of tokens to deposit.
     */
    function depositFor(
        uint _tokenId,
        uint _value
    )
        external
        override
        nonReentrant
    {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert NotApprovedOrOwner(msg.sender, _tokenId);
        }
        LockedBalance memory _locked = locked[_tokenId];
        if (_value == 0) {
            revert ZeroValueDeposit();
        }
        if (_locked.end <= block.timestamp) {
            revert LockExpired();
        }
        uint unlock_time = block.timestamp + locked[_tokenId].daysCount * _DAY;
        uint decayEnd = block.timestamp + locked[_tokenId].daysCount * _DAY / 6;
        decayEnd = decayEnd / _DAY * _DAY;
        _depositFor(_tokenId, _value, unlock_time, decayEnd, _locked, DepositType.DEPOSIT_FOR_TYPE);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Creates a new NFT lock for the sender, locking a specific amount of tokens.
     * @param _value Amount of tokens to lock.
     * @param _countOfDays Duration of the lock in days.
     * @return tokenId ID of the newly created NFT lock.
     */
    function createLock(
        uint _value,
        uint _countOfDays
    )
        external
        override
        nonReentrant
        returns (uint)
    {
        return _createLock(_value, _countOfDays, msg.sender);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Creates a new NFT lock for a specified address, locking a specific amount of tokens.
     * @param _value Amount of tokens to lock.
     * @param _countOfDays Duration of the lock in days.
     * @param _to Address for which the lock will be created.
     * @return tokenId ID of the newly created NFT lock.
     */
    function createLockFor(
        uint _value,
        uint _countOfDays,
        address _to
    )
        external
        override
        nonReentrant
        returns (uint)
    {
        return _createLock(_value, _countOfDays, _to);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Extends the unlock time of a specific NFT lock.
     * @param _tokenId ID of the NFT to extend.
     * @param _countOfDays Number of days to extend the unlock time.
     */
    function increaseUnlockTime(
        uint _tokenId,
        uint _countOfDays
    )
        external
        override
        nonReentrant
    {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert NotApprovedOrOwner(msg.sender, _tokenId);
        }
        LockedBalance memory _locked = locked[_tokenId];
        uint unlock_time = block.timestamp + _countOfDays * _DAY;
        uint decayEnd = block.timestamp + _countOfDays * _DAY / 6;
        decayEnd = decayEnd / _DAY * _DAY;
        if (_locked.end <= block.timestamp) {
            revert LockExpired();
        }
        if (unlock_time <= _locked.end) {
            revert UnlockTimeTooEarly(unlock_time, _locked.end);
        }
        if (unlock_time > block.timestamp + _MAXTIME) {
            revert UnlockTimeExceedsMax(unlock_time, block.timestamp + _MAXTIME);
        }
        if (unlock_time < block.timestamp + _WEEK) {
            revert UnlockTimeTooShort(unlock_time, block.timestamp + _WEEK);
        }
        _locked.daysCount = _countOfDays;
        _depositFor(_tokenId, 0, unlock_time, decayEnd, _locked, DepositType.INCREASE_UNLOCK_TIME);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Withdraws all tokens from an expired NFT lock.
     * @param _tokenId ID of the NFT from which to withdraw.
     */
    function withdraw(uint _tokenId)
        external
        override
        nonReentrant
    {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert NotApprovedOrOwnerForWithdraw(msg.sender, _tokenId);
        }
        address owner = _idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        if (block.timestamp < _locked.end) {
            revert LockNotExpiredYet(_locked.end);
        }
        uint value = uint(int256(_locked.amount));
        locked[_tokenId] = LockedBalance(0,0,0,0);
        uint supply_before = supply;
        supply = supply_before - value;
        _checkpoint(_tokenId, _locked, LockedBalance(0,0,0,0));
        IERC20(xnf).safeTransfer(owner, value);
        IAuction(Auction).claimAllForUser(owner);
        _burn(_tokenId);
        emit Burn(owner, _tokenId);
        emit Withdraw(owner, _tokenId, value);
        emit Supply(supply_before, supply_before - value);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Merges multiple NFTs into a single new NFT.
     * @param _from Array of NFT IDs to be merged.
     */
    function merge(uint[] memory _from)
        external
        override
    {
        address owner = _checkOwner(_from);
        (uint256 maxPeriod) = _getMaxPeriod(_from);
        uint value;
        uint256 length = _from.length;
        IAuction(Auction).claimAllForUser(msg.sender);
        for (uint256 i; i < length; i++) {
            LockedBalance memory _locked = locked[_from[i]];
            value += uint(int256(_locked.amount));
            locked[_from[i]] = LockedBalance(0, 0, 0, 0);
            _checkpoint(_from[i], _locked, LockedBalance(0, 0, 0, 0));
            _burn(_from[i]);
            emit Burn(msg.sender, _from[i]);
        }
        supply -= value;
        uint unlock_time = block.timestamp + maxPeriod * _DAY;
        uint decayEnd = block.timestamp + maxPeriod * _DAY / 6;
        decayEnd = decayEnd / _DAY * _DAY;
        ++_tokenID;
        uint _tokenId = _tokenID;
        _mint(owner, _tokenId);
        emit Mint(msg.sender, _tokenId, value, unlock_time);
        locked[_tokenId].daysCount = maxPeriod;
        _depositFor(_tokenId, value, unlock_time, decayEnd, locked[_tokenId], DepositType.MERGE_TYPE);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Splits a single NFT into multiple new NFTs with specified amounts.
     * @param amounts Array of token amounts for each new NFT.
     * @param _tokenId ID of the NFT to be split.
     */
    function split(
        uint[] calldata amounts,
        uint _tokenId
    )
        external
        override
    {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert NotApprovedOrOwnerForSplit(msg.sender, _tokenId);
        }
        address _to = _idToOwner[_tokenId];
        LockedBalance memory _locked = locked[_tokenId];
        uint value = uint(int256(_locked.amount));
        if (value == 0) {
            revert LockedAmountZero();
        }
        supply = supply - value;
        uint totalWeight;
        uint256 length = amounts.length;
        for (uint i; i < length; i++) {
            totalWeight += amounts[i];
        }
        if (totalWeight == 0) {
            revert WeightIsZero();
        }
        locked[_tokenId] = LockedBalance(0, 0, 0, 0);
        _checkpoint(_tokenId, _locked, LockedBalance(0, 0, 0, 0));
        IAuction(Auction).claimAllForUser(_idToOwner[_tokenId]);
        _burn(_tokenId);
        emit Burn(msg.sender, _tokenId);
        uint unlock_time = _locked.end;
        if (unlock_time <= block.timestamp) {
            revert LockExpired();
        }
        uint _value;
        for (uint j; j < length; j++) {
            ++_tokenID;
            _tokenId = _tokenID;
            _mint(_to, _tokenId);
            _value = value * amounts[j] / totalWeight;
            locked[_tokenId].daysCount = _locked.daysCount;
            emit Mint(msg.sender, _tokenId, _value, unlock_time);
            _depositFor(_tokenId, _value, unlock_time, _locked.decayEnd, locked[_tokenId], DepositType.SPLIT_TYPE);
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Returns the token URI of the specified NFT.
     * @dev This function requires the specified NFT. It returns the token URI,
     * which consists of the base URI concatenated with the token ID and ".json" extension.
     * @param tokenId The ID of the NFT to query the token URI of.
     * @return The token URI of the specified NFT.
     */
    function tokenURI(uint256 tokenId)
        external
        view
        override
        returns (string memory)
    {
        string memory baseURI = _baseURI();
        if (_idToOwner[tokenId] == address(0)) {
            revert NFTDoesNotExist();
        }
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the total token supply at a specific timestamp.
     * @param timestamp The specific point in time to retrieve the supply.
     * @return The total token supply at the given timestamp.
     */
    function getPastTotalSupply(uint256 timestamp)
        external
        view
        override
        returns (uint)
    {
        return totalSupplyAtT(timestamp);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the count of NFTs owned by a specific address.
     * @param _owner The address whose NFT count is to be determined.
     * @return The number of NFTs owned by the given address.
     */
    function balanceOf(address _owner)
        external
        view
        override
        returns (uint)
    {
        return _balance(_owner);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the approved address for a specific NFT.
     * @param _tokenId The unique identifier of the NFT.
     * @return The address approved to manage the given NFT.
     */
    function getApproved(uint _tokenId)
        external
        view
        override
        returns (address)
    {
        return _idToApprovals[_tokenId];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Determines if an operator is approved to manage all NFTs of an owner.
     * @param _owner The owner of the NFTs.
     * @param _operator The potential operator.
     * @return True if the operator is approved, false otherwise.
     */
    function isApprovedForAll(
        address _owner,
        address _operator
    )
        external
        view
        override
        returns (bool)
    {
        return (_ownerToOperators[_owner])[_operator];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Checks if an address is approved to manage a specific NFT or if it's the owner.
     * @param _spender The address in question.
     * @param _tokenId The unique identifier of the NFT.
     * @return True if the address is approved or is the owner, false otherwise.
     */
    function isApprovedOrOwner(
        address _spender,
        uint _tokenId
    )
        external
        view
        override
        returns (bool)
    {
        return _isApprovedOrOwner(_spender, _tokenId);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Verifies if the contract supports a specific interface.
     * @param _interfaceID The ID of the interface in question.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 _interfaceID)
        external
        view
        override
        returns (bool)
    {
        return _supportedInterfaces[_interfaceID];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the most recent voting power decrease rate for a specific NFT.
     * @param _tokenId The unique identifier of the NFT.
     * @return The slope value representing the rate of voting power decrease.
     */
    function get_last_user_slope(uint _tokenId)
        external
        view
        override
        returns (int128)
    {
        uint uepoch = user_point_epoch[_tokenId];
        return userPointHistory[_tokenId][uepoch].slope;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the timestamp of a specific checkpoint for an NFT.
     * @param _tokenId The unique identifier of the NFT.
     * @param _idx The index of the user's epoch.
     * @return The timestamp of the specified checkpoint.
     */
    function userPointHistory_ts(
        uint _tokenId,
        uint _idx
    )
        external
        view
        override
        returns (uint)
    {
        return userPointHistory[_tokenId][_idx].ts;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the end timestamp of a lock for a specific NFT.
     * @param _tokenId The unique identifier of the NFT.
     * @return The timestamp when the NFT's lock expires.
     */
    function lockedEnd(uint _tokenId)
        external
        view
        override
        returns (uint)
    {
        return locked[_tokenId].end;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the balance of a specific NFT at a given timestamp.
     * @param _tokenId The unique identifier of the NFT.
     * @param _t The specific point in time to retrieve the balance.
     * @return The balance of the NFT at the given timestamp.
     */
    function balanceOfNFTAt(
        uint _tokenId,
        uint _t
    )
        external
        view
        override
        returns (uint)
    {
        return _balanceOfNFT(_tokenId, _t);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the combined balance of all NFTs owned by an address at a specific timestamp.
     * @param _user The owner's address.
     * @param _t The specific point in time to retrieve the total balance.
     * @return totalBalanceOf The combined balance of all NFTs owned by the address at the given timestamp.
     */
    function totalBalanceOfNFTAt(
        address _user,
        uint _t
    )
        external
        view
        override
        returns (uint256 totalBalanceOf)
    {
        uint256 length = _ownerToIds[_user].length;
        for (uint256 i; i < length; i++) {
            totalBalanceOf += _balanceOfNFT(_ownerToIds[_user][i], _t);
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves a list of NFT IDs owned by a specific address.
     * @param _user The address whose NFT IDs are to be listed.
     * @return An array of NFT IDs owned by the specified address.
     */
    function userToIds(address _user)
        external
        view
        override
        returns (uint256[] memory)
    {
        return _ownerToIds[_user];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the current total supply of tokens.
     * @return The current total token supply.
     */
    function totalSupply()
        external
        view
        override
        returns (uint)
    {
        return totalSupplyAtT(block.timestamp);
    }

    /// --------------------------------- PUBLIC FUNCTIONS ---------------------------------- \\\

    /**
     * @notice Grants or changes approval for an address to manage a specific NFT.
     * @param _approved The address to be granted approval.
     * @param _tokenId The ID of the NFT to be approved.
     */
    function approve(
        address _approved,
        uint _tokenId
    )
        public
        override
    {
        address owner = _idToOwner[_tokenId];
        if (owner == address(0)) {
            revert TokenNotOwned(_tokenId);
        }
        if (_approved == owner) {
            revert ApprovingCurrentOwner(_approved, _tokenId);
        }
        bool senderIsOwner = (owner == msg.sender);
        bool senderIsApprovedForAll = (_ownerToOperators[owner])[msg.sender];
        if (!senderIsOwner && !senderIsApprovedForAll) {
            revert NotOwnerOrOperator(msg.sender, _tokenId);
        }
        _idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Safely transfers an NFT to another address, ensuring the recipient is capable of receiving it.
     * @param _from The current owner of the NFT.
     * @param _to The address to receive the NFT. If it's a contract, it must implement `onERC721Received`.
     * @param _tokenId The ID of the NFT to be transferred.
     * @param _data Additional data to send with the transfer, used in `onERC721Received` if `_to` is a contract.
     */
    function safeTransferFrom(
        address _from,
        address _to,
        uint _tokenId,
        bytes memory _data
    )
        public
        override
    {
        _transferFrom(_from, _to, _tokenId, msg.sender);
        if (_isContract(_to)) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 response) {
                if (response != IERC721Receiver(_to).onERC721Received.selector) {
                    revert InvalidERC721Receiver();
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert MissingERC721Receiver();
                }
                else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the owner of a specific NFT.
     * @param _tokenId The ID of the NFT whose owner is to be determined.
     * @return The address of the owner of the specified NFT.
     */
    function ownerOf(uint _tokenId)
        public
        view
        override
        returns (address)
    {
        return _idToOwner[_tokenId];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Calculates the total voting power at a specific timestamp.
     * @param t The timestamp at which to determine the total voting power.
     * @return The total voting power at the specified timestamp.
     */
    function totalSupplyAtT(uint t)
        public
        view
        override
        returns (uint)
    {
        uint _epoch = epoch;
        Point memory last_point = pointHistory[_epoch];
        return _supply_at(last_point, t);
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Clears the approval of a specific NFT.
     * @param _owner The address of the current owner of the NFT.
     * @param _tokenId The unique identifier of the NFT.
     */
    function _clearApproval(
        address _owner,
        uint _tokenId
    ) internal {
        if (_idToOwner[_tokenId] != _owner) {
            revert NotOwnerOfNFT();
        }
        if (_idToApprovals[_tokenId] != address(0)) {
            _idToApprovals[_tokenId] = address(0);
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Transfers an NFT from one address to another.
     * @param _from The address of the current owner of the NFT.
     * @param _to The address to receive the NFT.
     * @param _tokenId The unique identifier of the NFT.
     * @param _sender The address initiating the transfer.
     */
    function _transferFrom(
        address _from,
        address _to,
        uint _tokenId,
        address _sender
    ) internal {
        if (!_isApprovedOrOwner(_sender, _tokenId)) {
            revert NotApprovedOrOwner(_sender, _tokenId);
        }
        IAuction(Auction).updateStats(_from);
        IAuction(Auction).updateStats(_to);
        _clearApproval(_from, _tokenId);
        _removeTokenFrom(_from, _tokenId);
        _addTokenTo(_to, _tokenId);
        emit Transfer(_from, _to, _tokenId);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Assigns ownership of an NFT to a specific address.
     * @param _to The address to receive the NFT.
     * @param _tokenId The unique identifier of the NFT.
     */
    function _addTokenTo(
        address _to,
        uint _tokenId
    ) internal {
        if (_idToOwner[_tokenId] != address(0)) {
            revert NFTAlreadyHasOwner();
        }
        _idToOwner[_tokenId] = _to;
        _ownerToIds[_to].push(_tokenId);
        _ownerToNFTokenCount[_to] += 1;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Mints a new NFT and assigns it to a specific address.
     * @param _to The address to receive the minted NFT.
     * @param _tokenId The unique identifier for the new NFT.
     * @return A boolean indicating if the minting was successful.
     */
    function _mint(
        address _to,
        uint _tokenId
    )
        internal
        returns (bool)
    {
        if (_to == address(0)) {
            revert ZeroAddressMint();
        }
        _addTokenTo(_to, _tokenId);
        if (_isContract(_to)) {
            try IERC721Receiver(_to).onERC721Received(address(0), _to, _tokenId, "") returns (bytes4 response) {
                if (response != IERC721Receiver(_to).onERC721Received.selector) {
                    revert InvalidERC721Receiver();
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert MissingERC721Receiver();
                }
                else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Removes an NFT from its owner, effectively clearing its ownership.
     * @param _from The address of the current owner of the NFT.
     * @param _tokenId The unique identifier of the NFT.
     */
    function _removeTokenFrom(
        address _from,
        uint _tokenId
    ) internal {
        if (_idToOwner[_tokenId] != _from) {
            revert NotTokenOwner(_from, _tokenId);
        }
        _idToOwner[_tokenId] = address(0);
        uint256 length = _ownerToIds[_from].length;
        if (length == 1) {
            _ownerToIds[_from].pop();
        } else {
             for (uint256 i; i < length; i++) {
                if (_ownerToIds[_from][i] == _tokenId) {
                    if (i != length - 1) {
                        uint256 tokenIdToChange = _ownerToIds[_from][length - 1];
                        _ownerToIds[_from][i] = tokenIdToChange;
                    }
                    _ownerToIds[_from].pop();
                    break;
                }
            }
        }
        _ownerToNFTokenCount[_from] -= 1;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Permanently destroys an NFT.
     * @param _tokenId The unique identifier of the NFT to be burned.
     */
    function _burn(uint _tokenId) internal {
        if (!_isApprovedOrOwner(msg.sender, _tokenId)) {
            revert NotTokenOwnerOrApproved(msg.sender, _tokenId);
        }
        address owner = ownerOf(_tokenId);
        _clearApproval(owner, _tokenId);
        _removeTokenFrom(owner, _tokenId);
        emit Transfer(owner, address(0), _tokenId);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Records data to a checkpoint for tracking historical data.
     * @param _tokenId The unique identifier of the NFT. If 0, no user checkpoint is created.
     * @param old_locked The previous locked balance details.
     * @param new_locked The new locked balance details.
     */
    function _checkpoint(
        uint _tokenId,
        LockedBalance memory old_locked,
        LockedBalance memory new_locked
    ) internal {
        Point memory u_old;
        Point memory u_new;
        uint _epoch = epoch;
        int128 old_dslope = 0;
        int128 new_dslope = 0;
        if (_tokenId != 0) {
            if (old_locked.decayEnd > block.timestamp && old_locked.amount != 0) {
                u_old.slope = old_locked.amount * 6 / _iMAXTIME;
                u_old.bias = u_old.slope * int128(int256(old_locked.decayEnd) - int256(block.timestamp));
            }
            if (new_locked.decayEnd > block.timestamp && new_locked.amount != 0) {
                u_new.slope = new_locked.amount * 6 / _iMAXTIME;
                u_new.bias = u_new.slope * int128(int256(new_locked.decayEnd) - int256(block.timestamp));
            }
            old_dslope = slope_changes[old_locked.decayEnd];
            if (new_locked.decayEnd != 0) {
                if (new_locked.decayEnd == old_locked.decayEnd) {
                    new_dslope = old_dslope;
                } else {
                    new_dslope = slope_changes[new_locked.decayEnd];
                }
            }
        }
        Point memory last_point = Point({bias: 0, slope: 0, ts: block.timestamp});
        if (_epoch != 0) {
            last_point = pointHistory[_epoch];
        }
        uint last_checkpoint = last_point.ts;
        {
            uint t_i = (last_checkpoint / _DAY) * _DAY;
            for (uint i; i < 61; ++i) {
                t_i += _DAY;
                int128 d_slope = 0;
                if (t_i > block.timestamp) {
                    t_i = block.timestamp;
                } else {
                    d_slope = slope_changes[t_i];
                }
                last_point.bias -= last_point.slope * int128(int256(t_i) - int256(last_checkpoint));
                last_point.slope += d_slope;
                if (last_point.bias < 0) {
                    last_point.bias = 0;
                }
                if (last_point.slope < 0) {
                    last_point.slope = 0;
                }
                last_checkpoint = t_i;
                last_point.ts = t_i;
                _epoch += 1;
                if (t_i != block.timestamp) {
                    pointHistory[_epoch] = last_point;
                } else {
                    break;
                }
            }
        }
        epoch = _epoch;
        if (_tokenId != 0) {
            last_point.slope += (u_new.slope - u_old.slope);
            last_point.bias += (u_new.bias - u_old.bias);
            if (last_point.slope < 0) {
                last_point.slope = 0;
            }
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
        }
        pointHistory[_epoch] = last_point;
        if (_tokenId != 0) {
            if (old_locked.decayEnd > block.timestamp) {
                old_dslope += u_old.slope;
                if (new_locked.decayEnd == old_locked.decayEnd) {
                    old_dslope -= u_new.slope;
                }
                slope_changes[old_locked.decayEnd] = old_dslope;
            }
            if (new_locked.decayEnd > block.timestamp) {
                if (new_locked.decayEnd > old_locked.decayEnd) {
                    new_dslope -= u_new.slope;
                    slope_changes[new_locked.decayEnd] = new_dslope;
                }
            }
            uint user_epoch = user_point_epoch[_tokenId] + 1;
            user_point_epoch[_tokenId] = user_epoch;
            u_new.ts = block.timestamp;
            userPointHistory[_tokenId][user_epoch] = u_new;
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Deposits and locks tokens associated with an NFT.
     * @dev This function handles the internal logic for depositing and locking tokens. It updates the user's
     * locked balance, the total supply of locked tokens, and emits the appropriate events. It also
     * ensures the tokens are transferred into the contract when needed.
     * @param _tokenId The unique identifier of the NFT that holds the lock.
     * @param _value The amount of tokens to deposit.
     * @param unlock_time The timestamp when the tokens should be unlocked.
     * @param decayEnd The timestamp when the decay period ends, relevant for certain types of locks.
     * @param locked_balance The previous locked balance details.
     * @param deposit_type The type of deposit being made, defined by the DepositType enum.
     */
    function _depositFor(
        uint _tokenId,
        uint _value,
        uint unlock_time,
        uint decayEnd,
        LockedBalance memory locked_balance,
        DepositType deposit_type
    ) internal {
        LockedBalance memory _locked = locked_balance;
        uint supply_before = supply;
        supply = supply_before + _value;
        LockedBalance memory old_locked;
        (old_locked.amount, old_locked.end, old_locked.decayEnd) = (_locked.amount, _locked.end, _locked.decayEnd);
        _locked.amount += int128(int256(_value));
        if (unlock_time != 0) {
            _locked.end = unlock_time;
            _locked.decayEnd = decayEnd;
        }
        locked[_tokenId] = _locked;
        _checkpoint(_tokenId, old_locked, _locked);
        address from = msg.sender;
        if (_value != 0 && deposit_type != DepositType.MERGE_TYPE && deposit_type != DepositType.SPLIT_TYPE) {
            IERC20(xnf).safeTransferFrom(from, address(this), _value);
        }
        emit Deposit(from, _tokenId, _value, _locked.end, deposit_type);
        emit Supply(supply_before, supply_before + _value);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Creates a lock by depositing tokens for a specified duration.
     * @param _value The amount of tokens to deposit.
     * @param _countOfDays The duration (in days) to lock the tokens.
     * @param _to The address for which the lock is being created.
     * @return The unique identifier of the newly created NFT representing the lock.
     */
    function _createLock(
        uint _value,
        uint _countOfDays,
        address _to
    )
        internal
        returns (uint)
    {
        uint unlock_time = block.timestamp + _countOfDays * _DAY;
        uint decayEnd = ((block.timestamp + _countOfDays * _DAY / 6) /_DAY) * _DAY;
        if (_value == 0) {
            revert ZeroValueDeposit();
        }
        if (unlock_time < block.timestamp + _WEEK) {
            revert LockDurationTooShort();
        }
        if (unlock_time > block.timestamp + _MAXTIME) {
            revert LockDurationTooLong();
        }
        ++_tokenID;
        uint _tokenId = _tokenID;
        _mint(_to, _tokenId);
        emit Mint(msg.sender, _tokenId, _value, unlock_time);
        locked[_tokenId].daysCount = _countOfDays;
        _depositFor(_tokenId, _value, unlock_time, decayEnd, locked[_tokenId], DepositType.CREATE_LOCK_TYPE);
        return _tokenId;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Checks if a given address is authorised to transfer a specific NFT.
     * @param _spender The address attempting the transfer.
     * @param _tokenId The unique identifier of the NFT.
     * @return A boolean indicating if the spender is authorized.
     */
    function _isApprovedOrOwner(
        address _spender,
        uint _tokenId
    )
        internal
        view
        returns (bool)
    {
        address owner = _idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == _idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (_ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the number of NFTs owned by a specific address.
     * @param _owner The address whose balance is being queried.
     * @return The number of NFTs owned by the address.
     */
    function _balance(address _owner)
        internal
        view
        returns (uint)
    {
        return _ownerToNFTokenCount[_owner];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Retrieves the voting power of a specific NFT at a given epoch time.
     * @param _tokenId The unique identifier of the NFT.
     * @param _t The epoch time for which the voting power is being queried.
     * @return The voting power of the NFT at the specified time.
     */
    function _balanceOfNFT(
        uint _tokenId,
        uint _t
    )
        internal
        view
        returns (uint)
    {
        uint _epoch = user_point_epoch[_tokenId];
        if (_epoch == 0) {
            return 0;
        }
        else {
            Point memory last_point = userPointHistory[_tokenId][_epoch];
            if (_t < last_point.ts) {
                uint256 left = 0;
                uint256 right = _epoch;
                while (left <= right) {
                    uint256 mid = (left + right + 1) / 2;
                    last_point = userPointHistory[_tokenId][mid];
                    Point memory last_point_right = userPointHistory[_tokenId][mid + 1];
                    if (last_point.ts <= _t && _t < last_point_right.ts) {
                        break;
                    }
                    else if (_t < last_point.ts) {
                        if (mid == 0)
                            return 0;
                        right = mid - 1;
                    } else {
                        left = mid + 1;
                    }
                }
            }
            last_point.bias -= last_point.slope * int128(int256(_t) - int256(last_point.ts));
            if (last_point.bias < 0) {
                last_point.bias = 0;
            }
            return uint(int256(last_point.bias));
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Verifies that the msg.sender is the owner of all provided NFT IDs.
     * @param _ids An array of NFT IDs to verify ownership.
     * @return owner The address of the owner if all NFTs in the list are owned by the msg.sender.
     */
    function _checkOwner(uint[] memory _ids)
        internal
        view
        returns (address owner)
    {
        uint256 count;
        uint256 length = _ids.length;
        for (uint256 i; i < length; i++) {
            if (ownerOf(_ids[i]) == msg.sender) {
                count++;
            }
        }
        if (count != length) {
            revert NotAllTokensOwnedBySender();
        }
        owner = _idToOwner[_ids[0]];
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Determines the longest lock duration from a list of NFT IDs.
     * @param _ids An array of NFT IDs to check.
     * @return maxPeriod The maximum lock duration (in days) found among the provided NFTs.
     */
    function _getMaxPeriod(uint[] memory _ids)
        internal
        view
        returns (uint256 maxPeriod)
    {
        maxPeriod = locked[_ids[0]].daysCount;
        uint256 length = _ids.length;
        for (uint256 i = 1; i < length; i++) {
            if (maxPeriod < locked[_ids[i]].daysCount) {
                maxPeriod = locked[_ids[i]].daysCount;
            }
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Checks if a given address is associated with a contract.
     * @param account The address to verify.
     * @return A boolean indicating whether the address is a contract (true) or an externally owned account (false).
     */
    function _isContract(address account)
        internal
        view
        returns (bool)
    {
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size != 0;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Computes the total voting power at a specific past time using a given point as a reference.
     * @param point The reference point containing bias and slope values.
     * @param t The epoch time for which the total voting power is being calculated.
     * @return The total voting power at the specified time.
     */
    function _supply_at(
        Point memory point,
        uint t
    )
        internal
        view
        returns (uint)
    {
        Point memory last_point = point;
        if (t < last_point.ts) {
            uint256 left = 0;
            uint256 right = epoch;
            while (left <= right) {
                uint256 mid = (left + right + 1) / 2;
                last_point = pointHistory[mid];
                Point memory last_point_right = pointHistory[mid + 1];
                if (last_point.ts <= t && t < last_point_right.ts) {
                    break;
                }
                else if (t < last_point.ts) {
                    if (mid == 0)
                        return 0;
                    right = mid - 1;
                } else {
                    left = mid + 1;
                }
            }
        }
        uint t_i = (last_point.ts / _DAY) * _DAY;
        for (uint i; i < 61; ++i) {
            t_i += _DAY;
            int128 d_slope = 0;
            if (t_i > t) {
                t_i = t;
            } else {
                d_slope = slope_changes[t_i];
            }
            last_point.bias -= last_point.slope * int128(int256(t_i) - int256(last_point.ts));
            if (t_i == t) {
                break;
            }
            last_point.slope += d_slope;
            last_point.ts = t_i;
        }
        if (last_point.bias < 0) {
            last_point.bias = 0;
        }
        return uint(uint128(last_point.bias));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Returns the base URI for the veXNF NFT contract.
     * @return Base URI for the veXNF NFT contract.
     * @dev This function is internal and pure, it's used to get the base URI for the veXNF NFT contract.
     */
    function _baseURI()
        internal
        pure
        returns (string memory)
    {
        return "https://xnf-info.xenify.io/arbitrum/metadata/";
    }

    /// ------------------------------------------------------------------------------------- \\\
}