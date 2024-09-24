/**
 *Submitted for verification at thetatoken.org on 2024-08-05
 */
// SPDX-License-Identifier:  RPL-1.5 (Reciprocal Public) License

pragma solidity 0.8.23;


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/ERC20.sol)




// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)



/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Metadata.sol)





/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)



/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)


/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}


/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     * ```
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}


// OpenZeppelin Contracts (last updated v5.0.0) (utils/ReentrancyGuard.sol)



/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


//
// (((((((((((((((((((((((((((((((((((       (((((((((((((((((((((((((((((((((((
// (((((((((((((((((((((((((((((((((((       (((((((((((((((((((((((((((((((((((
// (((((((((((((((((((((((((((((((((((       (((((((((((((((((((((((((((((((((((
// (((((((((((((((((((((((((((((((((((       (((((((((((((((((((((((((((((((((((
//
//
//
// (((((((((((((((((((((((((((                       (((((((((((((((((((((((((((
// (((((((((((((((((((((((((((((((               (((((((((((((((((((((((((((((((
// (((((((((((((((((((((((((((((((((           (((((((((((((((((((((((((((((((((
// ((((((((((((((((((((((((((((((((((         ((((((((((((((((((((((((((((((((((
//                     (((((((((((((((       (((((((((((((((
//                        ((((((((((((       ((((((((((((
//                         (((((((((((       (((((((((((
//                         (((((((((((       (((((((((((
//                         (((((((((((       (((((((((((
//                         (((((((((((       (((((((((((
//                         (((((((((((       (((((((((((
//
// FUEL-20 FUEL Token Contract
// Generated by: FuelFoundry, LLC, a Belize corporation, all rights reserved.
// More info at: https://fuelfoundry.io
// Code Release: 0.99ff-k9-syndicatex
// Published Date: May 13th, 2024
//
// DISCLAIMER: This smart contract is provided "as is", with no warranties whatsoever, including any warranty of
// merchantability, fitness for any particular purpose, or any warranty otherwise arising out of any proposal, specification,
// or sample. By using this smart contract, you agree to take full responsibility for your use of the contract, including but not
// limited to the loss of data or funds. No representation or warranty is provided for the safety, security, accuracy, or performance
// of this contract.
//
// This contract is intended to be used as described in the documentation and in the context of Ethereum based blockchain environments.
// Use of this contract in a manner inconsistent with its intended purpose or design, or modification of the contract code, is done at
// your own risk and may expose you to legal or financial penalties.
//
// This software is provided by the copyright holders and contributors "as is" and any express or implied warranties, including,
// but not limited to, the implied warranties of merchantability and fitness for a particular purpose are disclaimed. In no event
// shall FuelFoundry, LLC or contributors be liable for any direct, indirect, incidental, special, exemplary, or consequential
// damages (including, but not limited to, procurement of substitute goods or services; loss of use, data, or profits; or business
// interruption) however caused and on any theory of liability, whether in contract, strict liability, or tort (including negligence
// or otherwise) arising in any way out of the use of this software, even if advised of the possibility of such damage.
//
// NOTE: This smart contract is under continuous development, pending final audit completion from CertiK.
//
// -----------------------------------------------------------------------------
//
// PREMISE: The FUEL-20 Token Contract serves as the core component to the reward framework for FuelFoundry applications on EVM compliant chains.
// Functions and feature-sets, some of which may be fine-tuned over time, leverage the multi-signature process `ExecutiveSession`,
// inspired by Roberts Rules of Order.
//
// Governance (2/3s req.): Custodial, Guardian, Executor are designated roles within the FuelFoundry Ecosystem.
// - While Custodial and Guardian serve unique roles in other FF contracts (i.e. FUEL-721), they operate equal roles for FUEL-20 governance
// - Majority, a 2/3rd multi-sig majority execution to enter Executive Session is required for updating low-level values
// - During Executive Session, Executor may:
//   - Update global setting variables
//   - Update staking reward percentages and blockrewards
//   - Add/Remove Mint Controllers
//   - Enable/Disable Shield Settings
// - During ExecutiveSession, Custodial and Guardian may:
//   - Enable/Disable Mint Controllers
// - All roles, excluding Oracle, at any time may:
//   - Propose and elect new role handlers
//   - Close Executive Session
//
// Operations(L1): Custodial, Guardian, Executor - Executives of the fabric.
// Operations(L2): Oracle - Readonly to fabric variables, may issue claims on behalf of stakers, utilize tools, may update limited config data.
// Minting:        mintControllers - Call ctrlMint function allowing for the minting of new tokens upto the maxSupply, and updateStakerRewardPerBlock to update validator returns for subchain operators.
// Initial Distro: As outlined in roadmap, escrow is sent to sender wallet upon construction.
//
// Fabric Roles (G1):
// - Custodial:    Open/Close ExecutiveSession, query es-code, propose new role handlers, enable/disable mint controllers.
// - Guardian:     Open/Close ExecutiveSession, query es-code, propose new role handlers, enable/disable mint controllers.
// - Executor:     Open/Close ExecutiveSession, add/delete mint controllers, update fabric variables, enable/disable shield settings.
//
// Fabric Roles (G2):
// - Oracle:       Read-only access to gov settings, may perform claim operation on behalf of fuel20 stakers (auto-claim).
//
// FuelSig Multi-Signature Execution:
// - Executive Session initialization requires two (2) of three (3) L1 gov wallets to enter es-code to init executive session.
// - Custodial and Guardian wallets operate as board members and are the only roles which may retrieve the executive session code.
// - Executor must be provided commit code from the guardian or custodial wallet to apply setting updates.
// - Executor commits said proposals as enacted during executive session.
// - Should Executor, or any gov actor, implement improper actions, the other two gov members may vote out the improper actor.
//
// -----------------------------------------------------------------------------
//
// Additional Configuration(s):
//
// - Token Name: FUEL
// - FuelSig Governance
//   - Custodial:   1
//   - Guardian:    1
//   - Executor:    1
//   - Oracle:      1
//   - Controllers: type(uint).max
//
// -----------------------------------------------------------------------------
//
// "A chain is never stronger than it's weakest link" -T. Reid
//


//
// INTERFACES
//

interface IERC721 {

    function transferFrom(address from, address to, uint256 tokenId) external;
}

//
// CONTRACT
//

contract SYNDX is ERC20, ReentrancyGuard {

    //
    // CONSTS
    //

    uint private constant MILLION = 1e6;
    uint private constant INTERMEDIATE_TOKEN_ESCROW_AMOUNT_IN_ETHER = 968 * MILLION;
    uint private constant MAX_SUPPLY_IN_ETHER = 1000 * MILLION;
    uint private constant REWARD_DIVISOR_FAILSAFE = 10 * MILLION;
    uint private constant GOV_SESSION_MAX = 4 hours;
    uint private constant GOV_SESSION_COOLDOWN = 30 seconds;

    //
    // ENUMS
    //

    // SHIELD: Various operational states and security mechanisms within the contract, providing
    // identifiers for the FuelShield system to manage access and actions based on the contract's current state.
    enum SHIELD {

        //MAINTENANCE, // Indicates the contract is in maintenance mode, restricting all non-standard erc20 operations.
        CLAIM,       // When enabled, claiming is disabled.
        MINT,        // When enabled, minting is disabled.
        BURN,        // When enabled, burning is disabled.
        STAKE        // When enabled, staking is disabled.
    }

    // Severity: Defines levels of importance for logging and monitoring, allowing for prioritized
    // attention and response based on the criticality of the information or event.
    enum Severity {

        Alert,        // Immediate action and/or attention required, though system is functional.
        Critical,     // Critical conditions, require attention to prevent escalation.
        Warning,      // Warning conditions, not immediately harmful but indicative of potential issues.
        Notice,       // Normal but significant conditions worth noting.
        Informational // Informational messages, non-critical, useful information.
        //Debug         // Debug-level messages, intended for development and troubleshooting.
    }

    // Facility: Categorizes areas of the contract or ecosystem to which logs, alerts, or operational
    // events are related, facilitating targeted diagnostics and management.
    enum Facility {

        Protocol,      // Related to the core protocol operations and mechanics.
        Governance,    // Pertains to governance actions and mechanisms.
        Executive,     // Involves executive decision-making and actions.
        Operations,    // Operational aspects of the contract.
        Oracle,        // Related to oracle services and actions taken by Oracle.
        External       // External systems or interactions outside the fuelfabric ecosystem.
    }

    //
    // STRUCTS
    //

    // Allowance structure for managing token allowances as they're created.
    struct Allowance {

        address owner;    // address of the token owner who is giving the allowance.
        address spender;  // address of the account that is allowed to spend the tokens.
        uint amount;      // amount of tokens that are allowed to be spent.
    }

    // ExecutiveSession structure holds configuration details for executive sessions within the FuelFoundry governance framework.
    struct ExecutiveSession {

        uint code;        // Unique code generated for authenticating access into executive session.
        uint seed;        // Seed value used in generating the session code, may be reset by the guardian.
        uint startedAt;   // Timestamp when the current or last executive session was entered.
        uint expiresAt;   // Timestamp when the current session expires, after which a new session must be initiated.
        uint sessionMax;  // The maximum duration (in seconds) an executive session can remain active.
        uint sessionCooldown; // The cooldown period (in seconds) for re-initiating an executive session.
    }

    // GovernanceKey structure represents a governance key, detailing roles within the executive board and their respective permissions.
    struct GovernanceKey {

        address wallet;    // The primary wallet address associated with a governance role.
        address custodial; // Declared address of the custodial (secretary) address.
        address guardian;  // Declared address of the guardian (vice president) address.
        address executor;  // Declared address of the executor (president) address, responsible for executing decisions.
        address oracle;    // Declared address of the oracle (non-executive), responsible for managing non-erc20 related functions, data and validations.
        uint code;         // Code (aka es-code), set by governance member to initiate executive session; two of the three governance members must lock in the same code to initialize executive session.
    }

    /**
     * MintController structure represents an external mint controller permitted to mint FUEL-20 tokens.
     *
     * This struct is part of a mechanism allowing specific external contracts to interact with the
     * FUEL-20 contract for the purpose of minting tokens. Each MintController is identified by a
     * unique contract address, and its ability to mint tokens may be toggled on and off. This design
     * enables decentralized governance over minting operations by allowing the addition or removal of
     * minting permissions to specific contracts, future-proofing reward mechanics of the token minting process.
     *
     * @param contractAddress address of the external contract permitted to mint FUEL-20 tokens.
     * @param enabled boolean flag indicating whether the MintController is currently authorized to mint tokens.
     */
    struct MintController {

        address contractAddress; // address of the controller contract.
        bool enabled;            // True if minting by this controller is enabled, false otherwise.
    }

    /**
     * Fuel20BaseContract structure defines the foundational structure for managing the FUEL-20 token ecosystem within the FuelFoundry environment.
     *
     * The Fuel20BaseContract struct is central to the FUEL-20 governance, staking, and token dynamics. It contains
     * variables for tracking various token metrics, such as staked amounts, claims, and burns. This struct also incorporates
     * several safeguards through 'shield' toggles that help manage the minting, staking, claiming, and burning processes,
     * enhancing the security and flexibility of token operations. Additionally, it provides global and real-time analytics
     * for detailed oversight of token interactions over time. Key functionalities include the management of token supply caps,
     * staking rewards, and holder allowances, making it a critical component for the token's lifecycle and governance.
     *
     * @param fuelId Identifier linking to FuelFoundry MetaForge Analytics for detailed tracking.
     * @param initAt Timestamp indicating when this contract was initialized.
     * @param topOffSupply Specifies a threshold for token supply above which only fractional tokens can be minted to the contract owner.
     * @param maxSupply The maximum allowable number of tokens that can exist within the ecosystem.
     * @param maxAllowances Maximum number of allowances that can be tracked per user, enhancing transparency.
     * @param stakeAnnualPercentRewardRate Annual percentage rate for FUEL-20 staking rewards.
     * @param stakeMin Minimum amount of FUEL required for participating in staking.
     * @param claimCooldown Minimum cooldown period in seconds between consecutive claims.
     * @param _allowancesByOwner Mapping to manage allowances assigned to each owner.
     * @param staked, claimed, burned Track the total amount of FUEL-20 staked, claimed, and burned by address, respectively.
     * @param stakedAt, unstakedAt, stakeClaimedAt Track the timestamps for staking activities and claims by address.
     * @param claimedAt Mapping to track the timestamps of claims by address for each epoch.
     * @param totalStakedAt, totalUnstakedAt, totalClaimedAt, totalBurnedAt Track the total amount of tokens staked, unstaked, claimed, and burned at each timestamp.
     * @param totalStaked, totalClaimed, totalBurned Track the real-time total amount of tokens staked, claimed, and burned, respectively.
     * @param mintshield, stakeshield, claimshield, burnshield Toggles for activating respective security features to protect token operations.
     * @param maintenance Toggle for activating maintenance mode, disabling all non-standard functionalities during migrations or updates.
     * @param nonce A unique identifier used for event tracking and integration with the MetaForge dashboard.
     */
    struct Fuel20BaseContract {

        //
        // FUEL GLOBAL
        //

        // vars
        uint80 fuelId;      // ID number for tying back to FuelFoundry MetaForge Analytics
        uint initAt;        // This contract's initialization timestamp
        uint topOffSupply;  // By default this is maxSupply - 1 ether, when totalSupply is above topOffSupply, topOffSupply may be utilized to mint the remaining fraction of a token to the contract owner Address and enables mintsheild + stakeshield.
        uint maxSupply;     // Production value to be set at ten (10) billion ether - Maximum number of tokens allowed in circulation.
        uint maxAllowances; // Production value to be set at one-hundred (100) - Max allowances tracked per user, keeping holders more informed about outstanding allowances.

        // staking
        uint stakeAnnualPercentRewardRate; // Production value to be set to 5%. FUEL-20 self-stake earning APR, set to % for earning.
        uint stakeMin;      // Production value to be set to 1 ether. Minimum required FUEL for virtual staking FUEL20.
        uint claimCooldown; // Production value to be set to 30 seconds. Number of seconds required between claims (minimum 30 seconds).

        //
        // HOLDER TRACKING
        //

        // allowance
        mapping(address => Allowance[]) _allowancesByOwner; // mapping utilized to track allowances by owner

        // analytics
        mapping(address => uint) staked;         // total fuel20 staked by address
        mapping(address => uint) claimed;        // total fuel-20 claimed by address
        mapping(address => uint) burned;         // total fuel-20 burned by address

        // stake
        mapping(address => uint) stakedAt;       // tracks timestamp when holder staked, also tracks when holder last claimed or updates stake amount
        mapping(address => uint) unstakedAt;     // tracks timestamp when holder last unstaked
        mapping(address => uint) stakeClaimedAt; // tracks timestamp when holder last claimed

        // claim
        mapping(address => mapping(uint => uint)) claimedAt; // total fuel-20 claimed by address at specified epoch

        // burn
        mapping(address => mapping(uint => uint)) burnedAt; // total fuel-20 claimed by address at specified epoch

        //
        // GLOBAL ANALYTICS
        //

        // totals - time tracking
        mapping(uint => uint) totalStakedAt;   // total FUEL20 tokens staked at timestamp
        mapping(uint => uint) totalUnstakedAt; // total FUEL20 tokens unstaked at timestamp
        mapping(uint => uint) totalClaimedAt;  // total FUEL20 tokens claimed at timestamp
        mapping(uint => uint) totalBurnedAt;   // total FUEL20 tokens burned at timestamp

        // totals - realtime tracking
        uint totalStaked;  // Current amount of FUEL20 staked in wei.
        uint totalClaimed; // Total number of FUEL20 tokens that have been created / claimed in wei.
        uint totalBurned;  // Total number of FUEL20 tokens that can be burned in wei.

        //
        // FUELSHIELD
        //

        // toggles
        bool mintshield;  // toggle variable for mintshield
        bool stakeshield; // toggle variable for stakeshield
        bool claimshield; // toggle variable for claimshield
        bool burnshield;  // toggle variable for burnshield
        bool maintenance; // toggle variable for maintenance mode is reserved for future migrations, disabling all bonus features, standard ERC functions remain operations.

        // event tracking
        uint nonce;       // ties back to metaforge dashboard
    }

    /**
     * Subchain structure manages staking rewards configurations for a FuelFoundry subchain.
     *
     * This struct supports managing validator rewards within a subchain, ensuring incentive alignment and controlled reward distribution. It allows for setting both maximum and actual reward rates per block to balance sustainability with validators' contributions.
     *
     * @param stakerRewardPerBlockMax Cap on rewards per block to maintain economic stability.
     * @param stakerRewardPerBlock Current rewards per block based on subchain policies and validator performance.
     */
    struct Subchain {

        uint stakerRewardPerBlock;    // Current staker reward per block.
        uint stakerRewardPerBlockMax; // Maximum allowable staker reward per block.
    }

    //
    // MODIFIERS
    //

    /**
     * onlyGovernance modifier ensures that only accounts with governance permissions can execute the modified function.
     *
     * This modifier restricts the execution of the function to which it's applied to only those
     * addresses that are recognized as part of the governance structure. It checks if the caller
     * is authorized as governance by calling `_isGov`, which internally verifies the caller's
     * governance status. If the caller is not authorized, the transaction is reverted with a
     * "!gov" error message, indicating lack of governance permissions.
     */
    modifier onlyGovernance() { require(_isGov(msg.sender), "!gov"); _; }

    /**
     * onlyExecutor modifier restricts function execution to the designated executor.
     *
     * This modifier ensures that only the executor, whose address is stored in the `executor.wallet`,
     * can call the modified function. It is used to protect sensitive operations that should be
     * carried out under the strict oversight of the contract's executor role. If the caller's address
     * does not match the executor's address, the transaction is reverted with a "!exe" error message.
     */
    modifier onlyExecutor() { require(msg.sender == executor.wallet, "!exe"); _; }

    /**
     * onlyCustodialGuardian modifier allows access only to the custodial or guardian role.
     *
     * Functions modified with this check can be executed by either the custodial or guardian roles,
     * ensuring that operations requiring higher-level oversight or dual-control security mechanisms
     * are adequately protected. The modifier checks if the caller matches either the `custodial.wallet`
     * or `guardian.wallet` addresses. If not, it reverts the transaction with a "!cgn" message, indicating
     * unauthorized access attempt by non-custodial or guardian entities.
     */
    modifier onlyCustodialGuardian() { require(msg.sender == custodial.wallet || msg.sender == guardian.wallet, "!cgn"); _; }

    /**
     * onlyOracle modifier confines the execution of the attached function to the oracle role.
     *
     * This modifier is designed to ensure that only the oracle, as determined by the `_oracle()`
     * function, can perform the operation it guards. It's essential for actions that depend on
     * external data verification or specific insights that the oracle provides. If the caller is
     * not the oracle, the transaction will revert with a "!ora" error message, safeguarding the
     * function against unauthorized access.
     */
    modifier onlyOracle() { require(msg.sender == _oracle(), "!ora"); _; }

    /**
     * onlyController modifier ensures that only approved mint controllers can execute the function.
     *
     * To safeguard minting operations and maintain controlled access to minting capabilities,
     * this modifier restricts function execution to addresses that have been designated as mint
     * controllers. It leverages the `_isMintController` function to verify if the caller is an
     * authorized mint controller. Unauthorized callers trigger a transaction revert with a "!con"
     * message, preventing execution by entities outside the approved controller list.
     */
    modifier onlyController() { require(_isMintControllerEnabled(msg.sender), "!con"); _; }

    /**
     * onlyExecutiveSession modifier ensures that function execution only occurs within a valid executive session under specific quorum conditions.
     *
     * This modifier is designed to enforce governance protocol by limiting function execution to the context of
     * an established executive session. It first checks that an executive session is currently active using the
     * `executiveSession()` function. It then verifies that the session's quorum conditions are met by checking the
     * current executor's code with `_quorumCodeVerify()`. If either condition fails, the transaction is reverted
     * with an appropriate error message to indicate the nature of the failure.
     */
    modifier onlyExecutiveSession() {

        // check if the executive session is established
        require(_inSession(), "quorm!estab");

        // verify executor quorum code synchronization
        require(_quorumCodeVerify(executor.code), "qcvfail");
        _;
    }

    //
    // GLOBALS
    //

    // ExecutiveSession declaration holds the current state of an executive session, including details like session codes, timestamps, and session limits.
    // Stored privately to ensure that session management is internally controlled and protected from unauthorized external access.
    ExecutiveSession private exsess;

    // GovernanceKey struct declarations for the custodial (secretary), guardian (vice president), and executor (president) roles.
    // These keys define the wallet addresses associated with each governance role, enabling role-based access control and actions.
    GovernanceKey private custodial;
    GovernanceKey private guardian;
    GovernanceKey private executor;

    // The base configuration and operational data for the FUEL-20 token contract.
    // Encapsulates essential tokenomics parameters, staking configurations, and operational metrics.
    Fuel20BaseContract private fuel20;

    // Represents the configuration and operational parameters of a subchain within the ecosystem.
    // This includes variables for managing staker rewards, aligning with subchain-specific policies and incentives.
    Subchain public subchain;

    // An array of MintController structs, listing external contracts permitted to mint FUEL-20 tokens.
    // This array supports enablement governance over designating mint controllers, allowing for the addition or removal of minting capabilities.
    MintController[] mintControllers;

    //
    // EVENT
    //

    event Trap(
        uint nonce,                // nonce
        uint timestamp,            // block timestamp
        address  indexed origin,   // address that initiated event
        Facility indexed facility, // source that produced the event
        Severity indexed severity, // urgency of event
        string  application,       // function name or identified
        uint value,                // relative data
        string  message            // info about the event
    );

    //
    // CONSTRUCTOR
    //

    /**
     * Initializes the contract with necessary governance roles and system parameters.
     *
     * Sets initial token properties, reserves amounts for escrow, sets maximum supply, and initializes governance roles.
     * Allows dynamic setting of the executive session seed used for 2FA in governance activities.
     *
     * @param __fuelId Initial fuel ID for analytics and tracking.
	 * @param __exsessSeed Initial seed value for executive session 2FA authentication.
	 */
    constructor(uint80 __fuelId, uint __exsessSeed)
    ERC20("Syndicate X", "SYNDX") {

        // all roles to sender on init
        address __root = msg.sender;
        address __guardian = __root;
        address __executor = __root;
        address __oracle   = __root;

        uint __intermediateTokenEscrowAmountInEther = INTERMEDIATE_TOKEN_ESCROW_AMOUNT_IN_ETHER; // the initial reserve set aside as spec'd in the roadmap - 25% will be set aside for earning
        uint __maxSupplyInEther                     = MAX_SUPPLY_IN_ETHER;                       // amt specified is in ether (10 billion ether = 10^28 wei)

        // init - executive session
        exsess.seed          = __exsessSeed;                         // this variable seeds the handshake for governance members entering executive session
        exsess.sessionMax    = GOV_SESSION_MAX;                      // amt specified is in seconds; i.e. 14400 = 4 hours
        exsess.sessionCooldown = GOV_SESSION_COOLDOWN;               // 30 seconds
        exsess.startedAt     = block.timestamp;                      // for setup convenience, executive session is initiated when the contract is constructed
        exsess.expiresAt     = exsess.startedAt + exsess.sessionMax; // initial executive session length set to sessionMax time
        exsess.code          = uint(keccak256(abi.encodePacked(exsess.code + block.number + block.timestamp + block.gaslimit + exsess.seed))) % 10 ** 9; // this intentionally pseudorandom variable is used by governance members only for entering executive session

        // init - executive governance enabled - two (2) of the three (3) executive codes must be in-sync to enable executive session
        custodial.code = exsess.code;
        guardian.code  = exsess.code;
        executor.code  = exsess.code;

        // init - fuelvars
        fuel20.fuelId        = __fuelId;                    // for analytics tracking in FuelFoundry MetaForge, internally used to tie contract back to fuelfoundry metaforge
        fuel20.stakeMin      = 1 ether;                     // minimum stake size when virtual staking fuel20
        fuel20.claimCooldown = 60 seconds;                  // cooldown between claims set to sixty (60) seconds
        fuel20.maxSupply     = __maxSupplyInEther * 10**18; // note: 10^18 at construction
        fuel20.topOffSupply  = fuel20.maxSupply - 10**18;   // topOffSupply is used for validator reward easing
        fuel20.maxAllowances = 10;                          // tracking first 10 approved allowances per holder
        fuel20.stakeAnnualPercentRewardRate = 10;           // 10% APR for self virtual staking 

        // init - governance
        custodial.wallet    = msg.sender;
        guardian.wallet     = __guardian;
        executor.wallet     = __executor;

        custodial.custodial = custodial.wallet;
        custodial.guardian  = guardian.wallet;
        custodial.executor  = executor.wallet;
        custodial.oracle    = __oracle;

        guardian.custodial  = custodial.wallet;
        guardian.guardian   = guardian.wallet;
        guardian.executor   = executor.wallet;
        guardian.oracle     = __oracle;

        executor.custodial  = custodial.wallet;
        executor.guardian   = guardian.wallet;
        executor.executor   = executor.wallet;
        executor.oracle     = __oracle;

        // if initial payout specified, send to escrow wallet / smart contract (based on roadmap defined terms) / etc...
        if (__intermediateTokenEscrowAmountInEther > 0) {

            // accounting initial distribution as a claim
            fuel20.totalClaimed = __intermediateTokenEscrowAmountInEther * 10**18;
            _mint(__root, fuel20.totalClaimed);
        }

        // fuel20 contract variable global defaults //

        // fuelshield optional init configuration
        /*
        fuel20.maintenance   = true;
        fuel20.verbose       = true;
        fuel20.mintshield    = true;
        fuel20.burnshield    = true;
        fuel20.stakeshield   = true;
        fuel20.claimshield   = true;
        */

        // subchain validator staking
        subchain.stakerRewardPerBlock    = 10**9;                                      // default reward (in wei) per block validated
        subchain.stakerRewardPerBlockMax = fuel20.maxSupply / REWARD_DIVISOR_FAILSAFE; // default max reward per block in wei

        // contract initlization
        fuel20.initAt = block.timestamp;
    }

    //
    // OVERRIDES (ERC20) AND OVERRIDE WRAPPERS
    //

    /**
     * _balanceOf calculates the adjusted balance for an account.
     * This private function participates in the override of "balanceOf" taking into account virtual stakes.
     *
     * @param __account The account address to query the balance of.
     * @return balance_ The calculated balance after subtracting the virtual stake.
     */
    function _balanceOf(address __account) private view returns (uint balance_) {

        // total balance of fuel20 in account (virtually staked and unstaked)
        uint ledgerBalance = super.balanceOf(__account);

        // virtually staked balance total (self-stake)
        uint virtuallyStakedBalance = fuel20.staked[__account];

        // subtract staked fuel20 from balance before reporting w/ safeguard adjustment
        if (ledgerBalance >= virtuallyStakedBalance) { return ledgerBalance - virtuallyStakedBalance; }
        else { return 0; }
    }


    /**
     * balanceOf retrieves the balance of a given account.
     * This public function overrides the standard "balanceOf" and internally calls `_balanceOf` to reflect subtraction of virtual stakes.
     *
     * @param __account The account address whose balance is being queried.
     * @return The balance of the account.
     */
    function balanceOf(address __account) public view override returns (uint) {

        return _balanceOf(__account);
    }


    /**
     * transfer executes a transfer of the specified amount from the sender's account to the specified recipient.
     * This public function overrides the standard "transfer", accounts for virtual stakes and ensures the operation is non-reentrant.
     *
     * @param  __to address to transfer funds to.
     * @param  __value The amount of funds to transfer.
     * @return returns true if the transfer is successful.
     */
    function transfer(address __to, uint __value) public override nonReentrant returns (bool)  {

        // ensure sender is not address(0) - if this day ever happens, probably not in our lifetime
        require(msg.sender != address(0), "sender may not equal zero address");

        // virtual balance supersedes ledger balance
        require(_balanceOf(msg.sender) >= __value, "amount specifed is greater than account balance");

        return super.transfer(__to, __value);
    }


    /**
     * transferFrom executes a transfer from a specified sender to a specified recipient.
     * This public function overrides the standard "transferFrom", with added non-reentrant protection.
     * This function does not purge tracked allowances (see: purgeAllowances).
     *
     * @param __from address to transfer funds from.
     * @param __to address to transfer funds to.
     * @param __value amount of funds to transfer.
     * @return returns true if the transfer is successful.
    */
    function transferFrom(address __from, address __to, uint __value) public override nonReentrant returns (bool)  {

        // ensure the sender is not address(0)
        require(__from != address(0), "sender may not equal zero address");

        // ensure the recipient is not address(0)
        require(__to != address(0), "destination may not equal zero address");

        // virtual balance supersedes ledger
        require(_balanceOf(__from) >= __value, "value specified is greater than balance available");

        // update allowance tracking if enabled
        if (fuel20.maxAllowances > 0 && !_allowanceDecrease(__from, msg.sender, __value)) {

            // alert if update fails
            emit Trap(_nonce(), block.timestamp,msg.sender, Facility.Protocol,Severity.Critical, "transferFrom",  __value, "failed to decrease tracked allowance");
        }

        // initiate request
        return super.transferFrom(__from, __to, __value);
    }


    /**
     * burn burns a specified amount of tokens from the caller's balance.
     * This public function overrides the standard "burn", accounts for virtual stakes and includes non-reentrant protection.
     *
     * @param __value the amount of tokens to be burned.
     */
    function burn(uint __value) public nonReentrant {

        // burnshield
        _fuelShield(SHIELD.BURN);

        // ensure sender doesn't burn more tokens than they have available un-staked
        require(_balanceOf(msg.sender) >= __value, "value specified is less than account balance");

        // update global metrix
        _burnMetrixAdd(msg.sender, __value);

        // call the original burn logic
        _burn(msg.sender, __value);
    }


    /**
     * burnFrom allows for the burning (destruction) of tokens from a specified account.
     * This public function extends "burnFrom", accounts for virtual stakes and includes non-reentrant protection.
     *
     * @param  __from The account from which tokens will be burned.
     * @param  __value The amount of tokens to burn.
     */
    function burnFrom(address __from, uint __value) public nonReentrant {

        // burnshield
        _fuelShield(SHIELD.BURN);

        // ensure the owner of the tokens doesn't burn more tokens than they have unstaked
        require(_balanceOf(__from) >= __value, "value specified is less than account balance");

        // update allowance tracking if enabled
        if (fuel20.maxAllowances > 0 && !_allowanceDecrease(__from, msg.sender, __value)) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Critical, "burnFrom",  __value, "failed to decrease tracked allowance value");
        }

        // call OZ internal function to safely spend the allowance, if fails, tx will revert
        _spendAllowance(__from, msg.sender, __value);

        // update global metrix
        _burnMetrixAdd( __from, __value);

        // call OZ burn logic
        _burn(__from, __value);
    }


    /**
     * _isGov checks if the specified address is recognized as a government address.
     * This private function validates the government status of an address.
     *
     * @param  __address address to verify as a government address.
     * @return  Returns true if the address is a government address.
     */
    function _isGov(address __address) private view returns (bool) {

        return (__address == custodial.wallet || __address == guardian.wallet || __address == executor.wallet);
    }

    //
    // ALLOWANCES
    //

    /**
     * Approves the specified amount to be spent by another address.
     * This public function overrides the standard "approve".
     *
     * @param  spender address authorized to spend the funds.
     * @param  value amount of funds approved for spending.
     * @return  Returns true if the approval is successful.
     */
    function approve(address spender, uint256 value) public override nonReentrant returns (bool) {

        uint senderAllowanceCount = fuel20._allowancesByOwner[msg.sender].length;

        require(spender != address(0), "spender may not equal zero address");

        // holder may perform as many allowances as they wish, the contract will only track upto the max allowances as defined
        if (senderAllowanceCount < fuel20.maxAllowances) {

            // find or add the allowance for this spender
            bool found = false;

            for (uint i = 0; i < fuel20._allowancesByOwner[msg.sender].length && i <= fuel20.maxAllowances; i++) {

                if (fuel20._allowancesByOwner[msg.sender][i].spender == spender) {

                    fuel20._allowancesByOwner[msg.sender][i].amount = value;
                    found = true;
                    break;
                }
            }

            if (!found) {

                Allowance memory newAllowance = Allowance({ owner: msg.sender, spender: spender, amount: value });
                fuel20._allowancesByOwner[msg.sender].push(newAllowance);
            }

            // 90% alert notice
            if (senderAllowanceCount * 10 > fuel20.maxAllowances * 9) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Warning, "approval", senderAllowanceCount, "90warn");
            }
        }

        return super.approve(spender, value);
    }


    /**
     * _allowancesByOwner retrieves the history of allowances for a specified owner.
     * This private function allows viewing of all allowances set by a specific owner, this function does not track spends.
     *
     * @param __owner address of the owner whose allowances are being queried.
     * @return allowances_ The array of Allowance structs representing the owner's current allowances.
     */
    function _allowancesByOwner(address __owner) private view returns (Allowance[] memory allowances_) {

        // cache allowancesByOwner length (total count of tracked allowances) for gas optimization
        uint _allowancesByOwnerLength = fuel20._allowancesByOwner[__owner].length;

        Allowance[] memory _ownerAllowances = new Allowance[](_allowancesByOwnerLength);

        for (uint i = 0; i < _allowancesByOwnerLength; i++) {

            _ownerAllowances[i] = Allowance(fuel20._allowancesByOwner[__owner][i].owner, fuel20._allowancesByOwner[__owner][i].spender, fuel20._allowancesByOwner[__owner][i].amount);
        }

        return _ownerAllowances;
    }


    /**
     * allowancesByOwner retrieves the history of allowances for a specified owner.
     * This external function allows viewing of all allowances set by a specific owner, this function does not track spends.
     *
     * @param __owner address of the owner whose allowances are being queried.
     * @return allowances_ The array of Allowance structs representing the owner's current allowances.
     */
    function allowancesByOwner(address __owner) external view returns (Allowance[] memory allowances_) {

        return _allowancesByOwner(__owner);
    }


    /**
     * allowances retrieves the history of allowances set by the owner.
     * This external function provides a view of all allowances created and most recent value specified, this function does not track spends.
     *
     * When an approve is comitted is is recorded in the allowances array.
     *
     * @return allowances_ The array of Allowance structs representing all current allowances.
     */
    function allowances() external view returns (Allowance[] memory allowances_) {

        return _allowancesByOwner(msg.sender);
    }


    /**
     * _allowanceDecrease safely decreases the allowance for a spender.
     *
     * @param __owner The owner of the tokens.
     * @param __spender The spender of the tokens.
     * @param __amount The amount by which to decrease the allowance.
     * @return success_ True if the operation was successful, False otherwise.
     */
    function _allowanceDecrease(address __owner, address __spender, uint __amount) private returns (bool success_) {

        // when fuel20.maxAllowances is set to 0, allowance tracking functionality is fully disabled
        if (fuel20.maxAllowances < 1) { return false; }

        Allowance[] storage _ownerAllowances = fuel20._allowancesByOwner[__owner];

        for (uint i = 0; i < _ownerAllowances.length; i++) {

            if (_ownerAllowances[i].spender == __spender) {

                if (_ownerAllowances[i].amount < __amount) {

                    // not enough allowance to decrease
                    // return failure w/o reverting
                    return false;
                }

                // decrease allowance amount
                _ownerAllowances[i].amount -= __amount;

                // optionally remove allowance if it hits zero and max allowances are exceeded
                if (_ownerAllowances[i].amount == 0 && _ownerAllowances.length > fuel20.maxAllowances) {

                    // swap & pop
                    if (i != _ownerAllowances.length - 1) {

                        _ownerAllowances[i] = _ownerAllowances[_ownerAllowances.length - 1];
                    }

                    _ownerAllowances.pop();
                }

                // successfully decreased
                return true;
            }
        }

        // no matching allowance found
        // indicate failure w/o revert
        return false;
    }


    /**
     * purgeAllowances purges all tracked allowances.
     * This external function purges both the history of allowances and sets all tracked allowance values to zero (0)
     * preventing the potential loss of funds due to approved allowance abuse.
     *
     * @return allowancesPurgedCount_ The total count of allowances that were purged.
     * @return allowancesClearedTotal_ The total aggregate of FUEL in allowances cleared.
     */
    function purgeAllowances() external nonReentrant returns (uint allowancesPurgedCount_, uint allowancesClearedTotal_) {

        // definitions
        allowancesPurgedCount_ = fuel20._allowancesByOwner[msg.sender].length;

        // zero out known allowances
        for (uint i = 0; i < allowancesPurgedCount_; i++) {

            // sum of all tokens zeroed out
            allowancesClearedTotal_ += fuel20._allowancesByOwner[msg.sender][i].amount;

            // zero out ERC20 storage allowance
            super.approve(fuel20._allowancesByOwner[msg.sender][i].spender, 0);

            // remove allowance record
            delete fuel20._allowancesByOwner[msg.sender][i];
        }

        // reset custom allowance storage for owner
        fuel20._allowancesByOwner[msg.sender] = new Allowance[](0);

        // return total number of allowances purged
        return (allowancesPurgedCount_, allowancesClearedTotal_);
    }

    //
    // INTERNALS
    //

    /**
     * _oracle returns the address of the fabric oracle.
     * This private function provides a view method to access the stored oracle address.
     *
     * @return  oracle_ address of the oracle.
     */
    function _oracle() private view returns (address oracle_) {

        if (custodial.oracle == guardian.oracle || custodial.oracle == executor.oracle) { return custodial.oracle; }
        else if (guardian.oracle == executor.oracle) { return guardian.oracle; }

        return address(0);
    }


    /**
     * _claimMetrixAdd adds fuel20 reward claims for a sender in the FuelFoundry Metrix system.
     * This private function updates the necessary metrics and logs for reward claims.
     *
     * @param  __sender address of the claimant.
     * @param  __reward amount of reward claimed.
     * @return  success_ Returns true upon successful addition of the reward claim.
     */
    function _claimMetrixAdd(address __sender, uint __reward) private returns (bool success_) {

        // if no reward, skip unnecessary writes
        if (__reward > 0) {

            // wallet analytics //

            // total claimed
            fuel20.claimed[__sender] += __reward;

            // claim amount by sender at specific time
            fuel20.claimedAt[__sender][block.timestamp] += __reward;

            // global analytics //

            // total claimed
            fuel20.totalClaimed += __reward;

            // claimed at
            fuel20.totalClaimedAt[block.timestamp] += __reward;
        }

        // for callback handling
        return true;
    }


    /**
     * _burnMetrixAdd adds fuel20 burns for a sender in the FuelFoundry Metrix system.
     * This private function updates the necessary metrics and logs for burn accounting.
     *
     * @param  __owner address of the wallet tokens burned from.
     * @param  __amount amount of token burned.
     * @return  success_ Returns true upon successful addition of the burn.
     */
    function _burnMetrixAdd(address __owner, uint __amount) private returns (bool success_) {

        // wallet analytics //

        // total burned
        fuel20.burned[__owner] += __amount;

        // claim amount by sender at specific time
        fuel20.burnedAt[__owner][block.timestamp] += __amount;

        // global analytics //

        // total claimed
        fuel20.totalBurned += __amount;

        // claimed at
        fuel20.totalBurnedAt[block.timestamp] += __amount;

        // for callback handling
        return true;
    }


    /**
     * _fuelShield evaluates and applies specific security protocols based on the defined SHIELD.
     * This private function checks the state of various security measures and enforces them accordingly.
     *
     * @param __SHIELD The specific security shield to check and enforce.
     * @return success_ Returns true if the security checks pass without triggering any shields.
     */
    function _fuelShield(SHIELD __SHIELD) private view returns (bool success_) {

        // in order of usage //

        // claimshield - claim disabled
        if (__SHIELD == SHIELD.CLAIM) { require(!fuel20.claimshield, "FFCS"); }

            // mintshield - mint disabled
        else if (__SHIELD == SHIELD.MINT) { require(!fuel20.mintshield, "FFMS"); }

            // stakeshield - stake disabled
        else if (__SHIELD == SHIELD.STAKE) { require(!fuel20.stakeshield, "FFSC"); }

            // burnshield - burn shield
        else if (__SHIELD == SHIELD.BURN) { require(!fuel20.burnshield, "FFBS"); }

        // maintenance mode - independent saftey check for all _fuelShield function calls
        if (fuel20.maintenance) {

            revert("FFMAINT: Maintenance mode enabled, all enhanced functionality outside of unstaking is disabled.");
        }

        return true;
    }

    //
    // MINTING
    //

    /**
     * ctrlMint controls the minting of tokens, ensuring compliance with defined security measures and supply limits.
     * This external function enforces minting controls, adjusts mint amounts for max supply, and ensures only authorized controllers can mint.
     *
     * @param __to The address to which tokens will be minted.
     * @param __amount The amount of tokens to be minted, which may be adjusted based on the max supply limit.
     * @return success_ Returns true if the minting operation completes successfully, otherwise false if any security checks fail or unauthorized access is detected.
     */
    function ctrlMint(address __to, uint __amount) external onlyController nonReentrant returns (bool success_) {

        // prohibit if mintshield enabled
        _fuelShield(SHIELD.MINT);

        // top off check
        __amount = _adjustForMaxSupply(__amount);

        // secondary validation
        require (totalSupply() + __amount <= fuel20.maxSupply, "totalsupply+mintamt>maxsupply");
        require (__to != address(0), "addr0mint!allowed");

        // if not a controller, report
        if(!_isMintControllerEnabled(msg.sender)) {

            // record attempt
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Alert, "mint", __amount, "failed");
            return false;
        } else {
            // is indeed a mint controller...

            // mntdat
            _mint(__to, __amount);

            // reflect reward up in contract
            _claimMetrixAdd(__to, __amount);

            // emit handled by _mint function
            return true;
        }
    }

    //
    // VIRTUALSTAKING
    //

    /**
     * balance retrieves various fuel metrics for the sender's account.
     * This external view function provides comprehensive fuel balance and staking information for the caller.
     *
     * @return balanceUnstakedInEther_ balance (in Ether) of fuel tokens owned by sender.
     * @return balanceUnstaked_ balance in wei of fuel tokens owned by sender.
     * @return balanceStakedInEther_ balance in ether of fuel tokens owned by sender.
     * @return balanceStaked_ amount of fuel tokens staked by sender.
     * @return balanceInTotalInEther_ balance of combined staked and unstaked in ether by sender.
     * @return balanceInTotal_ balance of combined staked and unstaked by sender.

     * @return balanceClaimed_ total amount of fuel claimed in contract.
     * @return balanceBurned_ total amount of fuel burned in contract.
     * @return globalTotalStaked_ total amount of fuel staked in contract.
     * @return globalTotalClaimed_ total amount of fuel claimed from contract.
     * @return globalTotalSupply_ total supply of tokens in circulation.
     * @return globalTotalBurned_ total amount of fuel burned from contract.
     * @return epochTime_ returns the current epoch time.
     */
    function balance() external view returns (
        uint balanceUnstakedInEther_, uint balanceUnstaked_, uint balanceStakedInEther_, uint balanceStaked_, uint balanceInTotalInEther_, uint balanceInTotal_,
        uint balanceClaimed_, uint balanceBurned_, uint globalTotalStaked_, uint globalTotalClaimed_, uint globalTotalSupply_, uint globalTotalBurned_, uint epochTime_) {

        if (super.balanceOf(msg.sender) >= 1 ether) {

            balanceInTotalInEther_ = super.balanceOf(msg.sender) / 1 ether;
        }

        if (balanceOf(msg.sender) >= 1 ether) {

            balanceUnstakedInEther_ = balanceOf(msg.sender) / 1 ether;
        }

        if (fuel20.staked[msg.sender] >= 1 ether) {

            balanceStakedInEther_ = fuel20.staked[msg.sender] / 1 ether;
        }

        return (
            balanceUnstakedInEther_,
            balanceOf(msg.sender),
            balanceStakedInEther_,
            uint(fuel20.staked[msg.sender]),
            balanceInTotalInEther_,
            super.balanceOf(msg.sender),
            uint(fuel20.claimed[msg.sender]),
            uint(fuel20.burned[msg.sender]),
            uint(fuel20.totalStaked),
            uint(fuel20.totalClaimed),
            uint(totalSupply()),
            uint(fuel20.totalBurned),
            block.timestamp
        );
    }

    //
    // FUELMETRIX
    //

    /**
     * totalAt retrieves total stake, claim and burn data for a specific epoch time.
     * This external view function returns the total amounts of claims, stakes, and unstakes at a given epoch time.
     *
     * @param __epochTime epoch time for which to retrieve the data.
     * @return totalClaimedAtEpoch_ total fuel claimed at the specified epoch.
     * @return totalStakedAtEpoch_ total fuel staked at the specified epoch.
     * @return totalUnstakedAtEpoch_ total fuel unstaked at the specified epoch.
     */
    function totalAt(uint __epochTime) external view returns (uint totalClaimedAtEpoch_, uint totalStakedAtEpoch_, uint totalUnstakedAtEpoch_, uint totalBurnedAtEpoch_) {

        return (fuel20.totalClaimedAt[__epochTime],fuel20.totalStakedAt[__epochTime],fuel20.totalUnstakedAt[__epochTime], fuel20.totalBurnedAt[__epochTime]);
    }

    //
    // STAKE | UNSTAKE | CLAIM
    //

    /**
     * _stake handles the logic for virtual staking of tokens.
     * This function manages staking of tokens and calculates rewards.
     *
     * @param  __amount The amount of tokens to stake.
     * @return  reward_ The calculated reward for staking.
     */
    function _stake(uint __amount) private returns (uint reward_) {

        require(__amount >= fuel20.stakeMin, "amount specified is less than stake minimum requirement");
        require(__amount <= _balanceOf(msg.sender), "amount specified is greater than sender balance");
        require(fuel20.stakeClaimedAt[msg.sender] + fuel20.claimCooldown < block.timestamp, "reward cooling in progress, please try again later");

        // claim any existing rewards
        if (fuel20.stakeClaimedAt[msg.sender] >= fuel20.initAt) {

            reward_ = _claim(msg.sender);
        }

        // update balances and timestamps
        fuel20.staked[msg.sender] += __amount;
        fuel20.stakedAt[msg.sender] = block.timestamp;
        fuel20.stakeClaimedAt[msg.sender] = block.timestamp;

        // Global analytics update
        fuel20.totalStakedAt[block.timestamp] += __amount;
        fuel20.totalStaked += __amount;

        // emit event
        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Informational, "stake", __amount, "successfully staked the specified amount, updating total and balances.");

        return reward_;
    }


    /**
     * stake allows staking or unstaking of FUEL-20 tokens.
     * This public function enables users to either stake or unstake the specified amount of FUEL-20 tokens, protected against re-entrance.
     *
     * @param __amount amount of FUEL-20 tokens to stake or unstake.
     * @return reward_ reward obtained as a result of staking or unstaking.
     */
    function stake(uint __amount) external nonReentrant returns (uint reward_) {

        // stakeshield
        _fuelShield(SHIELD.STAKE);

        return _stake(__amount);
    }


    /**
     * _unstake handles the logic for virtual unstaking of tokens.
     * This function manages unstaking of all tokens and calculates rewards.
     *
     * @return reward_ The calculated reward for unstaking.
     */
    function _unstake() private returns (uint reward_) {

        uint __amount = fuel20.staked[msg.sender];
        require(__amount > 0, "no tokens to unstake");

        // claim any existing rewards
        if (fuel20.stakeClaimedAt[msg.sender] >= fuel20.initAt) {
            reward_ = _claim(msg.sender);
        }

        // reset account balances
        fuel20.staked[msg.sender] = 0;
        fuel20.stakedAt[msg.sender] = 0;
        fuel20.stakeClaimedAt[msg.sender] = 0;
        fuel20.unstakedAt[msg.sender] = block.timestamp;

        // update global balances
        if (fuel20.totalStaked >= __amount) {

            fuel20.totalStaked -= __amount;
        } else {

            fuel20.totalStaked = 0;
        }

        // global analytics update
        fuel20.totalUnstakedAt[block.timestamp] += __amount;

        // emit event
        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Informational, "unstake", __amount, "successfully unstaked all tokens.");

        return reward_;
    }


    /**
     * unstake allows unstaking of all staked FUEL-20 tokens.
     * This public function enables users to unstake all their previously staked FUEL-20 tokens, protected against re-entrance.
     * The unstaking process uses the _stake function with an amount of zero, indicating a complete unstake of the user's holdings.
     *
     * @return reward_ reward obtained as a result of unstaking.
     */
    function unstake() external nonReentrant returns (uint reward_) {

        return _unstake();
    }


    /**
     * _claim processes a claim or returns the potential reward for the calling user.
     * This private function manages the reward claims within the FUEL-20 system. If cooling from a previous claim, it returns zero but does not block other claims.
     * if claim set to true, process claim, if claim set to false, return reward.
     *
     * @return reward_ reward amount for the claim or zero if still in the cooling period.
     */
    function _claim(address __stakerAddress) private returns (uint reward_) {

        // return 0 if cooling down from previous fuelstake claim as an abort would impeed claims partaking in loop operations
        if (fuel20.stakeClaimedAt[__stakerAddress] > block.timestamp - fuel20.claimCooldown) { return 0; }

        // top off or payout
        reward_ = _adjustForMaxSupply(_reward(__stakerAddress));

        // last stake claimed updated ahead of payout
        fuel20.stakeClaimedAt[__stakerAddress] = block.timestamp;

        // mint tokens to sender
        _mint(__stakerAddress, reward_);

        // global analytics
        _claimMetrixAdd(__stakerAddress, reward_);

        return reward_;
    }


    /**
     * claim processes a claim for the calling user and returns the reward.
     *
     * @return reward_ amount of reward claimed.
     */
    function claim() external nonReentrant returns (uint reward_) {

        // claimshield
        _fuelShield(SHIELD.CLAIM);

        // if still cooling down from previous claim
        require(fuel20.stakeClaimedAt[msg.sender] + fuel20.claimCooldown < block.timestamp, "reward cooling in progress, please try again later");

        // do not attempt claims on 0% APR.
        require(fuel20.stakeAnnualPercentRewardRate >= 1, "APR set to 0%");

        // temporarily disable claim if totalsupply == maxsupply
        require (totalSupply() < fuel20.maxSupply, "max number of tokens in circulation at capacity");

        return _claim(msg.sender);
    }


    /**
     * orClaim allows oracle to claim rewards on behalf of a staker.  Minted tokens are sent directly to the staker's address.
     *
     * @param __stakerAddress address of the staker.
     * @return reward_ amount of rewards claimed.
     */
    function orClaim(address __stakerAddress) external onlyOracle nonReentrant returns (uint reward_) {

        // claimshield
        _fuelShield(SHIELD.CLAIM);

        // claim rewards
        reward_ = _claim(__stakerAddress);

        // trap claims
        if (reward_ > 0) {
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Oracle, Severity.Informational, "orClaim", reward_, "claimed");
        }

        return reward_;
    }


    /**
     * claimedAt retrieves the claimed amount at a specific timestamp for a given sender.
     *
     * @param __owner address of the sender.
     * @param __epochTime timestamp for which to retrieve the claimed amount.
     * @return reward_ claimed amount at the specified timestamp.
     */
    function claimedAt(address __owner, uint __epochTime) public view returns (uint reward_) {

        return (fuel20.claimedAt[__owner][__epochTime]);
    }


    /**
     * burnedAt retrieves total burned tokens by owner at a specific epoch time.
     * This external view function returns the total amounts of burned tokens by owner at a given epoch time.
     *
     * @param __epochTime epoch time for which to retrieve the data.
     * @return burned_ total fuel claimed at the specified epoch.
     */
    function burnedAt(address __owner, uint __epochTime) external view returns (uint burned_) {

        return (fuel20.burnedAt[__owner][__epochTime]);
    }

    //
    // REWARD FUNCTIONS
    //

    /**
     * _reward calculates the self-stake rewards for a given address within the FUEL-20 system.
     * This private view function computes the reward amount based on the staking history of the provided address.
     *
     * @param __address address for which to calculate the staking rewards.
     * @return reward_ calculated reward for the address based on its staking activities.
     */
    function _reward(address __address) private view returns (uint reward_) {

        // failsafe
        if (fuel20.stakeClaimedAt[__address] <= fuel20.initAt) { return 0; }

        uint _timeStakedInSeconds = block.timestamp - fuel20.stakeClaimedAt[__address];

        // ANNUAL_REWARD_RATE = 5 = 5%
        // SECONDS_IN_A_YEAR = 365 * 24 * 60 * 60 == 31536000
        return (fuel20.staked[__address] * fuel20.stakeAnnualPercentRewardRate * _timeStakedInSeconds) / (100 * 31536000);
    }


    /**
     * reward retrieves the current potential reward for the caller based on their staking activities.
     * This external view function returns the reward amount that would be claimed by the calling user.
     *
     * @return reward_ potential reward amount for the calling user based on their staking.
     */
    function reward() external view returns (uint reward_) {

        return _reward(msg.sender);
    }


    /**
     * rewardByOwner calculates and retrieves the potential reward for a specified owner based on their staking activities.
     * This external view function returns the reward amount that would be claimed by the specified owner if they were to initiate a claim.
     * It allows query of rewards for any user, not just the caller, making it useful for interfaces displaying user-specific staking rewards.
     *
     * @param __owner The address of the owner for whom the reward is being calculated.
	 * @return reward_ The potential staking reward amount for the provided owner.
	 */
    function rewardByOwner(address __owner) external view returns (uint reward_) {

        return(_reward(__owner));
    }

    //
    // SUBCHAIN
    //

    /**
    * mintStakerReward mints new tokens to reward subchain validator stakers.
    * This external method is accessible only by controllers and is designed to reward validators with new tokens,
    * ensuring minting operations do not exceed the maximum supply of the token.
    *
    * Precondition checks ensure that:
    * - The account is not the zero address.
    * - The total supply hasn't already reached or exceeded the maximum limit.
    * - The minting amount does not cause the total supply to exceed the maximum limit.
    * Each check is accompanied by a corresponding Trap event for monitoring and logging.
    *
    * @param account The address of the validator staker to receive the reward.
	 * @param amount The amount of tokens to be minted as a reward.
	 * @return True if the tokens are successfully minted, false otherwise.
     */
    function mintStakerReward(address account, uint256 amount) external onlyController nonReentrant returns (bool) {

        // deny rewards to zero address
        if (account == address(0x0)) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Alert, "mintStakerReward", 0, "attempt to mint to zero address");
            return false;
        }

        // deny if totalsupply has reached or exceeded maxsupply
        if (totalSupply() >= fuel20.maxSupply) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Critical, "mintStakerReward", totalSupply(), "total supply reached maximum limit");
            return false;
        }

        // deny if minting amount exceeds maximum supply
        if (totalSupply() + amount > fuel20.maxSupply) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Warning, "mintStakerReward", amount, "minting would exceed maximum supply");
            return false;
        }

        // mint the tokens
        _mint(account, amount);

        // emit handled by _mint function
        return true;
    }


    /**
     * stakerRewardPerBlock returns staker rewards per mainnet block for subchain validators.
     *
     * @return The number of new tokens minted per Main Chain block for the Subchain validator stakers.
     */
    function stakerRewardPerBlock() external view returns (uint) {

        // dynamically disable validator earning slightly ahead of maxSupply
        if (totalSupply() > fuel20.topOffSupply) { return 0; }
        else { return subchain.stakerRewardPerBlock; }
    }


    /**
     * updateStakerRewardPerBlock updates the reward amount per block for Subchain validator stakers.
     *
     * This function allows an authorized controller during executive session to update the number of new tokens minted
     * per main chain block for Subchain validators. It ensures that the system can adapt to changing conditions
     * or policy updates regarding staking rewards. This function calls `exSubchainStakerRewardPerBlockSet` to
     * apply the new settings.  This function exists to support subchain governance token onboarding with ChainSmith.
     *
     * NOTE: This function is specifically formatted to match the Theta Network Subchain requirements and does not conform
     * to existing FuelFoundry design guidelines.  The format was preserved solely for maximum capibility with Subchain operations.
     *
     * @param stakerRewardPerBlock_ The new reward rate to be set per Main Chain block for Subchain validator stakers.
     */
    function updateStakerRewardPerBlock(uint256 stakerRewardPerBlock_) external onlyExecutiveSession onlyController nonReentrant {

        // call existing function to update the staker reward per block
        _subchainStakerRewardPerBlockSet(stakerRewardPerBlock_);

        // emit event
        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Informational, "updateStakerRewardPerBlock", stakerRewardPerBlock_, "new staker reward per block set by validator or controller");
    }


    /**
     * _quorumCodeVerify compares provided code with session code for validity.
     *
     * Checks if `__code` matches the session code and hasn't expired. Essential for time-sensitive code verification.
     *
     * @param __code Code for verification.
     * @return verified_ True if code matches and session is active, false if expired or mismatched.
     */
    function _quorumCodeVerify(uint __code) private view returns (bool verified_) {

        if (block.timestamp > exsess.expiresAt) { return false; } // code expired
        else if (_isCodeWithinVariance(__code, exsess.code)) { return true; } //__code == exsess.code) { return true; }

        return false;
    }

    //
    // EXECUTIVE SESSION GOVERNANCE FUNCTIONS
    //

    /**
     * _govAddressUpdate updates the governance addresses for a specific target.
     * This private function updates the custodial, guardian, executor, and oracle addresses in the GovernanceKey struct.
     *
     * @param  target The target governance structure to update.
     * @param  __custodial The new custodial address.
     * @param  __guardian The new guardian address.
     * @param  __executor The new executor address.
     * @param  __oracle The new oracle address.
     */
    function _govAddressUpdate(GovernanceKey storage target, address __custodial, address __guardian, address __executor, address __oracle) private {

        // caller holds a governance role
        if (msg.sender == target.wallet)  {

            // governance role update notification - custodial
            if (target.custodial != __custodial) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "_govAddressUpdate", uint160(__custodial), string(abi.encodePacked("custodial vote updated to: ", addressToString(__custodial))));
                target.custodial = __custodial;
            }

            // governance role update notification - guardian
            if (target.guardian != __guardian) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "_govAddressUpdate", uint160(__guardian), string(abi.encodePacked("guardian vote updated to: ", addressToString(__guardian))));
                target.guardian  = __guardian;
            }

            // governance role update notification - executor
            if (target.executor != __executor) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "_govAddressUpdate", uint160(__executor), string(abi.encodePacked("executor vote updated to: ", addressToString(__executor))));
                target.executor  = __executor;
            }

            // governance role update notification - oracle
            if (target.oracle != __oracle) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "_govAddressUpdate", uint160(target.wallet), string(abi.encodePacked("oracle vote updated to: ", addressToString(__oracle))));
                target.oracle  = __oracle;
            }
        }
    }


    /**
     * goVoteCast casts vote on behalf of the governance role(s) calling the function, validating non-zero conditions for key roles.
     * This external function updates governance addresses if executed by an authorized role and ensures non-reentrance.
     * Oracle can be set to zero, indicating disabled state, unlike other addresses.
     *
     * @param  __custodial The new custodial address to be set.
     * @param  __guardian The new guardian address to be set.
     * @param  __executor The new executor address to be set.
     * @param  __oracle The new oracle address to be set; can be zero.
     * @return  success_ Returns true if the operation was successful.
     */
    function goVoteCast(address __custodial, address __guardian, address __executor, address __oracle) external onlyGovernance nonReentrant returns (bool success_) {

        require (__custodial != address(0) && __guardian != address(0) && __executor != address(0), "only oracle may equal zero address (disabled)");

        if (msg.sender == custodial.wallet) { _govAddressUpdate(custodial, __custodial, __guardian, __executor, __oracle); }
        if (msg.sender == guardian.wallet)  { _govAddressUpdate(guardian,  __custodial, __guardian, __executor, __oracle); }
        if (msg.sender == executor.wallet)  { _govAddressUpdate(executor,  __custodial, __guardian, __executor, __oracle); }

        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "govSet", 1, "update complete");

        return true;
    }


    /**
     * goMembers retrieves the current active set of governance addresses.
     * This external view function can only be called by an account with governance permissions.
     *
     * @return custodial_ address currently set as the custodial.
     * @return guardian_ address currently set as the guardian.
     * @return executor_ address currently set as the executor.
     * @return oracle_ address currently set as the oracle.
     */
    function goMembers() external view onlyGovernance returns (address custodial_, address guardian_, address executor_, address oracle_) {

        return (custodial.wallet, guardian.wallet, executor.wallet, _oracle());
    }


    /**
     * goElect handles governance role elections.
     *
     * Facilitates election of custodial, guardian, and executor based on governance consensus.
     * The oracle role, determined dynamically, isn't elected.
     * Restricted to execution by the governance contract and protected against re-entrancy for security.
     *
     * @return custodial_ Elected custodial address.
     * @return guardian_ Elected guardian address.
     * @return executor_ Elected executor address.
     * @return oracle_ Dynamically determined oracle address.
     */
    function goElect() external onlyGovernance nonReentrant returns (address custodial_, address guardian_, address executor_, address oracle_) {

        address _legacyCustodial = custodial.wallet;
        address _legacyGuardian = guardian.wallet;
        address _legacyExecutor = executor.wallet;

        // elect new custodial
        custodial.wallet = (guardian.custodial == executor.custodial) ? guardian.custodial : custodial.wallet;

        if (_legacyCustodial != custodial.wallet) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "goElect", uint160(custodial.wallet), "Custodial role updated");
        }

        // elect new guardian
        guardian.wallet = (custodial.guardian == executor.guardian) ? custodial.guardian : guardian.wallet;

        if (_legacyGuardian != guardian.wallet) {

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "goElect", uint160(guardian.wallet), "Guardian role updated");
        }

        // elect new executor
        executor.wallet = (custodial.executor == guardian.executor) ? custodial.executor : executor.wallet;

        if (_legacyExecutor != executor.wallet) {
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "goElect", uint160(executor.wallet), "Executor role updated");
        }

        // oracle is not executive, is returned dynamically
        return (custodial.wallet, guardian.wallet, executor.wallet, _oracle());
    }

    //
    // EXECUTIVE SESSION CUSTODIAL|GUARDIAN FUNCTIONS
    //

    /**
     * exSessionInit initializes new session code or will provide existing session code if not yet expired.
     *
     * If within session plus cooldown, returns existing code. Otherwise, generates a secure code using blockchain
     * attributes and a seed. Access restricted to specific roles and safeguarded against re-entrancy.
     *
     * @return code_ Current or new session code.
     */
    function cgSessionInit() external onlyCustodialGuardian nonReentrant returns (uint code_) {

        // check if the session is still within its cooldown period and return the existing code if true
        if (block.timestamp < exsess.expiresAt + exsess.sessionCooldown) { return (exsess.code); }
        else {

            // last session has expired or closed,
            //generate a new exsess window and code
            exsess.startedAt = block.timestamp;
            exsess.expiresAt = block.timestamp + exsess.sessionMax;

            exsess.code = uint(keccak256(abi.encodePacked(exsess.code + block.number + block.timestamp + block.gaslimit + exsess.seed))) % 10 ** 9;

            return (exsess.code);
        }
    }


    /**
     * cgCodeVerify verifies code against the current executive session code, restricted to custodial/guardian roles only.
     *
     * Calls `_quorumCodeVerify` for code verification under custodial or guardian permissions, does not alter state.
     *
     * @param __code Code for session validation.
     * @return verified_ Outcome of session code comparison.
     */
    function cgCodeVerify(uint __code) external view onlyCustodialGuardian returns (bool verified_) {

        if (exsess.expiresAt < block.timestamp) { return false; }
        else { return (_quorumCodeVerify(__code)); }
    }

    //
    // EXECUTIVE SESSION EXECUTOR FUNCTIONS
    //

    /**
     * goSessionEnter initiates the next executive session by setting its expiration to the current block timestamp + fuel20.sessionMax value.
     * This action effectively activates the session, allowing subsequent actions that depend on the session being active.
     *
     * Access is restricted to ensure only authorized roles, typically custodial, guardian, or executor roles, can enter the session.
     * This is a critical governance function that needs to be protected from reentrancy to maintain state integrity.
     *
     * @param __code The unique session code provided by the actor attempting to initiate the session.
     * @return success_ Boolean indicating whether the session was successfully entered.
     */
    function goSessionEnter(uint __code) external onlyGovernance nonReentrant returns (bool success_) {

        bool custodialVerified = false;
        bool guardianVerified = false;
        bool executorVerified = false;

        // update role code and verify
        if (msg.sender == custodial.wallet) {

            custodial.code = __code;
        }

        if (msg.sender == guardian.wallet) {

            guardian.code = __code;
        }

        if (msg.sender == executor.wallet) {

            executor.code = __code;
        }

        custodialVerified = _quorumCodeVerify(custodial.code);
        guardianVerified = _quorumCodeVerify(guardian.code);
        executorVerified = _quorumCodeVerify(executor.code);

        uint quormCount = (custodialVerified ? 1 : 0) + (guardianVerified ? 1 : 0) + (executorVerified ? 1 : 0);

        // check if two of the three roles verify the code correctly to establish a quorum
        if (quormCount >= 2) {

            // enter executive session
            exsess.expiresAt = block.timestamp + exsess.sessionMax;

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "exSessionEnter", 1, "Executive session entered");
            return true;
        } else {

            // if no quorum is met, log a failed attempt and record in emit who requested action
            if (quormCount == 0) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Warning, "exSessionEnter", 0, "Failed to enter executive session, verification failed or insufficient quorum");
            } else if (quormCount == 1) {

                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "exSessionEnter", 0, "code accepted, awaiting one other member to enter code");
                return false;
            }
        }
    }


    /**
     * goSessionClose closes the current executive session by setting its expiration to the current block timestamp.
     * This action effectively ends the session, preventing any further actions that depend on the session being active.
     *
     * Access is restricted to ensure only authorized roles (custodial, guardian, executor) may close the session.
     *
     * @return success_ Boolean indicating whether the session was successfully closed.
     */
    function goSessionClose() external onlyExecutiveSession onlyGovernance nonReentrant returns (bool success_) {

        if (msg.sender == custodial.wallet && _quorumCodeVerify(custodial.code)) {

            // close executive session
            exsess.expiresAt = block.timestamp;

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "exSessionClose", 1, "executive session closed by custodial");
            return true;
        }

        if (msg.sender == guardian.wallet && _quorumCodeVerify(guardian.code)) {

            // close executive session
            exsess.expiresAt = block.timestamp;

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "exSessionClose", 1, "executive session closed by guardian");
            return true;
        }

        if (msg.sender == executor.wallet && _quorumCodeVerify(executor.code)) {

            // close executive session
            exsess.expiresAt = block.timestamp;

            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Informational, "exSessionClose", 1, "executive session closed by executor");
            return true;
        }

        // if no conditions met, log failed attempt and record in emit who requested action
        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Warning, "exSessionClose", 0, "failed to close executive session, verification failed");

        return false;
    }


    /**
     * goSessionExp returns current executive session expiration time and seconds remaining.
     *
     * Externally accessible by all, provides the session's end timestamp and time left in seconds; useful for tracking session activity.
     *
     * @return exsessSecondsRemaining_ Seconds until session ends, negative if expired.
     * @return exsessExpiresAt_ Session end UNIX timestamp.
     */
    function goSessionExp() external view onlyGovernance returns (int256 exsessSecondsRemaining_, uint exsessExpiresAt_) {

        // a positive number of seconds indicates session is open
        // a negative number of seconds indicates the length of time since executive session was last closed
        return (int(exsess.expiresAt) - int(block.timestamp), exsess.expiresAt);
    }


    /**
     * goCurrentState retrieves the current state and session parameters of the governance.
     *
     * This function provides a snapshot of the current blockchain state relevant to the contract,
     * along with the active executive session's details. It is designed to be called by governance
     * roles to obtain real-time data for making informed decisions and tracking session status.
     * Access is restricted to ensure that only authorized governance participants can fetch this sensitive information.
     *
     * @notice Must be called by an authorized governance role due to the `onlyGovernance` modifier.
     *
     * @return currentBlockNumber_ The number of the most recent block.
     * @return currentBlockTime_ The timestamp of the most recent block, equivalent to the current block time.
     * @return currentGasLimit_ The gas limit of the most recent block, which indicates the maximum amount of gas that can be spent on transactions in the block.
     * @return exsessStartedAt_ The start time of the current executive session, indicating when the session was activated.
     * @return exsessExpiresAt_ The expiration time of the current executive session, indicating when the session will automatically end.
     * @return exsessSessionMax_ The maximum number of actions or changes allowed within the current executive session.
     * @return exsessSessionCooldown_ The cooldown period required before a new session can commence after the current session ends.
     */
    function goCurrentState() external onlyGovernance view returns (
        uint currentBlockNumber_,uint currentBlockTime_,uint currentGasLimit_, uint exsessStartedAt_, uint exsessExpiresAt_, uint exsessSessionMax_, uint exsessSessionCooldown_) {

        return (block.number, block.timestamp, block.gaslimit, exsess.startedAt, exsess.expiresAt, exsess.sessionMax, exsess.sessionCooldown);
    }


    /**
     * goGovElects retrieves the addresses of governance positions across custodial, guardian, and executor categories.
     *
     * This function provides a comprehensive view of the governance structure, listing the addresses associated with
     * key roles within custodial, guardian, and executor groups. Each group includes specific roles such as wallet, custodial,
     * guardian, executor, and oracle. This detailed mapping is vital for ensuring transparency and accountability in governance
     * actions, allowing for a clear understanding of role distributions and responsibilities.
     *
     * Access to this function is restricted to accounts with governance permissions, ensuring that the sensitive structure
     * of governance roles is protected from unauthorized access. As a `view` function, it does not modify the blockchain state,
     * maintaining the integrity of the governance framework while providing essential insights.
     *
     * The data returned is crucial for overseeing the governance landscape, enabling effective monitoring and strategic
     * decision-making within the governance framework.
     *
     * @return custodial_wallet_ Address of the wallet role of the custodial.
     * @return custodial_custodial_ Address of the custodial role of the custodial.
     * @return custodial_guardian_ Address of the guardian role of the custodial.
     * @return custodial_executor_ Address of the executor role of the custodial.
     * @return custodial_oracle_ Address of the oracle role of the custodial.
     * @return guardian_wallet_ Address of the wallet role of the guardian.
     * @return guardian_custodial_ Address of the custodial role of the guardian.
     * @return guardian_guardian_ Address of the guardian role of the guardian.
     * @return guardian_executor_ Address of the executor role of the guardian.
     * @return guardian_oracle_ Address of the oracle role of the guardian.
     * @return executor_wallet_ Address of the wallet role of the executor.
     * @return executor_custodial_ Address of the custodial role of the executor.
     * @return executor_guardian_ Address of the guardian role of the executor.
     * @return executor_executor_ Address of the executor role of the executor.
     * @return executor_oracle_ Address of the oracle role of the executor.
     */
    function goGovElects() external onlyGovernance view returns (
        address custodial_wallet_, address custodial_custodial_, address custodial_guardian_, address custodial_executor_, address custodial_oracle_,
        address  guardian_wallet_, address  guardian_custodial_, address  guardian_guardian_, address  guardian_executor_, address  guardian_oracle_,
        address  executor_wallet_, address  executor_custodial_, address  executor_guardian_, address  executor_executor_, address  executor_oracle_) {

        return (custodial.wallet, custodial.custodial, custodial.guardian, custodial.executor, custodial.oracle,
            guardian.wallet,  guardian.custodial,  guardian.guardian,  guardian.executor,  guardian.oracle,
            executor.wallet,  executor.custodial,  executor.guardian,  executor.executor,  executor.oracle);
    }


    /**
     * _isCodeWithinVariance checks if two codes are within a specified variance.
     *
     * This function evaluates whether the difference between `code1` and `code2` is within a tolerance of 100 units.
     * It is useful for scenarios where exact matches are not required, but close approximations are acceptable, enhancing
     * the flexibility and robustness of code comparison operations.
     *
     * @param code1 The first code for comparison.
	 * @param code2 The second code for comparison.
	 * @return True if the codes are within 100 units of each other, otherwise false.
	 */
    function _isCodeWithinVariance(uint code1, uint code2) private pure returns (bool) {

        return (code1 <= code2 + 100) && (code1 >= code2 - 100);
    }


    /**
     * _inSession returns active status of executive session based on expiry and code consensus.
     *
     * Active if not expired and two of three roles (custodial, guardian, executor) agree on session code within a variance of 100.
     * This allows for minor discrepancies in the codes, enhancing robustness.
     * Called by onlyExecutiveSession modifier, may also be called upon by other functions.
     * @return inSession_ True if active, false if expired or no quorum.
	 */
    function _inSession() private view returns (bool inSession_) {

        // check if the session is not expired
        if (exsess.expiresAt > block.timestamp) {

            // determine if a quorum is established based on code agreement within a variance of 100
            uint agreeCount = 0;

            if (_isCodeWithinVariance(custodial.code, exsess.code)) { agreeCount++; }
            if (_isCodeWithinVariance(guardian.code,  exsess.code)) { agreeCount++; }
            if (_isCodeWithinVariance(executor.code,  exsess.code)) { agreeCount++; }

            return (agreeCount >= 2);
        }

        // return false if the session has expired or if there's no quorum
        return false;
    }


    /**
     * inSession returns active status of executive session based on expiry and code consensus.
     *
     * Active if not expired and two of three roles (custodial, guardian, executor) agree on session code. Public and state-unaltering.
     * Called by onlyExecutiveSession modifier, may also be called upon by
     * @return inSession_ True if active, false if expired or no quorum.
     */
    function inSession() public view returns (bool inSession_) {

        return _inSession();
    }


    /**
     * exGlobalSet updates key system parameters, restricted to the executor.
     *
     * Adjusts staking rewards, fuel ID, minimum stake, claim cooldown, and max allowances with safety caps. Ensures parameters stay within safe limits. Protected against re-entrancy.
     *
     * @param _fuelId Fuel resource identifier.
     * @param _stakeMin Minimum staking amount.
     * @param _claimCooldownInSeconds Cooldown for reward claims.
     * @param _stakeAnnualPercentRewardRate Annual staking reward rate.
     * @param _maxAllowances Maximum allowances, capped at 1000 for gas efficiency.
     * @return fuelId_ Updated fuel ID, reflecting the new or unchanged value.
     * @return stakeMin_ Updated minimum stake amount, reflecting the new or unchanged value.
     * @return claimCooldownInSeconds_ Updated claim cooldown in seconds, reflecting the new or unchanged value.
     * @return stakeAnnualPercentRewardRate_ Updated annual staking reward rate, reflecting the new or unchanged value.
     * @return maxAllowances_ Updated maximum allowances per address, reflecting the new or unchanged value.
     */
    function exGlobalSet(uint80 _fuelId, uint _stakeMin, uint _claimCooldownInSeconds, uint _stakeAnnualPercentRewardRate, uint _maxAllowances) external onlyExecutiveSession onlyExecutor nonReentrant returns (
        uint80 fuelId_, uint stakeMin_, uint claimCooldownInSeconds_, uint stakeAnnualPercentRewardRate_, uint maxAllowances_) {

        // fuelId must be greater than 0, update fuel ID if different from the current value and log change.
        if (_fuelId > 0 && fuel20.fuelId != _fuelId) {

            fuel20.fuelId = _fuelId;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Informational, "exGlobalSet", _fuelId, "fuelId updated");
        }

        // stakeMin must be greater than 0, failsafe: update minimum stake (in wei) if different from the current value and log change.
        if (_stakeMin > 0 && fuel20.stakeMin != _stakeMin) {

            fuel20.stakeMin = _stakeMin < 1 ether ? 1 ether : _stakeMin;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Informational, "exGlobalSet", _stakeMin, "minimum stake amount updated");
        }

        // failsafe: update and log changes to claim cooldown, if claim cooldown is set greater than 1-hour, lower to 1-hour.
        if (fuel20.claimCooldown != _claimCooldownInSeconds) {

            fuel20.claimCooldown = _claimCooldownInSeconds > 3600 ? 3600 : _claimCooldownInSeconds;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Informational, "exGlobalSet", fuel20.claimCooldown, "claim cooldown updated");
        }

        // failsafe: update annual percent reward rate if different from the current value and log change, if stakeAPR is set greater than 10000, lower to 10000.
        if (fuel20.stakeAnnualPercentRewardRate != _stakeAnnualPercentRewardRate) {

            fuel20.stakeAnnualPercentRewardRate = _stakeAnnualPercentRewardRate > 10000 ? 10000 : _stakeAnnualPercentRewardRate;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Informational, "exGlobalSet", _stakeAnnualPercentRewardRate, "stake annual percent reward rate updated");
        }

        // failsafe: update and log max allowances, if maxAllowances is set greater than 1000, lower to 1000 to keep gas operations reasonable.
        if (fuel20.maxAllowances != _maxAllowances) {

            fuel20.maxAllowances = _maxAllowances > 1000 ? 1000 : _maxAllowances;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Informational, "exGlobalSet", _maxAllowances, "maximum allowances per address update");
        }

        return (fuel20.fuelId, fuel20.stakeMin, fuel20.claimCooldown, fuel20.stakeAnnualPercentRewardRate, fuel20.maxAllowances);
    }


    /**
     * exShieldSet toggles system shields and maintenance mode.
     *
     * Executor-controlled function to adjust operation shields (mint, burn, stake, claim) and maintenance status. Ensures system responsiveness to security needs or operational updates. Guarded for executor-only access and against re-entrancy.
     *
     * @param _maintenance Toggles maintenance mode.
     * @param _mintshield Toggles minting operations.
     * @param _burnshield Toggles burning operations.
     * @param _stakeshield Toggles staking operations.
     * @param _claimshield Toggles claiming operations.
     */
    function exShieldSet(bool _claimshield, bool _mintshield, bool _stakeshield, bool _burnshield, bool _maintenance) external onlyExecutiveSession onlyExecutor nonReentrant returns (bool success_) {

        if (fuel20.claimshield != _claimshield) {

            fuel20.claimshield = _claimshield;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Notice, "exShieldSet", _claimshield ? 1 : 0, "claimshield updated");
        }

        if (fuel20.mintshield != _mintshield) {

            fuel20.mintshield = _mintshield;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Notice, "exShieldSet", _mintshield ? 1 : 0, "mintsshield updated");
        }

        if (fuel20.stakeshield != _stakeshield) {

            fuel20.stakeshield = _stakeshield;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Notice, "exShieldSet", _stakeshield ? 1 : 0, "stakeshield updated");
        }

        if (fuel20.burnshield != _burnshield) {

            fuel20.burnshield = _burnshield;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Notice, "exShieldSet", _burnshield ? 1 : 0, "burnshield updated");
        }

        if (fuel20.maintenance != _maintenance) {

            fuel20.maintenance = _maintenance;
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Notice, "exShieldSet", _maintenance ? 1 : 0, "maintenance mode updated");
        }

        return true;
    }


    /**
     * _isMintController checks if address is authorized for minting.
     *
     * Scans mint controller addresses to confirm if given address has mint permissions, used to validate minting actions within the contract.
     *
     * @param __controller Address to verify.
     * @return True if authorized as a mint controller, false otherwise.
     */
    function _isMintController(address __controller) private view returns (bool) {

        // cache mint controller length for gas optimization
        uint _mintControllersLength = mintControllers.length;

        // iterate over all registered mint controllers
        for (uint i = 0; i < _mintControllersLength; i++) {

            // check if the current controller matches the specified address and is enabled if found
            if (mintControllers[i].contractAddress == __controller) {

                // return true if a match is found
                return true;
            }
        }

        // return false if no match is found
        return false;
    }


    /**
     * _isMintControllerEnabled checks if a controller is authorized and enabled for minting.
     *
     * Iterates mint controllers to verify if an address is authorized and enabled, supporting dynamic control of minting permissions.
     *
     * @param __controller Address to check.
     * @return True if the address is an enabled mint controller, false otherwise.
     */
    function _isMintControllerEnabled(address __controller) private view returns (bool) {

        // cache mint controller length for gas optimization
        uint _mintControllersLength = mintControllers.length;

        // iterate through the list of mint controllers
        for (uint i = 0; i < _mintControllersLength; i++) {

            // check if the controller matches the address and is enabled
            if (mintControllers[i].contractAddress == __controller && mintControllers[i].enabled) {

                // return true if both conditions are met
                return true;
            }
        }

        // return false if no matching, enabled controller is found
        return false;
    }


    /**
     * exMintCtrlGet retrieves the status of a specified controller as a mint controller.
     *
     * This external view function is accessible only by the executor and is designed to check if a given
     * address is recognized as a mint controller within the system, and if so, whether it is currently enabled.
     * It leverages private functions `_isMintController` and `_isMintControllerEnabled` to ascertain the
     * controller's status. This method of querying controller status enables the executor to make informed
     * decisions regarding minting permissions and to manage the list of controllers effectively. The function
     * returns two boolean values indicating whether the controller exists and whether it is enabled, providing
     * clear, actionable information.
     *
     * @param __controller The address of the controller to query.
     * @return exists_ True if the controller is a mint controller, false otherwise.
     * @return enabled_ True if the controller is enabled, false otherwise.
     */
    function exMintCtrlGet(address __controller) external view onlyExecutiveSession onlyExecutor returns (bool exists_, bool enabled_) {

        // check if address is a mint controller
        if (_isMintController(__controller)) {

            // if so, return true and check if it's enabled
            return (true, _isMintControllerEnabled(__controller));
        } else {

            // if not a controller, return false for both exists_ and enabled_
            return (false, false);
        }
    }


    /**
     * exMintCtrlAdd adds a new controller to the list of mint controllers.
     *
     * This function allows the executor to add a new minting controller to the system, enhancing the
     * flexibility and scalability of minting operations. Before adding a new controller, it performs
     * several validations: it checks the controller is not already listed, and verifies the executor's
     * code through `_quorumCodeVerify` to ensure the action is authorized and legitimate. The new controller
     * is initially added in a disabled state, allowing for subsequent activation in a controlled manner.
     * This process is protected by the `onlyExecutor` modifier to restrict this capability to the executor
     * role, and the `nonReentrant` modifier to prevent re-entrancy vulnerabilities.
     *
     * Emits a Trap event with details of the action taken.
     *
     * @param __controller The address of the new controller to be added.
     */
    function exMintCtrlAdd(address __controller) external onlyExecutiveSession onlyExecutor nonReentrant returns (bool success_) {

        // confirm the operation is authorized
        require(_quorumCodeVerify(executor.code),  "quorm code invalid");

        // validate that the controller does not already exist
        require(!_isMintController(__controller), "mint controller exists");

        // cap max controllers to 1000
        require(mintControllers.length < 1000, "max controllers reached");

        // define and add new controller in disabled state
        MintController memory _newController = MintController({
            enabled: false,
            contractAddress: __controller
        });

        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Executive, Severity.Notice, "exMintCtrlAdd", uint160(__controller), "controller added");

        mintControllers.push(_newController);

        return true;
    }


    /**
     * exMintCtrlSet assigns a new controller or updates existing controller state.
     *
     * This function manages access control of controllers within the contract,
     * enabling or disabling a controller's privileges. The changes are recorded
     * on the blockchain for transparency. It can only be called by members of
     * the 'fabric' (as indicated by the onlyFabric modifier). The function
     * checks if the specified controller is in the array of controllers before
     * updating its state.
     *
     * Emits a Trap event with details of the action taken.
     *
     * @param __controller The address of the controller to be updated.
     * @param __enabled A boolean indicating whether to enable (true) or disable (false) the controller.
     */
    function exMintCtrlSet(address __controller, bool __enabled) external onlyExecutiveSession onlyCustodialGuardian nonReentrant returns (address controller_, bool enabled_) {

        // cache mint controller length for gas optimization
        uint _mintControllersLength = mintControllers.length;

        bool _isControllerPresent = false;

        for (uint i = 0; i < _mintControllersLength; i++) {

            if (__controller == mintControllers[i].contractAddress) {

                _isControllerPresent = true;

                if (!mintControllers[i].enabled && __enabled) {

                    emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "exMintCtrlSet", uint160(mintControllers[i].contractAddress), "controller enabled");
                } else if (mintControllers[i].enabled && !__enabled) {

                    emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "exMintCtrlSet", uint160(mintControllers[i].contractAddress), "controller disabled");
                } else {

                    revert("value already set to value provided");
                }

                mintControllers[i].enabled = __enabled;

                return (mintControllers[i].contractAddress, mintControllers[i].enabled);
            }
        }

        revert("controller not found, add controller first");
    }


    /**
     * exMintCtrlDel removes a specified controller from the list of authorized mint controllers.
     *
     * This function enables Executor to remove an existing mint controller from the system. It checks for the existence of the controller address in the list of mint controllers
     * and validates the operation through `_quorumCodeVerify` to confirm removal is authorized. The specified controller
     * is then located in the array of controllers and removed by replacing it with the last controller in the list
     * and then popping the last element, efficiently maintaining the integrity of the list. This action is safeguarded
     * by the `onlyExecutor` modifier to ensure that only the executor can execute this function, and `nonReentrant` to
     * protect against re-entrancy attacks. If the controller is not found, the function reverts the transaction.
     *
     * Emits a Trap event with details of the action taken.
     *
     * @param __controller The address of the controller to be removed.
     */
    function exMintCtrlDel(address __controller) external onlyExecutiveSession onlyExecutor nonReentrant returns (bool success_) {

        // confirm the operation is authorized
        require(_quorumCodeVerify(executor.code),  "quorm code invalue");

        // verify the controller exists before attempting removal
        require(_isMintController(__controller), "controller does not exist");

        // cache mint controller length for gas optimization
        uint _mintControllersLength = mintControllers.length;

        // iterate through the mint controllers to find and remove the specified controller
        for (uint i = 0; i < _mintControllersLength; i++) {

            if (mintControllers[i].contractAddress == __controller) {

                // emit controller deletion
                emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Governance, Severity.Notice, "exMintCtrlDel", uint160(mintControllers[i].contractAddress), "controller deleted");

                // replace the controller to be removed with the last controller in the list
                mintControllers[i] = mintControllers[_mintControllersLength - 1];

                // remove the last controller from the list
                mintControllers.pop();

                return true;
            }
        }

        // if the specified controller is not found, revert the transaction
        revert("controller not found");
    }


    /**
     * _subchainStakerRewardPerBlockSet sets the staker reward per block for subchain validator node stakers.
     *
     * This function is specifically designed for Theta Network's subchain environments, enabling
     * the adjustment of staker rewards per block. It provides Executor the capability to dynamically
     * set the reward amount that validator nodes receive for their contributions per block, within
     * predefined limits. The operation ensures that the reward does not exceed a maximum threshold
     * to maintain economic balance and sustainability of the staking rewards mechanism.
     *
     * To enhance security and prevent unauthorized changes, the function is protected with the onlyExecutor
     * modifier, ensuring that only the designated Executor account may modify the staker reward.
     *
     * @param __stakerRewardPerBlockInWei The new staker reward per block amount in Wei.
     * @return subchainStakerRewardPerBlock_ The updated staker reward per block, confirming the change.
     */
    function _subchainStakerRewardPerBlockSet(uint __stakerRewardPerBlockInWei) private returns (uint subchainStakerRewardPerBlock_) {

        // validate that the proposed reward does not exceed the maximum allowed.
        require(__stakerRewardPerBlockInWei <= subchain.stakerRewardPerBlockMax, "!val");

        // emit event
        //emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Informational, "exSubchainStakerRewardPerBlockSet", __stakerRewardPerBlockInWei, "new staker reward per block set");

        // if valid, update the staker reward per block to the new value.
        if (__stakerRewardPerBlockInWei <= subchain.stakerRewardPerBlockMax) {

            subchain.stakerRewardPerBlock = __stakerRewardPerBlockInWei;
        }

        // return updated staker reward per block value as confirmation
        return (subchain.stakerRewardPerBlock);
    }


    /**
     * exSubchainStakerRewardPerBlockSet sets the staker reward per block for subchain validator node stakers.
     *
     * This function is specifically designed for Theta Network's subchain environments, enabling
     * the adjustment of staker rewards per block. It provides Executor the capability to dynamically
     * set the reward amount that validator nodes receive for their contributions per block, within
     * predefined limits. The operation ensures that the reward does not exceed a maximum threshold
     * to maintain economic balance and sustainability of the staking rewards mechanism.
     *
     * To enhance security and prevent unauthorized changes, the function is protected with the onlyExecutor
     * modifier, ensuring that only the designated Executor account may modify the staker reward.
     *
     * @param __stakerRewardPerBlockInWei The new staker reward per block amount in Wei.
     * @return subchainStakerRewardPerBlock_ The updated staker reward per block, confirming the change.
     */
    function exSubchainStakerRewardPerBlockSet(uint __stakerRewardPerBlockInWei) public onlyExecutiveSession onlyExecutor nonReentrant returns (uint subchainStakerRewardPerBlock_) {

        // update staker rewards per block
        _subchainStakerRewardPerBlockSet(__stakerRewardPerBlockInWei);

        // emit event
        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Informational, "exSubchainStakerRewardPerBlockSet", __stakerRewardPerBlockInWei, "new staker reward per block set by executor");

        // return updated staker reward per block value as confirmation
        return (subchain.stakerRewardPerBlock);
    }

    //
    // GETS (PUBLIC) | DMPS (FABRIC GETS)
    //

    /**
     * cgSessionState retrieves detailed information about the current executive session.
     *
     * This function provides a comprehensive view of the executive session's current state,
     * including its unique code, seed value, start time, expiry time, maximum session limit, and cooldown period.
     * This snapshot is essential for governance operations to ensure decisions are made within the context
     * of active session parameters, enhancing the control and execution of governance protocols.
     *
     * Only accounts with governance permissions can access this data, safeguarding sensitive session
     * information from unauthorized access. As a `view` function, it does not modify the blockchain state,
     * ensuring its execution is safe and non-disruptive.
     *
     * The data returned is crucial for monitoring and managing the dynamics of executive sessions within
     * the governance framework, facilitating informed decision-making and effective governance oversight.
     *
     * @return code_ The unique code identifier for the session.
     * @return seed_ The seed value associated with the session for generating deterministic outcomes.
     * @return startedAt_ The blockchain timestamp when the session started.
     * @return expiresAt_ The blockchain timestamp when the session is set to expire.
     * @return sessionMax_ The maximum allowed number of actions or changes within this session.
     * @return sessionCooldown_ The required cooldown period before a new session can commence after this one ends.
     */
    function cgSessionState() external onlyCustodialGuardian view returns (
        uint code_, uint seed_, uint startedAt_, uint expiresAt_, uint sessionMax_, uint sessionCooldown_) {

        return(exsess.code, exsess.seed, exsess.startedAt, exsess.expiresAt, exsess.sessionMax, exsess.sessionCooldown);
    }


    /**
     * lsFabric returns the current configuration and statistical variables of the fuel20 contract for transparency.
     *
     * This function is designed to provide a comprehensive view of the fabric's operational variables,
     * offering insights into both configuration settings and real-time statistics of the contract. By
     * exposing these variables, it supports transparency and allows for informed interactions with the
     * contract. This is especially useful for understanding the contract's state, including staking
     * mechanics, supply metrics, and security features.
     *
     * The function is marked as `external` and `view`, indicating that it is intended to be called from
     * outside the contract and does not modify the contract state. This ensures that it can be freely
     * called (in most cases) to obtain information without incurring gas fees.
     *
     * @return fuelId_ FuelFoundry MetaForge unique identifier for tying data back into FuelMetrix.
     * @return initAt_ Initialization timestamp of the contract.
     * @return maxAllowances_ The maximum number of allowances per owner.
     * @return stakeMinInWei_ The minimum stake required (in wei).
     * @return claimCooldownInSeconds_ The cooldown period for claiming rewards.
     * @return stakeAnnualPercentRewardRate_ The annual percentage rate for staking rewards.
     * @return totalSupply_ The total supply of existing tokens in circulation.
     * @return maxSupply_ The maximum supply of tokens.
     * @return topOffSupply_ The supply top-off value.
     * @return maintenance_ Indicates if the contract is in maintenance mode.
     * @return mintshield_ Indicates if the minting shield is active.
     * @return burnshield_ Indicates if the burning shield is active.
     * @return stakeshield_ Indicates if the staking shield is active.
     * @return claimshield_ Indicates if the claiming shield is active.
     */
    function lsFabric() external view returns (
        uint80 fuelId_, uint initAt_, uint maxAllowances_, uint stakeMinInWei_, uint claimCooldownInSeconds_,
        uint stakeAnnualPercentRewardRate_, uint totalSupply_, uint maxSupply_, uint topOffSupply_,
        bool maintenance_, bool mintshield_, bool burnshield_, bool stakeshield_, bool claimshield_
    ) {

        return (
            fuel20.fuelId, fuel20.initAt, fuel20.maxAllowances, fuel20.stakeMin, fuel20.claimCooldown,
            fuel20.stakeAnnualPercentRewardRate, totalSupply(), fuel20.maxSupply, fuel20.topOffSupply,
            fuel20.maintenance, fuel20.mintshield, fuel20.burnshield, fuel20.stakeshield, fuel20.claimshield
        );
    }


    /**
     * lsMintCtrls retrieves the current list of mint controllers within the contract.
     *
     * This external view function provides access to the complete array of MintController structs,
     * allowing calling entities to view the active controllers and their statuses.
     *
     * @return mintControllers_ An array representing all the controllers currently configured in the contract.
	 */
    function lsMintCtrls() external view returns (MintController[] memory mintControllers_) {

        return (mintControllers);
    }


    /**
     * _nonce generates a nonce for transaction or operation identification.
     *
     * This private function is responsible for generating a unique identifier (nonce) for use in
     * various contract operations that require a unique or sequential value. The nonce is managed
     * within the fuel20 contract's state, ensuring that each call to this function returns a unique
     * value by incrementing the current nonce.
     *
     * To prevent the nonce from exceeding the maximum value for a uint type, this function checks if
     * the nonce has reached the maximum value. If it has not, the function increments and returns the
     * nonce. If the maximum value is reached, the function resets the nonce to 0, starting the cycle
     * over. This reset mechanism ensures continuous operation without interruption.
     *
     * @return nonce_ The newly generated nonce value.
     */
    function _nonce() private returns (uint nonce_) {

        if   (fuel20.nonce < type(uint).max) {

            fuel20.nonce++;
            return fuel20.nonce;
        } else {

            fuel20.nonce=0;
            return 0;
        }
    }


    /**
     * nonce is a publicly accessible function that generates a nonce.
     *
     * This function serves as an external interface to the private `_nonce` function, allowing
     * external callers to generate a nonce. The generated nonce can be used for various purposes,
     * including but not limited to, transaction identification, operation ordering, or as part of a
     * security mechanism to prevent replay attacks.
     *
     * @return nonce_ The generated nonce value, obtained by invoking the private `_nonce` function.
     */
    function nonce() public onlyGovernance nonReentrant returns (uint nonce_) {

        return (_nonce());
    }


    /**
     * nonceLast returns the latest nonce used in the fuel20 contract.
     *
     * This function provides external access to the current nonce value, facilitating
     * tracking and validation of unique operations or transactions within the contract.
     *
     * @return nonce_ The current nonce value in the fuel20 contract.
     */
    function nonceLast() external view returns (uint nonce_) {

        return (fuel20.nonce);
    }


    /**
     * maxSupply externally accessible function that returns the maximum supply of tokens.
     *
     * This function provides public access to the `maxSupply` variable of the fuel20 contract,
     * enabling external entities and contracts to query the maximum number of tokens that can
     * be minted or generated within the ecosystem.
     *
     * @return maxSupply_ The maximum supply of tokens defined in the fuel20 contract.
     */
    function maxSupply() external view returns (uint maxSupply_) {

        return fuel20.maxSupply;
    }


    /**
     * _adjustForMaxSupply adjusts the minting amount to ensure that the total token supply does not exceed the predefined maximum supply limit.
     *
     * This private function is designed to prevent the total token supply from surpassing the maximum allowable supply (fuel20.maxSupply).
     * It calculates the available room left to reach the max supply by subtracting the current total supply from the maximum supply limit.
     *
     * If the requested mint amount exceeds the available room, the function adjusts the mint amount down to exactly fill to the max supply.
     * This prevents any overflow beyond the max supply. Alternatively, if the requested amount is within the available room,
     * it permits minting of the original requested amount.
     *
     * @param __amount The intended mint amount proposed for addition to the total supply.
     * @return adjustedAmount_ Returns the adjusted mint amount that conforms to the maximum supply constraints. If no adjustment is needed,
     * it returns the original __amount proposed.
     */
    function _adjustForMaxSupply(uint __amount) private returns (uint adjustedAmount_) {

        // calculate remaining room until maxSupply is reached
        uint availableAmount = fuel20.maxSupply - totalSupply();

        if (__amount > availableAmount) {

            // amount to mint would overflow maxSupply, adjust it to fill to maxSupply exactly
            adjustedAmount_ = availableAmount;

            // emit notification about the adjustment
            emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Protocol, Severity.Notice, "_adjustForMaxSupply", adjustedAmount_, "invoked");
        } else {

            // no adjustment needed, use the original amount
            adjustedAmount_ = __amount;
        }

        // return the possibly adjusted mint amount
        return adjustedAmount_;
    }

    //
    // FUELTOOLS
    //

    /**
     * addressToString converts an Ethereum address to its string representation.
     * This function takes an address and converts it into a human-readable hexadecimal string prefixed with "0x".
     * It is useful for encoding addresses for events or logging purposes where a string format is more readable or required.
     *
     * @param _addr The Ethereum address to be converted to a string.
     * @return The string representation of the address, including leading "0x" followed by the 40 hexadecimal characters.
     */
    function addressToString(address _addr) internal pure returns (string memory) {

        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);

        str[0] = '0';
        str[1] = 'x';

        for (uint i = 0; i < 20; i++) {

            str[2+i*2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3+i*2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }

        return string(str);
    }


    /**
     * orWithdrawERC20 withdraws ERC-20 tokens sent to this contract, to the oracle address.
     *
     * The function directly transfers the specified amount of ERC-20 tokens to the oracle's address. This function is
     * specifically for ERC-20 tokens, not for native tokens or other types of assets that may be held by the contract.
     *
     * *** Use with extreme caution *** If the token contract is not published, do NOT use this tool. ***
     *
     * @param tokenAddress The address of the ERC-20 token contract.
     * @param amount The amount of tokens to be withdrawn.
     */
    function orWithdrawERC20(address tokenAddress, uint256 amount) external onlyOracle nonReentrant {

        require(IERC20(tokenAddress).transfer(_oracle(), amount), "transfer failed");
    }

    //
    // NATIVE TOKEN HANDLING
    //

    /**
     * orWithdrawEther withdraws native tokens sent to this contract, to a oracle address.
     *
     * The function directly transfers the specified amount of native token to the caller's address. This is strictly for native token,
     * not for ERC-20 tokens or other types of assets that might be held by the contract.
     *
     * @param amount The amount of native token (in wei) to be withdrawn from the contract.
     */
    function orWithdrawEther(uint256 amount) external onlyOracle nonReentrant {

        payable(_oracle()).transfer(amount);
    }


    /**
     * receive permits receiving native tokens with no data, with the addition of nonReentrant and emit.
     *
     * This external payable function is designed to accept native token transfers without additional data.
     */
    receive() external payable nonReentrant {

        emit Trap(_nonce(), block.timestamp, msg.sender, Facility.Operations, Severity.Alert, "receive", msg.value, "native token received");
    }


    /**
     * fallback reverts unexpected transactions and data sent to the contract.
     *
     * This external payable fallback function is triggered when a call to the contract does not match any functions
     * or when Ether is sent with data. It logs such interactions using the `revert` below.
     *
     * This function is intentionally made non-reentrant for security reasons,
     * even though it always reverts. This is to maintain a high standard of security
     * practices across all contract functions that might be sensitive.
     */
    fallback() external payable {

        revert("Close, but no cigar...");
    }
}