// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";


contract ZoomToken is ERC20, ERC20Burnable, Pausable, Ownable, ERC20Permit {
    constructor() ERC20("ZoomToken", "ZOOM") ERC20Permit("ZoomToken") {
        //Mint Liquidity provider tokens
        _mint(msg.sender, 84000000000e18); // 540 Bil Zoom
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    address public zoombiesContract;
    uint16 public totalContributors = 0; //LIVE
    uint256 public totalZoomPurchased = 0;
    bool public isTGE = true;

    event TGEClosed (bool isTGEClosed);
    event contractAuthorized(address newZoombiesService, bool isApproved);
    event zoomContribution(address contributor, uint256 ZoomScore,uint256 amount);
    event zoomScoreUpdated(address owner, uint256 newZoomScore, uint256 amount);
    event zoomBurned(address owner, uint256 totalZoomBurned, uint256 amount);

    //Storage
    //supporters
    mapping (address => uint256) public contributions;      // GLMR contributed per address
    mapping (address => uint256) public zoomScore;          // Total count of ZOOM acquired
    mapping (address => uint256) public totalZoomBurned;    // Total ZOOM sacrificed
    mapping (address => bool) public authorizedContracts;   // external Zoombies contracts to manage Mint/Burn

    function endTGE() external onlyOwner returns(bool) {
        if(isTGE == true){
            isTGE = false;
            emit TGEClosed(true);
            return true;
        }
        return false;
    }

    function setAuthorizedContract(address _newZoombiesService, bool _isAuthorized) external onlyOwner {
        require(_newZoombiesService != address(0x0));
        authorizedContracts[_newZoombiesService] = _isAuthorized;
        emit contractAuthorized(_newZoombiesService, _isAuthorized);
    }

    //Available only during TGE
    function buy() external payable {
        if(isTGE == false){
            revert();
        }

        require(msg.value >= 1000000000000000000, "Min. is 1 GLMR");

      //All clear ?
        if (contributions[_msgSender()] == 0) {
            totalContributors = totalContributors + 1;
        }

        //track total contributions per wallet
        contributions[_msgSender()] += msg.value;
        totalZoomPurchased += convertWeiToZoom(msg.value);

        zoomScore[_msgSender()] += convertWeiToZoom(msg.value);
        _mint(_msgSender(), convertWeiToZoom(msg.value));
        emit zoomContribution(_msgSender(), zoomScore[_msgSender()], convertWeiToZoom(msg.value));
    }

    /**
     *  Called in from our Authorized ERC721 contract services actions
     */
    function awardZoom(address _to, uint256 _amount) external  {
        require(authorizedContracts[_msgSender()] == true);
        require(_to != address(0));
        require(_amount > 0);

        zoomScore[_to] += _amount;
        _mint(_to, _amount);
        emit zoomScoreUpdated(_to, zoomScore[_to], _amount);
    }

    /**
     *  Called in from our Authorized ERC721 contract services actions
     */
    function burnZoom(address _wallet, uint256 _amount) external {
        require(authorizedContracts[_msgSender()] == true);
        require(_wallet != address(0));
        require(_amount > 0);
        
        totalZoomBurned[_wallet] += _amount;
        _burn(_wallet, _amount);
        emit zoomBurned(_wallet, totalZoomBurned[_wallet], _amount);
    }

   /**
    * Withdraw balance to wallet
    */
    function withdraw() external onlyOwner returns(bool) {
        payable(owner()).transfer(address(this).balance);
        return true;
    }

/* INTERNAL */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

     /**
      * Our base conversion rate for the TGE
      */
    function convertWeiToZoom(uint weiToConvert) internal pure returns (uint) {
          // 1 ZOOM = 10000000000000 wei;
        return (weiToConvert/10000000000000) * 1e18;
    }
}
