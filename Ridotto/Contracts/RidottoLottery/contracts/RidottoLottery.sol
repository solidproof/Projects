// SPDX-License-Identifier: Ridotto Core License

/*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*#/@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#(#####/&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*##########(*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@//###############/,@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*####################((@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@(/#########################//@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@*#############PLAY#############(*@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@*(###############################/(@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@&.###########################,@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@%(#####################/(@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@/(#/,@@@@@@@@@@*.#################*@@@@@@@@@@@%(#/(@@@@@@@@@@@@@@
@@@@@@@@@@@@%,#######/@@@@@@@@@@@((###########*#@@@@@@@@@@@/#######*@@@@@@@@@@@@
@@@@@@@@@@,(###########/,@@@@@@@@@@(.#######,&@@@@@@@@@@%(###########/#@@@@@@@@@
@@@@@@@&,################# @@@@@@@@@@@.(#/(@@@@@@@@@@@/#################*@@@@@@@
@@@@@*(#####################*,@@@@@@@@@@@@@@@@@@@@@/(#####################/*@@@@
@@&*##########################(,@@@@@@@@@@@@@@@@@/###########################*@@
.(#############BUILD#############,*@@@@@@@@@@@#(##############EARN#############/
@###############################(/@@@@@@@@@@@@@*################################
@@@/(#########################/@@@@@@@@@@@@@@@@@@//#########################//@@
@@@@@//####################(/@@@@@@@@@@@@@@@@@@@@@@@*##################### @@@@@
@@@@@@@@@(###############*@@@@@@@@@@@@(###(@@@@@@@@@@@/(###############/ @@@@@@@
@@@@@@@@@@%*##########(*%@@@@@@@@@@/########(.@@@@@@@@@@@.###########.@@@@@@@@@@
@@@@@@@@@@@@@&/#####/&@@@@@@@@@@@(#############,(@@@@@@@@@@#*#####((@@@@@@@@@@@@
@@@@@@@@@@@@@@@**(/@@@@@@@@@@@/##################(.@@@@@@@@@@@,(,@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@(#######################,#@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@#############################(.@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@&(#################################,(@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@#######################################(,@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@.###########################################,@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ Ridotto Lottery  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@*/

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./interfaces/IRidottoLottery.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@ridotto-io/global-rng/contracts/interfaces/IGlobalRng.sol";

/** @title Ridotto Lottery.
 * @notice It is a contract for a lottery system using
 * PsuedoRandomness provided .
 */
