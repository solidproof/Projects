//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/IERC20.sol";
import "../lib/SwapHelper.sol";

interface IXUSDReceiver {
    function deposit(uint256 amount) external;
}

interface IXSurge {
    function sell(uint256 amount) external returns (address, uint256);
    function getUnderlyingAssets() external view returns(address[] memory);
}

/**
    Allocates XUSD Taxation Across Various Resources
 */
contract ResourceCollector is Ownable, SwapHelper(0x10ED43C718714eb63d5aA57B78B54704E256024E){

    // receiving structure
    struct Receiver {
        uint256 points;
        uint256 index;
    }

    // divides up XUSD based on resourcePoints / totalPoints
    mapping ( address => Receiver ) public receivers;

    // list of resources to receive funding
    address[] public resources;

    // total allocation points
    uint256 public totalPoints;

    // XUSD Address
    address public immutable XUSD;

    // owner
    address public owner;
    modifier onlyOwner(){
        require(msg.sender == owner, 'Only Owner');
        _;
    }

    constructor(address _XUSD){
        XUSD = _XUSD;
    }

    function changeOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function tokenToBNB(address token) external onlyOwner {
        if (IERC20(token).balanceOf(address(this)) > 0) {
            _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        }
    }

    function bnbToToken(address token) external onlyOwner {
        if (address(this).balance > 0) {
            _bnbToToken(token, address(this).balance);
        }
    }

    function deliver() external onlyOwner {
        _deliver();
    }

    function sellAndDeliver(address token) external onlyOwner {
        _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        _deliver();
    }

    function sellXUSDAndDeliver() external onlyOwner {
        (address token,) = IXSurge(XUSD).sell(IERC20(XUSD).balanceOf(address(this)));
        _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        _deliver();
    }

    function sellAllAndDeliver() external onlyOwner {
        if (IERC20(XUSD).balanceOf(address(this)) > 0) {
            _sellSurge(XUSD);
        }
        address[] memory tokensToSell = IXSurge(XUSD).getUnderlyingAssets();
        for (uint i = 0; i < tokensToSell.length; i++) {
            if (IERC20(tokensToSell[i]).balanceOf(address(this)) > 0) {
                _tokenToBNB(tokensToSell[i], IERC20(tokensToSell[i]).balanceOf(address(this)));
            }
        }
        _deliver();
    }

    function deliverToken(address token) external onlyOwner {
        _deliverToken(token);
    }

    function deliverSellableTokens() external onlyOwner {
        address[] memory tokensToSell = IXSurge(XUSD).getUnderlyingAssets();
        for (uint i = 0; i < tokensToSell.length; i++) {
            if (IERC20(tokensToSell[i]).balanceOf(address(this)) > 100) {
                _deliverToken(tokensToSell[i]);
            }
        }
    }

    function _deliver() internal {
        uint256[] memory distributions = _fetchDistribution(address(this).balance);        
        for (uint i = 0; i < resources.length; i++) {
            if (distributions[i] > 0) {
                (bool s,) = payable(resources[i]).call{value: distributions[i]}("");
                require(s);
            }
        }
    }

    function _deliverToken(address token) internal {
        uint256[] memory distributions = _fetchDistribution(IERC20(token).balanceOf(address(this)));        
        for (uint i = 0; i < resources.length; i++) {
            if (distributions[i] > 0) {
                IERC20(token).transfer(resources[i], distributions[i]);
            }
        }
    }

    function sellXUSD() external onlyOwner {
        _sellSurge(XUSD);
    }

    function sellSurge(address surge) external onlyOwner {
        _sellSurge(surge);
    }

    function changeResourcePoints(address resource, uint newPoints) external onlyOwner {
        require(resources[resource].points > 0);
        require(newPoints > 0);

        totalPoints = totalPoints - resources[resource].points + newPoints;
        resources[resource].points = newPoints;
    }

    function addResource(
        address resource,
        uint256 points,
    ) external onlyOwner {

        // set structure data
        receivers[resource].points = points;
        receivers[resource].index = resources.length;

        // increment total points
        totalPoints += points;

        // add resource to list
        resources.push(resource);
    }

    function removeResource(
        address resource
    ) external onlyOwner {
        require(
            receivers[resource].points > 0,
            'Not Receiver'
        );

        // decrement total points
        totalPoints -= receivers[resource].points;

        // remove element from array and mapping
        receivers[
            resources[resources.length - 1]
        ].index = resources[resource].index;
        resources[
            resources[resource].index
        ] = resources[resources.length - 1];
        resources.pop();
        delete receivers[resource];
    }

    /**
        Iterates through sources and fractions out amount
        Between them based on their allocation score
     */
    function _fetchDistribution(uint256 amount) internal view returns (uint256[] memory) {
        uint256[] memory distributions = new uint256[](resources.length);
        for (uint i = 0; i < resources.length; i++) {
            distributions[i] = ( amount * receivers[resources[i]].allocation / totalPoints ) - 1;
        }
        return distributions;
    }
}