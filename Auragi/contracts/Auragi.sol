// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "./interfaces/IAuragi.sol";

contract Auragi is IAuragi {

    string public constant name = "Auragi";
    string public constant symbol = "AGI";
    uint8 public constant decimals = 18;
    uint public totalSupply = 0;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    uint public claimed = 0;
    bool public initialMinted;
    address public minter;
    address public merkleClaim;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event SetMinter(address minter);
    event SetMerkleClaim(address merkleClaim);


    constructor() {
        minter = msg.sender;
    }

    // No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        require(msg.sender == minter, "!minter");
        minter = _minter;
        emit SetMinter(minter);
    }

    function setMerkleClaim(address _merkleClaim) external {
        require(msg.sender == minter, "!minter");
        merkleClaim = _merkleClaim;
        emit SetMerkleClaim(merkleClaim);
    }

    // Initial mint: total 190M
    //   4M for "Genesis" pool
    //  48M for future partners
    //  30M for liquid team allocation (40M excl init veNFT)
    // 108M for future retroactive airdrops
    function initialMint(address _recipient) external {
        require(msg.sender == minter && !initialMinted, "!minter or initialMinted");
        initialMinted = true;
        _mint(_recipient, 190 * 1e6 * 1e18);
    }

    function approve(address _spender, uint _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function _mint(address _to, uint _amount) internal returns (bool) {
        totalSupply += _amount;
        unchecked {
            balanceOf[_to] += _amount;
        }
        emit Transfer(address(0x0), _to, _amount);
        return true;
    }

    function _transfer(address _from, address _to, uint _value) internal returns (bool) {
        balanceOf[_from] -= _value;
        unchecked {
            balanceOf[_to] += _value;
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function transfer(address _to, uint _value) external returns (bool) {
        return _transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) external returns (bool) {
        uint allowed_from = allowance[_from][msg.sender];
        if (allowed_from != type(uint).max) {
            allowance[_from][msg.sender] -= _value;
        }
        return _transfer(_from, _to, _value);
    }

    function mint(address account, uint amount) external returns (bool) {
        require(msg.sender != address(0x0) && msg.sender == minter, "!minter");
        _mint(account, amount);
        return true;
    }

    // Claim: total 132M
    //  72M for Arbitrum users
    //  60M for Defi users
    function claim(address account, uint amount) external returns (bool) {
        require(msg.sender != address(0x0) && msg.sender == merkleClaim, "!merkleClaim");
        require(claimed + amount <= 132 * 1e6 * 1e18, "over claimed");
        claimed += amount;
        _mint(account, amount);
        return true;
    }
}