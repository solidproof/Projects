// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./ERC20.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./DividendPayingTokenInterface.sol";
import "./Ownable.sol";
import "./IDex.sol";

contract DividendPayingToken is ERC20, DividendPayingTokenInterface, Ownable {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  // With `magnitude`, we can properly distribute dividends even if the amount of received ether is small.
  // For more discussion about choosing the value of `magnitude`,
  //  see https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
  uint256 constant internal magnitude = 2**128;

  IRouter public router;
  address public rewardToken;

  uint256 internal magnifiedDividendPerShare;

  // About dividendCorrection:
  // If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
  // When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
  //   `dividendOf(_user)` should not be changed,
  //   but the computed value of `dividendPerShare * balanceOf(_user)` is changed.
  // To keep the `dividendOf(_user)` unchanged, we add a correction term:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
  //   where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
  //   `dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
  // So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;

  uint256 public totalDividendsDistributed;

  constructor(string memory _name, string memory _symbol)  ERC20(_name, _symbol) {
      IRouter _router = IRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
      router = _router;
      rewardToken = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  }

    /// @dev Distributes dividends whenever ether is paid to this contract.
    receive() external payable{
        distributeDividends();
    }

     function distributeDividends() public override payable {
      require(totalSupply() > 0);

      if (msg.value > 0) {
        magnifiedDividendPerShare = magnifiedDividendPerShare.add(
          (msg.value).mul(magnitude) / totalSupply()
        );
        emit DividendsDistributed(msg.sender, msg.value);

        totalDividendsDistributed = totalDividendsDistributed.add(msg.value);
      }
    }

    /// @notice Withdraws the ether distributed to the sender.
    /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
    function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
        uint256 _withdrawableDividend = withdrawableDividendOf(user);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
            emit DividendWithdrawn(user, _withdrawableDividend);
            if(rewardToken != router.WETH()){
                (bool success) = swapBnbForCustomToken(user, _withdrawableDividend);
                if(!success) {
                    (bool secondSuccess,) = user.call{value: _withdrawableDividend, gas: 3000}("");
                    if(!secondSuccess) {
                        withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
                        return 0;
                    }
                }
            }
            else{
                (bool success,) = user.call{value: _withdrawableDividend, gas: 3000}("");
                if(!success) {
                    withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
                    return 0;
                }
            }
            return _withdrawableDividend;
        }
        return 0;
    }

    function setRewardToken(address newToken) external onlyOwner{
        rewardToken = newToken;
    }

    function swapBnbForCustomToken(address user, uint256 amt) internal returns (bool) {
          address[] memory path = new address[](2);
          path[0] = router.WETH();
          path[1] = rewardToken;

          try router.swapExactETHForTokens{value: amt}(0, path, user, block.timestamp + 2){
            return true;
        } catch {
            return false;
        }
    }

    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function dividendOf(address _owner) public view override returns(uint256) {
      return withdrawableDividendOf(_owner);
    }

    /// @notice View the amount of dividend in wei that an address can withdraw.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` can withdraw.
    function withdrawableDividendOf(address _owner) public view override returns(uint256) {
      return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
    }

    /// @notice View the amount of dividend in wei that an address has withdrawn.
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has withdrawn.
    function withdrawnDividendOf(address _owner) public view override returns(uint256) {
      return withdrawnDividends[_owner];
    }


    /// @notice View the amount of dividend in wei that an address has earned in total.
    /// @dev accumulativeDividendOf(_owner) = withdrawableDividendOf(_owner) + withdrawnDividendOf(_owner)
    /// = (magnifiedDividendPerShare * balanceOf(_owner) + magnifiedDividendCorrections[_owner]) / magnitude
    /// @param _owner The address of a token holder.
    /// @return The amount of dividend in wei that `_owner` has earned in total.
    function accumulativeDividendOf(address _owner) public view override returns(uint256) {
      return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
        .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
    }

    /// @dev Internal function that transfer tokens from one address to another.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param value The amount to be transferred.
    function _transfer(address from, address to, uint256 value) internal virtual override {
      require(false);

      int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
      magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
      magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
    }

    /// @dev Internal function that mints tokens to an account.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param account The account that will receive the created tokens.
    /// @param value The amount that will be created.
    function _mint(address account, uint256 value) internal override {
      super._mint(account, value);

      magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
    }

    /// @dev Internal function that burns an amount of the token of a given account.
    /// Update magnifiedDividendCorrections to keep dividends unchanged.
    /// @param account The account whose tokens will be burnt.
    /// @param value The amount that will be burnt.
    function _burn(address account, uint256 value) internal override {
      super._burn(account, value);

      magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
        .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
    }

    function _setBalance(address account, uint256 newBalance) internal {
      uint256 currentBalance = balanceOf(account);

      if(newBalance > currentBalance) {
        uint256 mintAmount = newBalance.sub(currentBalance);
        _mint(account, mintAmount);
      } else if(newBalance < currentBalance) {
        uint256 burnAmount = currentBalance.sub(newBalance);
        _burn(account, burnAmount);
      }
    }
  }
