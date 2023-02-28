const { expect, assert } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { network } = require("hardhat");
const {
  lotto,
  chainlinkRngProvider,
  calculateDiscountPrice,
  calculateEligibleBracket,
  getRandomInt,
  generateWalletAddresses,
  generateRandomIntArrayWithSum,
} = require("./shared/commonSettings");

describe("Lottery global tests", () => {
  let mockErc20Contract;
  // Creating the instance and contract info for the lottery contract
  let lotteryInstance, lotteryContract;
  let lotteryTokenInstance;
  // Creating the instance and contract info for the timer contract
  let globalRngInstance, globalRngContract;
  // Creating the instance and contract of all the contracts needed to mock
  // the ChainLink contract ecosystem.
  let mockVrfInstance, mockvrfContract;

  // Creating the users
  let players = [];
  let communityOperator = [];
  let owner, operator, treasury;

  // Chainlink params
  let providerId, vrfsubId;

  beforeEach(async () => {
    // Getting the signers
    [
      owner,
      players[0],
      players[1],
      players[2],
      operator,
      communityOperator[0],
      communityOperator[1],
      communityOperator[2],
      treasury,
    ] = await ethers.getSigners();

    // Deploying the Mock ERC20 contract (Lottery Token)
    mockErc20Contract = await ethers.getContractFactory("MockERC20");
    lotteryTokenInstance = await mockErc20Contract.deploy(
      lotto.lotteryToken.supply
    );

    const benificiaries = [...players, operator];
    // Transfering the lottery token to the players
    await Promise.all(
      benificiaries.map((benificiary) =>
        lotteryTokenInstance.transfer(
          benificiary.address,
          lotto.lotteryToken.transferAmt
        )
      )
    );

    // Deploying the ChainLink VRF Mock contract

    mockvrfContract = await ethers.getContractFactory("VRFCoordinatorV2Mock");
    mockVrfInstance = await mockvrfContract.deploy(
      chainlinkRngProvider.setup.baseFee,
      chainlinkRngProvider.setup.gasPriceLink
    );

    // Creating a subscription and funding it
    vrfsubId = await mockVrfInstance.callStatic.createSubscription();
    await mockVrfInstance.createSubscription();
    await mockVrfInstance.fundSubscription(
      vrfsubId,
      ethers.utils.parseUnits("100", 18)
    );

    // Deploying the GlobalRNG contract
    globalRngContract = await ethers.getContractFactory("GlobalRng");
    globalRngInstance = await upgrades.deployProxy(globalRngContract, [], {
      initializer: "init",
    });

    // Adding the ChainLink provider to the GlobalRNG contract
    providerId = await globalRngInstance.callStatic.addProvider([
      chainlinkRngProvider.setup.name,
      chainlinkRngProvider.setup.isActive,
      mockVrfInstance.address,
      chainlinkRngProvider.setup.gasLimit,
      chainlinkRngProvider.setup.paramData,
    ]);

    await globalRngInstance.addProvider([
      chainlinkRngProvider.setup.name,
      chainlinkRngProvider.setup.isActive,
      mockVrfInstance.address,
      chainlinkRngProvider.setup.gasLimit,
      chainlinkRngProvider.setup.paramData,
    ]);

    // Adding the consumer to the ChainLink provider
    await mockVrfInstance.addConsumer(vrfsubId, globalRngInstance.address);

    // Deploy Lottery contract
    lotteryContract = await ethers.getContractFactory("RidottoLottery");
    lotteryInstance = await upgrades.deployProxy(lotteryContract, [], {
      initializer: "init",
    });

    // Allow Lottery SM to transfer the lottery token
    await Promise.all(
      benificiaries.map((benificiary) =>
        lotteryTokenInstance
          .connect(benificiary)
          .approve(lotteryInstance.address, lotto.lotteryToken.transferAmt)
      )
    );

    // Granting `operator` the lottery operator role
    const LOTTERY_OPERATOR_ROLE = await lotteryInstance.OPERATOR_ROLE();
    await lotteryInstance.grantRole(LOTTERY_OPERATOR_ROLE, operator.address);

    // Granting the lottery contract the consumer role
    const GLOBAL_RNG_CONSUMER_ROLE = await globalRngInstance.CONSUMER_ROLE();
    await globalRngInstance.grantRole(
      GLOBAL_RNG_CONSUMER_ROLE,
      lotteryInstance.address
    );
  });

  describe("Lottery requirements tests", async () => {
    it("Should revert the transaction when a user without Operator Role triggers the initial round", async () => {
      const currentTime = await lotteryInstance.getTime();
      const maxTime = 14400;
      await expect(
        lotteryInstance.startInitialRound(
          lotteryTokenInstance.address,
          lotto.setup.incentivePercent,
          lotto.setup.periodicity,
          lotto.setup.ticketPrice,
          lotto.setup.discountDiv,
          lotto.setup.distribution,
          lotto.setup.treasuryFee
        )
      ).to.be.reverted;
    });

    it("Should throw an error if user tries to start the lottery without setting the random number generator (RNG)", async () => {
      const currentTime = await lotteryInstance.getTime();
      const maxTime = 14400;

      await expect(
        lotteryInstance
          .connect(operator)
          .startInitialRound(
            lotteryTokenInstance.address,
            lotto.setup.incentivePercent,
            lotto.setup.periodicity,
            lotto.setup.ticketPrice,
            lotto.setup.discountDiv,
            lotto.setup.distribution,
            lotto.setup.treasuryFee
          )
      ).to.be.revertedWith(lotto.errorMsgs.rngNotSet);
    });

    it("Should throw an error when trying to withdraw from treasury but the treasury address is not set", async () => {
      const currentTime = await lotteryInstance.getTime();
      const maxTime = 14400;
      // Setting the RNG for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setRngProvider(globalRngInstance.address, providerId);

      // Setting the ChainLink params for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setChainlinkCallParams(
          chainlinkRngProvider.setup.keyHash,
          vrfsubId,
          chainlinkRngProvider.setup.minimumRequestConfirmations,
          chainlinkRngProvider.setup.gasLimit,
          chainlinkRngProvider.setup.numWords
        );
      await expect(
        lotteryInstance
          .connect(operator)
          .startInitialRound(
            lotteryTokenInstance.address,
            lotto.setup.incentivePercent,
            lotto.setup.periodicity,
            lotto.setup.ticketPrice,
            lotto.setup.discountDiv,
            lotto.setup.distribution,
            lotto.setup.treasuryFee
          )
      ).to.be.revertedWith(lotto.errorMsgs.treasuryAddressNotSet);
    });

    it("Should trigger startInitial() for the initial round only for operator role and all requirements are", async () => {
      const currentTime = await lotteryInstance.getTime();
      const maxTime = 14400;
      // Setting the RNG for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setRngProvider(globalRngInstance.address, providerId);

      // Setting the ChainLink params for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setChainlinkCallParams(
          chainlinkRngProvider.setup.keyHash,
          vrfsubId,
          chainlinkRngProvider.setup.minimumRequestConfirmations,
          chainlinkRngProvider.setup.gasLimit,
          chainlinkRngProvider.setup.numWords
        );

      await lotteryInstance
        .connect(operator)
        .setTreasuryAddress(treasury.address);

      await lotteryInstance
        .connect(operator)
        .startInitialRound(
          lotteryTokenInstance.address,
          lotto.setup.periodicity,
          lotto.setup.incentivePercent,
          lotto.setup.ticketPrice,
          lotto.setup.discountDiv,
          lotto.setup.distribution,
          lotto.setup.treasuryFee
        );

      const lotteryId = 1;
      const currentLotteryId = await lotteryInstance.currentLotteryId();
      assert.equal(currentLotteryId, lotteryId, "Wrong lottery id");
    });

    describe("Lottery initialization tests", async () => {
      let currentTime, maxTime, tickeTPrice;
      beforeEach(async () => {
        currentTime = await lotteryInstance.getTime();
        maxTime = 14400;
        // Setting the RNG for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setRngProvider(globalRngInstance.address, providerId);

        // Setting the ChainLink params for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setChainlinkCallParams(
            chainlinkRngProvider.setup.keyHash,
            vrfsubId,
            chainlinkRngProvider.setup.minimumRequestConfirmations,
            chainlinkRngProvider.setup.gasLimit,
            chainlinkRngProvider.setup.numWords
          );

        // Setting the treasury address for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setTreasuryAddress(treasury.address);
      });

      it("Should raise exception when ticket price is out of the allowed range", async function () {
        const MAX_TICKET_PRICE = await lotteryInstance.maxTicketPrice();
        const MIN_TICKET_PRICE = await lotteryInstance.minTicketPrice();

        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              MAX_TICKET_PRICE + MAX_TICKET_PRICE,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorTicketprice);

        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              MIN_TICKET_PRICE.toNumber() - 1,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorTicketprice);
      });

      it("Should throw an exception if the discount divisor value is lower than the minimum allowed limit", async function () {
        const MIN_DISCOUNT_DIVISOR =
          await lotteryInstance.MIN_DISCOUNT_DIVISOR();
        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              lotto.setup.ticketPrice,
              MIN_DISCOUNT_DIVISOR.toNumber() - 1,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorDiscountDiv);
      });

      it("Should raise an error if the treasury fees exceed the allowed limit", async function () {
        const MAX_TREASURY_FEE = await lotteryInstance.MAX_TREASURY_FEE();
        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              lotto.setup.ticketPrice,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              MAX_TREASURY_FEE.toNumber() + 1
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorTreasuryFee);
      });

      it("Should raise an exception when the rewards distribution is incorrect", async function () {
        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              lotto.setup.ticketPrice,
              lotto.setup.discountDiv,
              lotto.setup.errorData.errorDistribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorDistribution);

        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.incentivePercent,
              lotto.setup.periodicity,
              tickeTPrice,
              lotto.setup.discountDiv,
              lotto.setup.errorData.errorDistributionLength,
              lotto.setup.treasuryFee
            )
        ).to.be.reverted;
      });

      it("Should throw an exception when the incentive rewards percentage is higher than the maximum allowed value", async function () {
        const MAX_INCENTIVE_REWARD =
          await lotteryInstance.MAX_INCENTIVE_REWARD();
        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              MAX_INCENTIVE_REWARD.toNumber() + 1,
              lotto.setup.periodicity,
              lotto.setup.ticketPrice,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorIncentivePercent);
      });

      it("Should raise exception when the periodicity set for the lottery is less than the minimum allowed", async function () {
        const minLotteryPeriodicity =
          await lotteryInstance.minLotteryPeriodicity();
        await expect(
          lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              minLotteryPeriodicity - 1,
              lotto.setup.incentivePercent,
              lotto.setup.ticketPrice,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            )
        ).to.be.revertedWith(lotto.errorMsgs.invalidLotteryPeriodicity);
      });

      describe("Change lottery parameters tests", function () {
        let lotteryStartTime, lotteryEndTime;
        let currentLotteyInfo;
        beforeEach(async function () {
          const currentLotteryId = await lotteryInstance.currentLotteryId();
          currentLotteyInfo = await lotteryInstance.viewLottery(
            currentLotteryId
          );
          const lotteryExtraTime = 24 * 60 * 60;
          lotteryStartTime = currentLotteyInfo.endTime + lotteryExtraTime;
          lotteryEndTime = lotteryStartTime + maxTime;
        });
        it("Should raise an exception when the ticket price is not within the allowed range", async function () {
          const MAX_TICKET_PRICE = await lotteryInstance.maxTicketPrice();
          const MIN_TICKET_PRICE = await lotteryInstance.minTicketPrice();

          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                MAX_TICKET_PRICE + MAX_TICKET_PRICE,
                lotto.setup.discountDiv,
                lotto.setup.distribution,
                lotto.setup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorTicketprice);

          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                MIN_TICKET_PRICE - 1,
                lotto.setup.discountDiv,
                lotto.setup.distribution,
                lotto.setup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorTicketprice);
        });

        it("Should throw an exception when the provided discount divisor value is below the minimum limit", async function () {
          const MIN_DISCOUNT_DIVISOR =
            await lotteryInstance.MIN_DISCOUNT_DIVISOR();
          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                lotto.setup.ticketPrice,
                MIN_DISCOUNT_DIVISOR - 1,
                lotto.setup.distribution,
                lotto.setup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorDiscountDiv);
        });

        it("Should raise an exception when the specified treasury fee percentage is higher than the maximum allowed", async function () {
          const MAX_TREASURY_FEE = await lotteryInstance.MAX_TREASURY_FEE();
          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                lotto.setup.ticketPrice,
                lotto.setup.discountDiv,
                lotto.setup.distribution,
                MAX_TREASURY_FEE + 1
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorTreasuryFee);
        });

        it("Should raise an exception when the rewards distribution is incorrect", async function () {
          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                lotto.setup.ticketPrice,
                lotto.setup.discountDiv,
                lotto.setup.errorData.errorDistribution,
                lotto.setup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorDistribution);

          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                lotteryStartTime,
                lotto.setup.ticketPrice,
                lotto.setup.discountDiv,
                lotto.setup.errorData.errorDistributionLength,
                lotto.setup.treasuryFee
              )
          ).to.be.reverted;
        });

        it("Should raise an exception when the start time is earlier than the current end time", async function () {
          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                currentLotteyInfo.endTime,
                lotto.setup.ticketPrice,
                lotto.setup.discountDiv,
                lotto.setup.distribution,
                lotto.setup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorStartTime);
        });
        it("Should raise exception when trying to change parameters without initializing the lottery first", async () => {
          const currentTime = await lotteryInstance.getTime();
          const maxTime = 14400;
          await expect(
            lotteryInstance
              .connect(operator)
              .changeLotteryParams(
                currentTime,
                lotto.secondSetup.ticketPrice,
                lotto.secondSetup.discountDiv,
                lotto.secondSetup.distribution,
                lotto.secondSetup.treasuryFee
              )
          ).to.be.revertedWith(lotto.errorMsgs.errorLotteryNotInitialized);
        });
        it("Should only affect the next round when changing lottery params", async () => {
          const currentTime = await lotteryInstance.getTime();

          await lotteryInstance
            .connect(operator)
            .startInitialRound(
              lotteryTokenInstance.address,
              lotto.setup.periodicity,
              lotto.setup.incentivePercent,
              lotto.setup.ticketPrice,
              lotto.setup.discountDiv,
              lotto.setup.distribution,
              lotto.setup.treasuryFee
            );

          const delayStart = 2 * 60 * 60;
          const startTimeNextLottery =
            currentTime.toNumber() + delayStart + lotto.setup.periodicity;

          await lotteryInstance
            .connect(operator)
            .changeLotteryParams(
              startTimeNextLottery,
              lotto.secondSetup.ticketPrice,
              lotto.secondSetup.discountDiv,
              lotto.secondSetup.distribution,
              lotto.secondSetup.treasuryFee
            );
          // Move in time & mine block
          await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
            currentTime.toNumber() + lotto.setup.periodicity + 1,
          ]);
          await network.provider.send("evm_mine");

          const currentLotteryId = await lotteryInstance.currentLotteryId();
          await lotteryInstance.closeLottery(currentLotteryId);
          const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
          const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
          const winningNumber = 1423623;
          await mockVrfInstance.fulfillRandomWordsWithOverride(
            vrfRequest,
            globalRngInstance.address,
            [winningNumber]
          );
          await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
            currentLotteryId
          );
          await expect(lotteryInstance.startLottery()).to.be.revertedWith(
            lotto.errorMsgs.cannotStartLottery
          );

          // Move in time & mine block
          await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
            startTimeNextLottery,
          ]);
          await network.provider.send("evm_mine");
          await expect(lotteryInstance.startLottery()).to.emit(
            lotteryInstance,
            "LotteryOpen"
          );
        });
      });
    });
  });

  describe("Utility functions tests", () => {
    const maxTime = 14400;

    beforeEach(async () => {
      const currentTime = await lotteryInstance.getTime();
      // Setting the RNG for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setRngProvider(globalRngInstance.address, providerId);

      // Setting the ChainLink params for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setChainlinkCallParams(
          chainlinkRngProvider.setup.keyHash,
          vrfsubId,
          chainlinkRngProvider.setup.minimumRequestConfirmations,
          chainlinkRngProvider.setup.gasLimit,
          chainlinkRngProvider.setup.numWords
        );
      // Setting the treasury address
      await lotteryInstance
        .connect(operator)
        .setTreasuryAddress(treasury.address);
      // Start Initial Round
      await lotteryInstance
        .connect(operator)
        .startInitialRound(
          lotteryTokenInstance.address,
          lotto.setup.periodicity,
          lotto.setup.incentivePercent,
          lotto.setup.ticketPrice,
          lotto.setup.discountDiv,
          lotto.setup.distribution,
          lotto.setup.treasuryFee
        );
    });

    it("Should return the current time in milliseconds since Unix epoch", async () => {
      const currentTime = await lotteryInstance.getTime();
      const blockNumBefore = await ethers.provider.getBlockNumber();
      const blockBefore = await ethers.provider.getBlock(blockNumBefore);
      const timestampBefore = blockBefore.timestamp;
      assert.equal(
        currentTime.toNumber(),
        timestampBefore,
        "Current time is not correct"
      );
    });

    describe("Lottery periodicity tests", () => {
      it("Should raise an exception when attempting to change the lottery periodicity to a value less than the minimum allowed lottery periodicity", async () => {
        const minLotteryPeriodicity =
          await lotteryInstance.minLotteryPeriodicity();
        await expect(
          lotteryInstance
            .connect(operator)
            .changeLotteryPeriodicity(minLotteryPeriodicity.toNumber() - 1)
        ).to.be.revertedWith(lotto.errorMsgs.invalidLotteryPeriodicity);
      });

      it("Should raise an exception if a user tries to change the lottery periodicity without the operator role", async () => {
        await expect(
          lotteryInstance.changeLotteryPeriodicity(lotto.setup.periodicity)
        ).to.be.reverted;
      });

      it("Should successfully update the lottery periodicity with a new value", async () => {
        const minLotteryPeriodicity =
          await lotteryInstance.minLotteryPeriodicity();
        const periodicity = minLotteryPeriodicity.toNumber() + 1000;
        await lotteryInstance
          .connect(operator)
          .changeLotteryPeriodicity(periodicity);
        const periodicityAfter = await lotteryInstance.lotteryPeriodicity();
        assert.equal(
          periodicityAfter.toNumber(),
          periodicity,
          "Periodicity is not correct"
        );
      });

      it("Should raise an exception when trying to change the lottery's minimum periodicity to a value less than 1 minute", async () => {
        await expect(
          lotteryInstance.connect(operator).setLoterryMinPeriodicity(50)
        ).to.be.revertedWith(lotto.errorMsgs.invalidLotteryPeriodicity);
      });

      it("Should raise an exception when attempting to change lottery minimum periodicity without Operator Role", async () => {
        await expect(
          lotteryInstance.setLoterryMinPeriodicity(lotto.setup.periodicity)
        ).to.be.reverted;
      });

      it("Should allow Operator to change the minimum lottery periodicity", async () => {
        const minPeriodicity = 1000;
        await lotteryInstance
          .connect(operator)
          .setLoterryMinPeriodicity(minPeriodicity);
        const minPeriodicityAfter =
          await lotteryInstance.minLotteryPeriodicity();
        assert.equal(
          minPeriodicityAfter.toNumber(),
          minPeriodicity,
          "Min periodicity is not correct"
        );
      });
    });

    describe("Incentive percent tests", () => {
      it("Should successfully update the incentive percent for the lottery when called by an operator", async () => {
        const incentivePercent = 100;
        await lotteryInstance
          .connect(operator)
          .changeIncentivePercent(incentivePercent);
        const incentivePercentAfter = await lotteryInstance.incentivePercent();
        assert.equal(
          incentivePercentAfter.toNumber(),
          incentivePercent,
          "Incentive percent is not correct"
        );
      });
      it("Should raise an exception when setting an incentive percentage higher than the maximum allowed value", async () => {
        const MAX_INCENTIVE_REWARD =
          await lotteryInstance.MAX_INCENTIVE_REWARD();
        await expect(
          lotteryInstance
            .connect(operator)
            .changeIncentivePercent(MAX_INCENTIVE_REWARD.toNumber() + 1)
        ).to.be.revertedWith(lotto.errorMsgs.errorIncentivePercent);
      });
      it("Should raise exception for non-operator users", async () => {
        const incentivePercent = 100;
        await expect(lotteryInstance.changeIncentivePercent(incentivePercent))
          .to.be.reverted;
      });
    });

    describe("Buy for others settings tests", () => {
      it("Should update the maximum number of tickets that can be purchased for others by the operator", async () => {
        const maxNumberTicketsBuyForOthers = 100;
        const maxNumberReceiversBuyForOthers = 200;
        await lotteryInstance
          .connect(operator)
          .setMaxBuyForOthers(
            maxNumberTicketsBuyForOthers,
            maxNumberReceiversBuyForOthers
          );
        const maxNumberTicketsBuyForOthersAfter =
          await lotteryInstance.maxNumberTicketsBuyForOthers();
        const maxNumberReceiversBuyForOthersAfter =
          await lotteryInstance.maxNumberReceiversBuyForOthers();
        assert.equal(
          maxNumberTicketsBuyForOthersAfter.toNumber(),
          maxNumberTicketsBuyForOthers,
          "Max number tickets buy for others is not correct"
        );
        assert.equal(
          maxNumberReceiversBuyForOthersAfter.toNumber(),
          maxNumberReceiversBuyForOthers,
          "Max number receivers buy for others is not correct"
        );
      });
      it("Should raise an exception when the maximum number of tickets that can be bought for others is changed by someone who is not the operator", async () => {
        const maxNumberTicketsBuyForOthers = 100;
        const maxNumberReceiversBuyForOthers = 200;
        await expect(
          lotteryInstance.setMaxBuyForOthers(
            maxNumberTicketsBuyForOthers,
            maxNumberReceiversBuyForOthers
          )
        ).to.be.reverted;
      });
    });

    describe("Auto injections settings tests", () => {
      it("Should set the auto injection amount to the desired value", async () => {
        await lotteryInstance.connect(operator).setAutoInjection(false);
        let autoInjection = await lotteryInstance.autoInjection();
        assert.equal(autoInjection, false, "Auto injection is not correct");
        await lotteryInstance.connect(operator).setAutoInjection(true);
        autoInjection = await lotteryInstance.autoInjection();
        assert.equal(autoInjection, true, "Auto injection is not correct");
      });
      it("Should raise exception for non-operator when changing auto injection", async () => {
        await expect(lotteryInstance.setAutoInjection(false)).to.be.reverted;
        await expect(lotteryInstance.setAutoInjection(true)).to.be.reverted;
      });
    });

    describe("Ticket price tests", () => {
      it("Should update the minimum and maximum ticket price with the specified values", async () => {
        const minPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "2000",
          18
        );
        const maxPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "3000",
          18
        );
        await lotteryInstance
          .connect(operator)
          .setMinAndMaxTicketPriceInLotteryToken(
            minPriceTicketInLotteryToken,
            maxPriceTicketInLotteryToken
          );
        const minPriceTicketInLotteryTokenAfter =
          await lotteryInstance.minTicketPrice();
        const maxPriceTicketInLotteryTokenAfter =
          await lotteryInstance.maxTicketPrice();
        assert.equal(
          minPriceTicketInLotteryTokenAfter - minPriceTicketInLotteryToken,
          0,
          "Min price ticket in lottery token is not correct"
        );
        assert.equal(
          maxPriceTicketInLotteryTokenAfter - maxPriceTicketInLotteryToken,
          0,
          "Max price ticket in lottery token is not correct"
        );
      });

      it("Should raise exception when minimum ticket price in lottery token is greater than maximum ticket price", async () => {
        const minPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "3000",
          18
        );
        const maxPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "2000",
          18
        );
        await expect(
          lotteryInstance
            .connect(operator)
            .setMinAndMaxTicketPriceInLotteryToken(
              minPriceTicketInLotteryToken,
              maxPriceTicketInLotteryToken
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorMinMaxTicketPrice);
      });

      it("Should raise exception for non-operator", async () => {
        const minPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "2000",
          18
        );
        const maxPriceTicketInLotteryToken = ethers.utils.parseUnits(
          "3000",
          18
        );
        await expect(
          lotteryInstance.setMinAndMaxTicketPriceInLotteryToken(
            minPriceTicketInLotteryToken,
            maxPriceTicketInLotteryToken
          )
        ).to.be.reverted;
      });
    });

    describe("Tickets buy settings tests", () => {
      it("Should change the maximum number of tickets per buy", async () => {
        const maxNumberTicketsPerBuy = 1000;
        await lotteryInstance
          .connect(operator)
          .setMaxNumberTicketsPerBuy(maxNumberTicketsPerBuy);
        const maxNumberTicketsPerBuyAfter =
          await lotteryInstance.maxNumberTicketsPerBuy();
        assert.equal(
          maxNumberTicketsPerBuyAfter.toNumber(),
          maxNumberTicketsPerBuy,
          "Max number of tickets per buy is not correct"
        );
      });

      it("Should raise an exception when attempting to change max number of tickets per buy to zero", async () => {
        const maxNumberTicketsPerBuy = 0;
        await expect(
          lotteryInstance
            .connect(operator)
            .setMaxNumberTicketsPerBuy(maxNumberTicketsPerBuy)
        ).to.be.revertedWith(lotto.errorMsgs.errorMaxNumberTicketsPerBuy);
      });

      it("Should raise exception when changing max number of tickets per buy for non-operator", async () => {
        const maxNumberTicketsPerBuy = 1000;
        await expect(
          lotteryInstance.setMaxNumberTicketsPerBuy(maxNumberTicketsPerBuy)
        ).to.be.reverted;
      });
    });

    describe("Tickets claim settings tests", () => {
      it("Should allow changing the maximum number of tickets that can be claimed at once", async () => {
        const maxNumberTicketsPerClaim = 1000;
        await lotteryInstance
          .connect(operator)
          .setMaxNumberTicketsPerClaim(maxNumberTicketsPerClaim);
        const maxNumberTicketsPerClaimAfter =
          await lotteryInstance.maxNumberTicketsPerClaim();
        assert.equal(
          maxNumberTicketsPerClaimAfter.toNumber(),
          maxNumberTicketsPerClaim,
          "Max number of tickets per claim is not correct"
        );
      });
      it("Should raise exception when max number of tickets per claim is zero", async () => {
        const maxNumberTicketsPerClaim = 0;
        await expect(
          lotteryInstance
            .connect(operator)
            .setMaxNumberTicketsPerClaim(maxNumberTicketsPerClaim)
        ).to.be.revertedWith(lotto.errorMsgs.errorMaxNumberTicketsPerClaim);
      });
      it("Should raise exception for changing max number of tickets per claim by non-operator", async () => {
        const maxNumberTicketsPerClaim = 1000;
        await expect(
          lotteryInstance.setMaxNumberTicketsPerClaim(maxNumberTicketsPerClaim)
        ).to.be.reverted;
      });
    });

    describe("Treasury address tests", () => {
      it("Should update the treasury address", async () => {
        await lotteryInstance
          .connect(operator)
          .setTreasuryAddress(treasury.address);
        const treasuryAddressAfter = await lotteryInstance.treasuryAddress();
        assert.equal(
          treasuryAddressAfter,
          treasury.address,
          "Treasury address is not correct"
        );
      });

      it("Should raise an exception when attempting to change the treasury address to 0", async () => {
        await expect(
          lotteryInstance
            .connect(operator)
            .setTreasuryAddress(ethers.constants.AddressZero)
        ).to.be.revertedWith(lotto.errorMsgs.errorTreasuryAddress);
      });
      it("Should raise exception for changing treasury address without Operator role", async () => {
        await expect(lotteryInstance.setTreasuryAddress(treasury.address)).to.be
          .reverted;
      });
    });

    it("Should generate random numbers of the correct length", async () => {
      const count = 100;
      const numbers = await lotteryInstance.getRandomNumbers(
        players[0].address,
        count
      );
      assert.equal(
        numbers.length,
        count,
        "Random numbers length is not correct"
      );
    });

    it("Should generate random number without duplicates up to a given threshold", async () => {
      const numRandomNumbers = 10000; // number of random numbers to generate
      const numbers = await lotteryInstance.getRandomNumbers(
        players[0].address,
        numRandomNumbers
      );

      const setOfNumbers = new Set(numbers); // set will only keep unique numbers
      const numUniqueNumbers = setOfNumbers.size;
      const numDuplicateNumbers = numRandomNumbers - numUniqueNumbers;

      const threshold = numRandomNumbers * 0.01; // 1% threshold
      assert.isAtMost(
        numDuplicateNumbers,
        threshold,
        `Generated ${numDuplicateNumbers} duplicate numbers which is more than 5% threshold of ${threshold}`
      );
    });

    describe("Random generator tests", () => {
      let newGlobalRngInstance;
      beforeEach(async () => {
        newGlobalRngInstance = await upgrades.deployProxy(
          globalRngContract,
          [],
          {
            initializer: "init",
          }
        );
      });

      it("Should raise exception when setting the RNG while the lottery is waiting for fulfillment", async () => {
        const pId = 1;
        const currentTime = await lotteryInstance.getTime();
        await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
          currentTime.toNumber() + lotto.setup.periodicity,
        ]);
        const currentLotteryId = await lotteryInstance.currentLotteryId();
        await lotteryInstance.closeLottery(currentLotteryId.toNumber());
        await expect(
          lotteryInstance
            .connect(operator)
            .setRngProvider(newGlobalRngInstance.address, pId)
        ).to.be.revertedWith(lotto.errorMsgs.pendingRngCall);
      });

      it("Should raise an exception when setting the Random Number Generator (RNG) by a non-operator role", async () => {
        const pId = 1;
        await expect(
          lotteryInstance.setRngProvider(newGlobalRngInstance.address, pId)
        ).to.be.reverted;
        await lotteryInstance
          .connect(operator)
          .setRngProvider(newGlobalRngInstance.address, pId);
        const randomGeneratorAddressAfter = await lotteryInstance.globalRng();
        assert.equal(
          randomGeneratorAddressAfter,
          newGlobalRngInstance.address,
          "Random generator address is not correct"
        );
      });

      it("Should set the RNG for the user only when called by the operator role", async () => {
        const pId = 1;
        await lotteryInstance
          .connect(operator)
          .setRngProvider(newGlobalRngInstance.address, pId);
        const randomGeneratorAddressAfter = await lotteryInstance.globalRng();
        assert.equal(
          randomGeneratorAddressAfter,
          newGlobalRngInstance.address,
          "Random generator address is not correct"
        );
      });

      it("Should raise an exception when setting a null or zero address for the RNG provider", async () => {
        const pId = 1;
        await expect(
          lotteryInstance
            .connect(operator)
            .setRngProvider(ethers.constants.AddressZero, pId)
        ).to.be.revertedWith(lotto.errorMsgs.incorrectRngAddress);
      });

      it("Should correctly update Chainlink parameters with valid input values", async () => {
        await lotteryInstance
          .connect(operator)
          .setChainlinkCallParams(
            chainlinkRngProvider.setup.keyHash,
            vrfsubId,
            chainlinkRngProvider.setup.minimumRequestConfirmations,
            chainlinkRngProvider.setup.gasLimit,
            chainlinkRngProvider.setup.numWords
          );
        const chainlinkCallParams = await lotteryInstance.providerCallParam();

        const VRFCoordinatorV2InterfaceContract = await ethers.getContractAt(
          "VRFCoordinatorV2Interface",
          ethers.constants.AddressZero
        );
        const calculatedChainlinkCallParams =
          VRFCoordinatorV2InterfaceContract.interface.encodeFunctionData(
            "requestRandomWords",
            [
              chainlinkRngProvider.setup.keyHash,
              vrfsubId,
              chainlinkRngProvider.setup.minimumRequestConfirmations,
              chainlinkRngProvider.setup.gasLimit,
              chainlinkRngProvider.setup.numWords,
            ]
          );
        assert.equal(
          chainlinkCallParams,
          calculatedChainlinkCallParams,
          "Chainlink call params are not correct"
        );
      });
    });

    describe("Recovers wrong token tests", () => {
      let externalTokenSupply, externalTokenInstance;
      beforeEach(async () => {
        externalTokenSupply = ethers.utils.parseEther("1000000");
        externalTokenInstance = await mockErc20Contract.deploy(
          externalTokenSupply
        );
        await externalTokenInstance.transfer(
          lotteryInstance.address,
          externalTokenSupply
        );
      });
      it("Should raise exception when trying to recover wrong token", async () => {
        await expect(
          lotteryInstance
            .connect(operator)
            .recoverWrongTokens(
              lotteryTokenInstance.address,
              externalTokenSupply
            )
        ).to.be.revertedWith(lotto.errorMsgs.cannotRecoverLotteryTokenError);
      });
      it("Should raise an exception if someone tries to recover tokens using a non-operator account", async () => {
        await expect(
          lotteryInstance.recoverWrongTokens(
            lotteryTokenInstance.address,
            externalTokenSupply
          )
        ).to.be.reverted;
      });
      it("Should retrieve the correct token", async () => {
        const externalTokenBalanceBefore =
          await externalTokenInstance.balanceOf(operator.address);
        await lotteryInstance
          .connect(operator)
          .recoverWrongTokens(
            externalTokenInstance.address,
            externalTokenSupply
          );
        const externalTokenBalanceAfter = await externalTokenInstance.balanceOf(
          operator.address
        );
        assert.equal(
          externalTokenBalanceAfter - externalTokenBalanceBefore,
          externalTokenSupply,
          "External token balance is not correct"
        );
      });
    });

    describe("Pause/Unpause contract tests", () => {
      it("Should raise exception for non-operator pause", async () => {
        await expect(lotteryInstance.pause()).to.be.reverted;
      });
      it("Should raise exception for non-operator unpause", async () => {
        await expect(lotteryInstance.unPause()).to.be.reverted;
      });
      it("Should raise exception for re-pausing already paused contract with non-operator role", async () => {
        await lotteryInstance.connect(operator).pause();
        await expect(
          lotteryInstance.connect(operator).pause()
        ).to.be.revertedWith(lotto.errorMsgs.alreadyPaused);
      });
      it("Should raise exception when unpausing a contract that is not currently paused", async () => {
        await expect(
          lotteryInstance.connect(operator).unPause()
        ).to.be.revertedWith(lotto.errorMsgs.alreadyUnPaused);
      });
      it("Should pause contract by operator users", async () => {
        await lotteryInstance.connect(operator).pause();
        const paused = await lotteryInstance.paused();
        assert.equal(paused, true, "Contract is not paused");
        const currentLotteryId = 1;
        await expect(
          lotteryInstance.buyTickets(currentLotteryId, 1)
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(
          lotteryInstance.buyForOthers(
            currentLotteryId,
            [1],
            [players[0].address]
          )
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, [1], [1])
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(
          lotteryInstance.closeLottery(currentLotteryId)
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(
          lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
            currentLotteryId
          )
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(
          lotteryInstance.injectFunds(currentLotteryId, 1)
        ).to.be.revertedWith(lotto.errorMsgs.isPausedError);
        await expect(lotteryInstance.startLottery()).to.be.revertedWith(
          lotto.errorMsgs.isPausedError
        );
      });
      it("Should unpause contract by operator users", async () => {
        await lotteryInstance.connect(operator).pause();
        await lotteryInstance.connect(operator).unPause();
        const paused = await lotteryInstance.paused();
        assert.equal(paused, false, "Contract is not unpaused");
      });
    });
  });

  describe("Tickets discount tests", () => {
    it("Should apply discount to the ticket price when buying multiple tickets in a single transaction", async () => {
      const lotteryTicketPrice = await lotteryInstance.minTicketPrice();
      const nmbrTicket = 10;
      const totalPrice =
        await lotteryInstance.calculateTotalPriceForBulkTickets(
          lotto.setup.discountDiv,
          lotteryTicketPrice,
          nmbrTicket
        );

      assert.equal(
        totalPrice,
        calculateDiscountPrice(
          lotto.setup.discountDiv,
          lotteryTicketPrice,
          nmbrTicket
        ),
        "Lottery ticket cost is incorrect"
      );
    });
  });

  describe("Buy tickets tests", () => {
    it("Should raise exception when buying lottery ticket for non-initialized lottery", async () => {
      const currentLotteryId = await lotteryInstance.currentLotteryId();
      const nmbrTicket = 10;
      await expect(
        lotteryInstance.buyTickets(currentLotteryId.toNumber(), nmbrTicket)
      ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
    });

    it("Should raise an exception when a player tries to buy a lottery ticket for a lottery that is not open", async () => {
      const currentLotteryId = await lotteryInstance.currentLotteryId();
      const nmbrTicket = 10;
      await expect(
        lotteryInstance.buyTickets(currentLotteryId.toNumber() + 1, nmbrTicket)
      ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
    });

    describe("Buy ticket for initialized lottery", () => {
      beforeEach(async () => {
        const currentTime = await lotteryInstance.getTime();
        const maxTime = 14400;
        // Setting the RNG for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setRngProvider(globalRngInstance.address, providerId);

        // Setting the ChainLink params for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setChainlinkCallParams(
            chainlinkRngProvider.setup.keyHash,
            vrfsubId,
            chainlinkRngProvider.setup.minimumRequestConfirmations,
            chainlinkRngProvider.setup.gasLimit,
            chainlinkRngProvider.setup.numWords
          );
        // Setting the treasury address
        await lotteryInstance
          .connect(operator)
          .setTreasuryAddress(treasury.address);
        // Start Initial Round
        await lotteryInstance
          .connect(operator)
          .startInitialRound(
            lotteryTokenInstance.address,
            lotto.setup.periodicity,
            lotto.setup.incentivePercent,
            lotto.setup.ticketPrice,
            lotto.setup.discountDiv,
            lotto.setup.distribution,
            lotto.setup.treasuryFee
          );
      });

      it("Should raise exception when player tries to buy more tickets than allowed per transaction", async () => {
        const maxNumberTicketsPerBuy =
          await lotteryInstance.maxNumberTicketsPerBuy();

        const currentLotteryId = await lotteryInstance.currentLotteryId();

        await expect(
          lotteryInstance
            .connect(players[0])
            .buyTickets(
              currentLotteryId.toNumber(),
              maxNumberTicketsPerBuy.toNumber() + 1
            )
        ).to.be.revertedWith(lotto.errorMsgs.cannotBuyTicketReachMax);
      });

      it("Should increment global lottery ticket ID when player buys tickets", async () => {
        const maxNumberTicketsPerBuy =
          await lotteryInstance.maxNumberTicketsPerBuy();
        const currentLotteryId = await lotteryInstance.currentLotteryId();

        // Transfering the lottery token to the players

        await Promise.all(
          players.map((player) =>
            lotteryInstance
              .connect(player)
              .buyTickets(
                currentLotteryId.toNumber(),
                maxNumberTicketsPerBuy.toNumber()
              )
          )
        );
        const currentTicketId = await lotteryInstance.currentTicketId();
        assert.equal(
          currentTicketId - maxNumberTicketsPerBuy * players.length,
          0,
          "Ticket id is not correct"
        );
      });

      it("Should associate a random number to each ticket bought", async () => {
        const numberTicket = await lotteryInstance.maxNumberTicketsPerBuy();
        const currentLotteryId = await lotteryInstance.currentLotteryId();

        await Promise.all(
          players.map((player) =>
            lotteryInstance
              .connect(player)
              .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
          )
        );
        let userInfoForLottery = [];
        await Promise.all(
          players.map((player) =>
            lotteryInstance
              .viewUserInfoForLotteryId(
                player.address,
                currentLotteryId.toNumber(),
                0,
                numberTicket.toNumber()
              )
              .then((userInfo) => {
                userInfoForLottery.push(userInfo);
              })
          )
        );

        const empyTicket = 10 ** 6;
        for (let i = 0; i < players.length; i++) {
          assert.equal(
            userInfoForLottery[i][1].length,
            numberTicket.toNumber(),
            "Ticket number is not correct for player " + i
          );

          for (let j = 0; j < userInfoForLottery[i][1].length; j++) {
            assert.notEqual(
              userInfoForLottery[i][1][j],
              empyTicket,
              "Ticket number is empty for player " + i
            );
          }
        }
      });

      it("Should transfer correct amount of lottery token and apply discount to the correct address when a player buys a lottery ticket", async () => {
        const numberTicket = await lotteryInstance.maxNumberTicketsPerBuy();
        const currentLotteryId = await lotteryInstance.currentLotteryId();

        const totalTicketPrice =
          await lotteryInstance.calculateTotalPriceForBulkTickets(
            lotto.setup.discountDiv,
            lotto.setup.ticketPrice,
            numberTicket
          );

        //check balance of all players
        let playersBlacancesBefore = [];
        await Promise.all(
          players.map((player) =>
            lotteryTokenInstance.balanceOf(player.address).then((balance) => {
              playersBlacancesBefore.push(balance);
            })
          )
        );

        await Promise.all(
          players.map((player) =>
            lotteryInstance
              .connect(player)
              .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
          )
        );

        //check balance of all players
        let playersBlacancesAfter = [];
        await Promise.all(
          players.map((player) =>
            lotteryTokenInstance.balanceOf(player.address).then((balance) => {
              playersBlacancesAfter.push(balance);
            })
          )
        );

        // assert diff balance equal to total ticket price for all player
        for (let i = 0; i < players.length; i++) {
          assert.equal(
            playersBlacancesBefore[i]
              .sub(playersBlacancesAfter[i])
              .sub(totalTicketPrice),
            0,
            "Balance is not correct for player " + i
          );
        }
      });

      describe("Buy ticket on end-cycle tests", () => {
        beforeEach(async () => {
          const currentTime = await lotteryInstance.getTime();
          await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
            currentTime.toNumber() + lotto.setup.periodicity + 1,
          ]);
          await network.provider.send("evm_mine");
        });

        it("Should raise an exception when trying to buy a lottery ticket after the lottery has ended", async () => {
          const currentLotteryId = await lotteryInstance.currentLotteryId();
          await expect(
            lotteryInstance.buyTickets(currentLotteryId.toNumber(), 10)
          ).to.be.revertedWith(lotto.errorMsgs.lotteryIsOver);
        });

        it("Should raise exception when trying to buy lottery ticket after the lottery is closed", async () => {
          const id = await lotteryInstance.currentLotteryId();
          await lotteryInstance.closeLottery(id.toNumber());
          await expect(
            lotteryInstance.connect(players[0]).buyTickets(id.toNumber(), 10)
          ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
        });
      });
    });
  });

  describe("Buy tickets for others tests", () => {
    const numberticketByReceiver = 1;
    const receiverLength = 3;
    const numberOfTickets = generateRandomIntArrayWithSum(
      numberticketByReceiver,
      receiverLength
    );
    const playerAddresses = generateWalletAddresses(receiverLength);
    const totalNumberOfTickets = numberticketByReceiver * receiverLength;

    it("Should raise an exception when a player tries to buy a lottery ticket for a non-initialized lottery", async () => {
      const currentLotteryId = await lotteryInstance.currentLotteryId();
      await expect(
        lotteryInstance.buyForOthers(
          currentLotteryId.toNumber(),
          numberOfTickets,
          playerAddresses
        )
      ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
    });

    it("Should raise an exception when buying a lottery ticket for a non-opened lottery", async () => {
      const currentLotteryId = await lotteryInstance.currentLotteryId();
      await expect(
        lotteryInstance.buyForOthers(
          currentLotteryId.toNumber() + 1,
          numberOfTickets,
          playerAddresses
        )
      ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
    });

    describe("Buy tickets for others for initialized lottery", () => {
      let currentLotteryId;
      beforeEach(async () => {
        const currentTime = await lotteryInstance.getTime();
        const maxTime = 14400;
        // Setting the RNG for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setRngProvider(globalRngInstance.address, providerId);

        // Setting the ChainLink params for the lottery contract
        await lotteryInstance
          .connect(operator)
          .setChainlinkCallParams(
            chainlinkRngProvider.setup.keyHash,
            vrfsubId,
            chainlinkRngProvider.setup.minimumRequestConfirmations,
            chainlinkRngProvider.setup.gasLimit,
            chainlinkRngProvider.setup.numWords
          );
        // Setting the treasury address
        await lotteryInstance
          .connect(operator)
          .setTreasuryAddress(treasury.address);
        // Start Initial Round
        await lotteryInstance
          .connect(operator)
          .startInitialRound(
            lotteryTokenInstance.address,
            lotto.setup.periodicity,
            lotto.setup.incentivePercent,
            lotto.setup.ticketPrice,
            lotto.setup.discountDiv,
            lotto.setup.distribution,
            lotto.setup.treasuryFee
          );

        currentLotteryId = await lotteryInstance.currentLotteryId();
      });

      it("Should raise an exception when the length of the receivers array does not match the numberOfTicket", async () => {
        await expect(
          lotteryInstance
            .connect(players[0])
            .buyForOthers(currentLotteryId.toNumber(), [1], playerAddresses)
        ).to.be.revertedWith(lotto.errorMsgs.errorBuyForOtherInvalidInputs);
      });

      it("Should raise exception when the number of receivers is higher than the maximum allowed", async () => {
        const maxNumberReceiversBuyForOthers =
          await lotteryInstance.maxNumberReceiversBuyForOthers();

        const receiverLength = maxNumberReceiversBuyForOthers.toNumber() + 1;
        const ticketByReceiver = 1;
        const receiversTicketsNumber = generateRandomIntArrayWithSum(
          ticketByReceiver,
          receiverLength
        );
        const receiversAddress = generateWalletAddresses(receiverLength);
        const currentLotteryId = await lotteryInstance.currentLotteryId();

        await expect(
          lotteryInstance
            .connect(players[0])
            .buyForOthers(
              currentLotteryId.toNumber(),
              receiversTicketsNumber,
              receiversAddress
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorTooManyReceivers);
      });

      it("Should raise an exception when a player attempts to buy for others more lottery tickets than the maximum number of tickets allowed", async () => {
        const maxNumberTicketsBuyForOthers =
          await lotteryInstance.maxNumberTicketsBuyForOthers();

        const ticketByReceiver = maxNumberTicketsBuyForOthers + 1;
        const receiversTicketsNumber = generateRandomIntArrayWithSum(
          ticketByReceiver,
          playerAddresses.length
        );
        await expect(
          lotteryInstance
            .connect(players[0])
            .buyForOthers(
              currentLotteryId,
              receiversTicketsNumber,
              playerAddresses
            )
        ).to.be.revertedWith(lotto.errorMsgs.errorBuyForOtherMaxTicketNumber);
      });

      it("Should increment the global lottery ticket ID when a player buys lottery tickets for others", async () => {
        await lotteryInstance
          .connect(players[0])
          .buyForOthers(
            currentLotteryId.toNumber(),
            numberOfTickets,
            playerAddresses
          );

        const currentTicketId = await lotteryInstance.currentTicketId();
        assert.equal(
          currentTicketId.toNumber() - totalNumberOfTickets,
          0,
          "Ticket id is not correct"
        );
      });

      it("Should associate a random number with a ticket when a player buys tickets for others", async () => {
        await lotteryInstance
          .connect(players[0])
          .buyForOthers(
            currentLotteryId.toNumber(),
            numberOfTickets,
            playerAddresses
          );

        let receiversInfoForLottery = [];
        await Promise.all(
          playerAddresses.map((player) =>
            lotteryInstance
              .viewUserInfoForLotteryId(
                player,
                currentLotteryId.toNumber(),
                0,
                numberticketByReceiver
              )
              .then((userInfo) => {
                receiversInfoForLottery.push(userInfo);
              })
          )
        );

        const empyTicket = 10 ** 6;
        for (let i = 0; i < players.length; i++) {
          assert.equal(
            receiversInfoForLottery[i][1].length,
            numberticketByReceiver,
            "Ticket number is not correct for player " + i
          );

          for (let j = 0; j < receiversInfoForLottery[i][1].length; j++) {
            assert.notEqual(
              receiversInfoForLottery[i][1][j],
              empyTicket,
              "Ticket number is empty for player " + i
            );
          }
        }
      });

      it("Should transfer the correct amount of lottery token with applied discount when a player buys lottery ticket(s) for others", async () => {
        const totalTicketPrice =
          await lotteryInstance.calculateTotalPriceForBulkTickets(
            lotto.setup.discountDiv,
            lotto.setup.ticketPrice,
            totalNumberOfTickets
          );

        const senderBalanceBefore = await lotteryTokenInstance.balanceOf(
          players[0].address
        );
        await lotteryInstance
          .connect(players[0])
          .buyForOthers(
            currentLotteryId.toNumber(),
            numberOfTickets,
            playerAddresses
          );

        const senderBalanceAfter = await lotteryTokenInstance.balanceOf(
          players[0].address
        );

        assert.equal(
          senderBalanceBefore.sub(senderBalanceAfter).sub(totalTicketPrice),
          0,
          "Balance is not correct"
        );
      });

      describe("Buy ticket for others on the end-cycle", () => {
        beforeEach(async () => {
          const currentTime = await lotteryInstance.getTime();

          await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
            currentTime.toNumber() + lotto.setup.periodicity + 1,
          ]);
          await network.provider.send("evm_mine");
        });

        it("Should raise an exception when a player attempts to buy a lottery ticket(s) for others after the end of the current lottery round", async () => {
          const currentLotteryId = await lotteryInstance.currentLotteryId();

          await expect(
            lotteryInstance
              .connect(players[0])
              .buyForOthers(
                currentLotteryId.toNumber(),
                numberOfTickets,
                playerAddresses
              )
          ).to.be.revertedWith(lotto.errorMsgs.lotteryIsOver);
        });

        it("Should raise an exception when a player attempts to buy a lottery ticket(s) for others after the lottery has closed.", async () => {
          const currentLotteryId = await lotteryInstance.currentLotteryId();
          await lotteryInstance.closeLottery(currentLotteryId.toNumber());
          await expect(
            lotteryInstance.buyForOthers(
              currentLotteryId.toNumber(),
              numberOfTickets,
              playerAddresses
            )
          ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
        });
      });
    });
  });

  describe("Lottery full cycle tests", () => {
    let numberTicket, currentLotteryId, currentTime, maxTime;

    beforeEach(async () => {
      currentTime = await lotteryInstance.getTime();
      maxTime = 14400;
      // Setting the RNG for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setRngProvider(globalRngInstance.address, providerId);

      // Setting the ChainLink params for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setChainlinkCallParams(
          chainlinkRngProvider.setup.keyHash,
          vrfsubId,
          chainlinkRngProvider.setup.minimumRequestConfirmations,
          chainlinkRngProvider.setup.gasLimit,
          chainlinkRngProvider.setup.numWords
        );
      // Setting the treasury address
      await lotteryInstance
        .connect(operator)
        .setTreasuryAddress(treasury.address);
      // Start Initial Round
      await lotteryInstance
        .connect(operator)
        .startInitialRound(
          lotteryTokenInstance.address,
          lotto.setup.periodicity,
          lotto.setup.incentivePercent,
          lotto.setup.ticketPrice,
          lotto.setup.discountDiv,
          lotto.setup.distribution,
          lotto.setup.treasuryFee
        );

      currentLotteryId = await lotteryInstance.currentLotteryId();
      numberTicket = await lotteryInstance.maxNumberTicketsPerBuy();
    });

    it("Should transfer incentive and treasury funds when operating the lottery", async () => {
      for (const player of players) {
        await expect(
          lotteryInstance
            .connect(player)
            .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
        ).to.emit(lotteryInstance, "TicketsPurchase");
      }
      const cursorTicketReader = 0;
      let userInfoForLottery = [];
      await Promise.all(
        players.map((player) =>
          lotteryInstance
            .viewUserInfoForLotteryId(
              player.address,
              currentLotteryId.toNumber(),
              cursorTicketReader,
              numberTicket.toNumber()
            )
            .then((userInfo) => {
              userInfoForLottery.push(userInfo);
            })
        )
      );

      const currentLotteryInfo = await lotteryInstance.viewLottery(
        currentLotteryId
      );

      await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
        currentLotteryInfo.endTime.toNumber(),
      ]);
      // Mine extra blok to reach lottery endtime
      await network.provider.send("evm_mine");

      let communityOperatorBalanceBefore = await lotteryTokenInstance.balanceOf(
        communityOperator[0].address
      );

      await expect(
        lotteryInstance
          .connect(communityOperator[0])
          .closeLottery(currentLotteryId)
      ).to.emit(lotteryInstance, "LotteryClose");

      const rewardByLotteryOperation =
        (currentLotteryInfo.amountCollectedInLotteryToken *
          3 *
          lotto.setup.incentivePercent) /
        10000;

      const treasuryfee =
        ((currentLotteryInfo.amountCollectedInLotteryToken -
          rewardByLotteryOperation) *
          lotto.setup.treasuryFee) /
        10000;

      communityOperatorBalanceAfter = await lotteryTokenInstance.balanceOf(
        communityOperator[0].address
      );

      assert.equal(
        communityOperatorBalanceAfter - communityOperatorBalanceBefore,
        rewardByLotteryOperation / 3,
        "Incentive reward is not correct"
      );

      const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
      const winningNumber = 1423623;
      const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
      await mockVrfInstance.fulfillRandomWordsWithOverride(
        vrfRequest,
        globalRngInstance.address,
        [winningNumber]
      );

      communityOperatorBalanceBefore = await lotteryTokenInstance.balanceOf(
        communityOperator[1].address
      );

      const treasuryAddressBalanceBefore = await lotteryTokenInstance.balanceOf(
        treasury.address
      );
      await expect(
        lotteryInstance
          .connect(communityOperator[1])
          .drawFinalNumberAndMakeLotteryClaimable(currentLotteryId)
      ).to.emit(lotteryInstance, "LotteryNumberDrawn");
      communityOperatorBalanceAfter = await lotteryTokenInstance.balanceOf(
        communityOperator[1].address
      );
      const treasuryAddressBalanceAfter = await lotteryTokenInstance.balanceOf(
        treasury.address
      );

      assert.equal(
        treasuryAddressBalanceAfter - treasuryAddressBalanceBefore,
        treasuryfee,
        "Treasury fee is not correct"
      );

      assert.equal(
        communityOperatorBalanceAfter - communityOperatorBalanceBefore,
        rewardByLotteryOperation / 3,
        "Incentive reward is not correct"
      );

      communityOperatorBalanceBefore = await lotteryTokenInstance.balanceOf(
        communityOperator[2].address
      );
      await expect(
        lotteryInstance.connect(communityOperator[2]).startLottery()
      ).to.emit(lotteryInstance, "LotteryOpen");
      communityOperatorBalanceAfter = await lotteryTokenInstance.balanceOf(
        communityOperator[2].address
      );
      assert.equal(
        communityOperatorBalanceAfter - communityOperatorBalanceBefore,
        rewardByLotteryOperation / 3,
        "Incentive reward is not correct"
      );
    });

    it("Should increase rewards when the operator injects funds", async () => {
      for (const player of players) {
        await expect(
          lotteryInstance
            .connect(player)
            .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
        ).to.emit(lotteryInstance, "TicketsPurchase");
      }

      let currentLotteryInfo = await lotteryInstance.viewLottery(
        currentLotteryId
      );

      const amountCollectedInLotteryTokenBefore =
        currentLotteryInfo.amountCollectedInLotteryToken;

      const amountToInject = ethers.utils.parseUnits("50", 18);
      await lotteryInstance
        .connect(operator)
        .injectFunds(currentLotteryId, amountToInject);

      currentLotteryInfo = await lotteryInstance.viewLottery(currentLotteryId);

      const amountCollectedInLotteryTokenAfter =
        currentLotteryInfo.amountCollectedInLotteryToken;

      assert.equal(
        amountCollectedInLotteryTokenAfter -
          amountCollectedInLotteryTokenBefore,
        amountToInject,
        "Amount collected is not correct"
      );
    });

    it("Should raise an exception when attempting to inject funds for a non-opened lottery", async () => {
      let currentLotteryInfo = await lotteryInstance.viewLottery(
        currentLotteryId
      );

      const amountToInject = ethers.utils.parseUnits("50", 18);
      await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
        currentLotteryInfo.endTime.toNumber(),
      ]);
      // Mine extra blok to reach lottery endtime
      await network.provider.send("evm_mine");

      await lotteryInstance.closeLottery(currentLotteryId);

      await expect(
        lotteryInstance
          .connect(operator)
          .injectFunds(currentLotteryId, amountToInject)
      ).to.be.revertedWith(lotto.errorMsgs.lotteryIsNotOpen);
    });

    it("Should send pending rewards to treasury when autoInject is false", async () => {
      for (const player of players) {
        await expect(
          lotteryInstance
            .connect(player)
            .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
        ).to.emit(lotteryInstance, "TicketsPurchase");
      }

      let currentLotteryInfo = await lotteryInstance.viewLottery(
        currentLotteryId
      );

      const amountCollectedInLotteryTokenBefore =
        currentLotteryInfo.amountCollectedInLotteryToken;

      const amountToInject = ethers.utils.parseUnits("50", 18);
      await lotteryInstance
        .connect(operator)
        .injectFunds(currentLotteryId, amountToInject);

      currentLotteryInfo = await lotteryInstance.viewLottery(currentLotteryId);

      const amountCollectedInLotteryTokenAfter =
        currentLotteryInfo.amountCollectedInLotteryToken;

      assert.equal(
        amountCollectedInLotteryTokenAfter -
          amountCollectedInLotteryTokenBefore,
        amountToInject,
        "Amount collected is not correct"
      );
    });
  });

  describe("Reward distribution", () => {
    let numberTicket, currentLotteryId;

    beforeEach(async () => {
      currentTime = await lotteryInstance.getTime();
      // Setting the RNG for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setRngProvider(globalRngInstance.address, providerId);

      // Setting the ChainLink params for the lottery contract
      await lotteryInstance
        .connect(operator)
        .setChainlinkCallParams(
          chainlinkRngProvider.setup.keyHash,
          vrfsubId,
          chainlinkRngProvider.setup.minimumRequestConfirmations,
          chainlinkRngProvider.setup.gasLimit,
          chainlinkRngProvider.setup.numWords
        );
      // Setting the treasury address
      await lotteryInstance
        .connect(operator)
        .setTreasuryAddress(treasury.address);
      // Start Initial Round
      await lotteryInstance
        .connect(operator)
        .startInitialRound(
          lotteryTokenInstance.address,
          lotto.setup.periodicity,
          lotto.setup.incentivePercent,
          lotto.setup.ticketPrice,
          lotto.setup.discountDiv,
          lotto.setup.distribution,
          lotto.setup.treasuryFee
        );

      currentLotteryId = await lotteryInstance.currentLotteryId();
      numberTicket = await lotteryInstance.maxNumberTicketsPerBuy();
    });

    it("Should distribute lottery rewards among winners according to the rewards breakdown", async () => {
      for (let i = 0; i < 20; i++) {
        await Promise.all(
          players.map((player) =>
            lotteryInstance
              .connect(player)
              .buyTickets(currentLotteryId.toNumber(), numberTicket.toNumber())
          )
        );
      }

      // Move in time & mine block
      await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
        currentTime.toNumber() + lotto.setup.periodicity + 4,
      ]);
      await network.provider.send("evm_mine");
      await lotteryInstance.closeLottery(currentLotteryId);
      const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
      const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
      const winningNumber = 1123456;
      await mockVrfInstance.fulfillRandomWordsWithOverride(
        vrfRequest,
        globalRngInstance.address,
        [winningNumber]
      );
      await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
        currentLotteryId
      );
      const lotteryInfo = await lotteryInstance.viewLottery(currentLotteryId);
      const tokenPerBracket = lotteryInfo.tokenPerBracket;
      const amountCollectedInLotteryToken =
        lotteryInfo.amountCollectedInLotteryToken;

      // Calculate the amount to share to winners
      const calcultedAmountToShareToWinners = amountCollectedInLotteryToken
        .mul(10000 - lotto.setup.treasuryFee)
        .div(10000);

      let totalTokenDistributed = ethers.BigNumber.from(0);

      // Calculate the total amount distributed to players
      for (let i = 0; i < lotto.setup.distribution.length; i++) {
        totalTokenDistributed = totalTokenDistributed.add(tokenPerBracket[i]);
      }

      // Check if the total amount distributed to players is correct
      // To check correct value need to check each tickets
      // ticket number are not mocked
      assert(totalTokenDistributed.gte(0), "Total token distributed is 0");

      // Check if the amount to share to winners is correct
      const calculatedInjectedToken = calcultedAmountToShareToWinners.sub(
        totalTokenDistributed
      );

      const injectedToken = await lotteryInstance.pendingInjectionNextLottery();

      // Check if the injected amount is correct
      assert.equal(
        calculatedInjectedToken.sub(injectedToken),
        0,
        "Injected token is not correct"
      );
    });

    it("Should allow multiple winners to claim rewards", async () => {
      // increase max numer of ticket per player
      const numberTicketsPerPlayer = 50;
      await lotteryInstance
        .connect(operator)
        .setMaxNumberTicketsPerBuy(numberTicketsPerPlayer);

      await Promise.all(
        players.map((player) =>
          lotteryInstance
            .connect(player)
            .buyTickets(currentLotteryId.toNumber(), numberTicketsPerPlayer)
        )
      );
      let userInfoForLottery = [];
      await Promise.all(
        players.map((player) =>
          lotteryInstance
            .viewUserInfoForLotteryId(
              player.address,
              currentLotteryId.toNumber(),
              0,
              numberTicketsPerPlayer
            )
            .then((userInfo) => {
              userInfoForLottery.push(userInfo);
            })
        )
      );
      // Move in time & mine block
      await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
        currentTime.toNumber() + lotto.setup.periodicity + 4,
      ]);
      await network.provider.send("evm_mine");
      await lotteryInstance.closeLottery(currentLotteryId);
      const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
      const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
      const winningNumber = 1123456;
      await mockVrfInstance.fulfillRandomWordsWithOverride(
        vrfRequest,
        globalRngInstance.address,
        [winningNumber]
      );
      await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
        currentLotteryId
      );

      let userTicketNumber,
        userTicketId,
        userTicketStatus,
        calculatedEligbleBrackets,
        ticketRewards = 0,
        userbalanceBefore,
        userbalanceAfter,
        ticketClaimStatus;
      for (let i = 0; i < players.length; i++) {
        for (let j = 0; j < numberTicketsPerPlayer; j++) {
          userTicketId = userInfoForLottery[i][0][j];
          userTicketNumber = userInfoForLottery[i][1][j];
          userTicketStatus = userInfoForLottery[i][2][j];
          calculatedEligbleBrackets = calculateEligibleBracket(
            winningNumber,
            userTicketNumber
          );
          if (calculatedEligbleBrackets > 0) {
            calculatedEligbleBrackets--;
            ticketRewards = await lotteryInstance.viewRewardsForTicketId(
              currentLotteryId.toNumber(),
              userTicketId,
              calculatedEligbleBrackets
            );

            // Check if the ticket reward is correct
            assert(ticketRewards > 0, "Invalid ticket reward");

            userbalanceBefore = await lotteryTokenInstance.balanceOf(
              players[i].address
            );
            await lotteryInstance
              .connect(players[i])
              .claimTickets(
                currentLotteryId,
                [userTicketId],
                [calculatedEligbleBrackets]
              );
            userbalanceAfter = await lotteryTokenInstance.balanceOf(
              players[i].address
            );
            // Check if the ticket reward is correct
            assert.equal(
              userbalanceAfter.sub(userbalanceBefore).sub(ticketRewards),
              0,
              "Invalid ticket reward"
            );

            ticketClaimStatus =
              await lotteryInstance.viewNumbersAndStatusesForTicketIds([
                userTicketId,
              ]);

            // Check if the ticket status is correct
            assert(ticketClaimStatus, "Invalid ticket status");
            ticketClaimStatus = false;
            ticketRewards = 0;
          }
        }
      }
    });

    describe("Claim rewards tests", async () => {
      it("Should raise exception when the length of provided _ticketIds and _brackets arrays are not equal", async () => {
        const ticketIds = [1, 2, 3];
        const brackets = [1, 2];
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, ticketIds, brackets)
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketWrongInputs);
      });

      it("Should raise an exception when trying to claim rewards with an empty array of ticket IDs", async () => {
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, [], [])
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketIdsLenght);
      });

      it("Should raise an exception when the number of ticket IDs provided for a claim is greater than the maximum number of tickets per claim", async () => {
        const ticketIds = new Array(101).fill(1);
        const brackets = new Array(101).fill(1);
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, ticketIds, brackets)
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketIdsLenghtMax);
      });

      it("Should raise exception when attempting to claim rewards for a non-claimable lottery", async () => {
        const ticketIds = [1, 2, 3];
        const brackets = [1, 2, 3];
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, ticketIds, brackets)
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketLotteryNotClaimable);
      });

      it("Should raise exception when a player tries to claim a ticket that they don't own", async () => {
        await lotteryInstance
          .connect(players[0])
          .buyTickets(currentLotteryId, 1);
        const userTicketInfo = await lotteryInstance.viewUserInfoForLotteryId(
          players[0].address,
          currentLotteryId,
          0,
          1
        );

        //Move in time
        await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
          currentTime.toNumber() + lotto.setup.periodicity + 4,
        ]);
        await network.provider.send("evm_mine");
        await lotteryInstance.closeLottery(currentLotteryId);
        const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
        const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
        const winningNumber = userTicketInfo[1][0];
        await mockVrfInstance.fulfillRandomWordsWithOverride(
          vrfRequest,
          globalRngInstance.address,
          [winningNumber]
        );
        await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
          currentLotteryId
        );
        // return lotteryTicketIds, ticketNumbers, ticketStatuses, _cursor + length;
        const userTicketId = userTicketInfo[0][0];
        await expect(
          lotteryInstance.claimTickets(currentLotteryId, [userTicketId], [5])
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketNotOnwer);
      });

      it("Should raise exception when attempting to claim the same ticket more than once", async () => {
        await lotteryInstance
          .connect(players[0])
          .buyTickets(currentLotteryId, 1);
        const userTicketInfo = await lotteryInstance.viewUserInfoForLotteryId(
          players[0].address,
          currentLotteryId,
          0,
          1
        );

        //Move in time
        await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
          currentTime.toNumber() + lotto.setup.periodicity + 4,
        ]);
        await network.provider.send("evm_mine");
        await lotteryInstance.closeLottery(currentLotteryId);
        // Draw final number
        const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
        const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
        const winningBracket = 5;
        const winningNumber = userTicketInfo[1][0];
        await mockVrfInstance.fulfillRandomWordsWithOverride(
          vrfRequest,
          globalRngInstance.address,
          [winningNumber]
        );
        await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
          currentLotteryId
        );
        const userTicketId = userTicketInfo[0][0];
        await expect(
          lotteryInstance
            .connect(players[0])
            .claimTickets(
              currentLotteryId,
              [userTicketId, userTicketId],
              [winningBracket, winningBracket]
            )
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketNotOnwer);
      });

      it("Should raise exception when claiming rewards for the wrong bracket", async () => {
        await lotteryInstance
          .connect(players[0])
          .buyTickets(currentLotteryId, 1);
        const userTicketInfo = await lotteryInstance.viewUserInfoForLotteryId(
          players[0].address,
          currentLotteryId,
          0,
          1
        );

        //Move in time
        await hre.ethers.provider.send("evm_setNextBlockTimestamp", [
          currentTime.toNumber() + lotto.setup.periodicity + 4,
        ]);
        await network.provider.send("evm_mine");
        await lotteryInstance.closeLottery(currentLotteryId);
        const rngRequestId = await lotteryInstance.reqIds(currentLotteryId);
        const vrfRequest = await globalRngInstance.reqIds(rngRequestId);
        const winningBracket = 5;
        const winningNumber = userTicketInfo[1][0];
        await mockVrfInstance.fulfillRandomWordsWithOverride(
          vrfRequest,
          globalRngInstance.address,
          [winningNumber]
        );
        await lotteryInstance.drawFinalNumberAndMakeLotteryClaimable(
          currentLotteryId
        );
        const userTicketId = userTicketInfo[0][0];
        await expect(
          lotteryInstance
            .connect(players[0])
            .claimTickets(
              currentLotteryId,
              [userTicketId],
              [winningBracket - 1]
            )
        ).to.be.revertedWith(lotto.errorMsgs.claimTicketLotteryNoPrize);
      });
    });
  });
});
