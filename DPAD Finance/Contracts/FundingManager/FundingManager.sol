//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./../RoleManager/IRoleManager.sol";
import "./../ContractsManager/IContractsManager.sol";

import "./../IDOFactory/IIDOFactory.sol";

import "./../IDODetails/IIDODetails.sol";
import "./../Constants.sol";
import "./../IDOStates.sol";

import "./FundingTypes.sol";

import "./../VotingManager/IVotingManager.sol";
import "./../VotingManager/VotingManagerStorage.sol";

import "./PreSaleStrategies/FCFSPreSale/FCFSPreSaleStrategy.sol";
import "./PreSaleStrategies/BasePreSaleStrategy.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FundingManager is Initializable {
    using SafeMath for uint;

    IContractsManager contractsManager;

    function initialize(address _contractsManager) public initializer {
        contractsManager = IContractsManager(_contractsManager);
    }

//    constructor(address _contractsManager) {
//        contractsManager = IContractsManager(_contractsManager);
//    }

//    modifier onlyIDOManagerOrDpadOwner() {
//        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
//        require(roleManager.isIDOManager(msg.sender) || roleManager.isAdmin(msg.sender), 'F1: 101'); //Only IDO Managers or DPAD owners are allowed
//        _;
//    }

//    modifier onlyIDOManagerOrIDOOwner(uint _idoId) {
//        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
//        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
//        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));
//        require(roleManager.isIDOManager(msg.sender) || idoDetails.ownerAddress() == msg.sender, 'F1: 104'); //Only IDO Managers or IDO Owner allowed
//        _;
//    }

    function createPresaleAndTreasury(IIDODetails idoDetails) internal returns (address, address){
        BasePreSaleStrategy preSale;
        if (idoDetails.fundingType() == FundingTypes.FundingType.FCFS) {
            preSale = new FCFSPreSaleStrategy(address(contractsManager), idoDetails.idoId());
        }
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        roleManager.grantRole(roleManager.IDOManagerRole(), address(preSale));
        roleManager.grantRole(roleManager.IDOManagerRole(), preSale.treasury());

        return (address(preSale), preSale.treasury());
    }

    function updateIdoWithPreSaleAndTreasury(IIDODetails idoDetails, address preSale, address treasury) internal {
        idoDetails.updatePreSaleAddress(preSale);
        idoDetails.updateTreasuryAddress(treasury);
    }

    function calcTreasuryDepositAmount(IIDODetails idoDetails) internal view returns (uint) {
        uint _tokenAmountForHardCap = idoDetails.basicIdoDetails().hardCap.div(idoDetails.basicIdoDetails().tokenPrice);
        uint _tokenAmountForLp = _tokenAmountForHardCap.mul(idoDetails.pcsListingDetails().allocationToLPInBP).div(10000);

        return _tokenAmountForHardCap.add(_tokenAmountForLp);
    }

    function fundTreasury(IIDODetails idoDetails) internal {
        IERC20 _token = IERC20(idoDetails.tokenAddress());
        _token.transferFrom(msg.sender, idoDetails.treasury(), calcTreasuryDepositAmount(idoDetails));
    }

    function updateHeadStart(IIDODetails idoDetails) internal {
        uint headStartTill;
        if(block.timestamp <= idoDetails.basicIdoDetails().saleStartTime) {
            headStartTill = idoDetails.basicIdoDetails().saleStartTime + idoDetails.basicIdoDetails().headStart;
        } else {
            if (idoDetails.basicIdoDetails().saleEndTime - block.timestamp >= idoDetails.basicIdoDetails().headStart * 2) {
                headStartTill = block.timestamp + ((idoDetails.basicIdoDetails().saleEndTime - block.timestamp) / 2);
            } else {
                headStartTill = block.timestamp + idoDetails.basicIdoDetails().headStart;
            }
        }

        idoDetails.updateInHeadStartTill(headStartTill);
    }

    function addForFunding(uint _idoId) public {
        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));

        require(block.timestamp > idoDetails.votingDetails().voteEndTime, 'F2: 102'); //Cannot finalize before voting period is over
        require(idoDetails.basicIdoDetails().saleEndTime >= block.timestamp + Constants.HOUR * 2, 'F2: 103'); //Sale can only start at-least 2 hours before sale-end time

        IVotingManager votingManager = IVotingManager(contractsManager.votingManager());
        VotingManagerStorage.VoteRecord memory voteRecord = votingManager.voteLedger(_idoId);

        IERC20 _token = IERC20(contractsManager.tokenAddress());

        if (voteRecord.positiveVoteWeight > voteRecord.negativeVoteWeight && voteRecord.positiveVoteWeight >= (_token.totalSupply() / 10)) { // more then 10% of total supply too
            (address preSale, address treasury) = createPresaleAndTreasury(idoDetails);
            updateIdoWithPreSaleAndTreasury(idoDetails, preSale, treasury);
            idoDetails.updateState(IDOStates.IDOState.IN_FUNDING);
//            fundTreasury(idoDetails); // @todo: probably this will change too as per auction strategy
            updateHeadStart(idoDetails);
        } else {
            idoDetails.updateState(IDOStates.IDOState.FAILED); // Update state as failed and move on
        }
    }

    //onlyIDOManagerOrIDOOwner(_idoId)

    function addForForceFunding(uint _idoId)  public {
        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));

        require(idoDetails.ownerAddress() == msg.sender, 'F1: 104'); // only IDO owner is allowed to do this

        (address preSale, address treasury) = createPresaleAndTreasury(idoDetails);
        updateIdoWithPreSaleAndTreasury(idoDetails, preSale, treasury);
        idoDetails.updateState(IDOStates.IDOState.IN_FUNDING);
//        fundTreasury(idoDetails); // @todo: probably this will change too as per auction strategy
        updateHeadStart(idoDetails);
    }
}
