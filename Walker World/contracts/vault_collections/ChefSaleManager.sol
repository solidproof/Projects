// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ChefAvatar.sol";

/// @title Tickets that exchange to a Chef. Sold during the Big Town Chef sale.
/// @author Valerio Leo @valeriohq

contract ChefSaleManager is Ownable {
    uint256 public presalePrice;
    uint256 public publicFixedPrice;
    ChefAvatar public chefAvatar;
    address public treasury;
    uint256 public presaleStart = block.timestamp + 180 days; // default to half a year from now
    uint256 public presaleLength = 1 days; // default to 1 day after presaleStart
    uint256 public publicStart = block.timestamp + 180 days; // default to half a year from now
    uint256 public publicSaleMaxPurchaseQuantity = 3;
    bytes32 public merkleRoot;

    event MerkleRootChanged(bytes32 newMerkleRoot);
    event TreasuryChanged(address newTreasury);
    event PricesChanged(uint256 newPresalePrice, uint256 newPublicFixedPrice);
    event PresaleConfigChanged(
        uint256 newPresaleStart,
        uint256 newPresaleLength
    );
    event PublicSaleConfigChanged(uint256 newPublicStart);
    event PublicSaleMaxPurchaseQuantityChanged(
        uint256 newPublicSaleMaxPurchaseQuantity
    );
    event PublicSalePricingModelChanged(
        PublicSalePricingModel newPublicSalePricingModel
    );
    event DutchAuctionConfigurationChanged(
        uint256 newDutchStartPrice,
        uint256 newDutchEndPrice,
        uint256 newDutchPriceStepDrecrease,
        uint256 newDutchStartTime,
        uint256 newDutchStep
    );

    struct DutchAuction {
        uint256 dutchStartPrice;
        uint256 dutchEndPrice;
        uint256 dutchPriceStepDrecrease;
        uint256 dutchStartTime;
        uint256 dutchStep;
    }

    DutchAuction public dutchAuction;

    mapping(address => uint256) public publicSalePurchasesPerAddress;
    mapping(address => uint256) public presaleChefs;

    enum SalePhases {
        NO_SALE,
        PRESALE,
        PUBLIC_SALE
    }

    enum PublicSalePricingModel {
        FIXED_PRICE,
        DUTCH_AUCTION
    }

    PublicSalePricingModel public publicSalePricingModel;

    constructor(
        uint256 _presalePrice,
        uint256 _publicPrice,
        ChefAvatar _chefAvatar,
        address _treasury
    ) {
        presalePrice = _presalePrice;
        publicFixedPrice = _publicPrice;
        chefAvatar = _chefAvatar;
        treasury = _treasury;
    }

    /// @notice It changes the merkleRoot variable.
    /// @dev Only callable by owner.
    /// @param _merkleRoot: the new merkle root
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;

        emit MerkleRootChanged(_merkleRoot);
    }

    /// @notice It changes the treasury treasury that receives the payments.
    /// @dev Only callable by owner.
    /// @param _treasury: the new treasury address
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;

        emit TreasuryChanged(_treasury);
    }

    /// @notice It updates the presale and public sale prices.
    /// @dev Only callable by owner.
    /// @param _presalePrice: the new presale price
    /// @param _publicPrice: the new public sale price
    function setPrices(uint256 _presalePrice, uint256 _publicPrice)
        external
        onlyOwner
    {
        presalePrice = _presalePrice;
        publicFixedPrice = _publicPrice;

        emit PricesChanged(_presalePrice, _publicPrice);
    }

    /// @notice It updates the start time and length of the presale
    /// @dev Only callable by owner.
    /// @param _presaleStart: the new presale start timestamp
    /// @param _presaleLength: the new presale length in seconds
    function setPresaleConfig(uint256 _presaleStart, uint256 _presaleLength)
        external
        onlyOwner
    {
        presaleStart = _presaleStart;
        presaleLength = _presaleLength;

        emit PresaleConfigChanged(_presaleStart, _presaleLength);
    }

    /// @notice It updates the start time of the public sale
    /// @dev Only callable by owner.
    /// @param _publicStart: the new public sale start timestamp
    function setPublicConfig(uint256 _publicStart) external onlyOwner {
        publicStart = _publicStart;

        emit PublicSaleConfigChanged(_publicStart);
    }

    /// @notice It updates the max purchase quantity of the public sale
    /// @dev Only callable by owner.
    /// @param newAmount: the new max amount users can mint during public sale
    function setPublicSaleMaxPurchaseQuantity(uint256 newAmount)
        external
        onlyOwner
    {
        publicSaleMaxPurchaseQuantity = newAmount;

        emit PublicSaleMaxPurchaseQuantityChanged(newAmount);
    }

    /// @notice It updates the pricing model of the public sale.
    /// @dev Only callable by owner. Parameter can be one of 0 or 1. 0 for fixed price, 1 for dutch auction.
    /// @param pricingModel: the new pricing model of the public sale
    function setPublicSalePricingModel(PublicSalePricingModel pricingModel)
        external
        onlyOwner
    {
        publicSalePricingModel = pricingModel;

        emit PublicSalePricingModelChanged(pricingModel);
    }

    /// @notice It updates the dutch auction settings.
    /// @dev Only callable by owner.
    /// @param _dutchStartPrice: the new start price
    /// @param _dutchEndPrice: the new end price
    /// @param _dutchPriceStepDrecrease: the new price decrease step
    /// @param _dutchStartTime: the new start timestamp in seconds
    /// @param _dutchStep: the new step in seconds for the price decrease
    function configureDutch(
        uint256 _dutchStartPrice,
        uint256 _dutchEndPrice,
        uint256 _dutchPriceStepDrecrease,
        uint256 _dutchStartTime,
        uint256 _dutchStep
    ) external onlyOwner {
        require(
            _dutchStartPrice > _dutchEndPrice,
            "ChefSaleManager: dutchStartPrice must be greater than dutchEndPrice"
        );
        require(
            _dutchPriceStepDrecrease > 0,
            "ChefSaleManager: dutchPriceStepDrecrease must be greater than 0"
        );
        require(
            _dutchStartTime >= block.timestamp,
            "ChefSaleManager: dutchStartTime must be greater than or equal to block.timestamp"
        );
        require(
            _dutchStep > 0,
            "ChefSaleManager: dutchStep must be greater than 0"
        );
        require(
            _dutchStartTime > _dutchStep,
            "ChefSaleManager: dutchStartTime must be greater than dutchStep"
        );

        dutchAuction.dutchStartPrice = _dutchStartPrice;
        dutchAuction.dutchEndPrice = _dutchEndPrice;
        dutchAuction.dutchPriceStepDrecrease = _dutchPriceStepDrecrease;
        dutchAuction.dutchStartTime = _dutchStartTime;
        dutchAuction.dutchStep = _dutchStep;

        emit DutchAuctionConfigurationChanged(
            _dutchStartPrice,
            _dutchEndPrice,
            _dutchPriceStepDrecrease,
            _dutchStartTime,
            _dutchStep
        );
    }

    function _getDutchAuctionPrice() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - dutchAuction.dutchStartTime;
        uint256 stepsElapsed = elapsed / dutchAuction.dutchStep;
        uint256 priceDecrease = stepsElapsed *
            dutchAuction.dutchPriceStepDrecrease;

        if (priceDecrease > dutchAuction.dutchStartPrice) {
            return dutchAuction.dutchEndPrice;
        }

        uint256 currPrice = dutchAuction.dutchStartPrice - priceDecrease;

        return
            currPrice >= dutchAuction.dutchEndPrice
                ? currPrice
                : dutchAuction.dutchEndPrice;
    }

    /// @notice It returns the current price per-nft taking into account the currect sale phase and pricing model
    function getCurrentPrice() public view returns (uint256) {
        SalePhases phase = getSalePhase();

        if (phase == SalePhases.PRESALE) {
            return presalePrice;
        }
        if (
            phase == SalePhases.PUBLIC_SALE &&
            publicSalePricingModel == PublicSalePricingModel.DUTCH_AUCTION
        ) {
            return _getDutchAuctionPrice();
        }

        if (
            phase == SalePhases.PUBLIC_SALE &&
            publicSalePricingModel == PublicSalePricingModel.FIXED_PRICE
        ) {
            return publicFixedPrice;
        }

        require(false, "Invalid phase"); // stop execution if reach here
    }

    function _transferFunds(uint256 totalCost) private {
        require(msg.value == totalCost, "wrong amount");
        (bool success, ) = payable(treasury).call{value: totalCost}("");
        require(success, "transfer failed");
    }

    function admitPresaleUser(
        uint256 quantity,
        uint256 maxQuantity,
        bytes32[] calldata proofs
    ) internal returns (bool) {
        bool isProofValid = MerkleProof.verify(
            proofs,
            merkleRoot,
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked(msg.sender, maxQuantity))
                )
            )
        );

        presaleChefs[msg.sender] += quantity;

        return presaleChefs[msg.sender] <= maxQuantity && isProofValid;
    }

    function admitPublicUser(uint256 quantity) internal returns (bool) {
        publicSalePurchasesPerAddress[msg.sender] += quantity;

        return
            publicSalePurchasesPerAddress[msg.sender] <=
            publicSaleMaxPurchaseQuantity;
    }

    /// @notice It returns the current sale phase
    function getSalePhase() public view returns (SalePhases) {
        if (block.timestamp < presaleStart) {
            return SalePhases.NO_SALE;
        }
        if (block.timestamp < presaleStart + presaleLength) {
            return SalePhases.PRESALE;
        }

        if (block.timestamp >= publicStart) {
            return SalePhases.PUBLIC_SALE;
        }

        return SalePhases.NO_SALE;
    }

    /// @notice It will purchase the given amount of tokens for the user during the presale phase
    /// @dev Only callable by during the presale phase. The correct amount of ETH should be sent based on the current price or the call will revert`
    /// @param quantity: the amount of tokens to purchase
    /// @param maxQuantity: the maximum amount of tokens this user can purchase during presale
    /// @param proofs: the merkle proofs for the current user
    function presaleBuy(
        uint256 quantity,
        uint256 maxQuantity,
        bytes32[] calldata proofs
    ) external payable {
        SalePhases salePhase = getSalePhase();
        require(salePhase == SalePhases.PRESALE, "presale not active");

        uint256 totalCost = getCurrentPrice() * quantity;
        require(msg.value == totalCost, "Wrong amount sent");

        bool admitUser = admitPresaleUser(quantity, maxQuantity, proofs);

        require(admitUser, "User not admitted");

        _transferFunds(totalCost);
        chefAvatar.mint(quantity, msg.sender);
    }

    /// @notice It will purchase the given amount of tokens for the user during the public sale phase
    /// @dev Only callable by during the public sale phase. The correct amount of ETH should be sent based on the current price or the call will revert
    /// @param quantity: the amount of tokens to purchase
    function publicBuy(uint256 quantity) external payable {
        SalePhases salePhase = getSalePhase();
        require(salePhase == SalePhases.PUBLIC_SALE, "public sale not active");

        uint256 totalCost = getCurrentPrice() * quantity;
        require(msg.value == totalCost, "Wrong amount sent");

        bool admitUser = admitPublicUser(quantity);
        require(admitUser, "User not admitted");

        _transferFunds(totalCost);
        chefAvatar.mint(quantity, msg.sender);
    }
}
