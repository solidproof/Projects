// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./MerkleTreeWithHistory.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IVerifier {
    function verifyProof(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[5] memory input
    ) external pure returns (bool r);
}

contract CipherCore_ETH_1 is MerkleTreeWithHistory, ReentrancyGuard {
    
    mapping(bytes32 => bool) public nullifiers;
    mapping(bytes32 => bool) public commitments;

    IVerifier public immutable verifier;
    uint public denomination = 1 ether;
    uint public platFormFee = 0.005 ether;   // 0.5%
    address payable public platFormAddress;  

    event Deposit(
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp 
    );
    
    event Withdrawal(address to, bytes32 _nullifier, address relayer, uint256 fee);
    event Check(bytes32 _root);

    constructor(
        uint32 _levels,
        IHasher _hasher,
        IVerifier _verifier
    ) MerkleTreeWithHistory(_levels, _hasher) {
        verifier = _verifier; 
    }


    function deposit(uint256 _commitment) external payable nonReentrant  {
        require(!commitments[bytes32(_commitment)], "commitment already submitted");
        require(denomination == msg.value, "invalid deposit amount");
        commitments[bytes32(_commitment)] = true;
        uint32 insertedIndex = _insert(bytes32(_commitment));
        emit Deposit(bytes32(_commitment), insertedIndex, block.timestamp);
    }

    function withdraw(uint256 _nullifier,
        uint256 _root,
        uint[2] memory _proof_a,
        uint[2][2] memory _proof_b,
        uint[2] memory _proof_c,
        uint256 _relayerFee,
        address payable _relayer,
        address payable _recipient) external nonReentrant {   

        _nullify(bytes32(_nullifier),bytes32(_root),_proof_a,_proof_b,_proof_c, _relayerFee, _relayer, _recipient);
        require(_relayerFee <= denomination / 2, "Fee too high");
        
        (bool success, ) = _recipient.call{ value: denomination - _relayerFee - platFormFee }("");
        require(success, "payment to recipient failed");

        if (_relayerFee > 0) {
            (success, ) = _relayer.call{ value: _relayerFee }("");
            require(success, "payment to relayer failed");
        }

        if (platFormFee > 0) {
            (success, ) = platFormAddress.call{ value: platFormFee }("");
            require(success, "payment to feeAddress failed");
        }

        emit Check(bytes32(_root));
        emit Withdrawal(_recipient, bytes32(_nullifier), _relayer, _relayerFee);
    }

    function _nullify(
        bytes32 _nullifier,
        bytes32 _root,
        uint[2] memory _proof_a,
        uint[2][2] memory _proof_b,
        uint[2] memory _proof_c,
        uint256 _relayerFee,
        address _relayer,
        address _recipient
    ) internal {
        require(!nullifiers[_nullifier], "nullifier already submitted");
        require(isKnownRoot(_root), "cant't find your merkle root");
        require(
            verifier.verifyProof(
                _proof_a,
                _proof_b,
                _proof_c,
                [uint256(_nullifier), uint256(_root), uint256(_recipient), uint256(_relayer), uint256(_relayerFee)]
            ),
            "Invalid proof"
        );

        nullifiers[_nullifier] = true;        
    }

    function isSpent(bytes32 _nullifierHash) public view returns (bool) {
        return nullifiers[_nullifierHash];
    }

    function setPlatformParamas(address payable _platformAddress, uint _platformFee) external {
        require(_platformFee <= denomination / 2 , "fee too high");
        if (platFormAddress != address(0)) {
            require(msg.sender == platFormAddress, "Unauthorized!");
        }
        platFormAddress = _platformAddress;
        platFormFee = _platformFee;
    }


}