// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./BaseVault.sol";
import "hardhat/console.sol";

contract SideVault is BaseVault {

    /**
     * @dev Events
     */
    event WormHoleReceive(uint16 chainId, address relayer, address vault, bytes payload);

    function initialize(
        string memory _name, 
        string memory _symbol,
        address _saleToken,
        address _mainVault,
        address _wormholeRelayer,
        uint16 _wormholeChainId,
        address _signer,
        address[] memory kyc
    ) initializer public {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __ReentrancyGuard_init();

        require(
            _saleToken != address(0) && 
            _mainVault != address(0) && 
            _signer != address(0), 
            "Zero address not allowed"
        );

        SALE_TOKEN = IERC20(_saleToken);
        MAIN_VAULT = _mainVault;
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        VAULT_CHAIN_ID = _wormholeChainId;
        signer = _signer;

        status = Status.NOT_INITIALIZED;
        depositGasLimit = 500_000;

        KYC_50K = kyc[0];
        KYC_UNLIMITED = kyc[1];
    }

    /**
     * @dev vault initialization
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");
        require(MAIN_CHAIN_ID == sourceChain, "Invalid source chain");
        require(
            MAIN_VAULT == fromWormholeFormat(sourceAddress), 
            "Unauthorized"
        );

        (
            uint256 _mode,
            address[] memory _addresses,
            uint256[] memory _amounts
        ) = abi.decode(
            payload, 
            (
                uint256,
                address[],
                uint256[]
            )
        );

        if (_mode == 0) {
            // InitVault
            require(status == Status.NOT_INITIALIZED, "vault already initialized");

            PLATFORM = _addresses[0];
            BENEFICIARY = _addresses[1];

            MIN_COLLECTED = _amounts[0];
            MAX_COLLECTED = _amounts[1];
            SALE_START = _amounts[2];
            SALE_END = _amounts[3];
            INVESTOR_FEE = _amounts[4];
            BENEFICIARY_FEE = _amounts[5];

            status = Status.SALE;

        } else if (_mode == 1) {
            // FinalizeSale
            if (_amounts[0] > totalShares) {
                // Failsafe in case something didn't propagete back to moonbeam in time and sidechain has more shares than mainchain
                totalShares = _amounts[0];
            }

            // Will get reverted if sale already finalized
            _finalizeSale();

        } else if (_mode == 2) {
            // Max collected sync
            if (_amounts[0] > totalShares) {
                // Failsafe in case something didn't propagete back to moonbeam in time and sidechain has more shares than mainchain
                totalShares = _amounts[0];
            }
            beneficiaryActionUnlock = _amounts[1];
        }

        emit WormHoleReceive(sourceChain, msg.sender, fromWormholeFormat(sourceAddress), payload);
    }
}