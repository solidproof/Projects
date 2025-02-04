// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./LaunchPadData.sol";
import "./LaunchPadSales.sol";
import "./LaunchPadVesting.sol";
import "./interfaces/IStakingRewards.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title LaunchPad
 * @dev Main contract for the LaunchPad, integrating vesting and sales functionalities.
 */
contract LaunchPad is
    Initializable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    LaunchPadVesting,
    LaunchPadSales
{
    using ECDSAUpgradeable for bytes32;

    /**
     * @dev Initializes the LaunchPad contract.
     * @param _fee The platform fee percentage.
     * @param _stakingContract The address of the staking contract.
     */
    function initialize(
        uint256 _fee,
        address _stakingContract,
        address _signer
    ) public initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_fee >= 0 && _fee <= 25, "Invalid fee");
        require(_signer != address(0), "Invalid signer");

        fee = _fee;
        stakingContract = _stakingContract;
        chainId = block.chainid;
        signer = _signer;
    }

    /**
     * @dev Authorizes the contract upgrade.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
