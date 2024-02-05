// SPDX-License-Identifier: MIT

// The OmniToken Ethereum token contract library, supporting multiple token standards.
// By Hiroshi Yamamoto.
// 虎穴に入らずんば虎子を得ず。
//
// Officially hosted at: https://github.com/dublr/dublr

pragma solidity ^0.8.15;

import "./OmniTokenInternal.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20Optional.sol";
import "./interfaces/IERC20Burn.sol";
import "./interfaces/IERC20SafeApproval.sol";
import "./interfaces/IERC20IncreaseDecreaseAllowance.sol";
import "./interfaces/IERC20TimeLimitedTokenAllowances.sol";
import "./interfaces/IERC777.sol";
import "./interfaces/IERC1363.sol";
import "./interfaces/IERC4524.sol";
import "./interfaces/IEIP2612.sol";

/**
 * @title OmniToken
 * @dev The OmniToken Ethereum token contract library, supporting multiple token standards.
 * @author Hiroshi Yamamoto
 */
contract OmniToken is OmniTokenInternal {

    // -----------------------------------------------------------------------------------------------------------------
    // ERC20 fields

    /** @dev ERC20 allowances. */
    mapping(address => mapping(address => uint256)) internal _allowance;

    /** @dev The allowance amount that is treated as unlimited by some ERC20 exchanges. */
    uint256 internal constant UNLIMITED_ALLOWANCE = type(uint256).max;

    // --------------

    /** @dev The block timestamp after which the ERC20 allowance expires for a given address. */
    mapping(address => mapping(address => uint256)) internal _allowanceExpirationTimestamp;

    /** @dev The expiration time that is treated as unlimited, if unlimited expiration is enabled. */
    uint256 internal constant UNLIMITED_EXPIRATION = type(uint256).max;
    
    /**
     * @notice The default number of seconds that an allowance is valid for, after the allowance or permit
     * is granted, before the allowance expires.
     *
     * @dev Note that the block timestamp can be altered by miners up to about +/-15 seconds (as long as block
     * timestamps increase monotonically), so do not use an allowance expiration time of less than 15 seconds.
     *
     * @dev Call `_owner_setDefaultAllowanceExpirationSec(type(uint256).max)` as the contract owner
     * if you want allowances to not expire, for backwards compatibility with ERC20.
     */
    uint256 public defaultAllowanceExpirationSec = 3600;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Set the default number of seconds that an allowance is valid for (default: 3600). Set this to
     * `type(uint256).max == 2**256-1` if you want allowances never to expire, for backwards compatibility
     * with ERC20.
     *
     * @dev Note that the block timestamp can be altered by miners up to about +/-15 seconds (as long as block
     * timestamps increase monotonically), so do not use an allowance expiration time of less than 15 seconds.
     *
     * You can utilize a different expiration time on a case-by-case basis by calling `approveWithExpiration`.
     *
     * @param allowanceExpirationSec The number of seconds that allowances should be valid for.
     */
    function _owner_setDefaultAllowanceExpirationSec(uint256 allowanceExpirationSec) external ownerOnly {
        defaultAllowanceExpirationSec = allowanceExpirationSec;
    }

    /**
     * @dev Calculate default allowance expiration time.
     *
     * This is ERC20 compatible if `defaultAllowanceExpirationSec == type(uint256).max`.
     *
     * @return expirationTimestamp The default allowance expiration block timestamp, defaultAllowanceExpirationSec
     * seconds in the future.
     */
    function defaultAllowanceExpirationTime() private view returns (uint256 expirationTimestamp) {
        return defaultAllowanceExpirationSec == UNLIMITED_EXPIRATION
                    ? defaultAllowanceExpirationSec
                    // solhint-disable-next-line not-rely-on-time
                    : block.timestamp + defaultAllowanceExpirationSec;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC777 fields

    /** @dev ERC777 default operators, if any. */
    address[] internal _defaultOperators;

    /** @notice ERC777 default operators, if any. */
    function defaultOperators() external view returns (address[] memory operators) { return _defaultOperators; }

    /** @dev True if an address is a default operator. */
    mapping(address => bool) internal isDefaultOperator;

    /** @dev True if an address is a revoked default operator. */
    mapping(address => mapping(address => bool)) internal isRevokedDefaultOperatorFor;

    /** @dev True if an address is an authorized operator. */
    mapping(address => mapping(address => bool)) internal isAuthorizedOperatorFor;

    // -----------------------------------------------------------------------------------------------------------------
    // EIP2612 permit API public field

    /** @notice EIP2612 permit nonces. */
    mapping(address => uint) public override(IEIP2612) nonces;

    // -----------------------------------------------------------------------------------------------------------------
    // Constructor

    /**
     * @dev Function that can be used to pass [] to the constructor, for `erc777DefaultOperators`.
     * Needed because Solidity has no way to declare an empty typed array literal.
     */
    function emptyAddressArray() internal pure returns (address[] memory) { }

    /**
     * @notice OmniToken constructor.
     *
     * @param tokenName the name of the token.
     * @param tokenSymbol the ticker symbol for the token.
     * @param tokenVersion the version number string for the token.
     * @param erc777DefaultOperators any default ERC777 operators.
     * @param initialMintAmount how many coins to mint for owner/deployer of contract.
     */
    constructor(string memory tokenName, string memory tokenSymbol, string memory tokenVersion,
            address[] memory erc777DefaultOperators, uint256 initialMintAmount)
            OmniTokenInternal(tokenName, tokenSymbol, tokenVersion) {

        // Set up ERC777 default operators, if any
        _defaultOperators = erc777DefaultOperators;
        for (uint256 i = 0; i < _defaultOperators.length; i++) {
            isDefaultOperator[_defaultOperators[i]] = true;
        }

        if (initialMintAmount > 0) {
            // Perform initial mint for contract owner/deployer
            _mint(msg.sender, msg.sender, initialMintAmount, "", "");
        }

        // Register via ERC1820
        registerInterfaceViaERC1820("OmniToken", true);
        
        // (Don't need to register OmniToken API via ERC165 -- each of the individual supported APIs is already
        // registered by OmniTokenInternal's constructor)
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Core internal state management functions (modified with `stateUpdater` to prevent these functions being
    // called reentrantly, and modified by `extCallerDenied` to ensure that these functions cannot themselves
    // call out to external functions (so that functions that call these functions can only call them in the
    // Effects phase of Checks-Effects-Interactions).

    /**
     * @dev Mint `amount` tokens into `account`.
     *
     * Modified with `extCallerDenied` so that external contracts cannot be called. Used by the Dublr subcontract
     * to ensure that _mint cannot call out to external contracts, so that Checks-Effects-Interactions is respected.
     * Therefore, cannot be called from the ERC777, ERC1363, or ERC4524 APIs (since these call external contracts).
     *
     * @param operator The address performing the mint.
     * @param account The address to mint tokens into.
     * @param amount The number of tokens to mint.
     * @param data Data generated by the user to be passed to the recipient.
     * @param operatorData Data generated by the operator to be passed to the recipient.
     */
    function __mint_extCallerDenied(address operator, address account, uint256 amount, 
            bytes memory data, bytes memory operatorData) internal stateUpdater extCallerDenied {

        // PRECONDITIONS [CHECKS]:
        
        require(operator != address(0), "Bad operator");
        require(account != address(0), "Bad account");
        require(amount != 0, "Zero amount");

        // MINT [EFFECTS]:

        // Mint tokens
        balanceOf[account] += amount;
        totalSupply += amount;

        // EMIT EVENTS:

        if (_erc777CallDepth > 0) {
            // Emit ERC777 Minted event
            emit Minted(operator, account, amount, data, operatorData);
        } else {
            // Emit ERC20 transfer event showing transfer from address(0)
            emit Transfer(/* sender = */ address(0), /* recipient = */ account, amount);
            // Emit ERC20 "safe approval" transfer event
            emit TransferInfo(operator, /* sender = */ address(0), /* recipient = */ account, amount);
        }
        
        // NO INTERACTIONS (modified with extCallerDenied)
    }
    
    /**
     * @dev Set the value of the allowance of `spender` to spend `holder`s tokens. Called only from `_approve`
     * and `_spendAllowance`, and only after all checks have been performed. (This function performs no checks
     * on the validity of the allowance, the holder, or the spender.)
     */
    function __setAllowance_noChecks_extCallerDenied(
            address holder, address spender, uint256 amount, uint256 expirationTimestamp)
            // Modified by extCallerDenied so that extCaller functions cannot be called, because
            // __spendAllowance_extCallerDenied (which calls __setAllowance_noChecks_extCallerDenied)
            // may be called by _transfer before _transfer has finished updating contract state.
            // This ensures that future code changes do not break the Checks-Effects-Interactions
            // pattern.
            private stateUpdater extCallerDenied {

        // APPROVE [EFFECTS]:

        // Update allowance.
        uint256 prevAmount = _allowance[holder][spender];
        _allowance[holder][spender] = amount;
        
        // Update expiration.
        // For allowedAmount == 0, set expiration time to 0 to free up storage.
        uint256 approvedExpirationTime = amount == 0 ? 0 : expirationTimestamp;
        _allowanceExpirationTimestamp[holder][spender] = approvedExpirationTime;

        // EMIT EVENTS:

        // Emit ERC20 Approval event
        emit Approval(holder, spender, amount);
        // Emit ERC20 "safe approval" event
        emit ApprovalInfo(holder, spender, prevAmount, amount);
        // Emit ERC20 "approval with expiration" event
        emit ApprovalWithExpiration(holder, spender, amount, approvedExpirationTime);
        
        // NO INTERACTIONS (modified with extCallerDenied)
    }

    /**
     * @dev Spend `amount` of `operator`'s allowance to spend `holder`'s tokens.
     * Called only by `_transfer`, and assumes some validity checks have already been performed.
     */ 
    function __spendAllowance_extCallerDenied(address operator, address holder, uint256 amount)
            // Modified by extCallerDenied so that extCaller functions cannot be called, because
            // __spendAllowance_extCallerDenied may be called by _transfer before _transfer has
            // finished updating contract state. This ensures that future code changes do not
            // break the Checks-Effects-Interactions pattern.
            private stateUpdater extCallerDenied {
            
        // Can't use allowance from the ERC777 API (sanity check)
        require(_erc777CallDepth == 0, "Can't use allowance");

        uint256 allowedAmount = _allowance[holder][/* spender = */ operator];
        
        // If unlimited allowance was previously enabled, and spender was granted an unlimited allowance,
        // and then later unlimited allowance was disabled, and the spender's allowance is still unlimited,
        // then the transfer should fail (the user's allowance needs to be set to a limited allowance
        // before transfers will succeed again).
        require(_unlimitedAllowancesEnabled || allowedAmount != UNLIMITED_ALLOWANCE,
                "Unlimited allowance disabled");
        
        // Fail transaction if allowance is insufficient
        require(amount <= allowedAmount, "Insufficient allowance");

        // Fail if allowance has expired
        uint256 expirationTimestamp = _allowanceExpirationTimestamp[holder][operator];
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= expirationTimestamp, "Allowance expired");
                
        // If allowance is not unlimited, reduce allowance by amount
        if (allowedAmount != UNLIMITED_ALLOWANCE) {
            // Decrease allowance by amount
            uint256 newAllowedAmount;
            unchecked { newAllowedAmount = allowedAmount - amount; }  // Save gas, checked above
            // Approve decreased allowance amount (this will update _allowance[holder][/* spender = */ operator]).
            // Will generate new allowance events.
            __setAllowance_noChecks_extCallerDenied(
                    holder, /* spender = */ operator, newAllowedAmount, expirationTimestamp);
        }
        
        // NO INTERACTIONS (modified with extCallerDenied)
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Core account state management functions.
    // Modified with `stateUpdater` so that these cannot be called reentrantly.

    /**
     * @dev Mint `amount` tokens into `account`.
     *
     * @param operator The address performing the mint.
     * @param account The address to mint tokens into.
     * @param amount The number of tokens to mint.
     * @param data Data generated by the user to be passed to the recipient.
     * @param operatorData Data generated by the operator to be passed to the recipient.
     */
    function _mint(address operator, address account, uint256 amount, 
            bytes memory data, bytes memory operatorData) internal stateUpdater {

        // CHECKS, EFFECTS, EVENTS:
        
        __mint_extCallerDenied(operator, account, amount, data, operatorData);

        // NOTIFY RECIPIENT [INTERACTIONS]:

        // Notify ER777 token recipient of mint from address(0), if called from ERC777 API.
        if (_erc777CallDepth > 0) {
            call_ERC777TokensRecipient_tokensReceived(
                    operator, /* sender = */ address(0), /* recipient = */ account, amount,
                    data, operatorData);
        }
        // Notify ERC4524 token recipient of mint from address(0), if called from ERC4524 API
        if (_erc4524CallDepth > 0) {
            call_ERC4524TokensRecipient_onERC20Received(
                    operator, /* sender = */ address(0), /* recipient = */ account, amount, data);
        }
        // Call ERC1363 recipient if called from ERC1363 API
        if (_erc1363CallDepth > 0) {
            call_ERC1363Receiver_onTransferReceived(
                    operator, /* sender = */ address(0), /* recipient = */ account, amount, data);
        }
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     *
     * @param operator The address performing the burn.
     * @param account The address to burn tokens from.
     * @param amount The number of tokens to burn.
     * @param data Data generated by the user to be passed to the recipient.
     * @param operatorData Data generated by the operator to be passed to the recipient.
     */
    function _burn(address operator, address account, uint256 amount,
            bytes memory data, bytes memory operatorData) internal stateUpdater {

        // PRECONDITIONS [CHECKS]:

        require(operator != address(0), "Bad operator");
        require(account != address(0), "Bad account");
        require(amount != 0, "Zero amount");

        // BURN [EFFECTS]:

        // Burn tokens and decrease total supply
        require(amount <= balanceOf[account], "Insufficient balance");
        unchecked { balanceOf[account] -= amount; }  // Save gas by using unchecked
        totalSupply -= amount;

        // EMIT EVENTS:

        if (_erc777CallDepth > 0) {
            // Emit ERC777 Burned event
            emit Burned(operator, account, amount, data, operatorData);
        } else {
            // Otherwise emit ERC20 event for the other token standards
            emit Transfer(/* sender = */ account, /* recipient = */ address(0), amount);
            // Emit ERC20 "safe approval" transfer event
            emit TransferInfo(operator, /* sender = */ account, /* recipient = */ address(0), amount);
        }

        // NOTIFY TOKEN BURNER [INTERACTIONS]
        
        // Notify token burner (`account`) of tokens sent to address(0), if account is an ERC777 contract.
        // The ERC777 spec says this must happen before the balance transfer. However, this violates the
        // Checks-Effects-Interactions pattern, and is unsafe. Therefore we break from the standard and
        // call the sender only after the state has been updated. Other ERC777 implementations have made
        // this same choice: https://github.com/OpenZeppelin/openzeppelin-contracts/issues/1749
        if (_erc777CallDepth > 0) {
            call_ERC777TokensSender_tokensToSend(
                    operator, /* sender = */ account, /* recipient = */ address(0), amount, data, operatorData);
        }
    }

    /**
     * @dev Transfer `amount` tokens from `holder` to `recipient`.
     *
     * @param operator The address performing the transfer.
     * @param holder The address holding the tokens being transferred.
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be transferred.
     * @param useAllowance If true, use the allowance system to determine whether the user can make
     *                     the transfer, and reduce the allowance by the amount of the transfer.
     * @param data Data generated by the user to be passed to the recipient.
     * @param operatorData Data generated by the operator to be passed to the recipient.
     */
    function _transfer(address operator, address holder, address recipient, uint256 amount, bool useAllowance,
            bytes memory data, bytes memory operatorData) internal stateUpdater {

        // PRECONDITIONS [CHECKS]:

        require(operator != address(0), "Bad operator");
        require(holder != address(0), "Bad holder");
        require(recipient != address(0), "Bad recipient");
        // Zero amount is valid for ERC20 transfers, for some reason (even though it's wasteful)

        // PERFORM TRANSFER [EFFECTS]:

        // If requested, check the operator has sufficient allowance to send the holder's tokens, and if so,
        // reduce the allowance by the requested amount.
        if (useAllowance && amount > 0) {
            // Spend (reduce) allowance. Will generate new allowance events, unless the allowance is unlimited.
            // Done before making the transfer, to ensure the allowance covers the transfer, but also, allowance
            // must be reduced before calling sender/recipient notification functions in external contracts
            // (see "[INTERACTIONS]" below), to respect the Checks-Effects-Interactions order.
            // This `spendAllowance` function is modified with `extCallerDenied` to prevent it calling functions
            // in other contracts, because `_transfer` has not yet finished updating contract state.
            __spendAllowance_extCallerDenied(operator, holder, amount);
        }

        // Transfer amount from holder to recipient
        require(amount <= balanceOf[holder], "Insufficient balance");
        unchecked { balanceOf[holder] -= amount; }  // Save gas by using unchecked
        balanceOf[recipient] += amount;

        // EMIT EVENTS:

        if (_erc777CallDepth > 0) {
            // Emit ERC777 Sent event
            emit Sent(operator, holder, recipient, amount, data, operatorData);
        } else {
            // Emit ERC20 transfer event
            emit Transfer(holder, recipient, amount);
            // Emit ERC20 "safe approval" transfer event
            emit TransferInfo(operator, holder, recipient, amount);
        }

        // NOTIFY SENDER/RECIPIENT [INTERACTIONS]:

        // Call ERC777 sender, if necessary.
        // The ERC777 spec says this must happen before the balance transfer. However, this violates the
        // Checks-Effects-Interactions pattern, and is unsafe. Therefore we break from the standard and
        // call the sender only after the state has been updated.
        // OpenZeppelin also considered breaking with the spec in the same way:
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/1749
        // however ultimately a decision was made to instead deprecate ERC777 in OpenZeppelin
        // (it is considered an overengineered standard anyway):
        // https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2620
        if (_erc777CallDepth > 0) {
            call_ERC777TokensSender_tokensToSend(operator, holder, recipient, amount, data, operatorData);
        }
        // Call ERC777 recipient if called from ERC777 API
        if (_erc777CallDepth > 0) {
            call_ERC777TokensRecipient_tokensReceived(operator, holder, recipient, amount, data, operatorData);
        }
        // Call ERC1363 recipient if called from ERC1363 API
        if (_erc1363CallDepth > 0) {
            call_ERC1363Receiver_onTransferReceived(operator, holder, recipient, amount, data);
        }
        // Call ERC4524 recipient if called from ERC4524 API
        if (_erc4524CallDepth > 0) {
            call_ERC4524TokensRecipient_onERC20Received(operator, holder, recipient, amount, data);
        }
    }

    /**
     * @dev Sets `allowedAmount` as the number of `holder`'s tokens that `spender` is allowed to transfer.
     *
     * @param holder The holder of the tokens.
     * @param spender The spender of the tokens.
     * @param allowedAmount The number of tokens to grant as an allowance.
     * @param expirationTimestamp The last valid block timestamp for the allowance.
     * @param data Data to be passed to the spender, if the approval is via ERC1363's `approveAndCall` function.
     */
    function _approve(address holder, address spender, uint256 allowedAmount, uint256 expirationTimestamp,
            bytes memory data) internal stateUpdater {
    
        // PRECONDITIONS [CHECKS]:
        
        require(holder != address(0), "Bad holder");
        require(spender != address(0), "Bad spender");
        require(_unlimitedAllowancesEnabled || allowedAmount != UNLIMITED_ALLOWANCE, "Unlimited allowance disabled");
        // ERC777 doesn't use the approval API (sanity check)
        require(_erc777CallDepth == 0, "Can't use allowance");
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= expirationTimestamp, "Allowance expired");

        // APPROVE [EFFECTS], AND EMIT EVENTS:

        // Set allowed amount. Will generate new allowance events.
        __setAllowance_noChecks_extCallerDenied(holder, spender, allowedAmount, expirationTimestamp);

        // NOTIFY SPENDER [INTERACTIONS]
        
        // Notify ERC1363 spender, if called from ERC1363 API
        if (_erc1363CallDepth > 0) {
            call_ERC1363Spender_onApprovalReceived(/* holder = */ msg.sender, spender, allowedAmount, data);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC20 allowance/approve/transfer/transferFrom API functions

    /**
     * @notice Get the number of tokens that `spender` can spend on behalf of `holder`.
     *
     * @dev [ERC20] Returns the remaining number of tokens that `spender` will be allowed to spend on
     * behalf of `holder`, via a call to `transferFrom`. Zero by default. Also returns zero if
     * allowance has expired.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The token holder.
     * @param spender The token spender.
     * @return amount The allowance of `spender` to spend the funds of `holder`.
     */
    function allowance(address holder, address spender) public view erc20 override(IERC20)
            returns (uint256 amount) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp <= _allowanceExpirationTimestamp[holder][spender]
                ? _allowance[holder][spender]
                : 0;  // Allowance has expired
    }

    /**
     * @notice Approve another account (or contract) to spend tokens on your behalf.
     *
     * @dev [ERC20] Approves a `spender` to be allowed to spend `amount` tokens on behalf of the
     * caller, via a call to `transferFrom`.
     *
     * Note that by default (unless the behavior was changed by the contract owner/deployer), the allowance
     * has to be set to zero before it can be set to a non-zero amount, to prevent the well-known ERC20 allowance
     * race condition that can allow double-spending of allowances. This is not fully ERC20-compatible, but it
     * is much safer.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The spender.
     * @param amount The allowance amount. Use a value of `0` to disallow `spender` spending tokens on behalf
     *          of the caller. Use a value of `2**256-1` to set unlimited allowance, if unlimited allowances are
     *          enabled. The allowed amount may be greater than the account balance.
     * @return success `true` if the approval succeeded (otherwise reverts).
     */
    function approve(address spender, uint256 amount) external erc20 override(IERC20)
            returns (bool success) {
        if (!_changingAllowanceWithoutZeroingEnabled && amount != 0) {
            // ERC20 safety: have to set allowance to zero (or let it expire) before it can be set to non-zero
            require(allowance(/* holder = */ msg.sender, spender) == 0, "Must set allowance to zero first");
        }
        _approve(/* holder = */ msg.sender, spender, amount, defaultAllowanceExpirationTime(), "");
        return true;
    }

    /**
     * @notice Transfer tokens to another account.
     *
     * @dev [ERC20] Moves `amount` tokens from the caller's account to `recipient`.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function transfer(address recipient, uint256 amount) external erc20 override(IERC20)
            returns (bool success) {
        // ERC20 tokens should almost never need to be sent to a smart contract -- tokens sent to a smart
        // contract are generally considered burned. Therefore, disallow transfer to smart contracts.
        // This is non-standard, but provides important protection to users against the most common mistake
        // in sending ERC20 tokens, which has caused millions of dollars in loss.
        // Instead, the user should use `approve` and `transferFrom`, or ERC777/ERC1363/ERC4524.
        require(_transferToContractsEnabled || !isContract(recipient), "Can't transfer to a contract");
        // Perform the transfer
        _transfer(/* operator = */ msg.sender, /* sender = */ msg.sender, recipient, amount,
                /* useAllowance = */ false, "", "");
        return true;
    }

    /**
     * @notice Transfer tokens from a holder account to a recipient account account, on behalf of the holder.
     *
     * @dev [ERC20] Moves `amount` tokens from `sender` to `recipient`. The caller must have previously been
     * approved by `sender` to send at least `amount` tokens on their behalf, by `sender` calling `approve`.
     * `amount` is deducted from the caller’s allowance (unless the allowance is set to unlimited).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     * 
     * @param holder The token holder.
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function transferFrom(address holder, address recipient, uint256 amount) external erc20 override(IERC20)
            returns (bool success) {
        // Don't allow transfer to contracts, as with `transfer` function
        require(_transferToContractsEnabled || !isContract(recipient), "Can't transfer to a contract");
        // Perform the transfer
        _transfer(/* operator = */ msg.sender, holder, recipient, amount, /* useAllowance = */ true, "", "");
        return true;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC20 extensions

    /**
     * @notice Safely increase the allowance for a spender to spend your tokens.
     *
     * @dev [ERC20 extension] Increases the ERC20 token allowance granted to `spender` by the caller.
     * This is an alternative to `approve` that can mitigate for the double-spend race condition attack
     * that is described here:
     *
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * N.B. the transaction will revert if the allowance is currently set to the unlimited allowance
     * amount of `2**256-1`, since the correct new allowance amount cannot be determined by addition.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The token spender.
     * @param amountToAdd The number of tokens by which to increase the allowance of `spender`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function increaseAllowance(address spender, uint256 amountToAdd)
            external erc20 override(IERC20IncreaseDecreaseAllowance) returns (bool success) {
        if (amountToAdd > 0) {
            uint256 allowedAmount = _allowance[/* holder = */ msg.sender][spender];
            // Don't increase an unlimited allowance
            require(allowedAmount != UNLIMITED_ALLOWANCE, "Unlimited allowance");
            // Don't increase an expired allowance
            // solhint-disable-next-line not-rely-on-time
            require(block.timestamp <= _allowanceExpirationTimestamp[/* holder = */ msg.sender][spender],
                    "Allowance expired");
            // Increase allowance
            _approve(/* holder = */ msg.sender, spender, allowedAmount + amountToAdd,
                    // Reset allowance expiration time every time allowance is increased
                    defaultAllowanceExpirationTime(), "");
        }
        return true;
    }

    /**
     * @notice Safely decrease the allowance for a spender to spend your tokens.
     *
     * @dev [ERC20 extension] Decreases the ERC20 token allowance granted to `spender` by the caller.
     * This is an alternative to `approve` that can mitigate for the double-spend race condition attack
     * that is described here:
     *
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * N.B. the transaction will revert if the allowance is currently set to the unlimited allowance
     * amount of `2**256-1`, since the correct new allowance amount cannot be determined by subtraction.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The token spender.
     * @param amountToSubtract The number of tokens by which to decrease the allowance of `spender`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     *         Note that this operation will revert if amountToSubtract is greater than the current allowance.
     */
    function decreaseAllowance(address spender, uint256 amountToSubtract)
            external erc20 override(IERC20IncreaseDecreaseAllowance) returns (bool success) {
        if (amountToSubtract > 0) {
            uint256 allowedAmount = _allowance[/* holder = */ msg.sender][spender];
            // Don't decrease an unlimited allowance
            require(allowedAmount != UNLIMITED_ALLOWANCE, "Unlimited allowance");
            // Can't decrease by more than the current allowance
            require(amountToSubtract <= allowedAmount, "Insufficient allowance");
            // Don't decrease an expired allowance
            // solhint-disable-next-line not-rely-on-time
            require(block.timestamp <= _allowanceExpirationTimestamp[/* holder = */ msg.sender][spender],
                    "Allowance expired");
            // Decrease allowance
            uint256 newAllowedAmount;
            unchecked { newAllowedAmount = allowedAmount - amountToSubtract; }  // Save gas with unchecked
            _approve(/* holder = */ msg.sender, spender, newAllowedAmount,
                    // Reset allowance expiration time every time allowance is decreased
                    defaultAllowanceExpirationTime(), "");
        }
        return true;
    }

    /**
     * @notice Safely change the allowance for a spender to spend your tokens.
     * 
     * @dev [ERC20 extension] Atomically compare-and-set the allowance for a spender.
     * This is designed to mitigate the ERC-20 allowance attack described in:
     *
     * "ERC20 API: An Attack Vector on Approve/TransferFrom Methods"
     * https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The spender.
     * @param expectedCurrentAmount The expected amount of `spender`'s current allowance.
     *        If the current allowance does not match this value, then the transaction will revert.
     * @param amount The new allowance amount.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function approve(address spender, uint256 expectedCurrentAmount, uint256 amount)
            external erc20 override(IERC20SafeApproval) returns (bool success) {
        require(_allowance[/* holder = */ msg.sender][spender] == expectedCurrentAmount, "Allowance mismatch");
        // Approve new allowance, with default expiration time.
        _approve(/* holder = */ msg.sender, spender, amount, defaultAllowanceExpirationTime(), "");
        return true;
    }

    /**
     * @notice Approve a spender to spend your tokens with a specified expiration time.
     *
     * @dev ERC20 extension function for approving with time-limited allowances.
     *
     * See: https://github.com/vrypan/EIPs/blob/master/EIPS/eip-draft_time_limited_token_allowances.md
     *
     * @dev Note that the block timestamp can be altered by miners up to about +/-15 seconds (as long as block
     * timestamps increase monotonically), so do not use an allowance expiration time of less than 15 seconds.
     *
     * Note that by default (unless the behavior was changed by the contract owner/deployer), the allowance
     * has to be set to zero before it can be set to a non-zero amount, to prevent the well-known ERC20 allowance
     * race condition that can allow double-spending of allowances. This is not fully ERC20-compatible (and
     * it is not the defined behavior of this ERC20 extension), but it is much safer than the ERC20 default.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The token spender.
     * @param amount The number of tokens to allow spender to spend on the caller's behalf.
     * @param expirationSec The number of seconds after which the allowance expires, or `2**256-1` if the
     *          allowance should not expire (consider this unsafe), or `0` if spending must happen in the
     *          same block as approval (e.g. for a flash loan).
     *          Note: The proposal for this ERC20 extension API requires a user to specify the number of
     *          blocks an approval should be valid for before expiration. OmniToken uses seconds instead
     *          of number of blocks, because mining does not happen at a reliable interval.
     * @return success `true` if approval was successful.
     */
    function approveWithExpiration(address spender, uint256 amount, uint256 expirationSec)
            external erc20 override(IERC20TimeLimitedTokenAllowances) returns (bool success) {
        if (!_changingAllowanceWithoutZeroingEnabled && amount != 0) {
            // Have to set allowance to zero (or let it expire) before it can be set to non-zero
            require(allowance(/* holder = */ msg.sender, spender) == 0, "Must set allowance to zero first");
        }
        _approve(/* holder = */ msg.sender, spender, amount,
                expirationSec == UNLIMITED_EXPIRATION ? expirationSec
                        // solhint-disable-next-line not-rely-on-time
                        : block.timestamp + expirationSec, "");
        return true;
    }
    
    /**
     * @notice Get the expiration timestamp for the allowance of a spender to spend tokens on behalf of a holder.
     * 
     * @dev ERC20 extension function for returning the allowance amount and block timestamp after which allowance
     * expires. Expiration time will be `2**256-1` for allowances that do not expire, or smaller than that value
     * for time-limited allowances.
     *
     * See: https://github.com/vrypan/EIPs/blob/master/EIPS/eip-draft_time_limited_token_allowance.md
     *
     * @param holder The token holder.
     * @param spender The token spender.
     * @return remainingAmount The amount of the allowance remaining, or 0 if the allowance has expired.
     * @return expirationTimestamp The block timestamp after which the allowance expires.
     */
    function allowanceWithExpiration(address holder, address spender)
            external view erc20 override(IERC20TimeLimitedTokenAllowances)
            returns (uint256 remainingAmount, uint256 expirationTimestamp) {
        remainingAmount = allowance(holder, spender);
        expirationTimestamp = _allowanceExpirationTimestamp[holder][spender];
    }

    /**
     * @notice Burn tokens.
     *
     * @dev [ERC20 extension] Burn tokens. Destroys `amount` tokens from caller's account forever,
     * reducing the total supply. Use with caution, as this cannot be reverted, and you should ensure
     * that some other smart contract guarantees you some benefit for burning tokens before you burn
     * them.
     *
     * By convention, burning is logged as a transfer to the zero address.
     *
     * @param amount The amount to burn.
     */
    function burn(uint256 amount) external erc20 override(IERC20Burn) {
        _burn(/* operator = */ msg.sender, /* account = */ msg.sender, amount, "", "");
    }

    // -----------------------------------------------------------------------------------------------------------------
    // ERC777 functions

    /**
     * @notice Authorize another address, `operator`, to be able to send your tokens.
     *
     * @dev [ERC777] Authorize `operator` to be able to send the caller's tokens. The operator can then call
     * `operatorSend` to transfer the caller's tokens to a recipient.
     *
     * @param operator The operator to authorize.
     */
    function authorizeOperator(address operator) external erc777 override(IERC777) {
        require(operator != msg.sender, "Can't authorize self");
        if (isDefaultOperator[operator]) {
            isRevokedDefaultOperatorFor[operator][msg.sender] = false;
        } else {
            isAuthorizedOperatorFor[operator][msg.sender] = true;
        }
        emit AuthorizedOperator(operator, msg.sender);
    }

    /**
     * @notice Revoke `operator` from being able to send your tokens.
     *
     * @dev [ERC777] Revoke `operator` from being able to send the caller's tokens.
     *
     * @param operator The operator to revoke.
     */
    function revokeOperator(address operator) external erc777 override(IERC777) {
        require(operator != msg.sender, "Can't revoke self");
        if (isDefaultOperator[operator]) {
            isRevokedDefaultOperatorFor[operator][msg.sender] = true;
        } else {
            isAuthorizedOperatorFor[operator][msg.sender] = false;
        }
        emit RevokedOperator(operator, msg.sender);
    }

    /**
     * @notice Check whether an operator is authorized to manage the tokens held by a given address.
     *
     * @dev [ERC777] Checking whether `operator` is authorized to manage the tokens held by
     * `holder` address. Returns `true` if `operator` is a non-revoked default operator, or has
     * been previously authorized (and not later revoked) by `holder` calling `authorizeOperator(operator)`.
     *
     * @param operator address to check if it has the right to manage the tokens.
     * @param holder address which holds the tokens to be managed.
     * @return isOperatorForHolder `true` if `operator` is authorized for `holder`.
     */
    function isOperatorFor(address operator, address holder) public view erc777View override(IERC777)
            returns (bool isOperatorForHolder) {
        return operator == holder || isAuthorizedOperatorFor[operator][holder]
            || (isDefaultOperator[operator] && !isRevokedDefaultOperatorFor[operator][holder]);
    }

    /**
     * @notice Send tokens to a recipient.
     *
     * @dev [ERC777] Send `amount` tokens to `recipient`, passing `data` to the recipient. `recipient` must
     * implement the ERC777 recipient interface, unless it is a non-contract account (EOA wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     */
    function send(address recipient, uint256 amount, bytes calldata data) external erc777 override(IERC777) {
        // Safety is guaranteed by the erc777 function modifier, which sets _erc777CallDepth,
        // which requires _transfer to successfully notify the ERC777 recipient
        _transfer(/* operator = */ msg.sender, /* holder = */ msg.sender, recipient, amount,
                  /* useAllowance = */ false, data, "");
    }

    /**
     * @notice Send tokens on behalf of a token holder that you have previously been authorized to be
     * an operator for.
     *
     * @dev [ERC777] Send `amount` tokens on behalf of the address `holder` to the address `recipient`.
     * The caller must have previously been authorized for as an operator for `sender`, by `sender`
     * calling `authorizeOperator`.
     *
     * The `holder` account may optionally implement the ERC777 sender interface to be notified when
     * tokens are sent.
     * 
     * `recipient` must implement the ERC777 recipient interface, unless it is a non-contract
     * account (EOA wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jursidiction
     * of the holder or recipient account.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The address holding the tokens being sent.
     * @param recipient The address of the recipient.
     * @param amount The number of tokens to be sent.
     * @param data Data generated by the user to be sent to the recipient.
     * @param operatorData Data generated by the operator to be sent to the recipient.
     */
    function operatorSend(address holder, address recipient, uint256 amount, bytes calldata data,
            bytes calldata operatorData) external erc777 override(IERC777) {
        // Ensure `msg.sender` is operator for `holder`
        require(isOperatorFor(msg.sender, holder), "Not operator");
        // Safety is guaranteed by the erc777 function modifier, which sets _erc777CallDepth,
        // which requires _transfer to successfully notify the ERC777 recipient
        _transfer(/* operator = */  msg.sender, holder, recipient, amount,
                  /* useAllowance = */ false, data, operatorData);
    }

    /**
     * @notice Burn tokens.
     *
     * @dev [ERC777] Burn tokens. Destroys `amount` tokens from caller's account forever,
     * reducing the total supply.
     *
     * Use with caution, as this cannot be reverted, and you should ensure that some other contract
     * guarantees you some benefit for burning tokens before you burn them.
     *
     * @param amount The number of tokens to burn.
     * @param data Extra data to log.
     */
    function burn(uint256 amount, bytes calldata data) external erc777 override(IERC777) {
        // Burn tokens
        _burn(/* operator = */ msg.sender, /* account = */ msg.sender, amount, data, "");
    }

    /**
     * @notice Burn tokens.
     *
     * @dev [ERC777] Burn tokens. Destroys `amount` tokens from `holder` account forever, reducing the total supply.
     * Caller must have previously been approved as an operator for `holder`.
     *
     * Use with caution, as this cannot be reverted, and you should ensure that some other contract guarantees
     * you some benefit for burning tokens before you burn them.
     *
     * @param holder The account to destroy tokens from.
     * @param amount The number of tokens to burn.
     * @param data Extra data to log.
     * @param operatorData Extra data to log.
     */
    function operatorBurn(address holder, uint256 amount, bytes calldata data, bytes calldata operatorData)
            external erc777 override(IERC777) {
        // Ensure `sender` is operator for `holder`
        require(isOperatorFor(msg.sender, holder), "Not operator");
        // Burn tokens
        _burn(/* operator = */ msg.sender, /* account = */ holder, amount, data, operatorData);
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // ERC1363 functions
    
    /**
     * @notice Transfer tokens to a recipient, and then call the ERC1363 recipient notification interface
     * on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from the caller to `recipient`, and then call the ERC1363 receiver
     * interface's `onTransferReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @return success `true` unless the transaction is reverted.
     */
    function transferAndCall(address recipient, uint256 amount)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _transfer to successfully notify the ERC1363 recipient
        _transfer(/* operator = */ msg.sender, /* holder = */ msg.sender, recipient, amount,
                  /* useAllowance = */ false, "", "");
        return true;
    }

    /**
     * @notice Transfer tokens to a recipient, and then call the ERC1363 recipient notification interface
     * on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from the caller to `recipient`, and then call the ERC1363 receiver
     * interface's `onTransferReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `recipient`.
     * @return success `true` unless the transaction is reverted.
     */
    function transferAndCall(address recipient, uint256 amount, bytes memory data)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _transfer to successfully notify the ERC1363 recipient
        _transfer(/* operator = */ msg.sender, /* holder = */ msg.sender, recipient, amount,
                  /* useAllowance = */ false, data, "");
        return true;
    }

    /**
     * @notice Transfer tokens to a recipient on behalf of another account, and then call the ERC1363
     * recipient notification interface on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from `holder` to `recipient`, and then call the ERC1363 spender
     * interface's `onApprovalReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The address which you want to send tokens on behalf of.
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @return success `true` unless the transaction is reverted.
     */
    function transferFromAndCall(address holder, address recipient, uint256 amount)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _transfer to successfully notify the ERC1363 recipient
        _transfer(/* operator = */ msg.sender, holder, recipient, amount, /* useAllowance = */ true, "", "");
        return true;
    }


    /**
     * @notice Transfer tokens to a recipient on behalf of another account, and then call the ERC1363
     * recipient notification interface on the recipient.
     *
     * @dev [ERC1363] Transfer tokens from `holder` to `recipient`, and then call the ERC1363 spender
     * interface's `onApprovalReceived` on the recipient. The transaction will fail if the recipient does
     * not implement this interface (including if the recipient address is an EOA address).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The address which you want to send tokens from.
     * @param recipient The address which you want to transfer tokens to.
     * @param amount The number of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `recipient`.
     * @return success `true` unless the transaction is reverted.
     */
    function transferFromAndCall(address holder, address recipient, uint256 amount, bytes memory data)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _transfer to successfully notify the ERC1363 recipient
        _transfer(/* operator = */ msg.sender, holder, recipient, amount, /* useAllowance = */ true, data, "");
        return true;
    }

    /**
     * @notice Approve another account to spend your tokens, and then call the ERC1363 spender notification
     * interface on the spender.
     *
     * @dev [ERC1363] Approve `spender` to spend the specified number of tokens on behalf of
     * caller (the token holder), and then call `onApprovalReceived` on spender.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the spender or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The address which will spend the funds.
     * @param amount The number of tokens to allow the spender to spend.
     * @return success `true` unless the transaction is reverted.
     */
    function approveAndCall(address spender, uint256 amount)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _approve to successfully notify the ERC1363 spender
        _approve(/* holder = */ msg.sender, spender, amount, defaultAllowanceExpirationTime(), "");
        return true;
    }

    /**
     * @notice Approve another account to spend your tokens, and then call the ERC1363 spender notification
     * interface on the spender.
     *
     * @dev [ERC1363] Approve `spender` to spend the specified number of tokens on behalf of
     * caller (the token holder), and then call `onApprovalReceived` on spender.
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the spender or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param spender The address which will spend the funds.
     * @param amount The number of tokens to be allow the spender to spend.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return success `true` unless the transaction is reverted.
     */
    function approveAndCall(address spender, uint256 amount, bytes memory data)
            external erc1363 override(IERC1363) returns (bool success) {
        // Safety is guaranteed by the erc1363 function modifier, which sets _erc1363CallDepth,
        // which requires _approve to successfully notify the ERC1363 spender
        _approve(/* holder = */ msg.sender, spender, amount, defaultAllowanceExpirationTime(), data);
        return true;
    }
       
    // -----------------------------------------------------------------------------------------------------------------
    // ERC4524 functions

    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from the caller's account to `recipient`. Only succeeds if `recipient`
     * correctly implements the ERC4524 receiver interface, or if the receiver is an EOA (non-contract wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransfer(address recipient, uint256 amount)
            external erc4524 override(IERC4524) returns(bool success) {
        // Safety is guaranteed by the erc4524 function modifier, which sets _erc4524CallDepth,
        // which requires _transfer to successfully notify the ERC4524 recipient
        _transfer(/* operator = */ msg.sender, /* holder = */ msg.sender, recipient, amount,
                  /* useAllowance = */ false, "", "");
        return true;
    }
    
    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from the caller's account to `recipient`. Only succeeds if `recipient`
     * correctly implements the ERC4524 receiver interface, or if the receiver is an EOA (non-contract wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @param data Extra data to add to the emmitted transfer event.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransfer(address recipient, uint256 amount, bytes memory data)
            external erc4524 override(IERC4524) returns(bool success) {
        // Safety is guaranteed by the erc4524 function modifier, which sets _erc4524CallDepth,
        // which requires _transfer to successfully notify the ERC4524 recipient
        _transfer(/* operator = */ msg.sender, /* holder = */ msg.sender, recipient, amount,
                  /* useAllowance = */ false, data, "");
        return true;
    }
    
    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from `holder` to `recipient`. (The caller must have
     * previously been approved by `holder` to send at least `amount` tokens on behalf of `holder`, by
     * `holder` calling `approve`.) `amount` is then deducted from the caller’s allowance.
     * Only succeeds if `recipient` correctly implements the ERC4524 receiver interface,
     * or if `recipient` is an EOA (non-contract wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     * 
     * @param holder The token holder.
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransferFrom(address holder, address recipient, uint256 amount)
            external erc4524 override(IERC4524) returns(bool success) {
        // Safety is guaranteed by the erc4524 function modifier, which sets _erc4524CallDepth,
        // which requires _transfer to successfully notify the ERC4524 recipient
        _transfer(/* operator = */ msg.sender, holder, recipient, amount, /* useAllowance = */ true, "", "");
        return true;
    }
    
    /**
     * @notice Transfer funds and then notify the recipient via the ERC4524 receiver interface.
     *
     * @dev [ERC4524] Move `amount` tokens from `holder` to `recipient`. (The caller must have
     * previously been approved by `holder` to send at least `amount` tokens on behalf of `holder`, by
     * `holder` calling `approve`.) `amount` is then deducted from the caller’s allowance.
     * Only succeeds if `recipient` correctly implements the ERC4524 receiver interface,
     * or if `recipient` is an EOA (non-contract wallet).
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or recipient.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     * 
     * @param holder The token holder.
     * @param recipient The token recipient.
     * @param amount The number of tokens to transfer from the caller to `recipient`.
     * @param data Extra data to add to the emmitted transfer event.
     * @return success `true` if the operation succeeded (otherwise reverts).
     */
    function safeTransferFrom(address holder, address recipient, uint256 amount, bytes memory data)
            external erc4524 override(IERC4524) returns(bool success) {
        // Safety is guaranteed by the erc4524 function modifier, which sets _erc4524CallDepth,
        // which requires _transfer to successfully notify the ERC4524 recipient
        _transfer(/* operator = */ msg.sender, holder, recipient, amount, /* useAllowance = */ true, data, "");
        return false;
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Permitting

    /**
     * @notice Convert a signed certificate into a permit or allowance for a spender account to spend tokens
     * on behalf of a holder account.
     *
     * @dev [EIP2612] Implements the EIP2612 permit standard. Sets the spendable allowance for `spender` to
     * spend `holder`'s tokens, which can then be transferred using the ERC20 `transferFrom` function.
     *
     * https://eips.ethereum.org/EIPS/eip-2612
     * https://github.com/Uniswap/v2-core/blob/master/contracts/UniswapV2ERC20.sol
     *
     * @notice By calling this function, you confirm that this token is not considered an unregistered or
     * illegal security, and that this smart contract is not considered an unregistered or illegal exchange,
     * by the laws of any legal jurisdiction in which you hold or use tokens, or any legal jurisdiction
     * of the holder or spender.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is
     * a taxable event. It is your responsibility to record the purchase price and sale price in ETH or
     * your local currency for each use, transfer, or sale of tokens you own, and to pay the taxes due.
     *
     * @param holder The token holder that signed the certificate.
     * @param spender The spender who will be authorized to spend tokens on behalf of `holder`.
     * @param amount The number of tokens `spender` will be authorized to spend on behalf of `holder`.
     * @param deadline The block timestamp after which the certificate expires.
     *          Note that if the permit is granted, then the allowance that is approved has its own deadline,
     *          separate from the certificate deadline. By default, allowances expire 1 hour after they are
     *          granted, but this may be modified by the contract owner -- call `defaultAllowanceExpirationSec()`
     *          to get the current value.
     * @param v The ECDSA certificate `v` value.
     * @param r The ECDSA certificate `r` value.
     * @param s The ECDSA certificate `s` value.
     */
    function permit(address holder, address spender, uint256 amount, uint256 deadline,
            uint8 v, bytes32 r, bytes32 s) external eip2612 override(IEIP2612) {
            
        // Get and update nonce
        uint256 nonce = nonces[holder]++;
        
        // Check whether permit is valid (reverts if not)
        checkPermit(deadline,
                keccak256(abi.encode(
                    // keccak256("Permit(address holder,address spender,uint256 value,uint256 nonce,uint256 deadline)")
                    0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9,
                    holder, spender, amount, nonce, deadline)),
                v, r, s, /* requiredSigner = */ holder);
                
        // Approve amount allowed in the permit
        _approve(holder, spender, amount,
                // Use the default allowance expiration time
                defaultAllowanceExpirationTime(), "");
    }
}

