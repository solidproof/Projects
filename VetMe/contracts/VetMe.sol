// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.12; 

interface IERC20 {

    function decimals() external pure returns (uint8);
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        // solhint-disable-next-line max-line-length
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "insuff bal"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "send failed"
        );
    }

    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "ll call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "ll call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "insuff bal"
        );
        require(isContract(target), "call EOA addr");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "ll static failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "call to eoa addr");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "ll delegate failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "call to eoa addr");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}
library HelperLib {
    using SafeERC20 for IERC20;

    function EthTransferHelper(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "ETH_transfer_failed");
    }

    function notAddressZero(address addr) internal pure {
        require(addr != address(0), "address_zero");
    }

    function getPercent(uint256 val, uint256 percentage)
        internal
        pure
        returns (uint256)
    {
        return (val * percentage) / 100;
    }

    function getFractionPercent(uint256 amount, uint256 fraction)
        internal
        pure
        returns (uint256)
    {
        return (amount * fraction) / 10_000;
    }

}


abstract contract Ownable is Context {
    uint256 public constant delay = 172_800; // delay for admin change
    address private admin;
    address private _feeReceiver;
    address public pendingAdmin; // pending admin variable
    uint256 public changeAdminDelay; // admin change delay variable

    event ChangeAdmin(address sender, address newOwner);
    event RejectPendingAdmin(address sender, address newOwner);
    event AcceptPendingAdmin(address sender, address newOwner);

    function onlyOwner() internal view {
        require(_msgSender() == admin, "Ownable: caller is not the owner");
    }

    constructor() {
        admin = _msgSender();
        _feeReceiver = _msgSender();
    }

    function _setOwner(address _owner) internal {
        HelperLib.notAddressZero(_owner);
        admin = _feeReceiver = _owner;
    }

    function changeAdmin(address _admin) external {
        onlyOwner();
        HelperLib.notAddressZero(_admin);
        pendingAdmin = _admin;
        changeAdminDelay = block.timestamp + delay;
        emit ChangeAdmin(_msgSender(), pendingAdmin);
    }

    function rejectPendingAdmin() external {
        onlyOwner();
        if (pendingAdmin != address(0)) {
            pendingAdmin = address(0);
            changeAdminDelay = 0;
        }
        emit RejectPendingAdmin(_msgSender(), pendingAdmin);
    }

    function owner() public view returns (address) {
        return admin;
    }

    function feeReceiver() public view returns (address) {
        return payable(_feeReceiver);
    }

    function setFeeReceiver(address feeReceiver_) external {
        onlyOwner();
        HelperLib.notAddressZero(feeReceiver_);
        _feeReceiver = feeReceiver_;
    }

    function acceptPendingAdmin() external {
        onlyOwner();
        if (changeAdminDelay > 0 && pendingAdmin != address(0)) {
            require(
                block.timestamp > changeAdminDelay,
                "Ownable: owner apply too early"
            );
            admin = pendingAdmin;
            changeAdminDelay = 0;
            pendingAdmin = address(0);
        }
        emit AcceptPendingAdmin(_msgSender(), admin);
    }
}

library SignatureHelper {
    using Address for address;

    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19\x01", domainSeparator, structHash)
            );
    }

    function tryRecover(bytes32 hash, bytes memory signature)
        internal
        pure
        returns (address, RecoverError)
    {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs &
            bytes32(
                0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            );
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (
            uint256(s) >
            0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
        ) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    function isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        if (error == RecoverError.NoError && recovered == signer) {
            return true;
        }

        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeWithSelector(
                IERC1271.isValidSignature.selector,
                hash,
                signature
            )
        );
        return (success &&
            result.length == 32 &&
            abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
    }

    function verify(
        address account,
        bytes32 domainSeparator,
        bytes32 hashStruct,
        bytes memory signature
    ) internal view returns (bool) {
        return
            isValidSignatureNow(
                account,
                toTypedDataHash(domainSeparator, hashStruct),
                signature
            );
    }
}

