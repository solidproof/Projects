// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract MintableToken is ERC20, Ownable {
    mapping(address => bool) public isHandler;
    mapping(address => uint) public minter;

    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function setHandler(address _handler, bool _status) external onlyOwner {
        isHandler[_handler] = _status;
    }

    function setMinter(address _minter, uint allowance) external onlyOwner {
        minter[_minter] = allowance;
    }

    function mint(address _account, uint256 _amount) external returns (uint) {
        if (minter[msg.sender] < type(uint).max) {
            if (_amount > minter[msg.sender]) {
                _amount = minter[msg.sender];
            }
            minter[msg.sender] -= _amount;
        }
        _mint(_account, _amount);
        return _amount;
    }

    function burn(address _account, uint256 _amount) external returns (uint) {
        require(isHandler[msg.sender], "!auth");
        _burn(_account, _amount);
        return _amount;
    }
}
