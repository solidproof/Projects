/**
 * SPDX-License-Identifier: MI231321T
 */
pragma solidity >=0.8.0 <0.9.0;

import "./Ownable.sol";
import "../interfaces/IAllowContract.sol";
import "../interfaces/IToken.sol";

abstract contract BaseContract is Ownable {
    
    //合约授权地址
    address public allowContractAddress;
    
    //签名合约地址
    address public signAddress;

    //暂停
    bool public paused = false;
    
    //是不是人来调用的
    modifier isHuman() {
        require(tx.origin == msg.sender, "sorry humans only");
        _;
    }

    //检查是不是被允许的合约
    modifier isAllowContract() {
        require(
            IAllowContract(allowContractAddress).has(msg.sender),
            "not allow contract"
        );
        _;
    }

    modifier isPaused() {
        require(!paused, "paused");
        _;
    }

    //设置合约授权地址
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    //设置合约授权地址
    function setAllowContractAddress(address _address) public onlyOwner {
        allowContractAddress = _address;
    }

    //设置代币地址
    function setSignAddress(address _address) public onlyOwner {
        signAddress = _address;
    }
    
    //获取eth余额
    function getBalance() public view returns(uint256)
    {
        return address(this).balance;
    }

    //获取代币余额
    function getTokenBalance(address _tokenAddress) public view returns(uint256)
    {
        return IToken(_tokenAddress).balanceOf(address(this));
    }

    function ownerSweep(address _tokenAddress) public onlyOwner {
        uint256 amount = IToken(_tokenAddress).balanceOf(address(this));
        if (amount > 0) {
            IToken(_tokenAddress).transfer(msg.sender, amount);
        }
    }

    function ownerWithdraw() public onlyOwner {
        uint256 b = address(this).balance;
        require(b > 0, "insufficient balance.");
        payable(owner()).transfer(b);
    }
}
