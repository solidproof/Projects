pragma solidity =0.6.6;

import "../interfaces/IArthurRouter.sol";

contract RouterEventEmitter {
    event Amounts(uint[] amounts);

    receive() external payable {}

    function swapExactTokensForTokens(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
            IArthurRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens.selector, amountIn, amountOutMin, path, to, address(0), false, deadline
        ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapExactETHForTokens(
        address router,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
            IArthurRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens.selector, amountOutMin, path, to, address(0), false, deadline
        ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

    function swapExactTokensForETH(
        address router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external {
        (bool success, bytes memory returnData) = router.delegatecall(abi.encodeWithSelector(
            IArthurRouter(router).swapExactTokensForETHSupportingFeeOnTransferTokens.selector, amountIn, amountOutMin, path, to, address(0), false, deadline
        ));
        assert(success);
        emit Amounts(abi.decode(returnData, (uint[])));
    }

}
