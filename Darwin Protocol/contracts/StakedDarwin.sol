pragma solidity ^0.8.14;

import "./interface/IStakedDarwin.sol";

contract StakedDarwin is IStakedDarwin {
    string public constant name = "Staked Darwin Protocol";
    string public constant symbol = "sDARWIN";
    uint8 public constant decimals = 18;

    address public darwinStaking;
    address public immutable darwin;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    // The contract will be deployed thru create2 directly within the Darwin Protocol initialized
    constructor() {
        darwin = msg.sender;
    }

    function setDarwinStaking(address _darwinStaking) external {
        require(address(darwinStaking) == address(0), "StakedDarwin: STAKING_ALREADY_SET");
        require(msg.sender == darwin, "StakedDarwin: CALLER_NOT_DARWIN");
        darwinStaking = _darwinStaking;
    }

    modifier onlyStaking() {
        require(msg.sender == darwinStaking, "StakedDarwin: CALLER_NOT_STAKING");
        _;
    }

    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        require(value <= balanceOf[from], "StakedDarwin: BURN_EXCEEDS_BALANCE");
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address _owner, address spender, uint value) private {
        allowance[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        require(value <= balanceOf[from], "StakedDarwin: TRANSFER_EXCEEDS_BALANCE");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function mint(address to, uint value) external onlyStaking {
        _mint(to, value);
    }

    function burn(address from, uint value) external onlyStaking {
        _burn(from, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            require(value <= allowance[from][msg.sender], "StakedDarwin: TRANSFERFROM_EXCEEDS_ALLOWANCE");
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }
}