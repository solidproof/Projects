// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ILottery, LibTransaction, LibVerdict} from "./interfaces/ILottery.sol";
import {LibPayment} from "../libraries/LibPayment.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {LibLottery} from "../libraries/LibLottery.sol";
import {LibOffer} from "../libraries/LibOffer.sol";
import {LibEIP712} from "../libraries/LibEIP712.sol";
import {LibAccess} from "../libraries/LibAccess.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDeelitProtocol} from "../protocol/interfaces/IDeelitProtocol.sol";
import {RandomConsumer, IRandomProducer} from "../random/RandomConsumer.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {FeeCollector, LibFee} from "../fee/FeeCollector.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Lottery
/// @author d0x4545lit
/// @notice Lottery contract to manage lottery creation, participation, drawing and payment.
/// @custom:security-contact dev@deelit.net
contract Lottery is ILottery, RandomConsumer, FeeCollector, AccessManagedUpgradeable, EIP712Upgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address payable;
    using Math for uint256;

    // Define the maximum protocol fees in basis points
    uint48 public constant MAX_FEES_BP = 25_00; // 25%

    // lottery state
    struct LotteryState {
        // lottery infos
        LotteryStatus status;
        uint256 randomRequestId; // random number request id to determine winner
        // protocol infos
        bytes32 paymentHash; // protocol payment hash
        bytes32 verdictHash; // protocol verdict hash
        // tickets infos
        uint256 ticketCount;
        mapping(uint256 => address) tickets; // ticket number to participants mapping. note: index starts at 1
        BitMaps.BitMap redeemed; // tickets redeemed bitmap
    }

    /// @custom:storage-location erc7201:deelit.storage.Lottery
    struct LotteryStorage {
        IAccessManager _manager;
        IDeelitProtocol _protocol;
        bytes32 _protocolDomainSeparator; // cached EIP712 domain separator
        mapping(bytes32 => LotteryState) _lotteries; // lottery state mapping
        uint256 _protocolMinVestingPeriod; // minimal vesting period for protocol payments
    }

    // keccak256(abi.encode(uint256(keccak256("deelit.storage.Lottery")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LotteryStorageLocation = 0xd1cf091c595fc493f0b5779990274e2d871a6e5a155133013bc5fd60bcd09200;

    /// @dev Get storage struct of the contract.
    function _getLotteryStorage() private pure returns (LotteryStorage storage $) {
        assembly {
            $.slot := LotteryStorageLocation
        }
    }

    /// @dev Modifier to check if the caller is the winner of the lottery.
    modifier onlyWinner(bytes32 lotteryHash) {
        require(msg.sender == _getWinnerAddress(lotteryHash), "Lottery: only winner can call");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract.
    /// @param manager_  The access manager contract
    /// @param protocol_  The DeelitProtocol contract
    /// @param randomProducer_ The RandomProducer contract
    /// @param fees_ The initial fees
    /// @param protocolMinVestingPeriod_  The minimal vesting period for protocol payments
    function initialize(
        IAccessManager manager_,
        IDeelitProtocol protocol_,
        IRandomProducer randomProducer_,
        LibFee.Fee calldata fees_,
        uint256 protocolMinVestingPeriod_
    ) public initializer {
        require(fees_.amount_bp <= MAX_FEES_BP, "DeelitProtocol: Fee amount too high");

        __AccessManaged_init(address(manager_));
        __RandomConsumer_init(randomProducer_);
        __EIP712_init("deelit.net", "1");
        __Pausable_init();
        __FeeCollector_init(fees_);
        __UUPSUpgradeable_init();

        _setProtocol(protocol_);
        _setProtocolMinVestingPeriod(protocolMinVestingPeriod_);
    }

    /// @dev Get the protocol contract.
    function getProtocol() external view returns (IDeelitProtocol) {
        return _getProtocol();
    }

    /// @dev Internal function to get the protocol contract.
    function _getProtocol() private view returns (IDeelitProtocol) {
        LotteryStorage storage $ = _getLotteryStorage();
        return $._protocol;
    }

    /// @dev Set the protocol contract.
    function setProtocol(IDeelitProtocol protocol_) external restricted {
        _setProtocol(protocol_);
    }

    /// @dev Internal function to set the protocol contract.
    /// @param protocol_ the DeelitProtocol contract
    function _setProtocol(IDeelitProtocol protocol_) internal {
        require(address(protocol_) != address(0), "Lottery: protocol address is zero");
        (, string memory name, string memory version, uint256 chainId, address verifyingContract, , ) = protocol_.eip712Domain();

        LotteryStorage storage $ = _getLotteryStorage();
        $._protocol = protocol_;
        $._protocolDomainSeparator = LibEIP712.buildDomainSeparator(LibEIP712.EIP712Domain(name, version, chainId, verifyingContract));
    }

    /// @dev Set the fees for the lottery. The fees are in basis points and should be less than 25%.
    /// @param fees The fees details
    function setFees(LibFee.Fee calldata fees) external restricted {
        require(fees.amount_bp <= MAX_FEES_BP, "Lottery: fees amount is too high");
        _setFees(fees);
    }

    /// @dev Set the minimal vesting period for protocol payments.
    /// The minimal vesting period is the minimal period for a protocol payment to be locked.
    function setProtocolMinVestingPeriod(uint256 protocolMinVestingPeriod_) external restricted {
        _setProtocolMinVestingPeriod(protocolMinVestingPeriod_);
    }

    /// @dev Internal function to set the minimal vesting period for protocol payments.
    /// @param protocolMinVestingPeriod_ the minimal vesting period for protocol payments
    function _setProtocolMinVestingPeriod(uint256 protocolMinVestingPeriod_) internal {
        require(protocolMinVestingPeriod_ > 0, "Lottery: protocol min vesting period is zero");

        LotteryStorage storage $ = _getLotteryStorage();
        $._protocolMinVestingPeriod = protocolMinVestingPeriod_;
    }

    /// @dev Get the minimal vesting period for protocol payments.
    function getProtocolMinVestingPeriod() external view returns (uint256) {
        LotteryStorage storage $ = _getLotteryStorage();
        return $._protocolMinVestingPeriod;
    }

    /// @dev Set the access manager contract.
    function setRandomProducer(IRandomProducer randomProducer) external restricted {
        _setRandomProducer(randomProducer);
    }

    /// @inheritdoc ILottery
    function createLottery(LibLottery.Lottery calldata lottery) external whenNotPaused returns (bytes32 lotteryHash) {
        lotteryHash = _hash(LibLottery.hash(lottery));

        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        require($_lottery.status == LotteryStatus.None, "Lottery: lottery already exists");
        require(lottery.product_hash > 0, "Lottery: transaction hash is zero");
        require(lottery.nb_tickets > 0, "Lottery: nbTickets is zero");
        require(lottery.ticket_price > 0, "Lottery: ticketPrice is zero");
        require(LibFee.equal(lottery.fee, _getFees()), "Lottery: fee bp mismatch");
        // Note: no need to check protocol fee, it is checked on payment at protocol level.

        // store lottery state
        $_lottery.status = LotteryStatus.Open;

        // log event
        emit Created(lotteryHash, lottery);
    }

    /// @inheritdoc ILottery
    function participate(LibLottery.Lottery calldata lottery) external payable override whenNotPaused {
        bytes32 lotteryHash = _hash(LibLottery.hash(lottery));
        require(_exist(lotteryHash), "Lottery: lottery not found");
        require(!_isCanceled(lotteryHash), "Lottery: canceled");
        require(!_isFilled(lotteryHash, lottery), "Lottery: already filled");

        // update state
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        $_lottery.ticketCount++;
        $_lottery.tickets[$_lottery.ticketCount] = msg.sender;

        // process payment
        if (lottery.token_address == address(0)) {
            _doParticipateNative(lottery);
        } else {
            _doParticipateErc20(IERC20(lottery.token_address), lottery);
        }

        // log event
        emit Participated(lotteryHash, $_lottery.ticketCount, msg.sender);
    }

    /// @dev Process native payment for participation.
    /// - Check if the value sent is enough to participate in the lottery.
    /// - Refund excess value.
    /// @param lottery The lottery details
    function _doParticipateNative(LibLottery.Lottery calldata lottery) private {
        uint256 totalWithFees = LibLottery.calculateParticipation(lottery);
        require(msg.value >= totalWithFees, "Lottery: insufficient value");

        // refund excess value
        uint256 rest = msg.value - totalWithFees;
        if (rest > 0) {
            payable(msg.sender).sendValue(rest);
        }
    }

    /// @dev Process ERC20 payment for participation.
    /// - Check if the allowance is enough to participate in the lottery.
    /// - Transfer the tokens.
    ///@param token The ERC20 token
    ///@param lottery The lottery details

    function _doParticipateErc20(IERC20 token, LibLottery.Lottery calldata lottery) private {
        uint256 totalWithFees = LibLottery.calculateParticipation(lottery);
        require(token.allowance(msg.sender, address(this)) >= totalWithFees, "Lottery: insufficient allowance");

        // transfer token
        token.safeTransferFrom(msg.sender, address(this), totalWithFees);
    }

    /// @inheritdoc ILottery
    function redeem(LibLottery.Lottery calldata lottery, uint256 ticketNumber) external override whenNotPaused {
        bytes32 lotteryHash = _hash(LibLottery.hash(lottery));
        require(_isCanceled(lotteryHash), "Lottery: not canceled");
        require(_isTicket(lotteryHash, ticketNumber), "Lottery: not a valid ticket");
        require(!_isRedeemed(lotteryHash, ticketNumber), "Lottery: already redeemed");

        // update state
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        BitMaps.set($_lottery.redeemed, ticketNumber);

        // calculate redemption
        uint256 totalWithFees = LibLottery.calculateParticipation(lottery);

        // process redemption
        address participant = $_lottery.tickets[ticketNumber];
        if (lottery.token_address == address(0)) {
            payable(participant).sendValue(totalWithFees);
        } else {
            IERC20 erc20 = IERC20(lottery.token_address);
            erc20.safeTransfer(participant, totalWithFees);
        }

        // log event
        emit Redeemed(lotteryHash, ticketNumber, participant);
    }

    /// @inheritdoc ILottery
    function cancel(LibLottery.Lottery calldata lottery) external override whenNotPaused {
        bytes32 lotteryHash = _hash(LibLottery.hash(lottery));
        require(_exist(lotteryHash), "Lottery: lottery not found");
        require(!_isPaid(lotteryHash), "Lottery: already paid");
        require(!_isCanceled(lotteryHash), "Lottery: already canceled");

        // if not expire and not the lottery creator, check if admin
        if (lottery.expiration_time > block.timestamp && lottery.from_address != msg.sender) {
            (bool isAdmin, ) = IAccessManager(authority()).hasRole(LibAccess.ADMIN_ROLE, msg.sender);
            require(isAdmin, "Lottery: not admin");
        }

        // update state
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        $_lottery.status = LotteryStatus.Canceled;

        // log event
        emit Canceled(lotteryHash, msg.sender);
    }

    /// @inheritdoc ILottery
    function draw(LibLottery.Lottery calldata lottery) external override whenNotPaused {
        bytes32 lotteryHash = _hash(LibLottery.hash(lottery));

        require(!_isCanceled(lotteryHash), "Lottery: canceled");
        require(!_isDrawn(lotteryHash), "Lottery: already drawn");
        require(_isFilled(lotteryHash, lottery), "Lottery: not filled");

        // request random number
        uint256 requestId = _requestRandomNumber();

        // update state
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        $_lottery.status = LotteryStatus.Drawn;
        $_lottery.randomRequestId = requestId;

        emit Drawn(lotteryHash, requestId);
    }

    ///  @dev Important! The protocol payment requester is responsible to align transaction inputs with the lottery datas.
    /// !WARNING! Note that we do not check the offer price versus the lottery price here.
    /// - It is not an issue for native payment because even if the protocol attempt to refund the excess payments, the transaction will failed cause the lottery contract is not a payable.
    /// - For ERC20 payment, we may implement a check so we prevent locking tokens on this contract.
    function pay(LibLottery.Lottery calldata lottery, LibTransaction.Transaction calldata transaction, bytes calldata paymentSignature) external override whenNotPaused {
        bytes32 lotteryHash = _hash(LibLottery.hash(lottery));
        address winner = _getWinnerAddress(lotteryHash); //  _getWinnerAddress(lotteryHash) also check if lottery is drawn.

        require(!_isCanceled(lotteryHash), "Lottery: canceled");
        require(winner != address(0), "Lottery: winner not available");
        require(transaction.offer.from_address == winner, "Lottery: from address mismatch with winner address");
        require(transaction.offer.product_hash == lottery.product_hash, "Lottery: product hash mismatch");
        require(transaction.offer.token_address == lottery.token_address, "Lottery: asset mismatch");
        require(transaction.payment.vesting_period >= _getLotteryStorage()._protocolMinVestingPeriod, "Lottery: vesting period is too short");

        // compute payment hash
        bytes32 paymentHash = _protocolHash(LibPayment.hash(transaction.payment));

        // update lottery state
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        $_lottery.status = LotteryStatus.Paid;
        $_lottery.paymentHash = paymentHash;

        // process payment
        (uint256 lotteryFee, uint256 totalWithProtocolFee) = LibLottery.calculateLotteryPrices(lottery);

        if (lottery.token_address == address(0)) {
            _collectFee(_getFees().recipient, lotteryFee);

            _getProtocol().pay{value: totalWithProtocolFee}(transaction, paymentSignature, winner);
        } else {
            IERC20 erc20 = IERC20(lottery.token_address);

            _collectFeeErc20(erc20, lotteryFee);

            erc20.approve(address(_getProtocol()), totalWithProtocolFee);
            _getProtocol().pay(transaction, paymentSignature, winner);
        }

        // log event
        emit Paid(lotteryHash, transaction);
    }

    /// @dev Internal function to get the lottery state.
    function _getLotteryState(bytes32 lotteryHash) internal view returns (LotteryState storage) {
        LotteryStorage storage $ = _getLotteryStorage();
        return $._lotteries[lotteryHash];
    }

    /// @inheritdoc ILottery
    function getWinnerAddress(bytes32 lotteryHash) external view override returns (address) {
        return _getWinnerAddress(lotteryHash);
    }

    /// @dev Get the winner address of a lottery.
    /// @param lotteryHash  The hash of the lottery
    function _getWinnerAddress(bytes32 lotteryHash) internal view returns (address) {
        uint256 winnerTicket = _getWinnerTicket(lotteryHash);
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.tickets[winnerTicket];
    }

    /// @inheritdoc ILottery
    function getWinnerTicket(bytes32 lotteryHash) external view override returns (uint256) {
        return _getWinnerTicket(lotteryHash);
    }

    /// @dev Internal function to get the winner ticket of a lottery.
    /// @param lotteryHash The hash of the lottery
    function _getWinnerTicket(bytes32 lotteryHash) internal view returns (uint256) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        if ($_lottery.status < LotteryStatus.Drawn) {
            return 0;
        }

        (bool fullfilled, uint256 randomWord) = _getRequestStatus($_lottery.randomRequestId);

        if (fullfilled) {
            return (randomWord % $_lottery.ticketCount) + 1; // random btw 1 and ticketCount
        } else {
            return 0;
        }
    }

    /// @inheritdoc ILottery
    function getLotteryStatus(bytes32 lotteryHash) external view override returns (LotteryStatus, uint256, address) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return ($_lottery.status, $_lottery.ticketCount, _isDrawn(lotteryHash) ? _getWinnerAddress(lotteryHash) : address(0));
    }

    /// @inheritdoc ILottery
    function getTicketOwner(bytes32 lotteryHash, uint256 ticketNumber) external view returns (address) {
        require(_isTicket(lotteryHash, ticketNumber), "Lottery: not a valid ticket");
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.tickets[ticketNumber];
    }

    /// @inheritdoc ILottery
    function isFilled(LibLottery.Lottery calldata lottery) external view returns (bool) {
        return _isFilled(_hash(LibLottery.hash(lottery)), lottery);
    }

    /// @dev Internal function to check if a lottery is filled.
    /// @param lotteryHash  The hash of the lottery
    /// @param lottery  The lottery details
    function _isFilled(bytes32 lotteryHash, LibLottery.Lottery calldata lottery) internal view returns (bool) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.ticketCount == lottery.nb_tickets;
    }

    /// @dev Internal function to check if a lottery is drawn.
    /// @param lotteryHash  The hash of the lottery
    function _isDrawn(bytes32 lotteryHash) internal view returns (bool) {
        require(_exist(lotteryHash), "Lottery: lottery not found");

        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.randomRequestId > 0;
    }

    /// @dev Internal function to check if a lottery is paid.
    /// @param lotteryHash  The hash of the lottery
    function _isPaid(bytes32 lotteryHash) internal view returns (bool) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.status == LotteryStatus.Paid;
    }

    /// @dev Internal function to check if a lottery is canceled.
    /// @param lotteryHash  The hash of the lottery
    function _isCanceled(bytes32 lotteryHash) internal view returns (bool) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.status == LotteryStatus.Canceled;
    }

    /// @inheritdoc ILottery
    function isTicket(bytes32 lotteryHash, uint256 ticketNumber) external view returns (bool) {
        return _isTicket(lotteryHash, ticketNumber);
    }

    /// @dev Internal function to check if a ticket is valid.
    /// @param lotteryHash The hash of the lottery
    /// @param ticketNumber The ticket number to check
    function _isTicket(bytes32 lotteryHash, uint256 ticketNumber) internal view returns (bool) {
        require(_exist(lotteryHash), "Lottery: lottery not found");
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.tickets[ticketNumber] != address(0);
    }

    /// @inheritdoc ILottery
    function isRedeemed(bytes32 lotteryHash, uint256 ticketNumber) external view returns (bool) {
        return _isRedeemed(lotteryHash, ticketNumber);
    }

    /// @dev Internal function to check if a ticket is redeemed.
    /// @param lotteryHash The hash of the lottery
    /// @param ticketNumber The ticket number to check
    function _isRedeemed(bytes32 lotteryHash, uint256 ticketNumber) internal view returns (bool) {
        require(_isTicket(lotteryHash, ticketNumber), "Lottery: not a valid ticket");
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return BitMaps.get($_lottery.redeemed, ticketNumber);
    }

    /// @dev Internal function to check if a lottery exists.
    /// @param lotteryHash The hash of the lottery
    function _exist(bytes32 lotteryHash) internal view returns (bool) {
        LotteryState storage $_lottery = _getLotteryState(lotteryHash);
        return $_lottery.status != LotteryStatus.None;
    }

    /// @dev Compute the hash of a data structure following EIP-712 spec.
    /// @param structHash the structHash(message) to hash
    function _hash(bytes32 structHash) private view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    /// @dev Compute the hash of a data structure following EIP-712 spec for the DeelitProtocol contract.
    /// @param structHash the structHash(message) to hash
    function _protocolHash(bytes32 structHash) internal view returns (bytes32) {
        LotteryStorage storage $ = _getLotteryStorage();
        return LibEIP712.hashTypedDataV4($._protocolDomainSeparator, structHash);
    }

    /// @dev Authorize an upgrade of the protocol. Only the admin can authorize an upgrade.
    function _authorizeUpgrade(address newImplementation) internal override restricted {
        // nothing to do
    }

    /// @dev Pause the lottery.
    function pause() external restricted {
        _pause();
    }

    /// @dev Unpause the lottery.
    function unpause() external restricted {
        _unpause();
    }
}