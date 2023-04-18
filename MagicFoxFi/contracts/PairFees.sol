// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import './interfaces/IERC20.sol';

// Pair Fees contract is used as a 1:1 pair relationship to split out fees, this ensures that the curve does not need to be modified for LP shares
contract PairFees {

    address internal immutable pair; // The pair it is bonded to
    address internal immutable token0; // token0 of pair, saved localy and statically for gas optimization
    address internal immutable token1; // Token1 of pair, saved localy and statically for gas optimization

    uint256 public toOwner0;
    uint256 public toOwner1;

    constructor(address _token0, address _token1) {
        pair = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    function _safeTransfer(address token,address to,uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    // Allow the pair to transfer fees to users
    function claimFeesFor(address recipient, uint amount0, uint amount1) external {
        require(msg.sender == pair);
        if (amount0 > 0) _safeTransfer(token0, recipient, amount0);
        if (amount1 > 0) _safeTransfer(token1, recipient, amount1);
    }

    function processOwnerFees(uint amount, bool isTokenZero) external {
        require(msg.sender == pair);
        if(amount > 0 && isTokenZero){
            toOwner0 += amount;
        }
    
        if(amount > 0 && !isTokenZero){
            toOwner1 += amount;
        }

    }

    function withdrawOwnerFees(address recipient) external {
        require(msg.sender == pair);
        if (toOwner0 > 0){
            _safeTransfer(token0, recipient, toOwner0);
            toOwner0 = 0;
        } 
        if (toOwner1 > 0){
            _safeTransfer(token1, recipient, toOwner1);
            toOwner1 = 0;
        }
    }

      

}
