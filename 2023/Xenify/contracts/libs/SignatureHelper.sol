// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

/*
 * @title SignatureHelper Library
 *
 * @notice A library to assist with signature operations.
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
library SignatureHelper {

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Returns message hash used for signature.
     * @dev Hash contains user, amount, partner, partnerPercent, feeSplitter, nonce, and chainId.
     * This message hash can be used for verification purposes in different parts of the contract.
     * @param user Address of user involved in the transaction.
     * @param amount Transaction amount.
     * @param partner Address of the partner involved in the transaction.
     * @param partnerPercent Percentage of the transaction amount allocated to the partner.
     * @param feeSplitter Address of the fee splitter contract.
     * @param nonce Transaction nonce, used to prevent replay attacks.
     * @return Message hash.
     */
    function _getMessageHash(
        address user,
        uint256 amount,
        address partner,
        uint256 partnerPercent,
        address feeSplitter,
        uint256 nonce
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            user,
            amount,
            partner,
            partnerPercent,
            feeSplitter,
            nonce,
            block.chainid
            )
        );
    }

    /// ------------------------------------------------------------------------------ \\\

    /**
     * @notice Returns message hash used for signature in the context of split fee transactions.
     * @dev Hash contains user, amount, token, nonce, and chainId.
     * This specific message hash structure is tailored for transactions involving fee splitting.
     * @param user Address of user involved in the transaction.
     * @param amount Transaction amount.
     * @param token Address of the token involved in the transaction.
     * @param nonce Transaction nonce, used to prevent replay attacks.
     * @return Message hash.
     */
    function _getMessageHashForSplitFee(
        address user,
        uint256 amount,
        address token,
        uint256 nonce
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            user,
            amount,
            token,
            nonce,
            block.chainid
            )
        );
    }

    /// ------------------------------------------------------------------------------ \\\

    /**
     * @notice Returns Ethereum signed message hash.
     * @dev Prepends Ethereum signed message header.
     * @param _messageHash Message hash.
     * @return Ethereum signed message hash.
     */
    function _getEthSignedMessageHash(bytes32 _messageHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }

    /// ------------------------------------------------------------------------------ \\\

    /**
     * @notice Splits signature into r, s, v.
     * @dev Allows recovering signer from signature.
     * @param signature Signature to split.
     * @return r Recovery parameter.
     * @return s Recovery parameter.
     * @return v Recovery parameter.
     */
    function _splitSignature(bytes memory signature)
        internal
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(
            signature.length == 65,
            "SignatureHelper: Invalid signature length"
        );
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}