// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./wormhole/IWormholeRelayer.sol";
import "./wormhole/IWormholeReceiver.sol";
import "hardhat/console.sol";

interface IKYC {
    function balanceOf(address) external view returns (uint256);
}

abstract contract BaseVault is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IWormholeReceiver {
    using SafeERC20 for IERC20;

    /**
     * @dev Token in which initial investments are accepted
     */
    IERC20 public SALE_TOKEN;

    uint16 public constant MAIN_CHAIN_ID = 16; // moonbeam

    /**
     * @dev Current vault chain id (wormhole ID not EVM)
     */
    uint16 public VAULT_CHAIN_ID;

    /**
     * @dev Main-chain vault address (address from moonbeam)
     */
    address public MAIN_VAULT;

    /**
     * @dev Minimum amount that the project seeks
     */
    uint256 public MIN_COLLECTED;

    /**
     * @dev Maximum amount that the project seeks
     */
    uint256 public MAX_COLLECTED;

    /**
     * @dev Start date for collecting investments   
     */
    uint256 public SALE_START;

    /**
     * @dev End date for collecting investments   
     */
    uint256 public SALE_END;

    /**
     * @dev Platform address - service provider treasury   
     */
    address public PLATFORM;

    /**
     * @dev Investor fee - amount of fee, that investor pays to platform
     */
    uint256 public INVESTOR_FEE;

    /**
     * @dev Beneficiary fee - amount of fee, that beneficiary pays to platform
     */
    uint256 public BENEFICIARY_FEE;

    /**
     * @dev Platform fee - upper limit (10000 = 100%)
     */
    uint256 public constant FEE_UL = 10000; // 100 = 1%

    /**
     * @dev Platform fee - max settable limit (2500 = 25%)
     */
    uint256 public constant FEE_MAX_SETTABLE = 2500; // 100 = 1%

    /**
     * @dev Project treasury address
     */
    address public BENEFICIARY;

    /**
     * @dev Total investments shares
     */
    uint256 public totalShares;

    /**
     * @dev Total platform fee (collected if MIN_COLLECTED is reached)
     */
    uint256 public totalPlatformFee;

    /**
     * @dev Total USDC amount allocated for user rewards 
     */
    uint256 public totalRevAlloc;

    /**
     * @dev Total USDC amount already claimed by users
     */
    uint256 public totalRevPaid;

    /**
     * @dev USDC amount invested by user
     */
    mapping(address => uint256) public userInfo; // address > amount
    
    enum Status {
        SALE,
        ACTIVE,
        DISABLED,
        NOT_INITIALIZED
    }

    /**
     * @dev Vaults status:
     * SALE     - Collecting investments
     * ACTIVE   - Sufficient investments collected
     * DISABLED - Insufficient investments collected
     */
    Status public status;

    /**
     * @dev USDC amount allocated for user rewards per ePoch
     */
    mapping(uint256 => uint256) public epochRevenue;

    /**
     * @dev current epoch
     */
    uint256 public epoch;

    /**
     * @dev timestamp when finalizeSale/endPeriodWithRevenue becomes available to call
     */
    uint256 public beneficiaryActionUnlock;

    /**
     * @dev User history checkpoint
     * exists - wether checkpoint was actually inserted (since balance can be 0)
     * balance - user latest LAT balance in specific epoch
     */
    struct Checkpoint {
        bool exists;
        uint256 balance;
    }

    /**
     * @dev history of user LAT holdings
     */
    mapping(uint256 => mapping(address => Checkpoint)) public history;

    /**
     * @dev latest epoch claimed by user
     */
    mapping(address => uint256) public lastUserEpochClaim;

    /**
     * @dev signer of depositWithSig signature
     */
    address public signer;

    /**
     * @dev hash usage mapping to prevent reuse of same hash multiple times
     */
    mapping(bytes32 => bool) public hashUsage;

    /**
     * @dev wormhole relayer which manages crosschain communication
     */
    IWormholeRelayer public wormholeRelayer;

    /**
     * @dev wormhole crosschain deposit sync gas limit
     */
    uint256 public depositGasLimit;

    /**
     * @dev KYC address for up to 50k LATs
     */
    address public KYC_50K;

    /**
     * @dev KYC address for unlimited LATs
     */
    address public KYC_UNLIMITED;

    /**
     * @dev KYC status:
     * NONE          - No KYC
     * KYC_50K       - Allowed to deposit up to 50k
     * KYC_UNLIMITED - Allowed to deposit unlimited amount
     */
    enum KycStatus {
        NONE,
        KYC_50K,
        KYC_UNLIMITED
    }

    /**
     * @dev Events
     */
    event Deposit(
        address indexed investor, 
        address indexed receiver, 
        uint256 amount, 
        uint256 fee, 
        bytes32 dataHash
    );
    event ClaimRefund(address indexed user, uint256 amountIn, uint256 amountOut);
    event Claim(address indexed user, uint256 amount);
    event FinalizeSale(uint256 amount, uint256 fee, uint8 status);
    event SignerUpdated(address signer);
    event EndPeriodWithRevenue(uint256 amount);

    /**
     * @dev Deposit USDC to get LAT tokens
     * @param amount amount of USDC tokens
     * @param user receiver of lat tokens
     * @param investorFee platform fee to be collected (if MIN_COLLECTED reached)
     * @param expiresAt signature expiration timestamp
     * @param signature signature provided by backend
     */
    function deposit(
        uint256 amount, 
        address user, 
        uint256 investorFee, 
        uint256 expiresAt, 
        bytes memory signature
    ) external payable {
        depositEx(amount, user, investorFee, expiresAt, signature);
    }

    /**
     * @dev Deposit USDC to get LAT tokens
     * @param amount amount of USDC tokens
     * @param user receiver of lat tokens
     */
    function depositSimple(
        uint256 amount, 
        address user
    ) external payable {
        depositEx(amount, user, INVESTOR_FEE, 0, new bytes(0));
    }

    /**
     * @dev Deposit USDC to get LAT tokens
     * @param amount amount of USDC tokens
     * @param user receiver of lat tokens
     * @param fee platform fee to be collected (if MIN_COLLECTED reached)
     * @param expiresAt signature expiration timestamp
     * @param signature signature provided by backend
     */
    function depositEx(
        uint256 amount, 
        address user, 
        uint256 fee, 
        uint256 expiresAt,
        bytes memory signature
    ) internal virtual nonReentrant {
        require(status == Status.SALE, "status not SALE");
        require(
            block.timestamp >= SALE_START && block.timestamp < SALE_END, 
            "Sale not open"
        );
        require(amount >= 10000, "Amount cannot be lower than 0.01 USDC");
        require(totalShares + amount <= MAX_COLLECTED, "Amount too big");
        require(fee + BENEFICIARY_FEE <= FEE_MAX_SETTABLE, "fee too high");

        KycStatus senderKYC = getKycStatus(msg.sender);
        KycStatus receiverKYC = msg.sender == user ? senderKYC : getKycStatus(user);
        require(
            senderKYC != KycStatus.NONE && receiverKYC != KycStatus.NONE, 
            "No KYC (msg.sender or user)"
        );

        // If either msg.sender or user don't have unlimited KYC or investorFee is custom
        bytes32 dataHash;
        if (
            senderKYC != KycStatus.KYC_UNLIMITED || 
            receiverKYC != KycStatus.KYC_UNLIMITED || 
            fee != INVESTOR_FEE
        ) {
            (bytes32 dHash, bool valid) = validateSignature(
                msg.sender, 
                user, 
                amount,
                fee, 
                expiresAt, 
                signature
            );
            dataHash = dHash;

            require(valid, "Invalid signature");
            require(
                !hashUsage[dataHash], 
                "Signature already used"
            );
            hashUsage[dataHash] = true;

            require(expiresAt > block.timestamp, "Signature expired");
        }
        
        totalShares += amount;

        // Calc platform fee (beneficiary fee + investor fee)
        uint256 benFee = amount * BENEFICIARY_FEE / FEE_UL;
        uint256 invFee = amount * fee / FEE_UL;

        totalPlatformFee += benFee + invFee;

        userInfo[user] += amount;
        SALE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // send LAT tokens
        _mint(user, amount - invFee);

        history[0][user].exists = true; 
        history[0][user].balance = balanceOf(user);

        // If not on main chain -- Notify MAIN_VAULT of deposit
        if (MAIN_CHAIN_ID != VAULT_CHAIN_ID) {
          
          uint256 cost = quoteCrossChainInit(MAIN_CHAIN_ID, depositGasLimit);
          require(msg.value == cost, "msg.value != cost");

          wormholeRelayer.sendPayloadToEvm{value: cost}(
              MAIN_CHAIN_ID,
              MAIN_VAULT,
              abi.encode(amount), // payload
              0, // no receiver value needed since we're just passing a message
              depositGasLimit,
              VAULT_CHAIN_ID, // refundChainId
              msg.sender // refundAddress
          );
        }

        emit Deposit(msg.sender, user, amount, fee, dataHash);
    }

    /**
     * @dev Claim refund in case sale didn't reach MIN_COLLECTED
     */
    function claimRefund() external nonReentrant {
        require(status != Status.ACTIVE, "status is ACTIVE");
        require(block.timestamp > SALE_END, "Sale not ended");
        require(totalShares < MIN_COLLECTED, "MIN_COLLECTED reached");
        uint256 bal = balanceOf(msg.sender);
        require(bal > 0, "Nothing to claim");
        
        _burn(msg.sender, bal);

        history[0][msg.sender].exists = true; 
        history[0][msg.sender].balance = 0;

        uint256 refundableAmt = userInfo[msg.sender];
        SALE_TOKEN.safeTransfer(msg.sender, refundableAmt);

        emit ClaimRefund(msg.sender, bal, refundableAmt);
    }

    /**
     * @dev Claim reward once periodical rewards are allocated
     */
    function claim() external nonReentrant {
        require(status == Status.ACTIVE, "status is not ACTIVE");

        (
            uint256 claimableAmt, 
            uint256 lastKnownBalance, 
            uint256 lastAccountedEpoch
        ) = _claimable(msg.sender);
        
        require(
            lastUserEpochClaim[msg.sender] < epoch,
            "Nothing to claim"
        );

        lastUserEpochClaim[msg.sender] = lastAccountedEpoch;
        history[lastAccountedEpoch][msg.sender].exists = true;
        history[lastAccountedEpoch][msg.sender].balance = lastKnownBalance;

        totalRevPaid += claimableAmt;
        
        SALE_TOKEN.safeTransfer(msg.sender, claimableAmt);

        emit Claim(msg.sender, claimableAmt);
    }

    /**
     * @dev Finalize sale after end timestamp is reached
     */
    function _finalizeSale() internal {
        require(canFinalizeSale(), "finalizeSale disabled");

        if (totalShares < MIN_COLLECTED) {
            status = Status.DISABLED;

            emit FinalizeSale(0, 0, uint8(status));
        } else {
            status = Status.ACTIVE;
            beneficiaryActionUnlock = block.timestamp + 86_400;

            uint256 bal = SALE_TOKEN.balanceOf(address(this));
            bal -= totalPlatformFee;

            SALE_TOKEN.safeTransfer(PLATFORM, totalPlatformFee);
            SALE_TOKEN.safeTransfer(BENEFICIARY, bal);

            emit FinalizeSale(bal, totalPlatformFee, uint8(status));
        }
    }

    /**
     * @dev End period & deposit revenue - only callable by BENEFICIARY
     * @param amount amount of USDC to be spent for user rewards
     */
    function endPeriodWithRevenue(uint256 amount) external {
        require(msg.sender == BENEFICIARY, "only BENEFICIARY");
        require(status == Status.ACTIVE, "status not ACTIVE");
        require(
            isBeneficiaryActionUnlocked(), 
            "epoch switch locked"
        );

        if (amount > 0) {
            SALE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        }

        // Calc current period revenue - takes into account amount + possible extra USDC balance on contract (which is not yet included in totalRevAlloc)
        uint256 revenueAlloc = SALE_TOKEN.balanceOf(address(this)) - (totalRevAlloc - totalRevPaid);
        require(revenueAlloc > 0, "nothing to allocate");

        epoch += 1;
        epochRevenue[epoch] = revenueAlloc;
        totalRevAlloc += revenueAlloc;
        beneficiaryActionUnlock = block.timestamp + 86_400;

        emit EndPeriodWithRevenue(revenueAlloc);
    }

    /**
     * @dev Overriden transfer function which: 
     * 1. Disables transfer if status != ACTIVE.
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(status == Status.ACTIVE, "status not ACTIVE");
        require(
            getKycStatus(msg.sender) == KycStatus.KYC_UNLIMITED, 
            "Unlimited KYC missing (msg.sender)"
        );
        require(
            getKycStatus(to) == KycStatus.KYC_UNLIMITED, 
            "Unlimited KYC missing (to)"
        );

        bool res = super.transfer(to, amount);

        // Update history for sender & recipient
        history[epoch][msg.sender].exists = true; 
        history[epoch][msg.sender].balance = balanceOf(msg.sender);

        history[epoch][to].exists = true; 
        history[epoch][to].balance = balanceOf(to);
 
        return res;
    }

    /**
    * @dev Sets signer.
    * @param _signer Address we are setting.
    */
    function setSigner(address _signer)
        external
        onlyOwner
    {
        require(_signer != address(0), "Non zero address");
        signer = _signer;
        emit SignerUpdated(signer);
    }

    /**
     * @dev Get claimable USDC amount for specified user 
     * @param targetChain chainIds (wormhole ids, NOT EVM!)
     * @param gasLimit gas limit to be used in dest chain
     */
    function quoteCrossChainInit(uint16 targetChain, uint256 gasLimit) public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, gasLimit);
    }

    /**
     * @dev Returns true if conditions for finalizeSale are met
     * an additional 24h delay is applied to assure that all sidechain deposits are synced on mainchain
     */
    function canFinalizeSale() public view returns (bool) {
        return status == Status.SALE && (isBeneficiaryActionUnlocked() || block.timestamp >= SALE_END + 86_400);
    }

    /**
     * @dev Returns true if finalizeSale/endPeriodWithRevenue action is unlocked
     */
    function isBeneficiaryActionUnlocked() public view returns (bool) {
        return beneficiaryActionUnlock > 0 && block.timestamp >= beneficiaryActionUnlock;
    }

    /**
     * @dev Get claimable USDC amount for specified user 
     * @param user user address
     */
    function claimable(address user) public view returns (uint256 amt) {
        (amt,,) = _claimable(user);
    }

    /**
     * @dev Get claimable USDC amount, lastKnownBalance, lastAccountedEpoch for specified user 
     * @param user user address
     */
    function _claimable(address user) internal view returns (uint256, uint256, uint256) {
        if (totalSupply() == 0) {
            return (0,0,0);
        }

        uint256 epochToClaim = lastUserEpochClaim[user] + 1;
        Checkpoint memory checkpoint;
        uint256 lastKnownBalance;
        uint256 amount;

        for (uint256 i = 0; i < 50; i++) {
            if (epochToClaim > epoch) {
                // last epoch reached
                break;
            }
            
            checkpoint = history[epochToClaim - 1][user];
            if (checkpoint.exists) {
                lastKnownBalance = checkpoint.balance;
            }

            amount += epochRevenue[epochToClaim] * lastKnownBalance / totalSupply();
            epochToClaim += 1;
        }

        return (amount, lastKnownBalance, epochToClaim - 1);
    }

    /**
     * @dev Convert bytes32 to address 
     */
    function fromWormholeFormat(bytes32 whFormatAddress) public pure returns (address) {
        if (uint256(whFormatAddress) >> 160 != 0) {
            revert NotAnEvmAddress(whFormatAddress);
        }
        return address(uint160(uint256(whFormatAddress)));
    }

    /**
     * @dev LAT has to have same number of decimals as SALE_TOKEN
     * SALE_TOKEN is expected to be USDC
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
    * @dev Validates signature for deposit.
    * @param sender Depositor.
    * @param receiver Receiver of LATs.
    * @param amount Amount to be invested.
    * @param investorFee platform fee to be collected (if MIN_COLLECTED reached)
    * @param expiresAt signature expiration timestamp
    * @param signature backend signature signed with signer address
    */
    function validateSignature(
        address sender, 
        address receiver, 
        uint256 amount, 
        uint256 investorFee,
        uint256 expiresAt,
        bytes memory signature
    ) public view returns (bytes32, bool) {
        bytes32 dataHash = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                sender,
                receiver,
                amount,
                investorFee,
                expiresAt
            )
        );
        bytes32 message = ECDSA.toEthSignedMessageHash(dataHash);
        address receivedAddress = ECDSA.recover(message, signature);
        return (dataHash, receivedAddress == signer);
    }

    /**
    * @dev Get contract balance of gas token
    */
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @dev Get users KYC status
    * @param user address
    */
    function getKycStatus(address user) public view returns (KycStatus) {
        if (IKYC(KYC_UNLIMITED).balanceOf(user) > 0) {
            return KycStatus.KYC_UNLIMITED;
        }
        if (IKYC(KYC_50K).balanceOf(user) > 0) {
            return KycStatus.KYC_50K;
        }
        return KycStatus.NONE;
    }
}