/*
 _______       ___      .______       __  ___       _______      ___      .______      .___________. __    __
|       \     /   \     |   _  \     |  |/  /      |   ____|    /   \     |   _  \     |           ||  |  |  |
|  .--.  |   /  ^  \    |  |_)  |    |  '  /       |  |__      /  ^  \    |  |_)  |    `---|  |----`|  |__|  |
|  |  |  |  /  /_\  \   |      /     |    <        |   __|    /  /_\  \   |      /         |  |     |   __   |
|  '--'  | /  _____  \  |  |\  \----.|  .  \       |  |____  /  _____  \  |  |\  \----.    |  |     |  |  |  |
|_______/ /__/     \__\ | _| `._____||__|\__\      |_______|/__/     \__\ | _| `._____|    |__|     |__|  |__|

                                WWW.DARKEARTH.GG by Olympus Origin.
                        Coded by Jesús Sánchez Fernández & Juan Palomo Cisneros
*/

//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

// Smart Contracts imports
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DECollection is ERC721Enumerable, AccessControlEnumerable {

    using Strings for uint256;
    using Counters for Counters.Counter;
    /**********************************************
     **********************************************
                       VARIABLES
    **********************************************
    **********************************************/

    // Variables de suspensión de funcionalidades
    bool private suspended = false; // Suspender funciones generales del SC

    // Wallet para comprobar la firma
    address private signAddr;

    string private _baseURIExtend;

    Counters.Counter private _tokenIdTracker;

    //Adds support for OpenSea
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    address private OpenSeaAddress = 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE;

    //Roles of minter and burner
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //Royaties address and amnount
    address payable private _royaltiesAddress;
    uint96 private _royaltiesBasicPoints;
    uint96 private maxRoyaltiePoints = 1500;

    // --> Control del Supply

    struct nftSup {
        uint256 sMax;
        Counters.Counter sNow;
        Counters.Counter burned;
    }

    // Mapeo tipo -> Supply
    mapping(uint256 => nftSup) private nftSupply;

    // --> Control tokenId + INFO
    struct nftInfo {
        uint256 tipo;
        uint256 serialNumber;
        bool usado;
    }

    mapping(uint256 => nftInfo) private tokenInfo;

    // Controlar la TX que ya se han registrado
    mapping(string => bool) private txRewarded;

    // Security - MultiOwner
    struct approveMap {
        address approveAddress;
        uint8 apprFunction;
    }

    mapping(address => bool) private owners;
    mapping(address => approveMap) private approvedFunction;
    Counters.Counter private _ownersTracker;

    // Burned control
    mapping(address => uint256[]) private burnedCards;

    /**********************************************
     **********************************************
                    CONSTRUCTOR
    **********************************************
    **********************************************/
    constructor() ERC721("Dark Earth Collection", "DEC") {

        // URI por defecto
        _baseURIExtend = "https://nft-hub.darkearth.gg/cards/";

        // Dirección que comprueba la firma
        signAddr = _msgSender();

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

    /**********************************************
     **********************************************
                    ERC721 STANDARD
    **********************************************
    **********************************************/

    receive() external payable {}

    function withdraw(uint amount) external {
        require(checkApproved(_msgSender(), 5), "You do not have permissions");
        payable(_msgSender()).transfer(amount);
    }

    /**********************************************
     **********************************************
                BATCH TRANSFERENCIAS
    **********************************************
    **********************************************/

    function bulkSafeTransfer(address _from, address _to, uint256[] calldata tokenIds) external {
        for (uint256 index = 0; index < tokenIds.length; index++) {
            safeTransferFrom(_from, _to, tokenIds[index]);
        }
    }

    /**********************************************
     **********************************************
                    ROLES SYSTEM
    **********************************************
    **********************************************/

    function addRole(address _to, bytes32 rol, bool grant) external {
        require(checkApproved(_msgSender(), 3), "You have not been approved to run this function");

        if(grant) {
            _grantRole(rol, _to);
        } else {
            _revokeRole(rol, _to);
        }
    }

    /**********************************************
     **********************************************
                    SUPPLY SYSTEM
    **********************************************
    **********************************************/

    // Añadir supply masivo
    function addBulkSupply(uint[] calldata tipos, uint[] calldata amount) external {
        require(checkApproved(_msgSender(), 1), "You do not have permissions");
        require(tipos.length == amount.length, "Array sizes do not match");

        for(uint i = 0; i < tipos.length; i++) {
            nftSupply[tipos[i]].sMax = amount[i];
        }
    }

    function getMaxSupply(uint tipo) external view returns(uint) {
        return nftSupply[tipo].sMax;
    }

    function getNowSupply(uint tipo) external view returns(uint) {
        return nftSupply[tipo].sNow.current();
    }

    function getBurnedAmount(uint tipo) external view returns(uint) {
        return nftSupply[tipo].burned.current();
    }

    function getCirculatingSupply(uint tipo) public view returns(uint256) {
        return nftSupply[tipo].sNow.current() - nftSupply[tipo].burned.current();
    }

    function getDilutedMaxSupply(uint tipo) public view returns(uint256) {
        return nftSupply[tipo].sMax - nftSupply[tipo].burned.current();
    }

    // Comprobar el Supply de cada carta
    function checkSupply(uint tipo) internal view returns (bool) {

        bool respuesta = false;

        if(nftSupply[tipo].sNow.current() < nftSupply[tipo].sMax) {
            respuesta = true;
        }

        return respuesta;
    }

    /**********************************************
     **********************************************
                        BURNER
    **********************************************
    **********************************************/

    function burn(uint256 tokenId) public virtual {
        require(!suspended, "The contract is temporaly suspended.");
        require(ownerOf(tokenId) == _msgSender(), "Exception on Burn: Your are not the owner");

        uint tipo = getTokenType(tokenId);
        nftSupply[tipo].burned.increment();

        burnedCards[ownerOf(tokenId)].push(tokenId);

        _burn(tokenId);
    }

    function bulkBurn(uint256[] calldata tokenIds) external {
        for(uint i = 0; i < tokenIds.length; i++){
            burn(tokenIds[i]);
        }
    }

    function bulkAdminBurn(uint256[] calldata tokenIds) external {
        require(!suspended, "The contract is temporaly suspended");
        require(hasRole(BURNER_ROLE, _msgSender()), "Exception on Burn: You do not have permission");

        for(uint i = 0; i < tokenIds.length; i++){
            uint tipo = getTokenType(tokenIds[i]);
            nftSupply[tipo].burned.increment();
            burnedCards[ownerOf(tokenIds[i])].push(tokenIds[i]);
            _burn(tokenIds[i]);
        }
    }

    function getBurnedCardsByWallet(address wallet) external view returns(uint256[] memory) {
        return burnedCards[wallet];
    }

    function getBurnedLengthCardsByWallet(address wallet) external view returns(uint256) {
        return burnedCards[wallet].length;
    }

    /**********************************************
     **********************************************
                    MINTER
              SETTERS AND GETTERS
    **********************************************
    **********************************************/
    function mintCards(uint[] calldata cardsIds, string[] calldata txIds, bytes calldata firma) external {
        require(!suspended, "The contract is temporaly suspended.");
        require(isSigValid(generaMensaje(cardsIds, txIds), firma), "SIGNATURE ERROR: What are you trying to do?");
        require(!checkTx(txIds), "ERROR: This transaction is already in our system.");

        for(uint i = 0; i < cardsIds.length; i++) {
            require(checkSupply(cardsIds[i]), "SUPPLY ERROR: Not enough of this type.");
            mint(_msgSender(), cardsIds[i]);
        }
    }

    function adminMint(address _to, uint[] calldata cardsIds) external {
        require(!suspended, "The contract is temporaly suspended.");
        require(hasRole(MINTER_ROLE, _msgSender()), "You dont have Minter role! Sorry");

        for(uint i = 0; i < cardsIds.length; i++) {
            require(checkSupply(cardsIds[i]), "SUPPLY ERROR: Not enough of this type.");
            mint(_to, cardsIds[i]);
        }
    }

    function mint(address _to, uint _tipo) internal {
        // Aumento el Supply Actual de ese tipo
        nftSupply[_tipo].sNow.increment();

        // Aumento el contador
        _tokenIdTracker.increment();

        // Guardo ID del token -> Tipo
        tokenInfo[_tokenIdTracker.current()].serialNumber = nftSupply[_tipo].sNow.current();
        tokenInfo[_tokenIdTracker.current()].tipo = _tipo;
        tokenInfo[_tokenIdTracker.current()].usado = false;

        // Minteo la carta
        _safeMint(_to, _tokenIdTracker.current());
    }

    /**********************************************
     **********************************************
                  SIGN SECURITY
    **********************************************
    **********************************************/

    // Genera el mensaje para poder verificar la firma
    function generaMensaje(uint[] memory cardsIds, string[] memory txIds) internal pure returns (string memory) {

        string memory mensaje;
        string memory aux;

        for(uint i = 0; i < cardsIds.length;i++){
            aux = string(abi.encodePacked(Strings.toString(cardsIds[i]),","));
            mensaje = string(abi.encodePacked(mensaje, aux));
        }

        for(uint j = 0; j < txIds.length; j++) {
            if(j == txIds.length-1) {
                mensaje = string(abi.encodePacked(mensaje, txIds[j]));
            } else {
                aux = string(abi.encodePacked(txIds[j],","));
                mensaje = string(abi.encodePacked(mensaje, aux));
            }
        }

        return mensaje;
    }

    // Comprobar firma
    function isSigValid (string memory message, bytes memory signature) internal view returns(bool) {
        return signAddr == ECDSA.recover(
            keccak256(abi.encodePacked(message)),
            signature
        );
    }

    function setSignAddr(address newSignAddr) external {
        require(newSignAddr != address(0), "Exception in setSignAddr: Address zero.");
        require(checkApproved(_msgSender(), 2), "You have not been approved to run this function.");
        signAddr = newSignAddr;
    }

    // Comprueba que la transacción no esté en el sistema
    // Si no la está añade
    function checkTx(string[] memory txIds) internal returns(bool) {
        require(txIds.length > 0, "Exception in checkTx: There are not Tx Ids to check");
        bool respuesta = false;
        uint i = 0;

        while(!respuesta && i < txIds.length) {
            if(txRewarded[txIds[i]]) {
                respuesta = true;
            } else {
                txRewarded[txIds[i]] = true;
            }
            i += 1;
        }

        return respuesta;
    }

    /**********************************************
     **********************************************
                     REWARDS ZONE
    **********************************************
    **********************************************/

    function bulkSetUsedCard(uint256[] calldata tokenIds) external {
        require(tokenIds.length >0, "Exception in bulkSetUsedCard: Array has not Data");

        for(uint i = 0; i < tokenIds.length; i++) {
            require(_msgSender() == ownerOf(tokenIds[i]), "You do not have this NFT");
            require(exists(tokenIds[i]), "This token not exist");

            tokenInfo[tokenIds[i]].usado = true;
        }
    }

    function bulkAdminUsedCard(uint256[] calldata tokenIds, bool[] calldata toggle) external {
        require(tokenIds.length == toggle.length, "Exception in bulkAdminUsedCard: Array sizes");
        require(checkApproved(_msgSender(), 4), "You have not been approved to run this function");

        for(uint i = 0; i < tokenIds.length; i++) {
            require(exists(tokenIds[i]), "This token not exist");

            tokenInfo[tokenIds[i]].usado = toggle[i];
        }
    }

    /**********************************************
     **********************************************
                GETTERS NFTs POR TIPO
    **********************************************
    **********************************************/

    function isTxOnSystem(string memory txId) external view returns(bool) {
        return txRewarded[txId];
    }

    function getTokenInfo(uint256 tokenId) external view returns (uint256 typeNft, bool used) {
        require(exists(tokenId), "This token does not exist.");
        return (tokenInfo[tokenId].tipo, tokenInfo[tokenId].usado);
    }

    function getTokenSerial(uint256 tokenId) external view returns (string memory) {
        require(exists(tokenId), "This token does not exist.");

        uint tipo = getTokenType(tokenId);
        string memory nSerie = (tokenInfo[tokenId].serialNumber).toString();
        string memory nMax = (nftSupply[tipo].sMax).toString();

        string memory serial = string(abi.encodePacked(nSerie, "/", nMax));
        return serial;
    }

    function getTokenIds(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i = 0; i < ownerTokenCount; i++)
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);

        return tokenIds;
    }

    function getTokenNotUsedIds(address _owner) external view returns (uint256[] memory) {

        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);

        uint256 aux;
        uint256 contador = 0;

        for (uint256 i = 0; i < ownerTokenCount; i++) {

            aux = tokenOfOwnerByIndex(_owner, i);

            if(!tokenInfo[aux].usado) {
                tokenIds[contador] = aux;
                contador += 1;
            }

        }

        return clearArray(tokenIds, contador);
    }

    function getTokenType(uint256 tokenId) public view returns (uint256) {
        require(exists(tokenId), "That token does not exist.");
        return tokenInfo[tokenId].tipo;
    }

    function getTokenTypeCount(address _owner, uint256 tipo) public view returns (uint256) {

        uint256[] memory tokenIds = getTokenIds(_owner);
        uint256 contador = 0;
        uint256 aux;

        for(uint i = 0; i < tokenIds.length; i++) {
            aux = tokenIds[i];
            if(tokenInfo[aux].tipo == tipo)
                 contador += 1;
        }

        return contador;
    }

    function getTokenByType(address _owner, uint256 tipo) external view returns (uint256[] memory) {

        uint256[] memory tokens = getTokenIds(_owner);
        uint256[] memory tokensIds = new uint256[](tokens.length);

        uint8 k = 0;

        for(uint i = 0; i < tokens.length; i++){
            if(tokenInfo[tokens[i]].tipo == tipo) {
                tokensIds[k] = tokens[i];
                k += 1;
            }
        }

        require(k > 0, "ERROR: You dont have NFTs of this type.");
        return clearArray(tokensIds, k);
    }

    function clearArray(uint256[] memory array, uint256 size) internal pure returns(uint256[] memory) {
        uint256[] memory result = new uint[](size);
        for(uint256 i = 0; i < size; i++){
            result[i] = array[i];
        }
        return result;
    }

    /**********************************************
     **********************************************
                  GETTERs Y SETTERs
    **********************************************
    **********************************************/

    // Suspender funcionalidades general del SC
    function isSuspend() external view returns (bool) {
        return suspended;
    }

    function toggleSuspend(bool value) external {
        require(checkApproved(_msgSender(), 7), "You have not been approved to run this function.");
        suspended = value;
    }

    /**********************************************
     **********************************************
                   SPECIAL URI
    **********************************************
    **********************************************/

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIExtend;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenType = tokenInfo[tokenId].tipo.toString();
        string memory _base = _baseURI();

        string memory _msgUri;

        if(tokenInfo[tokenId].usado) {
            _msgUri = string(abi.encodePacked(_tokenType, "-used"));
        } else {
            _msgUri = string(_tokenType);
        }

        return string(abi.encodePacked(_base, _msgUri, ".json"));
    }

    function setBaseURI(string memory newUri) external {
        require(checkApproved(_msgSender(), 8), "You have not been approved to run this function.");
        _baseURIExtend = newUri;
    }

    /**********************************************
     **********************************************
                   ROYALTIES & OPENSEA
    **********************************************
    **********************************************/

    //Public wrapper of _exists
    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice ) external view returns (address receiver, uint256 royaltyAmount) {
        if(exists(_tokenId))
            return(_royaltiesAddress, (_salePrice * _royaltiesBasicPoints)/10000);
        return (address(0), 0);
    }

    function setRoyaltiesAddress(address payable rAddress) external {
        require(rAddress != address(0), "Exception in setRoyaltiesAddress: Address zero.");
        require(checkApproved(_msgSender(), 9), "You have not been approved to run this function");
        _royaltiesAddress=rAddress;
    }

    function setRoyaltiesBasicPoints(uint96 rBasicPoints) external {
        require(checkApproved(_msgSender(), 10), "You have not been approved to run this function");
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
    **/
    function isApprovedForAll(address _owner, address _operator) public override(ERC721, IERC721) view returns (bool isOperator) {
      // if OpenSea's ERC721 Proxy Address is detected, auto-return true
        if (_operator == OpenSeaAddress) {
            return true;
        }

        // otherwise, use the default ERC721.isApprovedForAll()
        return super.isApprovedForAll(_owner, _operator);
    }

    function setOpenSeaAddress(address newAdd) external {
        require(newAdd != address(0), "Exception in setOpenSeaAddress: Address zero.");
        require(checkApproved(_msgSender(), 11), "You have not been approved to run this function.");
        OpenSeaAddress = newAdd;
    }

    function getOpenSeaAddress() external view returns (address) {
        return OpenSeaAddress;
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
        require(checkApproved(_msgSender(), 12), "You have not been approved to run this function");

        owners[newOwner] = true;
        _ownersTracker.increment();
    }

    function delOwner(address addr) external {
        require(checkApproved(_msgSender(), 6), "You have not been approved to run this function");

        owners[addr] = false;
        _ownersTracker.decrement();
        approvedFunction[addr].apprFunction = 0;
        approvedFunction[addr].approveAddress = address(0);
    }

    function getTotalOwners() external view returns(uint){
        return _ownersTracker.current();
    }
}