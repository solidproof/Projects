// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TransferHelper.sol";
import "./Bridge.sol";

contract Master is Ownable {
    uint256 public totalBridges;
    address public treasury;

    event BridgeCreated(address _address, uint256 _when, uint256 _chainId);
    event ERC20Transfer(
        address _token,
        address _to,
        uint256 _howmuch
    );
    event ETHTransfer(address _to, uint256 _howmuch);
    event TreasuryUpdated(address _old, address _new);

    constructor(address _treasury) {
        emit TreasuryUpdated(treasury, _treasury);
        treasury = _treasury;
    }

    function createBridge(
        address _token,
        address _verifier,
        address _governance,
        address _vault,
        uint256 _fee
    ) external onlyOwner {
        require(
            _token != address(0),
            "MasterBridge:: createBridge :: Invalid _token"
        );
        require(
            _verifier != address(0),
            "MasterBridge:: createBridge :: Invalid _verifier"
        );
        require(
            _governance != address(0),
            "MasterBridge:: createBridge :: Invalid _governance"
        );
        require(
            _vault != address(0),
            "MasterBridge:: createBridge :: Invalid _vault"
        );
        Bridge _bridge = new Bridge(
            address(this),
            _token,
            _verifier,
            _governance,
            _vault,
            _fee
        );
        totalBridges = totalBridges + 1;
        emit BridgeCreated(address(_bridge), block.timestamp, block.chainid);
    }

    function withdrawERC20(address _token, address _to) external onlyOwner {
        uint256 _total = IERC20(_token).balanceOf(address(this));
        TransferHelper.safeTransfer(_token, _to, _total);
        emit ERC20Transfer(_token, _to, _total);
    }

    function withdrawETH(address _to) external onlyOwner {
        uint256 _total = address(this).balance;
        TransferHelper.safeTransferETH(_to, _total);
        emit ETHTransfer(_to, _total);
    }

    function updateTreasury(address _newTreasury) external onlyOwner {
        require(
            _newTreasury != address(0),
            "MasterBridge :: updateTreasury :: Invalid address"
        );
        emit TreasuryUpdated(treasury, _newTreasury);
        treasury = _newTreasury;
    }

    function getTreasury() public view returns (address) {
        return treasury;
    }
}