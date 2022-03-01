// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "../structs/TokenMintData.sol";

interface ISuperAssetV2 is IERC165 {
    function setMarketplaceAddress(address marketplaceAddress) external;

    function setSignerAddress(address signerAddress) external;

    function setMetaUrl(string memory url) external;

    function mintTokenBatch(
        uint _amountToMint,
        uint _price,
        uint _batchId,
        address payable _creator,
        address payable _buyer,
        string memory _metadata,
        string memory _secretUrl,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) external payable;

    function mintToken(
        TokenMintData memory tokenData,
        address payable[] memory _royaltyAddresses,
        uint[] memory _royaltyPercentages,
        bytes memory _signature
    ) external payable returns (uint);

    function getTokenData(uint tokenId)
        external
        view
        returns (
            uint _batchId,
            uint _price,
            address _creator,
            address _buyer,
            string memory _metadata,
            string memory _location
        );

    function setTokenLocation(uint _tokenId, string memory _location) external;

    function setTokenRoyalties(
        uint256 _tokenId,
        address payable[] memory _royaltyAddresses,
        uint256[] memory _royaltyPercentages
    ) external;

    function getOwnedNFTs(address _owner) external view returns (string memory);

    function exists(uint tokenId) external view returns (bool);
}
