// SPDX-License-Identifier: Ridotto Core License

/*
.------..------..------..------..------..------.     .------..------..------.
|G.--. ||L.--. ||O.--. ||B.--. ||A.--. ||L.--. |.-.  |R.--. ||N.--. ||G.--. |
| :/\: || :/\: || :/\: || :(): || (\/) || :/\: ((5)) | :(): || :(): || :/\: |
| :\/: || (__) || :\/: || ()() || :\/: || (__) |'-.-.| ()() || ()() || :\/: |
| '--'G|| '--'L|| '--'O|| '--'B|| '--'A|| '--'L| ((1)) '--'R|| '--'N|| '--'G|
`------'`------'`------'`------'`------'`------'  '-'`------'`------'`------'
*/

pragma solidity ^0.8.9;

interface IGlobalRngEvents {
    event Initialised();

    event newRngRequest(uint256 providerId, uint256 reqId, address requester);

    event setProvider(uint256 providerId, string providerName, bool providerStatus, address providerAddress);

    event createProvider(uint256 providerId);

    event newRngResult(uint256 pId, uint256 id, uint256 result);
}
