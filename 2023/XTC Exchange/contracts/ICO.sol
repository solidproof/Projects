// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


interface IUniswapV2Router02 {
    function factory() external pure returns (address);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline) external payable returns (uint amountToken, uint amountETH, uint liquidity);    
}



interface IUniswapV2Factory 
{
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}


contract ICO 
{
    // Token being offered in the ICO
    address public tokenAddress;
    IERC20  private token;
    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // ICO parameters
    uint256 public hardCap;
    uint256 public softCap;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    // State variables
    uint256 public raisedAmount;
    bool public isICOActive;
    bool public softCapReached;
    bool public ICOCompleted;

    uint256 public timeUnit;

    // Mapping to track contributors and their contributions
    address[] public contributors;
    mapping(address => uint256) public contributions;
    mapping(address => uint256) public xtcBought;
    address public admin;
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    uint256[] public tokensPerWie;
    constructor(address _tokenAddress) 
    {
        tokenAddress = _tokenAddress;
        token = IERC20(tokenAddress);
        
        softCap = 2 * 10**17;  // 0.2 BNB
        hardCap = 4 * 10**18;  // 4 BNB

        tokensPerWie[0] = 16000; //  Stage 1 
        tokensPerWie[1] = 10000; //  Stage 2
        tokensPerWie[2] = 6666;  //  Stage 3
        tokensPerWie[3] = 5000;  //  Stage 4

        timeUnit = 1 days;
        admin =  0x19865Ffaa11cff00A094a5eBF66675C36E5e182b;
        raisedAmount = 0;
        isICOActive = false;
        softCapReached = false;
        ICOCompleted = false;
        uniswapV2Router = IUniswapV2Router02(router);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), tokenAddress);
        uniswapV2Router = _uniswapV2Router;         
    }



    // Function to contribute Ether to the ICO
    function contribute() external payable onlyWhileICOActive 
    {
        require(msg.value > 0, "Contribution amount must be greater than 0");
        require(block.timestamp<endTimestamp, "ICO Time is over");

        if( contributions[msg.sender]==0)
        {
            contributors.push(msg.sender);
        }
        contributions[msg.sender] = contributions[msg.sender]+msg.value;
        raisedAmount = raisedAmount+msg.value;
        uint256 stage = getStage();
        xtcBought[msg.sender] += tokensPerWie[stage]*msg.value;
        require(raisedAmount <= hardCap, "Hard cap reached");
        if (raisedAmount >= softCap) 
        {
            softCapReached = true;
        }

    }

    // To show contribution of the contributor. 
    // returns eth deposited and tokens bought. 
    function contributionOf(address account) public view returns(uint256 value, uint256 tokens)
    {
        value = contributions[account];
        tokens =xtcBought[account];
        return (value, tokens);
    }

    //This function can provide a set of variables values for showing on website.
    function getState1() public view returns(uint256, uint256, uint256, uint256)
    {   
        uint256 len = contributors.length;
        return(len,  raisedAmount,  softCap,  hardCap);
    }


    //This function can provide a set of variables values for showing on website. 
    function getState2() public view returns(uint256, uint256, uint256, bool)
    {    
        uint256 stage = getStage();
        return(endTimestamp, block.timestamp,  tokensPerWie[stage], ICOCompleted);
    }

    // Only admin can call this function. 
    // this function can withdraw remaining tokens in the ICO contract address. 
    function withdrawXTC(uint256 amount) public 
    {
        require(msg.sender==admin, "Only Admin is Authorize");
        token.transfer(admin, amount);
    }


    // Modifier to ensure the ICO is active
    modifier onlyWhileICOActive() {
        require(isICOActive, "ICO is not active");
        _;
    }



    // To open ICO
    // Admin can trager this function. 
    event StartedICO(uint256);
    function startICO() public 
    {
        require(msg.sender==admin, "Only Admin is Authorize");
        require(!ICOCompleted, "ICO is already completed");
        require(!isICOActive, "ICO is already started");
        isICOActive = true;
        uint256 _periodInSeconds = 8 * timeUnit;
        startTimestamp = block.timestamp;
        endTimestamp = block.timestamp+(_periodInSeconds);
        token.approve(router, token.totalSupply()); 
        emit StartedICO(block.timestamp);      
    }



    // this function determine the stage of ICO based on ICO start time. 
    function getStage() public view returns(uint256)
    {
        uint256 span = block.timestamp-startTimestamp;
        uint fac = span/(2*timeUnit);
        if(fac>3) { fac = 3; }
        return fac;
    }



    // Function to end the ICO and transfer remaining tokens to the owner's wallet
    event EndedICO(uint256);
    function endICO() external 
    {
        require(!ICOCompleted, "ICO is already completed");
        require(block.timestamp > endTimestamp || raisedAmount > hardCap, "ICO has not been ended yet");

        isICOActive = false;
        ICOCompleted = true;
        if (!softCapReached) 
        {
            refundContributors();
        } 
        else 
        {
            sendTokensToContributors();
            payable(admin).transfer(address(this).balance);
        }
        emit EndedICO(block.timestamp);
    }


    // internal function 
    // to distribute tokens to the contributors. 
    // The amount of tokens is pre-calculated 
    // this function will read that amount from xtcBought mapping 
    function sendTokensToContributors() internal  
    {
        for (uint256 i = 0; i < contributors.length; i++) 
        {
            address contributor = contributors[i];
            uint256 tokensToSend = xtcBought[contributor];
            if (tokensToSend > 0) 
            {
                token.transfer(contributor, tokensToSend);
            }
        }        
    }



    // Function to refund contributors if the soft cap is not reached
    function refundContributors() internal 
    {
        for (uint256 i = 0; i < contributors.length; i++) 
        {
            address contributor = contributors[i];
            uint256 contribution = contributions[contributor];
            if (contribution > 0) 
            {
                contributions[contributor] = 0;
                payable(contributor).transfer(contribution);
            }
        }
    }

    // Total number of investors contributed to the project. 
    function totalInvestors() public view returns(uint256)
    {
        return contributors.length;
    }


    // To show required number of tokens for distribution to all contributors. 
    function requiredTokens() public view returns(uint256)
    {
        uint256 totalTokens = 0;
        for (uint256 i = 0; i < contributors.length; i++) 
        {
            address contributor = contributors[i];
            uint256 tokensToSend = xtcBought[contributor];
            totalTokens += tokensToSend;
        } 
        return totalTokens;
    }



    // Function to add liquidity to a decentralized exchange (e.g., Uniswap)
    // function addLiquidity() internal 
    // {
    //     uint256 ethAmount = address(this).balance;
    //     uint256 stage = getStage();
    //     uint256 tokenAmount = ethAmount.mul(tokensPerWie[stage]);
    //     uniswapV2Router.addLiquidityETH{value: ethAmount} (
    //         tokenAddress,
    //         tokenAmount,
    //         0, // slippage is unavoidable
    //         0, // slippage is unavoidable
    //         admin,
    //         block.timestamp+30);
    // }

    receive() external payable {}

}
