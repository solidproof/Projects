// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./ERC20.sol";
import "./Ownable.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Router.sol";
import "./GasPriceController.sol";
import "./DexListing.sol";
import "./TransferFee.sol";

contract MeetWayToken is ERC20, Ownable, GasPriceController, TransferFee, DexListing {

    mapping(address => bool) private blackListedList;
    mapping(address => bool) private isExcludedFromFee;

    constructor()
    ERC20("MeetWay Token", "MET")
    DexListing(100) {

        _mint(msg.sender,  100000000 * (10**18));
        _setTransferFee(msg.sender, 0, 0, 0);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(
            !blackListedList[from] && !blackListedList[to],
            "Address is blacklisted"
        );
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(
        address sender_,
        address recipient_,
        uint256 amount_
    ) internal override onlyValidGasPrice {

        if (!listingFinished) {
            uint fee = _updateAndGetListingFee(sender_, recipient_, amount_);
            if (DexPair._isPair(recipient_)) {   // sell
                if (isExcludedFromFee[sender_]) fee = 0;
            } else {
                if (DexPair._isPair(sender_)) {  // buy
                    if (isExcludedFromFee[recipient_]) fee = 0;
                }
            }
            require(fee <= amount_, "Token: listing fee too high");
            uint transferA = amount_ - fee;
            if (fee > 0) {
                super._transfer(sender_, _getTransferFeeTo(), fee);
            }
            super._transfer(sender_, recipient_, transferA);
        } else {
            uint transferFee = _getTransferFee(sender_, recipient_, amount_);
            if (DexPair._isPair(recipient_)) {   // sell
                if (isExcludedFromFee[sender_]) transferFee = 0;
            } else {
                if (DexPair._isPair(sender_)) {  // buy
                    if (isExcludedFromFee[recipient_]) transferFee = 0;
                }
            }
            require(transferFee <= amount_, "Token: transferFee too high");
            uint transferA = amount_ - transferFee;
            if (transferFee > 0) {
                super._transfer(sender_, _getTransferFeeTo(), transferFee);
            }
            if (transferA > 0) {
                super._transfer(sender_, recipient_, transferA);
            }
        }
    }

    function addBlackList(address add) external onlyOwner {
        blackListedList[add] = true;
    }

    function addBlackLists(address[] calldata listAddress) external onlyOwner {
        uint256 count = listAddress.length;
        for (uint256 i = 0; i < count; i++) {
            blackListedList[listAddress[i]] = true;
        }
    }

    function removeBlackList(address add) external onlyOwner {
        blackListedList[add] = false;
    }

    function removeBlackLists(address[] calldata listAddress) external onlyOwner {
        uint256 count = listAddress.length;
        for (uint256 i = 0; i < count; i++) {
            blackListedList[listAddress[i]] = false;
        }
    }

    function addExcludeFee(address address_) external onlyOwner{
        isExcludedFromFee[address_] = true;
    }

    function removeExcludeFee(address address_) external onlyOwner{
        isExcludedFromFee[address_] = false;
    }

    /*
        Settings
    */

    function setMaxGasPrice(
        uint maxGasPrice_
    )
    external
    onlyOwner
    {
        _setMaxGasPrice(maxGasPrice_);
    }

    function setTransferFee(
        address to_,
        uint buyFee_,
        uint sellFee_,
        uint normalFee_
    )
    external
    onlyOwner
    {
        _setTransferFee(to_, buyFee_, sellFee_, normalFee_);
    }

    /*
         Withdraw
     */

    function withdrawBalance() external onlyOwner {
        address payable _owner = payable(_msgSender());
        _owner.transfer(address(this).balance);
    }

    function withdrawTokens(address _tokenAddr, address _to)
    external
    onlyOwner
    {
        require(
            _tokenAddr != address(this),
            "Cannot transfer out tokens from contract!"
        );
        require(isContract(_tokenAddr), "Need a contract address");
        ERC20(_tokenAddr).transfer(
            _to,
            ERC20(_tokenAddr).balanceOf(address(this))
        );
    }

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}