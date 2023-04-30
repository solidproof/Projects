// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./DAORoles.sol";
import { Roles } from "./Roles.sol";

abstract contract HasRole is ContextUpgradeable {
    DAORoles internal _roles;

    function _setRoles(DAORoles roles) internal {
        _roles = roles;
    }

    function setRoles(DAORoles roles) public onlyRole(Roles.OPERATOR_ROLE) {
        _setRoles(roles);
    }

    function getRoles() public view returns (DAORoles) {
        return _roles;
    }

    modifier onlyRole(bytes32 role) {
        address account = _msgSender();
        if (!_roles.hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
        _;
    }
}
