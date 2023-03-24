// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// contracts
import "./SmardexPair.sol";

// interfaces
import "./interfaces/ISmardexFactory.sol";

/**
 * @title SmardexFactory
 * @notice facilitates creation of SmardexPair to swap tokens.
 */
contract SmardexFactory is ISmardexFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    ///@inheritdoc ISmardexFactory
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    ///@inheritdoc ISmardexFactory
    function createPair(address _tokenA, address _tokenB) external returns (address pair_) {
        require(_tokenA != _tokenB, "SmarDex: IDENTICAL_ADDRESSES");
        (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(_token0 != address(0), "SmarDex: ZERO_ADDRESS");
        require(getPair[_token0][_token1] == address(0), "SmarDex: PAIR_EXISTS"); // single check is sufficient
        bytes32 _salt = keccak256(abi.encodePacked(_token0, _token1));
        SmardexPair pair = new SmardexPair{ salt: _salt }();
        pair.initialize(_token0, _token1);
        pair_ = address(pair);
        getPair[_token0][_token1] = pair_;
        getPair[_token1][_token0] = pair_; // populate mapping in the reverse direction
        allPairs.push(pair_);
        emit PairCreated(_token0, _token1, pair_, allPairs.length);
    }

    ///@inheritdoc ISmardexFactory
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "SmarDex: FORBIDDEN");
        feeTo = _feeTo;
    }

    ///@inheritdoc ISmardexFactory
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "SmarDex: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
