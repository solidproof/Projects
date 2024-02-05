// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../ShareholderRegistry/IShareholderRegistry.sol";
import "../RedemptionController/IRedemptionController.sol";
import "../PriceOracle/IStdReference.sol";

import "../NeokingdomToken/INeokingdomToken.sol";
import "../GovernanceToken/IGovernanceToken.sol";

import "hardhat/console.sol";

contract InternalMarketBase {
    event OfferCreated(
        uint128 id,
        address from,
        uint256 amount,
        uint256 createdAt
    );

    event OfferMatched(uint128 id, address from, address to, uint256 amount);

    struct Offer {
        uint256 expiredAt;
        uint256 amount;
    }

    struct Offers {
        uint128 start;
        uint128 end;
        mapping(uint128 => Offer) offer;
    }

    IGovernanceToken public tokenInternal;

    // Cannot use IERC20 here because it lacks `decimals`
    ERC20 public exchangeToken;

    IRedemptionController public redemptionController;
    IStdReference public priceOracle;
    IShareholderRegistry internal _shareholderRegistry;

    address public reserve;
    uint256 public offerDuration;

    mapping(address => Offers) internal _offers;

    mapping(address => uint256) internal _vaultContributors;

    function _initialize(
        IGovernanceToken _tokenInternal,
        uint256 _offerDuration
    ) internal virtual {
        tokenInternal = _tokenInternal;
        offerDuration = _offerDuration;
    }

    function _enqueue(
        Offers storage offers,
        Offer memory offer
    ) internal virtual returns (uint128) {
        offers.offer[offers.end] = offer;
        return offers.end++;
    }

    function _setInternalToken(IGovernanceToken token) internal virtual {
        tokenInternal = token;
    }

    function _setShareholderRegistry(
        IShareholderRegistry shareholderRegistry
    ) internal virtual {
        _shareholderRegistry = shareholderRegistry;
    }

    function _setExchangePair(
        ERC20 token,
        IStdReference oracle
    ) internal virtual {
        exchangeToken = token;
        priceOracle = oracle;
    }

    function _setReserve(address reserve_) internal virtual {
        reserve = reserve_;
    }

    function _setRedemptionController(
        IRedemptionController redemptionController_
    ) internal virtual {
        redemptionController = redemptionController_;
    }

    function _setOfferDuration(uint duration) internal virtual {
        offerDuration = duration;
    }

    function _makeOffer(address from, uint256 amount) internal virtual {
        _vaultContributors[from] += amount;

        uint256 expiredAt = block.timestamp + offerDuration;
        uint128 id = _enqueue(_offers[from], Offer(expiredAt, amount));

        emit OfferCreated(id, from, amount, expiredAt);

        require(
            tokenInternal.transferFrom(from, address(this), amount),
            "InternalMarketBase: transfer failed"
        );
        redemptionController.afterOffer(from, amount);
    }

    function _beforeWithdraw(address from, uint256 amount) internal virtual {
        Offers storage offers = _offers[from];

        for (uint128 i = offers.start; i < offers.end && amount > 0; i++) {
            Offer storage offer = offers.offer[i];

            if (block.timestamp > offer.expiredAt) {
                // FIXME it was > not >=
                if (amount >= offer.amount) {
                    amount -= offer.amount;
                    _vaultContributors[from] -= offer.amount;
                    delete offers.offer[offers.start++];
                } else {
                    offer.amount -= amount;
                    _vaultContributors[from] -= amount;
                    amount = 0;
                }
            }
        }

        require(amount == 0, "InternalMarket: amount exceeds balance");
    }

    function _beforeMatchOffer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        Offers storage offers = _offers[from];

        for (uint128 i = offers.start; i < offers.end && amount > 0; i++) {
            Offer storage offer = offers.offer[i];
            if (block.timestamp < offer.expiredAt) {
                // If offer is active check if the amount is bigger than the
                // current offer.
                if (amount >= offer.amount) {
                    amount -= offer.amount;
                    _vaultContributors[from] -= offer.amount;

                    // Remove the offer
                    emit OfferMatched(i, from, to, offer.amount);
                    delete offers.offer[offers.start++];
                    // If the amount is smaller than the offer amount, then
                } else {
                    // 1. decrease the amount of offered tokens
                    offer.amount -= amount;
                    _vaultContributors[from] -= amount;
                    emit OfferMatched(i, from, to, amount);

                    // 2. we've exhausted the amount, set it to zero and go back
                    // to the calling function
                    amount = 0;
                }
            }
        }

        require(amount == 0, "InternalMarket: amount exceeds offer");
    }

    function _matchOffer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        _beforeMatchOffer(from, to, amount);
        require(
            tokenInternal.transfer(to, amount),
            "InternalMarketBase: transfer failed"
        );
        require(
            exchangeToken.transferFrom(to, from, _convertToUSDC(amount)),
            "InternalMarketBase: transfer failed"
        );
    }

    function _withdraw(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.CONTRIBUTOR_STATUS(),
                from
            )
        ) {
            _beforeWithdraw(from, amount);
            tokenInternal.unwrap(address(this), to, amount);
        } else {
            tokenInternal.unwrap(from, to, amount);
        }
    }

    function _burn(address from, uint256 amount) internal virtual {
        assert(
            _shareholderRegistry.isAtLeast(
                _shareholderRegistry.CONTRIBUTOR_STATUS(),
                from
            )
        );
        _beforeWithdraw(from, amount);
        tokenInternal.burn(address(this), amount);
    }

    function _deposit(address to, uint256 amount) internal virtual {
        tokenInternal.wrap(to, amount);
    }

    function _redeem(address from, uint256 amount) internal virtual {
        uint256 withdrawableBalance = withdrawableBalanceOf(from);
        if (withdrawableBalance < amount) {
            uint256 difference = amount - withdrawableBalance;
            // internalToken is an address set by the operators of the DAO, hence trustworthy
            // slither-disable-start reentrancy-no-eth
            tokenInternal.burn(from, difference);
            _burn(from, withdrawableBalance);
            // slither-disable-end reentrancy-no-eth
        } else {
            _burn(from, amount);
        }

        // The "from" value is always the msg.sender according to the public implementation (see InternalMarket.sol)
        // slither-disable-next-line arbitrary-send-erc20
        require(
            exchangeToken.transferFrom(reserve, from, _convertToUSDC(amount)),
            "InternalMarketBase: transfer failed"
        );
        redemptionController.afterRedeem(from, amount);
    }

    function _convertToUSDC(uint256 eurAmount) internal view returns (uint256) {
        uint256 eurUsd = priceOracle.getReferenceData("EUR", "USD").rate;
        uint256 usdUsdc = priceOracle.getReferenceData("USDC", "USD").rate;

        // 18 is the default amount of decimals for ERC20 tokens, including neokingdom ones
        return
            (eurAmount * eurUsd) /
            usdUsdc /
            (10 ** (18 - exchangeToken.decimals()));
    }

    function _calculateOffersOf(
        address account
    ) internal view virtual returns (uint256, uint256) {
        Offers storage offers = _offers[account];

        uint256 vault = _vaultContributors[account];
        uint256 unlocked = 0;

        for (uint128 i = offers.start; i < offers.end; i++) {
            Offer storage offer = offers.offer[i];

            if (block.timestamp > offer.expiredAt) {
                unlocked += offer.amount;
            }
        }
        return (vault - unlocked, unlocked);
    }

    // Tokens owned by a contributor that are offered to other contributors
    function offeredBalanceOf(
        address account
    ) public view virtual returns (uint256) {
        (uint256 offered, ) = _calculateOffersOf(account);
        return offered;
    }

    // Tokens that has been offered but not bought by any other contributor
    // within the allowed timeframe.
    function withdrawableBalanceOf(
        address account
    ) public view virtual returns (uint256) {
        (, uint256 unlocked) = _calculateOffersOf(account);
        return unlocked;
    }
}
