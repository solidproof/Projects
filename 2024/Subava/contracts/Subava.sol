// SPDX-License-Identifier: MIT
//
// Copyright of The $SUBAVA Team
//
//  ____  _   _ ____    ___     ___
// / ___|| | | | __ )  / \ \   / / \
// \___ \| | | |  _ \ / _ \ \ / / _ \
//  ___) | |_| | |_) / ___ \ V / ___ \
// |____/ \___/|____/_/   \_\_/_/   \_\
//
//
// $Subava has 3% tax split across 5 protocols
// (Sells have doubled tax)
//
// Burn       0,50%
// Team       0,50%
// Marketing  0,50%
// Reflection 0,50%
// Lp         1%

pragma solidity ^0.8.4;
import "./interfaces/IERC20.sol";
import "./access/Ownable.sol";
import "./utils/Context.sol";
import "./utils/math/SafeMath.sol";
import "./utils/Address.sol";
import "./interfaces/ISubavaPoolManager.sol";

contract SubavaToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    // General Info
    string private _name = "Subava"; //Subava
    string private _symbol = "SUBAVA"; //SUBAVA
    uint8 private _decimals = 18;

    // Addresses
    address payable public _teamAddress =
        payable(0x987860E2276F89eF987adf2F212f4642c0CE2DE6); // Team address used to pay for team
    address public _traderJoeV2LiquidityPair;
    address public _subavaPoolManagerAddress;

    // Balances
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Exclusions
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    // Supply
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 720000000000 * 10 ** _decimals;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _totalReflections; // Total reflections

    // Token Tax Settings
    uint256 public _taxFee = 3; // 3% tax
    uint256 public _sellTaxFee = 14; // 14% tax
    uint256 public _whaleSellTaxFee = 21; // 21% tax
    uint256 private _previousTaxFee;

    // Token Limits
    uint256 public _maxTxAmount = 720000000000 * 10 ** _decimals; // 720 billion

    // Timer Constants
    uint private constant DAY = 86400; // How many seconds in a day

    // Anti-Whale Settings
    uint256 public _whaleSellThreshold = 360000000000 * 10 ** _decimals; // 360 billion
    uint public _whaleSellTimer = DAY; // 24 hours
    mapping(address => uint256) private _amountSold;
    mapping(address => uint) private _timeSinceFirstSell;

    bool public _enableLiquidity = false;

    constructor() {
        // Mint the total reflection balance to the deployer of this contract
        _rOwned[_msgSender()] = _rTotal;

        // Exclude the owner and the contract from paying fees
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /**
     * @notice Required to recieve AVAX from traderJoe V2 Router when swaping
     */
    receive() external payable {}

    /**
     * @notice Withdraws AVAX from the contract
     */
    function withdrawAVAX(uint256 amount) public onlyOwner {
        if (amount == 0) payable(owner()).transfer(address(this).balance);
        else payable(owner()).transfer(amount);
    }

    /**
     * @notice Withdraws non-SUBAVA tokens that are stuck as to not interfere with the liquidity
     */
    function withdrawForeignToken(address token) public onlyOwner {
        require(
            address(this) != address(token),
            "Cannot withdraw native token"
        );
        IERC20(address(token)).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function getTotalReflections() external view returns (uint256) {
        return _totalReflections;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function isExcludedFromReflection(
        address account
    ) external view returns (bool) {
        return _isExcluded[account];
    }

    function amountSold(address account) external view returns (uint256) {
        return _amountSold[account];
    }

    function getTimeSinceFirstSell(
        address account
    ) external view returns (uint) {
        return _timeSinceFirstSell[account];
    }

    function excludeFromFee(address account) external onlyOwner {
        _isExcludedFromFees[account] = true;
    }

    function includeInFee(address account) external onlyOwner {
        _isExcludedFromFees[account] = false;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setSellTaxFeePerecent(uint256 taxFee) external onlyOwner {
        _sellTaxFee = taxFee;
    }

    function setWhaleSellTaxFeePerecent(uint256 taxFee) external onlyOwner {
        _whaleSellTaxFee = taxFee;
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
        _maxTxAmount = maxTxAmount;
    }

    function setWhaleSellThreshold(uint256 amount) external onlyOwner {
        _whaleSellThreshold = amount;
    }

    function setWhaleSellTimer(uint time) external onlyOwner {
        _whaleSellTimer = time;
    }

    function setTraderJoeV2LiquidityPair(
        address traderJoeV2LiquidityPair
    ) external onlyOwner {
        _traderJoeV2LiquidityPair = traderJoeV2LiquidityPair;
    }

    function setLiquidity(bool b) external onlyOwner {
        _enableLiquidity = b;
    }

    function setTeamAddress(address teamAddress) external onlyOwner {
        _teamAddress = payable(teamAddress);
    }

    function setSubavaPoolManagerAddress(
        address subavaPoolManagerAddress
    ) external onlyOwner {
        _subavaPoolManagerAddress = subavaPoolManagerAddress;
    }

    /**
     * @notice Converts a token value to a reflection value
     */
    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) public view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @notice Converts a reflection value to a token value
     */
    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    /**
     * @notice Removes all fees and stores their previous values to be later restored
     */
    function removeAllFees() private {
        if (_taxFee == 0) return;

        _previousTaxFee = _taxFee;
        _taxFee = 0;
    }

    /**
     * @notice Restores the fees
     */
    function restoreAllFees() private {
        _taxFee = _previousTaxFee;
    }

    /**
     * @notice Collects all the necessary transfer values
     */
    function _getValues(
        uint256 tAmount
    ) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            _getRate()
        );
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    /**
     * @notice Calculates transfer token values
     */
    function _getTValues(
        uint256 tAmount
    ) private view returns (uint256, uint256) {
        uint256 tFee = tAmount.mul(_taxFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        return (tTransferAmount, tFee);
    }

    /**
     * @notice Calculates transfer reflection values
     */
    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 currentRate
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @notice Calculates the rate of reflections to tokens
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    /**
     * @notice Gets the current supply values
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
     * @notice Excludes an address from receiving reflections
     */
    function excludeFromReward(address account) external onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
     * @notice Includes an address back into the reflection system
     */
    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    /**
     * @notice Handles the before and after of a token transfer, such as taking fees and firing off a swap and liquify event
     */
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // Only the owner of this contract can bypass the max transfer amount
        if (from != owner() && to != owner()) {
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        // AUTO-LIQUIDITY MECHANISM
        if (_enableLiquidity) {
            ISubavaPoolManager(_subavaPoolManagerAddress).swapAndLiquify();
        }

        // If any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !(_isExcludedFromFees[from] || _isExcludedFromFees[to]);

        // ANTI-WHALE TAX MECHANISM
        // If we are taking fees and sending tokens to the liquidity pool (i.e. a sell), check for anti-whale tax
        if (takeFee && to == _traderJoeV2LiquidityPair) {
            // We will assume that the normal sell tax rate will apply
            uint256 fee = _sellTaxFee;

            // Get the time difference in seconds between now and the first sell
            uint delta = block.timestamp.sub(_timeSinceFirstSell[from]);

            // Get the new total to see if it has spilled over the threshold
            uint256 newTotal = _amountSold[from].add(amount);

            // If a known wallet started their selling within the whale sell timer window, check if they're trying to spill over the threshold
            // If they are then increase the tax amount
            if (
                delta > 0 &&
                delta < _whaleSellTimer &&
                _timeSinceFirstSell[from] != 0
            ) {
                if (newTotal > _whaleSellThreshold) {
                    fee = _whaleSellTaxFee;
                }
                _amountSold[from] = newTotal;
            } else if (
                _timeSinceFirstSell[from] == 0 && newTotal > _whaleSellThreshold
            ) {
                fee = _whaleSellTaxFee;
                _amountSold[from] = newTotal;
            } else {
                // Otherwise we reset their sold amount and timer
                _timeSinceFirstSell[from] = block.timestamp;
                _amountSold[from] = amount;
            }

            // Set the tax rate to the sell tax rate, if the whale sell tax rate applies then we set that
            _previousTaxFee = _taxFee;
            _taxFee = fee;
        }

        // Remove fees completely from the transfer if either wallet are excluded
        if (!takeFee) {
            removeAllFees();
        }

        // Transfer the token amount from sender to receipient.
        _tokenTransfer(from, to, amount);

        // If we removed the fees for this transaction, then restore them for future transactions
        if (!takeFee) {
            restoreAllFees();
        }

        // If this transaction was a sell, and we took a fee, restore the fee amount back to the original buy amount
        if (takeFee && to == _traderJoeV2LiquidityPair) {
            _taxFee = _previousTaxFee;
        }
    }

    /**
     * @notice Handles the actual token transfer
     */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        // Calculate the values required to execute a transfer
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, ) = _getRValues(
            tAmount,
            tFee,
            _getRate()
        );

        // Transfer from sender to recipient
        if (_isExcluded[sender]) {
            _tOwned[sender] = _tOwned[sender].sub(tAmount);
        }
        _rOwned[sender] = _rOwned[sender].sub(rAmount);

        if (_isExcluded[recipient]) {
            _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        }
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

        // This is always 1% of a transaction worth of tokens
        if (tFee > 0) {
            uint256 tPortion = tFee.div(3);
            uint256 halfZeroFiveAmount = tPortion.div(2);
            // Burn some of the taxed tokens
            _burnTokens(halfZeroFiveAmount);

            // Reflect some of the taxed tokens
            _reflectTokens(halfZeroFiveAmount);

            // Team some of the taxed tokens
            _teamTokens(halfZeroFiveAmount);

            // Take the rest of the taxed tokens for the other functions
            _takeTokens(
                tFee.sub(halfZeroFiveAmount).sub(halfZeroFiveAmount).sub(
                    halfZeroFiveAmount
                )
            );
        }

        // Emit an event
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @notice Team SUBAVA tokens straight to the team address
     */
    function _teamTokens(uint256 tTakeAmount) private {
        uint256 currentRate = _getRate();
        uint256 rTakeAmount = tTakeAmount.mul(currentRate);
        _rOwned[_teamAddress] = _rOwned[_teamAddress].add(rTakeAmount);
        if (_isExcluded[_teamAddress]) {
            _tOwned[_teamAddress] = _tOwned[_teamAddress].add(tTakeAmount);
        }
        emit Transfer(address(this), _teamAddress, tTakeAmount);
    }

    /**
     * @notice Burns SUBAVA tokens straight to the burn address
     */
    function _burnTokens(uint256 tFee) private {
        _rOwned[address(0)] = _rOwned[address(0)].add(tFee);
        if (_isExcluded[address(0)]) {
            _tOwned[address(0)] = _tOwned[address(0)].add(tFee);
        }
        emit Transfer(address(this), address(0), tFee);
    }

    /**
     * @notice Increases the rate of how many reflections each token is worth
     */
    function _reflectTokens(uint256 tFee) private {
        uint256 rFee = tFee.mul(_getRate());
        _rTotal = _rTotal.sub(rFee);
        _totalReflections = _totalReflections.add(tFee);
    }

    /**
     * @notice The contract takes a portion of tokens from taxed transactions
     */
    function _takeTokens(uint256 tTakeAmount) private {
        uint256 currentRate = _getRate();
        uint256 rTakeAmount = tTakeAmount.mul(currentRate);
        _rOwned[_subavaPoolManagerAddress] = _rOwned[_subavaPoolManagerAddress]
            .add(rTakeAmount);
        if (_isExcluded[_subavaPoolManagerAddress]) {
            _tOwned[_subavaPoolManagerAddress] = _tOwned[
                _subavaPoolManagerAddress
            ].add(tTakeAmount);
        }
        emit Transfer(address(this), _subavaPoolManagerAddress, tTakeAmount);
    }

    /**
     * @notice Allows a user to voluntarily reflect their tokens to everyone else
     */
    function reflect(uint256 tAmount) public {
        require(
            !_isExcluded[_msgSender()],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , ) = _getValues(tAmount);
        _rOwned[_msgSender()] = _rOwned[_msgSender()].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _totalReflections = _totalReflections.add(tAmount);
    }
}
