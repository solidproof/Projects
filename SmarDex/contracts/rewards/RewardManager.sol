// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// contracts
import "./FarmingRange.sol";
import "./Staking.sol";

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IRewardManager.sol";

/**
 * @title RewardManager
 * @notice RewardManager handles de creation of the contract staking and farming, automatically create a campaignInfo
 * in the farming for the staking, at slot 0 and initialize farming. The RewardManager is the owner of the funds in
 * the FarmingRange, only the RewardManager is capable of sending funds to be farmed and only the RewardManager will get
 * the funds back when updating of removing campaigns.
 */
contract RewardManager is IRewardManager {
    bytes4 private constant TRANSFER_OWNERSHIP_SELECTOR = bytes4(keccak256(bytes("transferOwnership(address)")));

    IFarmingRange public immutable farming;
    IStaking public immutable staking;

    /**
     * @param _farmingOwner address who will own the farming
     * @param _smardexToken address of the smardex token
     * @param _startFarmingCampaign block number the staking pool in the farming will start to give rewards
     */
    constructor(address _farmingOwner, IERC20 _smardexToken, uint256 _startFarmingCampaign) {
        farming = new FarmingRange(address(this));
        staking = new Staking(_smardexToken, farming);
        farming.addCampaignInfo(staking, _smardexToken, _startFarmingCampaign);
        staking.initializeFarming();

        address(farming).call(abi.encodeWithSelector(TRANSFER_OWNERSHIP_SELECTOR, _farmingOwner));
    }

    /// @inheritdoc IRewardManager
    function resetAllowance(uint256 _campaignId) external {
        require(_campaignId < farming.campaignInfoLen(), "RewardHolder:campaignId:wrong campaign ID");

        (, IERC20 rewardToken, , , , , ) = farming.campaignInfo(_campaignId);
        rewardToken.approve(address(farming), type(uint256).max);
    }
}
