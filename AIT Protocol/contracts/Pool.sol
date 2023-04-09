// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./lzApp/NonblockingLzApp.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
/// @title A LayerZero example sending a cross chain message from a source chain to a destination chain to increment a counter
contract Pool is NonblockingLzApp {
    using SafeERC20 for IERC20;
    mapping(bytes => bool) public usedSignatures;
    mapping(address => bool) public admin;
    IERC20 internal immutable AIT;
    uint public chainId;
    constructor(address _lzEndpoint, address _ait, uint _chainId) NonblockingLzApp(_lzEndpoint) {
        AIT = IERC20(_ait);
        chainId = _chainId;
    }

    event AddAdmin(
        address admin,
        bool status,
        uint timeStamp
    );
    event Claim(
        uint chainId,
        address user,
        uint amount,
        uint timeStamp
    );
    event DstClaim(
        uint chainId,
        address user,
        uint amount, 
        uint timeStamp
    );
    event Deposit(
        uint stt,
        address dev,
        uint amount,
        uint timeStamp
    );
    function addAdmin(address _admin) external onlyOwner {
        admin[_admin] = !admin[_admin];
        emit AddAdmin(_admin, admin[_admin], block.timestamp);
    } 
    function deposit(uint _stt, uint _amount) external {
        AIT.safeTransferFrom(msg.sender, address(this), _amount);
        emit Deposit(_stt, msg.sender, _amount, block.timestamp);
    }
    function _nonblockingLzReceive(uint16, bytes memory, uint64, bytes memory payload) internal override {
        ( uint _chainId, address _user, uint _amount) = abi.decode(payload, (uint, address, uint));
        AIT.safeTransfer(_user, _amount);
        emit DstClaim(_chainId, _user, _amount, block.timestamp);
    }

    function estimateFee(uint16 _dstChainId, bytes calldata payload, bool _useZro, bytes calldata _adapterParams) public view returns (uint nativeFee, uint zroFee) {
        return lzEndpoint.estimateFees(_dstChainId, address(this), payload, _useZro, _adapterParams);
    }

    function claimTo(uint16 _dstChainId, address _user, uint _amount, uint _timeStamp, bytes calldata signature, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) public payable {
        require(!usedSignatures[signature], "Signature used.");
        bytes32 criteriaMessageHash = signMessage(_user, _amount, _dstChainId, _timeStamp);
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(criteriaMessageHash);
        require(admin[ECDSA.recover(ethSignedMessageHash, signature)], "Invalid signature");
        if(_dstChainId == chainId){
            AIT.safeTransfer(_user, _amount);
        }else{
            bytes  memory message = abi.encode(chainId, _user, _amount);
            _lzSend(_dstChainId, message, _refundAddress, _zroPaymentAddress, _adapterParams, msg.value);
        }
        usedSignatures[signature] = true;
        emit Claim(_dstChainId, _user, _amount, _timeStamp);
    }

    function signMessage(
        address _user,
        uint _amount,
        uint _chainId,
        uint _timeStamp
    ) public view returns (bytes32){
        return
            keccak256(
                abi.encodePacked(
                    _user,
                    _amount,
                    _chainId,
                    _timeStamp,
                    address(this)
                )
            );
    }
}
