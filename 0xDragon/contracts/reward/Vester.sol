// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../token/BaseToken.sol";
import "../interfaces/IMintableToken.sol";

contract Vester is BaseToken {
    using SafeERC20 for IERC20;

    uint public vestingDuration;

    address public esToken;
    address public pairToken;
    address public claimableToken;

    uint public pairSupply;

    bool public disabled;

    uint public immutable PRECISION = 10000;
    uint public pairMultiplier;

    mapping(address => uint) public pairAmounts;
    mapping(address => uint) public cumulativeClaimAmounts;
    mapping(address => uint) public claimedAmounts;
    mapping(address => uint) public lastVestingTimes;

    mapping(address => uint) public cumulativeRewardDeductions;
    mapping(address => uint) public bonusRewards;

    event Claim(address receiver, uint amount);
    event Deposit(address account, uint amount);
    event Withdraw(address account, uint claimedAmount, uint balance);
    event PairTransfer(address indexed from, address indexed to, uint value);

    constructor(
        uint _vestingDuration,
        uint _pairMultiplier,
        address _esToken,
        address _pairToken,
        address _claimableToken
    ) ERC20("Vested FIRE", "vFIRE") {
        vestingDuration = _vestingDuration;
        pairMultiplier = _pairMultiplier;

        esToken = _esToken; // esFIRE
        pairToken = _pairToken; // sFIRE
        claimableToken = _claimableToken; // FIRE
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint
    ) internal virtual override {
        require(
            from == address(0) ||
                to == address(0) ||
                from == address(this) ||
                to == address(this),
            "Vested FIRE is non-transferrable"
        );
    }

    function setPairMultiplier(uint _multiplier) external onlyOwner {
        pairMultiplier = _multiplier;
    }

    function setDisabled(bool _disabled) external onlyOwner {
        disabled = _disabled;
    }

    function deposit(uint _amount) external {
        require(disabled == false, "Vester: disabled");
        _deposit(msg.sender, _amount);
    }

    modifier onlyHandler() {
        require(isHandler[msg.sender], "Vester: forbidden");
        _;
    }

    function depositForAccount(
        address _account,
        uint _amount
    ) external onlyHandler {
        _deposit(_account, _amount);
    }

    function claim() external returns (uint) {
        return _claim(msg.sender, msg.sender);
    }

    function claimForAccount(
        address _account,
        address _receiver
    ) external onlyHandler returns (uint) {
        return _claim(_account, _receiver);
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(
        address _token,
        address _account,
        uint _amount
    ) external onlyOwner {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function withdraw() external {
        address account = msg.sender;
        address _receiver = account;
        _claim(account, _receiver);

        uint claimedAmount = cumulativeClaimAmounts[account];
        uint balance = balanceOf(account);
        uint totalVested = balance + claimedAmount;
        require(totalVested > 0, "Vester: vested amount is zero");

        uint pairAmount = pairAmounts[account];
        _burnPair(account, pairAmount);
        IERC20(pairToken).safeTransfer(_receiver, pairAmount);

        IERC20(esToken).safeTransfer(_receiver, balance);
        _burn(account, balance);

        delete cumulativeClaimAmounts[account];
        delete claimedAmounts[account];
        delete lastVestingTimes[account];

        emit Withdraw(account, claimedAmount, balance);
    }

    function claimable(address _account) public view returns (uint) {
        uint amount = cumulativeClaimAmounts[_account] -
            claimedAmounts[_account];
        uint nextClaimable = _getNextClaimableAmount(_account);
        return amount + nextClaimable;
    }

    function getVestedAmount(address _account) public view returns (uint) {
        return balanceOf(_account) + cumulativeClaimAmounts[_account];
    }

    function _mintPair(address _account, uint _amount) private {
        require(_account != address(0), "Vester: mint to the zero address");

        pairSupply += _amount;
        pairAmounts[_account] += _amount;

        emit PairTransfer(address(0), _account, _amount);
    }

    function _burnPair(address _account, uint _amount) private {
        require(_account != address(0), "Vester: burn from the zero address");

        pairAmounts[_account] -= _amount;
        pairSupply -= _amount;

        emit PairTransfer(_account, address(0), _amount);
    }

    function _deposit(address _account, uint _amount) private {
        require(_amount > 0, "Vester: invalid _amount");

        _updateVesting(_account);

        IERC20(esToken).safeTransferFrom(_account, address(this), _amount);

        _mint(_account, _amount);

        uint pairAmount = pairAmounts[_account];
        uint nextPairAmount = (balanceOf(_account) * pairMultiplier) /
            PRECISION;
        if (nextPairAmount > pairAmount) {
            uint pairAmountDiff = nextPairAmount - pairAmount;
            IERC20(pairToken).safeTransferFrom(
                _account,
                address(this),
                pairAmountDiff
            );
            _mintPair(_account, pairAmountDiff);
        }

        emit Deposit(_account, _amount);
    }

    function _updateVesting(address _account) private {
        uint amount = _getNextClaimableAmount(_account);
        lastVestingTimes[_account] = block.timestamp;

        if (amount == 0) {
            return;
        }

        // transfer claimableAmount from balances to cumulativeClaimAmounts
        _burn(_account, amount);
        cumulativeClaimAmounts[_account] += amount;

        IMintableToken(esToken).burn(address(this), amount);
    }

    function _getNextClaimableAmount(
        address _account
    ) private view returns (uint) {
        uint timeDiff = block.timestamp - lastVestingTimes[_account];

        uint balance = balanceOf(_account);
        if (balance == 0) {
            return 0;
        }

        uint vestedAmount = getVestedAmount(_account);
        uint claimableAmount = (vestedAmount * timeDiff) / vestingDuration;

        if (claimableAmount < balance) {
            return claimableAmount;
        }

        return balance;
    }

    function _claim(
        address _account,
        address _receiver
    ) private returns (uint) {
        _updateVesting(_account);
        uint amount = claimable(_account);
        claimedAmounts[_account] += amount;
        IMintableToken(claimableToken).mint(_receiver, amount);
        emit Claim(_account, amount);
        return amount;
    }
}
