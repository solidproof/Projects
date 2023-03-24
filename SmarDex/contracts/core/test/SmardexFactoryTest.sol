// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.8.17;

// contracts
import "../SmardexFactory.sol";
import "./SmardexPairTest.sol";

contract SmardexFactoryTest is SmardexFactory {
    constructor(address _feeToSetter) SmardexFactory(_feeToSetter) {}

    function createPairTest(address _tokenA, address _tokenB) external returns (address pair_) {
        require(_tokenA != _tokenB, "SmarDex: IDENTICAL_ADDRESSES");
        (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        require(_token0 != address(0), "SmarDex: ZERO_ADDRESS");
        require(getPair[_token0][_token1] == address(0), "SmarDex: PAIR_EXISTS"); // single check is sufficient
        bytes32 _salt = keccak256(abi.encodePacked(_token0, _token1));
        SmardexPairTest pair = new SmardexPairTest{ salt: _salt }();
        pair.initialize(_token0, _token1);
        pair_ = address(pair);
        getPair[_token0][_token1] = pair_;
        getPair[_token1][_token0] = pair_; // populate mapping in the reverse direction
        allPairs.push(pair_);
        emit PairCreated(_token0, _token1, pair_, allPairs.length);
    }
}
