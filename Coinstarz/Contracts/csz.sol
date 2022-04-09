// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "hardhat/console.sol";

contract CSZ is ERC20, Ownable {
    using SafeMath for uint256;

    uint256 private _transactionFeePercent;
    uint256 private _transactionFeePercentOwner;

    mapping(address => bool) whitelistAddresses;

    enum Functions {FEE, FEE_OWNER, FEE_DIST}
    uint256 private constant _TIMELOCK = 0 days;
    mapping(Functions => uint256) public currentTimelocks;
    mapping(Functions => bool) public hasPendingFee;

	address public _DevelopmentWallet;
	address public _MarketingWallet;
	address public _RewardsWallet;
	address public _LiquidityWallet;

	uint256 public _DevelopmentWalletFeePercent;
	uint256 public _MarketingWalletFeePercent;
	uint256 public _RewardsWalletFeePercent;
	uint256 public _LiquidityWalletFeePercent;

    uint256 private _pendingTransactionFeePercent;
    uint256 private _pendingTransactionFeePercentOwner;

	uint256 public _pendingDevelopmentWalletFeePercent;
	uint256 public _pendingMarketingWalletFeePercent;
	uint256 public _pendingRewardsWalletFeePercent;
	uint256 public _pendingLiquidityWalletFeePercent;

    uint256 private _feeUpdateTimestamp;

    constructor(
		address DevelopmentWallet,
		address MarketingWallet,
		address RewardsWallet,
		address LiquidityWallet
    ) ERC20("CoinStarz", "CSZ") {
        _mint(_msgSender(), 100000000);

		_transactionFeePercent = 15e16; // 15%

		_DevelopmentWallet = DevelopmentWallet;
		_MarketingWallet = MarketingWallet;
		_RewardsWallet = RewardsWallet;
		_LiquidityWallet = LiquidityWallet;

		_DevelopmentWalletFeePercent = 35e16; // 35%
		_MarketingWalletFeePercent = 35e16; // 35%
		_RewardsWalletFeePercent = 24e16; // 24%
		_LiquidityWalletFeePercent = 6e16; // 6%

        currentTimelocks[Functions.FEE] = 0;
        currentTimelocks[Functions.FEE_OWNER] = 0;
        currentTimelocks[Functions.FEE_DIST] = 0;

        hasPendingFee[Functions.FEE] = false;
        hasPendingFee[Functions.FEE_OWNER] = false;
        hasPendingFee[Functions.FEE_DIST] = false;

        addWhitelistAddress(_msgSender());
		addWhitelistAddress(_DevelopmentWallet);
		addWhitelistAddress(_MarketingWallet);
		addWhitelistAddress(_RewardsWallet);
		addWhitelistAddress(_LiquidityWallet);

    }

    function transfer(address recipient, uint256 amount)
        public
        override
        updateFees()
        returns (bool)
    {
        _transferWithFee(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override updateFees() returns (bool) {
        _transferWithFee(sender, recipient, amount);

        uint256 currentAllowance = allowance(sender, _msgSender());
        require(
            currentAllowance >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        unchecked {_approve(sender, _msgSender(), currentAllowance - amount);}

        return true;
    }

    function _transferWithFee(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        uint256 feeToCharge;
            if (whitelistAddresses[sender] || whitelistAddresses[recipient]) {
                feeToCharge = amount.mul(_transactionFeePercentOwner).div(1e18);
            } else {
                feeToCharge = amount.mul(_transactionFeePercent).div(1e18);
            }

            uint256 amountAfterFee = amount.sub(feeToCharge);

            (
				uint256 toDevelopment,
				uint256 toMarketing,
				uint256 toRewards,
				uint256 toLiquidity
            ) = calculateFeeDistribution(feeToCharge);

			_transfer(sender, _DevelopmentWallet, toDevelopment);
			_transfer(sender, _MarketingWallet, toMarketing);
			_transfer(sender, _RewardsWallet, toRewards);
			_transfer(sender, _LiquidityWallet, toLiquidity);
            _transfer(sender, recipient, amountAfterFee);
    }

    function calculateFeeDistribution(uint256 amount)
        private
        view
        returns (
			uint256 toDevelopment,
			uint256 toMarketing,
			uint256 toRewards,
			uint256 toLiquidity
        )
    {
		toDevelopment = amount.mul(_DevelopmentWalletFeePercent).div(1e18);
		toMarketing = amount.mul(_MarketingWalletFeePercent).div(1e18);
		toRewards = amount.mul(_RewardsWalletFeePercent).div(1e18);
		toLiquidity = amount.mul(_LiquidityWalletFeePercent).div(1e18);


    }

    modifier updateFees() {
        setTransactionFee();
        setTransactionFeeOwner();
        setFeeDistribution();
        _;
    }

    function getCurrentTransactionFee() public view returns (uint256) {
        return _transactionFeePercent;
    }

    function getCurrentTransactionFeeOwner() public view returns (uint256) {
        return _transactionFeePercentOwner;
    }

    function getCurrentFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_DevelopmentWalletFeePercent,
			_MarketingWalletFeePercent,
			_RewardsWalletFeePercent,
			_LiquidityWalletFeePercent
        );
    }

    function getPendingTransactionFee() public view returns (uint256) {
        return _pendingTransactionFeePercent;
    }

    function getPendingTransactionFeeOwner() public view returns (uint256) {
        return _pendingTransactionFeePercentOwner;
    }

    function getPendingFeeDistribution()
        public
        view
        returns (
			uint256,
			uint256,
			uint256,
			uint256
        )
    {
        return (
			_pendingDevelopmentWalletFeePercent,
			_pendingMarketingWalletFeePercent,
			_pendingRewardsWalletFeePercent,
			_pendingLiquidityWalletFeePercent
        );
    }

    function getPendingTransactionFeeTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE];
    }

    function getPendingTransactionFeeOwnerTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_OWNER];
    }

    function getPendingFeeDistributionTime() public view returns (uint256) {
        return currentTimelocks[Functions.FEE_DIST];
    }

    function proposeTransactionFee(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "CSZ: transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE],
            "CSZ: There is a pending fee change already."
        );
        require(
            currentTimelocks[Functions.FEE] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercent = fee;

        currentTimelocks[Functions.FEE] = block.timestamp + _TIMELOCK;
        hasPendingFee[Functions.FEE] = true;
    }

    function proposeTransactionFeeOwner(uint256 fee) public onlyOwner {
        require(
            fee >= 0 && fee <= 15e16,
            "CSZ: sell transaction fee should be >= 0 and <= 15%"
        );
        require(
            !hasPendingFee[Functions.FEE_OWNER],
            "CSZ: There is a pending owner fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_OWNER] == 0,
            "Current Timelock is already initialized with a value"
        );

        _pendingTransactionFeePercentOwner = fee;

        currentTimelocks[Functions.FEE_OWNER] = block.timestamp + _TIMELOCK;
        hasPendingFee[Functions.FEE_OWNER] = true;
    }

    function proposeFeeDistribution(
			uint256 DevelopmentWalletFeePercent,
			uint256 MarketingWalletFeePercent,
			uint256 RewardsWalletFeePercent,
			uint256 LiquidityWalletFeePercent
    ) public onlyOwner {
        require(
				DevelopmentWalletFeePercent
				.add(MarketingWalletFeePercent)
				.add(RewardsWalletFeePercent)
				.add(LiquidityWalletFeePercent) == 1e18,
            "CSZ: The sum of distribuition should be 100%"
        );
        require(
            !hasPendingFee[Functions.FEE_DIST],
            "CSZ: There is a pending dsitribution fee change already."
        );
        require(
            currentTimelocks[Functions.FEE_DIST] == 0,
            "Current Timelock is already initialized with a value"
        );
			_pendingDevelopmentWalletFeePercent = _DevelopmentWalletFeePercent;
			_pendingMarketingWalletFeePercent = _MarketingWalletFeePercent;
			_pendingRewardsWalletFeePercent = _RewardsWalletFeePercent;
			_pendingLiquidityWalletFeePercent = _LiquidityWalletFeePercent;

        currentTimelocks[Functions.FEE_DIST] = block.timestamp + _TIMELOCK;
        hasPendingFee[Functions.FEE_DIST] = true;
    }

    function setTransactionFee() private {
        if (
            hasPendingFee[Functions.FEE] == true &&
            currentTimelocks[Functions.FEE] <= block.timestamp
        ) {
            _transactionFeePercent = _pendingTransactionFeePercent;
            currentTimelocks[Functions.FEE] = 0;
            hasPendingFee[Functions.FEE] = false;
        }
    }

    function setTransactionFeeOwner() private {
        if (
            hasPendingFee[Functions.FEE_OWNER] == true &&
            currentTimelocks[Functions.FEE_OWNER] <= block.timestamp
        ) {
            _transactionFeePercentOwner = _pendingTransactionFeePercentOwner;
            currentTimelocks[Functions.FEE_OWNER] = 0;
            hasPendingFee[Functions.FEE_OWNER] = false;
        }
    }

    function setFeeDistribution() private {
        if (
            hasPendingFee[Functions.FEE_DIST] == true &&
            currentTimelocks[Functions.FEE_DIST] <= block.timestamp
        ) {
			_DevelopmentWalletFeePercent = _pendingDevelopmentWalletFeePercent;
			_MarketingWalletFeePercent = _pendingMarketingWalletFeePercent;
			_RewardsWalletFeePercent = _pendingRewardsWalletFeePercent;
			_LiquidityWalletFeePercent = _pendingLiquidityWalletFeePercent;

            currentTimelocks[Functions.FEE_DIST] = 0;
            hasPendingFee[Functions.FEE_DIST] = false;
        }
    }

	function setDevelopmentWalletAddress(address DevelopmentAddress) public onlyOwner {
	require(
		DevelopmentAddress != address(0),
		"CSZ: DevelopmentAddress cannot be zero address"
	);
	_DevelopmentWallet = DevelopmentAddress;
}
	function setMarketingWalletAddress(address MarketingAddress) public onlyOwner {
	require(
		MarketingAddress != address(0),
		"CSZ: MarketingAddress cannot be zero address"
	);
	_MarketingWallet = MarketingAddress;
}
	function setRewardsWalletAddress(address RewardsAddress) public onlyOwner {
	require(
		RewardsAddress != address(0),
		"CSZ: RewardsAddress cannot be zero address"
	);
	_RewardsWallet = RewardsAddress;
}
	function setLiquidityWalletAddress(address LiquidityAddress) public onlyOwner {
	require(
		LiquidityAddress != address(0),
		"CSZ: LiquidityAddress cannot be zero address"
	);
	_LiquidityWallet = LiquidityAddress;
}

    function addWhitelistAddress(address companyAddress) public onlyOwner {
        whitelistAddresses[companyAddress] = true;
    }

    function removeWhitelistAddress(address companyAddress) public onlyOwner {
        require(
            whitelistAddresses[companyAddress] == true,
            "The company address you're trying to remove does not exist or already has been removed"
        );
        whitelistAddresses[companyAddress] = false;
    }
}