contract RidottoLottery is
    Initializable,
    ReentrancyGuardUpgradeable,
    IRidottoLottery,
    PausableUpgradeable,
    AccessControlUpgradeable
{
    // Lottery RNG role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public injectorAddress;
    address public treasuryAddress;

    uint256 public currentLotteryId;
    uint256 public currentTicketId;

    uint256 public maxNumberTicketsPerClaim;
    uint256 public maxNumberTicketsPerBuy;
    uint256 public incentivePercent;

    uint256 public minLotteryPeriodicity;
    uint256 public lotteryPeriodicity;

    uint256 public maxTicketPrice;
    uint256 public minTicketPrice;

    uint256 public maxNumberTicketsBuyForOthers;
    uint256 public maxNumberReceiversBuyForOthers;

    uint256 public pendingInjectionNextLottery;

    uint256 public constant MIN_DISCOUNT_DIVISOR = 300;
    uint256 public constant MAX_TREASURY_FEE = 3000; // 30%
    uint256 public constant MAX_INCENTIVE_REWARD = 500; // 5%

    bool public autoInjection;

    // Chainlink VRF parameters
    bytes32 public keyHash;
    uint256 public subId;
    uint256 public gasLimit;
    uint256 public callCount;
    uint256 public providerId;
    bytes public providerCallParam;

    // Flag to check if the lottery parameters have been nextLotteryParamchanged
    bool public nextLotteryParamchanged;

    struct Ticket {
        uint32 number;
        address owner;
        uint256 roundId;
    }

    // Mapping are cheaper than arrays
    mapping(address => uint256) private nonces;
    mapping(uint256 => Lottery) private _lotteries;
    mapping(uint256 => Ticket) private _tickets;
    mapping(address => mapping(uint256 => bool)) isSubscribed;

    mapping(uint256 => uint256) public reqIds;

    // Bracket calculator is used for verifying claims for ticket prizes
    mapping(uint32 => uint32) private _bracketCalculator;

    // Keeps track of number of ticket per unique combination for each lotteryId
    mapping(uint256 => mapping(uint32 => uint256))
        private _numberTicketsPerLotteryId;

    // Keep track of user ticket ids for a given lotteryId
    mapping(address => mapping(uint256 => uint256[]))
        private _userTicketIdsPerLotteryId;

    // Token used for lottery & globalRng address
    IERC20 public lotteryToken;
    IGlobalRng public globalRng;

    /**
    @dev Modifier to check if the caller is not a contract or proxy contract.
    Reverts if the caller is a contract or proxy contract.
    */
    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /**
    @notice Initializes the lottery smart contract with default values and sets up admin role
    */

    function init() external initializer {
        __AccessControl_init();
        __Pausable_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        // Initializes a mapping
        for (uint8 i = 0; i <= 5; i++) {
            _bracketCalculator[i] = (i == 0)
                ? 1
                : _bracketCalculator[i - 1] * 10 + 1;
        }

        // Set default lottery values
        providerId = 0;
        maxTicketPrice = 50 ether;
        minTicketPrice = 0.005 ether;
        maxNumberTicketsPerClaim = 100;
        maxNumberTicketsPerBuy = 6;
        maxNumberTicketsBuyForOthers = 1;
        maxNumberReceiversBuyForOthers = 6;
        minLotteryPeriodicity = 12 hours;
        autoInjection = true;
        emit Initialised();
    }

    /**
    @notice Returns the current timestamp
    @return the current timestamp in seconds since the Unix Epoch
    */
    function getTime() public view returns (uint256) {
        return block.timestamp;
    }

    /**
     * @notice Changes the minimum lottery periodicity
     * @param _lotteryPeriodicity: new value for minimum lottery periodicity
     */
    function changeLotteryPeriodicity(
        uint256 _lotteryPeriodicity
    ) public onlyRole(OPERATOR_ROLE) {
        require(
            _lotteryPeriodicity >= minLotteryPeriodicity,
            "RidottoLottery: Invalid lottery periodicity"
        );
        lotteryPeriodicity = _lotteryPeriodicity;
    }

    /**

    @notice Sets the minimum allowed lottery periodicity
    @param _minLotteryPeriodicity: new minimum lottery periodicity value in seconds
    @dev Only the operator can call this function
    @dev The minimum allowed lottery periodicity is 1 minute
    */
    function setLoterryMinPeriodicity(
        uint256 _minLotteryPeriodicity
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _minLotteryPeriodicity >= 1 minutes,
            "RidottoLottery: Invalid lottery periodicity"
        );
        minLotteryPeriodicity = _minLotteryPeriodicity;
    }

    /**
    @notice Sets the RNG provider and provider ID
    @param _rng: address of the RNG provider
    @param _piD: provider ID
    @dev Require operator role, valid address and current lottery status to be different than Close
    */
    function setRngProvider(
        address _rng,
        uint256 _piD
    ) external onlyRole(OPERATOR_ROLE) {
        require(_rng != address(0), "RidottoLottery: Invalid address");
        require(
            _lotteries[currentLotteryId].status != Status.Close,
            "RidottoLottery: Pending RNG call"
        );
        globalRng = IGlobalRng(_rng);
        providerId = _piD;
    }

    /**
    @notice Sets the Chainlink VRF call parameters
    @param _keyHash: Key hash to identify the VRF job
    @param _subId: Subscription ID to identify the VRF job
    @param _minimumRequestConfirmations: Minimum number of confirmations for the VRF job
    @param _gasLimit: Gas limit for the VRF job
    @param _numWords: Number of words to retrieve for the VRF job
    */
    function setChainlinkCallParams(
        bytes32 _keyHash,
        uint256 _subId,
        uint256 _minimumRequestConfirmations,
        uint256 _gasLimit,
        uint256 _numWords
    ) external onlyRole(OPERATOR_ROLE) {
        VRFCoordinatorV2Interface v = VRFCoordinatorV2Interface(address(0));
        providerCallParam = abi.encodeWithSelector(
            v.requestRandomWords.selector,
            _keyHash,
            _subId,
            _minimumRequestConfirmations,
            _gasLimit,
            _numWords
        );
    }

    /**
    @notice Sets the incentive percent for the lottery
    @param _incentivePercent: the new incentive percent to set
    @dev Only callable by the operator role
    */
    function changeIncentivePercent(
        uint256 _incentivePercent
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _incentivePercent < MAX_INCENTIVE_REWARD,
            "RidottoLottery: Incentive percent must be less than MAX_INCENTIVE_REWARD"
        );
        incentivePercent = _incentivePercent;
    }

    /**
    @notice Buy a bulk of lottery tickets for the specified lottery and adds them to the user's tickets.
    @param _lotteryId: Id of the lottery
    @param _number: Number of tickets to buy
    Requirements:
        The lottery must be open
        The lottery must not be over
        The maximum number of tickets that can be bought at once is 6
    Effects:
        Transfers the required amount of lottery token to this contract
        Increments the total amount collected for the lottery round
        Adds the tickets to the lottery
    Emits a TicketsPurchase event with details of the tickets purchased
    */

    function buyTickets(
        uint256 _lotteryId,
        uint8 _number
    ) external override notContract nonReentrant whenNotPaused {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "RidottoLottery: Lottery is not open"
        );
        require(
            block.timestamp < _lotteries[_lotteryId].endTime,
            "RidottoLottery: Lottery is over"
        );
        require(
            _number <= maxNumberTicketsPerBuy,
            "RidottoLottery: Can only buy 6 tickets at once"
        );

        // Calculate number of lottery token to this contract
        uint256 amountTokenToTransfer = _calculateTotalPriceForBulkTickets(
            _lotteries[_lotteryId].discountDivisor,
            _lotteries[_lotteryId].priceTicketInToken,
            _number
        );

        // Transfer lottery tokens to this contract
        lotteryToken.transferFrom(
            address(msg.sender),
            address(this),
            amountTokenToTransfer
        );

        // Increment the total amount collected for the lottery round
        _lotteries[_lotteryId]
            .amountCollectedInLotteryToken += amountTokenToTransfer;

        uint32[] memory _ticketNumbers = getRandomNumbers(msg.sender, _number);

        // Add tickets to lottery
        _addTicketsToLottery(_lotteryId, _ticketNumbers, msg.sender);

        emit TicketsPurchase(
            msg.sender,
            _lotteryId,
            _ticketNumbers.length,
            _ticketNumbers
        );
    }

    /**
    @notice Allows a player to buy lottery tickets for other players and add them to a lottery
    @param _lotteryId: lottery id
    @param _numberOfTickets: array of the number of tickets to buy for each player
    @param _receivers: array of addresses of the players to buy tickets for
    */
    function buyForOthers(
        uint256 _lotteryId,
        uint256[] calldata _numberOfTickets,
        address[] calldata _receivers
    ) external notContract nonReentrant whenNotPaused {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "RidottoLottery: Lottery is not open"
        );
        require(
            block.timestamp < _lotteries[_lotteryId].endTime,
            "RidottoLottery: Lottery is over"
        );
        require(
            _receivers.length == _numberOfTickets.length,
            "RidottoLottery: Invalid inputs"
        );

        require(
            _receivers.length <= maxNumberReceiversBuyForOthers,
            "RidottoLottery: Too many receivers"
        );

        uint256 totalNumberOfTickets = 0;
        for (uint256 i = 0; i < _numberOfTickets.length; i++) {
            require(
                _numberOfTickets[i] <= maxNumberTicketsBuyForOthers,
                "RidottoLottery: Too many tickets"
            );
            totalNumberOfTickets += _numberOfTickets[i];
        }

        uint256 amountTokenToTransfer = _calculateTotalPriceForBulkTickets(
            _lotteries[_lotteryId].discountDivisor,
            _lotteries[_lotteryId].priceTicketInToken,
            totalNumberOfTickets
        );

        lotteryToken.transferFrom(
            address(msg.sender),
            address(this),
            amountTokenToTransfer
        );

        _lotteries[_lotteryId]
            .amountCollectedInLotteryToken += amountTokenToTransfer;

        for (uint256 i = 0; i < _receivers.length; i++) {
            uint32[] memory _ticketNumbers = getRandomNumbers(
                _receivers[i],
                _numberOfTickets[i]
            );

            // Add tickets to lottery
            _addTicketsToLottery(_lotteryId, _ticketNumbers, _receivers[i]);

            emit TicketsPurchase(
                _receivers[i],
                _lotteryId,
                _ticketNumbers.length,
                _ticketNumbers
            );
        }
    }

    /**
     * @notice Adds tickets to the lottery round and updates the number of tickets bought by the player
     * @param _lotteryId: lottery id
     * @param _ticketNumbers: an array of ticket numbers to be added to the lottery
     * @param receiver: the address of the user whose tickets are being added to the lottery
     */
    function _addTicketsToLottery(
        uint256 _lotteryId,
        uint32[] memory _ticketNumbers,
        address receiver
    ) internal {
        for (uint256 i = 0; i < _ticketNumbers.length; i++) {
            uint32 thisTicketNumber = _ticketNumbers[i];
            require(
                (thisTicketNumber >= 1000000) && (thisTicketNumber <= 1999999),
                "Outside range"
            );
            _numberTicketsPerLotteryId[_lotteryId][
                1 + (thisTicketNumber % 10)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                11 + (thisTicketNumber % 100)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                111 + (thisTicketNumber % 1000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                1111 + (thisTicketNumber % 10000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                11111 + (thisTicketNumber % 100000)
            ]++;
            _numberTicketsPerLotteryId[_lotteryId][
                111111 + (thisTicketNumber % 1000000)
            ]++;
            _userTicketIdsPerLotteryId[receiver][_lotteryId].push(
                currentTicketId
            );
            _tickets[currentTicketId] = Ticket({
                number: uint32(thisTicketNumber),
                owner: receiver,
                roundId: _lotteryId
            });
            // Increase lottery ticket number
            currentTicketId++;
        }
    }

    /**
    @notice Sets the maximum number of lottery tickets that can be bought by one account for others,
    as well as the maximum number of receivers that a player can buy tickets for.
    @param _maxNumberTicketsBuyForOthers: the maximum number of tickets that can be bought by one account for others
    @param _maxNumberReceiversBuyForOthers: the maximum number of receivers that a player can buy tickets for
    */
    function setMaxBuyForOthers(
        uint256 _maxNumberTicketsBuyForOthers,
        uint256 _maxNumberReceiversBuyForOthers
    ) external onlyRole(OPERATOR_ROLE) {
        maxNumberTicketsBuyForOthers = _maxNumberTicketsBuyForOthers;
        maxNumberReceiversBuyForOthers = _maxNumberReceiversBuyForOthers;
    }

    /**
    @notice Claims rewards for specified tickets and brackets, transfers the reward amount in LOT token to msg.sender
    @param _lotteryId: lottery id
    @param _ticketIds: array of ticket ids to claim rewards for
    @param _brackets: array of brackets corresponding to each ticket to claim rewards for
    */
    function claimTickets(
        uint256 _lotteryId,
        uint256[] calldata _ticketIds,
        uint32[] calldata _brackets
    ) external override notContract nonReentrant whenNotPaused {
        require(
            _ticketIds.length == _brackets.length,
            "RidottoLottery: Invalid inputs"
        );
        require(
            _ticketIds.length != 0,
            "RidottoLottery: _ticketIds.length must be >0"
        );
        require(
            _ticketIds.length <= maxNumberTicketsPerClaim,
            "RidottoLottery: Too many tickets to claim"
        );
        require(
            _lotteries[_lotteryId].status == Status.Claimable,
            "RidottoLottery: Lottery is not claimable"
        );

        // Initializes the rewardInLotteryTokenToTransfer
        uint256 rewardInLotteryTokenToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            require(_brackets[i] < 6, "Bracket out of range"); // Must be between 0 and 5

            uint256 thisTicketId = _ticketIds[i];

            require(
                _tickets[thisTicketId].roundId == _lotteryId,
                "ticket doesnt belong to given lotteryId"
            );

            require(
                msg.sender == _tickets[thisTicketId].owner,
                "RidottoLottery: Caller isn't  the ticket owner"
            );

            // Update the lottery ticket owner to 0x address
            _tickets[thisTicketId].owner = address(0);

            uint256 rewardForTicketId = _calculateRewardsForTicketId(
                _lotteryId,
                thisTicketId,
                _brackets[i]
            );

            // Check user is claiming the correct bracket
            require(
                rewardForTicketId != 0,
                "RidottoLottery: No prize for this bracket"
            );

            if (_brackets[i] != 5) {
                require(
                    _calculateRewardsForTicketId(
                        _lotteryId,
                        thisTicketId,
                        _brackets[i] + 1
                    ) == 0,
                    "RidottoLottery: Bracket must be higher"
                );
            }

            // Increment the reward to transfer
            rewardInLotteryTokenToTransfer += rewardForTicketId;
        }

        // Transfer money to msg.sender
        lotteryToken.transfer(msg.sender, rewardInLotteryTokenToTransfer);

        emit TicketsClaim(
            msg.sender,
            rewardInLotteryTokenToTransfer,
            _lotteryId,
            _ticketIds.length
        );
    }

    /**
     * @dev Close a lottery by requesting a random number from the generator.
     * Distribute incentive rewards to the operators and transfer the remaining funds to the current owner.
     * @param _lotteryId uint256 ID of the lottery
     */
    function closeLottery(
        uint256 _lotteryId
    ) external override nonReentrant whenNotPaused {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "Lottery not open"
        );
        require(
            block.timestamp > _lotteries[_lotteryId].endTime,
            "Lottery not over"
        );
        _lotteries[_lotteryId].firstTicketIdNextLottery = currentTicketId;

        // Request a random number from the generator based on a seed
        reqIds[_lotteryId] = globalRng.requestRandomWords(
            providerId,
            providerCallParam
        );

        _lotteries[_lotteryId].status = Status.Close;

        uint256 incetiveRewards = (_lotteries[_lotteryId]
            .amountCollectedInLotteryToken *
            3 *
            incentivePercent) / 10000;

        _lotteries[_lotteryId].incentiveRewards = incetiveRewards;
        _lotteries[_lotteryId].amountCollectedInLotteryToken -= incetiveRewards;
        lotteryToken.transfer(_msgSender(), incetiveRewards / 3);

        emit LotteryClose(_lotteryId, currentTicketId);
    }

    /**
    @dev Draws the final number, calculates the rewards per bracket and updates the lottery's status to claimable
    @param _lotteryId The ID of the lottery to draw the final number for and make claimable
    */
    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId
    ) external override nonReentrant whenNotPaused {
        require(
            _lotteries[_lotteryId].status == Status.Close,
            "Lottery not close"
        );
        require(
            globalRng.viewRandomResult(providerId, reqIds[_lotteryId]) != 0,
            "Numbers not drawn"
        );

        // Calculate the finalNumber based on the randomResult generated by GLOBAL RNG
        uint256 number = globalRng.viewRandomResult(
            providerId,
            reqIds[_lotteryId]
        );
        uint32 finalNumber = uint32(1000000 + (number % 1000000));

        // Initialize a number to count addresses in the previous bracket
        uint256 numberAddressesInPreviousBracket;

        // Calculate the amount to share post-treasury fee
        uint256 amountToShareToWinners = (
            ((_lotteries[_lotteryId].amountCollectedInLotteryToken) *
                (10000 - _lotteries[_lotteryId].treasuryFee))
        ) / 10000;

        // Initializes the amount to withdraw to treasury
        uint256 amountToWithdrawToTreasury;

        // Calculate prizes in lottery token for each bracket by starting from the highest one
        for (uint32 i = 0; i < 6; i++) {
            uint32 j = 5 - i;
            uint32 transformedWinningNumber = _bracketCalculator[j] +
                (finalNumber % (uint32(10) ** (j + 1)));

            _lotteries[_lotteryId].countWinnersPerBracket[j] =
                _numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] -
                numberAddressesInPreviousBracket;

            // A. If number of users for this _bracket number is superior to 0
            if (
                (_numberTicketsPerLotteryId[_lotteryId][
                    transformedWinningNumber
                ] - numberAddressesInPreviousBracket) != 0
            ) {
                // B. If rewards at this bracket are > 0, calculate, else, report the numberAddresses from previous bracket
                if (_lotteries[_lotteryId].rewardsBreakdown[j] != 0) {
                    _lotteries[_lotteryId].tokenPerBracket[j] = Math.ceilDiv(
                        ((_lotteries[_lotteryId].rewardsBreakdown[j] *
                            amountToShareToWinners) /
                            (_numberTicketsPerLotteryId[_lotteryId][
                                transformedWinningNumber
                            ] - numberAddressesInPreviousBracket)),
                        10000
                    );

                    // Update numberAddressesInPreviousBracket
                    numberAddressesInPreviousBracket = _numberTicketsPerLotteryId[
                        _lotteryId
                    ][transformedWinningNumber];
                }
                // A. No lottery token to distribute, they are added to the amount to withdraw to treasury address
            } else {
                _lotteries[_lotteryId].tokenPerBracket[j] = 0;
            }
        }

        //sum of all allocations rewards
        uint256 sumOfAllAllocations = 0;
        for (
            uint32 i = 0;
            i < _lotteries[_lotteryId].rewardsBreakdown.length;
            i++
        ) {
            sumOfAllAllocations += _lotteries[_lotteryId].tokenPerBracket[i];
        }

        amountToWithdrawToTreasury =
            amountToShareToWinners -
            sumOfAllAllocations;

        // Update internal statuses for lottery
        _lotteries[_lotteryId].finalNumber = finalNumber;
        _lotteries[_lotteryId].status = Status.Claimable;

        if (autoInjection) {
            // Update the amount to inject to the next lottery
            pendingInjectionNextLottery = amountToWithdrawToTreasury;
            amountToWithdrawToTreasury = 0;
        }

        amountToWithdrawToTreasury += (_lotteries[_lotteryId]
            .amountCollectedInLotteryToken - amountToShareToWinners);

        // Transfer RDT to treasury address
        lotteryToken.transfer(treasuryAddress, amountToWithdrawToTreasury);

        // Transfer the incentive to the operator
        lotteryToken.transfer(
            _msgSender(),
            _lotteries[_lotteryId].incentiveRewards / 3
        );

        emit LotteryNumberDrawn(
            currentLotteryId,
            finalNumber,
            numberAddressesInPreviousBracket
        );
    }

    /**
    @dev Inject funds into a specific lottery.
    @param _lotteryId uint256 ID of the lottery.
    @param _amount uint256 Amount of tokens to inject.
    */
    function injectFunds(
        uint256 _lotteryId,
        uint256 _amount
    ) external override whenNotPaused {
        require(
            _lotteries[_lotteryId].status == Status.Open,
            "RidottoLottery: Lottery is not open"
        );

        lotteryToken.transferFrom(address(msg.sender), address(this), _amount);
        _lotteries[_lotteryId].amountCollectedInLotteryToken += _amount;

        emit LotteryInjection(_lotteryId, _amount);
    }

    /**
     * @notice Set the auto injection status (Inject remaining funds to the next lottery)
     * @param _autoInjection: true if auto injection is enabled
     * @dev Callable only by the contract owner
     */

    /**
    @dev Set auto-injection status for the contract.
    @param _autoInjection Flag to enable/disable auto-injection.
    */
    function setAutoInjection(
        bool _autoInjection
    ) external onlyRole(OPERATOR_ROLE) {
        autoInjection = _autoInjection;
    }

    /**
    @notice Starts the initial round of lottery with the given parameters.
    @dev Can only be called by the operator.
    @param _TokenAddress The address of the token used to buy tickets.
    @param _lotteryPeriodicity The duration of each round in seconds.
    @param _incentivePercent The percentage of the prize pool to be given as an incentive.
    @param _priceTicketInLotteryToken The price of a ticket in the lottery token.
    @param _discountDivisor The discount divisor for early ticket purchases.
    @param _rewardsBreakdown The percentage of the prize pool to be distributed among the different brackets.
    @param _treasuryFee The percentage of the prize pool to be sent to the treasury.
    */
    function startInitialRound(
        address _TokenAddress,
        uint256 _lotteryPeriodicity,
        uint256 _incentivePercent,
        uint256 _priceTicketInLotteryToken,
        uint256 _discountDivisor,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external onlyRole(OPERATOR_ROLE) {
        require(providerId != 0, "RidottoLottery: RNG not set");
        require(
            treasuryAddress != address(0),
            "RidottoLottery: Treasury address not set"
        );
        require(
            currentLotteryId == 0,
            "RidottoLottery: Use startLottery() to start the lottery"
        );
        currentLotteryId++;

        require(
            (_priceTicketInLotteryToken >= minTicketPrice) &&
                (_priceTicketInLotteryToken <= maxTicketPrice),
            "RidottoLottery: Ticket price is outside the allowed limits"
        );
        require(
            _discountDivisor >= MIN_DISCOUNT_DIVISOR,
            "RidottoLottery: Discount divisor is too low"
        );

        require(
            _treasuryFee <= MAX_TREASURY_FEE,
            "RidottoLottery: Treasury fee is too high"
        );

        uint256 totalRewards;
        for (uint8 i = 0; i < _rewardsBreakdown.length; i++) {
            totalRewards += _rewardsBreakdown[i];
        }
        require(
            totalRewards == 10000,
            "RidottoLottery: Rewards distribution sum must equal 10000"
        );

        // Check that the incentive is not too high
        require(
            _incentivePercent < MAX_INCENTIVE_REWARD,
            "RidottoLottery: Incentive percent must be less than MAX_INCENTIVE_REWARD"
        );

        changeLotteryPeriodicity(_lotteryPeriodicity);
        lotteryToken = IERC20(_TokenAddress);
        incentivePercent = _incentivePercent;

        _lotteries[1] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: block.timestamp + lotteryPeriodicity,
            priceTicketInToken: _priceTicketInLotteryToken,
            discountDivisor: _discountDivisor,
            rewardsBreakdown: _rewardsBreakdown,
            treasuryFee: _treasuryFee,
            tokenPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            countWinnersPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstTicketId: 0,
            firstTicketIdNextLottery: 0,
            amountCollectedInLotteryToken: 0,
            finalNumber: 0,
            incentiveRewards: 0
        });

        pendingInjectionNextLottery = 0;

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _lotteries[currentLotteryId].endTime,
            _lotteries[currentLotteryId].priceTicketInToken,
            currentTicketId,
            pendingInjectionNextLottery
        );
    }

    /**
     * @dev Allows the operator to change the parameters of the next lottery round.
     * @param _startTime The start time of the next lottery round.
     * @param _priceTicketInLotteryToken The ticket price in lottery token for the next round.
     * @param _discountDivisor The discount divisor for the next round.
     * @param _rewardsBreakdown The rewards breakdown for the next round.
     * @param _treasuryFee The treasury fee for the next round.
     */
    function changeLotteryParams(
        uint256 _startTime,
        uint256 _priceTicketInLotteryToken,
        uint256 _discountDivisor,
        uint256[6] calldata _rewardsBreakdown,
        uint256 _treasuryFee
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            (_priceTicketInLotteryToken >= minTicketPrice) &&
                (_priceTicketInLotteryToken <= maxTicketPrice),
            "RidottoLottery: Ticket price is outside the allowed limits"
        );
        require(
            _discountDivisor >= MIN_DISCOUNT_DIVISOR,
            "RidottoLottery: Discount divisor is too low"
        );

        require(
            _treasuryFee <= MAX_TREASURY_FEE,
            "RidottoLottery: Treasury fee is too high"
        );

        uint256 totalRewards;
        for (uint8 i = 0; i < _rewardsBreakdown.length; i++) {
            totalRewards += _rewardsBreakdown[i];
        }
        require(
            totalRewards == 10000,
            "RidottoLottery: Rewards distribution sum must equal 10000"
        );

        require(
            _startTime > _lotteries[currentLotteryId].endTime,
            "RidottoLottery: Start time must be after the end of the current round"
        );

        require(
            _lotteries[currentLotteryId].status == Status.Open,
            "RidottoLottery: Lottery must be initialized"
        );

        _lotteries[currentLotteryId + 1] = Lottery({
            status: Status.Pending,
            startTime: _startTime,
            endTime: _startTime + lotteryPeriodicity,
            priceTicketInToken: _priceTicketInLotteryToken,
            discountDivisor: _discountDivisor,
            rewardsBreakdown: _rewardsBreakdown,
            treasuryFee: _treasuryFee,
            tokenPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            countWinnersPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstTicketId: 0,
            firstTicketIdNextLottery: 0,
            amountCollectedInLotteryToken: 0,
            finalNumber: 0,
            incentiveRewards: 0
        });

        nextLotteryParamchanged = true;
    }

    /**
     * @dev Starts the next round of the lottery, setting its parameters and status
     * @dev Transfers incentive rewards from previous round to the caller
     * @dev Emits a `LotteryOpen` event with information about the new round
     * @dev Reverts if it's not time to start the new round or if the initial round hasn't been started yet
     */
    function startLottery() external whenNotPaused {
        require(
            (_lotteries[currentLotteryId].status == Status.Claimable),
            "Not time to start lottery"
        );
        require(currentLotteryId != 0, "use startInitialRound function");
        require(
            _lotteries[currentLotteryId + 1].startTime <= block.timestamp,
            "Ridotto: Cannot start lottery yet"
        );

        Lottery memory previous = _lotteries[currentLotteryId];

        currentLotteryId++;

        Lottery memory newLottery = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: block.timestamp + lotteryPeriodicity,
            priceTicketInToken: previous.priceTicketInToken,
            discountDivisor: previous.discountDivisor,
            rewardsBreakdown: previous.rewardsBreakdown,
            treasuryFee: previous.treasuryFee,
            tokenPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            countWinnersPerBracket: [
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0),
                uint256(0)
            ],
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountCollectedInLotteryToken: pendingInjectionNextLottery,
            finalNumber: 0,
            incentiveRewards: 0
        });

        if (nextLotteryParamchanged == true) {
            _lotteries[currentLotteryId].status = Status.Open;
            _lotteries[currentLotteryId].firstTicketId = currentTicketId;
            _lotteries[currentLotteryId]
                .firstTicketIdNextLottery = currentTicketId;
            _lotteries[currentLotteryId]
                .amountCollectedInLotteryToken = pendingInjectionNextLottery;
            _lotteries[currentLotteryId].finalNumber = 0;
            nextLotteryParamchanged = false;
        } else {
            _lotteries[currentLotteryId] = newLottery;
        }

        lotteryToken.transfer(
            _msgSender(),
            _lotteries[currentLotteryId - 1].incentiveRewards / 3
        );

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _lotteries[currentLotteryId].endTime,
            _lotteries[currentLotteryId].priceTicketInToken,
            currentTicketId,
            pendingInjectionNextLottery
        );

        pendingInjectionNextLottery = 0;
    }

    /**
    @dev Allows the operator to recover any ERC20 tokens that were sent to the contract by mistake.
    @param _tokenAddress The address of the token to be recovered.
    @param _tokenAmount The amount of tokens to be recovered.
    */
    function recoverWrongTokens(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _tokenAddress != address(lotteryToken),
            "RidottoLottery: Cannot withdraw the lottery token"
        );

        IERC20(_tokenAddress).transfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
    @dev Sets the minimum and maximum ticket price in lottery token that can be used in the current lottery.
    @param _minPriceTicketInLotteryToken The minimum ticket price in lottery token.
    @param _maxPriceTicketInLotteryToken The maximum ticket price in lottery token.
    */
    function setMinAndMaxTicketPriceInLotteryToken(
        uint256 _minPriceTicketInLotteryToken,
        uint256 _maxPriceTicketInLotteryToken
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _minPriceTicketInLotteryToken <= _maxPriceTicketInLotteryToken,
            "RidottoLottery: The minimum price must be less than the maximum price"
        );

        minTicketPrice = _minPriceTicketInLotteryToken;
        maxTicketPrice = _maxPriceTicketInLotteryToken;
    }

    /**
    @dev Sets the maximum number of tickets per buy.
    @param _maxNumberTicketsPerBuy Maximum number of tickets per buy.
    */
    function setMaxNumberTicketsPerBuy(
        uint256 _maxNumberTicketsPerBuy
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _maxNumberTicketsPerBuy != 0,
            "RidottoLottery: The maximum number of tickets per buy must be greater than 0"
        );
        maxNumberTicketsPerBuy = _maxNumberTicketsPerBuy;
    }

    /**
    @dev Set the maximum number of tickets that can be claimed per claim.
    @param _maxNumberTicketsPerClaim The maximum number of tickets per claim.
    */
    function setMaxNumberTicketsPerClaim(
        uint256 _maxNumberTicketsPerClaim
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _maxNumberTicketsPerClaim != 0,
            "RidottoLottery: The maximum number of tickets per claim must be greater than 0"
        );
        maxNumberTicketsPerClaim = _maxNumberTicketsPerClaim;
    }

    /**
    @dev Set the treasury address where a percentage of the lottery earnings will be sent.
    Only the operator can call this function.
    @param _treasuryAddress The address of the new treasury wallet.
    */
    function setTreasuryAddress(
        address _treasuryAddress
    ) external onlyRole(OPERATOR_ROLE) {
        require(
            _treasuryAddress != address(0),
            "RidottoLottery: Treasury address cannot be the zero address"
        );

        treasuryAddress = _treasuryAddress;

        emit NewTreasuryAddresses(_treasuryAddress);
    }

    /**
    @dev Calculates the total price for a bulk purchase of tickets, including discounts.
    @param _discountDivisor The divisor for the discount. For example, a value of 1000 means a 10% discount.
    @param _priceTicket The price of a single ticket.
    @param _numberTickets The number of tickets being purchased.
    @return The total price for the bulk ticket purchase, including any discounts.
    */
    function calculateTotalPriceForBulkTickets(
        uint256 _discountDivisor,
        uint256 _priceTicket,
        uint256 _numberTickets
    ) external pure returns (uint256) {
        require(
            _discountDivisor >= MIN_DISCOUNT_DIVISOR,
            "Must be >= MIN_DISCOUNT_DIVISOR"
        );
        require(_numberTickets != 0, "Number of tickets must be > 0");

        return
            _calculateTotalPriceForBulkTickets(
                _discountDivisor,
                _priceTicket,
                _numberTickets
            );
    }

    /**
    @dev View the information of a lottery by ID
    @param _lotteryId The ID of the lottery to view
    @return Lottery The lottery information, as a struct
    */
    function viewLottery(
        uint256 _lotteryId
    ) external view returns (Lottery memory) {
        return _lotteries[_lotteryId];
    }

    /**
    @dev View function that returns an array of ticket numbers and their statuses for an array of ticket IDs.
    @param _ticketIds An array of ticket IDs.
    @return A tuple of arrays containing the ticket numbers and their statuses, in the same order as the input array.
    */
    function viewNumbersAndStatusesForTicketIds(
        uint256[] calldata _ticketIds
    ) external view returns (uint32[] memory, bool[] memory) {
        uint256 length = _ticketIds.length;
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            ticketNumbers[i] = _tickets[_ticketIds[i]].number;
            if (_tickets[_ticketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                ticketStatuses[i] = false;
            }
        }

        return (ticketNumbers, ticketStatuses);
    }

    /**
     * @dev View the rewards for a specific lottery ticket.
     * @param _lotteryId ID of the lottery.
     * @param _ticketId ID of the ticket.
     * @param _bracket Bracket to check the ticket against.
     * @return The reward amount for the ticket and bracket.
     */
    function viewRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) external view returns (uint256) {
        // Check lottery is in claimable status
        if (_lotteries[_lotteryId].status != Status.Claimable) {
            return 0;
        }

        // Check ticketId is within range
        if (
            (_lotteries[_lotteryId].firstTicketIdNextLottery < _ticketId) &&
            (_lotteries[_lotteryId].firstTicketId >= _ticketId)
        ) {
            return 0;
        }

        return _calculateRewardsForTicketId(_lotteryId, _ticketId, _bracket);
    }

    /**
     * @notice View user ticket ids, numbers, and statuses of user for a given lottery
     * @param _user: user address
     * @param _lotteryId: lottery id
     * @param _cursor: cursor to start where to retrieve the tickets
     * @param _size: the number of tickets to retrieve
     * @return lotteryTicketIds: array of ticket ids
     * @return ticketNumbers: array of ticket numbers
     * @return ticketStatuses: array of bools indicating if a ticket is claimed or not
     * @return _cursor + length: the cursor to use for next batch
     */
    function viewUserInfoForLotteryId(
        address _user,
        uint256 _lotteryId,
        uint256 _cursor,
        uint256 _size
    )
        external
        view
        returns (uint256[] memory, uint32[] memory, bool[] memory, uint256)
    {
        uint256 length = _size;
        uint256 numberTicketsBoughtAtLotteryId = _userTicketIdsPerLotteryId[
            _user
        ][_lotteryId].length;

        if (length > (numberTicketsBoughtAtLotteryId - _cursor)) {
            length = numberTicketsBoughtAtLotteryId - _cursor;
        }

        uint256[] memory lotteryTicketIds = new uint256[](length);
        uint32[] memory ticketNumbers = new uint32[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            lotteryTicketIds[i] = _userTicketIdsPerLotteryId[_user][_lotteryId][
                i + _cursor
            ];
            ticketNumbers[i] = _tickets[lotteryTicketIds[i]].number;

            // True = ticket claimed
            if (_tickets[lotteryTicketIds[i]].owner == address(0)) {
                ticketStatuses[i] = true;
            } else {
                // ticket not claimed (includes the ones that cannot be claimed)
                ticketStatuses[i] = false;
            }
        }

        return (
            lotteryTicketIds,
            ticketNumbers,
            ticketStatuses,
            _cursor + length
        );
    }

    /**
    @notice Calculate rewards for a ticket and bracket for a given lotteryId
    @param _lotteryId: lottery id
    @param _ticketId: ticket id to calculate rewards for
    @param _bracket: bracket number
    @return the rewards amount of the ticket and bracket
    */
    function _calculateRewardsForTicketId(
        uint256 _lotteryId,
        uint256 _ticketId,
        uint32 _bracket
    ) internal view returns (uint256) {
        // Retrieve the winning number combination
        uint32 userNumber = _lotteries[_lotteryId].finalNumber;

        // Retrieve the user number combination from the ticketId
        uint32 winningTicketNumber = _tickets[_ticketId].number;

        // Apply transformation to verify the claim provided by the user is true
        uint32 transformedWinningNumber = _bracketCalculator[_bracket] +
            (winningTicketNumber % (uint32(10) ** (_bracket + 1)));

        uint32 transformedUserNumber = _bracketCalculator[_bracket] +
            (userNumber % (uint32(10) ** (_bracket + 1)));

        // Confirm that the two transformed numbers are the same, if not throw
        if (transformedWinningNumber == transformedUserNumber) {
            return _lotteries[_lotteryId].tokenPerBracket[_bracket];
        } else {
            return 0;
        }
    }

    /**
    @notice Calculates the total price in lottery token for purchasing multiple tickets with a discount
    @param _discountDivisor: the discount divisor used for the calculation
    @param _priceTicket: the price for each ticket in lottery token
    @param _numberTickets: the number of tickets being purchased
    @return The total price in lottery token for purchasing multiple tickets with a discount
    */
    function _calculateTotalPriceForBulkTickets(
        uint256 _discountDivisor,
        uint256 _priceTicket,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return
            (_priceTicket *
                _numberTickets *
                (_discountDivisor + 1 - _numberTickets)) / _discountDivisor;
    }

    /**
    @notice Internal function to check if an address is a contract
    @param _addr: Address to check
    @return bool: True if the address is a contract, false otherwise
    */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
    @notice Generate an array of random numbers for a user
    @param _from: address of user requesting random numbers
    @param _count: number of random numbers to generate
    @return an array of randomly generated numbers
    */
    function getRandomNumbers(
        address _from,
        uint256 _count
    ) public view returns (uint32[] memory) {
        uint32[] memory numbers = new uint32[](_count);
        uint256 randSeed = uint256(
            keccak256(abi.encodePacked(block.number, block.timestamp, _from))
        );
        for (uint256 i = 0; i < _count; i++) {
            uint32 randomNumber = uint32(
                uint256(keccak256(abi.encode(randSeed, i))) % 1000000
            ) + 1000000;
            numbers[i] = randomNumber;
        }
        return numbers;
    }

    /**
     * @notice Pause the contract
     * @dev Only callable by an operator
     * @dev Reverts if the contract is already paused
     */
    function pause() external onlyRole(OPERATOR_ROLE) {
        require(!paused(), "RidottoLottery: Contract already paused");
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev Can only be called by an address with the OPERATOR_ROLE
     * @dev Throws an error if the contract is not paused
     */
    function unPause() external onlyRole(OPERATOR_ROLE) {
        require(paused(), "RidottoLottery: Contract already Unpaused");
        _unpause();
    }
}
