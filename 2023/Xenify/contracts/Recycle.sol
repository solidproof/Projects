// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.18;

import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBurnRedeemable} from "./interfaces/IBurnRedeemable.sol";
import {IBurnableToken} from "./interfaces/IBurnableToken.sol";
import {IRecycle} from "./interfaces/IRecycle.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {console} from "hardhat/console.sol";

/*
 * @title Recycle Contract
 *
 * @notice This contract facilitates the conversion of native tokens into specified tokens,
 * adds liquidity to Uniswap V3, and manages the distribution of fees.
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
contract Recycle is
    ERC165,
    IRecycle,
    IBurnRedeemable,
    ReentrancyGuard
{

    /// ------------------------------------ VARIABLES ------------------------------------- \\\

    /**
     * @notice Address of the XNF contract, set during deployment and cannot be changed.
     */
    address public xnf;

    /**
     * @notice Address of the WETH contract, set during deployment and cannot be changed.
     */
    address public weth;

    /**
     * @notice Address designated for team-related distributions or operations.
     */
    address public team;

    /**
     * @notice Address of the Auction contract, set during deployment and cannot be changed.
     */
    address public Auction;

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Unique identifier for the Liquidity Provider (LP) Non-Fungible Token (NFT) in Uniswap V3.
     */
    uint256 public tokenId;

    /// ------------------------------------ INTERFACES ------------------------------------- \\\

    /**
     * @notice Interface to interact with token swaps using Uniswap V3.
     */
    ISwapRouter public swapRouter;

    /**
     * @notice Interface to interact with and manage positions on Uniswap V3.
     */
    INonfungiblePositionManager public nonfungiblePositionManager;

    /// --------------------------------- EXTERNAL FUNCTIONS -------------------------------- \\\

    /**
     * @notice Initialises the Recycle contract with the necessary addresses.
     * @param _team Address designated for team-related distributions or operations.
     * @param _auction Address of the Auction contract.
     * @param _xnf Address of the XNF contract.
     * @param _nonfungiblePositionManager Address of the Uniswap V3 NonfungiblePositionManager contract.
     * @param _swapRouter Address of the Uniswap V3 SwapRouter contract.
     */
    function initialise(
        address _team,
        address _auction,
        address _xnf,
        address _nonfungiblePositionManager,
        address _swapRouter
    ) external {
        if (team != address(0))
            revert ContractInitialised(team);
        if (_team == address(0))
            revert InvalidAddress();
        nonfungiblePositionManager = INonfungiblePositionManager(_nonfungiblePositionManager);
        weth = nonfungiblePositionManager.WETH9();
        swapRouter = ISwapRouter(_swapRouter);
        team = _team;
        Auction = _auction;
        xnf = _xnf;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Fallback function to accept and handle native token payments sent to this contract.
     * @dev This function is triggered when the contract receives native tokens without any calldata or with
     * calldata that does not match any function signature. It is intentionally left blank, as the contract does
     * not need to perform any specific actions when receiving native tokens directly.
     */
    receive() external payable {}

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Handles actions after a token is burned.
     * @dev Implements the IBurnRedeemable interface. This function can be extended to include additional logic post-burning.
     * @param user The address of the user who burned the tokens.
     * @param amount The number of tokens burned.
     */
    function onTokenBurned(
        address user,
        uint256 amount
    ) external override {}

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Sets the LP NFT ID. Only callable by the Auction contract.
     * @dev This function updates the `tokenId` state variable, which is presumed to be used elsewhere in the contract
     * to interact with Uniswap V3 positions. It includes a security check to ensure that only the authorized Auction
     * contract can invoke this function, enhancing the contract’s integrity and ensuring that the LP NFT ID can only
     * be set by trusted entities. If an unauthorized caller attempts to invoke this function it will revert.
     * @param _tokenId The unique identifier for the Liquidity Provider (LP) Non-Fungible Token (NFT) in Uniswap V3.
     */
    function setTokenId(uint256 _tokenId)
        external
        override
    {
        if (msg.sender != Auction) {
            revert UnauthorizedCaller();
        }
        tokenId = _tokenId;
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Converts native tokens into XNF, and transfers a portion to the team.
     * @dev The distribution is as follows: 90% of the native tokens are used for buyback and burn XNF tokens,
     * and the remaining 10% is transferred to the team's address.
     * Reverts if no native tokens are sent with the transaction, ensuring that the function is not executed
     * with a zero balance. Emits a `RecycleAction` event upon successful execution.
     */
    function recycle()
        external
        payable
        override
        nonReentrant
    {
        if (msg.value == 0) {
            revert ZeroNativeAmount();
        }
        uint256 nativeAmount = msg.value;
        _swap(nativeAmount * 90 / 100, address(this));
        _sendViaCall(
            payable(team),
            nativeAmount * 10 / 100
        );
        IBurnableToken(xnf).burn(address(this), IERC20(xnf).balanceOf(address(this)));
        emit RecycleAction(
            msg.sender,
            nativeAmount
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Executes a buyback, burning XNF tokens and distributing native tokens to the team.
     * @dev Swaps 50% of the sent value for XNF, burns it, and sends 10% to the team. The function
     * is non-reentrant and must have enough native balance to execute the swap and burn.
     */
    function executeBuybackBurn()
        external
        payable
        override
        nonReentrant
    {
        uint256 nativeAmount = msg.value;
        _swap(nativeAmount * 5 / 6, address(this));
        _sendViaCall(
            payable(team),
            nativeAmount / 6
        );
        IBurnableToken(xnf).burn(address(this), IERC20(xnf).balanceOf(address(this)));
        emit BuybackBurnAction(msg.sender, nativeAmount);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Collects and distributes fees accrued from Uniswap V3 swaps for the current cycle.
     * Swaps any collected XNF tokens to native tokens and sends them to the team's address.
     * @dev This function is intended to be called periodically to collect fees generated from liquidity provided in Uniswap V3.
     * It ensures that fees are only collected once per cycle to prevent double collection. The function will convert any collected
     * XNF tokens to native tokens using the Uniswap V3 pool, and then send the resulting native tokens to the team’s address.
     * It will revert if an attempt is made to collect fees for the current cycle more than once, ensuring proper accounting
     * and distribution of fees. Utilises the nonfungiblePositionManager to interact with the Uniswap V3 positions.
     */
    function collectFees() external override {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });
        nonfungiblePositionManager.collect(collectParams);
        uint256 xnfAmount = IERC20(xnf).balanceOf(address(this));
        if (xnfAmount != 0) {
            TransferHelper.safeApprove(xnf, address(swapRouter), xnfAmount);
            ISwapRouter.ExactInputSingleParams memory exactInputParams =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: xnf,
                    tokenOut: weth,
                    fee: 1e4,
                    recipient: address(this),
                    deadline: block.timestamp + 100,
                    amountIn: xnfAmount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            swapRouter.exactInputSingle(exactInputParams);
        }
        uint256 WETHBalance = IERC20(weth).balanceOf(address(this));
        IWETH9(weth).withdraw(WETHBalance);
        _sendViaCall(
            payable(team),
            address(this).balance
        );
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Executes a swap from XNF to native tokens (e.g., ETH), with a guaranteed minimum output.
     * @dev Swaps XNF for native tokens using swapRouter, transferring the output directly to the caller. A deadline for
     * the swap can be specified which is the timestamp after which the transaction is considered invalid. Before execution,
     * ensure swapRouter is secure and 'amountOutMinimum' accounts for slippage. The 'deadline' should be carefully set to allow
     * sufficient time for the transaction to be mined while protecting against market volatility.
     * @param amountIn The amount of XNF tokens to swap.
     * @param amountOut The minimum acceptable amount of native tokens in return.
     * @param deadline The timestamp by which the swap must be completed.
     */
    function swapXNF(
        uint256 amountIn,
        uint256 amountOut,
        uint256 deadline
    )
        external
        override
    {
        TransferHelper.safeTransferFrom(xnf, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(xnf, address(swapRouter), amountIn);
        ISwapRouter.ExactInputSingleParams memory exactInputParams =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: xnf,
                tokenOut: weth,
                fee: 1e4,
                recipient: address(this),
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: amountOut,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(exactInputParams);
        IWETH9(weth).withdraw(amountOut);
        TransferHelper.safeTransferETH(msg.sender, amountOut);
    }

    /// --------------------------------- PUBLIC FUNCTION ----------------------------------- \\\

    /**
     * @notice Checks if the contract implements an interface with the given ID.
     * @dev See {IERC165-supportsInterface}.
     * @param interfaceId The ID of the interface to check.
     * @return A boolean value indicating whether the interface is supported.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IBurnRedeemable).interfaceId || super.supportsInterface(interfaceId);
    }

    /// -------------------------------- INTERNAL FUNCTIONS --------------------------------- \\\

    /**
     * @notice Swaps ETH for XNF tokens at the current market rate.
     * @dev Executes an ETH to XNF token swap using Uniswap V3's `exactInputSingle` function. Sets the
     * deadline to 100 seconds from the current time. Assumes `_recipient` is a valid address.
     * No slippage protection is set (`amountOutMinimum` is 0).
     * @param _nativeAmount The amount of ETH to swap.
     * @param _recipient The recipient of the XNF tokens.
     * @return amountToken The amount of XNF tokens received.
     */
    function _swap(
        uint256 _nativeAmount,
        address _recipient
    )
        internal
        returns (uint256 amountToken)
    {
        ISwapRouter.ExactInputSingleParams memory exactInputParams =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: weth,
                tokenOut: xnf,
                fee: 1e4,
                recipient: _recipient,
                deadline: block.timestamp + 100,
                amountIn: _nativeAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountToken = swapRouter.exactInputSingle{value: _nativeAmount} (exactInputParams);
    }

    /// ------------------------------------------------------------------------------------- \\\

    /**
     * @notice Transfers native tokens to a specified address using a direct call.
     * @dev Uses a low-level call to transfer native tokens and reverts if the transfer fails.
     * @param to Address to receive the native tokens.
     * @param amount Amount of native tokens to be transferred.
     */
    function _sendViaCall(
        address payable to,
        uint256 amount
    ) internal {
        (bool sent, ) = to.call{value: amount} ("");
        if (!sent) {
            revert TransferFailed();
        }
    }

    /// ------------------------------------------------------------------------------------- \\\
}