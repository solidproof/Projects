// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Timelock {
    using SafeMath for uint;

    /**
     * @dev Events emitted by the contract
     */
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);
    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data,
        uint eta
    );

    /**
     * @dev Contract state variables
     */
    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 60;
    uint public constant MAXIMUM_DELAY = 30 days;

    address public admin;
    address public pendingAdmin;
    bool public timelockInitialised;
    uint public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    /**
     * @dev Constructor to initialize the Timelock contract
     * @param admin_ The initial admin address
     * @param delay_ The initial time delay for transactions
     */
    constructor(address admin_, uint delay_) {
        require(
            delay_ >= MINIMUM_DELAY,
            "Timelock::constructor: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Timelock::setDelay: Delay must not exceed maximum delay."
        );

        admin = admin_;
        delay = delay_;
        emit NewAdmin(admin_);
        emit NewDelay(delay_);
    }

    fallback() external payable {}

    receive() external payable {}

    /**
     * @dev Sets a new time delay for transactions
     * @param delay_ The new time delay to be set
     */
    function setDelay(uint delay_) public {
        require(
            msg.sender == address(this),
            "Timelock::setDelay: Call must come from Timelock."
        );
        require(
            delay_ >= MINIMUM_DELAY,
            "Timelock::setDelay: Delay must exceed minimum delay."
        );
        require(
            delay_ <= MAXIMUM_DELAY,
            "Timelock::setDelay: Delay must not exceed maximum delay."
        );
        delay = delay_;

        emit NewDelay(delay);
    }

    /**
     * @dev Accepts the pending admin as the new admin
     */
    function acceptAdmin() public {
        require(
            msg.sender == pendingAdmin,
            "Timelock::acceptAdmin: Call must come from pendingAdmin."
        );
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    /**
     * @dev Sets a new pending admin address
     * @param pendingAdmin_ The new pending admin address
     */
    function setPendingAdmin(address pendingAdmin_) public {
        if (!timelockInitialised) {
            require(
                msg.sender == admin,
                "Timelock::setPendingAdmin: Call must come from admin."
            );
        } else {
            require(
                msg.sender == address(this),
                "Timelock::setPendingAdmin: Call must come from Timelock."
            );
        }
        timelockInitialised = true;
        pendingAdmin = pendingAdmin_;
        emit NewPendingAdmin(pendingAdmin);
    }

    /**
     * @dev Queues a transaction for future execution
     * @param target The target address of the transaction
     * @param value The value to be sent with the transaction
     * @param signature The signature of the function to be called
     * @param data The data for the function call
     * @param eta The execution time for the transaction
     * @return txHash The hash of the queued transaction
     */
    function queueTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public returns (bytes32) {
        require(
            msg.sender == admin,
            "Timelock::queueTransaction: Call must come from admin."
        );
        require(
            eta >= getBlockTimestamp().add(delay),
            "Timelock::queueTransaction: Estimated execution block must satisfy delay."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;

        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }

    /**
     * @dev Cancels a previously queued transaction
     * @param target The target address of the transaction
     * @param value The value associated with the transaction
     * @param signature The signature of the function to be called
     * @param data The data for the function call
     * @param eta The execution time for the transaction
     */
    function cancelTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public {
        require(
            msg.sender == admin,
            "Timelock::cancelTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    /**
     * @dev Executes a previously queued transaction
     * @param target The target address of the transaction
     * @param value The value to be sent with the transaction
     * @param signature The signature of the function to be called
     * @param data The data for the function call
     * @param eta The execution time for the transaction
     * @return returnData The return data from the executed transaction
     */
    function executeTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) public payable returns (bytes memory) {
        require(
            msg.sender == admin,
            "Timelock::executeTransaction: Call must come from admin."
        );

        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(
            queuedTransactions[txHash],
            "Timelock::executeTransaction: Transaction hasn't been queued."
        );
        require(
            getBlockTimestamp() >= eta,
            "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
        );
        require(
            getBlockTimestamp() <= eta.add(GRACE_PERIOD),
            "Timelock::executeTransaction: Transaction is stale."
        );

        queuedTransactions[txHash] = false;

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(
            success,
            "Timelock::executeTransaction: Transaction execution reverted."
        );

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

    /// @dev Get the current block timestamp.
    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}