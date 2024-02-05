// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import "./Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract staking is Ownable {
    using SafeMath for uint256;

    address public treasury;

    uint256 constant private divider=10000;

    uint256 public depoiteTax=0;

    uint256 public withdrawTax=0;

    uint256 public rewardPercentage=150;

    uint256 public totalInvestedToken;

    uint256 public totalWithdrawToken;

    IERC20 public token;


    struct user {
        uint256 deposites;
        uint256 totalRewardWithdrawToken;
        uint256 checkToken;
        uint256 withdrawCheckToken;
        uint256 totalRewards;
    }

    mapping (address=>user) public investor;

	event NewDeposit(address indexed user, uint256 amount);
    event compoundRewards (address indexed user, uint256 amount);
	event withdrawal(address indexed user, uint256 amount);
	event RewardWithdraw(address indexed user,uint256 amount);
    event SetTax(uint256 DepositTax,uint256 withdrawTax);
    event SetRewardPercentage(uint256 rewardPercentage);
    constructor() Ownable(0x0c2f01db0e79a1D40B5a478A33a1B31A450C8F95){
        treasury=0x0c2f01db0e79a1D40B5a478A33a1B31A450C8F95;
        token=  IERC20(0x29cD78954c023cd9BffC435a816E568eDaf732aF);
    }


    function setWallet( address _treasury) public  onlyOwner{
        require(_treasury!=address(0),"Error: Can not set treasury wallet to zero address ");
        treasury=_treasury;
    }

    function setTax(uint256 _depoiteTax,uint256 _withdrawTax) public  onlyOwner{
        require(_depoiteTax<=2000,"Deposit Tax Must be less than 20%");
        require(_withdrawTax<=2000,"Withdraw Tax  Must be less than 20%");
        depoiteTax=_depoiteTax;
        withdrawTax=_withdrawTax;
        emit SetTax(_depoiteTax,_withdrawTax);
    }

    function setRewardPercentage(uint256 _rewardPercentage) public  onlyOwner{
        require(_rewardPercentage>=100,"Reward Percentage Must be less than 1%");
        require(_rewardPercentage<=2000,"Reward Percentage Must be less than 20%");
        rewardPercentage=_rewardPercentage;
        emit SetRewardPercentage(_rewardPercentage);
    }

    function invest(uint256 amount) public payable {
        user storage users =investor[msg.sender];

            require(amount<=token.allowance(msg.sender, address(this)),"Insufficient Allowence to the contract");
            uint256 tax=amount.mul(depoiteTax).div(divider);

            token.transferFrom(msg.sender, treasury, tax);
            token.transferFrom(msg.sender, address(this), amount.sub(tax));
            users.totalRewards+=calclulateReward(msg.sender);
            users.deposites+=amount;
            totalInvestedToken=totalInvestedToken.add(amount.sub(tax));
            users.checkToken=block.timestamp;
            emit NewDeposit(msg.sender, amount);
    }

    function compound() public payable {
        user storage users =investor[msg.sender];

            (uint256 amount)=calclulateReward(msg.sender);

            require(amount>0,"compound  Amount very low");
             users.deposites+=amount;
            totalInvestedToken=totalInvestedToken.add(amount);
            emit compoundRewards (msg.sender, amount);

            users.withdrawCheckToken=block.timestamp;
            users.checkToken=block.timestamp;
    }

    function withdrawToken(uint256 amount)public {
        uint256 totalDeposite=getUserTotalDepositToken(msg.sender);
        require(totalDeposite>0,"No Deposite Found");
        require(amount<=totalDeposite,"Amount Exceeds Deposite Amount");
        require(amount<=getContractTokenBalacne(),"Not Enough Token for withdrwal from contract please try after some time");
        uint256 tax=amount.mul(withdrawTax).div(divider);
        token.transfer(treasury, tax);
        token.transfer(msg.sender, amount.sub(tax));
        investor[msg.sender].totalRewards+=calclulateReward(msg.sender);
        investor[msg.sender].deposites-=amount;
        investor[msg.sender].checkToken=block.timestamp;
        emit withdrawal(msg.sender, amount);
    }

     function withdrawRewardToken()public {
        (uint256 totalRewards)=calclulateReward(msg.sender).add(investor[msg.sender].totalRewards);
        require(totalRewards>0,"No Rewards Found");
        require(totalRewards<=getContractTokenBalacne(),"Not Enough Token for withdrwal from contract please try after some time");
        uint256 taxR=totalRewards.mul(withdrawTax).div(divider);
        token.transfer(msg.sender, totalRewards.sub(taxR));
        investor[msg.sender].totalRewardWithdrawToken+=totalRewards;
        investor[msg.sender].totalRewards=0;
        investor[msg.sender].checkToken=block.timestamp;
        totalWithdrawToken+=totalRewards;
        emit RewardWithdraw(msg.sender, totalRewards);
    }


     function calclulateReward(address _user) public view returns(uint256){
        uint256 totalRewardToken;
        user storage users=investor[_user];
            if(users.deposites>0){
                uint256 depositeAmount=users.deposites;
                uint256 time = block.timestamp.sub(users.checkToken);
                totalRewardToken += depositeAmount.mul(rewardPercentage).div(divider).mul(time).div(1 days).div(365);
            }
        return(totalRewardToken);
    }

    function getUserTotalDepositToken(address _user) public view returns(uint256 _totalInvestment){

            _totalInvestment=investor[_user].deposites;

    }

    function getUserTotalRewardWithdrawToken(address _user) public view returns(uint256 _totalWithdraw){
        _totalWithdraw=investor[_user].totalRewardWithdrawToken;
    }


    function getContractTokenBalacne() public view returns(uint256 totalToken){
        totalToken=token.balanceOf(address(this));
    }

    function getContractBNBBalacne() public view returns(uint256 totalBNB){
        totalBNB=address(this).balance;
    }

    function withdrawalBNB() public payable onlyOwner{
        payable(owner()).transfer(getContractBNBBalacne());
    }

    receive() external payable {

    }

}