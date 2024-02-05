/**
 * @title STABLE MINTER
 * @author - <USDFI TEAM>
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity =0.8.19;

interface STABLE {
    function mint(address account, uint256 amount) external;
}

contract STABLE_MINTER is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] public receiver;
    uint16[] public percent;

    uint256 public createdTokens;
    uint256 public miningPerSecond;
    uint256 public lastTriggerTime;

    uint256 public constant MAX_MINING_RATE = 2314814814814800;
    address public constant Token = 0xa3870fbBeb730BA99e4107051612af3465CA9F5e;
    uint16 public constant TOTAL_PERCENT = 10000;

    event MiningPerSecondChanged(uint256 newRate);
    event ReceiverAndPercentChanged(
        address[] newReceivers,
        uint16[] newPercents
    );
    event TokensMinted(address indexed receiver, uint256 amount);

    constructor() {
        lastTriggerTime = block.timestamp;
        miningPerSecond = MAX_MINING_RATE;
    }

    function createNewSTABLE() public {
        _mintTokens();
    }

    function checkTime() public view returns (uint256) {
        return block.timestamp - lastTriggerTime;
    }

    function checkMining() public view returns (uint256) {
        return checkTime() * miningPerSecond;
    }

    function setMiningPerSecond(uint256 _miningPerSecond) external onlyOwner {
        require(
            _miningPerSecond <= MAX_MINING_RATE,
            "must be smaller than the start value"
        );
        miningPerSecond = _miningPerSecond;
        emit MiningPerSecondChanged(_miningPerSecond);
    }

    function _mintTokens() internal nonReentrant {
        if (block.timestamp > lastTriggerTime + 600) {
            uint256 totalMintAmount = checkMining();
            for (uint256 i = 0; i < receiver.length; i++) {
                uint256 amountToMint = (totalMintAmount * percent[i]) / TOTAL_PERCENT;
                createdTokens += amountToMint;
                STABLE(Token).mint(receiver[i], amountToMint);
                emit TokensMinted(receiver[i], amountToMint);
            }
            lastTriggerTime = block.timestamp;
        }
    }

    function setReceiverAndPercent(
        address[] memory _receiverAddress,
        uint16[] memory _percent
    ) external onlyOwner {
        require(
            _receiverAddress.length == _percent.length,
            "Arrays must have the same length"
        );
        uint256 totalPercent = 0;
        for (uint256 i = 0; i < _percent.length; i++) {
            totalPercent = totalPercent + _percent[i];
        }
        require(totalPercent == TOTAL_PERCENT, "must be 100%");
        receiver = _receiverAddress;
        percent = _percent;
        emit ReceiverAndPercentChanged(_receiverAddress, _percent);
    }
}