//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../ContractsManager/IContractsManager.sol";
import "./../IDODetails/IDODetailsStorage.sol";
import "./../FundingManager/FundingTypes.sol";
import "./../IDODetails/IDODetails.sol";
import "./../IDOStates.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract IDOFactory is Initializable {
    using Counters for Counters.Counter;

    IContractsManager private contractsManager;

    Counters.Counter public idoIdTracker;

    mapping(uint => address) public idoIdToIDODetailsContract;
    mapping(address => uint[]) public ownerToIDOs;

    function initialize(address _contractsManager) public initializer {
        contractsManager = IContractsManager(_contractsManager);
    }

    function create(
        address _tokenAddress,
        IDODetailsStorage.BasicIdoDetails memory _basicIdoDetails,
        IDODetailsStorage.VotingDetails memory _votingDetails,
        IDODetailsStorage.PCSListingDetails memory _pcsListingDetails,
        IDODetailsStorage.ProjectInformation memory _projectInformation
    ) public returns (IDODetails) {
        uint idoIDToAssign = idoIdTracker.current();
        idoIdTracker.increment();

        IDODetails newIDODetailsContract = new IDODetails(
//            0x6f97E091EfBcD65aabf21968Bfa51F1D3413eA6C, // Jugad
            address(contractsManager),
            msg.sender,
            _tokenAddress,
            idoIDToAssign,
            _basicIdoDetails,
            _votingDetails,
            _pcsListingDetails,
            _projectInformation
        );

        idoIdToIDODetailsContract[idoIDToAssign] = address(newIDODetailsContract);
        ownerToIDOs[msg.sender].push(idoIDToAssign);

        return newIDODetailsContract;
    }

    // @todo: this should be allowed by owner of project too
    // This probably is a redundant function too
//    function approve(uint _idoId) public onlyIDOManager {
//        IVotingManager votingManager = IVotingManager(contractsManager.votingManager());
//
//        votingManager.addForVoting(_idoId);
//    }
//
//    function reject(uint _idoId) public onlyIDOManager {
//        IDODetails idoDetails = IDODetails(idoIdToIDODetailsContract[_idoId]);
//
//        idoDetails.updateState(IDOStates.IDOState.REJECTED);
//    }
}
