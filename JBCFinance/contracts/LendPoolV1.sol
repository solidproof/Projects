pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IMasterChef.sol";

contract LendPoolV1 {
    using SafeERC20 for IERC20;

    mapping(address => uint) public sharesOf;
    uint public totalShareBal;

    address public immutable token;
    address public immutable masterChef;
    uint public immutable pid;

    constructor(
        address _token,
        address _masterChef,
        uint _pid
    ) {
        token = _token;
        masterChef = _masterChef;
        pid = _pid;
    }

    receive() external payable {}

    function deposit(uint amount) public payable {
        if (token == address(0)) {
            require(msg.value == amount);
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
        IMasterChef(masterChef).deposit(pid, amount, msg.sender);

        sharesOf[msg.sender] += amount;
        totalShareBal += amount;
    }

    function withdraw(uint amount) public {
        require(amount <= sharesOf[msg.sender]);
        IMasterChef(masterChef).withdraw(pid, amount, msg.sender);
        
        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
        sharesOf[msg.sender] -= amount;
        totalShareBal -= amount;
    }

}
