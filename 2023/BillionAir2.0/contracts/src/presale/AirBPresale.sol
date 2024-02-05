// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin-contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin-contracts/utils/Address.sol";

import {AggregatorV3Interface} from "@chainlink-contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IAIRBPresale} from "./interfaces/IAIRBPresale.sol";

/**
 *
 *          _____   .___ __________ __________
 *         /  _  \  |   |\______   \\______   \
 *        /  /_\  \ |   | |       _/ |    |  _/
 *       /    |    \|   | |    |   \ |    |   \
 *       \____|__  /|___| |____|_  / |______  /
 *               \/              \/         \/
 *
 * @title AIRBPresale contract on Binance Smart Chain
 * @author InnoPlatforms - BillionAir.com
 * @notice Presale contract for BillionAir $AIRB AIRB
 *
 */
contract AIRBPresale is Ownable, ReentrancyGuard, IAIRBPresale {
    using SafeERC20 for IERC20;

    using Address for address payable;

    IERC20 public immutable AIRB; // $AIRB BEP-20 AIRB contract

    address public treasury; // Treasury address

    // Timestamps
    uint256 public startTime; // Timestamp when presale starts

    uint256 public endTime; // Timestamp when presale ends

    // Vesting schedule
    uint256 public cliffDuration; // Duration of cliff after presale ends

    uint256 public vestingDuration; // Duration of vesting after cliff

    // Phases, caps and data
    uint256 public currentPhase = 0; // Current phase of presale

    uint256[] public caps = new uint256[](10); // Caps for each phase (in token amount per phase)

    uint256[10] public tokensSoldPerPhase; // Total number of tokens sold during presale for each phase

    mapping(address => uint256) public tokensBought; // tokensBought[address] = number of tokens bought by address

    mapping(address => uint256) public claimedTokens; // claimedTokens[address] = number of tokens claimed by address

    // Payment methods & prices
    uint256[10] public tokenPrices; // Token price in USD for each phase

    // BEP-20 address => AggregatorV3Interface
    mapping(address => AggregatorV3Interface) public paymentTokenToPriceFeed;

    // Supported payment methods
    address[] public supportedPaymentMethods;

    // Is supported payment method
    mapping(address => bool) public isSupportedPaymentMethod;

    // Events
    event TokensBought(
        address indexed buyer,
        address indexed paymentToken,
        uint256 numberOfTokens,
        address indexed referrer
    );

    event TokensClaimed(address indexed claimer, uint256 numberOfTokens);

    /*
        _______________  ___________________________________  _______      _____  .____     
        \_   _____/\   \/  /\__    ___/\_   _____/\______   \ \      \    /  _  \ |    |    
        |    __)_  \     /   |    |    |    __)_  |       _/ /   |   \  /  /_\  \|    |    
        |        \ /     \   |    |    |        \ |    |   \/    |    \/    |    \    |___ 
        /_______  //___/\  \  |____|   /_______  / |____|_  /\____|__  /\____|__  /_______ \
                \/       \_/                   \/         \/         \/         \/        \/
    */

    /**
     *
     * @notice Throws if called when presale is not active
     * @param paymentToken the method of payment
     * @param numberOfTokens the number of tokens to buy
     * @param referrer  the referrer address
     */
    function buyTokens(
        IERC20 paymentToken,
        uint256 numberOfTokens,
        address referrer
    ) external payable whenSaleIsActive nonReentrant {
        if (msg.value > 0) {
            require(
                address(paymentToken) == address(0),
                "Cannot have both BNB and BEP-20 payment"
            );

            // Payment is in BNB
            uint256 cost = getCost(paymentToken, numberOfTokens);
            require(msg.value >= cost, "Not enough BNB sent");
            _buyTokens(numberOfTokens, referrer);

            (bool sent, ) = payable(treasury).call{value: cost}("");
            require(sent, "Failed to send BNB");
            uint256 remainder = msg.value - cost;
            if (remainder > 0) {
                (sent, ) = payable(msg.sender).call{value: remainder}("");
                require(sent, "Failed to refund extra BNB");
            }
        } else {
            // Payment is in BEP-20
            uint256 cost = getCost(paymentToken, numberOfTokens);
            require(
                paymentToken.allowance(msg.sender, address(this)) >= cost,
                "Not enough allowance"
            );
            _buyTokens(numberOfTokens, referrer);
            paymentToken.safeTransferFrom(msg.sender, treasury, cost);
        }

        // Emit event
        emit TokensBought(
            msg.sender,
            address(paymentToken),
            numberOfTokens,
            referrer
        );
    }

    function _buyTokens(uint256 numberOfTokens, address referrer) internal {
        tokensBought[msg.sender] += numberOfTokens;
        tokensSoldPerPhase[currentPhase] += numberOfTokens;

        // Check if we have to give a bonus to the referrer
        if (referrer != address(0)) {
            require(referrer != msg.sender, "You cannot refer yourself");
            uint256 bonusTokens = (numberOfTokens * 5) / 100;

            // Check bonusTokens don't exceed current cap
            if (
                tokensSoldPerPhase[currentPhase] + bonusTokens >
                caps[currentPhase]
            ) {
                bonusTokens =
                    caps[currentPhase] -
                    tokensSoldPerPhase[currentPhase];
            }

            tokensBought[referrer] += bonusTokens;
            tokensSoldPerPhase[currentPhase] += bonusTokens;
        }

        // Check if we have to move to the next phase
        if (tokensSoldPerPhase[currentPhase] >= caps[currentPhase]) {
            ++currentPhase;
        }

        // Check if we exceeded last phase
        if (currentPhase >= caps.length) {
            // Presale is now over
            endTime = block.timestamp;
        }
    }

    /**
     * @notice Transfer the number of tokens that can currently be claimed by the user (if any)
     */
    function claimTokens() external nonReentrant {
        require(endTime != 0, "Presale has not ended");
        require(
            tokensBought[msg.sender] > claimedTokens[msg.sender],
            "No unclaimed tokens available"
        );

        uint256 elapsedTime = block.timestamp - endTime;
        uint256 releasableTokens;

        if (elapsedTime >= vestingDuration) {
            releasableTokens = tokensBought[msg.sender]; // All tokens are releasable after vestingDuration
        } else {
            uint256 immediateRelease = (tokensBought[msg.sender] * 20) / 100; // 20% released immediately after presale ends
            uint256 vestedTokens = ((tokensBought[msg.sender] -
                immediateRelease) * elapsedTime) / vestingDuration;
            releasableTokens = immediateRelease + vestedTokens;
        }

        uint256 tokensToClaim = releasableTokens - claimedTokens[msg.sender];
        claimedTokens[msg.sender] += tokensToClaim;
        AIRB.safeTransfer(msg.sender, tokensToClaim);

        // Emit event
        emit TokensClaimed(msg.sender, tokensToClaim);
    }

    /**
     * @notice List all supported payment methods
     */
    function listSupportedPaymentMethods()
        external
        view
        returns (address[] memory)
    {
        return supportedPaymentMethods;
    }

    /**
     * @notice Get the current phase of the presale
     * @return current phase of the presale
     */
    function getCurrentPhase() external view returns (uint256) {
        if (currentPhase == 10) {
            return 10;
        }
        return currentPhase + 1; // Phases start at 1 but array indexes start at 0
    }

    /**
     * @notice Get the number of tokens available of a given phase
     * @return number of tokens available for presale in the given phase
     */
    function tokensAvailable(uint256 phase) external view returns (uint256) {
        require(phase >= 1 && phase <= 10, "Invalid phase");
        uint256 phaseIndex = phase - 1; // Adjust for 0-indexed array

        return caps[phaseIndex] - tokensSoldPerPhase[phaseIndex];
    }

    /**
     * @notice Preview the estimated cost of buying a given number of tokens
     * with a given payment method
     * @param paymentToken the method of payment
     * @param numberOfTokens the number of tokens to buy
     */
    function previewCost(
        IERC20 paymentToken,
        uint256 numberOfTokens
    ) external view returns (uint256) {
        return getCost(paymentToken, numberOfTokens);
    }

    /*
        __________________________________________.___ _______    ________  _________
        /   _____/\_   _____/\__    ___/\__    ___/|   |\      \  /  _____/ /   _____/
        \_____  \  |    __)_   |    |     |    |   |   |/   |   \/   \  ___ \_____  \ 
        /        \ |        \  |    |     |    |   |   /    |    \    \_\  \/        \
        /_______  //_______  /  |____|     |____|   |___\____|__  /\______  /_______  /
                \/         \/                                   \/        \/        \/ 
    */

    /**
     * @param _airb $AIRB BEP-20 AIRB contract
     * @param _startTime Timestamp when presale starts
     * @param _caps Total number of tokens available for presale
     * @param _cliffDuration Duration of cliff after presale ends
     * @param _vestingDuration Duration of vesting after cliff
     */
    constructor(
        IERC20 _airb,
        uint256 _startTime,
        uint256[] memory _caps,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        address _treasury
    ) {
        require(
            _startTime >= block.timestamp,
            "Presale cannot start in the past"
        );
        require(_caps.length == 10, "Caps array must contain 10 phases");

        AIRB = _airb;
        startTime = _startTime;
        caps = _caps;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        treasury = _treasury;
    }

    /**
     * @notice Modifier to check if presale is active
     */
    modifier whenSaleIsActive() {
        require(
            block.timestamp >= startTime && endTime == 0,
            "Presale is not active"
        );
        require(currentPhase < 10, "Invalid phase");
        _;
    }

    /**
     * Calculate the cost of buying a number of tokens (AIRB)
     * @param paymentToken method of payment
     * @param numberOfTokens number of tokens to buy
     */
    function getCost(
        IERC20 paymentToken,
        uint256 numberOfTokens
    ) internal view returns (uint256) {
        AggregatorV3Interface dataFeed = paymentTokenToPriceFeed[
            address(paymentToken)
        ];
        require(address(dataFeed) != address(0), "Invalid data feed");
        require(
            isSupportedPaymentMethod[address(dataFeed)],
            "Unsupported payment method"
        );

        (, int256 answer, , , ) = dataFeed.latestRoundData();
        require(answer > 0, "Answer cannot be <= 0");
        require(dataFeed.decimals() == 8, "Unexpected decimals");
        uint256 price = uint256(answer) * 10 ** 10;

        uint256 tokenPrice = tokenPrices[currentPhase]; // 10 ** 15
        require(tokenPrice > 0, "Invalid token price");
        uint256 cost = (numberOfTokens * tokenPrice) / price;
        require(cost > 0, "Cost cannot be zero");

        return cost;
    }

    /**
     * @notice Set prices for each phase
     * @param _tokenPrices Array of token prices for each phase
     */
    function setTokenPrices(
        uint256[10] calldata _tokenPrices
    ) external onlyOwner {
        tokenPrices = _tokenPrices;
    }

    /**
     * @notice Set a price feed for a given payment method
     * @param paymentToken IERC20 token to set price feed for
     * @param dataFeed  AggregatorV3Interface price feed for the token
     */
    function setPriceFeed(
        address paymentToken,
        AggregatorV3Interface dataFeed
    ) external onlyOwner {
        if (!isSupportedPaymentMethod[address(dataFeed)]) {
            paymentTokenToPriceFeed[paymentToken] = dataFeed;
            supportedPaymentMethods.push(paymentToken);
            isSupportedPaymentMethod[address(dataFeed)] = true;
        }
    }

    /**
     * @notice Unset a price feed for a given payment method
     * @param paymentToken IERC20 token to set price feed for
     * @param dataFeed  AggregatorV3Interface price feed for the token
     */
    function unsetPriceFeed(
        address paymentToken,
        AggregatorV3Interface dataFeed
    ) external onlyOwner {
        isSupportedPaymentMethod[address(dataFeed)] = false;
        paymentTokenToPriceFeed[paymentToken] = AggregatorV3Interface(
            address(0)
        );
        // Create new supported payment method array without the removed payment method
        address[] memory newSupportedPaymentMethods = new address[](
            supportedPaymentMethods.length - 1
        );
        uint256 j = 0;
        for (uint256 i = 0; i < supportedPaymentMethods.length; ++i) {
            if (supportedPaymentMethods[i] != address(dataFeed)) {
                newSupportedPaymentMethods[j] = supportedPaymentMethods[i];
                ++j;
            }
        }
        supportedPaymentMethods = newSupportedPaymentMethods;
    }

    /**
     * @notice End the presale
     */
    function endSale() external onlyOwner {
        require(endTime == 0, "Presale has already ended");
        endTime = block.timestamp;

        uint unsoldTokens = 0;
        // Loop on each phase
        for (uint256 i = 0; i < caps.length; ++i) {
            // Add unsold tokens to unsoldTokens
            unsoldTokens += caps[i] - tokensSoldPerPhase[i];
        }

        // Transfer unsold AIRB to owner
        if (unsoldTokens > 0) {
            AIRB.safeTransfer(treasury, unsoldTokens);
        }
    }

    /**
     * @notice Transfer ownership of the contract to a new owner after the presale ends
     * @param newOwner new owner of the contract
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        Ownable.transferOwnership(newOwner);
    }

    /**
     * Revert any BNB sent to the contract directly
     */
    receive() external payable {
        revert();
    }
}
