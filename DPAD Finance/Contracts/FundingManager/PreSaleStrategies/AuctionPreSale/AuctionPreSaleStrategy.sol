//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../BasePreSaleStrategy.sol";
import "./SortedDescendingList.sol";
import "./SortedAscendingList.sol";

contract AuctionPreSaleStrategy is BasePreSaleStrategy {

    SortedDescendingList.Item[] public rateAmountSorted;
    mapping (uint => SortedAscendingList.Item[]) public rateContributionSortedList;

    struct Contribution {
        uint contributionTime;
        uint amount;
    }

    mapping (address => Contribution) public contributorMap;

    constructor(address _contractManager, uint _idoId) BasePreSaleStrategy(_contractManager, _idoId) {
        SortedDescendingList.initNodes(rateAmountSorted);
    }

    function _contribute(address _contributor, uint _amount, uint _rate) internal {
        validateContribution(_contributor, _amount);

        uint index = SortedDescendingList.findIndex(rateAmountSorted, _rate);
        if (index == 0) {
            SortedDescendingList.addNode(rateAmountSorted, _rate, _amount);
        } else {
            rateAmountSorted[index].amount += _amount;
        }

        contributorMap[_contributor].amount += _amount;
        contributorMap[_contributor].contributionTime = block.timestamp;

        if (rateContributionSortedList[_rate].length == 0) {
            SortedAscendingList.initNodes(rateContributionSortedList[_rate]);
        }

        index = SortedAscendingList.findIndex(rateContributionSortedList[_rate], block.timestamp);

        if (index == 0) {
            SortedAscendingList.addNode(rateContributionSortedList[_rate], block.timestamp, _amount);
        } else {
            rateContributionSortedList[_rate][index].amount += _amount;
        }

        ITreasury _treasury = ITreasury(treasury);
        _treasury.contribute(_contributor, _amount);
    }

    function validateContribution(address _contributor, uint _amount) internal view {
        super.baseValidateContribution(_contributor, _amount);
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        IStakingManager _stakingManager = IStakingManager(contractsManager.stakingManager());
        ITreasury _treasury = ITreasury(treasury);

        require(_treasury.contributed() + _amount <= _idoDetails.basicIdoDetails().hardCap, 'Presale: Hardcap will exceed, reduce contribution amount');

        if (block.timestamp < _idoDetails.inHeadStartTill()) {
            require(_stakingManager.getVotingPower(_contributor) >= 500, 'Presale:HeadStart: Cannot contribute with less then required stakes');
        }
    }

    function calcSaleRatesAndTokenSellAmount() public view returns (uint, uint) {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        uint tokensCanBeSold = 0;
        uint tokensToBeSold = _idoDetails.getTokensToBeSold();

        uint currentRate = 0;
        SortedDescendingList.Item memory currentItem = rateAmountSorted[SortedDescendingList.GUARD];
        while (tokensCanBeSold < tokensToBeSold && currentItem.next != SortedDescendingList.GUARD) {
            currentRate = currentItem.score;
            tokensCanBeSold += (currentItem.amount / currentItem.score);
            currentItem = rateAmountSorted[currentItem.next];
        }

        return (currentRate, tokensCanBeSold);
    }

    function finalize() public {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        ITreasury _treasury = ITreasury(treasury);
        require(_idoDetails.basicIdoDetails().saleEndTime <= block.timestamp, 'Presale: sale cannot end prematurely');

        uint currentRate;
        uint tokensCanBeSold;
        (currentRate, tokensCanBeSold) = calcSaleRatesAndTokenSellAmount();

        if ( _idoDetails.basicIdoDetails().softCap > currentRate * tokensCanBeSold
            && _idoDetails.basicIdoDetails().saleEndTime <= block.timestamp) {
            cancelIdo(_idoDetails);
        } else {
            // @todo: set rate here
            launchIdo(_idoDetails, _treasury);
        }
    }

    function contribute(uint _rate) public payable {
        _contribute(msg.sender, msg.value, _rate);
    }
}
