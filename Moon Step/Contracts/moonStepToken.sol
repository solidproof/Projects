// SPDX-License-Identifier: moonstep.app
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

interface IPancakewapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract MoonStepToken  is ERC20Burnable, Ownable, AccessControlEnumerable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 public constant MAX_FEE_PER_THOUSAND = 100;    // max fee is 10%
    uint256 constant PRECISION = 1000;

    using SafeMath for uint;
    address public factoryAddress;
    address public pairToken;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) public ammPairs;

    uint256 private _totalFee;
    uint256 private _totalBurned;

    uint256 public buyTaxFee = 0;   // buy fee per thousand
    uint256 public sellTaxFee = 35; // sell fee per thousand = 3.5%
    uint256 public burnFee = 35;    // burn fee per thousand = 3.5%
    address public beneficiary;

    address public minter;
    bool public mintEnabled;
    event FeeDistributedEvent(address beneficiary, uint fee);
    event MinterChangedEvent(address newMinter);
    event MintableChangedEvent(bool mintable);
    event NewFeesChangedEvent(uint buyTaxFee, uint sellTaxFee, uint burnFee);

    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "Invalid operator");
        _;
    }

    constructor (address _beneficiary, address _factoryAddress, address _pairToken) ERC20("Satoshi Moon Step", "SMT") {
        factoryAddress = _factoryAddress;
        pairToken= _pairToken;
        address pairAddress = IPancakewapV2Factory(factoryAddress).createPair(address(this), pairToken);
        ammPairs[pairAddress] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        beneficiary = _beneficiary;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(OPERATOR_ROLE, msg.sender);
        _mint(msg.sender, 50_000_000 ether); // 10.000.000.000 $MSA
        mintEnabled = true;
    }

    fallback () external payable {
        revert(); // Not allow sending BNB to this contract
    }

    receive() external payable {
        revert(); // Not allow sending BNB to this contract
    }

    function getMaxFeePercentage() public pure returns(uint) {
        return MAX_FEE_PER_THOUSAND.mul(100).div(PRECISION); // convert feePer thousand to fee percentage
    }

    function mint(address to, uint amount) public {
        require(mintEnabled, "Mint: mint is not enabled");
        require(msg.sender == minter, "Mint: invalid minter");
        _mint(to, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {

        bool takeFee = true;
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            takeFee = false;
        }
        _tokenTransfer(sender, recipient, amount, takeFee);
    }

    function _getTaxFee(address sender, address recipient, bool takeFee) private view returns (uint){
        uint _taxFee = 0;
        if(takeFee) {
            bool isBuy = ammPairs[sender];
            bool isSell = ammPairs[recipient];
            if(isBuy){
                _taxFee = buyTaxFee;
            } else if(isSell){
                _taxFee = sellTaxFee;
            }
        }
        return _taxFee;
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {

        uint _taxFee = _getTaxFee(sender, recipient, takeFee);
        (uint actualAmount, uint fee, uint burnFeeAmount) = _getValues(amount, _taxFee);
        super._transfer(sender, recipient, actualAmount);

        if(fee > 0) {
            super._transfer(sender, beneficiary, fee);
            _totalFee = _totalFee.add(fee);
            emit FeeDistributedEvent(beneficiary, fee);
        }

        if(burnFeeAmount > 0) {
            super._burn(sender, burnFeeAmount);
            _totalBurned = _totalBurned.add(burnFeeAmount);
        }

    }

    /**
       Calculate actual amount recipient will receive and fee to beneficiary
    */
    function _getValues(uint256 transferAmount, uint taxFee) private view returns (uint256, uint256, uint256) {

        if(taxFee == 0) {
            return (transferAmount, 0, 0);
        }

        uint fee =  transferAmount.mul(taxFee).div(PRECISION);
        uint256 burnAmount = transferAmount.mul(burnFee).div(PRECISION);

        uint256 actualAmount = transferAmount.sub(fee, "Fee too high").sub(burnAmount, "Tax too high");
        return (actualAmount, fee, burnAmount);
    }


    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }


    function totalFees() public view returns (uint256) {
        return _totalFee;
    }

    function totalBurned() public view returns(uint256) {
        return _totalBurned;
    }

    function setTaxFeePercent(uint256 _buyTaxFee, uint256 _sellTaxFee, uint256 _burnFee) external onlyOperator {
        require(_buyTaxFee + _burnFee <= MAX_FEE_PER_THOUSAND, "Buy Tax Fee and Burn fee reached the maximum limit");
        require(_sellTaxFee + _burnFee <= MAX_FEE_PER_THOUSAND, "Sell Tax Fee and Burn fee reached the maximum limit");
        require(_burnFee <= MAX_FEE_PER_THOUSAND, "Burn Fee reached the maximum limit");
        buyTaxFee = _buyTaxFee;
        sellTaxFee = _sellTaxFee;
        burnFee = _burnFee;
        emit NewFeesChangedEvent(buyTaxFee, sellTaxFee, burnFee);
    }

    function addExcludesFee(address[] calldata accounts) public onlyOperator {
        for(uint i = 0 ; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = true;
        }
    }

    function removeExcludesFee(address[] calldata accounts) public onlyOperator {
        for(uint i = 0 ; i < accounts.length; i++) {
           delete _isExcludedFromFee[accounts[i]];
        }
    }

    function changeBeneficiary(address newBeneficiary) public onlyOperator {
        beneficiary = newBeneficiary;
    }

    function setupMinter(address newMinter) public onlyOperator {
        minter = newMinter;
        emit MinterChangedEvent(newMinter);
    }

    function enableMint(bool value) public onlyOperator {
        mintEnabled = value;
        emit MintableChangedEvent(mintEnabled);
    }
}