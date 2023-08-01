// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../lib/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VeLogo {
    /// @dev Return SVG logo of veNFT.
    function _tokenURI(
        uint256 _tokenId,
        bool isBond,
        uint256 _balanceOf,
        uint256 untilEnd,
        uint256 _value
    ) external view returns (string memory output) {
        string memory _isBond;
        if (isBond) {
            _isBond = "true";
        } else {
            _isBond = "false";
        }

        output = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 900"><style>.b{fill:#4F6295;}.g{fill:#D3F85A;}.f{fill:#D0DA55;}.w{fill:#FFFFFF;}.s{font-size:37px;}</style><rect fill="#2B3A5B" width="600" height="900"/><rect class="b" x="55" y="424" width="544" height="98"/><rect class="b" x="0" y="544" width="517" height="98"/><rect class="b" x="0" y="772" width="516" height="98"/><rect class="b" x="55" y="658" width="544" height="98"/><path class="g" d="M62.2,419.7v97.8c0,0.5,0.4,0.9,0.9,0.9H600v-1.8H64v-96h536v-1.8H63.1C62.6,418.8,62.2,419.2,62.2,419.7z"/><path class="g" d="M62.2,651.8v97.8c0,0.5,0.4,0.9,0.9,0.9H600v-1.8H64v-96h536v-1.8H63.1C62.6,650.9,62.2,651.3,62.2,651.8z"/><path class="g" d="M512.3,636.3v-97.8c0-0.5-0.4-0.9-0.9-0.9H0v1.8h510.5v96H0v1.8h511.4C511.9,637.2,512.3,636.8,512.3,636.3z"/><path class="g" d="M512.3,863.8V766c0-0.5-0.4-0.9-0.9-0.9H0v1.8h510.5v96H0v1.8h511.4C511.9,864.7,512.3,864.3,512.3,863.8z"/>';
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 88 463)" class="f s">ID:</text><text transform="matrix(1 0 0 1 88 502)" class="w s">',
                _toString(_tokenId),
                "</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 350 463)" class="f s">isBond:</text><text transform="matrix(1 0 0 1 350 502)" class="w s">',
                _isBond,
                "</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 88 579)" class="f s">Balance:</text><text transform="matrix(1 0 0 1 88 618)" class="w s">',
                _toString(_balanceOf / 1e18),
                "</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 88 694)" class="f s">Until unlock:</text><text transform="matrix(1 0 0 1 88 733)" class="w s">',
                _toString(untilEnd / 60 / 60 / 24),
                " days</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 88 804)" class="f s">Power:</text><text transform="matrix(1 0 0 1 88 843)" class="w s">',
                _toString(_value / 1e18),
                "</text></svg>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "veFANG #',
                        _toString(_tokenId),
                        '", "description": "Locked FANG tokens", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
    }

    /// @dev Inspired by OraclizeAPI's implementation - MIT license
    ///      https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
