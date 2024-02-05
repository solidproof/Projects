//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../FundingManager/FundingTypes.sol";
import "./../IDOStates.sol";

interface IIDODetailsSetter {
    function updateTokenAddress(address _tokenAddress) external;

    function updateOwnerAddress(address _ownerAddress) external;

    function updateTokenPrice(uint _tokenPrice) external;

    function updateSoftCap(uint _softCap) external;

    function updateHardCap(uint _hardCap) external;

    function updateMinPurchasePerWallet(uint _minPurchasePerWallet) external;

    function updateMaxPurchasePerWallet(uint _maxPurchasePerWallet) external;

    function updateSaleStartTime(uint _saleStartTime) external;

    function updateSaleEndTime(uint _saleEndTime) external;

    function updateHeadStart(uint _headStart) external;

    function updateVotingStartTime(uint _voteStartTime) external;

    function updateVotingEndTime(uint _voteEndTime) external;

    function updateListingRate(uint _listingRate) external;

    function updateLpLockDuration(uint _lpLockDuration) external;

    function updateAllocationToLPInBP(uint8 _allocationToLPInBP) external;

    function updateSaleTitle(string memory _saleTitle) external;

    function updateSaleDescription(string memory _saleDescription) external;

    function updateWebsite(string memory _website) external;

    function updateTelegram(string memory _telegram) external;

    function updateGithub(string memory _github) external;

    function updateTwitter(string memory _twitter) external;

    function updateLogo(string memory _logo) external;

    function updateWhitePaper(string memory _whitePaper) external;

    function updateKyc(string memory _kyc) external;

    function updateFundingType(FundingTypes.FundingType _fundingType) external;

    function updateState(IDOStates.IDOState _newState) external;

    function updatePreSaleAddress(address _preSale) external;

    function updateTreasuryAddress(address _treasury) external;

    function updateInHeadStartTill(uint _inHeadStartTill) external;

    function updateLpLockerId(uint _lpLockerId) external;
}
