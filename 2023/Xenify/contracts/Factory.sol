// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

/*
 * @title Factory Contract
 *
 * @notice This contract facilitates the deployment of the entire Xenify protocol.
 *
 * Co-Founders:
 * - Simran Dhillon: simran@xenify.io
 * - Hardev Dhillon: hardev@xenify.io
 * - Dayana Plaz: dayana@xenify.io
 *
 * Official Links:
 * - Twitter: https://twitter.com/xenify_io
 * - Telegram: https://t.me/xenify_io
 * - Website: https://xenify.io
 *
 * Disclaimer:
 * This contract aligns with the principles of the Fair Crypto Foundation, promoting self-custody, transparency, consensus-based
 * trust, and permissionless value exchange. There are no administrative access keys, underscoring our commitment to decentralization.
 * Engaging with this contract involves technical and legal risks. Users must conduct their own due diligence and ensure compliance
 * with local laws and regulations. The software is provided "AS-IS," without warranties, and the co-founders and developers disclaim
 * all liability for any vulnerabilities, exploits, errors, or breaches that may occur. By using this contract, users accept all associated
 * risks and this disclaimer. The co-founders, developers, or related parties will not bear liability for any consequences of non-compliance.
 *
 * Redistribution and Use:
 * Redistribution, modification, or repurposing of this contract, in whole or in part, is strictly prohibited without express written
 * approval from all co-founders. Approval requests must be sent to the official email addresses of the co-founders, ensuring responses
 * are received directly from these addresses. Proposals for redistribution, modification, or repurposing must include a detailed explanation
 * of the intended changes or uses and the reasons behind them. The co-founders reserve the right to request additional information or
 * clarification as necessary. Approval is at the sole discretion of the co-founders and may be subject to conditions to uphold the
 * project’s integrity and the values of the Fair Crypto Foundation. Failure to obtain express written approval prior to any redistribution,
 * modification, or repurposing will result in a breach of these terms and immediate legal action.
 *
 * Copyright and License:
 * Copyright © 2023 Xenify (Simran Dhillon, Hardev Dhillon, Dayana Plaz). All rights reserved.
 * This software is primarily licensed under the Business Source License 1.1 (BUSL-1.1).
 * Please refer to the BUSL-1.1 documentation for complete license details.
 */
