/*
 _______       ___      .______       __  ___       _______      ___      .______      .___________. __    __
|       \     /   \     |   _  \     |  |/  /      |   ____|    /   \     |   _  \     |           ||  |  |  |
|  .--.  |   /  ^  \    |  |_)  |    |  '  /       |  |__      /  ^  \    |  |_)  |    `---|  |----`|  |__|  |
|  |  |  |  /  /_\  \   |      /     |    <        |   __|    /  /_\  \   |      /         |  |     |   __   |
|  '--'  | /  _____  \  |  |\  \----.|  .  \       |  |____  /  _____  \  |  |\  \----.    |  |     |  |  |  |
|_______/ /__/     \__\ | _| `._____||__|\__\      |_______|/__/     \__\ | _| `._____|    |__|     |__|  |__|

                             WWW.DARKEARTH.GG by Olympus Origin
                            Coded by Javier Nieto & Jesús Sánchez
                                    Juan Palomo Cisneros
*/

//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

// Smart Contracts imports
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MysteryCapsule is ERC721Enumerable, AccessControlEnumerable {

    /**********************************************
     **********************************************
                    VARIABLES
    **********************************************
    **********************************************/
    using Counters for Counters.Counter;

    IERC20 private tokenUSDC;

    string private _baseURIExtend;

    address private addrUSDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address private aggregator = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0; // Polygon MATIC/USD

    AggregatorV3Interface internal priceFeed;

    // Variables de suspensión de funcionalidades
    bool private suspended = true; // Suspender funciones generales del SC
    bool private suspendedWL = false; // Suspender función de WL
    bool private publicSale = false; // Al poner a true se activa la venta publica (Sin restricciones)
    bool private approvedTransfer = false;

    // Precio por cada capsula
    uint256 private priceCapsule = 15; // USD natural

    // Cantidad por defecto por Wallet
    uint32 private defaultMintAmount = 20;

    // Cantidad máxima de capsulas totales
    uint32 private limitCapsules = 15000;
    uint32 private limitPresale = 3000;
    uint32 private limitRewards = 2288;
    uint32 private presaleCounter = 0;

    Counters.Counter private rewardsCapsules;
    Counters.Counter private _tokenIdTracker;
    Counters.Counter private peopleWhitelisted;
    Counters.Counter private totalBurnedCapsules;

    //Adds support for OpenSea
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    address private OpenSeaAddress = 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE;

    //Roles of minter and burner
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    //Royaties address and amnount
    address payable private _royaltiesAddress;
    uint96 private _royaltiesBasicPoints;
    uint96 private maxRoyaltiePoints = 1500;

    //Mapping from address to uin32. Set the amount of chest availables to buy
    //Works both as counter and as whitelist
    mapping(address => uint32) private available;

    mapping(address => uint256[]) private burnedCapsules;

    mapping(address => Counters.Counter) private totalWalletMinted;

    // Free mints
    mapping(address => uint32) private freeMints;
    Counters.Counter private totalUsedFreeMints;
    uint256 private totalFreeMints;

    // ---------------
    // Security
    // ---------------
    struct approveMap {
        address approveAddress;
        uint8 apprFunction;
    }

    mapping(address => bool) private owners;
    mapping(address => approveMap) private approvedFunction;
    Counters.Counter private _ownersTracker;

    /**********************************************
     **********************************************
                    CONSTRUCTOR
    **********************************************
    **********************************************/
    constructor() ERC721("Mystery Capsule", "MC") {

        // URI por defecto
        _baseURIExtend = "https://nft-hub.darkearth.gg/capsules/genesis/capsule_genesis.json";

        // Oraculo
        priceFeed = AggregatorV3Interface(aggregator);

        // Interfaz para pagos en USDC
        tokenUSDC = IERC20(addrUSDC);

        //Royaties address and amount
        _royaltiesAddress=payable(address(this)); //Contract creator by default
        _royaltiesBasicPoints=1000; //10% default

        // Multi-owner
        owners[0xBB092DA2b7c96854ac0b59893a098b0803156b6a] = true;
        _ownersTracker.increment();

        owners[0xd26260934A78B9092BFc5b2518E437B20FE953b2] = true;
        _ownersTracker.increment();

		owners[0xB1e2C0F0210d32830E91d2c5ba514FDdA367eC71] = true;
        _ownersTracker.increment();

    }

    // ------------------------------
    // AÑADIR ROLES
    // ------------------------------

    function addRole(address _to, bytes32 rol, bool option) external {
        require(checkApproved(_msgSender(), 22), "You have not been approved to run this function");

        if(option) {
            _grantRole(rol, _to);
        } else {
            _revokeRole(rol, _to);
        }
    }

    // ------------------------------
    // AÑADIR WHITELIST
    // ------------------------------
    function addToWhitelist(address _to, uint32 amount) public {
        require(amount > 0, "Amount need to be higher than zero");
        require(!suspendedWL, "The contract is temporaly suspended for Whitelist");
        require(totalWalletMinted[_to].current() + amount <= defaultMintAmount, "Cannot assign more chests to mint than allowed");
        require(hasRole(WHITELIST_ROLE, _msgSender()), "Exception in WL: You do not have the whitelist role");

        // Añadir uno mas al contador de gente en la WL
        if(totalWalletMinted[_to].current() == 0 && available[_to] == 0) peopleWhitelisted.increment();

        available[_to] = amount;
    }

    function bulkDefaultAddToWhitelist(address[] calldata _to) external {
        for (uint i=0; i < _to.length; i++)
            addToWhitelist(_to[i], defaultMintAmount);
    }

    function delWhitelist(address _to) external {
        require(hasRole(WHITELIST_ROLE, _msgSender()), "Exception in WL: You do not have the whitelist role");
        if (totalWalletMinted[_to].current() == 0 && available[_to] != 0) peopleWhitelisted.decrement();
        available[_to] = 0;
    }

    // ------------------------------
    //  FREE MINTs
    // ------------------------------
    function bulkAddFreeMint(address[] calldata _to, uint32[] calldata amount) external {
        require(_to.length == amount.length, "Exception in buldAddFreeMint: Array sizes");
        require(checkApproved(_msgSender(), 2), "You have not been approved to run this function");
        uint256 auxFreeMints;

        for (uint i=0; i < _to.length; i++) {
            auxFreeMints = totalFreeMints - freeMints[_to[i]];

            require(auxFreeMints + amount[i] <= limitRewards, "Rewards limit reached. Check amount.");

            freeMints[_to[i]] = amount[i];
            totalFreeMints = auxFreeMints + amount[i];
        }
    }

    function bulkTakeFreeMint() external {
        require(!suspended, "The contract is temporaly suspended");
        require(freeMints[_msgSender()] > 0, "Exception in bulkTakeFreeMint: You dont have free mints");
        require(_tokenIdTracker.current() < limitCapsules + limitRewards, "There are no more capsules to mint... sorry!");

        for(uint i = 0; i < freeMints[_msgSender()]; i++) {
            _safeMint(_msgSender(), _tokenIdTracker.current());
            _tokenIdTracker.increment();
            totalUsedFreeMints.increment();
            rewardsCapsules.increment();
            totalWalletMinted[_msgSender()].increment();
        }

        freeMints[_msgSender()] = 0;
    }

    function getWalletFreeMints(address _to) view external returns (uint32) {
        return freeMints[_to];
    }

    function getTotalFreeMint() view external returns (uint256) {
        return totalFreeMints;
    }

    function getTotalUsedFreeMint() view external returns (uint256) {
        return totalUsedFreeMints.current();
    }

    function delFreeMints(address _to) external {
        require(checkApproved(_msgSender(), 1), "You have not been approved to run this function");
        totalFreeMints -= freeMints[_to];
        freeMints[_to] = 0;
    }

    // ------------------------------
    // MINTEO Y QUEMA DE CAPSULAS
    // ------------------------------

    function burn(uint256 tokenId) public virtual {
        require(!suspended, "The contract is temporaly suspended");
        require(ownerOf(tokenId) == _msgSender(), "Exception on Burn: Your are not the owner");

        burnedCapsules[ownerOf(tokenId)].push(tokenId);
        totalBurnedCapsules.increment();

        _burn(tokenId);
    }

    function bulkBurn(uint256[] calldata tokenIds) external {
        for(uint i = 0; i < tokenIds.length; i++)
            burn(tokenIds[i]);
    }

    function adminBulkBurn(uint256[] calldata tokenIds) external {
        require(!suspended, "The contract is temporaly suspended");
        require(hasRole(BURNER_ROLE, _msgSender()), "Exception in Burn: caller has no BURNER ROLE");
        for(uint i = 0; i < tokenIds.length; i++) {
            burnedCapsules[ownerOf(tokenIds[i])].push(tokenIds[i]);
            totalBurnedCapsules.increment();
            _burn(tokenIds[i]);
        }
    }

    //Minter
    function mint(address _to) internal {
        require(!suspended, "The contract is temporaly suspended");
        require(_tokenIdTracker.current() < limitCapsules + rewardsCapsules.current(), "There are no more capsules to mint... sorry!");

        if(_tokenIdTracker.current() == limitCapsules-1) internalEnableTransfer();

        if(!publicSale){
            require(available[_to]> 0, "Exception in mint: You have not available capsules to mint");
            available[_to] = available[_to] - 1;
        }

        _safeMint(_to, _tokenIdTracker.current());

        _tokenIdTracker.increment();
        totalWalletMinted[_to].increment();
    }

    function bulkMint(address _to, uint32 amount) internal {
        require(amount > 0, "Exception in bulkMint: Amount has to be higher than 0");
        for (uint i=0; i<amount; i++) {
            mint(_to);
        }
    }

    function purchaseChest(uint32 amount) external payable {
        require(!suspended, "The contract is temporaly suspended");
        require(amount > 0, "Exception in purchaseChest: Amount has to be higher than 0");
        require(_tokenIdTracker.current() + amount <= limitCapsules + rewardsCapsules.current(), "There are no more capsules to mint... sorry!");
        require(msg.value >= priceInMatic() * amount, "Not enough funds sent!");

        if(!publicSale){
            require(presaleCounter < limitPresale, "Exception in purchaseChest: Pre-Sale Sold-out");
            require(presaleCounter + amount <= limitPresale, "Exception in purchaseChest: There are less capsules availables");
            require(available[_msgSender()]>=amount, "Exception in purchaseChest: cannot mint so many chests");
            presaleCounter += amount;
        }

        //Mint the chest to the payer
        bulkMint(_msgSender(), amount);
    }

    function adminMint(address _to) public {
        require(!suspended, "The contract is temporaly suspended");
        require(hasRole(MINTER_ROLE, _msgSender()), "Exception in mint: You dont have the minter role.");
        require(rewardsCapsules.current() < limitRewards, "Exception in adminMint: Limit reached.");

        _safeMint(_to, _tokenIdTracker.current());
        _tokenIdTracker.increment();
        rewardsCapsules.increment();
        totalWalletMinted[_to].increment();
    }

    function bulkAdminMint(address _to, uint32 amount) external {
        require(amount > 0, "Amount need to be higher than zero.");
        for (uint i=0; i<amount; i++) {
            adminMint(_to);
        }
    }

    function bulkAdminPartnerMint(address _to, uint32 amount) external {
        require(amount > 0, "Exception in bulkAdminPartnerMint: Amount has to be higher than 0");
        require(checkApproved(_msgSender(), 9), "You have not been approved to run this function.");
        require(_tokenIdTracker.current() + amount <= limitCapsules + rewardsCapsules.current(), "There are no more capsules to mint... sorry!");

        for (uint i=0; i < amount; i++) {
            _safeMint(_to, _tokenIdTracker.current());
            _tokenIdTracker.increment();
            totalWalletMinted[_to].increment();
        }
    }

    /**********************************************
     **********************************************
                   TRANSFERENCIAS
    **********************************************
    **********************************************/

    function bulkSafeTransfer(address _from, address _to, uint256[] calldata tokenIds) external {
        for (uint256 index = 0; index < tokenIds.length; index++) {
            safeTransferFrom(_from, _to, tokenIds[index]);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721Enumerable) {

        if(from != address(0) && to != address(0)) {
            require(approvedTransfer, "Sorry, you have to wait for the sale to end to transfer these NFTs.");
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function internalEnableTransfer() internal {
        approvedTransfer = true;
    }

    function enableTransfer() external {
        require(checkApproved(_msgSender(), 23), "You have not been approved to run this function.");
        approvedTransfer = true;
    }

    function isApprovedTransfer() external view returns(bool) {
        return approvedTransfer;
    }

    /**********************************************
     **********************************************
                PAGOS EN USDC
    **********************************************
    **********************************************/

    function AcceptPayment(uint32 amount) external {
        require(amount > 0, "Exception in AcceptPayment: Amount has to be higher than 0");
        require(!suspended, "The contract is temporaly suspended");
        require(_tokenIdTracker.current() + amount <= limitCapsules + rewardsCapsules.current(), "There are no more capsules to mint... sorry!");

        uint256 convertPrice;

        if(!publicSale){
            require(presaleCounter < limitCapsules, "Exception in AcceptPayment: Pre-Sale SOLD-OUT");
            require(presaleCounter + amount <= limitPresale, "Exception in AcceptPayment: There are less capsules availables");
            require(available[_msgSender()]>=amount, "AcceptPayment: cannot mint so many chests");
            presaleCounter += amount;
        }

        convertPrice = 1000000000000000000 * priceCapsule;

        bool success = tokenUSDC.transferFrom(_msgSender(), address(this), amount * convertPrice);
        require(success, "Could not transfer token. Missing approval?");

        bulkMint(_msgSender(), amount);
    }

    function GetAllowance() external view returns(uint256) {
       return tokenUSDC.allowance(_msgSender(), address(this));
    }

    function GetUsdcBalance() external view returns(uint256) {
       return tokenUSDC.balanceOf(address(this));
    }

    function withdrawUSDC(uint amount) external {
        require(checkApproved(_msgSender(), 18), "You have not been approved to run this function.");
        bool itsOk = tokenUSDC.transfer(_msgSender(), amount);
        require(itsOk, "Could not transfer token.");
    }

    // ------------------------------------------------------

    receive() external payable {}

    function withdraw(uint amount) external {
        require(checkApproved(_msgSender(), 19), "You have not been approved to run this function.");
        payable(_msgSender()).transfer(amount);
    }

    /**********************************************
     **********************************************
                  GETTERs Y SETTERs
    **********************************************
    **********************************************/

    function getWhitelistedPeople() external view returns (uint256) {
        return peopleWhitelisted.current();
    }

    function getTotalBurnedCapsules() external view returns (uint256) {
        return totalBurnedCapsules.current();
    }

    function getChests(address _owner) external view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i = 0; i < ownerTokenCount; i++)
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);

        return tokenIds;
    }

    function getDefaultPrice() external view returns (uint256) {
        return priceCapsule;
    }

    function setDefaultPrice(uint256 newPrice) external {
        require(checkApproved(_msgSender(), 3), "You have not been approved to run this function.");
        priceCapsule=newPrice;
    }

    function setAggregator(address aggr) external {
        require(aggr != address(0), "Exception in setAggregator: Address zero.");
        require(checkApproved(_msgSender(), 4), "You have not been approved to run this function.");
        aggregator=aggr;
    }

    function getAggregator() external view returns (address) {
        return aggregator;
    }

    function setOpenSeaAddress(address newAdd) external {
        require(newAdd != address(0), "Exception in setOpenSeaAddress: Address zero.");
        require(checkApproved(_msgSender(), 5), "You have not been approved to run this function.");
        OpenSeaAddress = newAdd;
    }

    function getOpenSeaAddress() external view returns (address) {
        return OpenSeaAddress;
    }

    function setUSDCAddress(address usdc) external {
        require(usdc != address(0), "Exception in setUSDCAddress: Address zero.");
        require(checkApproved(_msgSender(), 6), "You have not been approved to run this function.");
        addrUSDC=usdc;
    }

    function getUSDCAddress() external view returns (address) {
        return addrUSDC;
    }

    function setLimitChest(uint32 limit) external {
        require(checkApproved(_msgSender(), 7), "You have not been approved to run this function.");
        limitCapsules=limit;
    }

    function getLimitChest() external view returns (uint32) {
        return limitCapsules;
    }

    function getLimitPresale() external view returns (uint32) {
        return limitPresale;
    }

    function getCounterPresale() external view returns (uint32) {
        return presaleCounter;
    }

    function getRewardsCounter() external view returns (uint256) {
        return rewardsCapsules.current();
    }

    function getTotalMintedChests() external view returns (uint256) {
        return _tokenIdTracker.current();
    }

    function getBurnedLengthCapsules(address ownerId) external view returns (uint256) {
        return burnedCapsules[ownerId].length;
    }

    function getBurnedCapsules(address ownerId) external view returns (uint256[] memory) {
        return burnedCapsules[ownerId];
    }

    function getMintableChest(address ownerId) external view returns (uint256) {
        return available[ownerId];
    }

    function getMintedCapsules(address ownerId) external view returns (uint256) {
        return totalWalletMinted[ownerId].current();
    }

    function isWhitelisted(address ownerId) external view returns (bool) {
        return (available[ownerId] > 0 || (!publicSale && totalWalletMinted[ownerId].current() > 0 ));
    }

    // Cantidad por defecto a mintear -> PRE-SALE
    function setDefaultMintAmount(uint32 defAmount) external {
        require(checkApproved(_msgSender(), 8), "You have not been approved to run this function.");
        defaultMintAmount=defAmount;
    }

    // Cantidad limite de capsulas en Pre-Sale
    function setDefaultLimitPresale(uint32 defLimit) external {
        require(checkApproved(_msgSender(), 21), "You have not been approved to run this function.");
        limitPresale=defLimit;
    }

    function getDefaultMintAmount() external view returns (uint32) {
        return defaultMintAmount;
    }

    // Activar o desactivar la venta publica
    function isPublicSale() external view returns (bool) {
        return publicSale;
    }

    function enablePublicSale() external {
        require(checkApproved(_msgSender(), 10), "You have not been approved to run this function.");
        publicSale = true;
        priceCapsule = 20;
    }

    function suspendPublicSale() external {
        require(checkApproved(_msgSender(), 11), "You have not been approved to run this function.");
        publicSale = false;
        priceCapsule = 15;
    }

    // Suspender funcionalidades general del SC
    function isSuspend() external view returns (bool) {
        return suspended;
    }

    function toggleSuspend(bool value) external {
        require(checkApproved(_msgSender(), 12), "You have not been approved to run this function.");
        suspended = value;
    }

    // Suspender la función de añadir en WL
    function isSuspendWL() external view returns (bool) {
        return suspendedWL;
    }

    function toggleSuspendWL(bool value) external {
        require(checkApproved(_msgSender(), 13), "You have not been approved to run this function.");
        suspendedWL = value;
    }

    /**********************************************
     **********************************************
                   SPECIAL URI
    **********************************************
    **********************************************/

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(_baseURIExtend);
    }

    function setBaseURI(string memory newUri) external {
        require(checkApproved(_msgSender(), 20), "You have not been approved to run this function.");
        _baseURIExtend = newUri;
    }

    /**********************************************
     **********************************************
                   UTILITY FUNCTIONS
    **********************************************
    **********************************************/

    //Public wrapper of _exists
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    /**********************************************
     **********************************************
                   ERC721 FUNCTIONS
    **********************************************
    **********************************************/

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice ) external view returns ( address receiver, uint256 royaltyAmount) {
        if(exists(_tokenId))
            return(_royaltiesAddress, (_salePrice * _royaltiesBasicPoints)/10000);
        return (address(0), 0);
    }

    function setRoyaltiesAddress(address payable rAddress) external {
        require(rAddress != address(0), "Exception in setRoyaltiesAddress: Address zero.");
        require(checkApproved(_msgSender(), 14), "You have not been approved to run this function.");
        _royaltiesAddress=rAddress;
    }

    function setRoyaltiesBasicPoints(uint96 rBasicPoints) external {
        require(checkApproved(_msgSender(), 15), "You have not been approved to run this function");
        require(rBasicPoints <= maxRoyaltiePoints, "Royaties error: Limit reached");
        _royaltiesBasicPoints=rBasicPoints;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControlEnumerable) returns (bool) {
        if(interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }

        return super.supportsInterface(interfaceId);
    }

    /**
    * Override isApprovedForAll to auto-approve OS's proxy contract
    */
    function isApprovedForAll(address _owner, address _operator) public override(ERC721, IERC721) view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == OpenSeaAddress) {
            return true;
        }

        // otherwise, use the default ERC721.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    /**********************************************
     **********************************************
           ORACULO OBTENER PRECIO EN MATIC
    **********************************************
    **********************************************/

    function decimals() public view returns (uint8) {
        return priceFeed.decimals();
    }

    function priceInMatic() public view returns (uint256) {
        return 1000000000000000000 * priceCapsule * uint256(10 ** uint256(decimals())) / uint256(getLatestPrice());
    }

    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }


    /*****************************************
                MULTI-OWNER SECURITY
    ******************************************/

    function existOwner(address addr) public view returns(bool) {
        return owners[addr];
    }

    function checkApproved(address user, uint8 idFunc) internal returns(bool) {
        require(existOwner(user), "This is not a wallet from a owner");
        bool aprobado = false;
        if(approvedFunction[user].apprFunction == idFunc) {
            aprobado = true;
            clearApprove(user);
        }
        return aprobado;
    }

    function approveOwner(uint8 idFunc, address owner) external {
        require(existOwner(_msgSender()), "You are not owner");
        require(existOwner(owner), "This is not a wallet from a owner");
        require(_msgSender() != owner, "You cannot authorize yourself");
        require(approvedFunction[owner].apprFunction == 0, "There is already a pending authorization for this owner.");
        approvedFunction[owner].apprFunction = idFunc;
        approvedFunction[owner].approveAddress = _msgSender();
    }

    function clearApprove(address owner) public {
        require(existOwner(_msgSender()), "You are not owner");
        require(existOwner(owner), "This is not a wallet from a owner");

        if (_msgSender() != owner) {
            require(approvedFunction[owner].approveAddress == _msgSender(), "You have not given this authorization");
        }

        approvedFunction[owner].apprFunction = 0;
        approvedFunction[owner].approveAddress = address(0);
    }

    /*****************************************
                CONTROL DE OWNERS
    ******************************************/

    function addOwner(address newOwner) external {
        require(checkApproved(_msgSender(), 16), "You have not been approved to run this function");

        owners[newOwner] = true;
        _ownersTracker.increment();
    }

    function delOwner(address addr) external {
        require(checkApproved(_msgSender(), 17), "You have not been approved to run this function");

        owners[addr] = false;
        _ownersTracker.decrement();
        approvedFunction[addr].apprFunction = 0;
        approvedFunction[addr].approveAddress = address(0);
    }

    function getTotalOwners() external view returns(uint){
        return _ownersTracker.current();
    }
}