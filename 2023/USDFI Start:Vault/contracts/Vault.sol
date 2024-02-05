// SPDX-License-Identifier: Business Source License 1.1

pragma solidity =0.8.19;

import "./ERC20Upgradeable.sol";
import "./SafeERC20Upgradeable.sol";
import "./OwnableUpgradeable.sol";
import "./ReentrancyGuardUpgradeable.sol";
import "./IStrategy.sol";
import "./IReferrals.sol";

/**
 * @dev Implementation of a vault to deposit funds for yield optimizing.
 * This is the contract that receives funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Strategy.sol' contract.
 */
contract UsdfiVaultV1 is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    // The strategy currently in use by the vault.
    IStrategy public strategy;

    uint256 public rewardIndex;
    mapping(address => uint256) public rewardIndexOf;
    mapping(address => uint256) public earned;
    mapping(address => bool) public whitelist;
    address public STABLE;
    uint256 public nextHarvest;
    bool public harvestPause;
    uint256 public totalRewards;

    address public referralContract;
    mapping(address => uint256) public earnedRefs;
    uint256 public referralFee;
    uint256[] public refLevelPercent;

    event RewardPaid(address indexed user, uint256 reward);
    event RefRewardPaid(address indexed user, uint256 reward);

    /**
     * @dev Sets the value of {token} to the token that the vault will
     * hold as underlying value. It initializes the vault's own 'Sub' token.
     * This token is minted when someone does a deposit. It is burned in order
     * to withdraw the corresponding portion of the underlying assets.
     * @param _strategy the address of the strategy.
     * @param _name the name of the vault token.
     * @param _symbol the symbol of the vault token.
     */
     function initialize(
        IStrategy _strategy,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __ReentrancyGuard_init();
        strategy = _strategy;
        STABLE = 0xa3870fbBeb730BA99e4107051612af3465CA9F5e;
        referralContract = 0xA015Dc8619Ad6992c6E9fa3c8188FCc06b6E3BcE;
        referralFee = 2000;
        refLevelPercent = [6000, 3000, 1000];
    }

    function want() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(strategy.want());
    }

    function stable() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(STABLE);
    }

    /**
     * @dev It calculates the total underlying value of {token} held by the system.
     * It takes into account the vault contract balance, the strategy contract balance
     *  and the balance deployed in other contracts as part of the strategy.
     */
    function balance() public view returns (uint256) {
        return want().balanceOf(address(this)) + IStrategy(strategy).balanceOf();
    }

    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    function available() public view returns (uint256) {
        return want().balanceOf(address(this));
    }

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance() * 1e18 / totalSupply();
    }

    /**
     * @dev A helper function to call deposit() with all the sender's funds.
     */
    function depositAll() external {
        depositFor(want().balanceOf(msg.sender), msg.sender);
    }

    /**
     * @dev The entrypoint of funds into the system. People deposit for other People with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     */
    function depositFor(uint256 _amount, address _user) public nonReentrant {
        require(checkIfContract(msg.sender) == false || whitelist[msg.sender] == true, "SafeERC20: call from contract");
        require (_amount > 0, "SafeERC20: 0 amount");

        _updateRewards(_user);

        uint256 _pool = balance();
        want().safeTransferFrom(msg.sender, address(this), _amount);
        earn();
        uint256 _after = balance();
        _amount = _after - _pool; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _pool;
        }
        _mint(_user, shares);
    }

    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() public {
        uint256 _bal = available();
        want().safeTransfer(address(strategy), _bal);
        strategy.deposit();
    }

    /**
     * @dev A helper function to call withdraw() with all the sender's funds.
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the strategy and pay up the token holder. A proportional number of IOU
     * tokens are burned in the process.
     */
    function withdraw(uint256 _shares) public nonReentrant {
        require(checkIfContract(msg.sender) == false || whitelist[msg.sender] == true, "SafeERC20: call from contract");
        require (_shares > 0, "SafeERC20: 0 amount");

        _updateRewards(msg.sender);

        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        uint b = want().balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r - b;
            strategy.withdraw(_withdraw);
            uint _after = want().balanceOf(address(this));
            uint _diff = _after - b;
            if (_diff < _withdraw) {
                r = b + _diff;
            }
        }
        want().safeTransfer(msg.sender, r);
    }

    /**
     * @dev Rescues random funds stuck that the strat can't handle.
     * @param _token address of the token to rescue.
     */
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(want()), "!token");

        uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(msg.sender, amount);
    }

    //---------------------------------------

    function updateRewardIndex(uint256 reward) internal {
        rewardIndex += (reward * 1e18) / totalSupply();
    }

    function _calculateRewards(address account) private view returns (uint256) {
        uint256 rewardShares = IERC20Upgradeable(address(this)).balanceOf(account);
        return
            (rewardShares * (rewardIndex - rewardIndexOf[account])) / 1e18;
    }

    function calculateRewardsEarned(address account)
        external
        view
        returns (uint256)
    {
        return earned[account] + _calculateRewards(account);
    }

    function _updateRewards(address account) private {
        earned[account] += _calculateRewards(account);
        rewardIndexOf[account] = rewardIndex;
    }

    //---------------------------------------

    function claim(address _user) external nonReentrant returns (uint256) {

        if (nextHarvest < block.timestamp && harvestPause == false) {
        generateReward();
        }
        _updateRewards(_user);

        uint256 reward = earned[_user];
        if (reward > 0) {
            earned[_user] = 0;

        uint256 refReward = (reward * referralFee) / 100000;
        uint256 remainingRefReward = refReward;

        address ref = IReferrals(referralContract).getSponsor(_user);

            stable().safeTransfer(_user, reward - refReward);
            emit RewardPaid(_user, reward - refReward);

            uint256 i = 0;
            while (i < refLevelPercent.length && refLevelPercent[i] > 0) {
                if (ref != IReferrals(referralContract).membersList(0)) {
                    uint256 refFeeAmount = (refReward * refLevelPercent[i]) /100000;
                    remainingRefReward = remainingRefReward - refFeeAmount;
                    stable().safeTransfer(ref, refFeeAmount);
                    earnedRefs[ref] = earnedRefs[ref] + refFeeAmount;
                    emit RefRewardPaid(ref, reward);
                    ref = IReferrals(referralContract).getSponsor(ref);
                    i++;
                } else {
                    break;
                }
            }
            if (remainingRefReward > 10000) {
                address _mainRefFeeReceiver = IStrategy(strategy).usdfiFeeRecipient();
                stable().safeTransfer(_mainRefFeeReceiver, remainingRefReward);
                earnedRefs[_mainRefFeeReceiver] = earnedRefs[_mainRefFeeReceiver] +remainingRefReward;
                emit RefRewardPaid(_mainRefFeeReceiver, remainingRefReward);
            }
        }
        return reward;
    }

    function generateRewards() public nonReentrant {
        generateReward();
    }

    function generateReward() internal {
        strategy.harvest();
        uint256 rewardBal = stable().balanceOf(address(strategy));
        stable().safeTransferFrom(address(strategy),address(this),rewardBal);
        updateRewardIndex(rewardBal);
        totalRewards = totalRewards + rewardBal;
        nextHarvest = block.timestamp + 1 days;
    }

    //---------------------------------------

    function setHarvestPause(bool _harvestPause) external onlyOwner {
        harvestPause = _harvestPause;
    }

    function checkIfContract(address _address) internal view returns(bool) {
        return _address.isContract();
    }

    function updateWhitelist(address _address, bool _bool) external onlyOwner {
        whitelist[_address] = _bool;
    }
}