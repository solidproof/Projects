//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./../TIERS.sol";
import "./../ContractsManager/IContractsManager.sol";
import "./../RoleManager/IRoleManager.sol";

contract Admin is Initializable {
    IContractsManager contractsManager;

    mapping(uint => mapping (TIERS.TIER => uint)) public tierWiseIdoMaxPurchasePerWalletOverrides;

    uint public devRewards; // IN BP
    uint public stakingRewards; // IN BP

    modifier onlyAdmin() {
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        require(roleManager.isAdmin(msg.sender), 'AD:101'); // Admin: Only IDO Admin allowed
        _;
    }

    function initialize(address _contractsManager) public initializer {
        contractsManager = IContractsManager(_contractsManager);
        devRewards = 100;
        stakingRewards = 200;
    }

    function updateTierMaxPurchaseLimit(uint _idoId, TIERS.TIER _tier, uint _maxAmount) public onlyAdmin {
        tierWiseIdoMaxPurchasePerWalletOverrides[_idoId][_tier] = _maxAmount;
    }

    function updateDevRewards(uint _devRewards) public onlyAdmin {
        devRewards = _devRewards;
    }

    function updateStakingRewards(uint _stakingRewards) public onlyAdmin {
        stakingRewards = _stakingRewards;
    }

}