contract VetMeEscrow is Ownable{
    using SafeERC20 for IERC20;

    mapping(address => mapping(uint256=> bool)) nonces;
    mapping(bytes32 => uint256) public totalMatchedOut;
    mapping(bytes32 => uint256) public totalMatchedIn;

    struct Order{
        address signatory;
        address receivingWallet;
        address tokenIn;
        address tokenOut;
        uint256 amountOut;
        uint256 amountIn;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 private immutable DOMAIN_SEPARATOR;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    uint256 public feeValue = 125;
    

    constructor(){
        // ROUTER = router;
        DOMAIN_SEPARATOR = keccak256(
                abi.encode(
                    DOMAIN_TYPEHASH,
                    keccak256(bytes("VetMe Escrow")), // name
                    keccak256(bytes("1.0.1")), // version
                    block.chainid,
                    address(this)
                )
            );
    }

    function getBalance (address token) external  view returns(uint256){
        if(token == address(0)){
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    event FeeChanged(address sender, uint256 fee);

   

    function setFees(uint256 fee) external{
        onlyOwner();
        feeValue = fee;
        emit FeeChanged(msg.sender, fee);
    }

    event Withdraw(address to, address token, uint256 amount);
    function withdrawFunds (address token) external {
        onlyOwner();
        uint256 amount =0;
        if(token == address(0)){
            (bool success, ) = feeReceiver().call{value: address(this).balance} ("");
            require(success, "Transfer failed");
        }
        else{
            amount = IERC20(token).balanceOf(address(this));
            if(amount>0)
                IERC20(token).transfer(feeReceiver(), amount);
        }
        emit Withdraw(feeReceiver(),token, amount);
    }

    bytes32 private constant ORDER_STRUCT =
        keccak256(
            // solhint-disable-next-line max-line-length
            "Order(address signatory,address receivingWallet,address tokenIn,address tokenOut,uint256 amountOut,uint256 amountIn,uint256 deadline,uint256 nonce)"
        );
    
    function hashOrder (Order calldata order) private pure returns(bytes32){
        return keccak256(
                abi.encode(
                    ORDER_STRUCT,
                    order.signatory,
                    order.receivingWallet,
                    order.tokenIn,
                    order.tokenOut,
                    order.amountOut,
                    order.amountIn,
                    order.deadline,
                    order.nonce
                )
            );
    }
    

    event Matched(bytes32 sellOrderId, uint256 sellAmount, bytes32 buyOrderId, uint256 buyAmount);

    function orderCheck( 
        Order calldata sellOrder, 
        Order calldata buyOrder
    )internal view returns(bytes32 buyHash, bytes32 sellHash){
        sellHash = hashOrder(sellOrder);
        buyHash = hashOrder(buyOrder);
        require(block.timestamp <= sellOrder.deadline && block.timestamp <= buyOrder.deadline, "Order(s) Expired");
        
        require(
            (totalMatchedOut[sellHash] < sellOrder.amountOut || !nonces[sellOrder.signatory][sellOrder.nonce]) && 
            (totalMatchedOut[buyHash] < buyOrder.amountOut ||!nonces[buyOrder.signatory][buyOrder.nonce]),
        "used nonce(s)");
        // require((isSupportedPairToken[sellOrder.tokenOutSwapPair] && isSupportedPairToken[buyOrder.tokenOutSwapPair])|| !swapping, "Not supported swap pair");
        require(sellOrder.tokenOut == buyOrder.tokenIn && sellOrder.tokenIn ==buyOrder.tokenOut,"tokens must match");
    }

    error SigError(string);

    function _matchSupportFraction(
        Order calldata sellOrder, 
        bytes calldata sellSig,
        Order calldata buyOrder, 
        bytes calldata buySig
    )internal returns(uint256 transferSell, uint256 transferBuy, bytes32 buyHash, bytes32 sellHash){
        (buyHash, sellHash) = orderCheck(sellOrder, buyOrder);
       
        if(!SignatureHelper.verify(sellOrder.signatory,DOMAIN_SEPARATOR, sellHash, sellSig))
            revert SigError("Invalid sell sig");
        if(!SignatureHelper.verify(buyOrder.signatory,DOMAIN_SEPARATOR, buyHash, buySig))
            revert SigError("Invalid buy sig");
        require(checkPricesMatch(buyOrder.amountOut, buyOrder.amountIn, sellOrder.amountOut, sellOrder.amountIn), "price mismatch");
        nonces[sellOrder.signatory][sellOrder.nonce] = nonces[buyOrder.signatory][buyOrder.nonce] = true;
        // make sure these is greater than 0
        uint256 availableBuyOut = buyOrder.amountOut - totalMatchedOut[buyHash];
        uint256 availableSellOut = sellOrder.amountOut - totalMatchedOut[sellHash];
        // calc 
        uint256 availableBuyIn = buyOrder.amountIn - totalMatchedIn[buyHash];
        uint256 availableSellIn = sellOrder.amountIn - totalMatchedIn[sellHash];

        transferSell = availableSellOut >= availableBuyIn? availableBuyIn: availableSellOut;
        transferBuy = availableBuyOut >= availableSellIn? availableSellIn: availableBuyOut;        
    }

    function checkPricesMatch(uint256 amountOutA, uint256 amountInA, uint256 amountOutB, uint256 amountInB)internal pure returns(bool){
        uint256 unitPriceA = (amountOutA *1e18)/amountInA; // multiply by ether in case of float value
        uint256 unitPriceB = (amountInB *1e18)/amountOutB; // multiply by ether in case of float value
        return unitPriceA == unitPriceB;
    }

    function matchSupportFraction(
        Order calldata sellOrder, 
        bytes calldata sellSig,
        Order calldata buyOrder, 
        bytes calldata buySig
    )external {
        (uint256 transferSell, uint256 transferBuy, bytes32 buyHash, bytes32 sellHash) = _matchSupportFraction(sellOrder, sellSig, buyOrder, buySig);
        
        totalMatchedOut[buyHash]+=transferBuy;
        totalMatchedOut[sellHash]+=transferSell;
        totalMatchedIn[buyHash]+=transferSell;
        totalMatchedIn[sellHash]+=transferBuy;

        // Withdraw only the matchable amount using the handler function
        transferSell = handleTransferFrom(sellOrder.tokenOut, sellOrder.signatory, transferSell);
        transferBuy = handleTransferFrom(buyOrder.tokenOut, buyOrder.signatory, transferBuy);

        IERC20(sellOrder.tokenOut).transfer(buyOrder.receivingWallet, HelperLib.getFractionPercent(transferSell,feeValue)); 
        IERC20(buyOrder.tokenOut).transfer(sellOrder.receivingWallet, HelperLib.getFractionPercent(transferBuy,feeValue));
        emit Matched(keccak256(sellSig), transferSell, keccak256(buySig), transferBuy);
        
    }

    // purposely to handle tokens with fees on transfer
    function handleTransferFrom(address token, address from, uint256 amount) internal returns(uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this)); 
        IERC20(token).safeTransferFrom(from, address(this), amount);
        return IERC20(token).balanceOf(address(this)) - balance;
    }

}