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

import "./IGlobalRngEvents.sol";

interface IGlobalRng is IGlobalRngEvents {
    struct provider {
        string name;
        bool isActive;
        address providerAddress;
        uint256 gasLimit;
        uint256[6] paramData;
    }

    function providerCounter() external view returns (uint256);

    function requestRandomWords(uint256 _pId, bytes memory _functionData) external returns (uint256);

    function viewRandomResult(uint256 _pId, uint256 _callCount) external view returns (uint256);

    fallback() external;

    function addProvider(provider memory _providerInfo) external returns (uint256);

    function chainlinkPId() external view returns (uint256);

    function configureProvider(uint256 _pId, provider memory _providerInfo) external;

    function providerId(address) external view returns (uint256);

    function providers(
        uint256
    ) external view returns (string memory name, bool isActive, address providerAddress, uint256 gasLimit);

    function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external;

    function reqIds(uint256) external view returns (uint256);

    function result(uint256, uint256) external view returns (uint256);

    function totalCallCount() external view returns (uint256);
}
