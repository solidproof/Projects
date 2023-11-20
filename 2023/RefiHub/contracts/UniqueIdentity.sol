// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract UniqueIdentity is ERC721Enumerable, Ownable {
  using Strings for uint256;

  /**
   * Collection base uri
   */
  string public baseURI;

  /**
   * Signer address to allow mint/burn using signature
   */
  address public signer;

  /**
   * Price per mint (minting with signer address is free)
   */
  uint256 public constant MINT_COST_PER_TOKEN = 830000 gwei;

  /**
   * @dev hash usage mapping to prevent reuse of same hash multiple times
   */
  mapping(bytes32 => bool) public hashUsage;

  /**
   * @dev Events
   */
  event SignerUpdated(address signer);
  event BaseURIUpdated(string baseURI);
  event Withdraw(uint256 amount);

  /**
   * @param _name collection name
   * @param _symbol collection symbol
   * @param _initBaseURI metadata uri
   * @param _signer signer address providing signatures for mint/burn
   */
  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    address _signer
  ) ERC721(_name, _symbol) {
    setBaseURI(_initBaseURI);
    signer = _signer;
  }

  /**
   * @dev Get collection base uri
   */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  /**
   * @dev Mint new KYC token for user.
   * @param account user address
   * @param tokenId tokenId, which should be userId from DB
   * @param expiresAt signature expiration timestamp
   * @param signature backend signature signed with signer address
   */
  function mint(
    address account,
    uint256 tokenId,
    uint256 expiresAt,
    bytes calldata signature
  ) external payable onlySigner(account, tokenId, expiresAt, signature) {
    require(
      msg.value >= MINT_COST_PER_TOKEN, 
      "Token mint requires MINT_COST_PER_TOKEN"
    );
    _mintEx(account, tokenId);
  }

  /**
   * @dev Mint new KYC token for user with signer address.
   * @param account user address
   * @param tokenId tokenId, which should be userId from DB
   */
  function mintWithSigner(
    address account,
    uint256 tokenId
  ) external {
    require(msg.sender == signer, "Unauthorized");
    _mintEx(account, tokenId);
  }

  /**
   * @dev Internal function for minting new KYC token for user.
   * @param account user address
   * @param tokenId tokenId, which should be userId from DB
   */
  function _mintEx(
    address account,
    uint256 tokenId
  ) internal {
    require(balanceOf(account) == 0, "Balance before mint must be 0");

    _safeMint(account, tokenId);
  }

  /**
   * @dev Burn users KYC token.
   * @param account user address
   * @param expiresAt signature expiration timestamp
   * @param signature backend signature signed with signer address
   */
  function burn(
    address account,
    uint256 expiresAt,
    bytes calldata signature
  ) public onlySigner(account, tokenOfOwnerByIndex(account, 0), expiresAt, signature) {
    require(balanceOf(account) == 1, "Balance before burn must be 1");
    _burn(tokenOfOwnerByIndex(account, 0));
    require(balanceOf(account) == 0, "Balance after burn must be 0");
  }


  /**
   * @dev Get token uri
   * @param tokenId nft id
   */
  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return
      bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString()))
        : "";
  }

  /**
   * @dev Disabled token transfers other than mint or burn. Each KYC nft is soulbounded to one user.
   */
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override {
    revert("Transfers not allowed!");
  }

  /**
   * @dev onlySigner modifier checks if signature is valid, not expired nor already used.
   */
  modifier onlySigner(
    address account,
    uint256 tokenId,
    uint256 expiresAt,
    bytes calldata signature
  ) {
    require(block.timestamp < expiresAt, "Signature has expired");

    bytes32 dataHash = keccak256(abi.encodePacked(account, tokenId, expiresAt, address(this), block.chainid));
    bytes32 ethSignedMessage = ECDSA.toEthSignedMessageHash(dataHash);
    require(signer == ECDSA.recover(ethSignedMessage, signature), "Invalid signer");
    require(!hashUsage[dataHash], "Signature already used");
    hashUsage[dataHash] = true;
    _;
  }

  /**
    * @dev Sets signer.
    * @param _signer Address we are setting.
    */
  function setSigner(address _signer)
    external
    onlyOwner
  {
    require(_signer != address(0), "Non zero address");
    signer = _signer;
    emit SignerUpdated(signer);
  }

  /**
    * @dev Sets baseURI.
    * @param _newBaseURI baseURI we are setting.
    */
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
    emit BaseURIUpdated(baseURI);
  }

  /**
    * @dev Withdraw raised
    * @param receiver receiver address
    */
  function withdrawRaised(address receiver) external onlyOwner {
    uint256 bal = address(this).balance;
    (bool os, ) = receiver.call{value: bal}("");
    require(os, "Transfer failed.");
    emit Withdraw(bal);
  }

  /**
   * @dev Get contract balance of gas token
   */
  function getNativeBalance() external view returns (uint256) {
      return address(this).balance;
  }
}
