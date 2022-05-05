//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./IDODetailsStorage.sol";
import "./../FundingManager/FundingTypes.sol";
import "./../IDOStates.sol";
import "./../Constants.sol";
import "./../RoleManager/IRoleManager.sol";
import "./../ContractsManager/IContractsManager.sol";

import "@openzeppelin/contracts/utils/Address.sol";
// @todo: group update functions
// @todo: update interfaces as well accordingly
contract IDODetails {
    using IDOStates for IDOStates.IDOState;
    using FundingTypes for FundingTypes.FundingType;

    uint public idoId;

    address public preSale;
    address public treasury;

    uint public lpLockerId;

    IContractsManager private contractsManager;

    address public tokenAddress;
    address public ownerAddress;
    IDODetailsStorage.BasicIdoDetails public basicIdoDetails;
    IDODetailsStorage.VotingDetails public votingDetails;
    IDODetailsStorage.PCSListingDetails public pcsListingDetails;
    IDODetailsStorage.ProjectInformation public projectInformation;

    FundingTypes.FundingType public fundingType; // @todo: should be removed for v1


    IDOStates.IDOState public state;

    uint public inHeadStartTill;
    uint16 public multiplier;

    constructor(
        address _contractsManager, // help in testing easily!!!
        address _ownerAddress,
        address _tokenAddress,
        uint _idoId,
        IDODetailsStorage.BasicIdoDetails memory _basicIdoDetails,
        IDODetailsStorage.VotingDetails memory _votingDetails,
        IDODetailsStorage.PCSListingDetails memory _pcsListingDetails,
        IDODetailsStorage.ProjectInformation memory _projectInformation
    ) {
        validateTokenAddress(_tokenAddress);
        validateVoteParams(_votingDetails.voteStartTime, _votingDetails.voteEndTime);
        validateSaleParams(_basicIdoDetails.saleStartTime, _basicIdoDetails.saleEndTime, _basicIdoDetails.headStart, _votingDetails.voteEndTime);

        contractsManager = IContractsManager(_contractsManager);

        tokenAddress = _tokenAddress;
        ownerAddress = _ownerAddress;

        idoId = _idoId;

        basicIdoDetails = _basicIdoDetails;
        votingDetails = _votingDetails;
        pcsListingDetails = _pcsListingDetails;
        projectInformation = _projectInformation;

        state = IDOStates.IDOState.UNDER_MODERATION;
    }

    modifier onlyProjectOwnerOrIDOModerator() {
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        require(msg.sender == ownerAddress || roleManager.isIDOModerator(msg.sender), 'ID:100'); // IDODetails: Only Project Owner or IDO Moderators allowed
        _;
    }

    modifier onlyIDOManager() {
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        require(roleManager.isIDOManager(msg.sender) || roleManager.isIDOManagerAdmin(msg.sender), 'ID:101'); // IDODetails: Only IDO Managers allowed
        _;
    }

    modifier onlyInModeration() {
        require(state == IDOStates.IDOState.UNDER_MODERATION, 'ID:102'); // IDODetails: Only allowed in UNDER_MODERATION state
        _;
    }

    function validateTokenAddress(address _tokenAddress) internal view {
        require(Address.isContract(_tokenAddress), 'ID:103'); // IDODetails: Token should be a contract
        // Probably add more validations here to make sure token is compatible with us ??
    }

    function validateSaleParams(uint _saleStartTime, uint _saleEndTime, uint _headStart, uint _voteEndTime) internal pure {
        require(_saleStartTime >= _voteEndTime + Constants.HOUR * 4, 'ID:104'); // IDODetails: Sale can only start after at-least 4 hours of vote end time
        require(_saleEndTime > _saleStartTime && _saleEndTime - _saleStartTime >= Constants.HOUR, 'ID:105'); // IDODetails: Sale should run for at-least 1 hour
        require(_saleEndTime - _saleStartTime <= Constants.DAY * 2, 'ID:106'); // IDODetails: Sale can only run for max 2 days
        require(_headStart >= Constants.MINUTE * 5, 'ID:107'); // IDODetails: HeadStart should be of at-least 5 mins
        require((_saleEndTime - _saleStartTime) / 2 >= _headStart, 'ID:108'); // IDODetails: HeadStart cannot be more then 50% of time
    }

    function validateVoteParams(uint _voteStartTime, uint _voteEndTime) internal view {
        require(_voteStartTime >= block.timestamp + Constants.MINUTE * 15, 'ID:109'); // IDODetails: Voting can start only after at-least 15 mins from now
        require(_voteEndTime <= block.timestamp + Constants.DAY * 7, 'ID:110'); // IDODetails: Voting should end within 7 days from now
        require(_voteEndTime > _voteStartTime && _voteEndTime - _voteStartTime > Constants.HOUR * 4, 'ID:111'); // IDODetails: Voting should be allowed for at-least 4 hours
    }

    // <Basic Details>

    function updateTokenAddress(address _tokenAddress) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        tokenAddress = _tokenAddress;
    }

    function updateOwnerAddress(address _ownerAddress) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        ownerAddress = _ownerAddress;
    }

    function updateIdoDetails(IDODetailsStorage.BasicIdoDetails memory _basicIdoDetails) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        basicIdoDetails.tokenPrice = _basicIdoDetails.tokenPrice;
        basicIdoDetails.softCap = _basicIdoDetails.softCap;
        basicIdoDetails.hardCap = _basicIdoDetails.hardCap;
        basicIdoDetails.minPurchasePerWallet = _basicIdoDetails.minPurchasePerWallet;
        basicIdoDetails.maxPurchasePerWallet = _basicIdoDetails.maxPurchasePerWallet;
        basicIdoDetails.saleStartTime = _basicIdoDetails.saleStartTime;
        validateSaleParams(basicIdoDetails.saleStartTime, _basicIdoDetails.saleEndTime, basicIdoDetails.headStart, votingDetails.voteEndTime);
        basicIdoDetails.saleEndTime = _basicIdoDetails.saleEndTime;
        validateSaleParams(basicIdoDetails.saleStartTime, basicIdoDetails.saleEndTime, _basicIdoDetails.headStart, votingDetails.voteEndTime);
        basicIdoDetails.headStart = _basicIdoDetails.headStart;
    }

