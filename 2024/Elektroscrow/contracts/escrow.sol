// Elektroscrow v1.0
// Utterly decentralized escrow transactions

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.18;
import "./escrowLogic.sol";

error Factory__NotOwner();
error Factory_Error();

contract escrow {
    event EscrowCreated(
        address indexed buyer,
        address indexed seller,
        address escrowContract
    );
    event OwnerUpdate(address owner);
    event FeeWalletUpdate(address feeWallet);
    event FeeUpdate(uint256 fee);

    address public s_owner;
    address public s_feeWallet;
    uint256 public s_fee;

    mapping(address => address[]) public s_buyerToEscrowAddy;
    mapping(address => address[]) public s_sellerToEscrowAddy;

    modifier onlyOwner() {
        // require(msg.sender == owner);
        if (msg.sender != s_owner) revert Factory__NotOwner();
        _;
    }

    constructor() {
        s_owner = msg.sender;
        s_feeWallet = msg.sender;
        s_fee = 15;
    }

    function escrowFactory(
        address seller,
        uint256 amount,
        address tokenContract
    ) external {
        address buyer = msg.sender;
        if (
            (buyer == address(0)) ||
            (seller == address(0)) ||
            (tokenContract == address(0))
        ) {
            revert("Zero address");
        }
        require(amount != 0, "Amount zero");
        EscrowLogic child = new EscrowLogic(
            buyer,
            seller,
            amount,
            tokenContract,
            address(this),
            s_fee,
            s_feeWallet
        );
        s_buyerToEscrowAddy[buyer].push(address(child));
        s_sellerToEscrowAddy[seller].push(address(child));
        emit EscrowCreated(buyer, seller, address(child));
    }

    function updateOwner(address account) external onlyOwner {
        require(account != address(0), "Zero address");
        s_owner = account;
        emit OwnerUpdate(account);
    }

    function updateFeeWallet(address account) external onlyOwner {
        require(account != address(0), "Zero address");
        s_feeWallet = account;
        emit FeeWalletUpdate(account);
    }

    function updateFee(uint256 fee) external onlyOwner {
        require(fee <= 20, "Err");
        s_fee = fee;
        emit FeeUpdate(fee);
    }

    function rescueERC20(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        uint256 amount = token.balanceOf(address(this));
        require(token.transfer(s_owner, amount), "Transfer failed");
    }

    function getBuyerEscrows(
        address buyer
    ) public view returns (address[] memory) {
        return s_buyerToEscrowAddy[buyer];
    }

    function getSellerEscrows(
        address seller
    ) public view returns (address[] memory) {
        return s_sellerToEscrowAddy[seller];
    }

    fallback() external payable {
        revert Factory_Error();
    }

    receive() external payable {
        revert Factory_Error();
    }
}