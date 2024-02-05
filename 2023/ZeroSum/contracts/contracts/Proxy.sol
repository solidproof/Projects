// SPDX-License-Identifier: Unlicensed
// ZeroSum Contract

pragma solidity 0.8.7;
import {Adminable} from "./Adminable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";
import {Initializable} from "./utils/Initializable.sol";


contract Proxy is Adminable, Initializable {

    constructor(address _logic, bytes memory _data) payable {
        _transferOwnership(msg.sender);
        _upgradeToAndCall(_logic, _data, false);
    }
// ++++++++++ Implementation ++++++++++
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    function getImplementation() public view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    function upgradeTo(address newImplementation) external onlyAdminHierarchy(AdminRole.Developer) upgraded {
        _upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) external upgraded onlyAdminHierarchy(AdminRole.Developer) {
        _upgradeToAndCall(newImplementation, data, forceCall);
    }

    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    function _upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
// ++++++++++ Delegating ++++++++++
    function _delegate(address implementation) internal virtual {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    fallback() external payable {
        _delegate(getImplementation());
    }

    receive() external payable {
        _delegate(getImplementation());
    }
// ++++++++++ Events ++++++++++
    event Upgraded(address indexed implementation);
}