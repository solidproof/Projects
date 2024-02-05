// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC20Facet } from "./diamond/interfaces/IERC20Facet.sol";
import { IRouter02 } from "./interfaces/IRouter02.sol";
import { IFactory } from "./interfaces/IFactory.sol";

/// @custom:version 1.0.0
contract LaunchControl is Ownable {
    using Address for address payable;

    bool public launched = false;
    bool public liquidity = false;
    uint256 public startPoolWithToken = 0;
    uint256 public startPoolWithNative = 0;
    address public router;
    address public lp;
    address public lpTokenReceiver;
    address public token; // diamond address is token address

    /// admin

    function recover(address _asset) external onlyOwner {
        uint256 _balanceA = address(this).balance;
        if (_balanceA > 0) payable(owner()).sendValue(_balanceA);
        uint256 _balanceB = IERC20(_asset).balanceOf(address(this));
        if (_balanceB > 0) IERC20(_asset).transfer(owner(), _balanceB);
    }

    function setRouter(address _router) external onlyOwner {
        router = _router;
    }

    function setToken(address _token) external onlyOwner {
        if (router == address(0)) revert("missing router");
        token = _token;
        lp = IFactory(IRouter02(router).factory()).createPair(token, IRouter02(router).WETH());
        IERC20Facet(token).setLP(lp);
    }

    function setStartPoolWithToken(uint256 _amount) external onlyOwner {
        startPoolWithToken = _amount;
    }

    function setStartPoolWithNative(uint256 _amount) external onlyOwner {
        startPoolWithNative = _amount;
    }

    function setLpTokenReceiver(address _account) external onlyOwner {
        lpTokenReceiver = _account;
    }

    function addLiquidity() external onlyOwner {
        if (lp == address(0) || token == address(0)) revert("set token first");
        if (lpTokenReceiver == address(0)) revert("lp token receiver not set");

        uint256 _balanceA = address(this).balance;
        if (_balanceA == 0 || startPoolWithNative == 0 || startPoolWithNative > _balanceA) revert("not enough native");

        uint256 _balanceB = IERC20(token).balanceOf(address(this));
        if (_balanceB == 0 || startPoolWithToken == 0 || startPoolWithToken > _balanceB) revert("not enough token");

        IERC20Facet(token).excludeAccountFromTax(address(this));
        IERC20(token).approve(router, startPoolWithToken);
        (uint256 amountToken, uint256 amountETH, ) = IRouter02(router).addLiquidityETH{ value: startPoolWithNative }(
            token,
            startPoolWithToken,
            startPoolWithToken,
            startPoolWithNative,
            lpTokenReceiver,
            block.timestamp + 60
        );
        IERC20Facet(token).disable();
        IERC20Facet(token).includeAccountForTax(address(this));

        if (amountToken != startPoolWithToken) revert("wrong amount of token");
        if (amountETH != startPoolWithNative) revert("wrong amount of native");

        liquidity = true;
    }

    function startTrading() external onlyOwner {
        if (token == address(0)) revert("no token");
        if (!liquidity) revert("no liquidity");
        IERC20Facet(token).enable();
        launched = true;
    }

    /// receiver
    receive() external payable {}
}
