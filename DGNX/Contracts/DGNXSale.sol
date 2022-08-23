// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '../interfaces/IDGNXPrivateSaleNFT.sol';

contract DGNXSale is ReentrancyGuard, Ownable, Pausable {
    uint256 public supplySale;
    uint256 public constant PRIVATE_SALE_TOKEN_PER_UNIT = 10_000 * 10**18; // 10k
    uint256 public constant PRIVATE_SALE_UNIT = 7_500 * 10**15; // 7.50 AVAX
    address public dgnx;
    address public locker;
    address public nfts;
    bool public claimActive = false;

    mapping(address => uint256) public privateSaleLimits;
    mapping(address => uint256) public bought;
    mapping(address => bool) public participant;

    constructor(
        address _dgnx,
        address _locker,
        address _nfts
    ) {
        require(_dgnx != address(0), 'no token _dgnx');
        require(_locker != address(0), 'no token _locker');
        require(_nfts != address(0), 'no token _nfts');

        dgnx = _dgnx;
        locker = _locker;
        nfts = _nfts;
        _pause();
    }

    event PayEntranceFee(address sender, uint256 tokenId, uint256 blockNumber);
    event AllocateForSale(address sender, uint256 amount, uint256 blockNumber);
    event Claim(address sender, uint256 amount, uint256 blockNumber);
    event Bought(
        address sender,
        uint256 amount,
        uint256 amountTotal,
        uint256 blockNumber
    );

    function finishSale() external onlyOwner {
        _pause();
        payable(owner()).transfer(address(this).balance);
    }

    function allocateForSale(uint256 amount) external onlyOwner {
        uint256 possibleAllocation = ERC20(dgnx).balanceOf(address(this));
        require(possibleAllocation >= amount, 'not enough dgnx available');
        supplySale = amount;
        emit AllocateForSale(_msgSender(), amount, block.number);
    }

    function lockLeftovers() external onlyOwner {
        if (supplySale > 0) {
            require(ERC20(dgnx).transfer(locker, supplySale), 'tx failed');
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {
        buy();
    }

    function payEntranceFee(uint256 tokenId)
        external
        whenNotPaused
        nonReentrant
    {
        require(
            IDGNXPrivateSaleNFT(nfts).ownerOf(tokenId) == _msgSender(),
            'DGNXSale::payEntranceFee wrong tokenId'
        );
        if (IDGNXPrivateSaleNFT(nfts).lookupTicketType(tokenId) == 2) {
            privateSaleLimits[_msgSender()] = 55 * (10**18);
        } else if (IDGNXPrivateSaleNFT(nfts).lookupTicketType(tokenId) == 1) {
            privateSaleLimits[_msgSender()] = 20 * (10**18);
        } else {
            privateSaleLimits[_msgSender()] = 10 * (10**18);
        }

        participant[_msgSender()] = true;

        emit PayEntranceFee(_msgSender(), tokenId, block.number);
        IDGNXPrivateSaleNFT(nfts).burn(tokenId);
    }

    function buy() public payable whenNotPaused nonReentrant {
        require(msg.value > 0, 'DGNXSale::buy not enough funds sent');
        require(supplySale > 0, 'DGNXSale::buy supply missing');
        uint256 payoutTokens = 0;
        uint256 valueReturn = 0;
        uint256 valueSent = msg.value;
        if (privateSaleLimits[_msgSender()] > 0) {
            if (valueSent > privateSaleLimits[_msgSender()]) {
                valueReturn = valueSent - privateSaleLimits[_msgSender()];
                valueSent -= valueReturn;
            }
            privateSaleLimits[_msgSender()] -= valueSent;
            payoutTokens =
                (PRIVATE_SALE_TOKEN_PER_UNIT * valueSent) /
                PRIVATE_SALE_UNIT;
        } else {
            revert('DGNXSale::buy sale limit exceeded or not registered yet');
        }

        if (payoutTokens > 0) {
            require(supplySale > payoutTokens, 'DGNXSale::buy supply exceeded');
            supplySale -= payoutTokens;
            if (valueReturn > 0 && valueReturn <= address(this).balance) {
                payable(_msgSender()).transfer(valueReturn);
            }
            bought[_msgSender()] += payoutTokens;
            emit Bought(
                _msgSender(),
                payoutTokens,
                bought[_msgSender()],
                block.number
            );
        }
    }

    /**
     * This method is used to claim previously allocated tokens through buying and participating in the private sale
     * To work properly the claming needs to be active and the sender should have bought at least 1 asset
     * the contract should be paused that this function is working
     */
    function claim() external whenPaused nonReentrant {
        require(claimActive, 'DGNXSale::claim claming not active yet');
        require(bought[_msgSender()] > 0, 'DGNXSale::claim no funds to claim');
        uint256 amount = bought[_msgSender()];
        delete bought[_msgSender()];
        require(
            ERC20(dgnx).transfer(_msgSender(), amount),
            'DGNXSale::claim tx failed'
        );
        emit Claim(_msgSender(), amount, block.number);
    }

    /**
     * Starts the claiming process
     */
    function startClaim() external onlyOwner {
        claimActive = true;
    }

    /**
     * Stops the claiming process
     */
    function stopClaim() external onlyOwner {
        claimActive = false;
    }
}
