// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import './NFT_flat.sol';

contract FundFactory {

    address owner;
    address marketPlace;
    address priceFeedAdd;
    address token;
    mapping(uint256 => address) FundList;
    mapping(address => bool) KYCed;
    uint256 public runningCount;

    constructor(address _priceFeed, address _token) {
        owner = msg.sender;
        priceFeedAdd = _priceFeed;
        token = _token;
        KYCed[msg.sender] = true;
    }

    event newProposal(string indexed proposal, uint256 id);
    event newVote(address indexed voter, uint256 indexed id, uint indexed choice);

    

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /*\
    set address of marketplace
    \*/
    function setMarketPlace(address _add) public onlyOwner {
        marketPlace = _add;
    }

    /*\
    transfer ownership of contract
    \*/
    function transferOwnerShip(address _add) public onlyOwner {
        owner = _add;
    }
    

    /*\
    create a new fundpool
    \*/
    function createFundPool(address _token, address _team, uint256 _cap, bool _kyc) public onlyOwner{
        address fundPool = address(new AvanzoNFT(marketPlace, _team, _cap, priceFeedAdd, _token, _kyc));
        FundList[runningCount] = fundPool;
        runningCount++;
    }


    /*\
    get the pool address of pool id
    \*/
    function getAddressOfId(uint256 _id) public view returns(address) {
        return FundList[_id];
    }

    /*\
    get the state of kyc from user
    \*/
    function isKYCed(address _of) external view returns(bool) {
        return KYCed[_of];
    }

    function exists(address _add) external view returns(bool) {
        for(uint i; i < runningCount; i++) {
            if(FundList[i] == _add) {
                return true;
            }
        }
        return false;
    }

    /*\
    toggle KYC of users
    \*/
    function toggleKYC(address[] memory _of) public onlyOwner {
        for(uint i; i < _of.length; i++)
            KYCed[_of[i]] = !KYCed[_of[i]];
    }


    /*\
    get all pool ids that address is invested in
    \*/
    function getInvestedIdsOf(address _add) external view returns(uint256[] memory) {
        uint256 count = 0;
        for(uint256 i; i < runningCount; i++) {
            if(AvanzoNFT(FundList[i]).balanceOf(_add) > 0){
                count++;
            }
        }
        uint[] memory _ids = new uint[](count);
        count = 0;
        for(uint256 i; i < runningCount-1; i++) {
            if(AvanzoNFT(FundList[i]).balanceOf(_add) > 0){
                _ids[count] = i;
                count++;
            }
        }
        return _ids;
    }

    /*\
    turn dead multiple tools at once
    \*/
    function endPoolsOf(uint256[] calldata _poolIds, uint256[] calldata _proposalIds) public  onlyOwner {
        require(_poolIds.length == _proposalIds.length, "You forgot something!");
        for(uint256 i; i < _poolIds.length; i++) {
            AvanzoNFT(getAddressOfId(i)).turnDead(_proposalIds[i]);
        }
    }

    /*\
    distribute rewards for mutliple pools at once
    \*/
    function distributeRewardsOf(uint256[] calldata _ids, uint256[] calldata _amounts, address[] calldata _tokens) public {
        require(_ids.length == _amounts.length, "You forgot something!");
        require(_ids.length == _tokens.length, "You forgot something!");
        require(_amounts.length == _tokens.length, "You forgot something!");
        for(uint256 i; i < _ids.length; i++) {
            IERC20(_tokens[i]).approve(getAddressOfId(_ids[i]), _amounts[i]);
            AvanzoNFT(getAddressOfId(_ids[i])).distributeRewards(_amounts[i], IERC20(_tokens[i]));
        }
    } 
}
