// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMintableToken is IERC20 {
    function mint(address _account, uint256 _amount) external returns (uint);

    function burn(address _account, uint256 _amount) external returns (uint);
}
