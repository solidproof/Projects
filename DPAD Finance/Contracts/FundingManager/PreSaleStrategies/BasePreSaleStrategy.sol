//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./../../ContractsManager/IContractsManager.sol";
import "./../../IDODetails/IIDODetails.sol";
import "./../../IDOFactory/IIDOFactory.sol";
import "./../Treasury/Treasury.sol";
import "./../Treasury/ITreasury.sol";
import "./../../StakingManager/IStakingManager.sol";
import "../../LPLocker/ILPLocker.sol";
import "../../IDOStates.sol";

contract BasePreSaleStrategy {
    using SafeMath for uint;
    IContractsManager contractsManager;

    address public treasury;
    uint public idoId;

    constructor(address _contractsManager, uint _idoId) {
        contractsManager = IContractsManager(_contractsManager);
        treasury = address(new Treasury(_contractsManager, _idoId));
        idoId = _idoId;
    }

    function claim() public {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        require(_idoDetails.state() == IDOStates.IDOState.LAUNCHED, 'P1: 201'); //Presale: Can only claim after sale succeeds

        ITreasury _treasury = ITreasury(treasury);

        _treasury.claim(msg.sender);
    }

    function cancelIdo(IIDODetails _idoDetails) internal {
        _idoDetails.updateState(IDOStates.IDOState.CANCELLED);
    }

    function getBnbAndTokenRequirementForFinalizes() public view returns (uint, uint) {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        ITreasury _treasury = ITreasury(treasury);
        uint _bnbForLp = _treasury.contributed().mul(_idoDetails.pcsListingDetails().allocationToLPInBP).div(10000);
        uint _tokenForLp = _bnbForLp.mul(_idoDetails.pcsListingDetails().listingRate);
        return (_bnbForLp, _tokenForLp);
    }

    function launchIdo(IIDODetails _idoDetails, ITreasury _treasury) internal {
        _idoDetails.updateState(IDOStates.IDOState.LAUNCHED);

        // <Removed auto liquidity>

//        uint _bnbForLp = (_treasury.contributed() * _idoDetails.pcsListingDetails().allocationToLPInBP) / 10000;
//        uint _tokenForLp = _bnbForLp * _idoDetails.pcsListingDetails().listingRate;
//        _treasury.addToLP(_tokenForLp, _bnbForLp);
//
//        IPancakeV2Router02 _pcsRouter = IPancakeV2Router02(contractsManager.pcsRouter());
//        IPancakeV2Factory _pcsFactory = IPancakeV2Factory(_pcsRouter.factory());
//        address _pairAddress = _pcsFactory.getPair(_pcsRouter.WETH(), _idoDetails.tokenAddress());
//
//        require(_pairAddress != address(0), 'Presale: Could not create PCS Pair');
//
//        uint _lpBalance = IERC20(_pairAddress).balanceOf(address(this));
//        IERC20(_pairAddress).approve(contractsManager.lpLocker(), _lpBalance);
//
//        uint lockerId = ILPLocker(contractsManager.lpLocker()).lock(_pairAddress,
//            _idoDetails.ownerAddress(),
//            _lpBalance,
//        // since lp lock duration is in days, hence the case
//            block.timestamp + (_idoDetails.pcsListingDetails().lpLockDuration * Constants.DAY)
//        );
//
//        _idoDetails.updateLpLockerId(lockerId);

        // </Removed auto liquidity>

        _treasury.transferDevRewards();
        _treasury.transferStakingRewards();
    }

    function baseValidateContribution(address _contributor, uint _amount) internal view {
        IIDOFactory _idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails _idoDetails = IIDODetails(_idoFactory.idoIdToIDODetailsContract(idoId));
        IStakingManager _stakingManager = IStakingManager(contractsManager.stakingManager());
        ITreasury _treasury = ITreasury(treasury);

        require(_idoDetails.state() == IDOStates.IDOState.IN_FUNDING, 'P1: 202'); //Presale: Funding is not available
        require(block.timestamp >= _idoDetails.basicIdoDetails().saleStartTime, 'P1: 203'); //Presale: To early to contribute
        require(block.timestamp <= _idoDetails.basicIdoDetails().saleEndTime, 'P1: 204'); //Presale: To late to contribute

        require(_treasury.contributions(_contributor) + _amount <= _stakingManager.getMaxPurchaseAmount(idoId, _contributor), 'P1: 205'); //Presale: Cannot contribute more then limit
        require(_amount >= _idoDetails.basicIdoDetails().minPurchasePerWallet, 'P1 : 206'); //Presale: Cannot contribute less then limit

        require(_stakingManager.getVotingPower(_contributor) >= 50, 'P1: 207'); //Presale: Cannot contribute with less then required stakes
    }
}
