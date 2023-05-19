// ██████╗ ██████╗ ██╗███████╗███╗   ███╗ █████╗     ███████╗██╗███╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗
// ██╔══██╗██╔══██╗██║██╔════╝████╗ ████║██╔══██╗    ██╔════╝██║████╗  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝
// ██████╔╝██████╔╝██║███████╗██╔████╔██║███████║    █████╗  ██║██╔██╗ ██║███████║██╔██╗ ██║██║     █████╗
// ██╔═══╝ ██╔══██╗██║╚════██║██║╚██╔╝██║██╔══██║    ██╔══╝  ██║██║╚██╗██║██╔══██║██║╚██╗██║██║     ██╔══╝
// ██║     ██║  ██║██║███████║██║ ╚═╝ ██║██║  ██║    ██║     ██║██║ ╚████║██║  ██║██║ ╚████║╚██████╗███████╗
// ╚═╝     ╚═╝  ╚═╝╚═╝╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝

// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract PrismaCharity is Ownable {
  /**
   * @notice Address of Prisma Token
   * @dev Points at the Prisma Token Proxy
   */
  address private constant _prismaProxy =
    0xB7ED90F0BE22c7942133404474c7c41199C08a2D;

  /**
   * @notice Retrieves ERC20 tokens from this contract and sends them to another address
   * Ensures that the 200,000 tokens initially allocated to the charity cannot be withdrawn
   * @dev This function can only be called by the owner of the contract
   * It throws if trying to withdraw to the zero address or if trying to withdraw Prisma Tokens
   * such that the Prisma Token balance is lower than 200_000 after the withdrawal
   * @param token The address of the ERC20 token to retrieve
   * @param dst The address to send the tokens to
   * @param amount The amount of tokens to send
   */
  function retrieveERC20(
    address token,
    address dst,
    uint256 amount
  ) external onlyOwner {
    require(dst != address(0x0), "Cannot send to zero address");
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (token == _prismaProxy) {
      require(
        balance - amount > (200_000 * (10 ** 18)),
        "Cannot withdraw initial charity funds"
      );
    }
    IERC20(token).transfer(dst, amount);
  }

  /**
   * @notice Retrieves all BNB from this contract and sends them to another address
   * @dev This function can only be called by the owner of the contract
   * @param dst The address to send the BNB to
   * @return success A boolean indicating whether the operation was successful
   */
  function retrieveBNB(address dst) external onlyOwner returns (bool success) {
    require(dst != address(0x0), "Cannot send to zero address");
    uint256 balance = address(this).balance;
    (success, ) = payable(address(dst)).call{value: balance}("");
    require(success, "Could not retrieve.");
  }
}