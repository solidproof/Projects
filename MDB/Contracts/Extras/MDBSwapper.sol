//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "../IUniswapV2Router02.sol";
interface IERC20 {
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MDBSwapper {

    // MDB Token
    address public token;

    // router
    IUniswapV2Router02 router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    // path
    address[] path;

    constructor(address _token) {
        token = _token;
        path = new address[](2);
        path[0] = router.WETH();
        path[1] = _token;
    }

    function withdraw(address token) external {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function withdraw() external {
        (bool s,) = payable(msg.sender).call{value: address(this).balance}("");
        require(s);
    }

    function buyToken(address recipient, uint minOut) external payable {
        _buyToken(recipient, msg.value, minOut);
    }

    function buyToken(address recipient) external payable {
        _buyToken(recipient, msg.value, 0);
    }

    function buyToken() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    receive() external payable {
        _buyToken(msg.sender, msg.value, 0);
    }

    function _buyToken(address recipient, uint value, uint minOut) internal {
        require(
            value > 0,
            'Zero Value'
        );
        require(
            recipient != address(0),
            'Recipient Cannot Be Zero'
        );
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: value}(
            minOut,
            path,
            recipient,
            block.timestamp + 300
        );
    }
}