// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.19;

// Importing required libraries
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

/**
 * @title Verifier Contract
 * @dev This contract is used for recovering the signer of a given message.
 */
contract Verifier is EIP712 {
    using ECDSA for bytes32;

    // Structure for Transaction request
    struct TxnRequest {
        bytes32 nonce; // Unique transaction nonce
    }

    /**
     * @dev Contract constructor
     * Calls the EIP712 constructor to initialize domain separator.
     */
    constructor() EIP712("Verifier", "1.0.0") {
    }

    /**
     * @dev Fallback function to accept ether
     */
    receive() external payable {}

    /**
     * @dev Returns the hash of the provided transaction request, according to EIP712
     * @param params The transaction request
     * @return The hash of the transaction request
     */
    function typedDataHash(TxnRequest memory params) public view returns (bytes32) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("TxnRequest(bytes32 nonce)"),
                    params.nonce
                )
            )
        );
        return digest;
    }

    /**
     * @dev Recover signer's address for a given signature
     * @param _nonce The unique transaction nonce
     * @param userSignature The signature provided by the user
     * @return The address recovered from the signature
     */
    function recoverSigner(bytes32 _nonce, bytes memory userSignature) external view returns (address) {
        TxnRequest memory params = TxnRequest({
            nonce: _nonce
        });
        bytes32 digest = typedDataHash(params);
        return ECDSA.recover(digest, userSignature);
    }
} 
