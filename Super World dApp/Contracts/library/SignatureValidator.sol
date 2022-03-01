// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

library SignatureValidator {
    using ECDSA for bytes32;

    function verifySignature(
        address _signer,
        bytes32 _hash,
        bytes memory _signature
    ) internal pure {
        bytes32 ethSignedMessageHash = _hash.toEthSignedMessageHash();
        address recoveredAddress = ethSignedMessageHash.recover(_signature);

        require(recoveredAddress == _signer, "Signer and recovered addresses do not match");
    }
}
