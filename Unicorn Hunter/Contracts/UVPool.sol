// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IUVPool.sol";
import "./interfaces/IUVReserveFactory.sol";

contract UVPool is ERC20, ERC20Burnable, Ownable, AccessControl, IUVPool {
    using SafeMath for uint256;

    struct Vote {
        string name;
        uint64 startTimestamp;
        uint64 endTimestamp;
        bool isActive;
        uint64 voteCount;
    }

    struct VoteInfo {
        uint64 timestamp;
        uint256 amount;
        uint8 optionId;
        address voter;
    }
    uint256 public feeCreator = 1 ether;
    mapping(uint8 => Vote) public allVotes;
    mapping(uint8 => mapping(address => VoteInfo)) public allVoters;
    mapping(uint8 => mapping(uint64 => VoteInfo)) public allVotersIndex;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    // Testnet Router
    address public constant PANCAKE_ROUTER_ADDRESS =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
    // Testnet BUSD address
    address public constant stableCoin =
        0x33F2534011277C09fE5Bd87D11ee3e251B2F8D1f;

    mapping(address => uint256) private _balances;
    mapping(address => bool) public investmentAddreses;
    IPancakeRouter02 public pancakeRouter;
    address public factory;
    address public factoryReserve;
    address public fundWallet;
    uint256 public currentSizePool = 0;
    uint256 public maxSizePool;
    uint8 public orderNumber;
    uint256 public minimumDeposit;
    bool public isClose = false;
    uint8 percentFee = 250;
    bool public pausedTransfer = false;
    bool public voteCreateable = true;

    constructor(uint8 _orderNumber)
        ERC20(
            string.concat("BUV - ", Strings.toString(_orderNumber)),
            string.concat("BUV-", Strings.toString(_orderNumber))
        )
    {
        factory = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    // called once by the factory at time of deployment
    function initialize(
        uint8 _orderNumber,
        uint256 _amountLimited,
        uint256 _minimumDeposit,
        address _fundWallet,
        address _factoryReserve
    ) external {
        require(msg.sender == factory, "FORBIDDEN"); // sufficient check
        minimumDeposit = _minimumDeposit;
        maxSizePool = _amountLimited;
        orderNumber = _orderNumber;
        pancakeRouter = IPancakeRouter02(PANCAKE_ROUTER_ADDRESS);
        fundWallet = _fundWallet;
        factoryReserve = _factoryReserve;
    }

    receive() external payable {}

    fallback() external payable {}

    // Transfer tokens to fund wallet process projects vesting
    function transferForInvestment(
        address _tokenAddress,
        uint256 _amount,
        address _receiver
    ) external onlyRole(MANAGER_ROLE) {
        require(_receiver != address(0), "receiver address is zero");
        require(
            investmentAddreses[_receiver],
            "receiver is not investment address"
        );
        IERC20 _instance = IERC20(_tokenAddress);
        uint256 _balance = _instance.balanceOf(address(this));
        require(_balance >= _amount, "Not enough");

        _instance.approve(address(this), _amount);
        _instance.transfer(fundWallet, _amount);
    }

    // Deposit stable coin to the pool
    function deposit(uint256 amount) public {
        require(!isClose, "Pool is closed");
        require(maxSizePool >= currentSizePool.add(amount), "Pool is full");
        require(amount >= minimumDeposit, "Not enough");

        IERC20(stableCoin).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _mint(fundWallet, amount.mul(percentFee).div(1000));
        _balances[fundWallet] = _balances[fundWallet].add(amount.mul(percentFee).div(1000));

        currentSizePool += amount;

        emit Deposit(msg.sender, amount);
    }

    // Set percent fee for the pool
    function setPercentFee(uint8 _percentFee) public onlyRole(MANAGER_ROLE) {
        require(
            _percentFee > 10 && _percentFee < 400,
            "Percent fee is invalid"
        );
        percentFee = _percentFee;
    }

    // Get pool reserved
    function getReserve() public view returns (address) {
        (address _poolReserved, , , ) = IUVReserveFactory(factoryReserve)
            .getPoolInfo(orderNumber);
        return _poolReserved;
    }

    // Buy native token on pancake
    function buyNativeToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline
    ) public onlyRole(MANAGER_ROLE) {
        require(isClose, "Pool is not closed");

        address _poolReserved = getReserve();
        IERC20(_path[0]).approve(PANCAKE_ROUTER_ADDRESS, _amountIn);
        // Handle buy BNB on pancake
        pancakeRouter.swapExactTokensForETH(
            _amountIn,
            _amountOutMin,
            _path,
            _poolReserved,
            _deadline
        );

        emit BuyBNB(_amountOutMin);
    }

    // Buy on pancake
    function buyToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline
    ) public onlyRole(MANAGER_ROLE) {
        require(isClose, "Pool is not closed");
        address _poolReserved = getReserve();
        IERC20(_path[0]).approve(PANCAKE_ROUTER_ADDRESS, _amountIn);
        // handle buy token on pancake
        pancakeRouter.swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            _path,
            _poolReserved,
            _deadline
        );
        emit BuyToken(_poolReserved, _amountOutMin);
    }

    // toggles the paused state of the transfer function
    function togglePausedTransfer() public onlyRole(MANAGER_ROLE) {
        pausedTransfer = !pausedTransfer;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(pausedTransfer == false, "ERC20: transfer is paused");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= _balances[sender],
            "ERC20: amount must be less or equal to balance"
        );

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    // Add investment address
    function addInvestmentAddress(address _investmentAddress) public onlyOwner {
        investmentAddreses[_investmentAddress] = true;
    }

    // Remove investment address
    function removeInvestmentAddress(address _investmentAddress)
        public
        onlyOwner
    {
        investmentAddreses[_investmentAddress] = false;
    }

    // Set the fund wallet
    function setFundWallet(address _fundWallet) public onlyOwner {
        fundWallet = _fundWallet;
    }

    // Set the factory Reserve
    function setFactoryReserve(address _factoryReserve)
        public
        onlyRole(MANAGER_ROLE)
    {
        factoryReserve = _factoryReserve;
    }

    // Set minimum deposit amount
    function setMinimumDeposit(uint256 _minimumDeposit)
        public
        onlyRole(MANAGER_ROLE)
    {
        minimumDeposit = _minimumDeposit;
    }

    // Set Max size pool
    function setMaxSizePool(uint256 _maxSizePool)
        public
        onlyRole(MANAGER_ROLE)
    {
        maxSizePool = _maxSizePool;
    }

    // open the pool
    function openPool() public onlyRole(MANAGER_ROLE) {
        isClose = false;
    }

    // close the pool
    function closePool() public onlyRole(MANAGER_ROLE) {
        isClose = true;
    }

    // get detail Vote
    function getVote(uint8 _orderNumber) public view returns (Vote memory) {
        return allVotes[_orderNumber];
    }

    // Set fee creator
    function setFeeCreator(uint256 _feeCreator) public onlyRole(MANAGER_ROLE) {
        feeCreator = _feeCreator;
    }

    // Add wallet to manager role
    function addManager(address _manager) public onlyOwner {
        _setupRole(MANAGER_ROLE, _manager);
    }

    // Remove wallet from manager role
    function removeManager(address _manager) public onlyOwner {
        revokeRole(MANAGER_ROLE, _manager);
    }

    // get detail VoteInfo by orderNumber
    function getVoteInfo(uint8 _orderNumber, address _user)
        public
        view
        returns (VoteInfo memory)
    {
        return allVoters[_orderNumber][_user];
    }

    // create a new vote
    function createVote(
        uint8 _orderNumber,
        uint64 _startTimestamp,
        uint64 _endTimestamp
    ) public payable {
        require(voteCreateable, "Vote is not createable");
        require(isClose, "Pool is not closed");
        if (hasRole(MANAGER_ROLE, msg.sender)) {} else {
            require(
                msg.value >= feeCreator,
                "You need to pay fee to create vote"
            );
            uint256 balance = balanceOf(msg.sender);
            require(
                balance >= totalSupply().div(10) ||
                    hasRole(MANAGER_ROLE, msg.sender),
                "You need to have 10% of total supply"
            );
        }

        allVotes[_orderNumber].startTimestamp = _startTimestamp;
        allVotes[_orderNumber].endTimestamp = _endTimestamp;
        allVotes[_orderNumber].isActive = true;
        voteCreateable = false;

        emit CreateVote(_orderNumber, _startTimestamp, _endTimestamp);
    }

    // close a vote
    function closeVote(uint8 _orderNumber) public onlyRole(MANAGER_ROLE) {
        allVotes[_orderNumber].isActive = false;
        voteCreateable = true;
        emit CloseVote(_orderNumber);
    }

    // voting for a option
    function voting(uint8 _orderNumber, uint8 _optionId) public {
        require(isClose, "This Pool is closed");
        require(allVotes[_orderNumber].isActive, "This Vote is closed");
        require(
            allVoters[_orderNumber][msg.sender].timestamp == 0,
            "You have voted"
        );
        require(
            allVoters[_orderNumber][msg.sender].amount == 0,
            "You have voted"
        );
        uint256 _amountBalance = balanceOf(msg.sender);

        transferFrom(msg.sender, address(this), _amountBalance);
        allVotes[_orderNumber].voteCount += 1;

        allVoters[_orderNumber][msg.sender] = VoteInfo({
            amount: _amountBalance,
            timestamp: uint64(block.timestamp),
            optionId: _optionId,
            voter: msg.sender
        });
        allVotersIndex[_orderNumber][
            allVotes[_orderNumber].voteCount
        ] = VoteInfo({
            amount: _amountBalance,
            timestamp: uint64(block.timestamp),
            optionId: _optionId,
            voter: msg.sender
        });

        emit Voting(
            msg.sender,
            _amountBalance,
            uint64(block.timestamp),
            _optionId,
            allVotes[_orderNumber].voteCount
        );
    }

    // internal release token after vote closed
    function releaseTokenAfterVote(
        uint8 _orderNumber,
        uint64 _from,
        uint64 _to
    ) external onlyRole(MANAGER_ROLE) {
        require(!allVotes[_orderNumber].isActive, "This Vote is closed");
        for (uint64 i = _from; i < _to; i++) {
            _transfer(
                address(this),
                allVotersIndex[_orderNumber][i].voter,
                allVotersIndex[_orderNumber][i].amount
            );
        }
    }
}
