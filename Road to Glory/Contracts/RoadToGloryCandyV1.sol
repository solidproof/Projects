// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./IRoadToGloryNFTMetadata.sol";
import "./BarbarianMetadata.sol";

contract RoadToGloryCandyV1 is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721Upgradeable
{
    struct MintRequestStruct {
        uint256 targetBlock;
        uint16 count;
    }
    using BarbarianMetadataLib for BarbarianMetadataLib.BarbarianMetadataStruct;
    IRoadToGloryNFTMetadata private metadata_generator;
    event MintRequested(address buyer, uint16 count, uint256 targetBlock);
    event MintPerformed(address buyer, uint256 id, BarbarianMetadataLib.BarbarianMetadataStruct data);
    mapping(address => MintRequestStruct[]) public mintRequestMap;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => BarbarianMetadataLib.BarbarianMetadataStruct) public tokenDatas;
    bytes32 public constant DIRECTOR_ROLE = keccak256("DIRECTOR_ROLE");
    mapping (address => bool) public Whitelisted;
    address [] public Whitelist;
    mapping (address => uint256) private performed_mints;
    uint256 public max_number_of_public_mints;
    uint256 public global_number_of_public_mints;
    uint256 public max_mint_per_wallet;
    uint256 public bnb_price_of_mint;

    uint256 public minWithdrawAmount;
    event MinWithdrawAmountUpdated(uint256 oldAmount, uint256 newAmount);

    function initialize(address _owner) public initializer {
        __ERC721_init("Road to Glory Barbarians", "RTGB");
        __AccessControl_init();
        __Context_init();
        __Pausable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(DIRECTOR_ROLE, _owner);
        bnb_price_of_mint = 2000;
        minWithdrawAmount = 1000 * 1e14;
    }

    function _request_mint(address buyer, uint16 count) internal {
        uint256 targetBlock = block.number + 2;
        mintRequestMap[buyer].push(MintRequestStruct(targetBlock, count));
        emit MintRequested(buyer, count, targetBlock);
    }

    function process_pending_mints() external {
        address buyer = msg.sender;
        MintRequestStruct[] storage requests = mintRequestMap[buyer];
        uint256 numberOfRequests = requests.length;

        for (uint256 i = numberOfRequests; i > 0; i--) {
            bool forced = false;
            MintRequestStruct storage lastRequest = requests[i - 1];
            require(block.number > lastRequest.targetBlock, "Mint is not ready");
            uint256 seed = uint256(blockhash(lastRequest.targetBlock));
            if (seed == 0) {
                forced = true;
            }
            _mint_tokens(buyer, lastRequest.count, forced, seed);
            requests.pop();
        }
    }

    function _mint_tokens(address buyer, uint16 count, bool forced, uint256 seed) internal {
        uint256 rarity = 255;
        if (forced) {
            rarity = 0;
        }
        for (uint256 i = 0; i < count; ++i) {
            uint256 id = _tokenIds.current();
            _tokenIds.increment();
            uint256 newID = _tokenIds.current();
            uint256 final_seed = uint256(keccak256(abi.encode(seed, id)));

            BarbarianMetadataLib.BarbarianMetadataStruct memory data = metadata_generator.create_random_metadata(final_seed, newID, rarity);
            tokenDatas[id] = data;
            _mint(buyer, newID);
            emit MintPerformed(buyer, id, data);
        }
    }

    function presale_draw(uint256 count) external payable nonReentrant {
        require(count <= 10, "The max number of draws for presale is 10.");
        uint cost = bnb_price_of_mint * count;
        require(msg.value >= cost * 1e14, "The value provided doesn't match the cost of minting.");
        bool canMint = false;
        uint current_number_of_mints = performed_mints[msg.sender];
        if ((Whitelisted[msg.sender] && current_number_of_mints + count <= max_mint_per_wallet) ||
            (current_number_of_mints + count <= max_mint_per_wallet && global_number_of_public_mints + count <= max_number_of_public_mints)) {
                canMint = true;
        }
        require(canMint, "The max mint has been reached for wallet or public.");
        performed_mints[msg.sender] += count;
        if (Whitelisted[msg.sender] != true) {
            global_number_of_public_mints += count;
        }
        _request_mint(msg.sender, uint16(count));
    }

    function setMinWithdrawAmount(uint256 amount) external onlyRole(DIRECTOR_ROLE) {
        require(amount > 0, "Min withdraw amount cannot be zero");
        require(amount != minWithdrawAmount, "Amount is already set");

        uint256 oldAmount = minWithdrawAmount;
        minWithdrawAmount = amount;
        emit MinWithdrawAmountUpdated(oldAmount, amount);        
    }

     function withdraw(address payable _to, uint256 amount) external nonReentrant onlyRole(DIRECTOR_ROLE) { 
        uint256 balance = address(this).balance; // Contract address balance 
 
        require(balance != 0, "Address balance is 0"); // Balance cannot be 0 
        require(amount > 0, "Cannot withdraw zero"); // Withdraw amount cannot be 0 
        require(amount >= minWithdrawAmount, "Withdraw amount to small"); // Amount must be higher than minWithdrawAmount 
        require(_to != address(0), "Recipient cannot be zero address"); // No zero address allowed 
 
        // Set amount to balance of contract if balance is not enough 
        if(balance < amount) 
            amount = balance; 
 
        (bool success, ) = _to.call{value: amount}(""); 
        require(success, "WF"); 
    }

    function get_whitelist() external onlyRole(DIRECTOR_ROLE) view returns (address [] memory) {
        return Whitelist;
    }
    function add_to_whitelist(address [] memory toWhitelist) external nonReentrant onlyRole(DIRECTOR_ROLE) {
        require(toWhitelist.length < 5000, "WLF");
        for (uint256 i = 0; i < toWhitelist.length; ++i) {
            Whitelisted[toWhitelist[i]] = true;
            Whitelist.push(toWhitelist[i]);

        }
    }
    function reset_whitelist() onlyRole(DIRECTOR_ROLE) external nonReentrant {
        for (uint i=0; i < Whitelist.length; ++i) {
            Whitelisted[Whitelist[i]] = false;
        }
        delete Whitelist;
    }
    function set_mint_price(uint256 new_price) external onlyRole(DIRECTOR_ROLE) nonReentrant {
        require(new_price >= 1000, "E1"); // Safeguard, 1000 * 1e14 = 0.1
        bnb_price_of_mint = new_price;
    }
    function set_max_mint_per_wallet(uint256 new_max_mint_per_wallet) external onlyRole(DIRECTOR_ROLE) nonReentrant {
        require (new_max_mint_per_wallet >= 1 && new_max_mint_per_wallet <= 10, "E2");
        max_mint_per_wallet = new_max_mint_per_wallet;
    }
    function set_max_public_mints(uint256 new_max_public_mints) external onlyRole(DIRECTOR_ROLE) nonReentrant {
        require(new_max_public_mints >= 10 && new_max_public_mints <= 10000, "E3");
        max_number_of_public_mints = new_max_public_mints;
    }
    function reset_global_number_of_mints() external onlyRole(DIRECTOR_ROLE) {
        global_number_of_public_mints = 0;
    }
    function set_metadata(address addr) external onlyRole(DIRECTOR_ROLE) {
        require(addr != address(0), "E4");
        metadata_generator = IRoadToGloryNFTMetadata(addr);
    }
    receive() external payable nonReentrant {}
    fallback() external payable nonReentrant {}
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Upgradeable, AccessControlUpgradeable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}