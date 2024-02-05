pragma solidity ^0.8.10;

import "./PriceOracle.sol";
import "./CErc20.sol";

abstract contract BasePriceOracle is PriceOracle {
    mapping(address => uint) prices;
    address public provider;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);

    modifier onlyProvider() {
        require(provider == msg.sender, 'provider!');
        _;
    }
    function setProvider(address newProvider) public onlyProvider {
		provider = newProvider;
	}

    function _getUnderlyingAddress(CToken cToken) internal view returns (address) {
        address asset;
        if (compareStrings(cToken.symbol(), "sETH")) {
            asset = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        } else {
            asset = address(CErc20(address(cToken)).underlying());
        }
        return asset;
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
}