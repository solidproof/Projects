// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./library/SafeMathExt.sol";

contract PTokenClaim is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public claimBeginTime;
    uint256 public claimEndTime;
    uint256 public unlockTime;
    mapping(address => uint256) public initialAmount;
    mapping(address => uint256) public latestClaimedTime;
    mapping(address => uint256) public claimedAmount;
    mapping(address => uint256) public remainingAmount;
    IERC20Upgradeable public claimToken;

    modifier inClaimTime() {
        require(block.timestamp >= claimBeginTime, "PTokenClaim: not start");
        require(block.timestamp <= claimEndTime, "PTokenClaim: has been ended");
        _;
    }

    modifier onlyEOA() {
        require(
            msg.sender == tx.origin,
            "PTokenClaim#onlyEOA: only the EOA address"
        );
        _;
    }

    function initialize(
        address _claimToken,
        address[] memory _users,
        uint256[] memory _amounts
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        // TODO: change the params when deploy
        claimToken = IERC20Upgradeable(_claimToken);
        claimBeginTime = 1644854400; // 2022-02-15 T00:00:00
        claimEndTime = ~uint256(0);
        unlockTime = 360 days;
        setClaimAmount(_users, _amounts);
    }

    function setClaimToken(address _newClaimToken) external onlyOwner {
        claimToken = IERC20Upgradeable(_newClaimToken);
    }

    function changeStartTime(uint256 _startTime) external onlyOwner {
        require(_startTime < claimEndTime, "_startTime < endTime");
        claimBeginTime = _startTime;
    }

    function changeEndTime(uint256 _endTime) external onlyOwner {
        require(_endTime > claimBeginTime, "_endTime > startTime");
        claimEndTime = _endTime > claimBeginTime ? _endTime : block.timestamp;
    }

    function setClaimAmount(address[] memory _users, uint256[] memory _amounts)
        public
        onlyOwner
    {
        require(
            _users.length == _amounts.length,
            "PTokenClaim#setClaimAmount: length mismatch"
        );
        for (uint256 i = 0; i < _users.length; i++) {
            require(
                _users[i] != address(0),
                "PTokenClaim#setClaimAmount: user address cannot be 0"
            );
            initialAmount[_users[i]] = _amounts[i];
            remainingAmount[_users[i]] = _amounts[i];
        }
    }

    function claim() external nonReentrant onlyEOA inClaimTime {
        uint256 claimable = getClaimable(msg.sender);
        require(claimable > 0, "PTokenClaim#claim: no claimable");
        claimedAmount[msg.sender] += claimable;
        latestClaimedTime[msg.sender] = block.timestamp;
        remainingAmount[msg.sender] -= claimable;
        require(
            remainingAmount[msg.sender] + claimedAmount[msg.sender] ==
                initialAmount[msg.sender],
            "PTokenClaim#claim: amount is not correct"
        );
        claimToken.safeTransfer(msg.sender, claimable);
    }

    function getClaimable(address _claimer)
        public
        view
        returns (uint256 claimable)
    {
        uint256 lastClaimedTime = latestClaimedTime[_claimer] == 0
            ? claimBeginTime
            : latestClaimedTime[_claimer];
        if (initialAmount[_claimer] > 0 && block.timestamp > lastClaimedTime) {
            claimable = SafeMathExt.min(
                remainingAmount[_claimer],
                (initialAmount[_claimer] *
                    (block.timestamp - lastClaimedTime)) / unlockTime
            );
        }
        return claimable;
    }
}
