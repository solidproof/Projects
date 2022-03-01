// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct TokenMintData {
    uint tokenId;
    uint batchId;
    uint price;
    address payable creator;
    address payable buyer;
    // JSON metadata with userId, name, fileUrl, thumbnailUrl information
    string metadata;
    string secretUrl;
}
