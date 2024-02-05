// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
import "./Ownable.sol";
import "./IERC20.sol";

contract PublicSale is Ownable {
    uint256 public vibPerEther = 20000;
    address public vib;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public softcap = 50 ether;
    uint256 public hardcap = 100 ether;
    uint256 public _duration;
    bool public softcapmet;
    bytes32 public root;

    mapping (address => uint256) public payAmount;
    mapping (address => uint256) private _vibReleased;

    event VibReleased(address user, uint256 amount);
    // TGE: 25%
    // VESTING 25%/month
    constructor(address _vib, uint256 _start, uint256 _end, uint256 durationSeconds) {
        vib = _vib;
        startTime = _start;
        endTime = _end;
        _duration = durationSeconds;
    }


    function setPrice(uint256 _price) external onlyOwner {
        require(block.timestamp < startTime, "IDO has started, the price cannot be changed");
        vibPerEther = _price;
    }

    function setTime(uint256 _start, uint256 _end) external onlyOwner {
        if(startTime > 0) {
            require(block.timestamp < startTime);
        }
        startTime = _start;
        endTime = _end;
    }

    function join() external payable {
        require(msg.value >= 0.1 ether && msg.value <= 10 ether);
        require(block.timestamp >= startTime && block.timestamp < endTime, "The public sale hasn't started yet");
        require(address(this).balance <= hardcap, "IDO quota has been reached");
        payAmount[msg.sender] += msg.value;
        if(address(this).balance >= softcap) {
            softcapmet = true;
        }
    }

    function leave(uint256 amount) external {
        require(!softcapmet, "Refunds are not possible as the soft cap has been exceeded");
        require(payAmount[msg.sender] >= amount, "The exit amount is greater than the invested amount");
        payAmount[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }

    function released(address _user) public view returns(uint256){
        //withdraw
        return _vibReleased[_user];
    }

    function releasable(address _user) public view returns(uint256){
        //available
        return _vestingSchedule( getTotalAllocation(_user) , block.timestamp) - released(_user);
    }

    function release() external {
        require(softcapmet, "VIB cannot be claimed as the soft cap for IDO has not been reached");
        uint256 amount = releasable(msg.sender);
        _vibReleased[msg.sender] += amount;
        emit VibReleased(msg.sender, amount);
        IERC20(vib).transfer(msg.sender, amount * vibPerEther);
    }

    function startVesting() public view returns(uint256){
        return endTime;
    }

    function duration() public view returns(uint256){
        return _duration;
    }

    function getTotalAllocation(address _user) public view returns (uint256){
        return payAmount[_user] * vibPerEther;
    }

    function _vestingSchedule(uint256 totalAllocation, uint256 timestamp) internal view returns (uint256) {
        if (timestamp < startVesting()) {
            return 0;
        } else if (timestamp > startVesting() + duration()) {
            return totalAllocation;
        } else {
            return ( totalAllocation / 4 + 3 * totalAllocation * (timestamp - startVesting())) / (4 * duration());
        }
    }


    function withdrawEther() external onlyOwner {
        require(block.timestamp >= endTime, "The owner can only withdraw ETH after the IDO ends");
        require(softcapmet, "The owner cannot withdraw ETH as the soft cap for IDO has not been reached");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    // to help users who accidentally send their tokens to this contract
    function sendToken(address token, address to, uint256 amount) external onlyOwner {
        require(block.timestamp >= endTime);
        IERC20(token).transfer(to, amount);
    }
}