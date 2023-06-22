// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract EthContribution is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many ETH the user has invested.
        uint256 lastInvestmentTime; // last time invested.
    }

    // max eth investment
    uint256 public maxInvestment;
    // current total investment
    uint256 public totalInvested;
    // sale start time
    uint256 public saleStartTime;
    // sale duration
    uint256 public saleDuration;
    // max per wallet invest
    uint256 public maxPerWalletInvest;

    // info of blacklist user
    mapping(address => bool) public blacklistUsers;
    // Info of each user.
    mapping (address => UserInfo) public userInfo;
    // merket root 
    bytes32 public merkleRoot;

    /**
     * @dev Events
     */
    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event setSaleDurationEvent(uint indexed _newDuration);
    event setSaleStartTimeEvent(uint indexed _newTime);
    event setMerkleRootEvent(bytes32 _newRoot);
    event setBlacklistUserEvent(address _user, bool _status);
    event setAddressToMintsWLNFTEvent(address _user, uint _amount);
    event setMaxPerWalletInvestEvent(uint indexed _newMaxInvestWallet);
    event setMaxInvestmentEvent(uint indexed _maxInvestment);
    event Invest(address _user, uint amount);
    event WithdrawAllEvent(address _to, uint _contractBalance);

    function initialize(
        uint256 _maxInvestment,
        uint256 _saleStartTime,
        uint256 _saleDuration,
        uint256 _maxPerWalletInvest
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();

        maxInvestment = _maxInvestment;
        saleStartTime = _saleStartTime;
        saleDuration = _saleDuration;
        maxPerWalletInvest = _maxPerWalletInvest;
    }

    /**
     * @notice Validates the sale data for each phase per user
     *
     * @dev For each phase validates that the time is correct,
     * that the ether supplied is correct and that the purchase
     * amount doesn't exceed the max amount
     *
     * @param amount. The amount the user want's to invest
     * @param proofWL. The proof used to validate if user is whitelisted or not.
     */
    function validateInvestment(
        uint256 amount,
        bytes32[] calldata proofWL
    ) internal view {
        UserInfo storage user = userInfo[msg.sender];
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            block.timestamp >= saleStartTime,
            "Investment HASN'T STARTED YET"
        );
        require(
            block.timestamp < saleStartTime + saleDuration,
            "Investment IS CLOSED"
        );
        require(
            (amount + user.amount) <= maxPerWalletInvest,
            "Invested amount reach max limit"
        );
        require(merkleRoot != "", "PERMISSIONED Investment CLOSED");
        require(MerkleProofUpgradeable.verify(proofWL, merkleRoot, leaf) == true, "Not Whitelisted");
    }

    /**
     * @notice Function to invest one or more tickets.
     * @dev First the Merkle Proof is verified.
     * Then the invest is verified with the data embedded in the Merkle Proof.
     * Finally the tokens are bought to the user's wallet.
     *
     * @param amount. The amount of tickets to buy.
     * @param proofWL. The Merkle Proof of the user.
     */
    function invest(
        uint256 amount,
        bytes32[] calldata proofWL
    ) external payable {
        /// @dev Verify that user can perform permissioned sale based on the provided parameters.
        
        require(msg.value == amount, "Invalid data");
        require(blacklistUsers[msg.sender] != true, "Not allowed to invest");
        require(amount > 0, "HAVE TO Invest AT LEAST 1");

        UserInfo storage user = userInfo[msg.sender];

        require(
            totalInvested + amount <= maxInvestment,
            "Investment AMOUNT GOES OVER MAX Limit"
        );

        /// @dev verify that user can perform permissioned sale based on phase of user
        validateInvestment(amount, proofWL);
        totalInvested += amount;

        user.amount = (user.amount) + amount;
        user.lastInvestmentTime = block.timestamp;

        emit Invest(msg.sender, amount);
    }

    /**
     * @notice Change the maximum investment.
     *
     * @param _maxInvestment. The new max supply.
     */
    function setMaxInvestment(uint256 _maxInvestment) external onlyOwner {
        maxInvestment = _maxInvestment;
        emit setMaxInvestmentEvent(_maxInvestment);
    }

    /**
     * @notice Change white list invest limit per wallet.
     *
     * @param _newMaxInvestWallet. The new limit.
     */
    function setMaxPerWalletInvest(uint256 _newMaxInvestWallet) external onlyOwner {
        maxPerWalletInvest = _newMaxInvestWallet;
        emit setMaxPerWalletInvestEvent(_newMaxInvestWallet);
    }

    /**
     * @notice black list any user.
     *
     * @param _user. The user address.
     * @param _status. true for blacklist.
     */
    function updateBlacklistUser(address _user, bool _status) external onlyOwner {
        blacklistUsers[_user] = _status;
        emit setBlacklistUserEvent(_user, _status);
    }

    /**
     * @notice Change the phase one merkle root.
     *
     * @param _newRoot. The new merkleRootSpotOne.
     */
    function setMerkleRoot(bytes32 _newRoot) external onlyOwner {
        merkleRoot = _newRoot;
        emit setMerkleRootEvent(_newRoot);
    }

    /**
     *
     * @notice Allows owner to withdraw f @notice Change start time of the phase one sale.
     *
     * @param _newTime. The new time.
     */
    function setSaleStartTime(uint256 _newTime) external onlyOwner {
        saleStartTime = _newTime;
        emit setSaleStartTimeEvent(_newTime);
    }

    /**
     * @notice Change duration of the phase two sale.
     *
     * @param _newDuration. The new duration.
     */
    function setSaleDuration(uint256 _newDuration) external onlyOwner {
        saleDuration = _newDuration;
        emit setSaleDurationEvent(_newDuration);
    }

    /**
     * @notice Allows owner to withdraw funds generated from sale.
     */
    function withdrawAll() external onlyOwner {
        address _to = msg.sender;
        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NO ETHER TO WITHDRAW");

        payable(_to).transfer(contractBalance);
        emit WithdrawAllEvent(_to, contractBalance);
    }

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }
}