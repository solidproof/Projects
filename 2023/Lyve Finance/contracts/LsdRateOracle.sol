pragma solidity ^0.8.13;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ILsdRateOracle} from "./interfaces/ILsdRateOracle.sol";


contract LsdRateOracle is ILsdRateOracle ,ReentrancyGuard{
    
    address public lsdToken;
    uint256 public rate;
    address public governor;
    mapping (address => bool) public rateManager;
    constructor(address _lsdToken,address _governor) {
        require(_lsdToken != address(0),"null address");
        require(_governor != address(0),"null address");
        lsdToken = _lsdToken;
        governor = _governor;
        rateManager[_governor] = true;
    }
  
   function setRateManager(address _rateManager)  external{
        require(msg.sender == governor,"not governor");
        rateManager[_rateManager] = true;
    }
     function removeRateManager(address _rateManager)  external{
        require(msg.sender == governor,"not governor");
        delete rateManager[_rateManager];
    }
    function getLsdRate()  external view returns(uint256){
        return rate;
    }
    function setLsdRate(uint256 _rate) external nonReentrant {
        require(rateManager[msg.sender],"only rateManager" );
        require(_rate >= 1e18,"wrong _rate" );
        require(_rate > rate,"wrong _rate" );
         rate = _rate;
        emit LsdRateSeted(lsdToken,_rate);
    }

    
}
