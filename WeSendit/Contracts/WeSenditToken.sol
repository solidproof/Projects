// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./BaseWeSenditToken.sol";

/**
 * @title WeSendit ERC20 token
 */
contract WeSenditToken is BaseWeSenditToken, ERC20Capped, ERC20Burnable {
    constructor(address addressTotalSupply)
        ERC20("WeSendit", "WSI")
        ERC20Capped(TOTAL_SUPPLY)
        BaseWeSenditToken()
    {
        _mint(addressTotalSupply, TOTAL_SUPPLY);
    }

    /**
     * Transfer token from without fee reflection
     *
     * @param from address - Address to transfer token from
     * @param to address - Address to transfer token to
     * @param amount uint256 - Amount of token to transfer
     *
     * @return bool - Indicator if transfer was successful
     */
    function transferFromNoFees(
        address from,
        address to,
        uint256 amount
    ) external virtual override returns (bool) {
        require(
            _msgSender() == address(dynamicFeeManager()),
            "WeSendit: Can only be called by Dynamic Fee Manager"
        );

        return super.transferFrom(from, to, amount);
    }

    /**
     * Transfer token with fee reflection
     *
     * @inheritdoc ERC20
     */
    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        // Reflect fees
        (uint256 tTotal, ) = _reflectFees(_msgSender(), to, amount);

        // Execute normal transfer
        return super.transfer(to, tTotal);
    }

    /**
     * Transfer token from with fee reflection
     *
     * @inheritdoc ERC20
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        // Reflect fees
        (uint256 tTotal, ) = _reflectFees(from, to, amount);

        // Execute normal transfer
        return super.transferFrom(from, to, tTotal);
    }

    /**
     * @inheritdoc ERC20
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        _preValidateTransfer(from);
    }

    // Needed since we inherit from ERC20 and ERC20Capped
    function _mint(address account, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(account, amount);
    }

    /**
     * Reflects fees using the dynamic fee manager
     *
     * @param from address - Sender address
     * @param to address - Receiver address
     * @param amount uint256 - Transaction amount
     */
    function _reflectFees(
        address from,
        address to,
        uint256 amount
    ) private returns (uint256 tTotal, uint256 tFees) {
        if (address(dynamicFeeManager()) == address(0)) {
            return (amount, 0);
        } else {
            // Allow dynamic fee manager to spent amount for fees if needed
            _approve(from, address(dynamicFeeManager()), amount);

            // Reflect fees
            (tTotal, tFees) = dynamicFeeManager().reflectFees(from, to, amount);

            // Reset fee manager approval to zero for security reason
            _approve(from, address(dynamicFeeManager()), 0);

            return (tTotal, tFees);
        }
    }

    /**
     * Checks if the minimum transaction amount is exceeded and if pause is enabled
     *
     * @param from address - Sender address
     */
    function _preValidateTransfer(address from) private view {
        /**
         * Only allow transfers if:
         * - token is not paused
         * - sender is owner
         * - sender is admin
         * - sender has bypass role
         */
        require(
            !paused() ||
                from == address(0) ||
                from == owner() ||
                hasRole(ADMIN, from) ||
                hasRole(BYPASS_PAUSE, from),
            "WeSendit: transactions are paused"
        );
    }
}
