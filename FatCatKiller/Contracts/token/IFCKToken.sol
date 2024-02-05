// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./ITokenomicsToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IFCKToken is ITokenomicsToken {
    function teamAndAdvisorsCap() external view returns (uint256);

    function marketingReserveCap() external view returns (uint256);

    function platformReserveCap() external view returns (uint256);

    function launchedAt() external view returns (uint256);

    function launched() external view returns (bool);

    function launch() external returns (bool);

    function mint(address account, uint256 amount) external;

    function pause() external;

    function unpause() external;

    function maxTxAmount() external view returns (uint256);

    function setMaxTxAmount(uint256 maxTxAmount_) external;

    function maxWalletBalance() external view returns (uint256);

    function setMaxWalletBalance(uint256 maxWalletBalance_) external;

    function isTxLimitExempt(address account) external view returns (bool);

    function setIsTxLimitExempt(address recipient, bool exempt) external;

    event Minted(address indexed account, uint256 amount);

    event Launched(uint256 launchedAt);

    event FeePayment(address indexed sender, uint256 balance, uint256 fee);
}
