// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IERC20MintableBurnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Denominator is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Balance {
        uint256 total;
        uint256 claimed;
    }

    address public seedAddress;
    address public metaSeedAddress;

    uint256 public supply;
    uint256 public minted;
    uint256 public denomenateValue;
    uint256 constant public vestingPeriod = 30 days;
    uint256 immutable public startDate;
    mapping(address=>Balance) public balances;

    constructor(address _seed, uint256 _startDate, address _metaSeed, uint256 _denomenateValue, uint256 _supply) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());

        seedAddress = _seed;
        metaSeedAddress = _metaSeed;
        denomenateValue = _denomenateValue;
        supply = _supply;
        startDate = _startDate;
    }

    function denominate(uint256 _amount) external {
        require(_amount > 0, "Zero amount");
        IERC20(seedAddress).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 denomenated = _amount * denomenateValue;
        balances[msg.sender].total += denomenated;
    }

    function getAvaliable(address _user) public view returns(uint256 avaliable) {
        uint256 elapsed = block.timestamp - startDate;
        if (elapsed >= vestingPeriod) avaliable = balances[_user].total - balances[_user].claimed;
        else avaliable = balances[_user].total * 20 / 100 + balances[_user].total * 80 / 100 * elapsed / vestingPeriod - balances[_user].claimed;
    }

    function claim(uint256 _amount) external nonReentrant {
        require(getAvaliable(msg.sender) >= _amount, "Amount greater than avaliable");
        require(minted+_amount <= supply, "Not enough tokens");
        balances[msg.sender].claimed += _amount;
        minted += _amount;
        IERC20MintableBurnable(metaSeedAddress).mint(msg.sender, _amount);
    }

    function setDenomenateValue(uint256 _value) external onlyRole(ADMIN_ROLE) {
        denomenateValue = _value;
    }

    function addSupply(uint256 _amount) external onlyRole(ADMIN_ROLE) {
        supply += _amount;
    }

    /// @notice transfer accidentally locked on contract ERC20 tokens
    function transferFromContract20(address _token, address _user, uint256 _amount) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "Caller is not admin");
        IERC20(_token).transfer(_user, _amount);
    }
}