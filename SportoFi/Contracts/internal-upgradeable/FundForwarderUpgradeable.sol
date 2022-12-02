// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

import "./TransferableUpgradeable.sol";

import "./interfaces/IFundForwarderUpgradeable.sol";

abstract contract FundForwarderUpgradeable is
    ContextUpgradeable,
    TransferableUpgradeable,
    IFundForwarderUpgradeable
{
    bytes32 private _treasury;

    function __FundForwarder_init(
        ITreasury treasury_
    ) internal onlyInitializing {
        __FundForwarder_init_unchained(treasury_);
    }

    function __FundForwarder_init_unchained(
        ITreasury treasury_
    ) internal onlyInitializing {
        _updateTreasury(treasury_);
    }

    receive() external payable virtual {
        address treasury_;
        assembly {
            treasury_ := sload(_treasury.slot)
        }
        _safeNativeTransfer(treasury_, msg.value);
    }

    function updateTreasury(ITreasury) external virtual override;

    function treasury() public view returns (ITreasury treasury_) {
        assembly {
            treasury_ := sload(_treasury.slot)
        }
    }

    function _updateTreasury(ITreasury treasury_) internal {
        assembly {
            sstore(_treasury.slot, treasury_)
        }
    }

    function recoverERC20(IERC20Upgradeable token_) external virtual {
        _safeERC20Transfer(
            token_,
            address(treasury()),
            token_.balanceOf(address(this))
        );
    }

    function recoverNative() external {
        _safeNativeTransfer(address(treasury()), address(this).balance);
    }

    uint256[49] private __gap;
}