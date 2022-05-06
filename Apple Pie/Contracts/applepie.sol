// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";
import "./IPinkAntiBot.sol";
contract ApplePie is ERC20, Ownable {
    using SafeERC20 for IERC20;
    IPinkAntiBot public pinkAntiBot;
    bool public antiBotEnabled;
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply,
        address pinkAntiBot_
    )  ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply * (10 ** 18) );
        pinkAntiBot = IPinkAntiBot(pinkAntiBot_);
    // Register the deployer to be the token owner with PinkAntiBot. You can
    // later change the token owner in the PinkAntiBot contract
  pinkAntiBot.setTokenOwner(msg.sender);
  antiBotEnabled = true;
  // Pink sale ANTI BOT contract address
        // BSC: 0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002
        //BSC_TESTNET: 0xbb06F5C7689eA93d9DeACCf4aF8546C4Fe0Bf1E5
    }
    // Checking blacklist before transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        if (antiBotEnabled) {
        pinkAntiBot.onPreTransferCheck(from, to, amount);
        }
        super._beforeTokenTransfer(from, to, amount);
    }
    function clearTokens(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(this), "Cannot clear same tokens as Class");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
    function setEnableAntiBot(bool _enable) external onlyOwner {
   antiBotEnabled = _enable;
 }
}