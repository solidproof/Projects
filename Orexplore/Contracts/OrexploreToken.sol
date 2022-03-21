//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.9;

import "./interfaces/IERC20.sol";
import "./interfaces/IAddressManager.sol";
import "./GlobalImpl.sol";


//erc20 token
contract A_OrexploreToken is ProjectGlobalImpl, IERC20 {
    IAddressManager public addressManager;
    bool public pause = false;

    string  _name;
    string  _symbol;
    uint8  _decimals;
    // max supply
    uint256 _totalSupply;
    // current supply
    uint256 public currentSupply = 0;
    // for minters
    mapping(address => bool) public _minters;

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) internal allowed;

    // transfer fee, ten thousandth ratio
    uint256 public fee = 500;
    mapping(address => bool) public noFeeAddress;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed account, uint256 amount);

    constructor(address _addressManager) {
        addressManager = IAddressManager(_addressManager);
        _decimals = 18;
        _symbol = "ORE";
        _name = "ORE Token";
        //10,000,000 token
        _totalSupply = 10000000 * (10 ** uint256(_decimals));
        noFeeAddress[address(this)] = true;
        noFeeAddress[msg.sender] = true;
    }

    modifier onlyMinter() {
        require(_minters[msg.sender], "!minter");
        _;
    }

    modifier notPaused() {
        require(!pause, "paused");
        _;
    }

    function setAddressManagerAddress(address _addressManager) onlyOwner public {
        addressManager = IAddressManager(_addressManager);
    }

    function setPause(bool b) onlyOwner public {
        pause = b;
    }

    function name() public override view returns (string memory){
        return _name;
    }

    function symbol() public override view returns (string memory){
        return _symbol;
    }

    function decimals() public override view returns (uint8){
        return _decimals;
    }

    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address _owner) override public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) override public notPaused returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);

        _transfer(msg.sender, _to, _value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) override public notPaused returns (bool){
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        _transfer(_from, _to, _value);
        require(allowed[_from][msg.sender] >= _value, "allowed[_from][msg.sender] is less _value");
        allowed[_from][msg.sender] = allowed[_from][msg.sender] - _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(balances[_from] >= _value, "balances[_from] is less _value");
        balances[_from] = balances[_from] - _value;
        if (noFeeAddress[_from] || noFeeAddress[_to]) {
            balances[_to] = balances[_to] + _value;
        } else {
            uint256 _fee = (_value * fee) / 10000;
            require(_value >= _fee, "_value is less _fee");
            uint256 _realValue = _value - _fee;
            balances[_to] = balances[_to] + _realValue;
            address feeTo = addressManager.getAddress("ProjectFeeAddress");
            balances[feeTo] = balances[feeTo] + _fee;
        }
    }

    function approve(address _spender, uint256 _value) override public notPaused returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) override public view returns (uint256){
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool)    {
        allowed[msg.sender][_spender] = (
        allowed[msg.sender][_spender] + _addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool)    {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            require(oldValue >= _subtractedValue, "oldValue is less _subtractedValue");
            allowed[msg.sender][_spender] = oldValue - _subtractedValue;
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }


    function addMinter(address minter) public onlyOwner {
        _minters[minter] = true;
    }

    function removeMinter(address minter) public onlyOwner {
        _minters[minter] = false;
    }


    /**
     * @dev Function to mint tokens
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(address _to, uint256 _amount) onlyMinter public returns (bool)    {
        uint256 tmpTotal = currentSupply + _amount;
        require(tmpTotal <= _totalSupply, "mint too much");
        currentSupply = currentSupply + _amount;
        balances[_to] = balances[_to] + _amount;
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Destroys `_amount` tokens from `_account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `_account` cannot be the zero address.
     * - `_account` must have at least `_amount` tokens.
     */
    function burn(address _account, uint256 _amount) onlyMinter public returns (bool)  {
        require(_account != address(0), "BEP20: burn from the zero address");

        require(balances[_account] >= _amount, "balances[_account] is less _amount");
        balances[_account] = balances[_account] - _amount;
        require(currentSupply >= _amount, "currentSupply is less _amount");
        currentSupply = currentSupply - _amount;
        emit Burn(_account, _amount);
        emit Transfer(_account, address(0), _amount);
        return true;
    }

    /**
     * @dev Function to set fee
     * @param _fee The fee.
     * @return A boolean that indicates if the operation was successful.
     */
    function setFee(uint256 _fee) onlyOwner public returns (bool)    {
        fee = _fee;
        return true;
    }
    /**
     * @dev Function to add no fee accounts
     * @param addr The address that will add to noFeeAddress.
     * @return A boolean that indicates if the operation was successful.
     */
    function addNoFeeAddress(address addr) onlyOwner public returns (bool)    {
        require(!noFeeAddress[addr], "Already in the list");
        noFeeAddress[addr] = true;
        return true;
    }
    /**
     * @dev Function to remove no fee accounts
     * @param addr The address that will remove from noFeeAddress.
     * @return A boolean that indicates if the operation was successful.
     */
    function removeNoFeeAddress(address addr) onlyOwner public returns (bool)    {
        require(noFeeAddress[addr], "Not in the list");
        noFeeAddress[addr] = false;
        return true;
    }
}