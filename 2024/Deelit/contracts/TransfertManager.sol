// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeeCollector, LibFee} from "../fee/FeeCollector.sol";
import {LibTransaction, LibOffer} from "../libraries/LibTransaction.sol";
import {LibBytes} from "../libraries/LibBytes.sol";
import {LibVerdict} from "../libraries/LibVerdict.sol";
import {LibConflict} from "../libraries/LibConflict.sol";

/// @custom:security-contact dev@deelit.net
abstract contract TransfertManager is Initializable, FeeCollector, ContextUpgradeable {
    using Math for uint;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using LibBytes for bytes;

    /// @dev Initialize the contract
    /// @param fees the fees details
    function __TransfertManager_init(LibFee.Fee calldata fees) internal onlyInitializing {
        __FeeCollector_init(fees);
        __TransfertManager_init_unchained();
    }

    function __TransfertManager_init_unchained() internal onlyInitializing {
        // empty function
    }

    /// @dev allow the contract to receive native currency
    receive() external payable {}

    /// @dev Process to the payment of an offer. The payment is stored by the contract.
    /// @param tx_ the payment and offer details
    function _doPay(LibTransaction.Transaction calldata tx_) internal {
        // compute amount to pay regarding the fees
        uint256 amount = LibOffer.calculateTotalPrice(tx_.offer);
        uint256 feeAmount = LibFee.calculateFee(amount, _getFees().amount_bp);

        if (tx_.offer.token_address == address(0)) {
            _doPayNative(amount, feeAmount);
        } else {
            _doPayErc20(IERC20(tx_.offer.token_address), amount, feeAmount);
        }
    }

    /// @dev Process to the payment of an offer in native currency. The payment is stored by the contract.
    /// @param amount_ the amount to pay
    /// @param feeAmount_ the fee amount to pay
    function _doPayNative(uint256 amount_, uint256 feeAmount_) private {
        (bool success, uint256 amountWithFee) = amount_.tryAdd(feeAmount_);
        assert(success);

        // native currency payment
        require(msg.value >= amountWithFee, "TransfertManager: not enough value");

        // transfer the fee amount to the contract
        _collectFee(feeAmount_);

        // refund the excess
        uint256 rest = msg.value - amountWithFee;
        if (rest > 0) {
            payable(_msgSender()).sendValue(rest);
        }
    }

    /// @dev Process to the payment of an offer in ERC20. The payment is stored by the contract.
    /// @param token the token address
    /// @param amount the amount to pay
    /// @param feeAmount the fee amount to pay
    function _doPayErc20(IERC20 token, uint256 amount, uint256 feeAmount) private {
        // verify allowance
        uint256 allowance = token.allowance(_msgSender(), address(this));
        require(allowance >= amount + feeAmount, "TransfertManager: allowance too low");

        // process the payment
        _collectFeeErc20From(token, _msgSender(), feeAmount);
        token.safeTransferFrom(_msgSender(), address(this), amount);
    }

    /// @dev Procces to the claim of a payment. The payment is released to the payee.
    /// @param tx_ the payment and offer details
    function _doClaim(LibTransaction.Transaction calldata tx_) internal {
        // compute amount to claim regarding the fees
        uint256 amount = LibOffer.calculateTotalPrice(tx_.offer);
        address payable payee = payable(tx_.payment.destination_address.toAddress());

        if (tx_.offer.token_address == address(0)) {
            // native currency payment
            payee.sendValue(amount);
        } else {
            // ERC20 payment
            IERC20 token = IERC20(tx_.offer.token_address);
            token.safeTransfer(payee, amount);
        }
    }

    /// @dev Process to the resolution of a conflict. The payment is transferred to the granted party.
    /// @param tx_ the payment and offer details
    /// @param conflict the conflict details
    /// @param verdict the verdict details
    function _doResolve(LibTransaction.Transaction calldata tx_, LibConflict.Conflict calldata conflict, LibVerdict.Verdict calldata verdict, address payerAddress) internal {
        // check the verdict amount
        uint256 amount = LibOffer.calculateTotalPrice(tx_.offer);

        // define payee and payer
        address payable payee = payable(tx_.payment.destination_address.toAddress());
        address payable payer = payable(payerAddress);

        address payable plaintiff = payable(conflict.from_address);
        address payable defendant = plaintiff == payee ? payer : payee;
        address payable grantee = verdict.granted ? plaintiff : defendant;

        // transfer the amounts
        if (tx_.offer.token_address == address(0)) {
            // native currency payment
            grantee.sendValue(amount);
        } else {
            // ERC20 payment
            IERC20 token = IERC20(tx_.offer.token_address);
            token.safeTransfer(grantee, amount);
        }
    }
}