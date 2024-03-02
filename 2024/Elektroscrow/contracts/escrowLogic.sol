// Elektroscrow v1.0
// Utterly decentralized escrow transactions

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error Logic__NotInParties();
error Logic__AlreadyInitialized();
error Logic__NotPossibleAfterInitialize();
error Logic__NotInitializedYet();
error Logic__EscrowComplete();
error Logic__UseInitialize();
error Logic__AlreadyDeposited();

contract EscrowLogic {
    enum Decision {
        DECLINE,
        ACCEPT,
        REFUND
    }
    address public immutable i_feeWallet;
    address public immutable i_buyer;
    address public immutable i_seller;
    address public immutable i_factory;
    IERC20 public immutable i_tokenContract;
    uint256 public immutable i_amount;
    uint256 public immutable i_fee;
    bool public s_isInitialized = false;
    bool public s_buyerDeposited = false;
    bool public s_sellerDeposited = false;
    bool public s_escrowComplete = false;
    Decision public s_buyerDecision;
    Decision public s_sellerDecision;

    modifier onlyParties() {
        // require(msg.sender == owner);
        if ((msg.sender != i_buyer) && (msg.sender != i_seller))
            revert Logic__NotInParties();
        _;
    }

    constructor(
        address buyer,
        address seller,
        uint256 amount,
        address tokenContract,
        address factory,
        uint256 fee,
        address feeWallet
    ) {
        i_buyer = buyer;
        i_seller = seller;
        i_amount = amount;
        i_tokenContract = IERC20(tokenContract);
        i_factory = factory;
        i_fee = fee;
        i_feeWallet = feeWallet;
    }

    function initialize() external onlyParties {
        if (s_isInitialized) {
            revert Logic__AlreadyInitialized();
        }
        if (
            ((msg.sender == i_buyer) && (s_buyerDeposited)) ||
            ((msg.sender == i_seller) && (s_sellerDeposited))
        ) {
            revert Logic__AlreadyDeposited();
        }

        if ((msg.sender == i_buyer)) {
            s_buyerDeposited = true;

            require(
                i_tokenContract.transferFrom(
                    msg.sender,
                    address(this),
                    (2 * i_amount)
                ),
                "Transfer failed"
            );
        }
        if ((msg.sender == i_seller)) {
            s_sellerDeposited = true;

            require(
                i_tokenContract.transferFrom(
                    msg.sender,
                    address(this),
                    i_amount
                ),
                "Transfer failed"
            );
        }

        if ((s_sellerDeposited && s_buyerDeposited)) {
            s_isInitialized = true;
        }
    }

    function withdraw() external onlyParties {
        if (s_isInitialized) {
            revert Logic__NotPossibleAfterInitialize();
        }
        if ((msg.sender == i_buyer) && (s_buyerDeposited)) {
            s_buyerDeposited = false;

            require(
                i_tokenContract.approve(address(this), 2 * i_amount),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    msg.sender,
                    (2 * i_amount)
                ),
                "Transfer failed"
            );
        }
        if ((msg.sender == i_seller) && (s_sellerDeposited)) {
            s_sellerDeposited = false;
            require(
                i_tokenContract.approve(address(this), i_amount),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    msg.sender,
                    (i_amount)
                ),
                "Transfer failed"
            );
        }
    }

    function finishEscrow(Decision decision) external onlyParties {
        if (!s_isInitialized) {
            revert Logic__NotInitializedYet();
        }
        if (s_escrowComplete) {
            revert Logic__EscrowComplete();
        }
        if ((!s_sellerDeposited) || (!s_buyerDeposited)) {
            revert Logic__EscrowComplete();
        }
        if (msg.sender == i_buyer) {
            s_buyerDecision = decision;
        }
        if (msg.sender == i_seller) {
            s_sellerDecision = decision;
        }

        if (
            (s_buyerDecision == Decision.ACCEPT) &&
            (s_sellerDecision == Decision.ACCEPT)
        ) {
            uint256 feeAmount = (i_amount * i_fee) / 1000;
            s_escrowComplete = true;
            s_sellerDeposited = false;
            s_buyerDeposited = false;
            require(
                i_tokenContract.approve(address(this), 3 * i_amount),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_buyer,
                    (i_amount - (feeAmount / 2))
                ),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_seller,
                    ((2 * i_amount) - (feeAmount / 2))
                ),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_feeWallet,
                    (feeAmount)
                ),
                "Transfer failed"
            );
        }
        if (
            (s_buyerDecision == Decision.REFUND) &&
            (s_sellerDecision == Decision.REFUND)
        ) {
            uint256 feeAmount = (i_amount * i_fee) / 1000;
            s_escrowComplete = true;
            s_sellerDeposited = false;
            s_buyerDeposited = false;
            require(
                i_tokenContract.approve(address(this), 3 * i_amount),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_buyer,
                    ((2 * i_amount) - (feeAmount / 2))
                ),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_seller,
                    (i_amount - (feeAmount / 2))
                ),
                "Transfer failed"
            );
            require(
                i_tokenContract.transferFrom(
                    address(this),
                    i_feeWallet,
                    (feeAmount)
                ),
                "Transfer failed"
            );
        }
    }

    function rescueERC20(address tokenAddress) external {
        require(s_escrowComplete, "Escrow ongoing");
        IERC20 token = IERC20(tokenAddress);
        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(i_factory, amount), "Transfer failed");
    }

    function getBalance() external view returns (uint256) {
        return i_tokenContract.balanceOf(address(this));
    }

    function getDecisions() public view returns (Decision, Decision) {
        return (s_buyerDecision, s_sellerDecision);
    }

    function getAmount() public view returns (uint256) {
        return (i_amount);
    }

    function getTokenContract() public view returns (address) {
        return (address(i_tokenContract));
    }

    function checkPayment(address account) public view returns (uint256) {
        if ((account == i_seller) && (s_sellerDeposited)) {
            return i_amount;
        }
        if ((account == i_buyer) && (s_buyerDeposited)) {
            return i_amount * 2;
        } else {
            return 0;
        }
    }

    function getInitilizeState() public view returns (bool) {
        return s_isInitialized;
    }

    function getEscrowState() public view returns (bool) {
        return s_escrowComplete;
    }

    fallback() external payable {
        revert Logic__UseInitialize();
    }

    receive() external payable {
        revert Logic__UseInitialize();
    }
}