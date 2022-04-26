// SPDX-License-Identifier: No License
pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BinanceApePropulsor is AccessControl {
    using SafeMath for uint;
    using SafeMath for uint256;

    struct StakerData {
        address addr;
        uint256 balance;
    }

    bool public isPaused;

    uint256 private _stakersCount;
    StakerData[] private _stakersData;
    mapping (address => uint256) private _stakersIds;
    mapping (address => uint256) private _earningsHistory;

    uint256 private _activeLock;
    uint256 private _activeStaker;

    address private _bapeTokenAddr;

    uint256 private _blockLastPropulsion;
    uint256 private _fuelToWin;

    uint256 private _blocksBetweenPropulsion;
    uint256 private _minStakingToBePropelled;

    event StakerPropelled(address staker, uint256 fuelEarned);

    constructor(address bapeTokenAddr) {
        _bapeTokenAddr = bapeTokenAddr;

        _stakersCount = 0;
        _fuelToWin = 0;
        _blockLastPropulsion = block.number;

        _activeLock = 0;
        _activeStaker = 0;

        isPaused = false;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function deposit(uint256 amount) external notPaused returns (bool) {
        require(amount >= _minStakingToBePropelled, "BAPES Propulsor: insufficient amount");

        IERC20 bapeToken = IERC20(_bapeTokenAddr);
        require(bapeToken.balanceOf(msg.sender) >= amount, "BAPES Propulsor: insufficient balance");
        require(bapeToken.transferFrom(msg.sender, address(this), amount), "BAPES Propulsor: transfer failed");

        uint256 fees = amount.div(100).mul(10);
        uint256 amountSubFees = amount.sub(fees);

        uint256 stakerId;
        if(_stakersIds[msg.sender] == 0) {
            _stakersCount = _stakersCount.add(1);
            stakerId = _stakersCount;

            _stakersIds[msg.sender] = stakerId;
            _stakersData.push(StakerData({
                addr: msg.sender,
                balance: 0
            }));
        } else {
            stakerId = _stakersIds[msg.sender];
        }

        StakerData storage stakerData = _stakersData[stakerId - 1];

        if (stakerData.balance == 0) {
            _activeStaker = _activeStaker.add(1);
        }

        stakerData.balance = stakerData.balance.add(amountSubFees);

        _activeLock = _activeLock.add(amountSubFees);

        return true;
    }

    function withdraw() external notPaused returns (bool) {
        uint256 stakerId = _stakersIds[msg.sender];
        require(stakerId > 0, "BAPES Propulsor: unauthorized");

        StakerData storage stakerData = _stakersData[stakerId - 1];

        require(stakerData.balance >= 0, "BAPES Propulsor: insufficient balance");

        uint256 amountToWithdraw = stakerData.balance;
        stakerData.balance = 0;

        IERC20 bapeToken = IERC20(_bapeTokenAddr);
        require(bapeToken.transfer(msg.sender, amountToWithdraw), "BAPES Propulsor: transfer failed");

        _activeStaker = _activeStaker.sub(1);
        _activeLock = _activeLock.sub(amountToWithdraw);

        return true;
    }

    function pulse(uint256 fees) external returns (bool) {
        require(msg.sender == _bapeTokenAddr, "BAPES Propulsor: unauthorized");

        _fuelToWin = _fuelToWin.add(fees);

        if (!isPaused &&
            _fuelToWin > 0 && _stakersCount > 0 &&
                block.number.sub(_blockLastPropulsion) >= _blocksBetweenPropulsion) {

            uint256 nextStakerId = rnd(_stakersCount);
            StakerData storage stakerData = _stakersData[nextStakerId - 1];

            if (stakerData.addr != address(0) &&
                stakerData.balance >= _minStakingToBePropelled) {

                uint256 propulsionFuel = _fuelToWin;
                _fuelToWin = 0;
                _blockLastPropulsion = block.number;

                _earningsHistory[stakerData.addr] = _earningsHistory[stakerData.addr].add(propulsionFuel);

                IERC20 bapeToken = IERC20(_bapeTokenAddr);
                bapeToken.transfer(stakerData.addr, propulsionFuel);

                emit StakerPropelled(stakerData.addr, propulsionFuel);
            }
        }

        return true;
    }

    function getBlockLastPropulsion() public view returns (uint256) {
        return _blockLastPropulsion;
    }

    function getFuelToWin() public view returns (uint256) {
        return _fuelToWin;
    }

    function getStakedAmountByAddr(address stakerAddr) public view returns (uint256) {
        uint256 stakerId = _stakersIds[stakerAddr];
        if (stakerId <= 0) {
            return 0;
        }

        return _stakersData[stakerId - 1].balance;
    }

    function getEarnedAmountByAddr(address stakerAddr) public view returns (uint256) {
        return _earningsHistory[stakerAddr];
    }

    function getBlocksBetweenPropulsion() public view returns (uint256) {
        return _blocksBetweenPropulsion;
    }

    function getMinStakingToBePropelled() public view returns (uint256) {
        return _minStakingToBePropelled;
    }

    function getActiveLock() public view returns (uint256) {
        return _activeLock;
    }

    function getBapeTokenAddr() public view returns (address) {
        return _bapeTokenAddr;
    }

    function getActiveStaker() public view returns (uint256) {
        return _activeStaker;
    }

    function rnd(uint256 max) private view returns(uint256) {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp +
                block.difficulty +
                    ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (block.timestamp)) +
                        block.gaslimit +
                            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (block.timestamp)) +
                                block.number
        )));

        return seed - ((seed / max) * max) + 1;
    }

    function setBlocksBetweenPropulsion(uint256 blocksBetweenPropulsion) external onlyAdmin {
        _blocksBetweenPropulsion = blocksBetweenPropulsion;
    }

    function setMinStakingToBePropelled(uint256 minStakingToBePropelled) external onlyAdmin {
        _minStakingToBePropelled = minStakingToBePropelled;
    }

    function pause() external onlyAdmin {
        isPaused = true;
    }

    function unpause() external onlyAdmin {
        isPaused = false;
    }

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "BAPES Propulsor: unauthorized");
        _;
    }

    modifier notPaused {
        require(!isPaused, "BAPES Propulsor: contract is paused");
        _;
    }
}