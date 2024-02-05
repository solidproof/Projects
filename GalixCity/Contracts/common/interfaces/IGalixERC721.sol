// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * @title Galix ERC721 Token
 * @author GALIX Inc
*/

interface IGalixERC721 is IERC721Upgradeable {
    event onAwardItem(address recipient, string cid, uint256 tokenId);
    event onTokenTransfer(address from, address to, uint256 tokenId);
    event onTokenBurn(uint256 tokenId);
    event onLockItem(uint256 tokenId);
    event onUnlockItem(uint256 tokenId);

    //anon view
    function isOwnerOf(address account, uint256 tokenId) external view returns (bool);
    function nonceOf(address account) external view returns (uint256);
    function awardItemBySignature(address recipient, string memory cid, uint256 deadline, bytes calldata signature) external returns (uint256);
    function burn(uint256 tokenId) external;
    function pause() external;
    function unpause() external;
    function isLocked(string memory cid) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function version() external view returns (uint256);
    function tokenIdsOf(address account) external view returns (uint256[] memory);
}
