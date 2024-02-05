// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./interfaces/IAuthority.sol";

import "./types/AccessControlled.sol";

contract Authority is IAuthority, AccessControlled {

    /* ========== STATE VARIABLES ========== */

    address public override governor;

    address public override guardian;

    address public override policy;

    address public override vault;

    address public newGovernor;

    address public newGuardian;

    address public newPolicy;

    address public newVault;

    mapping(address => bytes32) public override roles;

    /* ========== Constructor ========== */

    constructor(
        address _governor,
        address _guardian,
        address _policy,
        address _vault
    ) AccessControlled(IAuthority(address(this))) {
        require(_governor != address(0), "Governor cannot be zero address");
        require(_guardian != address(0), "Guardian cannot be zero address");
        require(_policy != address(0), "Policy cannot be zero address");
        require(_vault != address(0), "Vault cannot be zero address");
        governor = _governor;
        emit GovernorPushed(address(0), governor, true);

        guardian = _guardian;
        emit GuardianPushed(address(0), guardian, true);

        policy = _policy;
        emit PolicyPushed(address(0), policy, true);

        vault = _vault;
        emit VaultPushed(address(0), vault, true);

    }

    modifier notAddressZero(address _account){
        require(_account != address(0), "Account cannot be zero address");
        _;
    }

    modifier _isContract(address addr){
        require(isContract(addr), "Is not a contract");
        _;
    }    

    /* ==========is Contract============ */

    function isContract(address addr) public view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }


    /* ========== GOV ONLY ========== */

    function pushGovernor(address _newGovernor, bool _effectiveImmediately) external onlyGovernor notAddressZero(_newGovernor) {
        if (_effectiveImmediately) governor = _newGovernor;
        newGovernor = _newGovernor;
        emit GovernorPushed(governor, newGovernor, _effectiveImmediately);
    }

    function pushGuardian(address _newGuardian, bool _effectiveImmediately) external onlyGovernor notAddressZero(_newGuardian){
        if (_effectiveImmediately) guardian = _newGuardian;
        newGuardian = _newGuardian;
        emit GuardianPushed(guardian, newGuardian, _effectiveImmediately);
    }

    function pushPolicy(address _newPolicy, bool _effectiveImmediately) external onlyGovernor notAddressZero(_newPolicy) {
        if (_effectiveImmediately) policy = _newPolicy;
        newPolicy = _newPolicy;
        emit PolicyPushed(policy, newPolicy, _effectiveImmediately);
    }

    function pushVault(address _newVault, bool _effectiveImmediately) external onlyGovernor notAddressZero(_newVault) {
        if (_effectiveImmediately) vault = _newVault;
        newVault = _newVault;
        emit VaultPushed(vault, newVault, _effectiveImmediately);
    }

    function pushRole(address _account, bytes32 _role) external onlyGovernor notAddressZero(_account) {
        roles[_account] = _role;
        emit RolePushed(_account, _role);
    }


    /* ========== PENDING ROLE ONLY ========== */

    function pullGovernor() external {
        require(msg.sender == newGovernor, "!newGovernor");
        emit GovernorPulled(governor, newGovernor);
        governor = newGovernor;
    }

    function pullGuardian() external {
        require(msg.sender == newGuardian, "!newGuard");
        emit GuardianPulled(guardian, newGuardian);
        guardian = newGuardian;
    }

    function pullPolicy() external {
        require(msg.sender == newPolicy, "!newPolicy");
        emit PolicyPulled(policy, newPolicy);
        policy = newPolicy;
    }

    function pullVault() external {
        require(msg.sender == newVault, "!newVault");
        emit VaultPulled(vault, newVault);
        vault = newVault;
    }


}
