// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

/**
  @dev Abstract contract containing vesting logics.
        To be implemented by IFSale.
  @notice There are two vesting types: linear and cliff
  @notice Can only set one vesting type
  @notice Once one of the vesting type is set, another one will be reset
  @notice Linear vesting unlocks tokens at a linear scale. Calculated by vesting end time
  @notice Cliff vesting unlocks tokens at a series of specific time. According to cliff period
 */
abstract contract LaunchpadVesting is Ownable {
    uint64 private constant TEN_YEARS = 315_569_260;

    uint256 private constant percent_100 = 100_000;

    // --- VESTING

    // withdraw/cash delay timestamp (inclusive)
    uint256 public withdrawTime;
    // the most recent time the user claimed the saleToken
    mapping(address => uint256) public latestClaimTime;

    // --- LINEAR VESTING

    // the time where the user can take all of the vested saleToken
    uint256 public linearVestingEndTime;
    event SetLinearVestingEndTime(uint256 indexed linearVestingEndTime);

    // --- CLIFF VESTING

    // store how many percentage of the token can be claimed at a certain cliff date
    struct Cliff {
        // the date when the percentage of token can be claimed
        uint256 claimTime;
        // the percentage token that can be claimed
        uint256 pct;
    }
    // cliff vesting time and percentage
    Cliff[] public cliffPeriod;
    event SetCliffVestingPeriod(Cliff[] indexed cliffPeriod);

    function getCliffPeriod() public view returns (Cliff[] memory) {
        return cliffPeriod;
    }

    /** @notice WithdrawTime Event */
    event WithdrawTime(address indexed sender, uint256 withdrawTime);

    // --- CONSTRUCTOR

    constructor(
        // withdrawTime is endTime + withdrawal delay
        uint256 _withdrawTime
    ) {
        withdrawTime = _withdrawTime;
        emit WithdrawTime(msg.sender, withdrawTime);
    }

    // --- SETTER

    function _setWithdrawTime(uint256 _withdrawTime) internal {
        require(
            _withdrawTime > block.timestamp,
            "_withdrawTime is in the past"
        );
        require(withdrawTime > block.timestamp, "withdrawTime already passed");
        withdrawTime = _withdrawTime;
        // unset cliff vesting
        delete cliffPeriod;
        // unset linear vesting
        linearVestingEndTime = 0;
        emit WithdrawTime(msg.sender, withdrawTime);
    }

    // Function for owner to set a vesting end time
    function setLinearVestingEndTime(
        uint256 _linearVestingEndTime
    ) public virtual onlyOwner {
        require(
            block.timestamp < withdrawTime,
            "Can't edit vesting after sale"
        );
        require(
            _linearVestingEndTime > withdrawTime,
            "vesting end time has to be after withdrawal start time"
        );
        require(
            withdrawTime > _linearVestingEndTime - TEN_YEARS,
            "vesting end time has to be within 10 years"
        );
        linearVestingEndTime = _linearVestingEndTime;

        // unset cliff vesting
        delete cliffPeriod;
        emit SetLinearVestingEndTime(_linearVestingEndTime);
    }

    function setCliffPeriod(
        Cliff[] memory cliffPeriod_
    ) public virtual onlyOwner {
        require(
            block.timestamp < withdrawTime,
            "Can't edit vesting after sale"
        );
        require(cliffPeriod_.length > 0, "input is empty");
        require(cliffPeriod_.length <= 100, "input length cannot exceed 100");

        // clear the past entry
        delete cliffPeriod;

        uint256 maxDate;
        uint256 totalPct;
        require(
            cliffPeriod_[0].claimTime > withdrawTime,
            "first claim time is before end time + withdraw delay"
        );
        for (uint i = 0; i < cliffPeriod_.length; ) {
            require(
                maxDate < cliffPeriod_[i].claimTime,
                "dates not in ascending order"
            );
            require(cliffPeriod_[i].pct != 0, "percentage is zero");
            maxDate = cliffPeriod_[i].claimTime;
            totalPct += cliffPeriod_[i].pct;
            cliffPeriod.push(cliffPeriod_[i]);
            unchecked {
                i++;
            }
        }
        require(
            withdrawTime > maxDate - TEN_YEARS,
            "vesting end time has to be within 10 years"
        );
        // pct is the release percentage, with a precision of 100 ( 1% is 1000). Thus, the sum of all elements of pct must be equal to 10000
        require(
            totalPct == percent_100,
            "total input percentage doesn't equal to 100000"
        );

        // unset linear vesting
        linearVestingEndTime = 0;
    }

    // --- VESTING LOGIC

    /**
      @notice Get the amount of token unlocked
      @param totalPurchased Total tokens purchased
      @param user Address of the user claiming the tokens
     */
    function getUnlockedToken(
        uint256 totalPurchased,
        uint256 claimable,
        address user
    ) public view virtual returns (uint256) {
        uint256 cliffPeriodLength = cliffPeriod.length;
        require(
            linearVestingEndTime > 0 || cliffPeriodLength > 0,
            "linearVestingEndTime or cliffPeriodLength is not defined"
        );
        // linear vesting
        if (linearVestingEndTime > block.timestamp) {
            // current claimable = total purchased * (now - last claimed time) / (total vesting time)
            return
                (totalPurchased *
                    (block.timestamp -
                        Math.max(latestClaimTime[user], withdrawTime))) /
                (linearVestingEndTime - withdrawTime);
        }

        // cliff vesting
        if (
            cliffPeriodLength != 0 &&
            cliffPeriod[cliffPeriodLength - 1].claimTime > block.timestamp
        ) {
            uint256 claimablePct;
            for (uint256 i; i < cliffPeriodLength; ) {
                // if the cliff timestamp has been passed, add the claimable percentage
                if (cliffPeriod[i].claimTime > block.timestamp) {
                    break;
                }
                if (latestClaimTime[user] < cliffPeriod[i].claimTime) {
                    claimablePct += cliffPeriod[i].pct;
                }
                unchecked {
                    ++i;
                }
            }
            // current claimable = total * claimiable percentage
            if (claimablePct == 0) {
                return 0;
            }
            return (totalPurchased * claimablePct) / percent_100;
        }

        // When vesting end, claim all of the remaining tokens.
        // Since all of the above calculations return a lower rounded number,
        // users will get a little bit less tokens.
        // Keeping track and returning the total remaining claimable makes sure the users will get the exact amount.
        return claimable;
    }
}
