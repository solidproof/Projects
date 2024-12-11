// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHLAWStaking {
    function distributeBoost(uint256 _amount) external;
}

contract HLAWBoost is Ownable {
    IERC20 public hlawToken;
    IHLAWStaking public hlawStaking;
    address public signer;
    uint256 public startTime;
    uint256 public distributeTime;

    event BoostDistributed(uint256 amount);
    event SignerUpdated(address signer);
    event DistributeTimeUpdated(uint256 startTime, uint256 distributeTime);

    /**
     * @dev Constructor that sets the HLAW token address.
     * @param _hlawToken Address of the HLAW token contract.
     */
    constructor(address _hlawToken, address _hlawStaking) Ownable(msg.sender) {
        hlawToken = IERC20(_hlawToken);
        hlawStaking = IHLAWStaking(_hlawStaking);
        hlawToken.approve(address(hlawStaking), type(uint256).max);
        signer = msg.sender;
    }

    /**
     * @dev Distributes HLAW tokens to instant boost reward distribution.
     */
    function distributeBoost() external {
        require(msg.sender == signer, "Only signer can distribute boost");
        require(
            block.timestamp >= distributeTime,
            "Distribute time has not passed."
        );

        hlawStaking.distributeBoost(hlawToken.balanceOf(address(this)));

        emit BoostDistributed(hlawToken.balanceOf(address(this)));
    }

    /**
     * @dev Sets the signer address.
     * @param _signer Address of the new signer.
     */
    function setSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Invalid address set.");
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    /**
     * @dev Sets the timestamp you want distributeBoost to be called.
     * @param _distributeTime epoch timestamp for when distributeBoost will be called
     */
    function setDistributeTime(
        uint256 _startTime,
        uint256 _distributeTime
    ) external onlyOwner {
        startTime = _startTime;
        distributeTime = _distributeTime;
        require(
            startTime < distributeTime,
            "Start time must be before distribute time."
        );

        emit DistributeTimeUpdated(_startTime, _distributeTime);
    }
}
