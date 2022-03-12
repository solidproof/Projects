// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.9;
pragma abicoder v2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TransferHelper.sol";
import "./IMaster.sol";
import "./IBridgeVault.sol";

contract Bridge is Ownable, ReentrancyGuard {
    uint256 public fee;
    address public governance;
    address public token;
    address public verifier;
    address public master;
    address public vault;

    constructor(
        address _master,
        address _token,
        address _verifier,
        address _governance,
        address _vault,
        uint256 _fee
    ) {
        require(_master != address(0), "Bridge:: _master can not be Zero");
        require(_token != address(0), "Bridge:: _token can not be Zero");
        require(_verifier != address(0), "Bridge:: _verifier can not be Zero");
        require(_governance != address(0), "Bridge:: _governance can not be Zero");
        require(_vault != address(0), "Bridge:: _vault can not be Zero");
        token = _token;
        verifier = _verifier;
        governance = _governance;
        fee = _fee;
        vault = _vault;
        master = _master;
    }

    event BridgeFeeUpdated(uint256 _oldFee, uint256 _newFee);
    event Deposited(
        address account,
        uint256 amount,
        uint256 chainId,
        uint256 nonce,
        address token
    );
    event Withdrawal(
        address account,
        uint256 amount,
        uint256 nonce,
        bytes32 txHash,
        uint256 chainId,
        address token
    );
    event VerifierChanged(
        address _oldVerifier,
        address _newVerifier,
        uint256 _when
    );
    event GovernanceChanged(
        address _oldGovernance,
        address _newGovernance,
        uint256 _when
    );

    // deposit index of other chain  => withdrawal in current chain
    mapping(uint256 => mapping(uint256 => bool))
        public claimedWithdrawalsByOtherChainDepositId;

    // deposit nonce for current chain
    uint256 public txNonce;

    modifier onlyGovernance() {
        require(governance == msg.sender, "Bridge:: Unauthorized Access");
        _;
    }

    function updateGovernance(address _newGovernance) external onlyGovernance {
        require(
            _newGovernance != address(0),
            "Bridge :: updateGovernance :: Invalid _newGovernance"
        );
        emit GovernanceChanged(governance, _newGovernance, block.timestamp);
        governance = _newGovernance;
    }

    function updateVerifier(address _newVerifierAddress)
        external
        onlyGovernance
    {
        require(
            _newVerifierAddress != address(0),
            "Bridge :: setVerifyAddress :: Invalid _newVerifierAddress"
        );
        emit VerifierChanged(verifier, _newVerifierAddress, block.timestamp);
        verifier = _newVerifierAddress;
    }

    function updateBridgeFee(uint256 _fee) external {
        require(
            IMaster(master).getTreasury() == msg.sender,
            "Updated Bridge Fee: Unauthorized Access"
        );
        emit BridgeFeeUpdated(fee, _fee);
        fee = _fee;
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Bridge:: deposit:: Invalid _amount");
        txNonce = txNonce + 1;
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            vault,
            _amount
        );
        if (fee > 0) transferFee(fee);
        emit Deposited(msg.sender, _amount, block.chainid, txNonce, token);
    }

    // _data is an array of 4 items
    // _data[0] is amount
    // _data[1] is withdrawchainId
    // _data[2] is nonce
    // _data[3] is _v
    // _hashData
    // _hashData[0] is _txHash
    // _hashData[1] is _r
    // _hashData[2] is _s

    function withdraw(uint256[4] calldata _data, bytes32[3] calldata _hashData)
        external
        nonReentrant
    {
        require(
            !claimedWithdrawalsByOtherChainDepositId[_data[1]][_data[2]],
            "Bridge:: Withdraw :: Already Withdrawn!"
        );
        claimedWithdrawalsByOtherChainDepositId[_data[1]][_data[2]] = true;
        require(
            ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        keccak256(
                            abi.encodePacked(
                                msg.sender,
                                _data[0],
                                _data[1],
                                _data[2],
                                _hashData[0],
                                address(this)
                            )
                        )
                    )
                ),
                uint8(_data[3]),
                _hashData[1],
                _hashData[2]
            ) == verifier,
            "Bridge:: Withdraw :: Invalid Signature"
        );
        IBridgeVault(vault).bridgeWithdrawal(token, msg.sender, _data[0]);
        emit Withdrawal(
            msg.sender,
            _data[0],
            _data[2],
            _hashData[0],
            _data[1],
            token
        );
    }

    function transferFee(uint256 _fee) internal {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            IMaster(master).getTreasury(),
            _fee
        );
    }

    function generateMessage(
        address _account,
        uint256 _amount,
        uint256 _chainId,
        uint256 _nonce,
        bytes32 _txHash,
        address _contractAddress
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    _account,
                    _amount,
                    _chainId,
                    _nonce,
                    _txHash,
                    _contractAddress
                )
            );
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public pure returns (address) {
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }
}