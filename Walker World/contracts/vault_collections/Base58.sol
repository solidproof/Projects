// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/**
 * Ported from https://github.com/storyicon/base58-solidity/blob/master/contracts/Base58.sol
 */
contract Base58 {
    bytes private constant ALPHABET =
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    /**
     * @notice encode is used to encode the given bytes in base58 standard.
     * @param data_ raw data, passed in as bytes.
     * @return base58 encoded data_, returned as bytes.
     */
    function encode(bytes memory data_) public pure returns (bytes memory) {
        uint256 size = data_.length;
        uint256 zeroCount;
        while (zeroCount < size && data_[zeroCount] == 0) {
            ++zeroCount;
        }
        size = zeroCount + ((size - zeroCount) * 8351) / 6115 + 1;
        bytes memory slot = new bytes(size);
        uint32 carry;
        int256 m;
        int256 high = int256(size) - 1;
        uint256 dataLength = data_.length;
        for (uint256 i = 0; i < dataLength; ++i) {
            m = int256(size - 1);
            for (carry = uint8(data_[i]); m > high || carry != 0; --m) {
                carry = carry + 256 * uint8(slot[uint256(m)]);
                slot[uint256(m)] = bytes1(uint8(carry % 58));
                carry /= 58;
            }
            high = m;
        }
        uint256 n;
        for (n = zeroCount; n < size && slot[n] == 0; ++n) {}
        size = slot.length - (n - zeroCount);
        bytes memory out = new bytes(size);
        for (uint256 i = 0; i < size; ++i) {
            uint256 j = i + n - zeroCount;
            out[i] = ALPHABET[uint8(slot[j])];
        }
        return out;
    }

    /**
     * @notice encodeToString is used to encode the given byte in base58 standard.
     * @param data_ raw data, passed in as bytes.
     * @return base58 encoded data_, returned as a string.
     */
    function encodeToString(bytes memory data_)
        public
        pure
        returns (string memory)
    {
        return string(encode(data_));
    }
}
