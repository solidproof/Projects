// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./chainlink/AggregatorV3Interface.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./IERC20Snapshot.sol";

contract DealToken is
    ERC20Pausable,
    ERC20Snapshot,
    AccessControl,
    IERC20Snapshot
{
    using SafeMath for uint256;

    event FrozeAddress(address indexed _address, bool _lock);
    event LockedTokens(address indexed _address, uint256 _amount);
    event UnlockTokens(address indexed _address, uint256 _amount);
    event BuyToken(
        address indexed investor,
        address indexed issuer,
        uint256 _amount
    );
    event ChangeTokenPrice(address indexed _address, uint256 _finalPrice);
    event ChangeCommission(uint256 _finalPrice);

    // SafeERC20 internal _token;
    ERC20 internal _token;
    AggregatorV3Interface internal _priceFeed;
    int256 public maticUsdPrice;
    uint256 public maticTimestamp;
    uint80 public maticRoundID;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    address private admin;

    mapping(address => bool) whitelistedUsers;
    mapping(address => bool) lockAddress;
    mapping(address => uint256) lockTokens;

    uint256 private commission;
    uint256 private tokenPrice;
    uint256 private fees;
    uint256 private finalTokenPrice;

    // Restrict external transfers
    bool private allowTransfers;

    /**
     * @dev Constructor that mines all of existing tokens.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initial_supply,
        uint256 _tokenPrice,
        uint256 _fees,
        address _owner,
        address _erc20PaymentAddress,
        address _aggregatorAddress
    ) ERC20(_name, _symbol) {
        require(_owner != address(0));
        require(_erc20PaymentAddress != address(0));
        require(_aggregatorAddress != address(0));
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);
        _setupRole(BURNER_ROLE, _owner);
        _setupRole(PAUSER_ROLE, _owner);
        _setupRole(SNAPSHOT_ROLE, _owner);
        _setupRole(AGENT_ROLE, _owner);
        _mint(_owner, _initial_supply * (10**uint256(decimals())));
        admin = _owner;
        allowTransfers = false;
        finalTokenPrice = _tokenPrice.add(_fees);
        _token = ERC20(_erc20PaymentAddress);
        _priceFeed = AggregatorV3Interface(_aggregatorAddress);
    }

    // Set params
    function changeAggregatorFeed(address _aggregatorAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _priceFeed = AggregatorV3Interface(_aggregatorAddress);
    }

    function changeErcPaymentAddress(address _erc20PaymentAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _token = ERC20(_erc20PaymentAddress);
    }

    function setTokenPrice(uint256 _tokenPrice, uint256 _fees)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        tokenPrice = _tokenPrice;
        fees = _fees;
        finalTokenPrice = _tokenPrice.add(_fees);
        emit ChangeTokenPrice(address(this), finalTokenPrice);
    }

    function getTokenPrice() external view returns (uint256 _finalTokenPrice) {
        return finalTokenPrice;
    }

    function setCommission(uint256 _commission)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        commission = _commission;
        emit ChangeCommission(commission);
    }

    function getCommission()
        external
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint256 _commission)
    {
        return commission;
    }

    function allowTransfer() external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowTransfers = true;
    }

    function disallowTransfer() external onlyRole(DEFAULT_ADMIN_ROLE) {
        allowTransfers = false;
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    function freezeAddress(address _address, bool _lock)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        lockAddress[_address] = _lock;
        emit FrozeAddress(_address, _lock);
    }

    function freezeTokens(address _address, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            balanceOf(_address) >= amount,
            "Balance less than freezing tokens"
        );
        lockTokens[_address] = amount;
        emit LockedTokens(_address, amount);
    }

    function unfreezeTokens(address _address, uint256 amount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(lockTokens[_address] >= amount, "Unfreezing more than locked.");
        lockTokens[_address] = lockTokens[_address].sub(amount);
        emit UnlockTokens(_address, amount);
    }

    function transfer(address _to, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(allowTransfers, "Direct transfers not allowed");
        require(!lockAddress[_to] && !lockAddress[msg.sender], "Wallet locked");
        require(
            _amount <= balanceOf(msg.sender).sub(lockTokens[msg.sender]),
            "Not enough Balance"
        );
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override whenNotPaused returns (bool) {
        require(allowTransfers, "Direct transfers not allowed");
        require(!lockAddress[_to] && !lockAddress[msg.sender], "Wallet locked");
        require(
            _amount <= balanceOf(msg.sender).sub(lockTokens[msg.sender]),
            "Not enough Balance"
        );
        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    function forceTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(!lockAddress[_to] && !lockAddress[msg.sender], "Wallet locked");
        require(
            _amount <= balanceOf(msg.sender).sub(lockTokens[msg.sender]),
            "Not enough Balance"
        );
        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    function buy(uint256 _amount) external payable returns (uint256) {
        require(!lockAddress[msg.sender], "Wallet locked");
        require(_amount > 0, "Buy atleast 1 token");
        (, int256 price, , , ) = _priceFeed.latestRoundData();
        int256 _price = int256(price / int256(10**_priceFeed.decimals())); // price of 1 Matic in USD, it use 8 decimals
        require(_price > 0, "Error with price feed.");
        uint256 _tokenAmount = finalTokenPrice.mul(_amount) *
            10**uint256(_token.decimals());
        require(
            msg.value >= (_tokenAmount / uint256(_price)),
            "Transaction value less than required"
        );
        _transfer(admin, msg.sender, _amount * 10**uint256(decimals()));
        emit BuyToken(msg.sender, admin, _amount);
        (bool sent, ) = admin.call{value: msg.value}("");
        require(sent, "Failed to send Ether");
        return _tokenAmount;
    }

    function buyWithStablecoin(uint256 _amount) external returns (uint256) {
        require(_amount > 0, "Buy at least one token");
        uint256 _tokenAmount = finalTokenPrice.mul(_amount) *
            10**uint256(_token.decimals());
        require(
            _token.balanceOf(msg.sender) >= _tokenAmount,
            "Not enough balance"
        );
        require(
            _token.allowance(msg.sender, address(this)) > _tokenAmount,
            "Allow spend to contract"
        );
        _transfer(admin, msg.sender, _amount * 10**uint256(decimals()));
        emit BuyToken(msg.sender, admin, _amount);
        require(
            _token.transferFrom(msg.sender, admin, _tokenAmount),
            "Stablecoin payment unsuccesfull"
        );
        return _tokenAmount;
    }

    function snapshot() external override onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        return _snapshot();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Pausable, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "ERC20Pausable: token transfer while paused");
    }

    function pause() external virtual onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external virtual onlyRole(PAUSER_ROLE) {
        _unpause();
    }
}
