// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function mint(address user, uint256 amount) external returns (bool);
}

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data)
        private
    {
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

contract Bridge_ETH is Initializable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public admin;
    address public owner;
    address[] public signers;
    uint256 public totalLocked;
    IERC20Upgradeable public ERC20Interface;
    uint256 public minSignsRequired;
    uint256 public feeDenom;
    bool public taxEnabled;
    uint256 public taxPercent;

    mapping(address => bool) public signerKey;
    mapping(address => uint256) public position;
    mapping(address => uint256) public userNonce;
    mapping(address => uint256) public userClaimable;
    mapping(address => bool) public isTaxless;

    event Lock(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        bytes32 indexed Id
    );
    event Unlock(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        bytes32 indexed Id
    );
    event OwnerChanged(
        address previousOwner,
        address newOwner,
        uint256 timestamp
    );

    event SignerAdded(address signer, uint256 timestamp);

    event SignerStatusChanged(address signer, bool value, uint256 timestamp);

    event MinimumSignsChanged(
        uint256 oldValue,
        uint256 newValue,
        uint256 timestamp
    );

    event TaxStatusChanged(bool value, uint256 timestamp);

    event AdminChanged(address prevValue, address newValue, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}

    /**
     * @dev External function to initialize the contract.
     */
    function initialize(
        address _token,
        address _owner,
        address[] memory _signers,
        uint256 _minSignRequired,
        address _admin,
        bool _taxEnabled,
        uint256 _taxPercent
    ) external initializer {
        require(_token != address(0), "Zero token address");
        require(_admin != address(0), "Zero admin address");
        require(_owner != address(0), "Zero owner address");
        require(_signers.length >= 1, "Zero signers");
        __Pausable_init_unchained();
        ERC20Interface = IERC20Upgradeable(_token);
        owner = _owner;
        admin = _admin;
        for (uint256 i; i < _signers.length; i++) {
            _addSigner(_signers[i]);
        }
        require(
            _minSignRequired > 0 && _minSignRequired <= _signers.length,
            "Invalid min signs required"
        );
        minSignsRequired = _minSignRequired;
        feeDenom = 10000;
        taxEnabled = _taxEnabled;
        require(_taxPercent <= feeDenom, "Tax too high");
        taxPercent = _taxPercent;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not the admin");
        _;
    }

    /**
     * @dev External function to change the admin of the contract by admin.
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        address prevAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(prevAdmin, newAdmin, block.timestamp);
    }

    /**
     * @dev External function to change the owner of the contract by admin.
     */
    function changeOwner(address newOwner) external onlyAdmin {
        address prevOwner = owner;
        owner = newOwner;
        emit OwnerChanged(prevOwner, owner, block.timestamp);
    }

    /**
     * @dev External function to change the signing status of a particular signer by admin.
     */
    function changeSignerStatus(address _signer, bool status)
        external
        onlyAdmin
    {
        require(position[_signer] > 0, "Signer not found");
        signerKey[_signer] = status;
        emit SignerStatusChanged(_signer, status, block.timestamp);
    }

    /**
     * @dev External function to pause the contract by admin.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @dev External function to unpause the contract by admin.
     */
    function unPause() external onlyAdmin {
        _unpause();
    }

    /**
     * @dev External function to add new signer to the contract by admin.
     */
    function addSigner(address _signer) public onlyAdmin {
        _addSigner(_signer);
    }

    function _addSigner(address _signer) internal {
        require(_signer != address(0), "Zero signer address");
        require(position[_signer] == 0, "Already added");
        signers.push(_signer);
        position[_signer] = signers.length;
        signerKey[_signer] = true;
        emit SignerAdded(_signer, block.timestamp);
    }

    /**
     * @dev External function to change no of min signs required to unlock, by admin.
     */
    function changeMinSignsRequired(uint256 _minSignRequired)
        external
        onlyAdmin
    {
        require(
            _minSignRequired > 0 && _minSignRequired <= signers.length,
            "Invalid min signs required"
        );
        uint256 prevValue = minSignsRequired;
        minSignsRequired = _minSignRequired;
        emit MinimumSignsChanged(prevValue, _minSignRequired, block.timestamp);
    }

    /**
     * @dev External function to enable/disable tax on a particular address by admin.
     */
    function addTaxless(address user, bool value) external onlyAdmin {
        isTaxless[user] = value;
    }

    /**
     * @dev External function to enable/disable tax on the `lock` call.
     */
    function changeTaxStatus(bool value) external onlyAdmin {
        taxEnabled = value;
        emit TaxStatusChanged(value, block.timestamp);
    }

    /**
     * @dev External function to change tax percent on `lock` call.
     */
    function changeTaxPercent(uint256 value) external onlyAdmin {
        require(value <= feeDenom, "Tax too high");
        taxPercent = value;
    }

    /**
     * @dev External function to lock the tokens on bridge(when the contract is not paused).
     */
    function lock(uint256 amount) external whenNotPaused returns (bool) {
        require(amount > 0, "Zero amount");
        if (taxEnabled && !isTaxless[msg.sender]) {
            uint256 finalAmount = (amount * (feeDenom - taxPercent)) / feeDenom;
            uint256 taxAmount = amount - finalAmount;
            if (taxAmount > 0)
                ERC20Interface.safeTransferFrom(msg.sender, admin, taxAmount);
            amount = finalAmount;
        }

        totalLocked += amount;
        userNonce[msg.sender]++;
        ERC20Interface.safeTransferFrom(msg.sender, address(this), amount);
        emit Lock(
            msg.sender,
            amount,
            block.timestamp,
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    amount,
                    block.timestamp,
                    userNonce[msg.sender]
                )
            )
        );
        return true;
    }

    /**
     * @dev External function to unlock the tokens on bridge(when the contract is not paused).
     */
    function unlock(
        address user,
        uint256 amount,
        bytes32 _id,
        bytes[] memory signatures
    ) external whenNotPaused returns (bool) {
        require(msg.sender == owner, "Not the owner");

        require(
            signaturesValid(signatures, _id),
            "Signature Verification Failed"
        );

        //Only mint tokens if amount is greater than totalLocked.
        if (amount <= totalLocked) {
            userClaimable[user] += amount;
            totalLocked -= amount;
        } else {
            ERC20Interface.mint(address(this), amount - totalLocked);
            userClaimable[user] += amount;
            totalLocked = 0;
        }

        emit Unlock(user, amount, block.timestamp, _id);
        return true;
    }

    /**
     * @dev External function to claim the user tokens.
     */
    function claimTokens() external returns (bool) {
        uint256 amount = userClaimable[msg.sender];
        require(amount > 0, "No tokens available for claiming");
        require(
            ERC20Interface.balanceOf(address(this)) >= amount,
            "Not enough tokens in the contract"
        );
        delete userClaimable[msg.sender];
        ERC20Interface.safeTransfer(msg.sender, amount);
        return true;
    }

    /**
     * @dev Public function to check if the min signs from the signers are present during `unlock`.
     */
    function signaturesValid(bytes[] memory signatures, bytes32 _id)
        public
        view
        returns (bool)
    {
        require(signatures.length > 0, "Zero signatures length");
        uint256 minSignsChecked;
        for (uint256 i; i < signatures.length; i++) {
            if (minSignsChecked == minSignsRequired) {
                break;
            } else {
                (address signer, ) = ECDSAUpgradeable.tryRecover(
                    (ECDSAUpgradeable.toEthSignedMessageHash(_id)),
                    signatures[i]
                );
                if (signerKey[signer]) minSignsChecked++;
            }
        }
        return (minSignsChecked == minSignsRequired) ? true : false;
    }
}