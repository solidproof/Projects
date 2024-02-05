// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./BaseContract.sol";
import "../interfaces/IAllowContract.sol";

contract AllowContract is Ownable, IAllowContract {
    mapping(address => bool) contractList;

    //添加
    function set(address[] memory _list, bool _bool) public onlyOwner {
        for (uint256 i = 0; i < _list.length; i++) {
            contractList[_list[i]] = _bool;
        }
    }

    //是否存在
    function has(address _addr) public view override returns (bool) {
        return contractList[_addr] == true;
    }
}
