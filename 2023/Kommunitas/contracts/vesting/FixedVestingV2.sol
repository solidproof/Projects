// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

import '../interface/IFixedVestingFactoryV2.sol';
import '../interface/IFixedVestingV2.sol';

contract FixedVestingV2 is Initializable, PausableUpgradeable, IFixedVestingV2 {
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

  uint256 public sold;
  uint256 public tokenPrice; // Use stable decimal. If refund is done on another chain, use 18 as decimal
  uint256 public lastRefundAt; // epoch

  address[] public buyers;

  address public token;
  address public projectOwner;
  address public stable; // ignore if refund is done on another chain

  IFixedVestingFactoryV2 public factory;

  struct ProjectPayment {
    uint256 tokenReturned;
    uint256 stablePaid;
    bool isPaid;
  }

  struct Detail {
    uint256 datetime;
    uint256 ratio_d2;
  }

  struct RefundDetail {
    address buyer;
    uint256 stableRefunded;
  }

  struct Bought {
    uint128 buyerIndex;
    uint128 completed_d2; // in percent (2 decimal)
    uint256 purchased;
    uint256 claimed;
    uint256 stableRefunded;
  }

  RefundDetail[] internal refunds;
  mapping(address => uint256) internal refundIndex;

  Detail[] public vestings;
  ProjectPayment public projectPayment;
  mapping(address => Bought) public invoice;

  event Claim(
    address buyer,
    uint256 completed_d2,
    uint256 purchased,
    uint256 claimed,
    uint256 stableRefunded,
    uint256 claimedAt
  );
  event Refund(
    address buyer,
    uint256 completed_d2,
    uint256 purchased,
    uint256 claimed,
    uint256 stableRefunded,
    uint256 refundedAt
  );
  event PayToProject(address projectOwner, uint256 tokenReturned, uint256 stablePaid, uint256 paidAt);

  modifier onlyFactoryOwner() {
    require(_msgSender() == factory.owner(), '!owner');
    _;
  }

  /**
   * @dev Initialize vesting token distribution
   * @param _token Token project address
   * @param _stable Stable token address
   * @param _tokenPrice Token price (in stable decimal)
   * @param _lastRefundAt Last datetime to refund (epoch)
   * @param _projectOwner Project owner address
   * @param _datetime Vesting datetime (epoch)
   * @param _ratio_d2 Vesting ratio in percent (decimal 2)
   */
  function init(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint256[] calldata _datetime,
    uint256[] calldata _ratio_d2
  ) external override initializer {
    factory = IFixedVestingFactoryV2(_msgSender());

    _setToken(_token);
    _setStable(_stable);
    _setTokenPrice(_tokenPrice);
    _setLastRefundAt(_lastRefundAt);
    _setProjectOwner(_projectOwner);
    _newVesting(_datetime, _ratio_d2);
  }

  /**
   * @dev Get length of buyer
   */
  function buyerLength() external view virtual returns (uint256 length) {
    length = buyers.length;
  }

  /**
   * @dev Get length of vesting
   */
  function vestingLength() public view virtual returns (uint256 length) {
    length = vestings.length;
    if (length > 0) length -= 1;
  }

  /**
   * @dev Get length of buyer refund
   */
  function refundLength() public view virtual returns (uint256 length) {
    length = refunds.length;
  }

  /**
   * @dev Get refund payload
   */
  function refundPayload() external view virtual returns (bytes memory payloadValue) {
    payloadValue = abi.encode(projectPayment.stablePaid, refunds);
    if (block.timestamp <= lastRefundAt || stable != address(0)) payloadValue = new bytes(0);
  }

  /**
   * @dev Get vesting runnning
   */
  function vestingRunning() public view virtual returns (uint256 round, uint256 totalPercent_d2) {
    uint256 vestingSize = vestingLength();
    uint256 total;
    for (uint256 i = 1; i <= vestingSize; ++i) {
      Detail memory temp = vestings[i];
      total += temp.ratio_d2;

      if (
        (i < vestingSize && temp.datetime <= block.timestamp && block.timestamp <= vestings[i + 1].datetime) ||
        (i == vestingSize && block.timestamp >= temp.datetime)
      ) {
        round = i;
        totalPercent_d2 = total;
        break;
      }
    }
  }

  /**
   * @dev Calculate total ratio
   */
  function totalRatio() public view virtual returns (uint256 total) {
    uint256 vestingSize = vestingLength();
    for (uint256 i = 1; i <= vestingSize; ++i) {
      Detail memory temp = vestings[i];
      total += temp.ratio_d2;
    }
  }

  /**
   * @dev Calculate stable token amount have to be paid
   */
  function _calculateStableAmount(uint256 tokenAmount) internal view virtual returns (uint256) {
    return (tokenAmount * tokenPrice) / (10 ** IERC20MetadataUpgradeable(token).decimals());
  }

  /**
   * @dev Set token project
   * @param _token Token project address
   */
  function _setToken(address _token) internal virtual {
    token = _token;
  }

  /**
   * @dev Set stable project
   * @param _stable Stable project address
   */
  function _setStable(address _stable) internal virtual {
    stable = _stable;
  }

  /**
   * @dev Set last refund project
   * @param _lastRefundAt Last refund project
   */
  function _setLastRefundAt(uint256 _lastRefundAt) internal virtual {
    require(_lastRefundAt > block.timestamp, 'bad');
    lastRefundAt = _lastRefundAt;
  }

  /**
   * @dev Set token pice project
   * @param _tokenPrice Token project address
   */
  function _setTokenPrice(uint256 _tokenPrice) internal virtual {
    require(_tokenPrice > 0, 'bad');
    tokenPrice = _tokenPrice;
  }

  /**
   * @dev Set project owner to receive returned token & stable
   * @param _projectOwner Token project address
   */
  function _setProjectOwner(address _projectOwner) internal virtual {
    projectOwner = _projectOwner;
  }

  /**
   * @dev Insert new vestings
   * @param _datetime Vesting datetime
   * @param _ratio_d2 Vesting ratio in percent (decimal 2)
   */
  function _newVesting(uint256[] calldata _datetime, uint256[] calldata _ratio_d2) internal virtual {
    require(_datetime.length == _ratio_d2.length, 'misslength');

    if (vestingLength() == 0) vestings.push();

    for (uint256 i = 0; i < _datetime.length; ++i) {
      if (i != _datetime.length - 1) require(_datetime[i] < _datetime[i + 1], 'bad');
      vestings.push(Detail(_datetime[i], _ratio_d2[i]));
    }
  }

  /**
   * @dev Insert new vestings
   * @param _datetime Vesting datetime
   * @param _ratio_d2 Vesting ratio in percent (decimal 2)
   */
  function newVesting(uint256[] calldata _datetime, uint256[] calldata _ratio_d2) external virtual onlyFactoryOwner {
    _newVesting(_datetime, _ratio_d2);
  }

  /**
   * @dev Update vestings datetime
   * @param _vestingRound Vesting round
   * @param _newDatetime new datetime in epoch
   */
  function updateVestingDatetimes( 
    uint256[] calldata _vestingRound,
    uint256[] calldata _newDatetime
  ) external virtual onlyFactoryOwner {
    uint256 vestingSize = vestingLength();

    require(_vestingRound.length == _newDatetime.length && _vestingRound.length <= vestingSize, 'misslength');

    (uint256 round, ) = vestingRunning();

    for (uint256 i = 0; i < _vestingRound.length; ++i) {
      if (_vestingRound[i] > vestingSize || round >= _vestingRound[i]) continue;

      vestings[_vestingRound[i]].datetime = _newDatetime[i];
    }
  }

  /**
   * @dev Update vestings ratio
   * @param _vestingRound Vesting round
   * @param _newRatio_d2 New ratio in percent (decimal 2)
   */
  function updateVestingRatios(
    uint256[] calldata _vestingRound,
    uint256[] calldata _newRatio_d2
  ) external virtual onlyFactoryOwner {
    uint256 vestingSize = vestingLength();
    require(_vestingRound.length == _newRatio_d2.length && _vestingRound.length <= vestingSize, 'misslength');

    (uint256 round, ) = vestingRunning();

    for (uint256 i = 0; i < _vestingRound.length; ++i) {
      if (_vestingRound[i] > vestingSize || round >= _vestingRound[i]) continue;

      vestings[_vestingRound[i]].ratio_d2 = _newRatio_d2[i];
    }
  }

  /**
   * @dev Remove last vesting round
   */
  function removeLastVestingRound() external virtual onlyFactoryOwner {
    vestings.pop();
  }

  /**
   * @dev Insert new buyers & purchases
   * @param _buyer Buyer address
   * @param _purchased Buyer purchase
   */
  function newBuyers(address[] calldata _buyer, uint256[] calldata _purchased) external virtual onlyFactoryOwner {
    require(_buyer.length == _purchased.length && token != address(0) && tokenPrice > 0, 'misslength');

    uint256 soldTemp = sold;
    for (uint128 i = 0; i < _buyer.length; ++i) {
      if (_buyer[i] == address(0) || _purchased[i] == 0) continue;

      Bought memory temp = invoice[_buyer[i]];

      if (temp.purchased == 0) {
        invoice[_buyer[i]].buyerIndex = uint128(buyers.length);
        buyers.push(_buyer[i]);
      }

      invoice[_buyer[i]].purchased = temp.purchased + _purchased[i];
      soldTemp += _purchased[i];
    }

    sold = soldTemp;
    projectPayment.stablePaid = _calculateStableAmount(soldTemp);
  }

  /**
   * @dev Replace buyers address
   * @param _oldBuyer Old address
   * @param _newBuyer New purchase
   */
  function replaceBuyers(address[] calldata _oldBuyer, address[] calldata _newBuyer) external virtual onlyFactoryOwner {
    require(_oldBuyer.length == _newBuyer.length && buyers.length > 0, 'misslength');

    for (uint128 i = 0; i < _oldBuyer.length; ++i) {
      Bought memory temp = invoice[_oldBuyer[i]];

      if (temp.purchased == 0 || _oldBuyer[i] == address(0) || _newBuyer[i] == address(0)) continue;

      buyers[temp.buyerIndex] = _newBuyer[i];
      invoice[_newBuyer[i]] = temp;
      delete invoice[_oldBuyer[i]];

      uint256 refundOldBuyerIndex = refundIndex[_oldBuyer[i]];
      if (refunds.length == 0 || (refunds.length > 0 && refunds[refundOldBuyerIndex].buyer != _oldBuyer[i])) continue;

      refunds[refundOldBuyerIndex].buyer = _newBuyer[i];
      refundIndex[_newBuyer[i]] = refundOldBuyerIndex;
      delete refundIndex[_oldBuyer[i]];
    }
  }

  /**
   * @dev Remove buyers
   * @param _buyer Buyer address
   */
  function removeBuyers(address[] calldata _buyer) external virtual onlyFactoryOwner {
    require(buyers.length > 0 && token != address(0) && tokenPrice > 0, 'bad');

    uint256 soldTemp = sold;
    for (uint128 i = 0; i < _buyer.length; ++i) {
      Bought memory temp = invoice[_buyer[i]];

      if (temp.purchased == 0 || _buyer[i] == address(0)) continue;

      soldTemp -= temp.purchased;

      address addressToMove = buyers[buyers.length - 1];

      buyers[temp.buyerIndex] = addressToMove;
      invoice[addressToMove].buyerIndex = temp.buyerIndex;

      buyers.pop();
      delete invoice[_buyer[i]];
    }

    sold = soldTemp;
    projectPayment.stablePaid = _calculateStableAmount(soldTemp);
  }

  /**
   * @dev Replace buyers purchase
   * @param _buyer Buyer address
   * @param _newPurchased new purchased
   */
  function replacePurchases(
    address[] calldata _buyer,
    uint256[] calldata _newPurchased
  ) external virtual onlyFactoryOwner {
    require(
      _buyer.length == _newPurchased.length && buyers.length > 0 && token != address(0) && tokenPrice > 0,
      'misslength'
    );

    uint256 soldTemp = sold;
    for (uint128 i = 0; i < _buyer.length; ++i) {
      Bought memory temp = invoice[_buyer[i]];

      if (temp.purchased == 0 || temp.completed_d2 > 0 || _buyer[i] == address(0) || _newPurchased[i] == 0) continue;

      soldTemp = soldTemp - temp.purchased + _newPurchased[i];
      invoice[_buyer[i]].purchased = _newPurchased[i];
    }

    sold = soldTemp;
    projectPayment.stablePaid = _calculateStableAmount(soldTemp);
  }

  /**
   * @dev Token claim
   */
  function claimToken() external virtual whenNotPaused {
    (uint256 round, uint256 totalPercent_d2) = vestingRunning();

    address buyer = _msgSender();
    Bought memory temp = invoice[buyer];

    require(round > 0 && token != address(0) && totalRatio() == 10000, 'bad');
    require(temp.purchased > 0, '!buyer');
    require(temp.completed_d2 < totalPercent_d2, 'claimed');
    require(temp.stableRefunded == 0, 'refunded');

    uint256 amountToClaim;
    if (temp.completed_d2 == 0) {
      amountToClaim = (temp.purchased * totalPercent_d2) / 10000;
    } else {
      amountToClaim = ((temp.claimed * totalPercent_d2) / temp.completed_d2) - temp.claimed;
    }

    require(
      IERC20MetadataUpgradeable(token).balanceOf(address(this)) >= amountToClaim && amountToClaim > 0,
      'insufficient'
    );

    invoice[buyer].completed_d2 = uint128(totalPercent_d2);
    invoice[buyer].claimed = temp.claimed + amountToClaim;

    IERC20MetadataUpgradeable(token).safeTransfer(buyer, amountToClaim);

    emit Claim(
      buyer,
      totalPercent_d2,
      temp.purchased,
      temp.claimed + amountToClaim,
      temp.stableRefunded,
      block.timestamp
    );
  }

  /**
   * @dev Token refund
   */
  function refund() external virtual whenNotPaused {
    address buyer = _msgSender();
    Bought memory temp = invoice[buyer];

    require(block.timestamp <= lastRefundAt, 'over');
    require(temp.purchased > 0 && token != address(0) && tokenPrice > 0 && totalRatio() == 10000, 'bad');
    require(temp.stableRefunded == 0, 'refunded');

    uint256 tokenReturned = temp.purchased - temp.claimed;
    uint256 stablePaid = _calculateStableAmount(tokenReturned);

    refundIndex[buyer] = refunds.length;
    refunds.push(RefundDetail(buyer, stablePaid));

    invoice[buyer].stableRefunded = stablePaid;

    projectPayment.tokenReturned += tokenReturned;
    projectPayment.stablePaid -= stablePaid;

    // refund stable if possible
    if (stable != address(0)) {
      require(
        IERC20MetadataUpgradeable(stable).balanceOf(address(this)) >= stablePaid && stablePaid > 0,
        'insufficient'
      );
      IERC20MetadataUpgradeable(stable).safeTransfer(buyer, stablePaid);
    }

    emit Refund(buyer, temp.completed_d2, temp.purchased, temp.claimed, temp.stableRefunded, block.timestamp);
  }

  /**
   * @dev Token payment to project owner
   */
  function payToProject() external virtual whenNotPaused {
    require(block.timestamp > lastRefundAt && totalRatio() == 10000, '!claimable');
    require(_msgSender() == projectOwner, '!projectOwner');

    ProjectPayment memory temp = projectPayment;
    require(!temp.isPaid, 'paid');

    projectPayment.isPaid = true;

    require(
      token != address(0) && IERC20MetadataUpgradeable(token).balanceOf(address(this)) >= temp.tokenReturned,
      'insufficient'
    );

    // return token
    if (temp.tokenReturned > 0) {
      IERC20MetadataUpgradeable(token).safeTransfer(projectOwner, temp.tokenReturned);
    }

    // pay stable if possible
    if (stable != address(0)) {
      if (temp.stablePaid > 0) {
        require(IERC20MetadataUpgradeable(stable).balanceOf(address(this)) >= temp.stablePaid, 'insufficient');
        IERC20MetadataUpgradeable(stable).safeTransfer(projectOwner, temp.stablePaid);
      }
    }

    emit PayToProject(projectOwner, temp.tokenReturned, temp.stablePaid, block.timestamp);
  }

  /**
   * @dev Emergency condition to withdraw any token
   * @param _token Token address
   * @param _target Target address
   * @param _amount Amount to withdraw
   */
  function emergencyWithdraw(address _token, address _target, uint256 _amount) external virtual onlyFactoryOwner {
    require(_target != address(0), 'bad');

    uint256 contractBalance = uint256(IERC20MetadataUpgradeable(_token).balanceOf(address(this)));
    if (_amount > contractBalance) _amount = contractBalance;

    IERC20MetadataUpgradeable(_token).safeTransfer(_target, _amount);
  }

  /**
   * @dev Set token price project
   * @dev If refund is done on another chain, use 18 as default decimal
   * @dev Otherwise, use stable decimal
   * @param _tokenPrice Token project address
   */
  function setTokenPrice(uint256 _tokenPrice) external virtual onlyFactoryOwner {
    _setTokenPrice(_tokenPrice);
  }

  /**
   * @dev Set stable project
   * @param _stable Token project address
   */
  function setStable(address _stable) external virtual onlyFactoryOwner {
    _setStable(_stable);
  }

  /**
   * @dev Set lastRefundAt project
   * @param _lastRefundAt Last refund project address
   */
  function setLastRefundAt(uint256 _lastRefundAt) external virtual onlyFactoryOwner {
    _setLastRefundAt(_lastRefundAt);
  }

  /**
   * @dev Set token project
   * @param _token Token project address
   */
  function setToken(address _token) external virtual onlyFactoryOwner {
    require(_token != address(0), 'bad');
    _setToken(_token);
  }

  /**
   * @dev Set project owner to receive returned token & stable
   * @param _projectOwner Token project address
   */
  function setProjectOwner(address _projectOwner) external virtual onlyFactoryOwner {
    require(_projectOwner != address(0), 'bad');
    _setProjectOwner(_projectOwner);
  }

  /**
   * @dev Pause vesting activity
   */
  function togglePause() external virtual onlyFactoryOwner {
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }
}
