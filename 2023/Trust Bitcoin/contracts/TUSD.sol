// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.6;

contract Ownable {
    address public owner;
	
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
	
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}

interface ITBC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TBC20Basic is ITBC20, Ownable {
    
	uint256 circulatingSupply;
	
	mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
	
    function totalSupply() public override view returns (uint256) {
       return circulatingSupply ;
    }
	
    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }
	
    function transfer(address receiver, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[msg.sender], "Transfer amount exceeds balance");
		require(receiver != address(0), "Transfer from the zero address");
		
        balances[address(msg.sender)] -= numTokens;
        balances[address(receiver)] += numTokens;
        emit Transfer(address(msg.sender), address(receiver), numTokens);
        return true;
    }

    function approve(address spender, uint256 numTokens) public override returns (bool) {
        allowed[address(msg.sender)][address(spender)] = numTokens;
        emit Approval(address(msg.sender), address(spender), numTokens);
        return true;
    }

    function allowance(address owner, address spender) public override view returns (uint) {
        return allowed[address(owner)][address(spender)];
    }
	
    function transferFrom(address sender, address receiver, uint256 numTokens) public override returns (bool) {
		require(numTokens <= balances[sender], "Transfer amount exceeds balance");
        require(numTokens <= allowed[sender][msg.sender], "Transfer amount exceeds allowance");
		require(receiver != address(0), "Transfer from the zero address");
		
        balances[address(sender)] -= numTokens;
		balances[address(receiver)] += numTokens;
        allowed[address(sender)][address(msg.sender)] -= numTokens;
		
        emit Transfer(address(sender), address(receiver), numTokens);
        return true;
    }
	
	function mint(uint256 numTokens) public onlyOwner{
	    require(numTokens + circulatingSupply <= 2100000000 * 10**18, "Mint limit exceeds");
		
        circulatingSupply += numTokens;
        balances[address(msg.sender)] += numTokens;
        emit Transfer(address(0), address(msg.sender), numTokens);
    }
}

contract TUSD is TBC20Basic {
    string public constant name = "Trust USD";
    string public constant symbol = "TUSD";
    uint8 public constant decimals = 18;
	
	constructor(address receiver) {
	   owner = address(receiver);
       circulatingSupply = 210000000 * 10**18;
       balances[address(receiver)] = circulatingSupply;
	   emit Transfer(address(0), address(receiver), circulatingSupply);
   }
}