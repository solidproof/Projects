//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
contract Presale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    AggregatorV3Interface internal priceFeedETH;
    AggregatorV3Interface internal priceFeedUsdt;

    IERC20 public DthToken; // The token being sold
    IERC20 public UsdtToken; // The token being sold
    IERC20 public EthToken; // The token being sold

  

    

    bool public presaleStart; // Ön satışın başlangıç zamanı
    bool public presaleEnd;

    
    mapping(address => uint256) private contributions;
    mapping(address => uint256) private ethcontributions;

    mapping(address => bool) private whitelisted;

    address[] private participants;
    address[] private ethparticipants;

    uint256 private totalContributionsUsdt;
    uint256 private totalContributionsEth;

    event EthPurchase(address indexed buyer, uint256 amount);
    event UsdtPurchase(address indexed buyer, uint256 amount);
    event RewardClaimed(address indexed claimer, uint256 amount);

    constructor(
        address _dthToken,
        address _usdtToken,
        address _ethToken
        
    ) {
        DthToken = IERC20(_dthToken);
        UsdtToken = IERC20(_usdtToken);
        EthToken = IERC20(_ethToken);
        priceFeedETH = AggregatorV3Interface(0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46); // Address of the Chainlink Price Feed contract for Token1
    priceFeedUsdt = AggregatorV3Interface(0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
    } 

       function buyTokenWithUsdt(uint256 _amount) public nonReentrant {

        require(presaleStart == true, "Presale has not started yet");
        require(presaleEnd == false, "Presale has ended");
        require(whitelisted[msg.sender] == true, "You are not whitelisted");
        require(_amount > 0, "You need to send some USDT");
        require(_amount <= UsdtToken.allowance(msg.sender, address(this)), "You need to allow the contract to spend the USDT you are sending");
        
        
        UsdtToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        if (contributions[msg.sender] == 0) {
        
        participants.push(msg.sender);
    }

        contributions[msg.sender] = contributions[msg.sender].add(_amount);
        totalContributionsUsdt += _amount;

emit UsdtPurchase(msg.sender, _amount);
        
    }
    function getUserContributionInUsdt(address user) public view returns (uint256) {
    return contributions[user];
}

   

function calculateDthUsdt(address participant) public view returns (uint256) {
    uint256 contribution = contributions[participant];
    uint256 reward = contribution.mul(40).mul(10**12);
    return reward;
}




function buyTokenWithEth() public payable nonReentrant {

    require(presaleStart == true, "Presale has not started yet");
        require(presaleEnd == false, "Presale has ended");
        require(whitelisted[msg.sender] == true, "You are not whitelisted");
        require(msg.value > 0, "You need to send some ETH");
        
    
    if (ethcontributions[msg.sender] == 0) {
        
        ethparticipants.push(msg.sender);
    }

    ethcontributions[msg.sender] = ethcontributions[msg.sender].add(msg.value);
    totalContributionsEth += msg.value;
emit EthPurchase(msg.sender, msg.value);

}

function getUserContributionInEth(address user) public view returns (uint256) {
    return ethcontributions[user];
}
    
function calculateDthForParticipant(address participant) public view returns (uint256) {
    uint256 ethContributionWei = ethcontributions[participant]; // Get the ETH contribution of the participant in Wei
    uint256 ethPriceWei = getLatestEthPrice(); // Get the latest ETH price in Wei
    uint256 usdContributionWei = ethContributionWei.mul(ethPriceWei); // Convert the ETH contribution to USD (in Wei)
    uint256 dthRewardWei = usdContributionWei.mul(40); // Calculate the DTH reward (in Wei)
    uint256 dthReward = dthRewardWei.div(1e8);
    return dthReward;
}

function calculateTotalDthForParticipant(address participant) public view returns (uint256) {
    uint256 dthRewardEth = calculateDthForParticipant(participant);
    uint256 dthRewardUsdt = calculateDthUsdt(participant);
    uint256 totalDthReward = dthRewardEth.add(dthRewardUsdt);
    return totalDthReward;
}



function claimDthReward() external nonReentrant {
    require(presaleEnd == true, "Presale has not ended yet");
    uint256 dthReward = calculateTotalDthForParticipant(msg.sender);
    require(dthReward > 0, "No rewards available for this address");
    require(whitelisted[msg.sender] == true, "You are not whitelisted");
    

    // Reset the contributions of the participant
    ethcontributions[msg.sender] = 0;
    contributions[msg.sender] = 0;

    // Transfer the DTH reward to the participant
    DthToken.transfer(msg.sender, dthReward);

    emit RewardClaimed(msg.sender, dthReward);
}




function getLatestEthPrice() public view returns (uint256) {
    (,int price,,,) = priceFeedETH.latestRoundData();
    return uint256(price);
}

function setPresaleStart(bool _presaleStart) public onlyOwner {
        
            presaleStart = _presaleStart;
        }
          
    
    function setpresaleEnd(bool _presaleEnd) public onlyOwner {
        presaleEnd = _presaleEnd;
    }

    function getTotalUsdtInContract() public view returns (uint256) {
    return UsdtToken.balanceOf(address(this));
}
function getTotalEthInContract() public view returns (uint256) {
    return address(this).balance;
}

function getTotalEthInContractInUsd() public view returns (uint256) {
    uint256 totalEthInWei = address(this).balance;
    uint256 totalEth = totalEthInWei ; // Convert Wei to Ether.
    uint256 ethPriceInUsd = getLatestEthPrice();
    return totalEth * ethPriceInUsd; // Convert Ether to USD.
}

function withdrawAllUsdt() external onlyOwner nonReentrant {
    uint256 contractBalance = UsdtToken.balanceOf(address(this));
    require(contractBalance > 0, "No USDT in the contract to withdraw");
    UsdtToken.safeTransfer(msg.sender, contractBalance);
}

function withdrawAllEth() external onlyOwner nonReentrant {
    uint256 contractBalance = address(this).balance;
    require(contractBalance > 0, "No ETH in the contract to withdraw");
    payable(msg.sender).transfer(contractBalance);
}

function setWhitelistStatuses(address[] calldata _participants) external onlyOwner nonReentrant {
    for (uint i = 0; i < _participants.length; i++) {
        whitelisted[_participants[i]] = true;
    }
}


}