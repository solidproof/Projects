// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20.sol";
import "./IERC721.sol";
import "./IERC721Enumerable.sol";
import "./IERC721Receiver.sol";


contract LootBox is IERC721Receiver {

    address public owner;
    uint8 public start;
    uint8 public currentDay;
    uint8 public dayLeft;
    uint8 public totalDays;
    uint256 public carryOverSum;
    uint256 public rewardAmount;
    uint256 public totalRewardsPaid;
    uint256 public totalNFTRewards;
    uint256 public lastUpdateTimestamp;

    uint256 public minGoku = 1 * 10**18;
    uint256 public gokuPrice = 100000; // Price of Goku token in USDT ==> $0.10
    uint256 public seiGokuPrice = 1e17; // Price of Goku token in SEI  ==> 0.1 SEI
    uint256 public totalGokuBurnt;

    address public gokuToken = 0x019EA1347BD9bc912c0221d24983a74E9386B794;//80million
    address public usdtToken;
    address private teamWallet = 0xf67f3AAEc0D1da4d32405c9eCB53E8bF73bCf97E;
    IERC721 public nftContract;

    mapping(address => uint256) public gokuLootBoxBalance;
    mapping(address => uint256) public totalUserGokuBurnt;
    mapping(address => uint256) public rewardBalance;
    mapping(address => uint256) public nftBalance;

    modifier onlyOncePerDay() {
        require(block.timestamp >= lastUpdateTimestamp +  1 days, "Can only update once every 24 hours");
        _;
    }

    modifier onlyGokuCity() {
        require(msg.sender == owner,"Only Goku City");
        _;
    }

    event TokenPurchased(address indexed buyer, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event NftClaimed(address indexed user,uint256 tokenId);

    constructor() {
        owner = msg.sender;
    }



    function startReward() onlyGokuCity external {
        require(start == 0,"Gokucity Rewards has Already Started");
        totalDays = 30;
        currentDay = 1;
        lastUpdateTimestamp = block.timestamp;
        rewardAmount = 2640000 * 1e18; // 2.64million
        dayLeft = 30;
        start = 1;
    }

    function setRewardAmount(uint256 _amount) onlyGokuCity external {
        rewardAmount = _amount;
    }

    function setGokuPriceInUSDT(uint256 _amount) onlyGokuCity external {
        gokuPrice = _amount; //10000 = $.10 in usdt 6 Decimals
    }
    

    function setGokuPriceInSEI(uint256 _amount) onlyGokuCity external {
        seiGokuPrice = _amount;
    }


    function setUsdtAddress(address _addr) onlyGokuCity external {
        usdtToken = _addr;
    }


    function setTeamWallet(address _wallet) onlyGokuCity external {
        teamWallet = _wallet;
    }


    function setNFTContract(address _nftContract) external onlyGokuCity {
        nftContract = IERC721(_nftContract);
    }


    function setUserReward(address _recipient,uint256 _amount,uint256 _rewardAmount,uint256 _nftAmount) onlyGokuCity external {
        require(IERC20(gokuToken).allowance(_recipient, address(this)) >= _amount ,"Invalid User");
        require(IERC20(gokuToken).transferFrom(_recipient, address(this), _amount),"Goku Transfer to LootBot Failed");  
        gokuLootBoxBalance[_recipient] = gokuLootBoxBalance[_recipient] + _amount;
        rewardBalance[_recipient] = rewardBalance[_recipient] + _rewardAmount;
        nftBalance[_recipient] = nftBalance[_recipient] + _nftAmount;
    }


    function buyGokuSEI(uint256 _numberOfTokens) external payable {
        uint256 amount = (msg.value * 10**18) / seiGokuPrice;
        require(amount >= _numberOfTokens,"Insufficient SEI sent");
        require(amount >= minGoku,"Cannot buy less than 1 Goku");
        require(IERC20(gokuToken).balanceOf(address(this)) >= _numberOfTokens,"Insufficient Goku Tokens to Make Sale");
      
        require(
            IERC20(gokuToken).transfer(msg.sender, _numberOfTokens),
            "Transfer failed"
        );

        emit TokenPurchased(msg.sender, _numberOfTokens);
    }


    function buyGokuUSDT(uint256 _numberOfTokens) external {
        uint256 totalCost = (_numberOfTokens * gokuPrice) / 10**18;
        require(_numberOfTokens >= minGoku,"Cannot buy less than 1 Goku");
        require(IERC20(gokuToken).balanceOf(address(this)) >= _numberOfTokens,"Insufficient Goku Tokens to Make Sale");
        require(
            IERC20(usdtToken).allowance(msg.sender, address(this)) >= totalCost,
            "Allowance too low"
        );
        require(
            IERC20(usdtToken).transferFrom(msg.sender, address(this), totalCost),
            "Transfer failed"
        );
        require(IERC20(gokuToken).transfer(msg.sender, _numberOfTokens), "Buy Transfer failed");

        emit TokenPurchased(msg.sender, _numberOfTokens);
    }


    function processBuyLootBoxAndClaim() external {

        require(dayLeft > 0,"Reward period is over");

        uint256 _amount = gokuLootBoxBalance[msg.sender];

        uint256 amountToBurn = (_amount * 75) / 100;

        uint256 amountToProject = (_amount * 25) / 100;
        
        //burn  75%      
        IERC20(gokuToken).transfer(address(0x000000000000000000000000000000000000dEaD),amountToBurn);

        //Other
        IERC20(gokuToken).transfer(teamWallet,amountToProject);

        gokuLootBoxBalance[msg.sender] = gokuLootBoxBalance[msg.sender] - _amount;

        totalGokuBurnt = totalGokuBurnt + amountToBurn;

        totalUserGokuBurnt[msg.sender] = totalUserGokuBurnt[msg.sender] + amountToBurn;

        //claimReward
        claimReward(msg.sender);

    }


    function claimReward(address _recipient) internal {
        sendGoku(_recipient);
        sendNFT(_recipient);    
    }


    function sendGoku(address _recipient) internal {
        uint256 amount = rewardBalance[_recipient];
        if(amount == 0) return;
        rewardBalance[_recipient] = rewardBalance[_recipient] - amount;

        IERC20(gokuToken).transfer(_recipient,amount);
        updateTotalRewards(amount);

        emit RewardClaimed(_recipient, amount);
    }


    function sendNFT(address _recipient) internal {
        uint256 amount = nftBalance[_recipient];
        if(amount == 0) return;
        nftBalance[_recipient] = nftBalance[_recipient] - amount;

        uint256 tokenId = getTokenId();
        if(tokenId == 0) return;
        
        // Approve the transfer of the token to the caller
        nftContract.approve(_recipient, tokenId);

        // Transfer the token to the caller
        nftContract.safeTransferFrom(address(this), _recipient, tokenId);

        updateTotalNFTs();

        emit NftClaimed(_recipient, tokenId);
    }


    function getTokenId() public view returns (uint256) {
        uint256[] memory tokenIds;

        uint256 balance = IERC721(address(nftContract)).balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }

        tokenIds = new uint256[](balance);
        uint256 index = 0;
        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = findTokenAtIndex(address(nftContract), i);
            if (tokenId != 0) {
                tokenIds[index] = tokenId;
                index++;
            }
        }

        return tokenIds[0];
    }

    function findTokenAtIndex(address _nftContract, uint256 _index) internal view returns (uint256) {
        for (uint256 tokenId = 1; tokenId <= IERC721(_nftContract).totalSupply(); tokenId++) {
            if (IERC721(_nftContract).ownerOf(tokenId) == address(this)) {
                if (_index == 0) {
                    return tokenId;
                }
                _index--;
            }
        }
        return 0;
    }


    function updateCurrentDay() internal {
        require(dayLeft > 0,"Reward period is over");
        currentDay = currentDay + 1;
        uint8 sum = currentDay - 1;
        dayLeft = totalDays - sum;
        lastUpdateTimestamp = block.timestamp;

    }


    function updateRewardAmount(uint256 _amount) onlyOncePerDay onlyGokuCity external returns(uint256){
        updateCurrentDay();
        carryOverSum = carryOverSum + _amount;
        rewardAmount = rewardAmount + _amount;
        return rewardAmount;
    }


    function updateTotalRewards(uint256 _amount) internal returns(uint256){
        totalRewardsPaid = totalRewardsPaid + _amount;
        return totalRewardsPaid;
        
    }


    function updateTotalNFTs() internal returns(uint256){
        totalNFTRewards = totalNFTRewards + 1;
        return totalNFTRewards;
        
    }


    function getTotalRewards() external view returns(uint256) {
        return totalRewardsPaid;
    }


    function getDay() external view returns(uint8){
        return currentDay;
    }


    function getTotalGokuBurnt() external view returns(uint256){
        return totalGokuBurnt;
    }


    function getTotalUserGokuBurnt(address _user) external view returns(uint256){
        return totalUserGokuBurnt[_user];
    }


    function getCurrentRewardAmount() external view returns(uint256){
        return rewardAmount;
    }  


    function withdrawAllRewards() external onlyGokuCity {
        require(dayLeft == 0,"Cannot withdraw rewards while period is active");
        uint256 balance = IERC20(gokuToken).balanceOf(address(this));     
        IERC20(gokuToken).transfer(teamWallet,balance);

    } 


    function withdrawUSDT() external onlyGokuCity {
        uint256 balance = IERC20(usdtToken).balanceOf(address(this));  
        require(
            IERC20(usdtToken).transfer(teamWallet, balance),
            "USDT withdrawal failed"
        );
    }


    function withdrawSEI() external onlyGokuCity{
        uint256 balance = address(this).balance;

        if(balance > 0){
        payable(teamWallet).transfer(balance);
        }

    }


    function withdrawNFT(address _recipient) external onlyGokuCity {
        
        uint256 tokenId = getTokenId();
        
        // Approve the transfer of the token to the caller
        nftContract.approve(_recipient, tokenId);

        // Transfer the token to the caller
        nftContract.safeTransferFrom(address(this), _recipient, tokenId);
    
    }

     function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        
        return IERC721Receiver.onERC721Received.selector;
    }

}
