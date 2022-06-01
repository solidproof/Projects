// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PZVesting is Context{
   // Contract libs
    using SafeMath for uint256;


    // Contract events
    event Released(address indexed beneficiary, uint256 amount);

     // Addresses
    address internal constant SeedSale           =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant PrivateSale        =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant PublicSale         =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Team               =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Advisors           =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant GameInsentives     =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Marketing          =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Reserves           =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Liquidity          =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    address internal constant Exchanges          =0x6fF51ad15054e615Fd0A299Bb8777Da109135f96;
    // Vesting information struct
    struct VestingBeneficiary {
        address beneficiary;
        uint256 lockDuration;
        uint256 duration;
        uint256 amount;
        uint256 leftOverVestingAmount;
        uint256 released;
        uint256 upfrontAmount;
        uint256 startedAt;
        uint256 interval;
        uint256 lastReleasedAt;
    }

    IERC20 public token;
    // Vesting beneficiary list
    mapping(address => VestingBeneficiary) public beneficiaries;
    address[] public beneficiaryAddresses;
    // Token deployed date
    uint256 public tokenListingDate;
    uint256 public tokenVestingCap;

    constructor(address _token, uint256 _tokenListingDate) {
        require(_token != address(0), "The token's address cannot be 0");
        token = IERC20(_token);
        if (_tokenListingDate > 0) {
            tokenListingDate = _tokenListingDate;
        }

        addBeneficiary(SeedSale         ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(PrivateSale      ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(PublicSale       ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Team             ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Advisors         ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(GameInsentives   ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Marketing        ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Reserves         ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Liquidity        ,6000000000000000000000000,120,600,0,120);
        addBeneficiary(Exchanges        ,6000000000000000000000000,120,600,0,120);

    }

    // only added beneficiaries can release the vesting amount
    modifier onlyBeneficiaries() {
        require(beneficiaries[_msgSender()].amount > 0,"You cannot release tokens!");
        _;
    }

    /**
     * @dev Add new beneficiary to vesting contract with some conditions.
     */
    function addBeneficiary(
        address _beneficiary,
        uint256 _amount,
        uint256 _lockDuration,
        uint256 _duration,
        uint256 _upfrontAmount,
        uint256 _interval
    ) internal {
        require(
            _beneficiary != address(0),
            "The beneficiary's address cannot be 0"
        );

        require(_amount > 0, "Shares amount has to be greater than 0");
        require(
            tokenVestingCap.add(_amount) <= token.totalSupply(),
            "Full token vesting to other beneficiaries. Can not add new beneficiary"
        );
        require(
            beneficiaries[_beneficiary].amount == 0,
            "The beneficiary has added to the vesting pool already"
        );

        // Add new vesting beneficiary
        uint256 _leftOverVestingAmount = _amount.sub(_upfrontAmount);
        uint256 vestingStartedAt = tokenListingDate.add(_lockDuration);
        beneficiaries[_beneficiary] = VestingBeneficiary(
            _beneficiary,
            _lockDuration,
            _duration,
            _amount,
            _leftOverVestingAmount,
            0,
            _upfrontAmount,
            vestingStartedAt,
            _interval,
            0
        );

        beneficiaryAddresses.push(_beneficiary);
        tokenVestingCap = tokenVestingCap.add(_amount);
    }

    /**
     * @dev Get new vested amount of beneficiary base on vesting schedule of this beneficiary.
     */
    function releasableAmount(address _beneficiary)
    public
    view
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        if (beneficiaries[_beneficiary].amount == 0) {
            return (0, 0, block.timestamp);
        }

        (uint256 _vestedAmount, uint256 _lastIntervalDate) = vestedAmount(
            _beneficiary
        );

        return (
        _vestedAmount,
        _vestedAmount.sub(beneficiaries[_beneficiary].released),
        _lastIntervalDate
        );
    }

    /**
     * @dev Get total vested amount of beneficiary base on vesting schedule of this beneficiary.
     */
    function vestedAmount(address _beneficiary)
    public
    view
    returns (uint256, uint256)
    {
        require(beneficiaries[_beneficiary].amount > 0, "The beneficiary's address cannot be found");
        // Listing date is not set
        if (beneficiaries[_beneficiary].startedAt == 0) {
            return (beneficiaries[_beneficiary].released, beneficiaries[_beneficiary].lastReleasedAt);
        }

        // Transfer immediately if any upfront amount
        if (beneficiaries[_beneficiary].upfrontAmount > 0 && beneficiaries[_beneficiary].released == 0) {
            return (beneficiaries[_beneficiary].upfrontAmount, 0);
        }

        // No vesting (All amount unlock at the TGE)
        if (beneficiaries[_beneficiary].duration == 0) {
            return (beneficiaries[_beneficiary].amount, beneficiaries[_beneficiary].startedAt);
        }

        // Vesting has not started yet
        if (block.timestamp < beneficiaries[_beneficiary].startedAt) {
            return (beneficiaries[_beneficiary].released, beneficiaries[_beneficiary].lastReleasedAt);
        }

        // Vesting is done
        if (block.timestamp >= beneficiaries[_beneficiary].startedAt.add(beneficiaries[_beneficiary].duration)) {
            return (beneficiaries[_beneficiary].amount, beneficiaries[_beneficiary].startedAt.add(beneficiaries[_beneficiary].duration));
        }

        // It's too soon to next release
        if (
            beneficiaries[_beneficiary].lastReleasedAt > 0 &&
            block.timestamp < beneficiaries[_beneficiary].interval + beneficiaries[_beneficiary].lastReleasedAt
        ) {
            return (beneficiaries[_beneficiary].released, beneficiaries[_beneficiary].lastReleasedAt);
        }

        // Vesting is interval counter
        uint256 totalVestedAmount = beneficiaries[_beneficiary].released;
        uint256 lastIntervalDate = beneficiaries[_beneficiary].lastReleasedAt > 0
        ? beneficiaries[_beneficiary].lastReleasedAt
        : beneficiaries[_beneficiary].startedAt;

        uint256 multiplyIntervals;
        while (block.timestamp >= lastIntervalDate.add(beneficiaries[_beneficiary].interval)) {
            multiplyIntervals = multiplyIntervals.add(1);
            lastIntervalDate = lastIntervalDate.add(beneficiaries[_beneficiary].interval);
        }

        if (multiplyIntervals > 0) {
            uint256 newVestedAmount = beneficiaries[_beneficiary]
            .leftOverVestingAmount
            .mul(multiplyIntervals.mul(beneficiaries[_beneficiary].interval))
            .div(beneficiaries[_beneficiary].duration);

            totalVestedAmount = totalVestedAmount.add(newVestedAmount);
        }

        return (totalVestedAmount, lastIntervalDate);
    }

    /**
     * @dev Release vested tokens to a specified beneficiary.
     */
    function releaseTo(
        address _beneficiary,
        uint256 _amount,
        uint256 _lastIntervalDate
    ) internal returns (bool) {
        if (block.timestamp < _lastIntervalDate) {
            return false;
        }
        // Update beneficiary information
        beneficiaries[_beneficiary].released = beneficiaries[_beneficiary].released.add(_amount);
        beneficiaries[_beneficiary].lastReleasedAt = _lastIntervalDate;

        // Emit event to of new release
        emit Released(_beneficiary, _amount);
        // Transfer new released amount to vesting beneficiary
        token.transfer(_beneficiary, _amount);
        return true;
    }

    /**
     * @dev Release vested tokens to current beneficiary.
     */
    function releaseMyTokens() external onlyBeneficiaries {
        // Calculate the releasable amount
        (
        ,
        uint256 _newReleaseAmount,
        uint256 _lastIntervalDate
        ) = releasableAmount(_msgSender());

        // Release new vested token to the beneficiary
        if (_newReleaseAmount > 0) {
            releaseTo(_msgSender(), _newReleaseAmount, _lastIntervalDate);
        }
    }
}