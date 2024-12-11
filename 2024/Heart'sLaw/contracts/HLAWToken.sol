// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HeartsLaw is ERC20, Ownable {
    constructor() ERC20("Hearts Law", "HLAW") Ownable(msg.sender) {}

    address public hlawExchange;
    bool private initialized;

    /**
     * @dev Sets exchangeContract that has access to Burn and Mint functions.
     * Can only be called one time after deployment by the contract owner.
     */
    function init(address _hlawExchange) external onlyOwner {
        require(!initialized, "Can only initialize once!");
        hlawExchange = _hlawExchange;

        initialized = true;
    }

    /**
     * @dev Mints `amount` tokens to the specified `account`.
     * Can only be called by the owner of the contract.
     */
    function mint(address account, uint256 amount) external {
        require(
            msg.sender == hlawExchange,
            "Only the HLAW Exchange Contract can mint HLAW."
        );
        _mint(account, amount);
    }

    /**
     * @dev Burns `amount` tokens from the caller's account.
     */
    function burn(uint256 amount) external {
        require(
            msg.sender == hlawExchange,
            "Only the HLAW Exchange Contract can burn HLAW."
        );
        _burn(msg.sender, amount);
    }

    /**
     * @dev Allows owner to recover any PLS accidentally sent directly to this contract.
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
     * @dev Allows owner to recover any tokens accidentally sent directly to this contract.
     */
    function withdrawTokens(address _token) public onlyOwner {
        require(_token != address(0), "Invalid parameter is provided.");
        IERC20 token = IERC20(_token);
        uint256 amount = token.balanceOf(address(this));

        token.transfer(address(msg.sender), amount);
    }
}
