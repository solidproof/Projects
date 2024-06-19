// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IThrusterRouter02.sol";
import "./interfaces/IBlast.sol";

contract LICH is ERC20, Ownable, ReentrancyGuard {
    event Deposit(address indexed depositor, uint256 ethDeposited, uint256 totalSubscription);
    event Referral(address indexed referrer, uint256 ethDeposited, uint256 totalReferred);
    event PresaleClaim(address indexed depositor, uint256 tokensClaimed, uint256 ethRefund);
    event Claim(address indexed account, uint256 amount);

    uint256 public immutable fairAllocation;
    uint256 public immutable liquidityPoolAllocation;
    uint256 public immutable referralAllocation;
    uint256 public immutable communityAllocation;
    uint256 public immutable marketingAllocation;
    address public immutable marketingWallet;

    uint256 public immutable minimumDeposit;
    uint256 public immutable maximumDeposit;

    uint256 public immutable presaleDuration;
    uint256 public immutable hardcap;
    uint256 public presaleEnd;
    uint256 public totalReferred;
    uint256 public totalSubscription;

    address public immutable firstTreasury;
    address public immutable secondTreasury;

    address public immutable thrusterRouter;
    address public immutable thrusterFactory;

    bool public presaleSuccess;
    bool public presaleFinalized;
    bool public tradingEnabled;

    bytes32 private communityRoot;
    uint256 public immutable communityClaimAmount;
    uint256 public communityClaimedAmount;

    mapping(address referrer => uint256) public referredAmounts;
    mapping(address depositor => uint256) public depositAmounts;
    mapping(address depositor => bool) public depositClaimed;
    mapping(address referrer => bool) public referralClaimed;
    mapping(address wallet => bool) public communityClaimed;

    constructor(
        uint256 _supply,
        uint256 _minimumDeposit,
        uint256 _maximumDeposit,
        uint256 _hardcap,
        uint256 _communityClaimAmount,
        address _thrusterRouter,
        address _blast,
        address _owner,
        address _firstTreasury,
        address _secondTreasury,
        address _marketingWallet
    ) ERC20("LICH", "LICH") Ownable(_owner) {
        referralAllocation = (_supply * 15) / 100;
        liquidityPoolAllocation = (_supply * 25) / 100;
        fairAllocation = (_supply * 45) / 100;
        communityAllocation = (_supply * 7) / 100;
        marketingAllocation = (_supply * 8) / 100;
        marketingWallet = _marketingWallet;

        presaleDuration = 4 hours;
        hardcap = _hardcap;
        minimumDeposit = _minimumDeposit;
        maximumDeposit = _maximumDeposit;
        communityClaimAmount = _communityClaimAmount;
        thrusterRouter = _thrusterRouter;

        firstTreasury = _firstTreasury;
        secondTreasury = _secondTreasury;

        IBlast(_blast).configureClaimableGas();
        IBlast(_blast).configureGovernor(_owner);

        super._mint(address(this), liquidityPoolAllocation);
        super._mint(marketingWallet, marketingAllocation);
        super._mint(address(this), communityAllocation);
        super._mint(address(this), referralAllocation);
        super._mint(address(this), fairAllocation);
    }

    function startPresale() external onlyOwner {
        require(presaleEnd == 0, "Presale already started");
        presaleEnd = block.timestamp + presaleDuration;
    }

    function deposit() external payable {
        _processDeposit(address(0));
    }

    function depositReferral(address referrer) external payable {
        _processDeposit(referrer);
    }

    function claim() external nonReentrant {
        require(presaleFinalized, "Presale is not finalized yet");
        require(depositAmounts[msg.sender] > 0, "No deposits found");
        require(!depositClaimed[msg.sender], "Already claimed");
        (uint256 allocation, uint256 refund) = _calculateAllocation(msg.sender, presaleSuccess);
        depositClaimed[msg.sender] = true;
        if (allocation > 0) this.transfer(msg.sender, allocation);
        if (refund > 0) payable(msg.sender).transfer(refund);
        emit PresaleClaim(msg.sender, allocation, refund);
    }

    function referralClaim() external nonReentrant {
        require(presaleFinalized, "Presale is not finalized yet");
        uint256 referred = referredAmounts[msg.sender];
        require(referred > 0, "No referrals found");
        require(!referralClaimed[msg.sender], "Already claimed");
        referralClaimed[msg.sender] = true;
        uint256 allocation = (referred * referralAllocation) / totalReferred;
        this.transfer(msg.sender, allocation);
        emit Claim(msg.sender, allocation);
    }

    function communityClaim(bytes32[] memory _merkleProof) external nonReentrant {
        require(presaleEnd == 0, "Community claim not allowed after presale start");
        require(!communityClaimed[msg.sender], "Already claimed");
        require(
            communityClaimedAmount + communityClaimAmount <= communityAllocation,
            "Community allocation has been claimed"
        );
        require(
            MerkleProof.verify(_merkleProof, communityRoot, keccak256(abi.encodePacked(msg.sender))),
            "Invalid Merkle Proof"
        );
        communityClaimed[msg.sender] = true;
        communityClaimedAmount += communityClaimAmount;
        require(this.transfer(msg.sender, communityClaimAmount), "Token transfer failed");
        emit Claim(msg.sender, communityClaimAmount);
    }

    function userAllocation(address account) external view returns (uint256, uint256) {
        uint256 depositedEth = depositAmounts[account];
        if (depositedEth == 0 || depositClaimed[account]) return (0, 0);
        return _calculateAllocation(account, true);
    }

    function _processDeposit(address referrer) internal {
        require(address(msg.sender).code.length == 0, "Contracts are prohibited");
        require(presaleEnd != 0, "Presale is not active yet");
        require(block.timestamp < presaleEnd, "Presale ended");
        require(msg.value >= minimumDeposit, "Minimun deposit threshold not exceeded");
        require(depositAmounts[msg.sender] + msg.value <= maximumDeposit, "Maximum deposit threshold exceeded");

        totalSubscription += msg.value;
        depositAmounts[msg.sender] += msg.value;

        if (referrer != address(0)) _processReferral(referrer, msg.value);

        emit Deposit(msg.sender, msg.value, totalSubscription);
    }

    function _processReferral(address referrer, uint256 amount) internal {
        require(referrer != msg.sender, "Cannot refer self");
        referredAmounts[referrer] += amount;
        totalReferred += amount;
        emit Referral(referrer, amount, referredAmounts[referrer]);
    }

    function finalizePresale(bool proceed) external onlyOwner {
        require(presaleEnd != 0, "Presale is not active yet");
        require(block.timestamp > presaleEnd, "Presale is still in progress");
        presaleSuccess = proceed;
        if (proceed) {
            uint256 totalEth = totalSubscription > hardcap ? hardcap : totalSubscription;
            uint256 liquidityEth = (totalEth * 60) / 100;
            uint256 treasuryEth = (totalEth * 20) / 100;
            deployLiquidityPool(liquidityEth);
            distributeToTreasury(treasuryEth);
        }
        presaleFinalized = true;
    }

    function distributeToTreasury(uint256 treasuryEth) internal {
        payable(firstTreasury).transfer(treasuryEth);
        payable(secondTreasury).transfer(treasuryEth);
    }

    function deployLiquidityPool(uint256 ethPool) internal {
        this.approve(thrusterRouter, liquidityPoolAllocation);
        IThrusterRouter02(thrusterRouter).addLiquidityETH{value: ethPool}(
            address(this), liquidityPoolAllocation, 0, 0, owner(), block.timestamp
        );
    }


    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        renounceOwnership();
    }

    function setCommunityRoot(bytes32 root) external onlyOwner {
        communityRoot = root;
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (!tradingEnabled) {
            if (from == address(this) || from == address(0) || from == thrusterRouter) {
                super._update(from, to, amount);
            } else {
                revert("Trading is disabled");
            }
        } else {
            super._update(from, to, amount);
        }
    }

    function _calculateAllocation(address account, bool success) internal view returns (uint256 allocation, uint256 refund) {
        uint256 depositedEth = depositAmounts[account];
        require(depositedEth > 0, "No deposits found");
        require(!depositClaimed[account], "Already claimed");
        if (!success) {
            refund = depositedEth;
        } else if (totalSubscription > hardcap) {            
            allocation = (depositedEth * fairAllocation) / totalSubscription;
            refund = depositedEth - (depositedEth * hardcap) / totalSubscription - 1;
        } else {
            allocation = (depositedEth * fairAllocation) / totalSubscription;
        }
    }

    receive() external payable {
        _processDeposit(address(0));
    }
}