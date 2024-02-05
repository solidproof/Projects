// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./common/ERC721URIStorageUpgradeable.sol";
import "./common/ERC721PausableUpgradeable.sol";
import "./common/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title GALIX ERC721 Token
 * @author GALIX Inc
*/

contract GalixERC721 is
    Initializable,
    ContextUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC721BurnableUpgradeable,
    ERC721PausableUpgradeable,
    EIP712Upgradeable,
    ReentrancyGuardUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdIncr;
    address public proxyRegistryAddress;
    mapping(string => uint8) public cids;
    string public __baseURI;
    mapping(uint256 => uint8) public locks;
    mapping(address => uint256) public nonces;
    mapping(uint256 => uint256) public lastTransfer;
    uint256 public transferLock;
    IERC20Upgradeable public currency;
    address public liquidityProviderAddress;  

    event onAwardItems(address[] recipients, string[] cids, uint256[] tokenIds);
    event onAwardItem(address recipient, string cid, uint256 tokenId);
    event onTransfer(address from, address to, uint256 tokenId);
    event onBurn(uint256 tokenId);
    event onLock(uint256 tokenId);
    event onUnlock(uint256 tokenId);

    function initialize(string memory _name, string memory _symbol, address _currency) public virtual initializer {
        __Ownable_init();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __ERC721_init_unchained(_name, _symbol);
        __ERC721Burnable_init_unchained();
        __Pausable_init_unchained();
        __ERC721Pausable_init_unchained();
        __EIP712_init_unchained("GalixERC721EIP712", "1.0.0");

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        transferLock = 0;
        currency = IERC20Upgradeable(_currency);
    }

    //internal view
    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        string memory _cid = _getCID(tokenId);
        super._burn(tokenId);
        if (bytes(_cid).length != 0) {
            cids[_cid] = 0;
        }
    }
    
    function isTransferable(uint256 tokenId) internal view returns (bool){
        bool ret = lastTransfer[tokenId] <= blockHeight();
        return ret;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Upgradeable, ERC721PausableUpgradeable) {
        require(locks[tokenId] != 1 && isTransferable(tokenId), "ERC721: was locking");
        super._beforeTokenTransfer(from, to, tokenId);
        lastTransfer[tokenId] = blockHeight();
        emit onTransfer(from, to, tokenId);
    }

    function _awardItem(address recipient, string memory cid) internal returns(uint256 tokenId){
        require(cids[cid] != 1, "_awardItem: cid invalid");
        cids[cid] = 1;        
        uint256 newTokenId = _tokenIdIncr.current();
        _tokenIdIncr.increment();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, cid);
        return newTokenId;
    }
    
    function _awardItemBySignatureHash(
        address account,
        string memory cid,
        uint256 deadline
    ) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("AwardItemBySignature(address account,string cid,uint256 nonce,uint256 deadline)"),
            account,        
            keccak256(bytes(cid)),
            nonces[account],
            deadline
        )));
    }

    function _awardItemWithFeeBySignatureHash(
        address account,
        string memory cid,
        uint256 deadline,
        uint256 fee
    ) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("AwardItemWithFeeBySignature(address account,string cid,uint256 nonce,uint256 deadline,uint256 fee)"),
            account,        
            keccak256(bytes(cid)),
            nonces[account],
            deadline,
            fee
        )));
    }


    function _verify(bytes32 digest, bytes memory signature)
        internal view returns (bool)
    {
        return hasRole(MINTER_ROLE, ECDSAUpgradeable.recover(digest, signature));
    }

    //onwer view
    function setBaseURI(string memory baseURI) public onlyOwner {
        __baseURI = baseURI;
    }

    function setLandLpAddress(address  _landLpAddress) public onlyOwner {
        liquidityProviderAddress = _landLpAddress;
    }

    function setProxyRegistryAddress(address _proxyRegistryAddress) public onlyOwner {
        proxyRegistryAddress = _proxyRegistryAddress;
    }

    //admin view
    function awardItems(address[] memory _recipients, string[] memory _cids) public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721: must have minter role to awardItem");
        uint256[] memory tokenIds = new uint256[](_recipients.length);
        for(uint256 i=0; i<=_recipients.length; i++){
            tokenIds[i] = _awardItem(_recipients[i], _cids[i]);
        }
        emit onAwardItems(_recipients, _cids, tokenIds);
    }
    
    function awardItem(address recipient, string memory cid) public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721: must have minter role to awardItem");
        uint256 tokenId = _awardItem(recipient, cid);
        emit onAwardItem(recipient, cid, tokenId);
    }

    function lock(uint256 tokenId) public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721: must have minter role to lock");
        locks[tokenId] = 1;
        emit onLock(tokenId);
    }

    function unlock(uint256 tokenId) public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721: must have minter role to unlock");
        require((locks[tokenId] == 1), "ERC721: unlock input invalid");
        delete locks[tokenId];
        emit onUnlock(tokenId);
    }

    function burn(uint256 tokenId) public virtual override{
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not owner nor approved");
        _burn(tokenId);
        emit onBurn(tokenId);
    }

    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721: must have pauser role to pause");
        _pause();
    }

    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721: must have pauser role to unpause");
        _unpause();
    }

    function addMinter(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC721: Must have admin role to addMinter");
        grantRole(MINTER_ROLE, account);
    }

    function removeMinter(address account) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC721: must have admin role to removeMinter");
        revokeRole(MINTER_ROLE, account);
    }

    function setTransferLock(uint256 _transferLock) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "ERC721: must have admin role to setTransferLock");
        transferLock = _transferLock;
    }

    //anon view
    function awardItemBySignature(
        string memory cid,
        uint256 deadline,
        bytes calldata signature
    ) public nonReentrant {
        address account = _msgSender();
        require(timestamp() <= deadline, "awardItemBySignature: Expired transaction");
        require(_verify(_awardItemBySignatureHash(account, cid, deadline), signature), "awardItemBySignature: Invalid signature");
        uint256 tokenId = _awardItem(account, cid);
        nonces[account]++;
        emit onAwardItem(account, cid, tokenId);
    }

    function awardItemWithFeeBySignature(
        string memory cid,
        uint256 deadline,
        uint256 fee,
        bytes calldata signature
    ) public nonReentrant{
        address account = _msgSender();
        require(timestamp() <= deadline, "awardItemWithFeeBySignature: Expired transaction");
        require(_verify(_awardItemWithFeeBySignatureHash(account, cid, deadline, fee), signature), "awardItemWithFeeBySignature: Invalid signature");
        require(currency.balanceOf(account) >= fee, "Balance not enough");
        require(currency.allowance(account, address(this)) >= fee, "fee exceeds allowance");
        currency.safeTransferFrom(account, liquidityProviderAddress, fee);
        uint256 tokenId = _awardItem(account, cid);
        nonces[account]++;
        emit onAwardItem(account, cid, tokenId);
    }
    
    

    function transferableAt(uint256 tokenId) internal view returns (uint256){
        return lastTransfer[tokenId] + transferLock;
    }

    function tokenIdsOf(address account) public view returns (uint256[] memory) { 
        uint256 retCount = 0;
        for(uint256 i=0; i<=_tokenIdIncr.current(); i++){
            if(isOwnerOf(account, i)){
                retCount++;
            }
        }
        uint256[] memory tokenIds = new uint256[](retCount);
        uint256 j = 0;
        for(uint256 i=0; i<=_tokenIdIncr.current(); i++){
            if(isOwnerOf(account, i)){
                tokenIds[j]= i;
                j++;
            }
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * Override isApprovedForAll to whitelist market contract.
    */
    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {   
        if (operator == proxyRegistryAddress) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    function timestamp() public view returns (uint256) {
        return block.timestamp;
    }

    function blockHeight() public view returns (uint256) {
        return block.number;
    }

    function version() public view virtual returns (uint256) {
        return 202108251;
    }

    /*
        t.Approval
        t.ApprovalForAll
        t.DEFAULT_ADMIN_ROLE
        t.OwnershipTransferred
        t.Paused
        t.RoleAdminChanged
        t.RoleGranted
        t.RoleRevoked
        t.Transfer
        t.Unpaused
        t.abi
        t.address
        t.allEvents
        t.approve
        t.awardItem
        t.balanceOf
        t.burn
        t.constructor
        t.contract
        t.getApproved
        t.getPastEvents
        t.getRoleAdmin
        t.getRoleMember
        t.getRoleMemberCount
        t.grantRole
        t.hasRole
        t.initialize
        t.isApprovedForAll
        t.methods
        t.name
        t.owner
        t.ownerOf
        t.paused
        t.renounceOwnership
        t.renounceRole
        t.revokeRole
        t.safeMint
        t.safeTransferFrom
        t.send
        t.sendTransaction
        t.setApprovalForAll
        t.supportsInterface
        t.symbol
        t.tokenByIndex
        t.tokenOfOwnerByIndex 
        t.tokenURI
        t.totalSupply
        t.transactionHash
        t.transferFrom
        t.transferOwnership
    */
}
