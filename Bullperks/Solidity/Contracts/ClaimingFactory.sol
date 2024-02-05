// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract ClaimingFactory is Initializable, ContextUpgradeable, OwnableUpgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using StringsUpgradeable for uint16;
    using StringsUpgradeable for uint256;

    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    struct DistributorSettings {
        bytes32 claimingWalletsMerkleRoot; // Root Merkle Tree: WalletAddress|Balance
        uint256 unlocksNumber; // UnlocksNumber = 2
        uint256 lastRootUpdate;
        bool paused;
    }

    struct UnlockPeriod {
        uint256 vestingStartDate; // Unix timestamp (example: 1664661600)
        uint256 tokensPercentage; // Examples: 300 equals to 3% | 215 equals to 2.15%
        uint256 cliffEndDate; // Unix timestamp (example: 1664661600)
    }

    struct Claim {
        uint256 totalClaimed;
    }

    struct Wallet {
        bool isGraylisted;
        uint256 lastWalletUpdate;
    }

    mapping(address => DistributorSettings) distributors; // distributors[distributor]
    mapping(address => mapping(uint256 => UnlockPeriod)) unlocks; // unlocks[distributor][period]
    mapping(address => mapping(address => Claim)) claims; // claims[wallet][distributor]
    //mapping(address => mapping(address => uint256)) lastWalletUpdate; // lastWalletUpdate[wallet][distributor] = timestamp
    mapping(address => mapping(address => Wallet)) wallets; // wallets[wallet][distributor];

    event TokenSettingsChanged(address indexed _distributorAddress);
    event UnlockPeriodChanged(address indexed _distributorAddress, uint256 indexed _periodIndex, uint256 _vestingStartDate, uint256 _tokensPercentage, uint256 _cliffEndDate);
    event Claimed(address indexed _distributorAddress, address indexed sender, uint256 _amount);
    event TokensWithdrawn(address indexed _distributorAddress, uint256 _amount);
    event MerkleRootUpdated(address indexed _distributorAddress, bytes32 _merkleRoot);
    event DistributionPaused(address indexed _distributorAddress, bool _paused);
    event WalletUpdated(address indexed _distributorAddress, address indexed _existingWallet, address indexed _newWallet);

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(LOCKER_ROLE, _msgSender());
    }

   function setRoot(address _distributorAddress, bytes32 _merkleRoot) public onlyRole(LOCKER_ROLE) {
        _setRoot(_distributorAddress, _merkleRoot);
   }

   function setPause(address _distributorAddress, bool _paused) public onlyRole(LOCKER_ROLE) {
        distributors[_distributorAddress].paused = _paused;
        emit DistributionPaused(_distributorAddress, _paused);
   }

   function withdrawTokens(address _distributorAddress, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _transfer(_distributorAddress, amount);
        emit TokensWithdrawn(_distributorAddress, amount);
   }

    function lock(
        address _distributorAddress,
        bytes32 _merkleRoot,
        UnlockPeriod[] calldata _periods) public onlyRole(LOCKER_ROLE) {

        _setRoot(_distributorAddress, _merkleRoot);
        _setUnlockPeriods(_distributorAddress, _periods);
    }

    function updateWallet(
        address _distributorAddress,
        uint256 _totalAllocation,
        address _newWallet,
        bytes32[] calldata _merkleProof
    ) public nonReentrant {
        require(!distributors[_distributorAddress].paused, "distribution paused");
        require(distributors[_distributorAddress].lastRootUpdate > wallets[_msgSender()][_distributorAddress].lastWalletUpdate, "wallet already updated");

        _validateProof(_totalAllocation, distributors[_distributorAddress].claimingWalletsMerkleRoot, _merkleProof);

        wallets[_msgSender()][_distributorAddress].isGraylisted = true;
        wallets[_msgSender()][_distributorAddress].lastWalletUpdate = block.timestamp;
        wallets[_newWallet][_distributorAddress].isGraylisted = false;
        wallets[_newWallet][_distributorAddress].lastWalletUpdate = block.timestamp;

        claims[_newWallet][_distributorAddress].totalClaimed = claims[_msgSender()][_distributorAddress].totalClaimed;

        emit WalletUpdated(_distributorAddress, _msgSender(), _newWallet);
    }

    function claim(
        address _distributorAddress,
        uint256 _totalAllocation,
        bytes32[] calldata _merkleProof) public nonReentrant {

        require(!distributors[_distributorAddress].paused, "distribution paused");

        require(!wallets[_msgSender()][_distributorAddress].isGraylisted, "wallet greylisted");

        if(distributors[_distributorAddress].lastRootUpdate > wallets[_msgSender()][_distributorAddress].lastWalletUpdate)
        {
            _validateProof(_totalAllocation, distributors[_distributorAddress].claimingWalletsMerkleRoot, _merkleProof);
        }

        uint256 totalToClaim = _getAvailableTokens(_distributorAddress, _totalAllocation);

        require(totalToClaim > 0, "nothing to claim");

        _transfer(_distributorAddress, totalToClaim);

        claims[_msgSender()][_distributorAddress].totalClaimed += totalToClaim;

        emit Claimed(_distributorAddress, _msgSender(), totalToClaim);
    }

    function getAvailableTokens(
        address _distributorAddress,
        uint256 _totalAllocation
    ) public view returns (uint256) {
        return _getAvailableTokens(_distributorAddress, _totalAllocation);
    }

    // --------------------------------------------------------------------------------
    // Internal functions
    // --------------------------------------------------------------------------------

   function _setRoot(
       address _distributorAddress,
       bytes32 _merkleRoot
    ) internal {
        distributors[_distributorAddress].claimingWalletsMerkleRoot = _merkleRoot;
        distributors[_distributorAddress].lastRootUpdate = block.timestamp;
        emit MerkleRootUpdated(_distributorAddress, _merkleRoot);
   }

    function _calculatePercentage(
        uint256 _amount,
        uint256 _percentage
    ) internal pure returns (uint256) {
        return (_amount * _percentage / 10000);
    }

    function _validateProof(
        uint256 _totalAllocation,
        bytes32 _merkleRoot,
        bytes32[] calldata _merkleProof
    ) internal view
    {
        bytes32 leaf = keccak256(abi.encode(_msgSender(), _totalAllocation));
        require(MerkleProofUpgradeable.verify(_merkleProof, _merkleRoot, leaf), "invalid proof");
    }

    function _transfer(
        address _distributorAddress,
        uint256 _amount
    ) internal
    {
        IERC20Upgradeable _token = IERC20Upgradeable(_distributorAddress);
        require(_token.balanceOf(address(this)) >= _amount, "insufficient balance");
        _token.transfer(_msgSender(), _amount);
    }

    function _getAvailableTokens(
        address _distributorAddress,
        uint256 _totalAllocation
    ) internal view returns (uint256)  {
        uint256 availableAmount = 0;
        uint256 unlocksNumber = distributors[_distributorAddress].unlocksNumber;
        uint256 totalClaimed = claims[_msgSender()][_distributorAddress].totalClaimed;

        for (uint256 _periodIndex = 0; _periodIndex <= unlocksNumber; _periodIndex++)
        {
            UnlockPeriod memory _unlockPeriod = unlocks[_distributorAddress][_periodIndex];

            if(block.timestamp >= _unlockPeriod.vestingStartDate)
            {
                if (_unlockPeriod.cliffEndDate > 0 && (block.timestamp < _unlockPeriod.cliffEndDate))
                {
                    continue;
                }

                availableAmount += _calculatePercentage(_totalAllocation, _unlockPeriod.tokensPercentage);
            }
        }

        return availableAmount - totalClaimed;
    }

    function _setUnlockPeriods(
        address _distributorAddress,
        UnlockPeriod[] calldata _periods) internal {
        distributors[_distributorAddress].unlocksNumber = _periods.length;

        for(uint _periodIndex = 0; _periodIndex <= _periods.length-1; _periodIndex++){

            unlocks[_distributorAddress][_periodIndex].vestingStartDate = _periods[_periodIndex].vestingStartDate;
            unlocks[_distributorAddress][_periodIndex].tokensPercentage = _periods[_periodIndex].tokensPercentage;
            unlocks[_distributorAddress][_periodIndex].cliffEndDate = _periods[_periodIndex].cliffEndDate;

            emit UnlockPeriodChanged(
                _distributorAddress,
                _periodIndex,
                _periods[_periodIndex].vestingStartDate,
                _periods[_periodIndex].tokensPercentage,
                _periods[_periodIndex].cliffEndDate);
        }
    }
}