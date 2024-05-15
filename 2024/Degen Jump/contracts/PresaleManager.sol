// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./CommonERC20.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import {INonfungiblePositionManager} from "@cryptoalgebra/integral-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./PresaleReleaseExcutor.sol";

contract PresaleManager is IERC721Receiver {
    PresaleReleaseExcutor public releaseExecutor;
    address public immutable WNativeToken;
    mapping(address => Presale) public presales;
    INonfungiblePositionManager public positionManager;

    constructor(address _WNativeToken, INonfungiblePositionManager _positionManager) {
        WNativeToken = _WNativeToken;
        positionManager = _positionManager;
        releaseExecutor = new PresaleReleaseExcutor(_positionManager, _WNativeToken, this);
    }

    function putPresale(Presale memory presale) external {
        require(presales[presale.pair].presaleAmount == 0, "PresaleManager: already exists");
        presales[presale.pair] = presale;
        positionManager.transferFrom(msg.sender, address(this), presale.positionTokenId);

        emit PresaleCreated(
            msg.sender,
            presale.name,
            presale.symbol,
            presale.presaleAmount,
            presale.token,
            presale.pair,
            presale.totalSupply,
            presale.minterAllocation,
            presale.data
        );
    }

    function getPresale(address pair) external view returns (Presale memory) {
        return presales[pair];
    }

    function getProgress(address poolAddress) public view returns (uint256) {
        IAlgebraPool pool = IAlgebraPool(poolAddress);
        Presale memory presale = presales[poolAddress];
        (uint256 reserve0, uint256 reserve1) = pool.getReserves();

        if (pool.token0() == WNativeToken) {
            return (100 * reserve0) / presale.presaleAmount;
        } else {
            return (100 * reserve1) / presale.presaleAmount;
        }
    }

    function release(address poolAddress) external {
        uint256 progress = getProgress(poolAddress);
        require(progress >= 100, "PresaleManager : progress is not enough");
        uint256 tokenId = presales[poolAddress].positionTokenId;
        positionManager.transferFrom(address(this), address(releaseExecutor), tokenId);
        releaseExecutor.release(poolAddress);
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    event PresaleCreated(
        address from,
        string name,
        string symbol,
        uint256 presaleAmount,
        address token,
        address pairAddress,
        uint256 totalSupply,
        uint256 minterAllocation,
        string data
    );
}

struct Presale {
    string name;
    string symbol;
    uint256 presaleAmount;
    address token;
    address pair;
    uint256 totalSupply;
    uint256 minterAllocation;
    string data;
    uint256 positionTokenId;
    bool released;
}