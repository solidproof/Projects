// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UVPool.sol";
import "./interfaces/IUVPoolFactory.sol";

contract UVPoolFactory is Ownable, AccessControl, IUVPoolFactory {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(uint8 => address) public managers;
    mapping(uint8 => address) public fundWallets;
    mapping(uint8 => address) public getPool;
    address[] public allPools;
    uint8 orderNumber = 0;
    address public factoryReserve;

    event PoolCreated(address indexed poolAddress, uint8 orderNumber);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // Create a new pool
    function createPool(
        uint256 _amountLimited,
        uint256 _minimumDeposit,
        address _manager,
        address _fundWallet,
        uint64 _poolOpenTime
    ) public onlyRole(ADMIN_ROLE) {
        orderNumber += 1;
        require(getPool[orderNumber] == address(0), "Pool already exists");
        bytes32 salt = keccak256(abi.encodePacked(orderNumber));
        address pool = address(new UVPool{salt: salt}(orderNumber));
        IUVPool(pool).initialize(
            orderNumber,
            _amountLimited,
            _minimumDeposit,
            _fundWallet,
            factoryReserve,
            _poolOpenTime
        );
        
        getPool[orderNumber] = pool;
        allPools.push(pool);
        managers[orderNumber] = _manager;
        fundWallets[orderNumber] = _fundWallet;

        emit PoolCreated(pool, orderNumber);
    }

    // Set factory Reserve address
    function setFactoryReserve(address _factoryReserve)
        public
        onlyRole(ADMIN_ROLE)
    {
        factoryReserve = _factoryReserve;
    }

    // Add Investment for the pool
    function addPoolInvestment(uint8 _orderNumber, address _investmentAddress)
        public
        onlyRole(ADMIN_ROLE)
    {
        IUVPool(getPool[_orderNumber]).addInvestmentAddress(_investmentAddress);
    }

    // Remove Investment for the pool
    function removePoolInvestment(uint8 _orderNumber, address _investmentAddress)
        public
        onlyRole(ADMIN_ROLE)
    {
        IUVPool(getPool[_orderNumber]).removeInvestmentAddress(_investmentAddress);
    }

    // Set fund wallet address for the pool
    function setFundWallet(uint8 _orderNumber, address _fundWallet)
        public
        onlyRole(ADMIN_ROLE)
    {
        IUVPool(getPool[_orderNumber]).setFundWallet(_fundWallet);
    }

    // Add Role to the pool
    function addPoolRole(uint8 _orderNumber, address _manager)
        public
        onlyOwner
    {
        IUVPool(getPool[_orderNumber]).addManager(_manager);
        managers[_orderNumber] = _manager;
    }

    // Remove Role from the pool
    function removePoolRole(uint8 _orderNumber, address _manager)
        public
        onlyOwner
    {
        IUVPool(getPool[_orderNumber]).removeManager(_manager);
        managers[_orderNumber] = address(0);
    }

    // Add Role to the factory
    function addRole(address _addr) public onlyOwner {
        _setupRole(ADMIN_ROLE, _addr);
    }

    // Remove Role from the factory
    function removeRole(address _addr) public onlyOwner {
        _revokeRole(ADMIN_ROLE, _addr);
    }

    // Get length of all pools
    function getPoolsLength() public view returns (uint256) {
        return allPools.length;
    }
    
    // Get info of a pool
    function getPoolInfo(uint8 _orderNumber) public view returns (
        address _pool,
        address _manager,
        address _fundWallet
    ) {
        return (
            getPool[_orderNumber],
            managers[_orderNumber],
            fundWallets[_orderNumber]
        );
    }
}