contract Factory {

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Address of the YSL token contract.
     */
    address public YSL;

    /**
     * @notice Address of the XNF token contract.
     */
    address public XNF;

    /**
     * @notice Address of the vXEN token contract.
     */
    address public vXEN;

    /**
     * @notice Address of the veXNF contract.
     */
    address public veXNF;

    /**
     * @notice Address of the Auction contract.
     */
    address public auction;

    /**
     * @notice Address of the Recycle contract.
     */
    address public recycle;

    /**
     * @notice Address of the deployer.
     */
    address public deployer;

    /**
     * @notice Address of the YSLFactory.
     */
    address public immutable YSLFactory;

    /**
     * @notice Address of the XNFFactory.
     */
    address public immutable XNFFactory;

    /**
     * @notice Address of the vXENFactory.
     */
    address public immutable vXENFactory;

    /**
     * @notice Address of the veXNFFactory.
     */
    address public immutable veXNFFactory;

    /**
     * @notice Address of the AuctionFactory.
     */
    address public immutable AuctionFactory;

    /**
     * @notice Address of the RecycleFactory.
     */
    address public immutable RecycleFactory;

    /// -------------------------------------- ERRORS --------------------------------------- \\\

    /**
     * @notice This error is raised when the function caller is not the deployer.
     */
    error NotTheDeployer();

    /**
     * @notice This error is raised when the YSL contract deployment fails.
     */
    error YSLDeploymentFailed();

    /**
     * @notice This error is raised when the XNF contract deployment fails.
     */
    error XNFDeploymentFailed();

    /**
     * @notice This error is raised when the vXEN contract deployment fails.
     */
    error vXENDeploymentFailed();

    /**
     * @notice This error is raised when the veXNF contract deployment fails.
     */
    error veXNFDeploymentFailed();

    /**
     * @notice This error is raised when the XNF contract initialization fails.
     */
    error XNFInitializationFailed();

    /**
     * @notice This error is raised when the Auction contract deployment fails.
     */
    error AuctionDeploymentFailed();

    /**
     * @notice This error is raised when the Recycle contract deployment fails.
     */
    error RecycleDeploymentFailed();

    /**
     * @notice This error is raised when the veXNF contract initialization fails.
     */
    error veXNFInitializationFailed();

    /**
     * @notice This error is raised when the Auction contract initialization fails.
     */
    error AuctionInitializationFailed();

    /**
     * @notice This error is raised when the Recycle contract initialization fails.
     */
    error RecycleInitializationFailed();

    /**
     * @notice This error is raised when the YSL and vXEN contracts have not been deployed yet.
     */
    error YSLAndvXENDeploymentPending();

    /// ------------------------------------ CONSTRUCTOR ------------------------------------ \\\

    /**
     * @notice Initialises the contract setting deployer as the initial owner.
     * @param _deployer Address of the deployer.
     * @param _AuctionFactory Address of the AuctionFactory.
     * @param _RecycleFactory Address of the RecycleFactory.
     * @param _XNFFactory Address of the XNFFactory.
     * @param _veXNFFactory Address of the veXNFFactory.
     * @param _YSLFactory Address of the YSLFactory.
     * @param _vXENFactory Address of the vXENFactory.
     */
    constructor(
        address _deployer,
        address _AuctionFactory,
        address _RecycleFactory,
        address _XNFFactory,
        address _veXNFFactory,
        address _YSLFactory,
        address _vXENFactory
    ) payable {
        deployer = _deployer;
        AuctionFactory = _AuctionFactory;
        RecycleFactory = _RecycleFactory;
        XNFFactory = _XNFFactory;
        YSLFactory = _YSLFactory;
        vXENFactory = _vXENFactory;
        veXNFFactory = _veXNFFactory;
    }

    /// ------------------------------- EXTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Initiates the deployment of all Xenify Protocol contracts.
     * @dev This function deploys the Auction, Recycle, XNF, and veXNF contracts and initialises them.
     * It requires that YSL and vXEN contracts have been previously deployed on this chain. Only the
     * `deployer` is allowed to call this function.
     * @param payload A calldata byte stream containing the necessary parameters for initializing the Xenify Protocol.
     * @param _gateway Address of the gateway contract for the Xenify Protocol.
     * @param _gasService Address of the gas service contract or provider.
     * @param _endpoint Address for the Xenify Protocol endpoint or service.
     * @param _wormholeRelayer Address of the wormhole relayer contract for cross-chain operations.
     */
    function deployXenifyProtocol(
        bytes calldata payload,
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    )
        external
        payable
    {
        if (msg.sender != deployer) {
            revert NotTheDeployer();
        }
        if (address(YSL) == address(0)) {
            revert YSLAndvXENDeploymentPending();
        }
        _deployAuction();
        _deployRecycle();
        _deployXNF(_gateway, _gasService, _endpoint, _wormholeRelayer);
        _deployveXNF();
        _initialiseAuction(payload);
        _initialiseRecycle(payload);
        _initialiseXNF(payload);
        _initialiseVeXNF();
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initiates the deployment of both YSL & vXEN contracts.
     * @dev This function deploys YSL using a MerkleRoot for an airdrop and vXEN using a specific ratio.
     * It uses delegate calls to both YSLFactory and vXENFactory contracts for deployment.
     * Only the `deployer` is allowed to invoke this function.
     * @param merkleRootYSL Merkle root used for the YSL airdrop distribution.
     * @param ratio The conversion ratio between the current chain's XEN and Ethereum's XEN price.
     * @param _XEN The address of the underlying XEN token for the current chain.
     * @param _gateway The address of the Axelar gateway contract.
     * @param _gasService The address of the Axelar gasService contract or provider.
     * @param _endpoint The designated address for the LayerZero endpoint or service.
     * @param _wormholeRelayer The address of the Wormhole Relayer for cross-chain operations.
     */
    function deployYSLAndvXEN(
        bytes32 merkleRootYSL,
        uint256 ratio,
        address _XEN,
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    )
        external
        payable
    {
        if (msg.sender != deployer) {
            revert NotTheDeployer();
        }
        (bool success, bytes memory data) = YSLFactory.delegatecall(
            abi.encodeWithSignature(
                "deployYSL(bytes32,address,address,address,address)",
                merkleRootYSL,
                _gateway,
                _gasService,
                _endpoint,
                _wormholeRelayer
            )
        );
        if (!success) {
            revert YSLDeploymentFailed();
        }
        YSL = abi.decode(data, (address));
        (success, data) = vXENFactory.delegatecall(
            abi.encodeWithSignature(
                "deployvXEN(uint256,address,address,address,address,address)",
                ratio,
                _XEN,
                _gateway,
                _gasService,
                _endpoint,
                _wormholeRelayer
            )
        );
        if (!success) {
            revert vXENDeploymentFailed();
        }
        vXEN = abi.decode(data, (address));
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Deploys the Auction contract.
     * @dev Utilises a delegate call to create an instance of the Auction contract within the current factory's context.
     * This approach ensures that the Xenify Protocol contracts have consistent addresses across different chains.
     * If the deployment encounters any issues, it will throw an `AuctionDeploymentFailed` exception.
     */
    function _deployAuction() internal {
        (bool success, bytes memory data) = AuctionFactory.delegatecall(
            abi.encodeWithSignature("deployAuction()")
        );
        if (!success) {
            revert AuctionDeploymentFailed();
        }
        auction = abi.decode(data, (address));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Deploys the Recycle contract.
     * @dev Initiates a delegate call to the RecycleFactory to deploy the Recycle contract within the context of the current factory.
     * The primary motivation is to maintain a consistent address for the Xenify Protocol contracts across different blockchains.
     * Throws an error if deployment fails.
     */
    function _deployRecycle() internal {
        (bool success, bytes memory data) = RecycleFactory.delegatecall(
            abi.encodeWithSignature("deployRecycle()")
        );
        if (!success) {
            revert RecycleDeploymentFailed();
        }
        recycle = abi.decode(data, (address));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Deploys the XNF contract.
     * @dev Initiates a delegate call to the XNFFactory to deploy the XNF contract within the current factory's context.
     * This strategy ensures the Xenify Protocol contracts have the same address on all chains. Additional configuration
     * parameters like Axelar gateway, gasService, etc. are passed to aid the deployment. If the deployment is unsuccessful,
     * an exception is thrown.
     * @param _gateway Address of the Axelar gateway used for cross-chain communication.
     * @param _gasService Address of the Axelar gasService that assists with transaction gas calculations.
     * @param _endpoint Address of the LayerZero endpoint.
     * @param _wormholeRelayer Address of the Wormhole Relayer facilitating cross-chain asset transfers.
     */
    function _deployXNF(
        address _gateway,
        address _gasService,
        address _endpoint,
        address _wormholeRelayer
    ) internal {
        (bool success, bytes memory data) = XNFFactory.delegatecall(
            abi.encodeWithSignature(
                "deployXNF(address,address,address,address)",
                _gateway,
                _gasService,
                _endpoint,
                _wormholeRelayer
            )
        );
        if (!success) {
            revert XNFDeploymentFailed();
        }
        XNF = abi.decode(data, (address));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Deploys the veXNF contract.
     * @dev Initiates a delegate call to the veXNFFactory for deploying the veXNF contract within the current factory's context.
     * This uniform approach ensures that Xenify Protocol contracts maintain the same address across multiple blockchains.
     * In case the deployment is unsuccessful, it throws an error.
     */
    function _deployveXNF() internal {
        (bool success, bytes memory data) = veXNFFactory.delegatecall(
            abi.encodeWithSignature("deployveXNF()")
        );
        if (!success) {
            revert veXNFDeploymentFailed();
        }
        veXNF = abi.decode(data, (address));
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initialises the Auction contract.
     * @dev Extracts necessary parameters from the provided payload and passes them to the Auction contract's
     * initialise function. Throws an exception if initialization fails.
     * @param payload Encoded data comprising Xenify Protocol parameters.
     */
    function _initialiseAuction(
        bytes calldata payload
    ) internal {
        (
            , address registrar1,
              address registrar2,
            , uint256 YSLPerBatch,
              uint256 vXENPerBatch,
              uint256 feePerBatch,
            , address nonfungiblePositionManager
        ) = abi.decode(payload, (
                                    bytes32,
                                    address,
                                    address,
                                    address,
                                    uint256,
                                    uint256,
                                    uint256,
                                    address,
                                    address
                                )
        );
        (bool success, ) = auction.call(
            abi.encodeWithSignature(
                "initialise(address,address,address,address,address,address,address,uint256,uint256,uint256,address)",
                recycle,
                XNF,
                veXNF,
                vXEN,
                YSL,
                registrar1,
                registrar2,
                YSLPerBatch,
                vXENPerBatch,
                feePerBatch,
                nonfungiblePositionManager
            )
        );
        if (!success) {
            revert AuctionInitializationFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initialises the Recycle contract.
     * @dev Extracts necessary parameters from the encoded payload and initialises the Recycle contract.
     * Raises an exception upon initialization failure.
     * @param payload Encoded data containing Xenify Protocol parameters.
     */
    function _initialiseRecycle(
        bytes calldata payload
    ) internal {
        (
            ,,, address team,
            ,,, address swapRouter,
                address nonfungiblePositionManager
        ) = abi.decode(payload, (
                                    bytes32,
                                    address,
                                    address,
                                    address,
                                    uint256,
                                    uint256,
                                    uint256,
                                    address,
                                    address
                                )
        );
        (bool success, ) = recycle.call(
            abi.encodeWithSignature(
                "initialise(address,address,address,address,address)",
                team,
                auction,
                XNF,
                nonfungiblePositionManager,
                swapRouter
            )
        );
        if (!success) {
            revert RecycleInitializationFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initialises the XNF contract.
     * @dev Deciphers the merkle root from the provided payload and utilises it for XNF contract initialization.
     * Throws an error if initialization is unsuccessful.
     * @param payload Encoded Xenify Protocol parameters.
     */
    function _initialiseXNF(
        bytes calldata payload
    ) internal {
        (
            bytes32 merkleRootXNF,
            ,,,,,,,
        ) = abi.decode(payload, (
                                    bytes32,
                                    address,
                                    address,
                                    address,
                                    uint256,
                                    uint256,
                                    uint256,
                                    address,
                                    address
                                )
        );
        (bool success, ) = XNF.call(
            abi.encodeWithSignature(
                "initialise(address,address,bytes32)",
                auction,
                recycle,
                merkleRootXNF
            )
        );
        if (!success) {
            revert XNFInitializationFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Initialises the veXNF contract.
     * @dev This function sets up the veXNF contract by invoking its `initialise` function through a low-level call.
     * The initialization process binds the veXNF contract to the given XNF and auction addresses.
     * If the initialization fails, it will throw a `veXNFInitializationFailed` error.
     */
    function _initialiseVeXNF() internal {
        (bool success, ) = veXNF.call(
            abi.encodeWithSignature(
                "initialise(address,address)",
                XNF,
                auction
            )
        );
        if (!success) {
            revert veXNFInitializationFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}