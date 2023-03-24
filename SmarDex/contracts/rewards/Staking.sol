// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./interfaces/IStaking.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Staking
 * @notice Implementation of an APY staking pool. Users can deposit SDEX for a share in the pool. New shares depend of
 * current shares supply and SDEX in the pool. Pool will receive SDEX rewards fees by external transfer from admin or
 * contract but also from farming pool. Each deposit/withdraw will harvest the user funds in the farming pool as well.
 */
contract Staking is IStaking, ERC20 {
    using SafeERC20 for IERC20;

    uint256 public constant CAMPAIGN_ID = 0;
    uint256 internal constant SHARES_FACTOR = 1e18;

    IERC20 public immutable smardexToken;
    IFarmingRange public immutable farming;

    mapping(address => UserInfo) public userInfo;
    uint256 public totalShares;
    bool public farmingInitialized = false;

    modifier isFarmingInitialized() {
        require(farmingInitialized == true, "Staking::isFarmingInitialized::Farming campaign not initialized");
        _;
    }

    modifier checkUserBlock() {
        require(
            userInfo[msg.sender].lastBlockUpdate < block.number,
            "Staking::checkUserBlock::User already called deposit or withdraw this block"
        );
        userInfo[msg.sender].lastBlockUpdate = block.number;
        _;
    }

    constructor(IERC20 _smardexToken, IFarmingRange _farming) ERC20("Staked SmarDex Token", "stSDEX") {
        smardexToken = _smardexToken;
        farming = _farming;
    }

    /// @inheritdoc IStaking
    function initializeFarming() external {
        require(farmingInitialized == false, "Staking::initializeFarming::Farming campaign already initialized");
        _approve(address(this), address(farming), 1 wei);
        _mint(address(this), 1 wei);
        farming.deposit(CAMPAIGN_ID, 1 wei);

        farmingInitialized = true;
    }

    /// @inheritdoc IStaking
    function deposit(uint256 _depositAmount) public isFarmingInitialized checkUserBlock {
        require(_depositAmount > 0, "Staking::deposit::can't deposit zero token");

        harvestFarming();

        uint256 _currentBalance = smardexToken.balanceOf(address(this));
        uint256 _newShares = _tokensToShares(_depositAmount, _currentBalance);

        smardexToken.safeTransferFrom(msg.sender, address(this), _depositAmount);

        totalShares += _newShares;
        userInfo[msg.sender].shares += _newShares;

        emit Deposit(msg.sender, _depositAmount, _newShares);
    }

    /// @inheritdoc IStaking
    function depositWithPermit(
        uint256 _depositAmount,
        bool _approveMax,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        SafeERC20.safePermit(
            IERC20Permit(address(smardexToken)),
            msg.sender,
            address(this),
            _approveMax ? type(uint256).max : _depositAmount,
            _deadline,
            _v,
            _r,
            _s
        );

        deposit(_depositAmount);
    }

    /// @inheritdoc IStaking
    function withdraw(address _to, uint256 _sharesAmount) external isFarmingInitialized checkUserBlock {
        require(
            _sharesAmount > 0 && userInfo[msg.sender].shares >= _sharesAmount,
            "Staking::withdraw::can't withdraw more than user shares or zero"
        );

        harvestFarming();

        uint256 _currentBalance = smardexToken.balanceOf(address(this));
        uint256 _tokensToWithdraw = _sharesToTokens(_sharesAmount, _currentBalance);

        userInfo[msg.sender].shares -= _sharesAmount;
        totalShares -= _sharesAmount;
        smardexToken.safeTransfer(_to, _tokensToWithdraw);

        emit Withdraw(msg.sender, _to, _tokensToWithdraw, _sharesAmount);
    }

    /// @inheritdoc IStaking
    function harvestFarming() public {
        farming.withdraw(CAMPAIGN_ID, 0);
    }

    /// @inheritdoc IStaking
    function tokensToShares(uint256 _tokens) external view returns (uint256 shares_) {
        uint256 _currentBalance = smardexToken.balanceOf(address(this));
        _currentBalance += farming.pendingReward(CAMPAIGN_ID, address(this));

        shares_ = _tokensToShares(_tokens, _currentBalance);
    }

    /// @inheritdoc IStaking
    function sharesToTokens(uint256 _shares) external view returns (uint256 tokens_) {
        uint256 _currentBalance = smardexToken.balanceOf(address(this));
        _currentBalance += farming.pendingReward(CAMPAIGN_ID, address(this));

        tokens_ = _sharesToTokens(_shares, _currentBalance);
    }

    /**
     * @notice Calculate shares qty for an amount of sdex tokens
     * @param _tokens user qty of sdex to be converted to shares
     * @param _currentBalance contract balance sdex. _tokens <= _currentBalance
     * @return shares_ shares equivalent to the token amount. _shares <= totalShares
     */
    function _tokensToShares(uint256 _tokens, uint256 _currentBalance) internal view returns (uint256 shares_) {
        shares_ = totalShares > 0 ? (_tokens * totalShares) / _currentBalance : _tokens * SHARES_FACTOR;
    }

    /**
     * @notice Calculate shares values in sdex tokens
     * @param _shares amount of shares. _shares <= totalShares
     * @param _currentBalance contract balance in sdex
     * @return tokens_ qty of sdex token equivalent to the _shares. tokens_ <= _currentBalance
     */
    function _sharesToTokens(uint256 _shares, uint256 _currentBalance) internal view returns (uint256 tokens_) {
        tokens_ = totalShares > 0 ? (_shares * _currentBalance) / totalShares : _shares / SHARES_FACTOR;
    }
}
