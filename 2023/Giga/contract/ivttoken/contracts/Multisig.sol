// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title MultiSig
 * @dev Implements a multi-signature wallet. Transactions can be executed only when approved by a threshold number of signers.
 */
contract MultiSig is EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    event NewSigner(address signer);
    event NewTheshold(uint threshold);
    event SignerRemoved(address signer);
    event Execution(address destination, bool success, bytes returndata);

    // Multisig transaction payload
    struct TxnRequest {
        address to;
        uint256 value;
        bytes data;
        bytes32 nonce;
    }

    // Variables
    address[] public signers;
    mapping (address => bool) public isSigner;
    mapping (bytes32 => bool) public executed;
    uint256 public threshold;

    /**
     * @dev Contract constructor. Sets the initial signers and threshold.
     * @param _secondSigner The address of the second signer.
     * @param _thirdSigner The address of the third signer.
     */
    constructor(address _secondSigner, address _thirdSigner) EIP712("MultiSig", "1.0.0") {
        require(_secondSigner != address(0), "Second signer address cannot be the zero address");
        require(_thirdSigner != address(0), "Third signer address cannot be the zero address");
        require(_secondSigner != _thirdSigner, "Second signer address cannot be the third signer address");
        require(_secondSigner != msg.sender, "Second signer address cannot be the sender address");
        require(_thirdSigner != msg.sender, "Third signer address cannot be the sender address");

        threshold = 2;

        signers.push(msg.sender);
        signers.push(_secondSigner);
        signers.push(_thirdSigner);

        isSigner[msg.sender] = true;
        isSigner[_secondSigner] = true;
        isSigner[_thirdSigner] = true;
    }

    /**
     * @dev Allows the contract to receive funds.
     */
    receive() external payable {}

    /**
     * @dev Returns hash of data to be signed
     * @param params The struct containing transaction data
     * @return Packed hash that is to be signed
     */
    function typedDataHash(TxnRequest memory params) public view returns (bytes32) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("TxnRequest(address to,uint256 value,bytes data,bytes32 nonce)"),
                    params.to,
                    params.value,
                    keccak256(params.data),
                    params.nonce
                )
            )
        );
        return digest;
    }

    /**
     * @dev Utility function to recover a signer given a signature
     * @param _to The to address of the transaction
     * @param _value Transaction value
     * @param _data Transaction calldata
     * @param _nonce Transaction nonce
     * @param userSignature The signature provided by the user
     * @return The address of the signer
     */
    function recoverSigner(address _to, uint256 _value, bytes memory _data, bytes memory userSignature, bytes32 _nonce) public view returns (address) {
        TxnRequest memory params = TxnRequest({
            to: _to,
            value: _value,
            data: _data,
            nonce: _nonce
        });
        bytes32 digest = typedDataHash(params);
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(digest), userSignature);
    }

    /**
     * @dev Adds additional owners to the multisig
     * @param _signer The address to be added to the signers list
     */
    function addAdditionalOwners(address _signer) public onlySigner {
        require(_signer != address(0), "Signer address cannot be the zero address");
        require(!isSigner[_signer], "Address is already a signer.");

        signers.push(_signer);
        isSigner[_signer] = true;

        emit NewSigner(_signer);
    }

    /**
     * @dev Allows a signer to resign, removing them from the multisig
     */
    function resign() public onlySigner {
        require(signers.length > 2, "Cannot remove last 2 signers.");
        
        uint index = 0;
        for (uint i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                index = i;
                break;
            }
        }

        for (uint i = index; i < signers.length - 1; i++) {
            signers[i] = signers[i+1];            
        }
        signers.pop(); // delete the last item

        isSigner[msg.sender] = false;

        emit SignerRemoved(msg.sender);
    }

    /**
     * @dev Executes a multisig transaction given an array of signatures, and TxnRequest params
     * @param signatures The array of signatures from multisig holders
     * @param _to The address a transaction should be sent to
     * @param _value The transaction value
     * @param _data The data to be sent with the transaction (e.g: to call a contract function)
     * @param _nonce The transaction nonce
     * @return The return data from the transaction call
     */
    function executeTransaction(bytes[] memory signatures, address _to, uint256 _value, bytes memory _data, bytes32 _nonce) public onlySigner nonReentrant returns (bytes memory) {
        // require minimum # of signatures (m-of-n)
        require(signatures.length >= threshold, "Invalid number of signatures");
        require(_to != address(0), "Cannot send to zero address.");

        // construct transaction
        TxnRequest memory txn = TxnRequest({
            to: _to,
            value: _value,
            data: _data,
            nonce: _nonce
        });

        // create typed hash
        bytes32 digest = typedDataHash(txn);

        // verify replay
        require(!executed[digest], "Transaction has already been executed.");

        // get the signer of the message
        verifySigners(signatures, digest);    

        // execute transaction
        (bool success, bytes memory returndata) = txn.to.call{value: txn.value}(_data);
        require(success, "Failed transaction");
        executed[digest] = true;

        emit Execution(txn.to, success, returndata);

        return returndata;
    }

    /**
     * @dev Changes the threshold for the multisig
     * @param _threshold The new threshold
     */
    function changeThreshold(uint _threshold) public onlySigner {
        require(_threshold <= signers.length, "Threshold cannot exceed number of signers.");
        require(_threshold >= 2, "Threshold cannot be < 2.");
        threshold = _threshold;

        emit NewTheshold(threshold);
    }

    /**
     * @dev Returns the current number of signers.
     * @return The number of signers
     */
    function getOwnerCount() public view returns (uint256) {
        return signers.length;
    }

    /**
     * @dev Returns the current list of signers.
     * @return The list of signers
     */
    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    /**
     * @dev Verifies if signers are part of the signers' list.
     * @param signatures The list of signatures to be verified
     * @param digest The hash of the transaction data
     * @return A boolean indicating if all signers are valid
     */
    function verifySigners(bytes[] memory signatures, bytes32 digest) public view returns (bool) {
        for (uint i = 0; i < threshold; i ++) {            
            // recover signer address
            address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(digest), signatures[i]);
            // verify that signer is owner (any signer can execute the transaction given a set of off-chain signatures)
            require(isSigner[signer], "Invalid signer");
        }
        return true;
    }
   
    /**
     * @dev Modifier to make a function callable only by a signer.
     */
    modifier onlySigner() {
        require(isSigner[msg.sender], "Unauthorized signer.");
        _;
    }
}
