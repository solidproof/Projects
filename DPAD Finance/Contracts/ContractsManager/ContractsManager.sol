//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../RoleManager/IRoleManager.sol";

contract ContractsManager {
    address public idoFactory;
    address public roleManager;

    address public votingManager;
    address public fundingManager;
    address public stakingManager;

    address public tokenAddress;

    address public developerAddress;

    address public pcsRouter;

    address public lpLocker;

    address public adminContract;

    address public busd = 0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee;

    constructor(
        address _idoFactory,
        address _roleManager,
        address _votingManager,
        address _fundingManager,
        address _stakingManager,
        address _tokenAddress,
        address _developerAddress,
        address _pcsRouter,
        address _lpLocker,
        address _adminContract
    ) {
        idoFactory = _idoFactory;
        roleManager = _roleManager;
        votingManager = _votingManager;
        fundingManager = _fundingManager;
        stakingManager = _stakingManager;

        tokenAddress = _tokenAddress;

        developerAddress = _developerAddress;

        pcsRouter = _pcsRouter;
        lpLocker = _lpLocker;

        adminContract = _adminContract;
    }

    modifier onlyAdmin() {
        IRoleManager _roleManager = IRoleManager(roleManager);
        require(_roleManager.isAdmin(msg.sender), "ContractsManager: Restricted to only admin.");
        _;
    }

    function updateIDOFactory(address _idoFactory) public onlyAdmin {
        idoFactory = _idoFactory;
    }

    function updateRoleManager(address _roleManager) public onlyAdmin {
        roleManager = _roleManager;
    }

    function updateVotingManager(address _votingManager) public onlyAdmin {
        votingManager = _votingManager;
    }

    function updateFundingManager(address _fundingManager) public onlyAdmin {
        fundingManager = _fundingManager;
    }

    function updateStakingManager(address _stakingManager) public onlyAdmin {
        stakingManager = _stakingManager;
    }

    function updateTokenAddress(address _tokenAddress) public onlyAdmin {
        tokenAddress = _tokenAddress;
    }

    function updateDeveloperAddress(address _developerAddress) public onlyAdmin {
        developerAddress = _developerAddress;
    }

    function updatePCSRouter(address _pcsRouter) public onlyAdmin {
        pcsRouter = _pcsRouter;
    }

    function updateLpLocker(address _lpLocker) public onlyAdmin {
        lpLocker = _lpLocker;
    }

    function updateAdminContract(address _adminContract) public onlyAdmin {
        adminContract = _adminContract;
    }

    function updateBUSDAddress(address _busd) public onlyAdmin {
        busd = _busd;
    }
}
