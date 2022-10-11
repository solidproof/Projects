// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUVPool {
    function deposit(uint256 amount) external;

    function initialize(
        uint8 _orderNumber,
        uint256 _amountLimited,
        uint256 _minimumDeposit,
        address _fundWallet,
        address _factoryReserve,
        uint64 _poolOpenTime
    ) external;

    function transferForInvestment(
        address _tokenAddress,
        uint256 _amount,
        address _receiver
    ) external;

    function getReserve() external returns (address);

    function buyToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        bytes calldata _path,
        uint256 _deadline
    ) external;

    function setFundWallet(address _fundWallet) external;

    function setMinimumDeposit(uint256 _minimumDeposit) external;

    function openPool() external;

    function closePool() external;

    function setFeeCreator(uint256 _feeCreator) external;

    function addManager(address _manager) external;

    function removeManager(address _manager) external;

    function addInvestmentAddress(address _investmentAddress) external;

    function removeInvestmentAddress(address _investmentAddress) external;

    function createVote(
        uint8 _orderNumber,
        uint64 _startTimestamp,
        uint64 _endTimestamp
    ) external payable;

    function closeVote(uint8 _orderNumber) external;

    function voting(uint8 _orderNumber, uint8 _optionId) external;

    event Deposit(address indexed sender, uint256 amount);
    event BuyToken(address indexed tokenAddress, uint256 amount);
    event BuyBNB(uint256 amount);

    event CreateVote(uint8 voteId, uint64 startTimestamp, uint64 endTimestamp);
    event Voting(
        address indexed voter,
        uint256 amount,
        uint64 timestamp,
        uint8 optionId,
        uint64 voteCount
    );
    event CloseVote(uint8 voteId);
}
