pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IToken is IERC20 {
    function mint(address _to, uint256 _amount) external;
}
