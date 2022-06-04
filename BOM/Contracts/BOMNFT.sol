// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IERC20.sol";

interface LPPrice {
    function getCurrentPrice(address _lppairaddress) external view returns(uint256);
    function getLatestPrice(address _lppairaddress) external view returns(uint256);
    function updatePriceFromLP(address _lppairaddress) external returns(uint256);
    function getDecVal() external view returns(uint256);
}

contract BlackList is Ownable {

    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded BOM) ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    mapping (address => bool) public isBlackListed;

    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    event DestroyedBlackFunds(address _blackListedUser, uint _balance);

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

}

contract BOMNFT is ERC721URIStorage, Ownable, BlackList {
    using Strings for uint256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    IERC20 public busd;
    IERC20 public usdt;
    IERC20 public usdc;
    IERC20 public matic;

    LPPrice public lpinfo;
    address public lpAddress = address(0); // Address of Matic & USD LP

    address public withdrawAddress;
    string public baseURI;
    uint8 public _decimals = 10;
    uint256 public usdCost = 300 * 10 ** _decimals;
    uint256 public maxSupply = 20000;
    uint256 public allowedSupply = 0;
    bool public paused = false;
    uint256 public supply = 0;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        IERC20 _matic,
        IERC20 _busd,
        IERC20 _usdt,
        IERC20 _usdc
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        matic = _matic;
        busd = _busd;
        usdt = _usdt;
        usdc = _usdc;
    }

    event UpdateAllowedSupply(uint256 _allowedSupply);

    //internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function getBaseURI() external view returns(string memory) {
        return _baseURI();
    }

    function setLPpairaddress(address _address) external onlyOwner {
        lpAddress = _address;
    }

    function setLPPriceInfo(address _address) external onlyOwner {
        require(_address != address(0), "Cannot be zero address");
        lpinfo = LPPrice(_address);
    }

    function getNFTMaticPrice(uint _count) public view returns(uint){
        return usdCost * 10 ** matic.decimals() * lpinfo.getDecVal() / lpinfo.getLatestPrice(lpAddress) / 10 ** _decimals .mul(_count);
    }

    //public
    function mint(string memory _tokenURI, uint id) public payable returns(uint tokenID) {
        return mintNFTs(1, _tokenURI, id, 0, "");
    }

    function mintNFTs(uint256 _count, string memory _tokenFolderURI, uint id, uint _mode, string memory _ext) public payable returns(uint startingTokenID){
        // _mode=0 means normal mint, _mode != 0 means advanced mint
        // _ext is the metadata extension when using advanced mint
        require(!paused);
        require(supply + _count <= allowedSupply);

        if (msg.sender == owner()) {}
        else if (id == 0) {
            lpinfo.updatePriceFromLP(lpAddress);
            uint nMaticCost = getNFTMaticPrice(_count);
            require(msg.value >= nMaticCost, "Matic not enough");
            if (msg.value > nMaticCost) {
                payable(msg.sender).transfer(msg.value - nMaticCost);
            }
        }
        else {
            require(withdrawAddress != address(0));
            if      (id == 1) busd.transferFrom(msg.sender, withdrawAddress, usdCost * 10 ** busd.decimals() / 10 ** _decimals);
            else if (id == 2) usdt.transferFrom(msg.sender, withdrawAddress, usdCost * 10 ** usdt.decimals() / 10 ** _decimals);
            else if (id == 3) usdc.transferFrom(msg.sender, withdrawAddress, usdCost * 10 ** usdc.decimals() / 10 ** _decimals);
        }

        uint _tokenID;
        for(uint _index = 1; _index <= _count; _index++) {
            supply++;
            _tokenID = supply;
            _mint(msg.sender, _tokenID);
            if(_mode == 0) _setTokenURI(_tokenID, _tokenFolderURI);
            else _setTokenURI(_tokenID, string(abi.encodePacked(_tokenFolderURI, "/", Strings.toString(_index), _ext)));
        }
        return _tokenID + 1 - _count;
    }

    function _beforeTokenTransfer(address from, address, uint256) internal override view{
        // Check if the sender is blacklisted
        require(!isBlackListed[from]);
    }

    function setUsdCost(uint256 _newUsdCost) public onlyOwner {
        usdCost = _newUsdCost;
    }

    function setMaxSupply(uint256 _newMaxSupply) public onlyOwner {
        maxSupply = _newMaxSupply;
    }

    function addAllowedSupply(uint256 _addAllowedSpply) public onlyOwner {
        require(allowedSupply + _addAllowedSpply <= maxSupply);
        allowedSupply += _addAllowedSpply;
        emit UpdateAllowedSupply(allowedSupply);
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setTokenURI(uint256 tokenID, string memory _tokenURI) public {
        require(msg.sender == ownerOf(tokenID));
        _setTokenURI(tokenID, _tokenURI);
    }

    function totalSupply() public view returns(uint) {
        return supply;
    }

    function withdraw() external payable onlyOwner {
        require(withdrawAddress != address(0));
        payable(withdrawAddress).transfer(address(this).balance);
    }

    function setwithdrawAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0));
        withdrawAddress = _newAddress;
    }

    function checkIfExistsTokenID(uint256 _tokenID) external view returns(bool) {
        return _exists(_tokenID);
    }
}