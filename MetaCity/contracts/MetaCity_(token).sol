// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @dev Interface of the DIRO token
 */
interface IDIRO {
    function mint(address account, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

interface IWhitelist {
    function isWhitelist(address sender_) external view returns (bool);
}

contract MetaCity is ERC20, ERC20Snapshot, Ownable, Pausable {
    address public swapPair;
    address public receiptFeeAddress;
    uint256 public sellFeeRate;
    uint256 public buyFeeRate;

    address private _diroToken;
    uint256 private MULTIPLER = 1;

    uint256 private _publicTime;
    IWhitelist private _whitelistChecker;
    mapping(address => uint256) private _whitelistAmount;

    constructor() ERC20("MetaCity Token", "MTC") {
        _mint(_msgSender(), 5 * 10 ** 6 * 10 ** decimals());
    }

    function updateTokenConfig(
        address diroToken_,
        address whitelistChecker_,
        uint256 publicTime_
    ) external onlyOwner {
        _diroToken = diroToken_;
        _whitelistChecker = IWhitelist(whitelistChecker_);
        _publicTime = publicTime_;
    }

    function updateExchangeFee(
        address _swapPair,
        address _receiptFeeAddress,
        uint256 _sellFeeRate,
        uint256 _buyFeeRate
    ) external onlyOwner {
        swapPair = _swapPair;
        receiptFeeAddress = _receiptFeeAddress;
        sellFeeRate = _sellFeeRate;
        buyFeeRate = _buyFeeRate;
    }

    function updateMultiplier(uint256 _multiplier) external onlyOwner {
        MULTIPLER = _multiplier;
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 transferFeeRate = 0;
        bool inWhitelistTime = block.timestamp < _publicTime;

        // Only whitelist can buy with Zero tax before public time
        if (inWhitelistTime) {
            if (_whitelistChecker.isWhitelist(recipient) && _whitelistAmount[recipient] == 0) {
                // Max buy is 2000 token
                require(amount < 2000 * 10 ** decimals(), "Invalid amount");
                transferFeeRate = 0;
            } else {
                // Tax 30% to prevent bot
                transferFeeRate = (recipient == swapPair || sender == swapPair) ? 3000 : 0;
            }
        }

        if (transferFeeRate > 0) {
            uint256 _fee = (amount * transferFeeRate) / 10000;
            super._transfer(sender, receiptFeeAddress, _fee); // TransferFee
            amount = amount - _fee;
        }

        if (recipient == swapPair) {
            uint256 diroAmount = _getRequiredDiroAmount(amount);
            IDIRO(_diroToken).burnFrom(sender, diroAmount);
        }

        if (sender == swapPair) {
            // Buyer will receipt 80% diro
            uint256 diroAmount = (amount * 8) / 10;

            // Whitelist receipt 60% diro and only buy one time
            if (inWhitelistTime) {
                if (_whitelistChecker.isWhitelist(recipient) && _whitelistAmount[recipient] == 0) {
                    diroAmount = (amount * 6) / 10;
                    _whitelistAmount[recipient] = amount;
                }
            }

            IDIRO(_diroToken).mint(recipient, diroAmount);
        }

        super._transfer(sender, recipient, amount);
    }

    function _getRequiredDiroAmount(uint256 tokenAmount) internal view returns (uint256) {
        return tokenAmount * MULTIPLER;
    }
}
