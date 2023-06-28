// Submitted for verification at BscScan.com on 2023-xx-xx
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  address private beneficiary_; //address to send tokens after lockDuration_
  uint256 private start_; //start of lockDuration_
  uint256 private vestingDuration_; //linear vesting time after lock time (lockDuration_)
  uint256 private lockDuration_; //lock time from start_
  mapping (address => uint256) private released;

  event TokensReleased(IERC20 token, uint256 amount);
  event VestingStartedNow(uint256 startTime);
  event BeneficiaryUpdated(address  indexed _newBeneficiary,address indexed _beneficiary);

  constructor(
    address _beneficiary,
    uint256 _start,
    uint256 _lockDuration,
    uint256 _vestingDuration
  )
  {
    require(_beneficiary != address(0), "Error: beneficiary cannot be zero address");
    require((_vestingDuration > 0), "Error: vestingDuration has to be greater than zero");
    require((_start.add(_lockDuration).add(_vestingDuration)> block.timestamp), "Error: End of vesting has to be in the future");
    beneficiary_ = _beneficiary;
    start_ = _start;
    vestingDuration_ = _vestingDuration;
    lockDuration_ = _lockDuration;
  }

  function beneficiary() public view returns(address) {
    return beneficiary_;
  }

  function start() public view returns(uint256) {
    return start_;
  }

  function lockDuration() public view returns(uint256) {
    return lockDuration_;
  }

  function vestingDuration() public view returns(uint256) {
    return vestingDuration_;
  }

  function getLockEnd() public view returns(uint256) {
    return start_.add(lockDuration_); //after this time linear vesting starts
  }

  function getVestingEnd() public view returns(uint256) {
    return start_.add(lockDuration_).add(vestingDuration_); //after this time all tokens can be released
  }

  function startVestingNow() public onlyOwner { //start lock time; lock time can be extended with this function
    start_ = block.timestamp;
    emit VestingStartedNow(start_);
  }

  function releasedTokens(address _token) public view returns(uint256) {
    return released[_token];
  }

  function release(IERC20 _token) public onlyOwner {
    uint256 unreleased = releasableAmount(_token);
    require(unreleased > 0, "Error: no tokens to release");
    released[address(_token)] = released[address(_token)].add(unreleased);
    _token.safeTransfer(beneficiary_, unreleased);
    emit TokensReleased(_token, unreleased);
  }

  function releasableAmount(IERC20 _token) public view returns (uint256) {
    uint256 _vestedAmountOfTokens = _vestedAmount(_token);
    if(_vestedAmountOfTokens < released[address(_token)]) {
        return 0;
    }
    else {
        return _vestedAmountOfTokens.sub(released[address(_token)]);
    }
  }

  function _vestedAmount(IERC20 _token) private view returns (uint256) {
    uint256 currentBalance = _token.balanceOf(address(this));
    uint256 totalBalance = currentBalance.add(released[address(_token)]);
    uint256 lockEnd = start_.add(lockDuration_);
    uint256 vestingEnd = lockEnd.add(vestingDuration_);

    if (block.timestamp < lockEnd) {
      return 0;
    } else if (block.timestamp >= vestingEnd) {
      return totalBalance;
    } else {
      return totalBalance.mul(block.timestamp.sub(lockEnd)).div(vestingDuration_);
    }
  }

  //necessary in case beneficiary_ has to be changed in the future
  function updateBeneficiary(address _newBeneficiary) external onlyOwner {
      require(_newBeneficiary != address(0), "Error: Address cannot be zero");
      require(_newBeneficiary != beneficiary_, "Error: The _beneficiary is already this address");
      emit BeneficiaryUpdated(_newBeneficiary, beneficiary_);
      beneficiary_ = _newBeneficiary;
  }
}

//constructor(address _beneficiary, uint256 _start, uint256 _lockDuration,uint256 _vestingDuration)
//1 year = 60*60*24*365 seconds = 31_536_000; 5 years = 31_536_000*5 = 157_680_000 seconds
contract LongTermGrowthTokenVesting is TokenVesting {
    //lockDuration = 5 years = 157_680_000, vestingDuration = 1 year = 31_536_000
    constructor () TokenVesting(address(0x521e0823E6905ca6BE44797De7679AC007B4F1Ed), block.timestamp, 157680000, 31536000) { }
}

contract TeamTokenVesting is TokenVesting {
    //lockDuration = 1 year = 31_536_000, vestingDuration = 1 year = 31_536_000
    constructor () TokenVesting(address(0x0ceF20D3955b63cDcDc566F1cCa698C8E2189425), block.timestamp, 31536000, 31536000) { }
}

contract EcosystemTokenVesting is TokenVesting {
    //lockDuration = 0, vestingDuration = 1 year = 31_536_000
    constructor () TokenVesting(address(0x5bFc6665c6397ca4bFdee5D4f4806B75ec64807a), block.timestamp, 0, 31536000) { }
}

contract Pool3BurnForever is TokenVesting {
    //lockDuration = near to max value of uint256, vestingDuration = 1 (zero not possible)
    uint256 private pool3LockDuration = type(uint256).max - block.timestamp * 2;
    constructor () TokenVesting(address(0x5bFc6665c6397ca4bFdee5D4f4806B75ec64807a), block.timestamp, pool3LockDuration, 1) { }
}