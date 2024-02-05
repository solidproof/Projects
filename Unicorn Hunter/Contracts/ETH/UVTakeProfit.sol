// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IUVTakeProfit.sol";
import "./interfaces/IUVReserveFactory.sol";

contract UVTakeProfit is Ownable, AccessControl, IUVTakeProfit {
    using SafeMath for uint256;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    struct StakeInfo {
        uint8 Id;
        uint256 totalToken;
        uint256 remainingToken;
        address tokenAddress;
        uint64 closeTimestamp;
        uint64 openTimestamp;
        uint8 feePercent;
    }

    struct UserInfo {
        uint256 amount;
        uint256 stakeTime;
    }

    mapping(uint8 => mapping(address => UserInfo)) public users; // Key string Key is address
    mapping(uint8 => StakeInfo) public stakeInfos; // Key is address of token

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public factoryReserve;
    address public fundWallet;
    uint8 public orderNumber;
    address public poolToken;

    event WithdrawToken(
        address indexed user,
        address indexed tokenAddress,
        uint256 _amount
    );
    event FinishStake(address indexed user, uint256 _amount);

    constructor() {
        factoryReserve = msg.sender;
    }

    function initialize(
        uint8 _orderNumber,
        address _poolToken,
        address _fundWallet
    ) external {
        require(msg.sender == factoryReserve, "Only factory can initialize");
        orderNumber = _orderNumber;
        poolToken = _poolToken;
        fundWallet = _fundWallet;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    receive() external payable {}
    fallback() external payable {}

    // Distribute tokens to users
    function distributeTokens(
        address[] memory _users,
        uint256 _amountDistribute,
        address _tokenAddress,
        uint8 _feePercent
    ) public onlyRole(MANAGER_ROLE) {
        IERC20 instance = IERC20(_tokenAddress);
        IERC20 instancePoolToken = IERC20(poolToken);
        uint256 _totalSupply = instancePoolToken.totalSupply();
        uint256 totalFee = 0;
        uint256 amountDistribute = _amountDistribute;
        uint8 feePercent = _feePercent;

        for (uint256 index = 0; index < _users.length; index++) {
            address user = _users[index];
            uint256 amount = instancePoolToken.balanceOf(user);

            uint256 multiples = 10**18;
            uint256 tokenPerPoolToken = amountDistribute.div(
                _totalSupply.div(multiples)
            );
            uint256 amountToUser = amount.mul(tokenPerPoolToken).div(multiples);
            uint256 fee = 0;
            if (feePercent > 0) {
                fee = (amountToUser.mul(feePercent)).div(1000);
                totalFee += fee;
            }
            instance.transfer(user, amountToUser - fee);
        }
        if (totalFee > 0) instance.transfer(fundWallet, totalFee);
    }

    // Create stakeinfos token for user
    function createStakeInfo(
        uint8 _id,
        address _tokenAddress,
        uint256 _amount,
        uint64 _openTime,
        uint64 _closeTime,
        uint8 _feePercent
    ) public onlyRole(MANAGER_ROLE) {
        require(_tokenAddress != address(0));
        require(
            stakeInfos[_id].openTimestamp == 0,
            "Stake is already created"
        );
        require(_closeTime > block.timestamp);

        stakeInfos[_id].tokenAddress = _tokenAddress;
        stakeInfos[_id].totalToken = _amount;
        stakeInfos[_id].remainingToken = _amount;
        stakeInfos[_id].closeTimestamp = _closeTime;
        stakeInfos[_id].openTimestamp = _openTime;
        stakeInfos[_id].feePercent = _feePercent;
    }

    // Withdraw Token
    function withdrawToken(uint8 _stakeId) external {
        uint256 _amountStake = IERC20(poolToken).balanceOf(msg.sender);
        require(_amountStake > 0, "You have no tokens to stake");

        IERC20(poolToken).transferFrom(msg.sender, address(this), _amountStake);
        users[_stakeId][msg.sender].amount = _amountStake;
        users[_stakeId][msg.sender].stakeTime = block.timestamp;
        
        require(
            users[_stakeId][msg.sender].amount > 0,
            "You have no tokens to withdraw"
        );
        uint256 _totalSupply = IERC20(poolToken).totalSupply();
        uint256 multiples = 10**18;
        uint256 tokenPerPoolToken = stakeInfos[_stakeId]
            .totalToken
            .div(_totalSupply.div(multiples));
        uint256 amountWithdraw = users[_stakeId][msg.sender]
            .amount
            .mul(tokenPerPoolToken)
            .div(multiples);

        uint256 totalToken = amountWithdraw;
        uint256 fee = 0;
        if (stakeInfos[_stakeId].feePercent > 0) {
            fee = (totalToken.mul(stakeInfos[_stakeId].feePercent)).div(1000);
            IERC20(stakeInfos[_stakeId].tokenAddress).transfer(fundWallet, fee);
        }

        IERC20(stakeInfos[_stakeId].tokenAddress).transfer(
            msg.sender,
            totalToken - fee
        );

        stakeInfos[_stakeId].remainingToken -= totalToken;
        emit WithdrawToken(
            msg.sender,
            stakeInfos[_stakeId].tokenAddress,
            totalToken
        );
    }

    // Get pool reserved
    function getReserve() public view returns (address) {
        (address _poolReserved, , , ) = IUVReserveFactory(factoryReserve)
            .getPoolInfo(orderNumber);
        return _poolReserved;
    }

    // Finish Stake
    function finishStake() external onlyRole(MANAGER_ROLE) {

        IERC20 instance = IERC20(poolToken);

        instance.transfer(BURN_ADDRESS, instance.balanceOf(address(this)));
    }

    // Add wallet to manager role
    function addManager(address _manager) public onlyOwner {
        _setupRole(MANAGER_ROLE, _manager);
    }

    // Remove wallet from manager role
    function removeManager(address _manager) public onlyOwner {
        revokeRole(MANAGER_ROLE, _manager);
    }

    // Set the fund wallet
    function setFundWallet(address _fundWallet) public onlyOwner {
        fundWallet = _fundWallet;
    }
}
