// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

contract HashRateUpgradeable is EIP712Upgradeable {
    address public hrSigner;
    // token contract => (token Id , nonce)
    mapping(address => mapping(uint256 => uint256)) public nftNonceMap;

    function __HashRate_init(address _hrSigner) internal initializer {
        __EIP712_init_unchained("HashRate", "1");
        hrSigner = _hrSigner;
    }

    function getDomainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    bytes32 public constant HashRate_CALL_HASH_TYPE =
        0xce6057f96b1856fab37bcba791a8f79f33fe696bb1d99b034e91c8ae9dfb586c;

    //        keccak256(
    //            "hashrate(address contract, uint256 tokenId, uint256 nftNonce, uint256 value)"
    //        );

    function setNftHashRate(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _vNonceValue,
        bytes32 _r,
        bytes32 _s
    ) internal returns (uint256) {
        uint256 value = getNFTHashRate(
            _tokenContract,
            _tokenId,
            _vNonceValue,
            _r,
            _s
        );
        nftNonceMap[_tokenContract][_tokenId] += 1;
        return value;
    }

    function getNFTHashRate(
        address _tokenContract,
        uint256 _tokenId,
        uint256 _vNonceValue,
        bytes32 _r,
        bytes32 _s
    ) public view returns (uint256 value) {
        uint248 nonceValue = uint248(_vNonceValue);
        uint8 v = uint8(_vNonceValue >> 248);
        uint256 nonce = uint120(nonceValue >> 128);
        value = uint128(nonceValue);

        require(
            nftNonceMap[_tokenContract][_tokenId] == nonce,
            "HashRateUpgradeable#getNFTHashRate: nonce is not match"
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                ECDSAUpgradeable.toTypedDataHash(
                    _domainSeparatorV4(),
                    keccak256(
                        abi.encode(
                            HashRate_CALL_HASH_TYPE,
                            _tokenContract,
                            _tokenId,
                            nonce,
                            value
                        )
                    )
                )
            )
        );
        require(
            ECDSAUpgradeable.recover(digest, v, _r, _s) == hrSigner,
            "HashRate#getNFTHashRate: invalid signer"
        );
        return value;
    }
}
