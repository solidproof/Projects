// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import './interfaces/IPairFactory.sol';
import './Pair.sol';

contract PairFactory is IPairFactory {

    struct Partner {
        address partner;
        uint256 fee;
    }

    bool public isPaused;

    uint256 public stableFee;
    uint256 public volatileFee;
    uint256 public degenFee;
    uint256 public ownerFee;
    uint256 public MAX_PARTNER_FEE = 5000; // 50%
    uint256 public constant MAX_FEE = 25; // 0.25%
    uint256 public constant MAX_DEGEN_FEE = 100; // 1%

    address public feeManager;
    address public pendingFeeManager;
    address public ownerFeeHandler;   // owner fee handler
    mapping(address => Partner) public lpPartner; // LP-address => Partner

    mapping(address => mapping(address => mapping(bool => address))) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals

    address internal _temp0;
    address internal _temp1;
    bool internal _temp;

    event PairCreated(address indexed token0, address indexed token1, bool stable, address pair, uint);

    constructor() {
        isPaused = false;
        feeManager = msg.sender;
        ownerFeeHandler = msg.sender;
        stableFee = 4; // 0.04%
        volatileFee = 18; // 0.18%
        degenFee = 100; // 1%
        ownerFee = 3000; // 30% of stable/volatileFee
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function pairs() external view returns(address[] memory ){
        return allPairs;
    }

    function setPause(bool _state) external {
        require(msg.sender == feeManager);
        isPaused = _state;
    }

    function setFeeManager(address _feeManager) external {
        require(msg.sender == feeManager, 'not fee manager');
        pendingFeeManager = _feeManager;
    }

    function acceptFeeManager() external {
        require(msg.sender == pendingFeeManager, 'not pending fee manager');
        feeManager = pendingFeeManager;
    }


    function setOwnerFee(uint256 _newFee) external {
        require(msg.sender == feeManager, 'not fee manager');
        require(_newFee <= 3000);
        ownerFee = _newFee;
    }

    function setOwnerFeeAddress(address _feehandler) external {
        require(msg.sender == feeManager, 'not fee manager');
        require(_feehandler != address(0), 'addr 0');
        ownerFeeHandler = _feehandler;
    }

    function setPartner(address _lp, address _partner, uint256 _fee) external {
        require(msg.sender == feeManager, 'not fee manager');
        require(_lp != address(0), 'address zero');
        require(_fee <= MAX_PARTNER_FEE, 'fee too high');
        lpPartner[_lp] = Partner({
            partner: _partner,
            fee: _fee
        });
    }

    function setFee(bool _stable, uint256 _fee) external {
        require(msg.sender == feeManager, 'not fee manager');
        require(_fee <= MAX_FEE, 'fee too high');
        require(_fee != 0, 'fee must be nonzero');
        if (_stable) {
            stableFee = _fee;
        } else {
            volatileFee = _fee;
        }
    }

    function setDegenFee(uint256 _degen) external {
        require(msg.sender == feeManager, 'not fee manager');
        require(_degen != 0, 'fee must be nonzero');
        require(_degen <= MAX_DEGEN_FEE);
        degenFee = _degen;
    }

    function getFee(bool _stable, bool _degen) public view returns(uint256) {
        if (_stable) {
            return stableFee;
        }
        return _degen ? degenFee : volatileFee;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    function getInitializable() external view returns (address, address, bool) {
        return (_temp0, _temp1, _temp);
    }

    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair) {
        require(tokenA != tokenB, 'IA'); // Pair: IDENTICAL_ADDRESSES
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZA'); // Pair: ZERO_ADDRESS
        require(getPair[token0][token1][stable] == address(0), 'PE'); // Pair: PAIR_EXISTS - single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable)); // notice salt includes stable as well, 3 parameters
        (_temp0, _temp1, _temp) = (token0, token1, stable);
        pair = address(new Pair{salt:salt}());
        getPair[token0][token1][stable] = pair;
        getPair[token1][token0][stable] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, stable, pair, allPairs.length);
    }
}
