// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IDeelitProtocol, LibTransaction, LibAcceptance, LibConflict, LibVerdict} from "./interfaces/IDeelitProtocol.sol";
import {TransfertManager, LibFee} from "./TransfertManager.sol";
import {LibPayment} from "../libraries/LibPayment.sol";
import {LibOffer} from "../libraries/LibOffer.sol";
import {LibAccess} from "../libraries/LibAccess.sol";

/// @custom:security-contact dev@deelit.net
contract DeelitProtocol is IDeelitProtocol, TransfertManager, AccessManagedUpgradeable, EIP712Upgradeable, PausableUpgradeable, UUPSUpgradeable {
    using SignatureChecker for address;

    // Define the maximum protocol fees in basis points
    uint48 public constant MAX_FEES_BP = 25_00; // 25%

    // Define auto acceptance due to expiration
    bytes32 public constant AUTO_ACCEPTANCE = keccak256("AUTO_ACCEPTANCE");

    /// @notice Payment state.
    struct PaymentState {
        address payer; // the payer address to refund. Also used to identify initiated payment
        bytes32 acceptance; // acceptance hash
        bytes32 conflict; // conflict hash
        bytes32 verdict; // verdict hash
        uint256 vesting; // vesting time for payment claim => payment time + vesting_period
    }

    /// @custom:storage-location erc7201:deelit.storage.DeelitProtocol
    struct DeelitProtocolStorage {
        // Mapping of payment hashes to payment states
        mapping(bytes32 => PaymentState) _payments;
    }

    // keccak256(abi.encode(uint256(keccak256("deelit.storage.DeelitProtocol")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DeelitProtocolStorageLocation = 0x498d0df3a7b2a0a1eb46763a5ff0e597e34f5c2a5111a9795b59a880fe830b00;

    function _getDeelitProtocolStorage() private pure returns (DeelitProtocolStorage storage $) {
        assembly {
            $.slot := DeelitProtocolStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the DeelitProtocol contract.
    function initialize(IAccessManager manager_, LibFee.Fee calldata fees_) public initializer {
        require(fees_.amount_bp <= MAX_FEES_BP, "DeelitProtocol: Fee amount too high");

        __AccessManaged_init(address(manager_));
        __Pausable_init();
        __EIP712_init("deelit.net", "1");
        __TransfertManager_init(fees_);
        __UUPSUpgradeable_init();
    }

    /// @dev Set the fees for the protocol.
    /// @param fees_ the fees to set. see LibFee.Fee struct.
    function setFees(LibFee.Fee calldata fees_) external restricted {
        require(fees_.amount_bp <= MAX_FEES_BP, "DeelitProtocol: Fee amount too high");
        _setFees(fees_);
    }

    /// @dev Get the payment state for a given payment hash.
    /// @param paymentHash the payment hash to get the state for.
    function _getPayment(bytes32 paymentHash) private view returns (PaymentState storage) {
        DeelitProtocolStorage storage $ = _getDeelitProtocolStorage();
        return $._payments[paymentHash];
    }

    /// @inheritdoc IDeelitProtocol
    function pay(LibTransaction.Transaction calldata tx_, bytes calldata paymentSignature, address refundAddress) external payable whenNotPaused {
        // compute hashes
        bytes32 paymentHash = _hash(LibPayment.hash(tx_.payment));
        bytes32 offerHash = _hash(LibOffer.hash(tx_.offer));

        PaymentState storage $_payment = _getPayment(paymentHash);
        require($_payment.payer == address(0), "DeelitProtocol: Payment already initiated");
        require(tx_.payment.offer_hash == offerHash, "DeelitProtocol: Invalid payment offer hash");
        require(tx_.payment.destination_address.length == 20, "DeelitProtocol: Invalid payment destination address");
        require(tx_.payment.expiration_time > block.timestamp, "DeelitProtocol: Payment expired");

        // verify signature and validate payment datas
        _verifySignature(tx_.payment.from_address, paymentHash, paymentSignature);

        // update payment state
        $_payment.payer = refundAddress != address(0) ? refundAddress : msg.sender; // if no refund address, use the sender as payer
        $_payment.vesting = block.timestamp + tx_.payment.vesting_period;

        // process payment
        _doPay(tx_);

        emit Payed(paymentHash, tx_);
    }

    /// @inheritdoc IDeelitProtocol
    function claim(LibTransaction.Transaction calldata tx_) external whenNotPaused {
        // compute payment hash
        bytes32 paymentHash = _hash(LibPayment.hash(tx_.payment));
        bytes32 offerHash = _hash(LibOffer.hash(tx_.offer));

        // retrieve payment state
        PaymentState storage $_payment = _getPayment(paymentHash);

        // validate inputs and state
        require(tx_.payment.offer_hash == offerHash, "DeelitProtocol: Invalid payment offer hash");
        require($_payment.payer != address(0), "DeelitProtocol: Payment not paid");
        require($_payment.acceptance == bytes32(0), "DeelitProtocol: Payment already claimed");
        require($_payment.conflict == bytes32(0), "DeelitProtocol: Payment in conflict");
        require($_payment.vesting < block.timestamp, "DeelitProtocol: Payment deadline not reached. acceptance needed");

        // update payment state
        $_payment.acceptance = AUTO_ACCEPTANCE;

        // process claim payment
        _doClaim(tx_);

        emit Claimed(paymentHash, AUTO_ACCEPTANCE, LibAcceptance.Acceptance(address(0), 0));
    }

    /// @inheritdoc IDeelitProtocol
    function claimAccepted(LibTransaction.Transaction calldata tx_, LibAcceptance.Acceptance calldata acceptance, bytes calldata acceptanceSignature) external whenNotPaused {
        // compute hashes
        bytes32 paymentHash = _hash(LibPayment.hash(tx_.payment));
        bytes32 offerHash = _hash(LibOffer.hash(tx_.offer));
        bytes32 acceptanceHash = _hash(LibAcceptance.hash(acceptance));

        // retrieve payment state
        PaymentState storage $_payment = _getPayment(paymentHash);

        require(tx_.payment.offer_hash == offerHash, "DeelitProtocol: Invalid payment offer hash");
        require(acceptance.payment_hash == paymentHash, "DeelitProtocol: Invalid acceptance payment hash");
        require(acceptance.from_address == tx_.offer.from_address, "DeelitProtocol: Invalid acceptance from address");
        require($_payment.payer != address(0), "DeelitProtocol: Payment not paid");
        require($_payment.acceptance == bytes32(0), "DeelitProtocol: Payment already claimed");
        require($_payment.conflict == bytes32(0), "DeelitProtocol: Payment in conflict");

        // verify signature if not called by payer
        if (msg.sender != acceptance.from_address) {
            _verifySignature(acceptance.from_address, acceptanceHash, acceptanceSignature);
        }

        // update payment state
        $_payment.acceptance = acceptanceHash;

        // process claim payment
        _doClaim(tx_);

        emit Claimed(paymentHash, acceptanceHash, acceptance);
    }

    /// @inheritdoc IDeelitProtocol
    function conflict(LibTransaction.Transaction calldata tx_, LibConflict.Conflict calldata conflict_, bytes calldata conflictSignature) external whenNotPaused {
        // compute hashes
        bytes32 paymentHash = _hash(LibPayment.hash(tx_.payment));
        bytes32 offerHash = _hash(LibOffer.hash(tx_.offer));
        bytes32 conflictHash = _hash(LibConflict.hash(conflict_));

        // retrieve payment state
        PaymentState storage $_payment = _getPayment(paymentHash);

        require(conflict_.from_address == tx_.offer.from_address || conflict_.from_address == tx_.payment.from_address, "DeelitProtocol: Invalid conflict issuer");
        require(conflict_.payment_hash == paymentHash, "DeelitProtocol: Invalid conflict payment hash");
        require(tx_.payment.offer_hash == offerHash, "DeelitProtocol: Invalid payment offer hash");
        require($_payment.payer != address(0), "DeelitProtocol: Payment not paid");
        require($_payment.acceptance == bytes32(0), "DeelitProtocol: Payment already claimed");
        require($_payment.conflict == bytes32(0), "DeelitProtocol: Payment already in conflict");
        require($_payment.verdict == bytes32(0), "DeelitProtocol: Payment already resolved");

        // verify conflict signature if caller not originator
        if (msg.sender != conflict_.from_address) {
            _verifySignature(conflict_.from_address, conflictHash, conflictSignature);
        }

        // update payment state
        $_payment.conflict = conflictHash;

        emit Conflicted(paymentHash, conflictHash, conflict_);
    }

    /// @inheritdoc IDeelitProtocol
    function resolve(
        LibTransaction.Transaction calldata tx_,
        LibConflict.Conflict calldata conflict_,
        LibVerdict.Verdict calldata verdict,
        bytes calldata signature
    ) external whenNotPaused {
        // compute hashes
        bytes32 paymentHash = _hash(LibPayment.hash(tx_.payment));
        bytes32 verdictHash = _hash(LibVerdict.hash(verdict));
        bytes32 conflictHash = _hash(LibConflict.hash(conflict_));

        // retrieve payment state
        PaymentState storage $_payment = _getPayment(paymentHash);

        (bool isIssuerJudge, ) = IAccessManager(authority()).hasRole(LibAccess.JUDGE_ROLE, verdict.from_address);
        require(isIssuerJudge, "DeelitProtocol: Invalid verdict issuer");
        require($_payment.payer != address(0), "DeelitProtocol: Payment not paid");
        require($_payment.acceptance == bytes32(0), "DeelitProtocol: Payment already claimed");
        require($_payment.conflict != bytes32(0), "DeelitProtocol: Payment not in conflict");
        require($_payment.verdict == bytes32(0), "DeelitProtocol: Payment already resolved");
        require($_payment.conflict == verdict.conflict_hash, "DeelitProtocol: Invalid conflict hash");
        require(verdict.conflict_hash == conflictHash, "DeelitProtocol: Verdict conflict hash mismatch");

        // verify signature if not called by judge
        if (msg.sender != verdict.from_address) {
            _verifySignature(verdict.from_address, verdictHash, signature);
        }

        // update payment state
        $_payment.verdict = verdictHash;

        // process verdict
        _doResolve(tx_, conflict_, verdict, $_payment.payer);

        emit Verdicted(paymentHash, verdictHash, verdict);
    }

    /// @dev Get the payment state for a given payment hash.
    /// @param paymentHash the payment hash to get the state for.
    function getPaymentState(bytes32 paymentHash) external view returns (PaymentState memory) {
        return _getPayment(paymentHash);
    }

    /// @inheritdoc IDeelitProtocol
    function getPaymentStatus(bytes32 paymentHash) external view override returns (bool paid, bytes32 claimHash, bytes32 conflictHash, bytes32 verdictHash) {
        PaymentState storage $_payment = _getPayment(paymentHash);
        return ($_payment.payer != address(0), $_payment.acceptance, $_payment.conflict, $_payment.verdict);
    }

    /// @dev validate a signature originator. Handle EIP1271 and EOA signatures using SignatureChecker library.
    /// @param signer the expected signer address
    /// @param digest the digest hash supposed to be signed
    /// @param signature the signature to verify
    function _verifySignature(address signer, bytes32 digest, bytes calldata signature) private view {
        bool isValid = signer.isValidSignatureNow(digest, signature);
        require(isValid, "DeelitProtocol: Invalid signature");
    }

    /// @dev Compute the hash of a data structure following EIP-712 spec.
    /// @param dataHash_ the structHash(message) to hash
    function _hash(bytes32 dataHash_) private view returns (bytes32) {
        return _hashTypedDataV4(dataHash_);
    }

    /// @dev Authorize an upgrade of the protocol. Only the admin can authorize an upgrade.
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Pause the protocol.
    function pause() external restricted {
        _pause();
    }

    /// @dev Unpause the protocol.
    function unpause() external restricted {
        _unpause();
    }
}