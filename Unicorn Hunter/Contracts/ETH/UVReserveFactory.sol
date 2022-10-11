// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./UVReserve.sol";
import "./UVTakeProfit.sol";
import "./interfaces/IUVReserveFactory.sol";

contract UVReserveFactory is Ownable, AccessControl, IUVReserveFactory {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(uint8 => address) public managers;
    mapping(uint8 => address) public fundWallets;

    mapping(uint8 => address) public getPoolReserve;
    address[] public allPoolsReserve;
    mapping(uint8 => address) public getPoolTP;
    address[] public allPoolsTP;
    uint8 orderNumber = 0;

    event PoolCreated(address indexed reserveAddress, address indexed stakeAddress, uint8 orderNumber);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // Create a new Reserve
    function createReserve(
        address _fundWallet,
        address _pool,
        address _manager
    ) public onlyRole(ADMIN_ROLE) {
        orderNumber += 1;
        address poolTP = address(new UVTakeProfit());
        address poolReserve = address(new UVReserve());
        IUVTakeProfit(poolTP).initialize(orderNumber, _pool, _fundWallet);
        IUVReserve(poolReserve).initialize(orderNumber, poolTP);

        getPoolReserve[orderNumber] = poolReserve;
        allPoolsReserve.push(poolReserve);
        getPoolTP[orderNumber] = poolTP;
        allPoolsTP.push(poolTP);
        managers[orderNumber] = _manager;
        fundWallets[orderNumber] = _fundWallet;

        emit PoolCreated(poolReserve, poolTP, orderNumber);
    }

    // Add Role to the pool
    function addPoolRole(uint8 _orderNumber, address _manager)
        public
        onlyOwner
    {
        IUVReserve(getPoolReserve[_orderNumber]).addManager(_manager);
        IUVTakeProfit(getPoolTP[_orderNumber]).addManager(_manager);
        managers[_orderNumber] = _manager;
    }

    // Remove Role from the pool
    function removePoolRole(uint8 _orderNumber, address _manager)
        public
        onlyOwner
    {
        IUVReserve(getPoolReserve[_orderNumber]).removeManager(_manager);
        IUVTakeProfit(getPoolTP[_orderNumber]).removeManager(_manager);

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
        return allPoolsReserve.length;
    }

    // Get info of a pool
    function getPoolInfo(uint8 _orderNumber)
        public
        view
        returns (
            address _poolReserve,
            address _poolTP,
            address _manager,
            address _fundWallet
        )
    {
        return (
            getPoolReserve[_orderNumber],
            getPoolTP[_orderNumber],
            managers[_orderNumber],
            fundWallets[_orderNumber]
        );
    }

    // Set fund wallet address for the pool
    function setFundWallet(uint8 _orderNumber, address _fundWallet)
        public
        onlyRole(ADMIN_ROLE)
    {
        IUVReserve(getPoolReserve[_orderNumber]).setFundWallet(_fundWallet);
        IUVTakeProfit(getPoolTP[_orderNumber]).setFundWallet(_fundWallet);
    }
}
