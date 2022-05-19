// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./IERC20.sol";

contract RewardDistribution is Ownable {
    address public signerAddress;
    IERC20 internal floyx;
    mapping(bytes => bool) public usedSignatures;

    event RewardWithdrawal(
        address indexed userAdd,
        uint256 amount,
        uint256 withdrawalId
    );

    constructor(address _signerAddress, address _tokenAddress) {
        require(
            _signerAddress != address(0),
            "Signer Address could not be empty"
        );
        require(
            _tokenAddress != address(0),
            "Token Address could not be empty"
        );

        signerAddress = _signerAddress;
        floyx = IERC20(_tokenAddress);
    }

    function withdrawReward(
        address userAddress,
        uint256 amount,
        uint256 withdrawalId,
        bytes memory signature
    ) public returns (bool) {
        require(userAddress != address(0), "User Address could not be empty");
        require(amount > 0, "Amount cannot be zero");
        require(!usedSignatures[signature], "Signatures already used");

        address recoveredAddress = recoverSigner(
            keccak256(abi.encodePacked(userAddress, amount, withdrawalId)),
            signature
        );
        require(recoveredAddress == signerAddress, "sign incorrect");
        floyx.transfer(userAddress, amount);
        usedSignatures[signature] = true;

        emit RewardWithdrawal(userAddress, amount, withdrawalId);
        return true;
    }

    function adminWithdrawal(address userAddress, uint256 amount)
        public
        onlyOwner
    {
        require(userAddress != address(0), "User Address could not be empty");
        require(amount > 0, "Amount cannot be zero");

        floyx.transfer(userAddress, amount);
    }

    function updateSignerAddress(address _signerAddress) public onlyOwner {
        require(
            _signerAddress != address(0),
            "Signer Address could not be empty"
        );
        signerAddress = _signerAddress;
    }

    function recoverSigner(bytes32 message, bytes memory sig)
        internal
        pure
        returns (address)
    {
        message = prefixed(message);
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(sig);
        return ecrecover(message, v, r, s);
    }

    // Builds a prefixed hash to mimic the behavior of eth_sign.
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
            );
    }

    function splitSignature(bytes memory sig)
        internal
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }
}