// SPDX-License-Identifier: BUSL-1.1

// OpenZeppelin Contracts (last updated v4.7.0) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.10;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

/*
 * @title ERC2771Context Library
 *
 * @notice Context variant with ERC2771 support.
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
abstract contract ERC2771Context is Context {

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Trusted forwarder for the contract.
     */
    address internal _trustedForwarder;

    /// ------------------------------------ CONSTRUCTOR ------------------------------------ \\\

    /**
     * @notice Initialises the contract with a trusted forwarder address.
     * @param trustedForwarder The trusted forwarding contract.
     */
    constructor(address trustedForwarder) {
        _trustedForwarder = trustedForwarder;
    }

    /// ----------------------------------- PUBLIC FUNCTION --------------------------------- \\\

    /**
     * @notice Checks if an address is the trusted forwarder.
     * @dev Returns true if the forwarder matches the stored value.
     * @param forwarder The address to check.
     * @return true If the forwarder is trusted.
     */
    function isTrustedForwarder(address forwarder)
        public
        view
        virtual
        returns (bool)
    {
        return forwarder == _trustedForwarder;
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Determine the msg.sender.
     * @dev Uses trusted forwarder if available.
     * @return sender The determined sender address.
     */
    function _msgSender()
        internal
        view
        virtual
        override
        returns (address sender)
    {
        if (isTrustedForwarder(msg.sender)) {
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
        else {
            return super._msgSender();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Get the msg.data.
     * @dev Uses data from trusted forwarder if available.
     * @return calldata The msg.data for the call.
     */
    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        }
        else {
            return super._msgData();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}