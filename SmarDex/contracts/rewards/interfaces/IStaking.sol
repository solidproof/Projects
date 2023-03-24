// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

// interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IFarmingRange.sol";

interface IStaking is IERC20 {
    /**
     * @notice iunfo of each user
     * @param shares shares owned in the staking
     * @param lastBlockUpdate last block the user called deposit or withdraw
     */
    struct UserInfo {
        uint256 shares;
        uint256 lastBlockUpdate;
    }

    /**
     * @notice emitted at each deposit
     * @param from address that deposit its funds
     * @param depositAmount amount deposited
     * @param shares shares corresponding to the token amount deposited
     */
    event Deposit(address indexed from, uint256 depositAmount, uint256 shares);

    /**
     * @notice emitted at each withdraw
     * @param from address that calls the withdraw function, and of which the shares are withdrawn
     * @param to address that receives the funds
     * @param tokenReceived amount of token received by to
     * @param shares shares corresponding to the token amount withdrawn
     */
    event Withdraw(address indexed from, address indexed to, uint256 tokenReceived, uint256 shares);

    /**
     * @notice Initialize staking connection with farming
     * Mint one token of stSDEX and then deposit in the staking farming pool
     * This contract should be the only participant of the staking farming pool
     */
    function initializeFarming() external;

    /**
     * @notice Send SDEX to get shares in the staking pool
     * @param _depositAmount The amount of SDEX to send
     */
    function deposit(uint256 _depositAmount) external;

    /**
     * @notice Send SDEX to get shares in the staking pool with the EIP-2612 signature off chain
     * @param _depositAmount The amount of SDEX to send
     * @param _approveMax Whether or not the approval amount in the signature is for liquidity or uint(-1).
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @param _v The v component of the permit signature.
     * @param _r The r component of the permit signature.
     * @param _s The s component of the permit signature.
     */
    function depositWithPermit(
        uint256 _depositAmount,
        bool _approveMax,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /**
     * @notice Harvest and withdraw SDEX for the amount of shares defined
     * @param _to The address who will receive SDEX
     * @param _sharesAmount The amount of shares to use
     */
    function withdraw(address _to, uint256 _sharesAmount) external;

    /**
     * @notice Harvest the farming pool for the staking, will increase the SDEX
     */
    function harvestFarming() external;

    /**
     * @notice Calculate shares qty for an amount of sdex tokens
     * @param _tokens user qty of sdex to be converted to shares
     * @return shares_ shares equivalent to the token amount. _shares <= totalShares
     */
    function tokensToShares(uint256 _tokens) external view returns (uint256 shares_);

    /**
     * @notice Calculate shares values in sdex tokens
     * @param _shares amount of shares. _shares <= totalShares
     * @return tokens_ qty of sdex token equivalent to the _shares. tokens_ <= _currentBalance
     */
    function sharesToTokens(uint256 _shares) external view returns (uint256 tokens_);

    /**
     * @notice Campaign id for staking in the farming contract
     * @return ID of the campaign
     */
    function CAMPAIGN_ID() external view returns (uint256);

    /**
     * @notice get farming initialized status
     * @return boolean inititalized or not
     */
    function farmingInitialized() external view returns (bool);

    /**
     * @notice get smardex Token contract address
     * @return smardex contract (address or type for Solidity)
     */
    function smardexToken() external view returns (IERC20);

    /**
     * @notice get farming contract address
     * @return farming contract (address or type for Solidity)
     */
    function farming() external view returns (IFarmingRange);

    /**
     * @notice get user info for staking status
     * @param _user user address
     * @return shares amount for user
     * @return lastBlockUpdate last block the user called deposit or withdraw
     */
    function userInfo(address _user) external view returns (uint256, uint256);

    /**
     * @notice get total shares in the staking
     * @return total shares amount
     */
    function totalShares() external view returns (uint256);
}
