// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./aCO2Token.sol";

contract StakingPool is Initializable, UUPSUpgradeable, AccessControlUpgradeable, IERC1155Receiver {
    aCO2Token public aco2Token;

    struct Package {
        uint256[] aco2_ids;
        uint256[] aco2_amounts;
        uint256 internal_pointer;
    }

    mapping(uint256 => Package) public packages;

    uint256 public packagePointer;
    uint256 public totalaCO2;
    uint256 public totalPackages;
    uint256 public MAX_TOKEN_IDS_PER_TX;
    uint256 public oldestNonEmptyPackage;

    bytes32 public constant STAKING_CONTRACT_ROLE = keccak256("STAKING_CONTRACT_ROLE");

    event ClaimedTokens(address recipient, uint256 aco2Id, uint256 transferAmount, uint256 remainingInPackage, uint256 totalTransferredAmount);
    event PartialClaimed(address recipient, uint256 requestedAmount, uint256 transferredAmount);

    function initialize(address _aco2TokenAddress) public initializer {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(STAKING_CONTRACT_ROLE, msg.sender);
        __UUPSUpgradeable_init();
        aco2Token = aCO2Token(_aco2TokenAddress);
        oldestNonEmptyPackage = 0;  // Initialize pointer to the first package
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function setaCO2TokenAddress(address _aco2TokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        aco2Token = aCO2Token(_aco2TokenAddress);
    }

    function setMaxaCO2TokenIds(uint256 _maxTokenIds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        MAX_TOKEN_IDS_PER_TX = _maxTokenIds;
    }

    function grantStakingContractRole(address _address) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(STAKING_CONTRACT_ROLE, _address);
    }

    function revokeStakingContractRole(address _address) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(STAKING_CONTRACT_ROLE, _address);
    }

    function addPackage(Package memory package, uint256 totalAco2Added) public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Ensure that the package's internal pointer is 0
        require(package.internal_pointer == 0, "Internal pointer must be 0");

        // Ensure that the aCO2 ID array and amounts array have the same length
        require(package.aco2_ids.length == package.aco2_amounts.length, "aCO2 IDs and amounts array lengths must match");

        // Ensure that the aCO2 arrays are not empty
        require(package.aco2_ids.length > 0, "aCO2 IDs array cannot be empty");
        require(package.aco2_amounts.length > 0, "aCO2 amounts array cannot be empty");

        // Amounts can't be zero
        for (uint256 i = 0; i < package.aco2_amounts.length; i++) {
            require(package.aco2_amounts[i] > 0, "aCO2 amounts must be greater than 0");
        }

        // Check balances for all aCO2 token IDs in one go
        for (uint256 i = 0; i < package.aco2_ids.length; i++) {
            require(aco2Token.balanceOf(msg.sender, package.aco2_ids[i]) >= package.aco2_amounts[i], "Insufficient aCO2 balance");
        }

        // Use safeBatchTransferFrom to transfer all tokens in a single transaction
        aco2Token.safeBatchTransferFrom(
            msg.sender,
            address(this),
            package.aco2_ids,
            package.aco2_amounts,
            ""
        );

        // Store the package in the mapping
        packages[packagePointer] = package;

        // Update total aCO2 added to the contract
        totalaCO2 += totalAco2Added;

        // Increment package pointer and total packages
        packagePointer++;
        totalPackages++;
    }

    function claimStakingaCO2(address recipient, uint256 amount) public onlyRole(STAKING_CONTRACT_ROLE) {
        uint256 transferred_amount = 0;
        uint256 tokenIdsProcessed = 0;
        uint256 amountToClaim = (amount > totalaCO2) ? totalaCO2 : amount;

        uint256 currentPackageIndex = oldestNonEmptyPackage;  // Start from the oldest non-empty package
        uint256 newOldestNonEmptyPackage = currentPackageIndex;

        while (transferred_amount < amountToClaim && currentPackageIndex < totalPackages && tokenIdsProcessed < MAX_TOKEN_IDS_PER_TX) {
            Package storage currentPackage = packages[currentPackageIndex];

            while (currentPackage.internal_pointer < currentPackage.aco2_ids.length && transferred_amount < amountToClaim) {
                uint256 aco2_id = currentPackage.aco2_ids[currentPackage.internal_pointer];
                uint256 aco2_amount = currentPackage.aco2_amounts[currentPackage.internal_pointer];

                uint256 contractBalance = aco2Token.balanceOf(address(this), aco2_id);
                uint256 availableAmount = aco2_amount > contractBalance ? contractBalance : aco2_amount;

                if (availableAmount == 0) {
                    currentPackage.internal_pointer++;
                    continue;
                }

                uint256 transferAmount = (amountToClaim - transferred_amount > availableAmount) 
                    ? availableAmount 
                    : amountToClaim - transferred_amount;

                aco2Token.safeTransferFrom(address(this), recipient, aco2_id, transferAmount, "");
                transferred_amount += transferAmount;
                currentPackage.aco2_amounts[currentPackage.internal_pointer] -= transferAmount;

                emit ClaimedTokens(recipient, aco2_id, transferAmount, currentPackage.aco2_amounts[currentPackage.internal_pointer], transferred_amount);

                if (currentPackage.aco2_amounts[currentPackage.internal_pointer] == 0) {
                    currentPackage.internal_pointer++;
                    tokenIdsProcessed++;
                }

                if (tokenIdsProcessed >= MAX_TOKEN_IDS_PER_TX) {
                    break;
                }
            }

            if (currentPackage.internal_pointer >= currentPackage.aco2_ids.length) {
                newOldestNonEmptyPackage = currentPackageIndex + 1;
            }

            currentPackageIndex++;
        }

        // Update outside the loop
        oldestNonEmptyPackage = newOldestNonEmptyPackage;

        if (transferred_amount > 0) {
            totalaCO2 -= transferred_amount;  // Decrement total after calculating
        }

        if (transferred_amount < amount) {
            emit PartialClaimed(recipient, amount, transferred_amount);
        }
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function getaCO2Balance() public view returns (uint256) {
        uint256 totalBalance = 0;
        uint256 tokenIdsProcessed = 0;
        uint256 currentPackageIndex = oldestNonEmptyPackage;  // Start from the oldest non-empty package

        while (tokenIdsProcessed < MAX_TOKEN_IDS_PER_TX && currentPackageIndex < totalPackages) {
            Package storage currentPackage = packages[currentPackageIndex];

            uint256 internalPointer = currentPackage.internal_pointer;

            while (internalPointer < currentPackage.aco2_ids.length && tokenIdsProcessed < MAX_TOKEN_IDS_PER_TX) {
                uint256 aco2_id = currentPackage.aco2_ids[internalPointer];
                uint256 aco2_amount = currentPackage.aco2_amounts[internalPointer];

                uint256 contractBalance = aco2Token.balanceOf(address(this), aco2_id);
                uint256 availableAmount = aco2_amount > contractBalance ? contractBalance : aco2_amount;

                if (availableAmount == 0) {
                    internalPointer++;
                    continue;
                }

                totalBalance += availableAmount;
                tokenIdsProcessed++;
                internalPointer++;
            }

            if (internalPointer >= currentPackage.aco2_ids.length) {
                currentPackageIndex++;
            }
        }

        return totalBalance;
    }

    // Function to get package details by ID
    function getPackage(uint256 packageId) public view returns (uint256[] memory, uint256[] memory, uint256) {
        require(packageId < packagePointer, "Package does not exist");
        Package storage package = packages[packageId];
        return (package.aco2_ids, package.aco2_amounts, package.internal_pointer);
    }

    // Adjust the internal pointer of a package
    function adjustPackagePointer(uint256 packageId, uint256 newPointer) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(packageId < packagePointer, "Package does not exist");
        packages[packageId].internal_pointer = newPointer;
    }
}
