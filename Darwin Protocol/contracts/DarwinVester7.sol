// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IDarwinVester} from "./interface/IDarwinVester.sol";
import {IDarwin} from "./interface/IDarwin.sol";

/// @title Darwin Vester (MIGRATED FROM BSC)
contract DarwinVester7 is IDarwinVester, ReentrancyGuard, Ownable {

    /// @notice Percentage of monthly interest (0.625%, 7.5% in a year)
    uint256 public constant INTEREST = 625;
    /// @notice Number of months thru which interest is active
    uint256 public constant MONTHS = 12;
    /// @notice Above in seconds
    uint256 public constant VESTING_TIME = MONTHS * (30 days);

    mapping(address => UserInfo) public userInfo;

    /// @notice The Darwin token
    IERC20 public darwin;
    address public deployer;

    bool private _isInitialized;

    modifier isInitialized() {
        if (!_isInitialized) {
            revert NotInitialized();
        }
        _;
    }

    // Constructor takes these args due to migration from BSC
    constructor(address[] memory _users, UserInfo[] memory _userInfo) {
        require(_users.length == _userInfo.length, "Vester7: Invalid _userInfo");
        for (uint i = 0; i < _users.length; i++) {
            userInfo[_users[i]] = _userInfo[i];
        }
        deployer = msg.sender;
    }

    function init(address _darwin) external {
        require (msg.sender == address(deployer), "Vester7: Caller not Deployer");
        require (!_isInitialized, "Vester7: Already initialized");
        darwin = IERC20(_darwin);
        _isInitialized = true;
    }

    // Withdraws darwin from contract and also claims any minted darwin. If _amount == 0, does not withdraw but just claim.
    function withdraw(uint _amount) external isInitialized nonReentrant {
        _withdraw(msg.sender, _amount);
    }

    function _withdraw(address _user, uint _amount) internal {
        _claim(_user);
        if (_amount > 0) {
            uint withdrawable = withdrawableDarwin(_user);
            if (_amount > withdrawable) {
                revert AmountExceedsWithdrawable();
            }
            userInfo[_user].vested -= _amount;
            userInfo[_user].withdrawn += _amount;
            if (!darwin.transfer(_user, _amount)) {
                revert TransferFailed();
            }
            emit Withdraw(_user, _amount);
        }
    }

    function _claim(address _user) internal {
        uint claimAmount = claimableDarwin(msg.sender);
        if (claimAmount > 0) {
            userInfo[_user].claimed += claimAmount;
            IDarwin(address(darwin)).mint(_user, claimAmount);
            emit Claim(_user, claimAmount);
        }
    }

    function withdrawableDarwin(address _user) public view returns(uint256 withdrawable) {
        uint vested = userInfo[_user].vested;
        if (vested == 0) {
            return 0;
        }
        uint withdrawn = userInfo[_user].withdrawn;
        uint start = userInfo[_user].vestTimestamp;
        uint passedMonthsFromStart = (block.timestamp - start) / (30 days);
        if (passedMonthsFromStart > MONTHS) {
            passedMonthsFromStart = MONTHS;
        }
        withdrawable = (((vested + withdrawn) * passedMonthsFromStart) / MONTHS) - withdrawn;
        if (withdrawable > vested) {
            withdrawable = vested;
        }
    }

    function claimableDarwin(address _user) public view returns(uint256 claimable) {
        uint vested = userInfo[_user].vested;
        if (vested == 0) {
            return 0;
        }
        uint claimed = userInfo[_user].claimed;
        uint start = userInfo[_user].vestTimestamp;
        uint passedMonthsFromStart = (block.timestamp - start) / (30 days);
        if (passedMonthsFromStart > MONTHS) {
            passedMonthsFromStart = MONTHS;
        }
        claimable = (((vested * INTEREST) / 100000) * passedMonthsFromStart) - claimed;
    }
}
