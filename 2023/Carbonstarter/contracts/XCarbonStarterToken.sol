// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces//ICarbonStarterToken.sol";
import "./interfaces/IXCarbonStarterToken.sol";
import "./interfaces/IXCarbonStarterTokenUsage.sol";

/*
 * xARBS is Carbon Starters reward escrowed token obtainable by converting ARBS to it
 * It's non-transferable, except from/to whitelisted addresses
 * It can be converted back to ARBS through a vesting process
 * This contract is made to receive xARBS deposits from users
 */
contract XCarbonStarterToken is
    Ownable,
    ReentrancyGuard,
    ERC20("ARBS reward escrowed token", "xARBS"),
    IXCarbonStarterToken
{
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for ICarbonStarterToken;

    struct XArbsBalance {
        uint256 allocatedAmount; // Amount of xARBS allocated to a Usage
        uint256 redeemingAmount; // Total amount of xARBS currently being redeemed
    }

    struct RedeemInfo {
        uint256 arbsAmount; // ARBS amount to receive when vesting has ended
        uint256 xArbsAmount; // xARBS amount to redeem
        uint256 endTime;
        uint256 startTime;
    }

    ICarbonStarterToken public immutable arbsToken; // ARBS token to convert to/from

    EnumerableSet.AddressSet private _transferWhitelist; // addresses allowed to send/receive xARBS
    uint256 private constant DIV_100 = 100;

    uint256 public constant MAX_DEALLOCATION_FEE = 200; // 2%

    uint256 public constant MAX_FIXED_RATIO = 100; // 100%

    // Redeeming min/max settings
    uint256 public minRedeemRatio = 50; // 1:0.5
    uint256 public maxRedeemRatio = 100; // 1:1
    uint256 public minRedeemDuration = 14 days;
    uint256 public maxRedeemDuration = 140 days;
    uint256 public excessBurnRatio = 50; // 50%

    address public excessAddress; // Address to send excess ARBS to

    mapping(address => XArbsBalance) public xArbsBalances; // User's xARBS balances
    mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances

    constructor(ICarbonStarterToken arbsToken_) {
        require(address(arbsToken_) != address(0), "invalid arbsToken address");
        arbsToken = arbsToken_;
        _transferWhitelist.add(address(this));
        excessAddress = msg.sender;
    }

    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event Convert(address indexed from, address to, uint256 amount);
    event UpdateRedeemSettings(
        uint256 minRedeemRatio,
        uint256 maxRedeemRatio,
        uint256 minRedeemDuration,
        uint256 maxRedeemDuration
    );
    event UpdateDeallocationFee(address indexed usageAddress, uint256 fee);
    event SetTransferWhitelist(address account, bool add);
    event Redeem(
        address indexed userAddress,
        uint256 xArbsAmount,
        uint256 arbsAmount,
        uint256 duration
    );
    event FinalizeRedeem(
        address indexed userAddress,
        uint256 xArbsAmount,
        uint256 arbsAmount
    );
    event CancelRedeem(address indexed userAddress, uint256 xArbsAmount);

    /***********************************************/
    /****************** MODIFIERS ******************/
    /***********************************************/

    /*
     * @dev Check if a redeem entry exists
     */
    modifier validateRedeem(address userAddress, uint256 redeemIndex) {
        require(
            redeemIndex < userRedeems[userAddress].length,
            "validateRedeem: redeem entry does not exist"
        );
        _;
    }

    /**************************************************/
    /****************** PUBLIC VIEWS ******************/
    /**************************************************/

    /*
     * @dev Returns user's xARBS balances
     */
    function getXArbsBalance(
        address userAddress
    ) external view returns (uint256 allocatedAmount, uint256 redeemingAmount) {
        XArbsBalance storage balance = xArbsBalances[userAddress];
        return (balance.allocatedAmount, balance.redeemingAmount);
    }

    /*
     * @dev returns redeemable ARBS for "amount" of xARBS vested for "duration" seconds
     */
    function getArbsByVestingDuration(
        uint256 amount,
        uint256 duration
    ) public view returns (uint256) {
        if (duration < minRedeemDuration) {
            return 0;
        }

        // capped to maxRedeemDuration
        if (duration > maxRedeemDuration) {
            return (amount * maxRedeemRatio) / DIV_100;
        }

        uint256 ratio = minRedeemRatio +
            ((duration - minRedeemDuration) *
                (maxRedeemRatio - minRedeemRatio)) /
            (maxRedeemDuration - minRedeemDuration);

        return (amount * ratio) / DIV_100;
    }

    /**
     * @dev returns quantity of "userAddress" pending redeems
     */
    function getUserRedeemsLength(
        address userAddress
    ) external view returns (uint256) {
        return userRedeems[userAddress].length;
    }

    /**
     * @dev returns "userAddress" info for a pending redeem identified by "redeemIndex"
     */
    function getUserRedeem(
        address userAddress,
        uint256 redeemIndex
    )
        external
        view
        validateRedeem(userAddress, redeemIndex)
        returns (
            uint256 arbsAmount,
            uint256 xArbsAmount,
            uint256 endTime,
            uint256 startTime
        )
    {
        RedeemInfo storage _redeem = userRedeems[userAddress][redeemIndex];
        return (
            _redeem.arbsAmount,
            _redeem.xArbsAmount,
            _redeem.endTime,
            _redeem.startTime
        );
    }

    /**
     * @dev returns length of transferWhitelist array
     */
    function transferWhitelistLength() external view returns (uint256) {
        return _transferWhitelist.length();
    }

    /**
     * @dev returns transferWhitelist array item's address for "index"
     */
    function transferWhitelist(uint256 index) external view returns (address) {
        return _transferWhitelist.at(index);
    }

    /**
     * @dev returns if "account" is allowed to send/receive xARBS
     */
    function isTransferWhitelisted(
        address account
    ) external view override returns (bool) {
        return _transferWhitelist.contains(account);
    }

    /*******************************************************/
    /****************** OWNABLE FUNCTIONS ******************/
    /*******************************************************/

    /**
     * @dev Updates all redeem ratios and durations
     *
     * Must only be called by owner
     */
    function updateRedeemSettings(
        uint256 minRedeemRatio_,
        uint256 maxRedeemRatio_,
        uint256 minRedeemDuration_,
        uint256 maxRedeemDuration_
    ) external onlyOwner {
        require(
            minRedeemRatio_ <= maxRedeemRatio_,
            "updateRedeemSettings: wrong ratio values"
        );
        require(
            minRedeemDuration_ < maxRedeemDuration_,
            "updateRedeemSettings: wrong duration values"
        );
        // should never exceed 100%
        require(
            maxRedeemRatio_ <= MAX_FIXED_RATIO,
            "updateRedeemSettings: wrong ratio values"
        );

        minRedeemRatio = minRedeemRatio_;
        maxRedeemRatio = maxRedeemRatio_;
        minRedeemDuration = minRedeemDuration_;
        maxRedeemDuration = maxRedeemDuration_;

        emit UpdateRedeemSettings(
            minRedeemRatio_,
            maxRedeemRatio_,
            minRedeemDuration_,
            maxRedeemDuration_
        );
    }

    /**
     * @dev Adds or removes addresses from the transferWhitelist
     */
    function updateTransferWhitelist(
        address account,
        bool add
    ) external onlyOwner {
        require(
            account != address(this),
            "updateTransferWhitelist: Cannot update transferWhitelist"
        );

        if (add) _transferWhitelist.add(account);
        else _transferWhitelist.remove(account);

        emit SetTransferWhitelist(account, add);
    }

    /**
     * @dev Changes the excess address
     */
    function setExcessAddress(address account) external onlyOwner {
        require(
            account != address(this),
            "setExcessAddress: Cannot change excess address"
        );

        excessAddress = account;
    }

    /**
     * @dev Changes the excess burn ratio
     */
    function setExcessRatio(uint256 ratio) external onlyOwner {
        require(
            ratio <= 100,
            "setExcessRatio: Cannot change excess burn ratio"
        );

        excessBurnRatio = ratio;
    }

    /*****************************************************************/
    /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
    /*****************************************************************/

    /**
     * @dev Convert caller's "amount" of ARBS to xARBS
     */
    function convert(uint256 amount) external nonReentrant {
        _convert(amount, msg.sender);
    }

    /**
     * @dev Convert caller's "amount" of ARBS to xARBS to "to" address
     */
    function convertTo(
        uint256 amount,
        address to
    ) external override nonReentrant {
        require(address(msg.sender).isContract(), "convertTo: not allowed");
        _convert(amount, to);
    }

    /**
     * @dev Initiates redeem process (xARBS to ARBS)
     *
     * Handles dividends' compensation allocation during the vesting process if needed
     */
    function redeem(
        uint256 xArbsAmount,
        uint256 duration
    ) external nonReentrant {
        require(xArbsAmount > 0, "redeem: xArbsAmount cannot be null");
        require(duration >= minRedeemDuration, "redeem: duration too low");

        _transfer(msg.sender, address(this), xArbsAmount);
        XArbsBalance storage balance = xArbsBalances[msg.sender];

        // get corresponding ARBS amount
        uint256 arbsAmount = getArbsByVestingDuration(xArbsAmount, duration);
        emit Redeem(msg.sender, xArbsAmount, arbsAmount, duration);

        // if redeeming is not immediate, go through vesting process
        if (duration > 0) {
            // add to SBT total
            balance.redeemingAmount += xArbsAmount;

            // add redeeming entry
            userRedeems[msg.sender].push(
                RedeemInfo({
                    arbsAmount: arbsAmount,
                    xArbsAmount: xArbsAmount,
                    endTime: _currentBlockTimestamp() + duration,
                    startTime: _currentBlockTimestamp()
                })
            );
        } else {
            // immediately redeem for ARBS
            _finalizeRedeem(msg.sender, xArbsAmount, arbsAmount);
        }
    }

    /**
     * @dev Finalizes redeem process when vesting duration has been reached
     *
     * Can only be called by the redeem entry owner
     */
    function finalizeRedeem(
        uint256 redeemIndex
    ) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
        XArbsBalance storage balance = xArbsBalances[msg.sender];
        RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];
        require(
            _currentBlockTimestamp() >= _redeem.startTime + minRedeemDuration,
            "finalizeRedeem: must wait minimum duration before redeeming"
        );

        // remove from SBT total
        balance.redeemingAmount -= _redeem.xArbsAmount;

        uint256 duration = _currentBlockTimestamp() - _redeem.startTime;
        uint256 arbsAmount = getArbsByVestingDuration(
            _redeem.xArbsAmount,
            duration
        );
        uint256 xArbsAmount = _redeem.xArbsAmount;
        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);

        _finalizeRedeem(msg.sender, xArbsAmount, arbsAmount);
    }

    /**
     * @dev Cancels an ongoing redeem entry
     *
     * Can only be called by its owner
     */
    function cancelRedeem(
        uint256 redeemIndex
    ) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
        XArbsBalance storage balance = xArbsBalances[msg.sender];
        RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

        // make redeeming xARBS available again
        balance.redeemingAmount -= _redeem.xArbsAmount;

        _transfer(address(this), msg.sender, _redeem.xArbsAmount);

        emit CancelRedeem(msg.sender, _redeem.xArbsAmount);

        // remove redeem entry
        _deleteRedeemEntry(redeemIndex);
    }

    /********************************************************/
    /****************** INTERNAL FUNCTIONS ******************/
    /********************************************************/

    /**
     * @dev Convert caller's "amount" of ARBS into xARBS to "to"
     */
    function _convert(uint256 amount, address to) internal {
        require(amount != 0, "convert: amount cannot be null");

        // mint new xARBS
        _mint(to, amount);

        emit Convert(msg.sender, to, amount);
        arbsToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Finalizes the redeeming process for "userAddress" by transferring him "arbsAmount" and removing "xArbsAmount" from supply
     *
     * Any vesting check should be ran before calling this
     * ARBS excess is automatically burnt
     */
    function _finalizeRedeem(
        address userAddress,
        uint256 xArbsAmount,
        uint256 arbsAmount
    ) internal {
        uint256 arbsExcess = xArbsAmount - arbsAmount;

        // sends due ARBS tokens
        arbsToken.safeTransfer(userAddress, arbsAmount);

        // burns ARBS excess / 2 and transfers the other half to EOA for future use (Staking, etc.)
        if (arbsExcess > 0) {
            uint256 arbsExcessBurn = (arbsExcess * excessBurnRatio) / DIV_100;
            arbsToken.burnToDead(arbsExcessBurn);
            arbsToken.safeTransfer(excessAddress, arbsExcess - arbsExcessBurn);
        }

        _burn(address(this), xArbsAmount);

        emit FinalizeRedeem(userAddress, xArbsAmount, arbsAmount);
    }

    function _deleteRedeemEntry(uint256 index) internal {
        RedeemInfo[] storage redeems = userRedeems[msg.sender];
        if (index != redeems.length - 1) {
            redeems[index] = redeems[redeems.length - 1];
        }
        redeems.pop();
    }

    /**
     * @dev Hook override to forbid transfers except from whitelisted addresses and minting
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 /*amount*/
    ) internal view override {
        require(
            from == address(0) ||
                _transferWhitelist.contains(from) ||
                _transferWhitelist.contains(to),
            "transfer: not allowed"
        );
    }

    /**
     * @dev Utility function to get the current block timestamp
     */
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        /* solhint-disable not-rely-on-time */
        return block.timestamp;
    }
}
