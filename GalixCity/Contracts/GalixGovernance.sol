// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./common/interfaces/IGalixERC20.sol";

contract GalixGovernance is
    ContextUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant STAKE_OPERATOR_ROLE     = keccak256("STAKE_OPERATOR_ROLE");
    bytes32 public constant TOKEN_OPERATOR_ROLE     = keccak256("TOKEN_OPERATOR_ROLE");

    IGalixERC20 public token; //NEMO token
    address public daoFund; //DAO Treasury Address
    address public stakePool; //GALIX Stake Pool
    EnumerableSetUpgradeable.AddressSet private _rewardPools; //Game reward Pools

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event TokenMint(address daoFund, address rewardPool, uint256 daoFundAmount, uint256 rewardPoolAmount);
    event StakeDistribute(address operator, address stakePool, uint256 amount);

    modifier notContract() {
        require(!_isContract(_msgSender()), "Contract not allowed");
        require(_msgSender() == tx.origin, "Proxy contract not allowed");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Not Admin");
        _;
    }

    modifier onlyTokenOperator() {
        require(hasRole(TOKEN_OPERATOR_ROLE, _msgSender()), "Not TokenOperator");
        _;
    }

    modifier onlyStakeOperator() {
        require(hasRole(STAKE_OPERATOR_ROLE, _msgSender()), "Not StakeOperator");
        _;
    }

    function initialize() external initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __AccessControlEnumerable_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    ///////////////////////// INTERNAL /////////////////////////
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    ///////////////////////// ADMIN /////////////////////////
    function setInit(
        address _token,
        address _daoFund,
        address _stakePool
    ) onlyAdmin external {
        token = IGalixERC20(_token);
        daoFund = _daoFund;
        stakePool = _stakePool;
    }

    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) onlyAdmin external {
        IERC20Upgradeable(_tokenAddress).transfer(address(_msgSender()), _tokenAmount);
        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    function addTokenOperator(address _account) onlyAdmin external {
        grantRole(TOKEN_OPERATOR_ROLE, _account);
    }

    function removeTokenOperator(address _account) onlyAdmin external {
        revokeRole(TOKEN_OPERATOR_ROLE, _account);
    }

    function addStakeOperator(address _account) onlyAdmin external {
        grantRole(STAKE_OPERATOR_ROLE, _account);
    }

    function removeStakeOperator(address _account) onlyAdmin external {
        revokeRole(STAKE_OPERATOR_ROLE, _account);
    }

    function addRewardPool(address _pool) onlyAdmin external {
        _rewardPools.add(_pool);
    }

    function removeRewardPool(address _pool) onlyAdmin external {
        _rewardPools.remove(_pool);
    }

    ///////////////////////// TOKEN OPERATOR /////////////////////////
    function tokenMint(address _rewardPool, uint256 _amount, uint256 _daoDivision) onlyTokenOperator external {
        require(!_rewardPools.contains(_rewardPool), "_rewardPool invalid");
        uint256 _daoFundAmount = _amount.mul(_daoDivision).div(10000);
        token.mintFrom(daoFund, _daoFundAmount);
        token.mintFrom(_rewardPool, _amount.sub(_daoFundAmount));
        emit TokenMint(daoFund, _rewardPool, _daoFundAmount, _amount.sub(_daoFundAmount));
    }

    ///////////////////////// STAKE OPERATOR /////////////////////////
    function stakeDistribute(uint256 _amount) onlyStakeOperator external {
        token.transferFrom(_msgSender(), stakePool, _amount);
        emit StakeDistribute(_msgSender(), stakePool, _amount);
    }

    ///////////////////////// ANON /////////////////////////
    function version() external view virtual returns (uint256) {
        return 202205161;
    }
}