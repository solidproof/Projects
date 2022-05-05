//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../IDODetails/IDODetailsStorage.sol";
import "./../IDODetails/IDODetails.sol";

interface IIDOFactory {

    function idoIdTracker() external view returns (uint);

    function idoIdToIDODetailsContract(uint) external view returns (address);

    function ownerToIDOs(address) external view returns (uint[] memory);

    function create(
        address _tokenAddress,
        IDODetailsStorage.BasicIdoDetails memory _basicIdoDetails,
        IDODetailsStorage.VotingDetails memory _votingDetails,
        IDODetailsStorage.PCSListingDetails memory _pcsListingDetails,
        IDODetailsStorage.ProjectInformation memory _projectInformation
    ) external returns (IDODetails);

    function approve(uint _idoId, uint _votingStartsAt, uint _votingEndsAt) external;

    function reject(uint _idoId) external;
}
