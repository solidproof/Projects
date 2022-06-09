// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Token.sol";

contract Airdrop is Ownable {
    using SafeMath for uint;

    address public tokenAddr; // The token address

    event EtherTransfer(address beneficiary, uint amount);

    constructor(address _tokenAddr) public {
        // this is where you input the token address you want to airdroped
        require(_tokenAddr != address(0));
        tokenAddr = _tokenAddr;
    }

     /**
     * @dev dropTokens airdrop ERC20 tokens to multiple addresses
     * @param _recipients is the array of list of addresses you want airdrop tokens to 
     * @param _amount is the array of list of amount of token you want to airdrop to each address 
     */
    function dropTokens(address[] memory _recipients, uint256[] memory _amount) public onlyOwner returns (bool) {
       
        for (uint i = 0; i < _recipients.length; i++) {

            // Transfer the tokens
            require(_recipients[i] != address(0));
            require(Token(tokenAddr).transfer(_recipients[i], _amount[i]));
        }

        return true;
    }
 
    /**
     * @dev updateTokenAddress is to change the initial token address to another token address
     * @param newTokenAddr is the new token address 
    */
    function updateTokenAddress(address newTokenAddr) public onlyOwner {
        // when LIXX platform want to airdrop another
        // token the owner will use this for updating the token address
        require(newTokenAddr != address(0));
        tokenAddr = newTokenAddr;
    }

     /**
     * @dev withdrawTokens is to withdraw token from the contract address
     * @param beneficiary is the wallet address you want to send it to
    */
    function withdrawTokens(address beneficiary) public onlyOwner {
        // withdraw tokens from contract address
        // Transfer the balance of the token to the wallet address
        require(beneficiary != address(0));
        require(Token(tokenAddr).transfer(beneficiary, Token(tokenAddr).balanceOf(address(this))));
    }

}