//    function updateSaleStartTime(uint _saleStartTime) public onlyProjectOwnerOrIDOModerator onlyInModeration {
//        validateSaleParams(_saleStartTime, basicIdoDetails.saleEndTime, basicIdoDetails.headStart, votingDetails.voteEndTime);
//        basicIdoDetails.saleStartTime = _saleStartTime;
//    }

    // </Basic Details>

    // </Voting Details>

    function updateVotingDetails(IDODetailsStorage.VotingDetails memory _votingDetails) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        validateVoteParams(_votingDetails.voteStartTime, votingDetails.voteEndTime);
        votingDetails.voteStartTime = _votingDetails.voteStartTime;
        validateVoteParams(votingDetails.voteStartTime, _votingDetails.voteEndTime);
        votingDetails.voteEndTime = _votingDetails.voteEndTime;
    }

    // </Voting Details>

    // <Listing Details>

    function updatePcsListingDetails(IDODetailsStorage.PCSListingDetails memory _pcsListingDetails) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        pcsListingDetails.listingRate = _pcsListingDetails.listingRate;
        pcsListingDetails.lpLockDuration = _pcsListingDetails.lpLockDuration; // @todo: some validations here as well, i think
        pcsListingDetails.allocationToLPInBP = _pcsListingDetails.allocationToLPInBP;
    }

    // </Listing Details>

    // <Project Information>

    //function updateSaleTitle(string memory _saleTitle) public onlyProjectOwnerOrIDOModerator onlyInModeration {
    //    projectInformation.saleTitle = _saleTitle;
    //}

    function updateProjectInformation(IDODetailsStorage.ProjectInformation memory _projectInformation) public onlyProjectOwnerOrIDOModerator onlyInModeration {
        projectInformation.saleDescription = _projectInformation.saleDescription;
        projectInformation.website = _projectInformation.website;
        projectInformation.telegram = _projectInformation.telegram;
        projectInformation.github = _projectInformation.github;
        projectInformation.twitter = _projectInformation.twitter;
        projectInformation.logo = _projectInformation.logo;
        projectInformation.whitePaper = _projectInformation.whitePaper;
        projectInformation.kyc = _projectInformation.kyc;
        projectInformation.video = _projectInformation.video;
        projectInformation.audit = _projectInformation.audit;
    }

    // </Project Information>

    //function updateFundingType(FundingTypes.FundingType _fundingType) public onlyProjectOwnerOrIDOModerator onlyInModeration {
    //    fundingType = _fundingType;
    //}

    // Don't group below functions

    function updateState(IDOStates.IDOState _newState) public onlyIDOManager {
        state.validateState(_newState);
        state = _newState;
    }

    function updatePreSaleAddress(address _preSale) public onlyIDOManager {
        preSale = _preSale;
    }

    function updateTreasuryAddress(address _treasury) public onlyIDOManager {
        treasury = _treasury;
    }

    function updateInHeadStartTill(uint _inHeadStartTill) public onlyIDOManager {
        inHeadStartTill = _inHeadStartTill;
    }

    function updateLpLockerId(uint _lpLockerId) public onlyIDOManager {
        lpLockerId = _lpLockerId;
    }

    function getTokensToBeSold() public view returns (uint) { // Returns in full token
        return basicIdoDetails.hardCap / basicIdoDetails.tokenPrice;
    }

    function updateMultiplier(uint16 _multiplier) public onlyProjectOwnerOrIDOModerator {
        multiplier = _multiplier;
    }
}
