// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPaymentProcessor.sol";
import "./EmergencyGuard.sol";

contract PaymentProcessor is
    IPaymentProcessor,
    Ownable,
    AccessControlEnumerable,
    ReentrancyGuard,
    EmergencyGuard
{
    // Role allowed to do admin operations like withdrawal.
    bytes32 public constant ADMIN = keccak256("ADMIN");

    // Role allowed to do processor operations like executing and refunding payments.
    bytes32 public constant PROCESSOR = keccak256("PROCESSOR");

    // Token instance used for payments
    IERC20 internal immutable _token;

    // Payments by user
    mapping(address => bytes32[]) internal _paymentsByUser;

    // Payments by id
    mapping(bytes32 => Payment) internal _paymentsById;

    constructor(address tokenAddress) {
        // Add creator to admin role
        _setupRole(ADMIN, _msgSender());

        // Set role admin for roles
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(PROCESSOR, ADMIN);

        // Initialize token instance
        _token = IERC20(tokenAddress);
    }

    function lastPayment(
        address user
    ) external view override returns (Payment memory payment) {
        bytes32[] memory paymentIds = _paymentsByUser[user];
        bytes32 lastPaymentId = paymentIds[paymentIds.length - 1];

        return _paymentsById[lastPaymentId];
    }

    function paymentsByUser(
        address user
    ) external view override returns (Payment[] memory payments) {
        bytes32[] memory paymentIds = _paymentsByUser[user];

        Payment[] memory paymentsArr = new Payment[](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            paymentsArr[i] = _paymentsById[paymentIds[i]];
        }

        return paymentsArr;
    }

    function paymentAtIndex(
        address user,
        uint256 index
    ) external view override returns (Payment memory payment) {
        bytes32 paymentId = _paymentsByUser[user][index];

        return _paymentsById[paymentId];
    }

    function paymentById(
        bytes32 paymentId
    ) external view override returns (Payment memory payment) {
        return _paymentsById[paymentId];
    }

    function paymentCount(
        address user
    ) external view override returns (uint256 count) {
        return _paymentsByUser[user].length;
    }

    function executePayment(
        address user,
        uint256 amount
    ) external override onlyRole(PROCESSOR) nonReentrant {
        // Transfer token from user
        require(
            _token.transferFrom(user, address(this), amount),
            "PaymentProcessor: Token transfer failed"
        );

        // Generate unique payment id
        bytes32 paymentId = _generateIdentifier(user, amount, block.timestamp);

        // Create payment object
        Payment memory payment = Payment(
            paymentId,
            user,
            amount,
            block.timestamp,
            false,
            0
        );

        // Add payments to mappings
        _paymentsByUser[user].push(paymentId);
        _paymentsById[paymentId] = payment;

        // Emit event
        emit PaymentDone(paymentId, user, amount);
    }

    function refundPayment(
        bytes32 paymentId
    ) external override onlyRole(PROCESSOR) nonReentrant {
        // Get payment
        Payment memory payment = _paymentsById[paymentId];

        // Ensure it's not refunded yet
        require(
            !payment.isRefunded,
            "PaymentProcessor: Payment was already refunded"
        );

        // Refund token
        require(
            _token.transfer(payment.user, payment.amount),
            "PaymentProcessor: Token transfer failed"
        );

        // Update mappings
        _paymentsById[paymentId].isRefunded = true;
        _paymentsById[paymentId].refundedAt = block.timestamp;

        // Emit event
        emit PaymentRefunded(paymentId, payment.user, payment.amount);
    }

    function emergencyWithdraw(
        uint256 amount
    ) external override onlyRole(ADMIN) {
        super._emergencyWithdraw(amount);
    }

    function emergencyWithdrawToken(
        address tokenToWithdraw,
        uint256 amount
    ) external override onlyRole(ADMIN) {
        super._emergencyWithdrawToken(tokenToWithdraw, amount);
    }

    /**
     * Generates an unique identifier for a payment
     *
     * @param user address - User address
     * @param amount uint256 - Payment amount
     * @param executedAt uint256 - Time when payment was executed
     *
     * @return id bytes32 - Unique id
     */
    function _generateIdentifier(
        address user,
        uint256 amount,
        uint256 executedAt
    ) private pure returns (bytes32 id) {
        return keccak256(abi.encodePacked(user, amount, executedAt));
    }
}