// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {vXEN} from "../vXEN.sol";

/*
 * @title vXENFactory
 *
 * @notice A factory contract for deploying vXEN instances.
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
contract vXENFactory {

    /// --------------------------------- EXTERNAL FUNCTION --------------------------------- \\\

    /**
     * @notice Deploys a new instance of the vXEN contract with the provided parameters.
     * @param ratio The ratio for vXEN.
     * @param _XEN XEN token address.
     * @param _gateway Gateway address.
     * @param _gasService Gas service address.
     * @param _endpoint Endpoint address.
     * @param _wormholeRelayer Wormhole relayer address.
     * @return The address of the newly deployed vXEN contract.
     */
    function deployvXEN(
        uint256 ratio,
        address _XEN,
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    )
        external
        returns (address)
    {
        vXEN vxen = new vXEN(
            ratio,
            _XEN,
            _gateway,
            _gasService,
            _endpoint,
            _wormholeRelayer
        );
        return address(vxen);
    }

    /// ------------------------------------------------------------------------------------- \\\
}
