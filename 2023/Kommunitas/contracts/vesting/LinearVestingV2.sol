// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

import '../interface/ILinearVestingFactoryV2.sol';
import '../interface/ILinearVestingV2.sol';

contract LinearVestingV2 is Initializable, PausableUpgradeable, ILinearVestingV2 {
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

  uint128 public tgeRatio_d2;
  uint128 public tgeAt; // epoch
  uint128 public startLinearAt; // epoch
  uint128 public endLinearAt; // epoch

  uint256 public sold;
  uint256 public tokenPrice; // Use stable decimal. If refund is done on another chain, use 18 as decimal
  uint256 public lastRefundAt; // epoch

  address[] public buyers;

  address public token;
  address public projectOwner;
  address public stable; // ignore if refund is done on another chain

  ILinearVestingFactoryV2 public factory;

  struct ProjectPayment {
    uint256 tokenReturned;
    uint256 stablePaid;
    bool isPaid;
  }

  struct RefundDetail {
    address buyer;
    uint256 stableRefunded;
  }

  struct Bought {
    uint128 buyerIndex;
    uint128 lastClaimedAt;
    uint256 purchased;
    uint256 linearPerSecond;
    uint256 claimed;
    uint256 stableRefunded;
    bool isTgeClaimed;
  }

  RefundDetail[] internal refunds;
  mapping(address => uint256) internal refundIndex;

  ProjectPayment public projectPayment;
  mapping(address => Bought) public invoice;

  event Claim(
    address buyer,
    uint128 lastClaimedAt,
    uint256 purchased,
    uint256 linearPerSecond,
    uint256 claimed,
    uint256 stableRefunded,
    bool isTgeClaimed
  );
  event Refund(
    address buyer,
    uint128 lastClaimedAt,
    uint256 purchased,
    uint256 linearPerSecond,
    uint256 claimed,
    uint256 stableRefunded,
    bool isTgeClaimed
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
   * @param _tgeAt TGE datetime in epoch
   * @param _tgeRatio_d2 TGE ratio in percent (2 decimal)
   * @param _startEndLinearDatetime Start & end Linear datetime in epoch
   */
  function init(
    address _token,
    address _stable,
    address _projectOwner,
    uint256 _tokenPrice,
    uint256 _lastRefundAt,
    uint128 _tgeAt,
    uint128 _tgeRatio_d2,
    uint128[2] calldata _startEndLinearDatetime
  ) external override initializer {
    factory = ILinearVestingFactoryV2(_msgSender());

    _setToken(_token);
    _setStable(_stable);
    _setTokenPrice(_tokenPrice);
    _setLastRefundAt(_lastRefundAt);
    _setProjectOwner(_projectOwner);
    _setStartEndLinearDatetime(_startEndLinearDatetime);

    if (_tgeAt > 0 && _tgeRatio_d2 > 0) {
      _setTgeDatetime(_tgeAt);
      _setTgeRatio(_tgeRatio_d2);
    }
  }

  /**
   * @dev Get length of buyer
   */
  function buyerLength() external view virtual returns (uint256 length) {
    length = buyers.length;
  }

  /**
   * @dev Get length of buyer refund
   */
  function refundLength() public view virtual returns (uint256 length) {
    length = refunds.length;
  }

  /**
   * @dev Get linear started status
   */
  function isLinearStarted() public view virtual returns (bool) {
    return startLinearAt < block.timestamp;
  }

  /**
   * @dev Get refund payload
   */
  function refundPayload() external view virtual returns (bytes memory payloadValue) {
    payloadValue = abi.encode(projectPayment.stablePaid, refunds);
    if (block.timestamp <= lastRefundAt || stable != address(0)) payloadValue = new bytes(0);
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
   * @dev Set TGE datetime
   * @param _tgeAt TGE datetime in epoch
   */
  function _setTgeDatetime(uint128 _tgeAt) internal virtual {
    tgeAt = _tgeAt;
  }

  /**
   * @dev Set TGE ratio
   * @param _tgeRatio_d2 TGE ratio in percent (2 decimal)
   */
  function _setTgeRatio(uint128 _tgeRatio_d2) internal virtual {
    tgeRatio_d2 = _tgeRatio_d2;
  }

  /**
   * @dev Set start & end linear datetime
   * @param _startEndLinearDatetime Start & end Linear datetime in epoch
   */
  function _setStartEndLinearDatetime(uint128[2] calldata _startEndLinearDatetime) internal virtual {
    require(
      block.timestamp < _startEndLinearDatetime[0] && _startEndLinearDatetime[0] < _startEndLinearDatetime[1],
      'bad'
    );

    startLinearAt = _startEndLinearDatetime[0];
    endLinearAt = _startEndLinearDatetime[1];
  }

  /**
   * @dev Insert new buyers & purchases
   * @param _buyer Buyer address
   * @param _purchased Buyer purchase
   */
  function newBuyers(address[] calldata _buyer, uint256[] calldata _purchased) external virtual onlyFactoryOwner {
    require(_buyer.length == _purchased.length && token != address(0) && tokenPrice > 0, 'misslength');

    uint256 tgeRatio = tgeRatio_d2;
    uint256 diffLinearDatetime = endLinearAt - startLinearAt;
    uint256 soldTemp = sold;
    for (uint128 i = 0; i < _buyer.length; ++i) {
      if (_buyer[i] == address(0) || _purchased[i] == 0) continue;

      Bought memory temp = invoice[_buyer[i]];

      if (temp.purchased == 0) {
        invoice[_buyer[i]].buyerIndex = uint128(buyers.length);
        buyers.push(_buyer[i]);
      }

      uint256 purchasedAmount = temp.purchased + _purchased[i];
      invoice[_buyer[i]].purchased = purchasedAmount;
      invoice[_buyer[i]].linearPerSecond = ((purchasedAmount * (10000 - tgeRatio)) / 10000) / diffLinearDatetime;
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
   * @dev Token claim
   */
  function claimToken() external virtual whenNotPaused {
    address buyer = _msgSender();
    bool linearStarted = isLinearStarted();
    Bought memory temp = invoice[buyer];

    require(tgeAt <= block.timestamp && token != address(0), '!started');
    require(temp.purchased > 0 && temp.lastClaimedAt <= endLinearAt, 'bad');
    if (temp.isTgeClaimed) require(linearStarted, 'wait');
    require(temp.stableRefunded == 0, 'refunded');

    uint256 amountToClaim;

    // if tge is exists & haven't claimed yet
    if (tgeAt > 0 && !temp.isTgeClaimed) {
      invoice[buyer].isTgeClaimed = true;
      amountToClaim = (temp.purchased * tgeRatio_d2) / 10000;
    }

    if (linearStarted) {
      if (temp.lastClaimedAt < startLinearAt && block.timestamp >= endLinearAt) {
        amountToClaim += (temp.purchased * (10000 - tgeRatio_d2)) / 10000;
      } else {
        uint128 lastClaimed = temp.lastClaimedAt < startLinearAt ? startLinearAt : temp.lastClaimedAt;
        uint128 claimNow = block.timestamp >= endLinearAt ? endLinearAt : uint128(block.timestamp);
        amountToClaim += ((claimNow - lastClaimed) * temp.linearPerSecond);
      }
    }

    require(
      IERC20MetadataUpgradeable(token).balanceOf(address(this)) >= amountToClaim && amountToClaim > 0,
      'insufficient'
    );

    uint256 claimAmount = temp.claimed + amountToClaim;
    invoice[buyer].claimed = claimAmount;
    invoice[buyer].lastClaimedAt = uint128(block.timestamp);

    IERC20MetadataUpgradeable(token).safeTransfer(buyer, amountToClaim);

    emit Claim(
      buyer,
      uint128(block.timestamp),
      temp.purchased,
      temp.linearPerSecond,
      claimAmount,
      temp.stableRefunded,
      temp.isTgeClaimed
    );
  }

  /**
   * @dev Token refund
   */
  function refund() external virtual whenNotPaused {
    address buyer = _msgSender();
    Bought memory temp = invoice[buyer];

    require(block.timestamp <= lastRefundAt, 'over');
    require(temp.purchased > 0 && token != address(0) && tokenPrice > 0, 'bad');
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

    emit Refund(
      buyer,
      uint128(block.timestamp),
      temp.purchased,
      temp.linearPerSecond,
      temp.claimed,
      temp.stableRefunded,
      temp.isTgeClaimed
    );
  }

  /**
   * @dev Token payment to project owner
   */
  function payToProject() external virtual whenNotPaused {
    require(block.timestamp > lastRefundAt, '!claimable');
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

    uint256 tgeRatio = tgeRatio_d2;
    uint256 diffLinearDatetime = endLinearAt - startLinearAt;
    uint256 soldTemp = sold;
    for (uint128 i = 0; i < _buyer.length; ++i) {
      Bought memory temp = invoice[_buyer[i]];

      if (temp.purchased == 0 || temp.claimed > 0 || _buyer[i] == address(0) || _newPurchased[i] == 0) continue;

      soldTemp = soldTemp - temp.purchased + _newPurchased[i];
      invoice[_buyer[i]].purchased = _newPurchased[i];
      invoice[_buyer[i]].linearPerSecond = ((_newPurchased[i] * (10000 - tgeRatio)) / 10000) / diffLinearDatetime;
    }

    sold = soldTemp;
    projectPayment.stablePaid = _calculateStableAmount(soldTemp);
  }

  /**
   * @dev Set TGE datetime
   * @param _tgeAt TGE datetime in epoch
   */
  function setTgeDatetime(uint128 _tgeAt) external virtual onlyFactoryOwner {
    _setTgeDatetime(_tgeAt);
  }

  /**
   * @dev Set TGE ratio
   * @param _tgeRatio_d2 TGE ratio in percent (2 decimal)
   */
  function setTgeRatio(uint128 _tgeRatio_d2) external virtual onlyFactoryOwner {
    _setTgeRatio(_tgeRatio_d2);
  }

  /**
   * @dev Set start & end linear datetime
   * @param _startEndLinearDatetime Start & end Linear datetime in epoch
   */
  function setStartEndLinearDatetime(uint128[2] calldata _startEndLinearDatetime) external virtual onlyFactoryOwner {
    _setStartEndLinearDatetime(_startEndLinearDatetime);
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
