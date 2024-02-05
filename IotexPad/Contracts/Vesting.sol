// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct CreateVestingInput {
    address user;
    uint128 amount;
}

/**
 * @title Vesting
 * @dev 3 stages: 0 = no rate applies(until cliffEnd), 1 = rateDuringStage1(until stage1End), 2 = rateDuringStage2(until vestingEnd)
 * @dev no user can claim until contract is unlocked
 */
contract Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error VestingIsNotUnlocked();
    error NoZeroAddress(string param);
    error NothingToClaimCurrentlyPleaseTryAgainLater();
    error DepositedAmountIsInsufficientPleaseDepositMore();
    error WrongInputParameters();
    error AlreadyUnlocked();
    error OnlyOneVestingPerAddress();
    error MustNotBeZero(string param);
    error NoActiveVesting();

    struct UserVesting {
        bool init;
        uint256 amount;
        uint256 amountClaimed;
        uint256 lastClaimAt;
    }

    bool public locked;
    uint256 public totalAmountAllocated; // Amount owner allocated for users

    uint256 public constant YEAR_IN_SECONDS = 31536000;
    uint256 public constant RATE_CONVERTER = 100;

    IERC20 public immutable vestedToken;
    string public name;
    uint256 public immutable cliffEndAt;
    uint256 public immutable stage1EndAt;
    uint256 public immutable vestingEndAt;
    uint256 public immutable claimableAtStart; // percentage
    uint256 public immutable rateDuringStage1; // annual percentage rate
    uint256 public immutable rateDuringStage2; // annual percentage rate

    mapping(address => UserVesting) public vestings;

    event NewVestingCreated(address indexed user, uint256 amount);

    event NewClaim(address indexed user, uint256 amountClaimed);

    constructor(
        IERC20 _vestedToken,
        string memory _name,
        uint256 _cliffEndAt,
        uint256 _stage1EndAt,
        uint256 _vestingEndAt,
        uint256 _claimableAtStart,
        uint256 _rateDuringStage1,
        uint256 _rateDuringStage2
    ) {
        if (!(_cliffEndAt < _stage1EndAt && _stage1EndAt <= _vestingEndAt)) {
            revert WrongInputParameters();
        }
        uint256 total = _claimableAtStart +
            ((_stage1EndAt - _cliffEndAt) * _rateDuringStage1) /
            YEAR_IN_SECONDS +
            ((_vestingEndAt - _stage1EndAt) * _rateDuringStage2) /
            YEAR_IN_SECONDS;
        if (total != 100) {
            revert WrongInputParameters();
        }

        if (address(_vestedToken) == address(0)) {
            revert NoZeroAddress("_vestedToken");
        }

        name = _name;
        vestedToken = _vestedToken;
        cliffEndAt = _cliffEndAt;
        stage1EndAt = _stage1EndAt;
        vestingEndAt = _vestingEndAt;
        claimableAtStart = _claimableAtStart;
        rateDuringStage1 = _rateDuringStage1;
        rateDuringStage2 = _rateDuringStage2;

        locked = true;
    }

    /**
     * @notice allow users to claim their vested tokens
     */
    function unlock() external onlyOwner {
        if (!locked) {
            revert AlreadyUnlocked();
        }

        locked = false;
    }

    /**
     * @notice Move vesting to another address in case user lose access to his original account
     */
    function moveVesting(address from, address to) external onlyOwner {
        UserVesting memory vesting = vestings[from];
        if (vesting.amount - vesting.amountClaimed == 0) {
            revert NoActiveVesting();
        }
        if (vestings[to].init) {
            revert OnlyOneVestingPerAddress();
        }
        if (to == address(0)) {
            revert NoZeroAddress("to");
        }

        vestings[to] = vesting;
        delete vestings[from];
    }

    /**
     * @notice create vesting for user, only one vesting per user address
     * @dev owner needs to first deploy enough tokens to vesting contract address
     */
    function createVestings(CreateVestingInput[] calldata vestingsInput)
        external
        onlyOwner
    {
        uint256 totalDepositedAmount = getDepositedAmount();
        uint256 amountAllocated;

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            amountAllocated += vestingsInput[i].amount;
        }
        // check if depositor have enough credit
        if ((totalDepositedAmount - totalAmountAllocated) < amountAllocated) {
            revert DepositedAmountIsInsufficientPleaseDepositMore();
        }

        for (uint64 i = 0; i < vestingsInput.length; i++) {
            _createVesting(vestingsInput[i]);
        }
    }

    /**
     * @dev can be called any amount of time after vesting contract is unlocked, tokens are vested each block after cliffEnd
     */
    function claim() external nonReentrant {
        if (locked) {
            revert VestingIsNotUnlocked();
        }

        UserVesting storage vesting = vestings[msg.sender];
        if (vesting.amount - vesting.amountClaimed == 0) {
            revert NoActiveVesting();
        }

        uint256 claimableAmount = _claimable(vesting);

        if (claimableAmount == 0) {
            revert NothingToClaimCurrentlyPleaseTryAgainLater();
        }

        vesting.amountClaimed += claimableAmount;
        vesting.lastClaimAt = block.timestamp;

        assert(vesting.amountClaimed <= vesting.amount);

        vestedToken.safeTransfer(msg.sender, claimableAmount);
        emit NewClaim(msg.sender, claimableAmount);
    }

    // return amount user can claim from locked tokens at the moment
    function claimable(address _user) external view returns (uint256 amount) {
        return _claimable(vestings[_user]);
    }

    function getDepositedAmount() public view returns (uint256 amount) {
        return vestedToken.balanceOf(address(this));
    }

    // create a vesting for an user
    function _createVesting(CreateVestingInput memory v) private {
        if (v.user == address(0)) {
            revert NoZeroAddress("user");
        }
        if (v.amount == 0) {
            revert MustNotBeZero("amount");
        }
        if (vestings[v.user].init) {
            revert OnlyOneVestingPerAddress();
        }

        totalAmountAllocated += v.amount;

        vestings[v.user] = UserVesting({
            init: true,
            amount: v.amount,
            amountClaimed: 0,
            lastClaimAt: 0
        });

        emit NewVestingCreated(v.user, v.amount);
    }

    function _claimable(UserVesting memory v)
        private
        view
        returns (uint256 amount)
    {
        uint256 amountLeft = v.amount - v.amountClaimed;
        if (amountLeft == 0) return 0;
        if (block.timestamp >= vestingEndAt) {
            return amountLeft;
        }

        if (v.lastClaimAt == 0) {
            amount += (claimableAtStart * v.amount) / RATE_CONVERTER;
        }

        if (block.timestamp > cliffEndAt) {
            if ((v.lastClaimAt < stage1EndAt)) {
                uint256 start = Math.max(v.lastClaimAt, cliffEndAt);
                uint256 end = Math.min(block.timestamp, stage1EndAt);

                amount +=
                    (rateDuringStage1 * v.amount * (end - start)) /
                    (YEAR_IN_SECONDS * RATE_CONVERTER);
            }

            if ((block.timestamp > stage1EndAt)) {
                uint256 start = Math.max(v.lastClaimAt, stage1EndAt);
                uint256 end = Math.min(block.timestamp, vestingEndAt);

                amount +=
                    (rateDuringStage2 * v.amount * (end - start)) /
                    (YEAR_IN_SECONDS * RATE_CONVERTER);
            }
        }

        amount = Math.min(amount, amountLeft);

        return amount;
    }
}
