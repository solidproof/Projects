// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

// File: contracts\Bridge.sol

contract Bridge is Initializable, PausableUpgradeable {
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
        require(amount <= totalLocked, "Not enough tokens on the bridge");
        require(
            signaturesValid(signatures, _id),
            "Signature Verification Failed"
        );
        userClaimable[user] += amount;
        totalLocked -= amount;
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
            amount <= ERC20Interface.balanceOf(address(this)),
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