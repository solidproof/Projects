// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import '@openzeppelin/contracts/access/Ownable.sol';
import "../token/WonkaCapital.sol";
/* 
interface WonkaCapital {
	function getVestingFee(address addr) external view returns (uint256);
	function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
	function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);
    function getPair(address tokenA, address tokenB) external view returns (address lpPair);
    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
} */

/*
* @title WonkaExchange
*
* @author Wonka
*/
contract WonkaExchange is Ownable {
  
    address public signerPublicAddress;
    address public otcSaleAddress	=	0xE2B2db935055954b0Bb0eb5F001928E83c7a8ed4;
    address public wonkaAddress;
    IRouter01 public dexRouter;
	WonkaCapital private wonkacapital;
	
	mapping(uint256 => bool) private _isNonceUsed;

    /**
    * @notice Constructor to create WonkaExchange contract
    *
    */
    constructor (
        address _signerPublicAddress,
        address _wonkaAddress,
		address _routerAddress
    ){
        signerPublicAddress = _signerPublicAddress;
        wonkaAddress = _wonkaAddress;
		dexRouter = IRouter01(_routerAddress);
		wonkacapital 	= WonkaCapital(wonkaAddress);
    }

    /**
    * @notice Check if address is allowed
    *
    */
    function isAllowed(uint256 amount, uint256 percentage, uint256 nonce, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        
		require(!_isNonceUsed[nonce], "Invalid nonce");
		
		if (_validateSignature(keccak256(abi.encodePacked(_msgSender(),amount,percentage,nonce,address(this))), v, r, s)){
            return true;
        }
        return false;
    }

    /**
    * @notice Token Transfer
    // */
    function tokenTransfer(uint256 percentage, uint256 nonce, uint8 v, bytes32 r, bytes32 s) external payable returns (uint256){

        uint256 amount						=	msg.value;
        require(isAllowed(amount, percentage, nonce, v, r, s), "Invalid request");
		
		_isNonceUsed[nonce]					=	true;
		
        address[] memory path				=	new address[](2);
        path[0]								=	dexRouter.WETH();
        path[1]								=	wonkaAddress;
		
		uint256[] memory perbnbprice 		= 	dexRouter.getAmountsOut(amount,path);
		
		uint256 tokentotransfer 			= 	perbnbprice[1];
		(bool sent,) 						= 	otcSaleAddress.call{value: msg.value}("");
        require(sent, "Failed to send Value");
		if(percentage>0){
			tokentotransfer					=	perbnbprice[1] + (perbnbprice[1]*percentage)/100;
		}
		if(wonkacapital.transfer(_msgSender(), tokentotransfer)){
            return tokentotransfer;
        }else{
            revert("Unable to transfer funds");
        }
    }

    function _validateSignature(bytes32 hashOfText, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 hashOfSignature = keccak256(abi.encodePacked(prefix, hashOfText));
        return ecrecover(hashOfSignature, v, r, s) == signerPublicAddress;
    }
}