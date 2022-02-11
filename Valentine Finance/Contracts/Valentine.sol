// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./IERC20.sol";


contract Valentine is ERC20, Ownable {
    using SafeERC20 for IERC20;
    mapping(address => bool) _blacklist;
    event BlacklistUpdated(address indexed user, bool value);
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) public ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply * (10 ** 18) );
    }
// Check if address is blacklisted or not
    function isBlackListed(address user) public view returns (bool) {
        return _blacklist[user];
    }
    // Blacklist to block potentially known bots and scammers
    function blacklistUpdate(address user, bool value)
        public
        virtual
        onlyOwner
    {
        _blacklist[user] = value;
        emit BlacklistUpdated(user, value);
    }
    // Checking blacklist before transfer
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        require(
            !isBlackListed(to),
            "Token transfer refused. Receiver is on blacklist"
        );
        super._beforeTokenTransfer(from, to, amount);
    }
    function clearTokens(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(this), "Cannot clear same tokens as Class");
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }
}