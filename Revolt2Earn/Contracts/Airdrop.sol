// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Airdrop is Ownable {

    // airdrop token contract address
    address public tokenAddr;

    event Transfer(address beneficiary, uint amount);
    event TokenAddress(address _oldToken, address _newToken);

    /**
      * @notice Used to initialize the contract
      * @param _tokenAddr The address of the airdrop token
      */
    constructor(address _tokenAddr) {
        require(_tokenAddr != address(0), "Invalid token address");
        tokenAddr = _tokenAddr;
    }

    /**
      * @notice dropTokens used to airdrop in batch
      * @param _recipients list of recipients
      * @param _amount list of amount
      */
    function dropTokens(address[] memory _recipients, uint256[] memory _amount) public onlyOwner returns (bool) {
        require(_recipients.length == _amount.length, "Invalid data");
        for (uint i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0), "Invalid recipients address");
            require(IERC20(tokenAddr).transfer(_recipients[i], _amount[i]));
            emit Transfer(_recipients[i], _amount[i]);
        }
        return true;
    }

    /**
      * @notice updateTokenAddress used to update airdrop token
      * @param _newTokenAddr new airdrop token address
      */
    function updateTokenAddress(address _newTokenAddr) public onlyOwner {
        emit TokenAddress(tokenAddr, _newTokenAddr);
        tokenAddr = _newTokenAddr;
    }

    /**
      * @notice withdrawTokens used to withdraw all smart contract airdrop tokens by admin
      * @param beneficiary recipient address
      * @param _amount receive token amount
      */
    function withdrawTokens(address beneficiary, uint256 _amount) public onlyOwner {
        require(IERC20(tokenAddr).balanceOf(address(this)) >= _amount, "Insufficient fund");
        require(IERC20(tokenAddr).transfer(beneficiary, _amount));
    }
}