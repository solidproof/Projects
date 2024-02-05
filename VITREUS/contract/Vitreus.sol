// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC165Upgradeable, ERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {ContextUpgradeable, OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import {IERC721MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @title Vitreus Presale Voucher
 *
 * @notice Vitreus NFT Voucher which allows to mint VTRS after
 * Vitreus blockchain launch
 * @dev There could be only one voucher per wallet
 */
contract VitreusVoucher is
    Initializable,
    ContextUpgradeable,
    ERC165Upgradeable,
    IERC721MetadataUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using StringsUpgradeable for uint256;
    using StringsUpgradeable for uint48;
    using AddressUpgradeable for address;

    /**
     * @notice Deposit event
     * @dev Emitted when user deposits money to voucher (either new or existing)
     *
     * @param id the NFT token ID
     * @param round the number of presale round
     * @param amount the amount of deposited tokens in USDC
     */
    event Deposit(uint256 indexed id, uint256 round, uint256 amount);

    /**
     * @notice Presale Round Create event
     * @dev Emitted when owner specifies the new presale round during initialization.
     *
     * @param round the number of presale round
     * @param presaleRound the presale round info struct
     */
    event PresaleRoundCreated(uint256 indexed round, PresaleRound presaleRound);

    /**
     * @notice Presale Round Change event
     * @dev Emitted when owner changes the presale round
     *
     * @param round the number of presale round
     * @param presaleRound the updated presale round info struct
     */
    event PresaleRoundChanged(uint256 indexed round, PresaleRound presaleRound);

    /**
     * @notice Base URI change event
     * @dev Emitted when owner changes the base token URI
     *
     * @param baseURI updated token base URI
     */
    event BaseURIChanged(string baseURI);

    // The Uniswap pair for getting price
    address private _uniswapPair;

    // Uniswap Router address (for auto-swapping ETH to USDC if needed)
    IUniswapV2Router02 private _uniswapV2Router;

    // The target multi-sig USDC receiver address (for receiving the user deposit money)
    address private _usdcReceiver;

    // The USDC ERC20 token
    IERC20 private _usdc;

    // Uniswap swap path to convert from ETH to USDC
    address[] private _path;

    /// Presale Round struct
    struct PresaleRound {
        // price of the VTRS token in USDC
        uint32 price;
        // total allocation of this presale round in VTRS
        uint64 allocation;
        // minimum acceptable deposit in USDC
        uint64 minimumDeposit;
        // maximum acceptable deposit in USDC
        uint64 maximumDeposit;
        // total amount of deposits in USDC for this round
        uint64 totalDeposits;
        // first voucher token ID of this round
        uint32 startingId;
        // last voucher token ID of this round
        uint32 endingId;
        // start time of the presale round
        uint64 startTime;
        // end time of the presale round
        uint64 endTime;
    }

    // The whole list of presale rounds (current and future)
    PresaleRound[] private _rounds;

    // Deposit info as mapping tokenID => round => value in USDC
    mapping(uint256 => mapping(uint256 => uint)) private _deposits;

    // token ownership tokenID => owner address
    mapping(uint256 => address) private _ownedTokens;

    // token mapping owner address => tokenId
    mapping(address => uint256) private _tokenOwners;

    // token approval tokenId => spender address
    mapping(uint256 => address) private _tokenApprovals;

    // operator approvals owner => operator => approval flag
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // tokenId counter
    uint256 private _tokenIds;

    // base token metadata URI
    string private _baseURI;

    /**
     * @dev Contract initialization
     *
     * @param uniswapV2RouterAddress_ uniswap router address
     * @param usdcReceiver_ the target USDC receiver address
     * @param usdcAddress The target USDC wallet
     * @param uniswapPair_ The uniswap pairt address
     * @param baseTokenUri Base voucher token URI
     */
    function initialize(
        address uniswapV2RouterAddress_,
        address usdcReceiver_,
        address usdcAddress,
        address uniswapPair_,
        string calldata baseTokenUri
    ) external initializer {
        require(uniswapV2RouterAddress_ != address(0), "Zero Uniswap router");
        require(usdcReceiver_ != address(0), "Zero USDC receiver");
        require(uniswapPair_ != address(0), "Zero Uniswap pair");
        require(usdcAddress != address(0), "Zero Uniswap pair");

        __Ownable_init();
        __Pausable_init();
        __Context_init();
        __ReentrancyGuard_init();
        __DefaultOperatorFilterer_init();

        _uniswapV2Router = IUniswapV2Router02(uniswapV2RouterAddress_);
        _usdcReceiver = usdcReceiver_;
        _uniswapPair = uniswapPair_;
        _usdc = IERC20(usdcAddress);
        _path = new address[](2);
        (_path[0], _path[1]) = (_uniswapV2Router.WETH(), usdcAddress);

        _tokenIds = 1;
        _baseURI = baseTokenUri;
    }

    /**
     * @notice USDC receiver wouldn't be able to mint as it would be free
     */
    modifier onlyNotUSDCReceiver() {
        require(msg.sender != _usdcReceiver, "USDC receiever cannot mint");
        _;
    }

    /**
     * @dev receive function which will make minting or depositing
     * for the received amount of USDC
     */
    receive() external payable whenNotPaused onlyNotUSDCReceiver {
        require(msg.value != 0, "Value must not be zero");
        if (balanceOf(msg.sender) > 0) {
            _deposit(_tokenOwners[msg.sender], _swapETHForUSDC(msg.value));
        } else {
            _mint(msg.sender, _nextTokenId(), _swapETHForUSDC(msg.value));
        }
    }

    /**
     * @dev Mints the new voucher to the specified address automatically swapping ETH to USDC
     */
    function mint() external payable whenNotPaused onlyNotUSDCReceiver {
        require(msg.value != 0, "Value must not be zero");
        _mint(msg.sender, _nextTokenId(), _swapETHForUSDC(msg.value));
    }

    /**
     * @dev Deposits the sent amount to existing user voucher token
     */
    function deposit() external payable whenNotPaused onlyNotUSDCReceiver {
        require(msg.value != 0, "Value must not be zero");
        _deposit(_tokenOwners[msg.sender], _swapETHForUSDC(msg.value));
    }

    /**
     * @dev Mints the voucher with specified USDC amount to specified address
     * The owner should first approve the contract for spending USDC on behalf of the user
     *
     * @param to_ The user address for minting
     * @param value_ The amount of tokens in USDC
     */
    function mintWithUSDC(address to_, uint96 value_) external whenNotPaused onlyNotUSDCReceiver {
        require(value_ != 0, "Value must not be zero");
        _mint(to_, _nextTokenId(), value_);
        require(_usdc.transferFrom(msg.sender, _usdcReceiver, value_), "Transfer USDC failed");
    }

    /**
     * @dev Deposit specified USDC amount to existing user voucher
     * The owner should first approve the contract for spending USDC on behalf of the user
     *
     * @param amount_ The amount of tokens in USDC
     */
    function depositUSDC(uint256 amount_) external whenNotPaused onlyNotUSDCReceiver {
        require(amount_ != 0, "Value must not be zero");
        _deposit(_tokenOwners[msg.sender], amount_);
        require(_usdc.transferFrom(msg.sender, _usdcReceiver, amount_), "Transfer USDC failed");
    }

    /**
     * @notice Pauses the contract
     */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpauseContract() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Creates the presale round. Can only be run by the contract owner
     *
     * @param price_ The price of the VTRS token in USDC
     * @param allocation_ total allocation of this presale round in VTRS
     * @param depositMin_ minimum acceptable deposit in USDC
     * @param depositMax_ maximum acceptable deposit in USDC
     * @param startTime_ start time of the presale round
     * @param endTime_ end time of the presale round
     */
    function createPresaleRound(
        uint32 price_,
        uint56 allocation_,
        uint64 depositMin_,
        uint64 depositMax_,
        uint64 startTime_,
        uint64 endTime_
    ) external onlyOwner {
        _rounds.push(
            PresaleRound(price_, allocation_, depositMin_, depositMax_, 0, uint32(_tokenIds), 0, startTime_, endTime_)
        );
        emit PresaleRoundCreated(_rounds.length - 1, _rounds[_rounds.length - 1]);
    }

    /**
     * @dev Force mints the voucher with specified USDC amount to specified address
     * Can only be run by the contract owner
     *
     * @param to_ The user address for minting
     * @param value_ The amount of tokens in USDC
     */
    function forceMint(address to_, uint64 value_) external onlyOwner {
        uint256 nextToken = _nextTokenId();
        _deposit(nextToken, value_);
        _mint(to_, nextToken);
    }

    /**
     * @dev Changes the upcoming round allocation
     *
     * @param roundId_ the updated round number
     * @param newAllocation_ updated round allocation
     */
    function changeUpcomingRound(uint256 roundId_, uint56 newAllocation_) external onlyOwner {
        require(_currentPresaleRoundNumber() <= roundId_, "Round is not upcoming");
        require(newAllocation_ != 0, "Allocation cannot be zero");

        _rounds[roundId_].allocation = newAllocation_;

        emit PresaleRoundChanged(roundId_, _rounds[roundId_]);
    }

    /**
     * @dev Updates the base metadata URI
     *
     * @param _newBaseUri Updated base metadata URI
     */
    function setBaseURI(string calldata _newBaseUri) external onlyOwner {
        _baseURI = _newBaseUri;
        emit BaseURIChanged(_newBaseUri);
    }

    /**
     * @notice Returns the deposit info by tokenId and round
     *
     * @param tokenId the voucher tokenId
     * @param round the round
     */
    function getDeposit(uint256 tokenId, uint256 round) external view returns (uint256) {
        return _deposits[tokenId][round];
    }

    /**
     * @notice Returns the deposit info by owner and round
     *
     * @param owner_ The voucher owner
     * @param round the round
     */
    function getDeposit(address owner_, uint256 round) external view returns (uint256) {
        return _deposits[tokenOf(owner_)][round];
    }

    /**
     * @notice Returns the latest price of ETH in USDC
     * @param _amount amount of ETH in wei
     */
    function estimateUSDCAmount(uint256 _amount) external view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_uniswapPair).getReserves();
        if (IUniswapV2Pair(_uniswapPair).token0() == address(_usdc)) {
            return (_amount * reserve0) / reserve1;
        } else {
            return (_amount * reserve1) / reserve0;
        }
    }

    /**
     * @notice Returns the amount of ETH in wei for a given amount of USDC
     * @param _usdcAmount amount of USDC in 6 decimals
     * @return Amount of ETH in wei
     */
    function estimateETHAmount(uint256 _usdcAmount) external view returns (uint256) {
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(_uniswapPair).getReserves();
        if (IUniswapV2Pair(_uniswapPair).token0() == address(_usdc)) {
            return (_usdcAmount * reserve1) / reserve0;
        } else {
            return (_usdcAmount * reserve0) / reserve1;
        }
    }

    /**
     * @dev returns the total supply of the Vitreus Voucher
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds - 1;
    }

    /**
     * @dev returns the presale round by number
     */
    function getPresaleRound(uint256 roundId_) external view returns (PresaleRound memory) {
        return _rounds[roundId_];
    }

    /**
     * @dev returns the number of presale rounds
     */
    function getPresaleRoundAmount() external view returns (uint) {
        return _rounds.length;
    }

    /**
     * @dev returns the list of presale rounds
     */
    function getAllPresaleRounds() external view returns (PresaleRound[] memory) {
        return _rounds;
    }

    /**
     * @dev returns the current presale round info
     */
    function getCurrentPresaleRound() external view returns (PresaleRound memory) {
        return _rounds[_currentPresaleRoundNumber()];
    }

    /**
     * @dev Returns the the round statistics for the specified tokenId
     *
     * @param _tokenId the voucher tokenID
     */
    function statsOf(uint256 _tokenId) external view returns (uint[] memory) {
        uint[] memory roundStatistic = new uint[](_currentPresaleRoundNumber() + 1);

        for (uint256 i = 0; i <= _currentPresaleRoundNumber(); ) {
            roundStatistic[i] = _deposits[_tokenId][i];

            unchecked {
                ++i;
            }
        }

        return roundStatistic;
    }

    /**
     * @dev Returns the name of the voucher
     */
    function name() external pure returns (string memory) {
        return "Vitreus Voucher";
    }

    /**
     * @dev Returns the symbol of the Vitreus Voucher
     */
    function symbol() external pure returns (string memory) {
        return "ViVo";
    }

    /**
     * @dev Returns the token URI for specified tokenId
     *
     * @param tokenId voucher token id
     */
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        _requireMinted(tokenId);
        return string.concat(_baseURI, tokenId.toString());
    }

    /**
     * @notice Performs approve to specified address for the tokenId
     *
     * @param to the address for being approved
     * @param tokenId for approval
     */
    function approve(address to, uint256 tokenId) external virtual override onlyAllowedOperatorApproval(to) {
        address owner_ = _ownerOf(tokenId);
        require(to != owner_, "Approval to current owner");

        require(
            _msgSender() == owner_ || isApprovedForAll(owner_, _msgSender()),
            "Approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev Returns the voucher tokenID of the user (0 if none)
     *
     * @param owner_ The token owner
     */
    function tokenOf(address owner_) public view returns (uint256) {
        return _tokenOwners[owner_];
    }

    /**
     * @notice Gets the approved address for tokenId
     *
     * @param tokenId The voucher tokenId
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _tokenApprovals[tokenId];
    }

    /**
     * @notice Set approval to the operator
     *
     * @param operator Operator address
     * @param approved The approval flag
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) external virtual override onlyAllowedOperatorApproval(operator) {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @notice Get approval flag for the operator
     *
     * @param owner_ owner of voucher
     * @param operator operator address
     */
    function isApprovedForAll(address owner_, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner_][operator];
    }

    /**
     * @notice Performs transfer of token from one wallet to another
     * @dev Will revert if the user already has another voucher
     *
     * @param from the token holder address
     * @param to the new owner address
     * @param tokenId the tokenID to be transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override onlyAllowedOperator(from) {
        _requireApprovedOrOwner(_msgSender(), tokenId);
        _transfer(from, to, tokenId);
    }

    /**
     * @notice Performs safe transfer of token from one wallet to another
     * @dev Will revert if the user already has another voucher
     *
     * @param from The token holder address
     * @param to the new owner address
     * @param tokenId the tokenID to be transfer
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external virtual override onlyAllowedOperator(from) {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * Returns the current presale round
     */
    function presaleRoundNumber() external view returns (uint) {
        return _currentPresaleRoundNumber();
    }

    /**
     * @notice Returns the the maximum available deposit for the tokenId
     * @dev TokenId would be 0 if user has no voucher
     *
     * @param tokenId The voucher tokenId
     */
    function availableDeposit(uint256 tokenId) external view returns (uint) {
        uint256 tokenDeposit = _currentPresaleRound().maximumDeposit - _deposits[tokenId][_currentPresaleRoundNumber()];
        uint256 roundDeposit = _currentPresaleRound().allocation *
            _currentPresaleRound().price -
            _currentPresaleRound().totalDeposits;

        return tokenDeposit > roundDeposit ? roundDeposit : tokenDeposit;
    }

    /**
     * @notice Performs safe transfer of token from one wallet to another
     * @dev Will revert if the user already has another voucher
     *
     * @param from The token holder address
     * @param to the new owner address
     * @param tokenId the tokenID to be transfer
     * @param data extra data to be passed to callback function (if supported)
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        _requireApprovedOrOwner(_msgSender(), tokenId);
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @notice Returns flag if the contract supports the specified interface
     *
     * @param interfaceId interfaceId
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Returns the balance of the specified wallet address
     *
     * @param owner_ the owner to be checked
     */
    function balanceOf(address owner_) public view virtual override returns (uint256) {
        return _balanceOf(owner_);
    }

    /**
     * @notice Returns the owner of the specified tokenId
     *
     * @param tokenId the voucher tokenId to be checked
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);
        return _ownerOf(tokenId);
    }

    /**
     * @notice Performs the swap of ETH to USDC using Uniswap
     */
    function _swapETHForUSDC(uint256 amountIn) internal returns (uint256) {
        uint256[] memory amounts = _uniswapV2Router.swapExactETHForTokens{value: amountIn}(
            0, // accept any amount of USDC
            _path,
            _usdcReceiver,
            block.timestamp
        );
        return amounts[1];
    }

    /**
     * @notice Performs the check wallet to have the zero balance
     *
     * @param to_ the address of the wallet to be checked
     */
    function _requireZeroBalance(address to_) internal view {
        require(_balanceOf(to_) == 0, "Only one voucher per address");
    }

    /**
     * @notice Performs the check for round to be open and available deposit to be enough
     *
     * @param _depositValue The deposit value to be checked
     */
    function _requirePresaleRoundOpen(uint256 _depositValue) internal view {
        // solhint-disable-next-line not-rely-on-time
        require(_currentPresaleRound().startTime <= block.timestamp, "Presale round not started");

        // solhint-disable-next-line not-rely-on-time
        require(_currentPresaleRound().endTime >= block.timestamp, "Presale round ended");
        require(
            _currentPresaleRound().allocation * _currentPresaleRound().price >
                _currentPresaleRound().totalDeposits + _depositValue,
            "Presale round allocation reached"
        );
    }

    /**
     * @notice Performs the check for deposit to be above the minimum
     *
     * @param tokenId voucher tokenId to be checked
     */
    function _requireDepositAboveMin(uint256 tokenId) internal view {
        require(
            _deposits[tokenId][_currentPresaleRoundNumber()] >= _currentPresaleRound().minimumDeposit,
            "Deposit below minimum"
        );
    }

    /**
     * @notice Performs the check for deposit to be below the maximum
     *
     * @param tokenId voucher tokenId to be checked
     */
    function _requireDepositsBelowMax(uint256 tokenId) internal view {
        require(
            _deposits[tokenId][_currentPresaleRoundNumber()] <= _currentPresaleRound().maximumDeposit,
            "Deposits above maximum"
        );
    }

    /**
     * @notice Perform the check of the account to be approved or owner address
     *
     * @param account_ account address to be checked
     * @param tokenId_ the voucher tokenId to be checked
     */
    function _requireApprovedOrOwner(address account_, uint256 tokenId_) internal view {
        require(_isApprovedOrOwner(account_, tokenId_), "Caller is not token owner or approved");
    }

    /**
     * @notice Perform the check of the voucher to exist
     *
     * @param tokenId the voucher tokenId to be checked
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "Invalid token ID");
    }

    /**
     * @notice Perform the check of the voucher to not exist
     *
     * @param tokenId the voucher tokenId to be checked
     */
    function _requireNotMinted(uint256 tokenId) internal view virtual {
        require(!_exists(tokenId), "Token already minted");
    }

    /**
     * @notice Performs minting of the tokenId to specified address and
     * with specified deposit amount
     *
     * @param to_ the address for minting
     * @param tokenId_ the tokenId to be minted
     * @param value_ value to be minted
     */
    function _mint(address to_, uint256 tokenId_, uint256 value_) internal nonReentrant {
        _requirePresaleRoundOpen(value_);
        _deposit(tokenId_, value_);
        _currentPresaleRound().endingId = uint32(tokenId_);
        _mint(to_, tokenId_);
    }

    /**
     * @notice Returns the current presale round
     */
    function _currentPresaleRound() internal view returns (PresaleRound storage) {
        return _rounds[_currentPresaleRoundNumber()];
    }

    /**
     * @notice Returns the current presale round number
     */
    function _currentPresaleRoundNumber() internal view returns (uint) {
        uint256 roundsAmount = _rounds.length;

        for (uint256 i = 0; i < roundsAmount; ) {
            // solhint-disable-next-line not-rely-on-time
            if (
                (_rounds[i].endTime >= block.timestamp && _rounds[i].startTime <= block.timestamp) ||
                _rounds[i].startTime > block.timestamp
            ) {
                return i;
            }

            unchecked {
                ++i;
            }
        }

        return roundsAmount > 0 ? roundsAmount - 1 : 0;
    }

    /**
     * @notice Performs deposit of the specified amount to tokenId
     *
     * @param tokenId_ the tokenId to be minted
     * @param value_ deposit value to be minted
     */
    function _deposit(uint256 tokenId_, uint256 value_) internal {
        require(tokenId_ != 0, "Deposit on zero token");
        _requirePresaleRoundOpen(value_);

        _deposits[tokenId_][_currentPresaleRoundNumber()] += value_;
        _requireDepositAboveMin(tokenId_);
        _requireDepositsBelowMax(tokenId_);

        _currentPresaleRound().totalDeposits += uint48(value_);

        emit Deposit(tokenId_, _currentPresaleRoundNumber(), value_);
    }

    /**
     * @notice Performs safe transfer of token from one wallet to another
     * @dev Will revert if the user already has another voucher
     *
     * @param from The token holder address
     * @param to the new owner address
     * @param tokenId the tokenID to be transfer
     * @param data extra data to be passed to callback function (if supported)
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        require(
            _checkOnVoucherReceived(from, to, tokenId, data),
            "Transfer to non ERC721Receiver implementer"
        );
        _transfer(from, to, tokenId);
    }

    /**
     * @notice Returns the owner of the specified tokenId
     *
     * @param tokenId the voucher tokenId to be checked
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _ownedTokens[tokenId];
    }

    /**
     * @notice Returns if the token exists
     *
     * @param tokenId the voucher tokenId to be checked
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @notice Returns if the specified address approved or owner for tokenId
     *
     * @param spender account address to be checked
     * @param tokenId the voucher tokenId to be checked
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner_ = VitreusVoucher.ownerOf(tokenId);
        return (spender == owner_ || isApprovedForAll(owner_, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @notice Returns the next tokenId
     */
    function _nextTokenId() internal returns (uint256) {
        return _tokenIds++;
    }

    /**
     * @notice Performs minting of the tokenId to specified address
     *
     * @param to the address for minting
     * @param tokenId the tokenId to be minted
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        _requireZeroBalance(to);
        require(to != address(0), "Mint to the zero address");
        _requireNotMinted(tokenId);

        _ownedTokens[tokenId] = to;
        _tokenOwners[to] = tokenId;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @notice Performs transfer of token from one wallet to another
     * @dev Will revert if the user already has another voucher
     *
     * @param from the token holder address
     * @param to the new owner address
     * @param tokenId the tokenID to be transfer
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(VitreusVoucher.ownerOf(tokenId) == from, "Transfer from incorrect owner");
        require(to != address(0), "Transfer to the zero address");
        require(_tokenOwners[to] == 0, "Transfer to Voucher holder");

        delete _tokenApprovals[tokenId];
        _ownedTokens[tokenId] = to;
        delete _tokenOwners[from];
        _tokenOwners[to] = tokenId;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @notice Performs approve to specified address for the tokenId
     *
     * @param to the address for being approved
     * @param tokenId for approval
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;

        emit Approval(VitreusVoucher.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @notice Returns the balance of the specified wallet address
     *
     * @param owner_ the owner to be checked
     */
    function _balanceOf(address owner_) internal view virtual returns (uint256) {
        return _tokenOwners[owner_] == 0 ? 0 : 1;
    }

    /**
     * @notice Set approval to the operator
     *
     * @param owner_ the owner of the token
     * @param operator Operator address
     * @param approved The approval flag
     */
    function _setApprovalForAll(address owner_, address operator, bool approved) internal virtual {
        require(owner_ != operator, "Approve to caller");
        _operatorApprovals[owner_][operator] = approved;

        emit ApprovalForAll(owner_, operator, approved);
    }

    /**
     * @notice Performs check for IERC721Receiver callback implementation
     *
     * @param from The initial owner of the token
     * @param to The target owner of the token
     * @param tokenId the voucher tokenId
     * @param data extra data to be passed to the callback
     */
    function _checkOnVoucherReceived(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("Transfer to non IERC721 implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }

        return true;
    }
}