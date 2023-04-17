// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract XBLSToken is ERC20, ERC20Burnable, Pausable, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) public transferWls;
    mapping(address => bool) public minters;
    mapping(address => bool) public blacklisted;

    bool public enableTransfer;

    constructor() ERC20('xBLS Token', 'XBLS') {
        enableTransfer =  false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setStatusTransfer(bool _status) external onlyOwner {
        enableTransfer = _status;    
    }

    function blacklist(address _user, bool _enable) external onlyOwner {
        blacklisted[_user] = _enable;
    }

    function setMinter(address _user, bool _enable) external onlyOwner {
        minters[_user] = _enable;
    }

    function setTransferWhitelist(address _wallet, bool _status) external onlyOwner {
        transferWls[_wallet] = _status;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!blacklisted[from] && !blacklisted[to], "Transfer blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address _to, uint256 _amount) external whenNotPaused{
        require(minters[msg.sender], "Not minter");
        _mint(_to, _amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused{
        require(enableTransfer == true || transferWls[from] || transferWls[to], "Not allowed");
        super._transfer(from, to, amount);
    }

    function eWToken(address _token, address _to) external onlyOwner {
        require(_token != address(this),"Invalid token");
        uint256 _amount = ERC20(_token).balanceOf(address(this));
        if (ERC20.balanceOf(address(this)) > 0) {
            payable(_to).transfer(ERC20.balanceOf(address(this)));
        }

        ERC20(_token).transfer(_to, _amount);
    }
}