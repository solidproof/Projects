//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/Operatable.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";

/**
 * This contract implements EIP-712 for verifying signed messages
 */
contract Swap is Context, Ownable, Operatable, IERC165, IERC1363Receiver {
    mapping(uint256 => uint256) private _nonces;
    mapping(uint256 => mapping(uint256 => bool)) private _usedNonces;

    IERC20 private _inpulsex;

    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct SwapRequest {
        uint256 fromChain;
        uint256 toChain;
        address operator;
        address recipient;
        uint256 amount;
        uint256 nonce;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 constant SWAPREQUEST_TYPEHASH =
        keccak256(
            "SwapRequest(uint256 fromChain,uint256 toChain,address operator,address recipient,uint256 amount,uint256 nonce)"
        );

    bytes32 immutable DOMAIN_SEPARATOR;

    constructor() {
        DOMAIN_SEPARATOR = hash(
            EIP712Domain({
                name: "InpulseX PegSwap Router",
                version: "1",
                chainId: getChainId(),
                verifyingContract: address(this)
            })
        );
    }

    /**
     * @dev Returns the chain ID of the network the contract is currently deployed to.
     * @return uint256 The chain ID of the network.
     */
    function getChainId() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /**
     * @dev Returns the hash of an EIP712 domain.
     * @param eip712Domain An EIP712 domain.
     * @return bytes32 The hash of the EIP712 domain.
     */
    function hash(EIP712Domain memory eip712Domain)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(eip712Domain.name)),
                    keccak256(bytes(eip712Domain.version)),
                    eip712Domain.chainId,
                    eip712Domain.verifyingContract
                )
            );
    }

    /**
     * @dev Returns the hash of a swap request.
     * @param swapRequest A swap request.
     * @return bytes32 The hash of the swap request.
     */
    function hash(SwapRequest memory swapRequest)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    SWAPREQUEST_TYPEHASH,
                    swapRequest.fromChain,
                    swapRequest.toChain,
                    swapRequest.operator,
                    swapRequest.recipient,
                    swapRequest.amount,
                    swapRequest.nonce
                )
            );
    }

    /**
     * @dev Verifies a signature for a swap request.
     * @param swapRequest A swap request.
     * @param v The recovery parameter of the signature.
     * @param r The first half of the signature.
     * @param s The second half of the signature.
     * @return bool `true` if the signature is valid, `false` otherwise.
     */
    function verify(
        SwapRequest memory swapRequest,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view returns (bool) {
        // Note: we need to use `encodePacked` here instead of `encode`.
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash(swapRequest))
        );
        return ECDSA.recover(digest, v, r, s) == swapRequest.operator;
    }

    /**
     * @dev Emitted when a swap request has been successfully claimed.
     * @param fromChain The chain the token is being swapped from.
     * @param toChain The chain the token is being swapped to.
     * @param operator The address of the operator.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens being swapped.
     */
    event Claimed(
        uint256 fromChain,
        uint256 toChain,
        address operator,
        address recipient,
        uint256 amount
    );

    /**
     * @dev Claims a swap request.
     * Requirements:
     * - The signature must be valid.
     * - The operator must be valid.
     * - The nonce must not have already been claimed.
     * @param swapRequest A swap request.
     * @param v The recovery parameter of the signature.
     * @param r The first half of the signature.
     * @param s The second half of the signature.
     *
     * Emits `Clamed` If the swap request is successfully claimed.
     */
    function claim(
        SwapRequest memory swapRequest,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bool isValid = verify(swapRequest, v, r, s);
        require(isValid, "PegSwap: Signature is not valid");

        bool isFromValidOperator = isOperator(swapRequest.operator);
        require(isFromValidOperator, "PegSwap: Operator not valid");

        bool claimed = _usedNonces[swapRequest.fromChain][swapRequest.nonce];
        require(!claimed, "PegSwap: Already claimed");

        _usedNonces[swapRequest.fromChain][swapRequest.nonce] = true;

        emit Claimed(
            swapRequest.fromChain,
            swapRequest.toChain,
            swapRequest.operator,
            swapRequest.recipient,
            swapRequest.amount
        );

        bool success = _inpulsex.transfer(
            swapRequest.recipient,
            swapRequest.amount
        );

        require(success, "PegSwap: TransferFrom failed");
    }

    /**
     * @dev Returns whether a swap request with the given nonce from the given
     * chain has already been claimed.
     * @param fromChain The chain the token is being swapped from.
     * @param nonce The nonce of the swap request.
     * @return bool `true` if the swap request has been claimed, `false`
     */
    function isClaimed(uint256 fromChain, uint256 nonce)
        external
        view
        returns (bool)
    {
        return _usedNonces[fromChain][nonce];
    }

    /**
     * @dev Sets `inpulsex` contract address.
     *
     * Requirements:
     *
     * - `inpulsex` should not be address(0)
     */
    function setInpulseXAddr(address inpulsex) external onlyOwner {
        require(inpulsex != address(0), "PegSwap: Cannot set InpulseX to 0x0");
        _inpulsex = IERC20(inpulsex);
    }

    event SwapRequested(
        uint256 toChain,
        address toAddress,
        uint256 amount,
        address requestedFrom,
        address operator,
        uint256 nonce
    );

    /**
     * @dev Called when a transfer is received by the contract.
     * @param requestedFrom The address that requested the transfer.
     * @param from The address that sent the transfer.
     * @param value The amount of tokens transferred.
     * @param data The data associated with the transfer.
     * @return bytes4 The selector for the onTransferReceived function from the
     * IERC1363Receiver interface.
     *
     * Reverts if the message sender is not the InpulseX token.
     * Emits `SwapRequested` with information about the swap request.
     */
    function onTransferReceived(
        address requestedFrom,
        address from,
        uint256 value,
        bytes memory data
    ) external returns (bytes4) {
        require(
            _msgSender() == address(_inpulsex),
            "PegSwap: Message sender is not the InpulseX token"
        );

        (uint256 toChain, address operator) = abi.decode(
            data,
            (uint256, address)
        );

        uint256 nonce = _nonces[toChain];
        _nonces[toChain] = _nonces[toChain] + 1;

        emit SwapRequested(
            toChain,
            from,
            value,
            requestedFrom,
            operator,
            nonce
        );

        return IERC1363Receiver(this).onTransferReceived.selector;
    }

    /* ERC165 methods */

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == type(IERC1363Receiver).interfaceId;
    }

    /**
     * @dev Sends `amount` of `token` from contract address to `recipient`
     *
     * Useful if someone sent erc20 tokens to the contract address by mistake.
     */
    function recoverTokens(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner returns (bool) {
        return IERC20(token).transfer(recipient, amount);
    }
}
