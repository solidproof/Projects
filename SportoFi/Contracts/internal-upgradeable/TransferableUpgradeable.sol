// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

abstract contract TransferableUpgradeable is Initializable {
    function __Transferable_init() internal onlyInitializing {}

    function __Transferable_init_unchained() internal onlyInitializing {}

    function _safeTransferFrom(
        IERC20Upgradeable token_,
        address from_,
        address to_,
        uint256 value_
    ) internal virtual {
        __checkValidTransfer(to_, value_);
        bool success;
        if (address(token_) == address(0))
            success = __nativeTransfer(to_, value_);
        else success = __ERC20TransferFrom(token_, from_, to_, value_);

        require(success, "TRANSFERABLE: TRANSFER_FAILED");
    }

    function _safeTransfer(
        IERC20Upgradeable token_,
        address to_,
        uint256 value_
    ) internal virtual {
        __checkValidTransfer(to_, value_);
        bool success;
        if (address(token_) == address(0))
            success = __nativeTransfer(to_, value_);
        else success = __ERC20Transfer(token_, to_, value_);

        require(success, "TRANSFERABLE: TRANSFER_FAILED");
    }

    function _safeNativeTransfer(
        address to_,
        uint256 amount_
    ) internal virtual {
        __checkValidTransfer(to_, amount_);
        require(
            __nativeTransfer(to_, amount_),
            "TRANSFERABLE: TRANSFER_FAILED"
        );
    }

    function _safeERC20Transfer(
        IERC20Upgradeable token_,
        address to_,
        uint256 amount_
    ) internal virtual {
        __checkValidTransfer(to_, amount_);
        require(
            __ERC20Transfer(token_, to_, amount_),
            "TRANSFERABLE: TRANSFER_FAILED"
        );
    }

    function _safeERC20TransferFrom(
        IERC20Upgradeable token_,
        address from_,
        address to_,
        uint256 amount_
    ) internal virtual {
        __checkValidTransfer(to_, amount_);
        require(
            __ERC20TransferFrom(token_, from_, to_, amount_),
            "TRANSFERABLE: TRANSFER_FAILED"
        );
    }

    function __nativeTransfer(
        address to_,
        uint256 amount_
    ) private returns (bool success) {
        assembly {
            success := call(gas(), to_, amount_, 0, 0, 0, 0)
        }
    }

    function __ERC20Transfer(
        IERC20Upgradeable token_,
        address to_,
        uint256 value_
    ) internal virtual returns (bool success) {
        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), to_) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), value_) // Append the "amount" argument.

            success := and(
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                call(gas(), token_, 0, freeMemoryPointer, 68, 0, 32)
            )
        }
    }

    function __ERC20TransferFrom(
        IERC20Upgradeable token_,
        address from_,
        address to_,
        uint256 value_
    ) internal virtual returns (bool success) {
        assembly {
            let freeMemoryPointer := mload(0x40)

            mstore(
                freeMemoryPointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), from_)
            mstore(add(freeMemoryPointer, 36), to_)
            mstore(add(freeMemoryPointer, 68), value_)

            success := and(
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                call(gas(), token_, 0, freeMemoryPointer, 100, 0, 32)
            )
        }
    }

    function __checkValidTransfer(address to_, uint256 value_) private view {
        require(
            value_ != 0 && to_ != address(0) && to_ != address(this),
            "TRANSFERABLE: INVALID_ARGUMENTS"
        );
    }

    uint256[50] private __gap;
}