// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @dev Error events that are used in token transfer function.
error BeforeTransferValidationFailed();
error InsufficientAmount(uint256 available, uint256 required);

contract Token is
    ERC20,
    ERC20Snapshot,
    Ownable,
    Pausable,
    ERC20Permit,
    ERC20Votes
{
    /// @notice Dead address to receive the burn tax.
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    /// @notice Decimal point constant used for calcualtion fees percentage.
    uint256 public constant DECIMAL_POINT = 10000;
    /// @notice Constant for max tax percentage.
    uint256 public constant MAX_FEES = 2500;
    /// @notice Constant for max slippage percentage.
    uint256 public constant MAX_SLIPPAGE = 2500;

    /// @notice V2 Router address.
    address public router;

    /// @notice Treasury addreess to receive tax.
    address public treasury;

    /// @notice Slippage percentage that will be used at the time of selling token in tax.
    uint256 public slippage;

    /// @notice Minimum ether buy amount.
    uint256 public minBuyAmount;

    /// @notice Burn tax percentage.

    uint256 public burnTax;

    /// @notice Treasury tax percentage.
    uint256 public treasuryTax;

    /// @notice Mapping to keep the track of whitelisted pair.
    mapping(address => bool) public whiteListedPair;

    /// @notice Mapping to keep the track of whitelisted user address.
    mapping(address => bool) public whiteListedAddress;

    /// @notice Mapping to keep the track of blacklisted address.
    mapping(address => bool) public blackListedAddress;

    /// @notice Pair path used for checking the minimum buy condition.
    address[] public pairPath;

    /// @notice Pair path used for selling token in tax.
    address[] public pairPathToken;

    // Events emitted from the contract.
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MinBuyAmountUpdated(uint256 indexed oldMinBuyAmount, uint256 indexed newMinBuyAmount);
    event BurnTaxUpdated(uint256 indexed oldBurnTax, uint256 indexed newBurnTax);
    event SlippageUpdated(uint256 indexed oldSlippage, uint256 indexed newSlippage);
    event RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event TreasuryTaxUpdated(uint256 indexed oldTreasuryTax, uint256 indexed newTreasuryTax);
    event WhiteListedPair(address indexed _address, bool indexed _value);
    event WhiteListedAddress(address indexed _address, bool indexed _value);
    event BlackListedAddress(address indexed _address, bool indexed _value);
    event UpdatePairPath(address[] indexed _path);
    event UpdatePairPathToken(address[] indexed _path);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 totalSupply,
        uint256 _slippage,
        uint256 _minBuyAmount,
        uint256 _burnTax,
        uint256 _treasuryTax
    ) ERC20(_name, _symbol) ERC20Permit(_name) {
        require(
            _burnTax + _treasuryTax <= MAX_FEES,
            "Cannot set Tax more that max value"
        );
        require(
            _slippage <= MAX_SLIPPAGE,
            "Cannot set Slippage more that max value"
        );
        _mint(msg.sender, totalSupply * 10 ** decimals());
        slippage = _slippage;
        minBuyAmount = _minBuyAmount;
        burnTax = _burnTax;
        treasuryTax = _treasuryTax;
        emit SlippageUpdated(0, _slippage);
        emit MinBuyAmountUpdated(0, _minBuyAmount);
        emit BurnTaxUpdated(0, _burnTax);
        emit TreasuryTaxUpdated(0, _treasuryTax);
    }

    /// @notice Snapshot function to take the snapshot at that moment of time. Only owner can call this function.
    function snapshot() public onlyOwner {
        _snapshot();
    }

    /// @notice Pause the token transfer. Only owner can call this function.
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice UnPause the token transfer. Only owner can call this function.
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev Internal function called before transfer to check if user is blacklisted or not.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Snapshot) whenNotPaused {
        if (blackListedAddress[from] || blackListedAddress[to]) {
            revert BeforeTransferValidationFailed();
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @dev Internal transfer function, it contains all the logic for tax and minimum buy condition.
    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        if (
            whiteListedPair[_from] ||
            whiteListedPair[_to] ||
            whiteListedAddress[_from] ||
            whiteListedAddress[_to]
        ) {
            if (whiteListedPair[_from] && !whiteListedAddress[_to]) {
                uint _ethAmount = IUniswapV2Router02(router).getAmountsOut(
                    _amount,
                    pairPath
                )[1];
                if (_ethAmount < minBuyAmount)
                    revert InsufficientAmount(_ethAmount, minBuyAmount);
            }
            super._transfer(_from, _to, _amount);
        } else {
            uint256 _burnAmount = (_amount * burnTax) / DECIMAL_POINT;
            uint256 _treasuryAmount = (_amount * treasuryTax) / DECIMAL_POINT;
            uint256 _transferAmount = _amount - (_burnAmount + _treasuryAmount);
            uint _tokenAmount = IUniswapV2Router02(router).getAmountsOut(
                _treasuryAmount,
                pairPathToken
            )[1];
            super._transfer(_from, DEAD, _burnAmount);
            super._transfer(_from, address(this), _treasuryAmount);
            IERC20(address(this)).approve(router, _treasuryAmount);
            _swap(
                _treasuryAmount,
                (_tokenAmount - (_tokenAmount * slippage) / DECIMAL_POINT),
                pairPathToken,
                treasury,
                block.timestamp
            );
            super._transfer(_from, _to, _transferAmount);
        }
    }

    /// @dev Internal swap function, it will be used to swap token on router.
    function _swap(
        uint256 _amountIn,
        uint _amountOutMin,
        address[] memory _path,
        address _to,
        uint _deadline
    ) private {
        IUniswapV2Router02(router)
            .swapExactTokensForETHSupportingFeeOnTransferTokens(
                _amountIn,
                _amountOutMin,
                _path,
                _to,
                _deadline
            );
    }

    /// @dev Override function as it used by multiple libraries.
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /// @dev Override function as it used by multiple libraries.
    function _mint(
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    /// @dev Override function as it used by multiple libraries.
    function _burn(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }

    /**
     * @notice Update the pair path used for checking the minimum buy condition.
     * @param _path Path that will be used over router.
     */
    function updatePairPath(address[] memory _path) external onlyOwner {
        require(_path.length > 1, "Pair should contains at least 2 addresses");
        pairPath = _path;

        emit UpdatePairPath(_path);
    }

    /**
     * @notice Update the pair path used for selling token in tax.
     * @param _path Path that will be used over router.
     */
    function updatePairPathToken(address[] memory _path) external onlyOwner {
        require(_path.length > 1, "Pair should contains at least 2 addresses");
        pairPathToken = _path;
        
        emit UpdatePairPathToken(_path);
    }

    /**
     * @notice Update the pair whitelist status. Contract will check whitelisted pair for minimum buy condition.
     * @param _address Pair to whitelist.
     * @param _value Bool value. To whitelist pair pass true and to remove from whitelist pass false.
     */
    function whiteListPairAddress(
        address _address,
        bool _value
    ) external onlyOwner {
        require(address(0) != _address, "Zero address");
        whiteListedPair[_address] = _value;
        emit WhiteListedPair(_address, _value);
    }

    /**
     * @notice Update the address whitelist status. Whitelisted address have no validation for minimum buy and transfer tax.
     * @param _address User address to whitelist.
     * @param _value Bool value. To whitelist pass true and to remove from whitelist pass false.
     */
    function whiteListAddress(
        address _address,
        bool _value
    ) external onlyOwner {
        require(address(0) != _address, "Zero address");
        whiteListedAddress[_address] = _value;
        emit WhiteListedAddress(_address, _value);
    }

    /**
     * @notice Update the address blacklist status.
     * @param _address User address to blacklist.
     * @param _value Bool value. To blacklist pass true and to remove from blacklist pass false.
     */
    function blackListAddress(
        address _address,
        bool _value
    ) external onlyOwner {
        require(address(0) != _address, "Zero address");
        blackListedAddress[_address] = _value;
        emit BlackListedAddress(_address, _value);
    }

    /**
     * @notice Update the router address. Use v2 router address only.
     * @param _router New router address
     */
    function updateRouter(address _router) external onlyOwner {
        require(address(0) != _router, "Zero address");
        emit RouterUpdated(router, _router);

        router = _router;
    }

    /**
     * @notice Update the treasury address to receive the tax.
     * @param _treasury New treasury address
     */
    function updateTreasury(address _treasury) external onlyOwner {
        require(address(0) != _treasury, "Zero address");
        emit TreasuryUpdated(treasury, _treasury);

        treasury = _treasury;
    }

    /**
     * @notice Update the minimum buy amount. Amount should be entered in wei format.
     * @param _minBuyAmount New minimum buy
     */
    function updateMinBuyAmount(uint256 _minBuyAmount) external onlyOwner {
        emit MinBuyAmountUpdated(minBuyAmount, _minBuyAmount);

        minBuyAmount = _minBuyAmount;
    }

    /**
     * @notice Update the burn tax percentage.
     * @param _burnTax New burn tax
     */
    function updateBurnTax(uint256 _burnTax) external onlyOwner {
        require(
            _burnTax + treasuryTax <= MAX_FEES,
            "Cannot set Tax more that max value"
        );
        emit BurnTaxUpdated(burnTax, _burnTax);

        burnTax = _burnTax;
    }

    /**
     * @notice Update the slippage percentage.
     * @param _slippage New slippage
     */
    function updateSlippage(uint256 _slippage) external onlyOwner {
        require(
            _slippage <= MAX_SLIPPAGE,
            "Cannot set Slippage more that max value"
        );
        emit SlippageUpdated(slippage, _slippage);

        slippage = _slippage;
    }

    /**
     * @notice Update the Treasury tax percentage.
     * @param _treasuryTax New Tax
     */
    function updateTreasuryTax(uint256 _treasuryTax) external onlyOwner {
        require(
            burnTax + _treasuryTax <= MAX_FEES,
            "Cannot set Tax more that max value"
        );
        emit TreasuryTaxUpdated(treasuryTax, _treasuryTax);

        treasuryTax = _treasuryTax;
    }
}