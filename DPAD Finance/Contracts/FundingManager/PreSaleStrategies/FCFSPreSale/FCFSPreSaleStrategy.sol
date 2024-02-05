//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../BasePreSaleStrategy.sol";
import "./../../Treasury/ITreasury.sol";

import "./../../../IDODetails/IIDODetails.sol";
import "./../../../IDOFactory/IIDOFactory.sol";

import "./../../../StakingManager/IStakingManager.sol";

import "./../../../IDOStates.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../../PancakeSwap/IPancakeV2Router02.sol";
import "../../../PancakeSwap/IPancakeV2Factory.sol";

contract FCFSPreSaleStrategy is BasePreSaleStrategy {
    constructor(address _contractManager, uint _idoId) BasePreSaleStrategy(_contractManager, _idoId) {}

    function finalize() public {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        ITreasury _treasury = ITreasury(treasury);
        require(
            (_idoDetails.basicIdoDetails().hardCap / 100) <= _treasury.contributed()
            || _idoDetails.basicIdoDetails().saleEndTime <= block.timestamp
            , 'P1 : 101'); //Presale: Not reached about 1% of hardcap, neither sale end time has arrived

        if ( _idoDetails.basicIdoDetails().softCap > _treasury.contributed()
        && _idoDetails.basicIdoDetails().saleEndTime <= block.timestamp) {
            cancelIdo(_idoDetails);
        } else {
            launchIdo(_idoDetails, _treasury);
        }
    }

    function refund() public {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        ITreasury _treasury = ITreasury(treasury);

        if(_treasury.contributed() < _idoDetails.basicIdoDetails().softCap
        && _idoDetails.state() == IDOStates.IDOState.IN_FUNDING
            && _idoDetails.basicIdoDetails().saleEndTime < block.timestamp) {
            finalize();
        }

        require(_idoDetails.state() == IDOStates.IDOState.CANCELLED, 'P2: 102'); //Presale: Can only refund if sale cancels

        _treasury.refund(msg.sender);
    }

    function contribute(uint _amount) public {
        _contribute(msg.sender, _amount);
    }

    // Optional function to allow cheaper gas cost contributions for this strategy only
    receive() external payable {
        _contribute(msg.sender, msg.value);
    }

    function _contribute(address _contributor, uint _amount) internal {
        validateContribution(_contributor, _amount);
        ITreasury _treasury = ITreasury(treasury);

        require(IERC20(contractsManager.busd()).transferFrom(_contributor, address(_treasury), _amount), "P3: 103"); //Presale: ERC20 Transfer failed

        _treasury.contribute(_contributor, _amount);
    }

    function validateContribution(address _contributor, uint _amount) internal view {
        super.baseValidateContribution(_contributor, _amount);
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        IStakingManager _stakingManager = IStakingManager(contractsManager.stakingManager());
        ITreasury _treasury = ITreasury(treasury);

        require(_treasury.contributed() + _amount <= _idoDetails.basicIdoDetails().hardCap, 'P4: 104'); //Presale: Hardcap will exceed, reduce contribution amount

        if (block.timestamp < _idoDetails.inHeadStartTill()) {
            require(_stakingManager.getVotingPower(_contributor) >= 500, 'P5: 105'); //Presale:HeadStart: Cannot contribute with less then required stakes
        }
    }
}
