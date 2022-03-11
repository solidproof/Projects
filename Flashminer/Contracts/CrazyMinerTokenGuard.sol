/**
 *  SPDX-License-Identifier: MIT
 */
// solium-disable-next-line linebreak-style
pragma solidity >=0.8.0 <0.9.0;
import "./base/BaseContract.sol";

contract CrazyMinerTokenGuard is Ownable {
    mapping(address => bool) public blackList;
    //白名单
    mapping(address => bool) public whiteList;

    //白名单检查
    bool public whiteCheck = true;

    uint256 public transactionLimit;

    function addBlackList(address _address) public onlyOwner {
        blackList[_address] = true;
    }

    function removeBlackList(address _address) public onlyOwner {
        blackList[_address] = false;
    }

    function addWhiteList(address _address) public onlyOwner {
        whiteList[_address] = true;
    }

    function removeWhiteList(address _address) public onlyOwner {
        whiteList[_address] = false;
    }

    function batchAddWhiteList(address[] memory _list) public onlyOwner {
        for (uint256 i = 0; i < _list.length; i++) {
            whiteList[_list[i]] = true;
        }
    }

    function batchRemoveWhiteList(address[] memory _list) public onlyOwner {
        for (uint256 i = 0; i < _list.length; i++) {
            whiteList[_list[i]] = false;
        }
    }

    function setLimit(uint256 _limit) public onlyOwner {
        transactionLimit = _limit;
    }

    function setWhiteCheck(bool _whiteCheck) public onlyOwner {
        whiteCheck = _whiteCheck;
    }

    function protect(
        address sender,
        address receiver,
        uint256 amount
    ) public view {
        require(!blackList[sender], "sender in blackList!");
        require(!blackList[receiver], "receiver in blackList!");
        if (transactionLimit > 0) {
            require(amount <= transactionLimit, "transaction amount exceed!");
        }
    }

    //合约转账检查
    function contractTransferCheck(
        address sender,
        address recipient,
        uint256 amount
    ) public view {
        //判断有没有开启白名单
        if (whiteCheck) {
            require(sender != address(0), "transfer from the zero address");
            require(recipient != address(0), "transfer to the zero address");
            //判断是不是合约地址
            if (amount > 0 && isContract(recipient)) {
                require(whiteList[recipient], "recipient unauthorized");
            }
        }
    }

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
