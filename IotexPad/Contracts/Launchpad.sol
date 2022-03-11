// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Helper.sol";

/**
 * @title Launchpad
 * @dev 4 rounds : 0 = not open, 1 = guaranty round, 2 = fcfs, 3 = sale finished
 */
contract Launchpad is Ownable {
    using SafeERC20 for IERC20;

    error FunctionInvalidAtThisRound(uint8 currentRound, uint8 requiredRound);
    error NotWhitelistedOrAlreadyFullyParticipated();
    error CannotMatchTiersToAllowances();
    error AmountTooHigh();
    error SaleDateCannotBeInThePast();
    error SaleAlreadyEnded();
    error SaleHasNotEnded();
    error SoldOut();
    error MustNotBeZero(string param);

    uint16 internal round2Multiplier = 2;
    uint256 public saleStartDate;
    uint256 public immutable tokenTarget;
    uint256 public immutable stableTarget;
    uint256 public immutable multiplier; // ratio between tokenTarget and stableTarget * 100
    uint256 public immutable round1Duration = 3600;
    uint256 public immutable baseAllowance;
    bool public endUnlocked;
    uint256 public totalOwed;
    uint256 public stableRaised;

    Helper private immutable tiersHelper;
    IERC20 public immutable stablecoin;

    mapping(address => bool) public whitelist;
    mapping(address => bool) public hasParticipated;
    mapping(address => uint256) public contributedRound1;
    mapping(address => uint256) public contributedRound2;
    address[] public participants;

    event SaleWillStart(uint256 startTimestamp);
    event SaleEnded(uint256 endTimestamp);
    event PoolProgress(uint256 stableRaised, uint256 stableTarget);
    event Round2MultiplierChanged(uint16 round2Multiplier);

    modifier atRound(uint8 requiredRound) {
        uint8 currentRound = roundNumber();
        if (currentRound != requiredRound) {
            revert FunctionInvalidAtThisRound(currentRound, requiredRound);
        }
        _;
    }

    constructor(
        uint256 _tokenTarget,
        uint256 _stableTarget,
        uint256 _saleStartDate,
        uint256 _baseAllowance,
        IERC20 _stableCoinAddress,
        Helper _tiersHelperAddress
    ) {
        if (_stableTarget == 0) revert MustNotBeZero("_stableTarget");
        if (_tokenTarget == 0) revert MustNotBeZero("_tokenTarget");

        tokenTarget = _tokenTarget;
        stableTarget = _stableTarget;
        saleStartDate = _saleStartDate;
        baseAllowance = _baseAllowance;
        multiplier = (tokenTarget * 100) / stableTarget;
        stablecoin = _stableCoinAddress;
        tiersHelper = _tiersHelperAddress;
    }

    function setRound2Multiplier(uint16 _round2Multiplier) external onlyOwner {
        round2Multiplier = _round2Multiplier;

        emit Round2MultiplierChanged(_round2Multiplier);
    }

    function setSaleStartDate(uint256 _saleStartDate)
        external
        onlyOwner
        atRound(0)
    {
        if (block.timestamp - 60 > _saleStartDate) {
            revert SaleDateCannotBeInThePast();
        }

        saleStartDate = _saleStartDate;

        emit SaleWillStart(block.timestamp);
    }

    function finishSale() external onlyOwner {
        if (endUnlocked) revert SaleAlreadyEnded();

        endUnlocked = true;
        emit SaleEnded(block.timestamp);
    }

    // whitelisting
    function addWhitelistedAddress(address user) external onlyOwner {
        whitelist[user] = true;
    }

    function addMultipleWhitelistedAddresses(address[] calldata users)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < users.length; i++) {
            whitelist[users[i]] = true;
        }
    }

    function withdrawStable() external onlyOwner {
        if (!endUnlocked) revert SaleHasNotEnded();

        stablecoin.safeTransfer(
            msg.sender,
            stablecoin.balanceOf(address(this))
        );
    }

    function getUserContribution(address user)
        external
        view
        returns (uint256 contributedStable, uint256 tokensToReceive)
    {
        contributedStable = contributedRound1[user] + contributedRound2[user];
        tokensToReceive = (contributedStable * multiplier) / 100;
    }

    // @notice rescue any token accidentally sent to this contract
    function emergencyWithdrawToken(IERC20 token)
        external
        onlyOwner
        atRound(3)
    {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function buyRound1(uint256 stableAmount) external atRound(1) {
        uint256 allowance = round1Allowance(msg.sender);

        _checkAllowance(allowance, stableAmount);

        _registerParticipation(msg.sender);

        contributedRound1[msg.sender] += stableAmount;

        _buy(stableAmount);
    }

    function buyRound2(uint256 stableAmount) external atRound(2) {
        uint256 allowance = round2Allowance(msg.sender);

        _checkAllowance(allowance, stableAmount);

        _registerParticipation(msg.sender);

        contributedRound2[msg.sender] += stableAmount;

        _buy(stableAmount);
    }

    function _checkAllowance(uint256 allowance, uint256 amount) private pure {
        if (allowance == 0) revert NotWhitelistedOrAlreadyFullyParticipated();

        if (amount > allowance) revert AmountTooHigh();
    }

    function _registerParticipation(address user) private {
        if (!hasParticipated[user]) {
            hasParticipated[user] = true;
            participants.push(user);
        }
    }

    function _buy(uint256 stableAmount) private {
        stablecoin.safeTransferFrom(msg.sender, address(this), stableAmount);

        uint256 tokenAmount = (stableAmount * multiplier) / 100;

        totalOwed += tokenAmount;
        if (totalOwed > tokenTarget) {
            revert SoldOut();
        }

        stableRaised += stableAmount;

        if (stableRaised > stableTarget) {
            revert SoldOut();
        }

        emit PoolProgress(stableRaised, stableTarget);

        if (stableRaised == stableTarget) {
            endUnlocked = true;
            emit SaleEnded(block.timestamp);
        }
    }

    function roundNumber() public view returns (uint8 _roundNumber) {
        if (endUnlocked) return 3;

        if (block.timestamp < saleStartDate || saleStartDate == 0) {
            return 0;
        }

        if (
            block.timestamp >= saleStartDate &&
            block.timestamp < saleStartDate + round1Duration
        ) {
            return 1;
        }

        if (block.timestamp >= (saleStartDate + round1Duration)) {
            return 2;
        }
    }

    function getNumberOfParticipants() public view returns (uint256) {
        return participants.length;
    }

    function isWhitelisted(address user) public view returns (bool) {
        return whitelist[user];
    }

    function round1Allowance(address user) public view returns (uint256) {
        if (!whitelist[user]) return 0;

        (string memory tier, , ) = tiersHelper.getUserStakingData(user);
        (, , uint16 weight) = tiersHelper.tiersMap(tier);

        uint256 allowance = baseAllowance * weight - contributedRound1[user];

        return allowance;
    }

    function round2Allowance(address user) public view returns (uint256) {
        if (!whitelist[user]) return 0;

        (string memory tier, , ) = tiersHelper.getUserStakingData(user);
        (, , uint16 weight) = tiersHelper.tiersMap(tier);

        return
            baseAllowance * weight * round2Multiplier - contributedRound2[user];
    }

    function removeWhitelistedAddress(address user) external onlyOwner {
        whitelist[user] = false;
    }
}
