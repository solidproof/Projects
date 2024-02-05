// SPDX-License-Identifier: None
pragma solidity ^0.8.7;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IVaultBuilder.sol";
import "./interfaces/IAssetVault.sol";
import "./interfaces/IMetaWealthModerator.sol";
import "./interfaces/IMetaWealthFundraiser.sol";

contract MetaWealthFundraiser is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC721Receiver,
    IMetaWealthFundraiser
{
    IVaultBuilder vaultBuilder;
    IMetaWealthModerator moderator;
    struct CampaignInstance {
      address owner;
      bytes32[] _merkleProof;
      uint64 numberShares;
      uint256 raiseGoal;
      uint256 remainingRaise;
      address raiseCurrency;
    }

    // Collection => Token ID => Campaign instance
    mapping(address => mapping(uint256 => CampaignInstance)) public activeCampaigns;

    // Collection => Token ID => Investors[] array
    mapping(address => mapping(uint256 => address[])) public investors;

    // User => Collection => Token ID => Investment amount
    mapping(address => mapping(address => mapping(uint256 => uint256))) public investments;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IVaultBuilder vault, IMetaWealthModerator _metawealthMod)
        public
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();
        vaultBuilder = vault;
        moderator = _metawealthMod;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function startCampaign(address collection, uint256 tokenId, uint64 numberShares, uint256 raiseGoal, address raiseCurrency, bytes32[] memory _merkleProof) external override {
      require(moderator.checkWhitelist(_merkleProof, _msgSender()), "MetaWealthFundraiser: Not whitelisted");
      require(moderator.isSupportedCurrency(raiseCurrency), "MetaWealthFundraiser: Raise currency not supported");
      require(IERC721(collection).ownerOf(tokenId) == _msgSender(), "MetaWealthFundraiser: Caller not asset owner");
      require(numberShares > 0, "MetaWealthFundraiser: Too few shares");
      require(raiseGoal > 0, "MetaWealthFundraiser: Raise goal not accepted");
      
      IERC721(collection).safeTransferFrom(_msgSender(), address(this), tokenId, "");
      activeCampaigns[collection][tokenId] = CampaignInstance(_msgSender(), _merkleProof, numberShares, raiseGoal, raiseGoal, raiseCurrency);

      emit CampaignStarted(_msgSender(), collection, tokenId, numberShares, raiseGoal, raiseCurrency);
    }

    function invest(address collection, uint256 tokenId, uint256 amount, bytes32[] memory _userMerkleProof, bytes32[] memory _fundraiserMerkleProof) external override {
      CampaignInstance memory campaign = activeCampaigns[collection][tokenId];

      require(moderator.checkWhitelist(_userMerkleProof, _msgSender()), "MetaWealthFundraiser: Not whitelisted");
      require(campaign.remainingRaise >= amount, "MetaWealthFundraiser: Does not require this much amount");
      require(amount * campaign.numberShares / campaign.raiseGoal >= 1, "MetaWealthFundraiser: Should invest for at least 1 share");

      IERC20(campaign.raiseCurrency).transferFrom(_msgSender(), address(this), amount);
      campaign.remainingRaise -= amount;
      
      if (investments[_msgSender()][collection][tokenId] == 0) {
        investors[collection][tokenId].push(_msgSender());
      }
      investments[_msgSender()][collection][tokenId] += amount;

      emit InvestmentReceived(_msgSender(), collection, tokenId, amount, campaign.remainingRaise == 0);

      if (campaign.remainingRaise == 0) {
        _completeRaise(collection, tokenId, _fundraiserMerkleProof);
      }
    }

    function cancelRaise(address collection, uint256 tokenId, bytes32[] memory _merkleProof) external override {
      require(moderator.checkWhitelist(_merkleProof, _msgSender()), "MetaWealthFundraiser: Not whitelisted");
      require(activeCampaigns[collection][tokenId].owner == _msgSender() || moderator.getAdmin() == _msgSender(), "MetaWealthFundraiser: Access forbidden");

      CampaignInstance memory campaign = activeCampaigns[collection][tokenId];
      address[] memory activeInvestors = investors[collection][tokenId];
      
      for (uint256 i = 0; i < activeInvestors.length; i++) {
        uint256 invested = investments[activeInvestors[i]][collection][tokenId];
        IERC20(campaign.raiseCurrency).transfer(activeInvestors[i], invested);
        delete investments[activeInvestors[i]][collection][tokenId];
      }

      IERC721(collection).safeTransferFrom(address(this), _msgSender(), tokenId, "");

      delete activeCampaigns[collection][tokenId];
      delete investors[collection][tokenId];

      emit CampaignCancelled(_msgSender(), collection, tokenId);
    }

    function _completeRaise(address collection, uint256 tokenId, bytes32[] memory _fundraiserMerkleProof) internal {
      CampaignInstance memory campaign = activeCampaigns[collection][tokenId];
      address[] memory activeInvestors = investors[collection][tokenId];

      delete activeCampaigns[collection][tokenId];
      delete investors[collection][tokenId];
      
      IERC721(collection).approve(address(vaultBuilder), tokenId);

      // VaultBuilder makes address(this) the owner of new Vault
      IERC20 newVault = IERC20(vaultBuilder.fractionalize(collection, tokenId, campaign.numberShares, _fundraiserMerkleProof));

      uint256 cumulativeRaised = 0;
      uint256 remainingShares = campaign.numberShares;
      for (uint256 i = 0; i < activeInvestors.length; i++) {
        uint256 invested = investments[activeInvestors[i]][collection][tokenId];
        uint256 share = invested * campaign.numberShares / campaign.raiseGoal;

        newVault.transfer(activeInvestors[i], share);

        unchecked {
          remainingShares -= share;
          cumulativeRaised += invested;
        }

        delete investments[activeInvestors[i]][collection][tokenId];
      }
      if (remainingShares > 0) {
        newVault.transfer(campaign.owner, remainingShares);
      }
      IERC20(campaign.raiseCurrency).transfer(campaign.owner, cumulativeRaised);

      // Make the campaign owner the owner of the asset vault
      OwnableUpgradeable(address(newVault)).transferOwnership(campaign.owner);
    }

    function onERC721Received(
        address ,
        address ,
        uint256 ,
        bytes calldata 
    ) external pure override returns (bytes4) {
      return IERC721Receiver.onERC721Received.selector;
    }
}
