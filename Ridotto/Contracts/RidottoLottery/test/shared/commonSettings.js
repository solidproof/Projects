const { ethers } = require("ethers");
const { randomBytes } = require("crypto");

const lotto = {
  lotteryToken: {
    supply: ethers.utils.parseUnits("10000000", 18),
    transferAmt: ethers.utils.parseUnits("50000", 18),
  },

  setup: {
    periodicity: 12 * 60 * 60,
    discountDiv: 300,
    distribution: [1000, 2000, 2000, 3000, 1000, 1000],
    treasuryFee: 300,
    incentivePercent: 100,
    ticketPrice: ethers.utils.parseUnits("5", 18),
    errorData: {
      errorDistributionLength: [1000, 2000, 1000, 3000, 1000],
      errorDistribution: [1000, 1000, 2000, 2000, 1000, 1000],
    },
  },
  secondSetup: {
    discountDiv: 3000,
    distribution: [2000, 2000, 2000, 2000, 1000, 1000],
    treasuryFee: 2000,
    incentivePercent: 300,
    ticketPrice: ethers.utils.parseUnits("10", 18),
  },

  rng: {
    number: Math.floor(Math.random() * 10) + 1,
  },
  errorMsgs: {
    initialRound: "RidottoLottery: Use startLottery() to start the lottery",
    rngNotSet: "RidottoLottery",
    treasuryAddressNotSet: "RidottoLottery: Treasury address not set",
    errorDistribution:
      "RidottoLottery: Rewards distribution sum must equal 10000",
    errorIncentivePercent:
      "RidottoLottery: Incentive percent must be less than MAX_INCENTIVE_REWARD",
    errorTicketprice:
      "RidottoLottery: Ticket price is outside the allowed limits",
    errorDiscountDiv: "RidottoLottery: Discount divisor is too low",
    errorTreasuryFee: "RidottoLottery: Treasury fee is too high",
    errorStartTime:
      "RidottoLottery: Start time must be after the end of the current round",
    errorEndTime: "RidottoLottery: End time must be in the future",
    lotteryIsNotOpen: "RidottoLottery: Lottery is not open",
    lotteryIsOver: "RidottoLottery: Lottery is over",
    cannotBuyTicketReachMax: "RidottoLottery: Can only buy 6 tickets at once",
    pendingRngCall: "RidottoLottery: Pending RNG call",
    incorrectRngAddress: "RidottoLottery: Invalid address",
    errorMinMaxTicketPrice:
      "RidottoLottery: The minimum price must be less than the maximum price",
    errorMaxNumberTicketsPerBuy:
      "RidottoLottery: The maximum number of tickets per buy must be greater than 0",
    errorMaxNumberTicketsPerClaim:
      "RidottoLottery: The maximum number of tickets per claim must be greater than 0",
    errorTreasuryAddress:
      "RidottoLottery: Treasury address cannot be the zero address",
    errorTooManyReceivers: "RidottoLottery: Too many receivers",
    errorBuyForOtherInvalidInputs: "RidottoLottery: Invalid inputs",
    errorBuyForOtherMaxTicketNumber: "RidottoLottery: Too many tickets",
    subscribeClosedLotteryError:
      "RidotoLottery: Cannot subscribe to a closed or ongoing lottery",
    errorLotteryNotInitialized: "RidottoLottery: Lottery must be initialized",
    cannotStartLottery: "Ridotto: Cannot start lottery yet",
    cannotRecoverLotteryTokenError:
      "RidottoLottery: Cannot withdraw the lottery token",
    invalidLotteryPeriodicity: "RidottoLottery: Invalid lottery periodicity",
    claimTicketNotOnwer: "RidottoLottery: Caller isn't  the ticket owner",
    claimTicketWrongInputs: "RidottoLottery: Invalid inputs",
    claimTicketIdsLenght: "RidottoLottery: _ticketIds.length must be >0",
    claimTicketIdsLenghtMax: "RidottoLottery: Too many tickets to claim",
    claimTicketLotteryNotClaimable: "RidottoLottery: Lottery is not claimable",
    claimTicketLotteryNoPrize: "RidottoLottery: No prize for this bracket",
    alreadyPaused: "RidottoLottery: Contract already paused",
    alreadyUnPaused: "RidottoLottery: Contract already Unpaused",
    isPausedError: "Pausable: paused",
  },
};

const chainlinkRngProvider = {
  setup: {
    name: "chainlink",
    isActive: true,
    gasLimit: 100000,
    paramData: [0, 0, 0, 0, 0, 0],
    keyHash: randomBytes(32),
    minimumRequestConfirmations: 4,
    numWords: 1,
    baseFee: 1,
    gasPriceLink: 1,
  },
};

function calculateEligibleBracket(winningNumber, ticketNumber) {
  const winningDigits = winningNumber.toString().split("").reverse();
  const ticketDigits = ticketNumber.toString().split("").reverse();

  if (winningDigits.length !== ticketDigits.length) {
    throw new Error(
      "Winning number and ticket number must have the same length."
    );
  }

  let matches = 0;
  for (let i = 0; i < winningDigits.length - 1; i++) {
    if (winningDigits[i] === ticketDigits[i]) {
      matches++;
    } else {
      break;
    }
  }
  return matches;
}

function calculateDiscountPrice(discountDiv, price, noOfTickets) {
  return (price * noOfTickets * (discountDiv + 1 - noOfTickets)) / discountDiv;
}

function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function generateWalletAddresses(n) {
  const addresses = [];
  for (let i = 0; i < n; i++) {
    const randomWallet = ethers.Wallet.createRandom();
    addresses.push(randomWallet.address);
  }
  return addresses;
}
function generateRandomIntArrayWithSum(item, length) {
  return new Array(length).fill(item);
}

module.exports = {
  lotto,
  chainlinkRngProvider,
  calculateDiscountPrice,
  calculateEligibleBracket,
  getRandomInt,
  generateWalletAddresses,
  generateRandomIntArrayWithSum,
};
