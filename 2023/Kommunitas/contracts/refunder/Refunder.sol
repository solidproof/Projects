// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';

import '../interface/IRefunderFactory.sol';
import '../interface/IRefunder.sol';

contract Refunder is Initializable, PausableUpgradeable, IRefunder {
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

  uint256 public totalRefunded;
  uint256 public totalPaidToProject;
  uint256 public payToProjectOwnerAt; // datetime project owner could claim its stable (epoch)

  address public projectOwner;
  address public stable; // ignore if refund is done on another chain

  bool public isRefunded;
  bool public isPaid;

  IRefunderFactory public factory;
  struct RefundDetail {
    address buyer;
    uint256 stableRefunded;
  }

  RefundDetail[] public refunds;

  event UserRefund(address buyer, uint256 stableRefunded);
  event PayToProject(address projectOwner, uint256 stablePaid, uint256 paidAt);

  modifier onlyFactoryOwner() {
    require(_msgSender() == factory.owner(), '!owner');
    _;
  }

  /**
   * @dev Initialize vesting token distribution
   * @param _stable Token project address
   * @param _projectOwner Project owner address
   * @param _payToProjectOwnerAt Payment start to project owner (epoch)
   */
  function init(address _stable, address _projectOwner, uint256 _payToProjectOwnerAt) external override initializer {
    factory = IRefunderFactory(_msgSender());

    _setStable(_stable);
    _setProjectOwner(_projectOwner);
    _setPayToProjectOwnerAt(_payToProjectOwnerAt);
  }

  /**
   * @dev Get length of buyer refund
   */
  function refundLength() public view virtual returns (uint256 length) {
    length = refunds.length;
  }

  /**
   * @dev Set stable project
   * @param _stable Stable project address
   */
  function _setStable(address _stable) internal virtual {
    require(_stable != address(0), 'bad');
    stable = _stable;
  }

  /**
   * @dev Set project owner to receive returned token & stable
   * @param _projectOwner Token project address
   */
  function _setProjectOwner(address _projectOwner) internal virtual {
    projectOwner = _projectOwner;
  }

  /**
   * @dev Set datetime project owner could claim its stable
   * @param _payToProjectOwnerAt datetime (epoch)
   */
  function _setPayToProjectOwnerAt(uint256 _payToProjectOwnerAt) internal virtual {
    require(_payToProjectOwnerAt > block.timestamp, 'bad');
    payToProjectOwnerAt = _payToProjectOwnerAt;
  }

  /**
   * @dev Token refund
   */
  function refund(bytes calldata _refundPayload) external virtual whenNotPaused onlyFactoryOwner {
    require(!isRefunded, 'bad');

    (uint256 totalPaid, RefundDetail[] memory userRefunds) = abi.decode(_refundPayload, (uint256, RefundDetail[]));

    isRefunded = true;

    totalPaidToProject = (totalPaid * (10 ** IERC20MetadataUpgradeable(stable).decimals())) / (10 ** 18);

    uint256 total = totalRefunded;
    for (uint256 i = 0; i < userRefunds.length; ++i) {
      // adjust into stable decimals
      userRefunds[i].stableRefunded =
        (userRefunds[i].stableRefunded * (10 ** IERC20MetadataUpgradeable(stable).decimals())) /
        (10 ** 18);

      require(
        IERC20MetadataUpgradeable(stable).balanceOf(address(this)) >= userRefunds[i].stableRefunded,
        'insufficient'
      );

      // insert into array
      refunds.push(userRefunds[i]);

      // add to totalRefunded
      total += userRefunds[i].stableRefunded;

      // refund stable
      IERC20MetadataUpgradeable(stable).safeTransfer(userRefunds[i].buyer, userRefunds[i].stableRefunded);

      emit UserRefund(userRefunds[i].buyer, userRefunds[i].stableRefunded);
    }

    totalRefunded = total;
  }

  /**
   * @dev Token payment to project owner
   */
  function payToProject() external virtual whenNotPaused {
    require(block.timestamp >= payToProjectOwnerAt && isRefunded && !isPaid, '!claimable');
    require(_msgSender() == projectOwner, '!projectOwner');

    isPaid = true;

    uint256 paidAmount = totalPaidToProject;

    require(IERC20MetadataUpgradeable(stable).balanceOf(address(this)) >= paidAmount, 'insufficient');

    // pay stable
    IERC20MetadataUpgradeable(stable).safeTransfer(projectOwner, paidAmount);

    emit PayToProject(projectOwner, paidAmount, block.timestamp);
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
   * @dev Set stable project
   * @param _stable Token project address
   */
  function setStable(address _stable) external virtual onlyFactoryOwner {
    _setStable(_stable);
  }

  /**
   * @dev Set project owner to receive returned token & stable
   * @param _projectOwner Token project address
   */
  function setProjectOwner(address _projectOwner) external virtual onlyFactoryOwner {
    _setProjectOwner(_projectOwner);
  }

  /**
   * @dev Set datetime project owner could claim its stable
   * @param _payToProjectOwnerAt datetime (epoch)
   */
  function setPayToProjectOwnerAt(uint256 _payToProjectOwnerAt) external virtual onlyFactoryOwner {
    _setPayToProjectOwnerAt(_payToProjectOwnerAt);
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
