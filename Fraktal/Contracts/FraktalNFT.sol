//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "./PaymentSplitterUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract FraktalNFT is ERC1155Upgradeable,ERC721HolderUpgradeable,ERC1155HolderUpgradeable{
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableMap for EnumerableMap.UintToAddressMap;
  address revenueChannelImplementation;
  bool fraktionalized;
  bool public sold;
  uint256 public fraktionsIndex;
  uint16 public majority;
  mapping(uint256 => bool) indexUsed;
  mapping(uint256 => mapping(address => uint256)) public lockedShares;
  mapping(uint256 => mapping(address => uint256)) public lockedToTotal;
  EnumerableSet.AddressSet private holders;
  EnumerableMap.UintToAddressMap private revenues;
  string public name = "FraktalNFT";
  string public symbol = "FRAK";
  address public factory;
  address collateral;

  event LockedSharesForTransfer(
    address shareOwner,
    address to,
    uint256 numShares
  );
  event unLockedSharesForTransfer(
    address shareOwner,
    address to,
    uint256 numShares
  );
  event ItemSold(address buyer, uint256 indexUsed);
  event NewRevenueAdded(
    address payer,
    address revenueChannel,
    uint256 amount,
    bool sold
  );
  event Fraktionalized(address holder, address minter, uint256 index);
  event Defraktionalized(address holder, uint256 index);
  event MajorityValueChanged(uint16 newValue);

  // constructor() initializer {}

  function init(
    address _creator,
    address _revenueChannelImplementation,
    string calldata uri,
    uint16 _majority,
    string memory _name,
    string memory _symbol
  ) external initializer {
    __ERC1155_init(uri);
    _mint(_creator, 0, 1, "");
    fraktionalized = false;
    sold = false;
    majority = _majority;
    revenueChannelImplementation = _revenueChannelImplementation;
    holders.add(_creator);
    if(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("")) && 
    keccak256(abi.encodePacked(_symbol)) != keccak256(abi.encodePacked(""))
    ){
      name = _name;
      symbol = _symbol;
    }
    factory = msg.sender;//factory as msg.sender
  }

  // User Functions
  ///////////////////////////
  function fraktionalize(address _to, uint256 _tokenId) external {
    require((_tokenId != 0) && 
    (this.balanceOf(_msgSender(), 0) == 1) && 
    !fraktionalized && 
    (indexUsed[_tokenId] == false)
    );
    // require(this.balanceOf(_msgSender(), 0) == 1);
    // require(fraktionalized == false);
    // require(indexUsed[_tokenId] == false);
    fraktionalized = true;
    sold = false;
    fraktionsIndex = _tokenId;
    _mint(_to, _tokenId, 10000*10**18, "");
    emit Fraktionalized(_msgSender(), _to, _tokenId);
  }

  function defraktionalize() external {
    fraktionalized = false;
    _burn(_msgSender(), fraktionsIndex, 10000*10**18);
    emit Defraktionalized(_msgSender(), fraktionsIndex);
  }

  function setMajority(uint16 newValue) external {
    require((this.balanceOf(_msgSender(), 0) == 1)&&
    (newValue <= 10000*10**18)
    );
    // require(newValue <= 10000*10**18);
    // require(newValue > 0);
    majority = newValue;
    emit MajorityValueChanged(newValue);
  }

  function soldBurn(
    address owner,
    uint256 _tokenId,
    uint256 bal
  ) external {
    // if (_msgSender() != owner) {
    //   require(isApprovedForAll(owner, _msgSender()));
    // }
    _burn(owner, _tokenId, bal);
  }

  function lockSharesTransfer(
    address from,
    uint256 numShares,
    address _to
  ) external {
    if (from != _msgSender()) {
      require(isApprovedForAll(from, _msgSender()));
    }
    require(
      balanceOf(from, fraktionsIndex) - lockedShares[fraktionsIndex][from] >=
        numShares
    );
    lockedShares[fraktionsIndex][from] += numShares;
    lockedToTotal[fraktionsIndex][_to] += numShares;
    emit LockedSharesForTransfer(from, _to, numShares);
  }

  function unlockSharesTransfer(address from, address _to) external {
    require(!sold);
    if (from != _msgSender()) {
      require(isApprovedForAll(from, _msgSender()));
    }
    uint256 balance = lockedShares[fraktionsIndex][from];
    lockedShares[fraktionsIndex][from] -= balance;
    lockedToTotal[fraktionsIndex][_to] -= balance;
    emit unLockedSharesForTransfer(from, _to, 0);
  }

  function createRevenuePayment(address _marketAddress) external payable returns (address _clone) {
    cleanUpHolders();
    address[] memory owners = holders.values();
    uint256 listLength = holders.length();
    uint256[] memory fraktions = new uint256[](listLength);
    for (uint256 i = 0; i < listLength; i++) {
      fraktions[i] = this.balanceOf(owners[i], fraktionsIndex);
    }
    _clone = ClonesUpgradeable.clone(revenueChannelImplementation);
    address payable revenueContract = payable(_clone);
    PaymentSplitterUpgradeable(revenueContract).init(owners, fraktions, _marketAddress);
    uint256 bufferedValue = msg.value;
    AddressUpgradeable.sendValue(revenueContract, bufferedValue);
    uint256 index = revenues.length();
    revenues.set(index, _clone);
    emit NewRevenueAdded(_msgSender(), revenueContract, msg.value, sold);
  }

  function sellItem() external payable {
    require(this.balanceOf(_msgSender(), 0) == 1);
    sold = true;
    fraktionalized = false;
    indexUsed[fraktionsIndex] = true;
    emit ItemSold(_msgSender(), fraktionsIndex);
  }

  function cleanUpHolders() internal {
    uint256 listLength = holders.length();
    address[] memory remove = new address[](listLength);
    uint16 removeIndex = 0;
    for (uint256 i = 0; i < listLength; i++) {
      // uint256 bal = this.balanceOf(holders.at(i), fraktionsIndex);
      if (this.balanceOf(holders.at(i), fraktionsIndex) < 1) {
        remove[removeIndex] = holders.at(i);
        removeIndex++;
      }
    }
    for (uint256 i = 0; i < removeIndex; i++) {
      holders.remove(remove[i]);
    }
  }

  // Overrided functions
  ////////////////////////////////
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory tokenId,
    uint256[] memory amount,
    bytes memory data
  ) internal virtual override {
    super._beforeTokenTransfer(operator, from, to, tokenId, amount, data);
    if (from != address(0) && to != address(0)) {
      if (tokenId[0] == 0) {
        if (fraktionalized == true && sold == false) {
          require((lockedToTotal[fraktionsIndex][to] > 9999));
        }
      } else {
        require(sold != true);
        require(
          (balanceOf(from, tokenId[0]) - lockedShares[fraktionsIndex][from] >=
            amount[0])
        );
      }
      holders.add(to);
    }
  }

  // Getters
  ///////////////////////////
  // function getRevenue(uint256 index) external view returns (address) {
  //   return revenues.get(index);
  // }

  // function getFraktions(address who) external view returns (uint256) {
  //   return this.balanceOf(who, fraktionsIndex);
  // }

  // function getLockedShares(uint256 index, address who)
  //   external
  //   view
  //   returns (uint256)
  // {
  //   return lockedShares[index][who];
  // }

  // function getLockedToTotal(uint256 index, address who)
  //   external
  //   view
  //   returns (uint256)
  // {
  //   return lockedToTotal[index][who];
  // }
  /**
  *@notice transfer contained ERC721 to the Fraktal owner with given address and index
  *@param contractAddress address of ERC721 contained
  *@param index index of the ERC721
   */
  //todo: Should block if collateral is being claimed
  function claimContainedERC721(address contractAddress, uint256 index) external{
    if(msg.sender != factory){
      require(contractAddress != collateral);
    }
    require((this.balanceOf(msg.sender, 0) == 1) && !fraktionalized && (IERC721(contractAddress).ownerOf(index) == address(this)));
    // require(fraktionalized==false);
    // require(IERC721(contractAddress).ownerOf(index) == address(this));
    IERC721(contractAddress).safeTransferFrom(address(this), msg.sender, index);
  }

  /**
  *@notice transfer contained ERC1155 to the Fraktal owner with given address and index
  *@param contractAddress address of ERC1155 contained
  *@param index index of the ERC1155
   */
  //todo: Should block if collateral is being claimed
  function claimContainedERC1155(address contractAddress, uint256 index, uint256 amount) external{
    if(msg.sender != factory){
      require(contractAddress != collateral);
    }
    require((this.balanceOf(msg.sender, 0) == 1) && !fraktionalized);
    IERC1155(contractAddress).safeTransferFrom(address(this), msg.sender, index, amount,"");
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155Upgradeable, ERC1155ReceiverUpgradeable) returns (bool) {
        return ERC1155Upgradeable.supportsInterface(interfaceId) || ERC1155ReceiverUpgradeable.supportsInterface(interfaceId);
  }

  function setCollateral(address _collateral ) external{
    require(msg.sender == factory);
    collateral = _collateral;
  }

  // function getStatus() external view returns (bool) {
  //   return sold;
  // }

  // function getFraktionsIndex() external view returns (uint256) {
  //   return fraktionsIndex;
  // }
}
