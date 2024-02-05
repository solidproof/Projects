// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./BaseVault.sol";

// import "hardhat/console.sol";

contract MainVault is BaseVault {

    /**
     * @dev side-chain vault contract, linked to mainVault through wormhole
     */
    mapping(uint16 => address) public sideVault;

    /**
     * @dev list of supported side-chains
     */
    uint16[] public sideChainList;

    /**
     * @dev Events
     */
    event SideDeposit(uint16 chainId, address relayer, address vault);

    function initialize(
        string memory _name, 
        string memory _symbol,
        address _saleToken,
        uint256[] memory params,
        address _platform,
        address _beneficiary,
        address _wormholeRelayer,
        address _signer,
        address[] memory kyc
    ) initializer public {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __ReentrancyGuard_init();

        require(
            _saleToken != address(0) && 
            _platform != address(0) &&
            _beneficiary != address(0) &&
            _signer != address(0), 
            "Zero address not allowed"
        );

        SALE_TOKEN = IERC20(_saleToken);

        MIN_COLLECTED = params[0];
        MAX_COLLECTED = params[1];
        SALE_START = params[2];
        SALE_END = params[3];
        INVESTOR_FEE = params[4];
        BENEFICIARY_FEE = params[5];

        require(
            SALE_START > 0 && SALE_START < SALE_END, 
            "SALE_START has to be: 0 < SALE_START < SALE_END"
        );

        require(
            INVESTOR_FEE + BENEFICIARY_FEE <= FEE_MAX_SETTABLE, 
            "INVESTOR_FEE + BENEFICIARY_FEE too high"
        );

        PLATFORM = _platform;
        BENEFICIARY = _beneficiary;

        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
        VAULT_CHAIN_ID = MAIN_CHAIN_ID;

        signer = _signer;

        KYC_50K = kyc[0];
        KYC_UNLIMITED = kyc[1];
    }  

    /**
     * @dev Set sideVault address for each chain
     * @param chainId wormhole chain id, NOT EVM!
     * @param sidechainVault sidechain vault address
     * @param gasLimit gas limit to be used in dest chain
     */
    function setSideVault(
        uint16 chainId, 
        address sidechainVault,
        uint256 gasLimit
    ) external payable onlyOwner {
        if (sideVault[chainId] == address(0)) {
            sideChainList.push(chainId);
        }
        sideVault[chainId] = sidechainVault;
        uint256 cost = quoteCrossChainInit(chainId, gasLimit);
        require(
            msg.value == getInitSideVaultCost(chainId, gasLimit), 
            "invalid msg.value"
        ); // expected amount should be 2x cost + 10%

        address[] memory _addresses = new address[](2);
        _addresses[0] = PLATFORM;
        _addresses[1] = BENEFICIARY;

        uint256[] memory _data = new uint256[](6);
        _data[0] = MIN_COLLECTED;
        _data[1] = MAX_COLLECTED;
        _data[2] = SALE_START;
        _data[3] = SALE_END;
        _data[4] = INVESTOR_FEE;
        _data[5] = BENEFICIARY_FEE;

        _wormholeSend(
            chainId,
            abi.encode(
                0, // mode - initVault
                _addresses,
                _data
            ), // payload
            gasLimit,
            cost
        );
    }

    /**
     * @dev Deposit USDC to get LAT tokens
     * @param amount amount of USDC tokens
     * @param user receiver of lat tokens
     * @param fee platform fee to be collected (if MIN_COLLECTED reached)
     */
    function depositEx(
        uint256 amount, 
        address user, 
        uint256 fee, 
        uint256 expiresAt,
        bytes memory signature
    ) internal override {
        super.depositEx(amount, user, fee, expiresAt, signature);

        if (totalShares >= MAX_COLLECTED) {
            _notifySidechainMaxReached();
        }
    }

    /**
     * @dev Sidechain deposit
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override nonReentrant {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");
        address _sideVault = fromWormholeFormat(sourceAddress);
        require(
            sideVault[sourceChain] == _sideVault, 
            "Unauthorized"
        );

        uint256 amount = abi.decode(payload, (uint256));
        totalShares += amount;

        emit SideDeposit(sourceChain, msg.sender, fromWormholeFormat(sourceAddress));

        if (totalShares >= MAX_COLLECTED) {
            _notifySidechainMaxReached();
        }
    }

    /**
     * @dev Finalize sale after end timestamp is reached
     */
    function finalizeSale() external payable {
        _finalizeSale();

        uint16 chainId;
        uint256 totalCost;
        uint256 gasLimit = 500_000;
        for (uint256 i = 0; i < sideChainList.length; i++) {
            chainId = sideChainList[i];
            uint256 cost = quoteCrossChainInit(chainId, gasLimit);
            totalCost += cost;
            
            address[] memory _addresses = new address[](0);
            uint256[] memory _data = new uint256[](1);
            _data[0] = totalShares;

            _wormholeSend(
                chainId,
                abi.encode(
                    1, // mode - finalizeSale
                    _addresses,
                    _data
                ), // payload
                gasLimit,
                cost
            );
        }

        require(msg.value == totalCost, "msg.value != totalCost");
    }

    /**
     * @dev Notify all sidechains when hardcap is reached on mainchain.
     * Funds for wormhole fee are already deposited when setSideVault is called.
     */
    function _notifySidechainMaxReached() private {
        beneficiaryActionUnlock = block.timestamp + 86_400;

        if (address(this).balance > 0) {

            uint16 chainId;
            uint256 gasLimit = 500_000;
            uint256 totalCost;
            uint256 cost;
            for (uint256 i = 0; i < sideChainList.length; i++) {
                chainId = sideChainList[i];
                cost = quoteCrossChainInit(chainId, gasLimit);
                totalCost += cost;
            }

            if (address(this).balance >= totalCost) {
                address[] memory _addresses = new address[](0);
                uint256[] memory _data = new uint256[](2);
                _data[0] = totalShares;
                _data[1] = beneficiaryActionUnlock;

                for (uint256 i = 0; i < sideChainList.length; i++) {
                    chainId = sideChainList[i];
                    cost = quoteCrossChainInit(chainId, gasLimit);
                    _wormholeSend(
                        chainId,
                        abi.encode(
                            2, // mode - max collected sync
                            _addresses,
                            _data
                        ), // payload
                        gasLimit,
                        cost
                    );
                }

                // return remaining funds to owner
                (bool os, ) = payable(owner()).call{value: address(this).balance}("");
            }
        }
    }

    /**
     * @dev Send crosschain msg using wormhole
     */
    function _wormholeSend(
        uint16 chainId,
        bytes memory payload,
        uint256 gasLimit,
        uint256 cost
    ) private {
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            chainId,
            sideVault[chainId],
            payload, // payload
            0, // no receiver value needed since we're just passing a message
            gasLimit,
            16, // refundChainId -> 16 = Moonbeam
            msg.sender // refundAddress
        ); 
    }

    /**
     * @dev Get cost for initialization of sidechain vault
     * @param _chainId wormhole chain id
     * @param _gasLimit gas limit for destination transaction
     */
    function getInitSideVaultCost(uint16 _chainId, uint256 _gasLimit) public view returns (uint256) {
        return quoteCrossChainInit(_chainId, _gasLimit) * 2 * 11 / 10; // expected amount should be 2x cost + 10%
    }
}