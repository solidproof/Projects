//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DPADStakingContract {
    IERC20 constant token = IERC20(0x601564b128C5bc2F3aB7e0E6FaB474625354f54c);

    struct Stake {
        uint8 amount;
        uint32 endAt;
    }

    mapping (address => Stake) stakes;
    address[] users;

    function _stake(address _user, uint8 _amount) internal {
        require(token.transferFrom(_user, address(this), (_amount - stakes[_user].amount)*1e18), 'DS: Token transfer failed');
        stakes[_user].amount = _amount;
        stakes[_user].endAt = uint32(block.timestamp + 30 days);
    }

    function stake(uint8 _amount) external {
        require(_amount == 120 || _amount == 320 || _amount == 520, 'DS: Can only stake 120, 320 or 520 DPAD');
        require(stakes[msg.sender].amount < _amount, 'DS: Can not downgrade stake');
        _stake(msg.sender, _amount);
    }

    function _unstake(address _user) internal {
        require(token.transfer(_user, stakes[_user].amount*1e18), 'DS: Token transfer failed');
        delete stakes[_user];
    }

    function unstake() external {
        require(stakes[msg.sender].amount > 0, 'DS: No stakes');
        require(stakes[msg.sender].endAt <= block.timestamp, 'DS: staking is not over');

        _unstake(msg.sender);
    }

    function getUserCount() external view returns (uint) {
        return users.length;
    }
}
