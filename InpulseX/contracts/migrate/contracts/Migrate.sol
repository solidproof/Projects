// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Migrate is Context, Ownable {
    IERC20 private _token;
    address private _sender;
    mapping(address => bool) private _adminAddrs;

    constructor() {}

    /**
     * @dev Set `addr` admin state to `state`.
     */
    function setIsAdmin(address addr, bool state) external onlyOwner {
        _adminAddrs[addr] = state;
    }

    /**
     * @dev Check if `addr` is is an admin.
     */
    function getIsAdmin(address addr) public view returns (bool) {
        return _adminAddrs[addr];
    }

    /**
     * @dev Throws if called by any account other than the admins.
     */
    modifier onlyAdmins() {
        require(getIsAdmin(_msgSender()), "Caller is not an admin");
        _;
    }

    /**
     * @dev Sets the airdrop token address.
     */
    function setToken(address token) external onlyOwner {
        _token = IERC20(token);
    }

    /**
     * @dev Sets the airdrop token holder address. All tokens
     * will be sent from this address.
     */
    function setSender(address sender) external onlyOwner {
        _sender = sender;
    }

    /**
     * @dev Airdrop `amount` to `recipient`. Can be called by
     * admins only.
     */
    function airdrop(address recipient, uint256 amount) public onlyAdmins {
        // We don't want to airdrop twice by mistake
        if (_token.balanceOf(recipient) == 0) {
            require(_token.transferFrom(_sender, recipient, amount));
        }
    }

    /**
     * @dev Airdrop `amounts` to `recipients`. Can be called by
     * admins only.
     */
    function bulkAirdrop(address[] memory recipients, uint256[] memory amounts)
        external
        onlyAdmins
    {
        require(
            recipients.length == amounts.length,
            "Recipients and amounts arrays don't have the same size"
        );
        for (uint256 index = 0; index < recipients.length; index++) {
            airdrop(recipients[index], amounts[index]);
        }
    }
}
