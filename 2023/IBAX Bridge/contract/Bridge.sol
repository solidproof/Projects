// SPDX-License-Identifier: GPL-3.0

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

pragma solidity ^0.8.6;

contract Bridge is Ownable, Pausable {
    using SafeERC20 for IERC20;

    event Deposit(address indexed sender, address token, uint256 amount);

    event Withdraw(
        address indexed sender,
        address token,
        uint256 amount,
        string message
    );

    address public immutable WETH;
    address[] public signers;
    mapping(address => bool) public isSigner;
    mapping(string => bool) public txHashs;
    uint256 public required;

    error VerifySignError(address caller, uint256 amount);

    modifier checkAmount(uint256 amount) {
        require(amount > 0, "amount is zero");
        _;
    }
    modifier checkSigLen(bytes[] memory signatures) {
        require(
            signatures.length == required,
            "the quantity of check is incorrect"
        );
        _;
    }

    constructor(
        address _WETH,
        address[] memory _signers,
        uint256 _required
    ) {
        require(isContract(_WETH), "not a contract");
        require(_signers.length > 0, "signers required");
        require(
            _required > 0 && _required <= _signers.length,
            "invalid required number of signers"
        );
        for (uint256 i = 0; i < _signers.length; ++i) {
            address _signer = _signers[i];
            require(_signer != address(0), "0 address");
            require(!isContract(_signer), "not an account address");
            require(!isSigner[_signer], "signer is not unique");

            isSigner[_signer] = true;
            signers.push(_signer);
        }
        WETH = _WETH;
        required = _required;
    }

    receive() external payable {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function depositETH() external payable whenNotPaused {
        uint256 ETHAmount = msg.value;

        if (msg.value != 0) {
            IWETH(payable(WETH)).deposit{value: ETHAmount}();
        }
        require(
            IWETH(payable(WETH)).balanceOf(address(this)) >= ETHAmount,
            "Ethereum not deposited"
        );
        IWETH(payable(WETH)).transfer(msg.sender, ETHAmount);
        IWETH(payable(WETH)).transferFrom(
            address(msg.sender),
            address(this),
            ETHAmount
        );
        emit Deposit(msg.sender, WETH, ETHAmount);
    }

    function deposit(address token, uint256 amount)
    external
    checkAmount(amount)
    whenNotPaused
    {
        require(isContract(token), "not a contract");
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            "insufficient allowance"
        );
        IERC20(payable(token)).safeTransferFrom(
            address(msg.sender),
            address(this),
            amount
        );
        emit Deposit(msg.sender, address(token), amount);
    }

    function withdraw(
        address token,
        bytes[] memory signatures,
        string memory txhash,
        uint256 amount
    ) external checkAmount(amount) checkSigLen(signatures) whenNotPaused {
        require(isContract(token), "not a contract");
        require(!txHashs[txhash], "already withdraw");
        require(signaturesUnique(signatures), "duplicate signatures");

        string memory message = string(
            abi.encodePacked(
                txhash,
                Strings.toHexString(msg.sender),
                Strings.toString(amount),
                Strings.toString(block.chainid),
                Strings.toHexString(token)
            )
        );

        if (token == WETH) {
            require(
                IWETH(payable(WETH)).balanceOf(address(this)) >= amount,
                "insufficient balance"
            );

            if (verify(signatures, message)) {
                txHashs[txhash] = true;
                IWETH(payable(WETH)).withdraw(amount);
                payable(msg.sender).transfer(address(this).balance);
                emit Withdraw(msg.sender, WETH, amount, message);
            } else {
                revert VerifySignError(msg.sender, amount);
            }
        } else {
            require(
                IERC20(token).balanceOf(address(this)) >= amount,
                "insufficient balance"
            );

            if (verify(signatures, message)) {
                txHashs[txhash] = true;
                IERC20(token).safeTransfer(address(msg.sender), amount);
                emit Withdraw(msg.sender, token, amount, message);
            } else {
                revert VerifySignError(msg.sender, amount);
            }
        }
    }

    function addSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "0 address");
        require(!isContract(_signer), "not an account address");
        require(!isSigner[_signer], "signer is not unique");

        isSigner[_signer] = true;
        signers.push(_signer);
    }

    function cancelSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "0 address");
        require(!isContract(_signer), "not an account address");
        require(isSigner[_signer], "signer is not exist");
        delete isSigner[_signer];
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
    }

    function updateRequired(uint256 _required) external onlyOwner {
        require(
            _required > 0 && _required <= signers.length,
            "invalid required number of signers"
        );
        required = _required;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function verify(bytes[] memory signatures, string memory message)
    private
    view
    returns (bool)
    {
        bytes32 messageHash = getMessageHash(message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        bool res = true;
        for (uint256 i = 0; i < signatures.length; i++) {
            address relay = recover(ethSignedMessageHash, signatures[i]);
            if (!isSigner[relay]) {
                res = false;
                break;
            }
        }

        return res;
    }

    function getMessageHash(string memory message)
    private
    pure
    returns (bytes32)
    {
        return keccak256(abi.encodePacked(message));
    }

    function getEthSignedMessageHash(bytes32 messageHash)
    private
    pure
    returns (bytes32)
    {
        return
        keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                messageHash
            )
        );
    }

    function recover(bytes32 ethSignedMessageHash, bytes memory sig)
    private
    pure
    returns (address)
    {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);

        return ecrecover(ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
    private
    pure
    returns (
        uint8 v,
        bytes32 r,
        bytes32 s
    )
    {
        require(sig.length == 65);

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    function signaturesUnique(bytes[] memory signatures)
    public
    pure
    returns (bool)
    {
        uint256 len = signatures.length;
        for (uint256 i = 0; i < len - 1; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (bytesEqual(signatures[i], signatures[j])) {
                    return false;
                }
            }
        }
        return true;
    }

    function bytesEqual(bytes memory a, bytes memory b)
    public
    pure
    returns (bool)
    {
        return (keccak256(a) == keccak256(b));
    }

    function isContract(address addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}

interface IWETH is IERC20 {
    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 amount) external;
}