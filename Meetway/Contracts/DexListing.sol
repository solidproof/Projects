// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./OriginOwner.sol";
import "./DexPair.sol";

contract DexListing is OriginOwner {

    address immutable public uniswapV2Router;
    address immutable public wbnbPair;
    address immutable public busdPair;

    uint internal _listingFeePercent = 0;
    uint internal _listingDuration;
    uint internal _listingStartAt =  0;

    bool internal _listingFinished;

    constructor(
        uint listingDuration_
    )
    {
        _listingDuration = listingDuration_;
        //PancakeSwap: Router v2  // mainnet 0x10ED43C718714eb63d5aA57B78B54704E256024E  // testnet 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        address router = address(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        uniswapV2Router = router;
        wbnbPair = DexPair._createPair(router, DexPair._wbnb);
        busdPair = DexPair._createPair(router, DexPair._busd);
    }

    function _startListing()
    private
    onlyOriginOwner
    {
        _listingStartAt = block.timestamp;
        _listingFeePercent = 100;

        //Owner removed, once listing started
        _removeOriginOwner();
    }

    function _finishListing()
    private
    {
        _listingFinished = true;
    }

    function _updateListingFee()
    private
    {
        uint pastTime = block.timestamp - _listingStartAt; // so thoi gian tu luc bat dau listing
        if (pastTime > _listingDuration) {
            _listingFeePercent = 0;
        } else {
            // pastTime == 0 => fee = 100
            // pastTime == _listingDuration => fee = 0

            // _listingDuration luon bang 100?  -> 
            _listingFeePercent = 100 * (_listingDuration - pastTime) / _listingDuration;
        }
    }

    function _updateAndGetListingFee(
        address sender_,
        address recipient_,
        uint256 amount_
    )
    internal
    returns (uint)
    {
        if (_listingStartAt == 0) { // chaa list add lq lan dau tien =? tra ve fee 0
            // first addLiquidity
            if (DexPair._isPair(recipient_) && amount_ > 0) {
                _startListing();
            }
            return 0;
        } else {
            _updateListingFee();
            if (_listingStartAt + _listingDuration <= block.timestamp) {
                _finishListing();
            }

            if (!DexPair._isPair(sender_) && !DexPair._isPair(recipient_)) { // neeus ng nhan va gui deu ko phai la pair - > fee 0
                // normal transfer  
                return 0;
            } else {
                // swap
                return amount_ * _listingFeePercent / 100;
            }
        }
    }

    function listingDuration()
    public
    view
    returns (uint)
    {
        return _listingDuration;
    }

    function listingFinished()
    public
    view
    returns (bool)
    {
        return _listingFinished;
    }

    function listingStartAt()
    public
    view
    returns (uint)
    {
        return _listingStartAt;
    }

}