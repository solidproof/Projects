const chai = require("chai");
const chaiAsPromised = require("chai-as-promised");
chai.use(chaiAsPromised).should();
const expect = chai.expect;

const { ethers } = require("hardhat");
const { utils } = require("ethers");
const TestHelper = require("./Helper");
const helper = new TestHelper();
const path = "./test/";

describe.only("Bribe Bond Tests", function () {
  let owner, user1, user2, user3, user4, multisigGov, veReserve;
  let treasury, draculaFactory, draculaRouter, swapLibrary;
  let weth, dai;
  let fangToken;
  let controller,
    bribeFactory,
    gaugeFactory,
    ve,
    draculaVoter,
    veDist,
    draculaMinter,
    bribeBond;

  let poolFang, gauge_usdc_fang, bribe_usdc_fang;
  let bribeWETH_DAI;
  let gaugeWETH_DAI;
  let WETH_DAI;
  let mute, zkdoge, zkinu;
  let pool_usdc_mute, gauge_usdc_mute, bribe_usdc_mute;
  let pool_weth_mute, gauge_weth_mute, bribe_weth_mute;
  let pool_usdc_zkdoge, gauge_usdc_zkdoge, bribe_usdc_zkdoge;
  let pool_usdc_zkinu, gauge_usdc_zkinu, bribe_usdc_zkinu;
  before(async () => {
    await helper.deployDex();
    await helper.deployFangToken();
    await helper.deployVotes();
    await helper.getTokens();

    //users
    owner = helper.users.owner;
    user1 = helper.users.user1;
    user2 = helper.users.user2;
    user3 = helper.users.user3;
    user4 = helper.users.user4;
    multisigGov = helper.users.multisigGov;
    veReserve = helper.users.veReserve;
    //DEX
    treasury = helper.contracts.governanceTreasury;
    draculaFactory = helper.contracts.draculaFactory;
    draculaRouter = helper.contracts.draculaRouter;
    swapLibrary = helper.contracts.swapLibrary;
    //TOKEN
    fangToken = helper.contracts.fangToken;
    weth = helper.contracts.weth;
    usdc = helper.contracts.tokenContracts.USDC;
    mute = helper.contracts.tokenContracts.MUTE;
    zkdoge = helper.contracts.tokenContracts.ZKDOGE;
    zkinu = helper.contracts.tokenContracts.ZKINU;

    //VOTES
    controller = helper.contracts.controller;
    bribeFactory = helper.contracts.bribeFactory;
    gaugeFactory = helper.contracts.gaugeFactory;
    ve = helper.contracts.ve;
    draculaVoter = helper.contracts.draculaVoter;
    veDist = helper.contracts.veDist;
    draculaMinter = helper.contracts.draculaMinter;

    ////////////////////////CONTROLLER
    //set veDist
    await controller.setVeDist(veDist.address);

    //set draculaVoter
    await controller.setVoter(draculaVoter.address);

    //set Governance
    await controller.setGovernance(multisigGov.address);
    await controller.connect(multisigGov).acceptGovernance();

    //set Depositor
    await veDist.setDepositor(draculaMinter.address);

    //set Minter
    await fangToken.setMinter(draculaMinter.address);

    ///////////////////BRIBEBOND
    //deploy bribeBond
    await helper.deployBribeBond();
    bribeBond = helper.contracts.bribeBond;

    //set BribeBond in ve
    await ve.setBribeBond(bribeBond.address);
    await draculaVoter.setBribeBond(bribeBond.address);
    //deploy fang pool
    poolFang = await helper.deployPoolFang();
    //set poolFang
    await bribeBond.setPoolFang(poolFang.address);
    // deploy pools
    pool_usdc_mute = await helper.deployPool(
      usdc,
      mute,
      ethers.utils.parseUnits("10000", "6"),
      ethers.utils.parseUnits("5000", "18"), //2$
      false
    );
    pool_weth_mute = await helper.deployPool(
      weth,
      mute,
      ethers.utils.parseUnits("10", "18"),
      ethers.utils.parseUnits("5000", "18"), //0.002 Eth
      false
    );
    pool_usdc_zkdoge = await helper.deployPool(
      usdc,
      zkdoge,
      ethers.utils.parseUnits("15000", "6"),
      ethers.utils.parseUnits("5000", "18"), //3$
      false
    );
    pool_usdc_zkinu = await helper.deployPool(
      usdc,
      zkinu,
      ethers.utils.parseUnits("14000", "6"),
      ethers.utils.parseUnits("16000", "18"), //0.875$
      false
    );
  });

  it("Initialize Minter Contract", async function () {
    const claimants = [
      veReserve.address,
      veReserve.address,
      owner.address,
      owner.address,
      user1.address,
    ];
    const amounts = [
      utils.parseEther("5000000"),
      utils.parseEther("5000000"),
      utils.parseEther("2500000"),
      utils.parseEther("2499000"),
      utils.parseEther("1000"),
    ];
    const totalAmount = utils.parseEther("15000000"); //15M (+0.05%=750_000)

    await draculaMinter.initialize(claimants, amounts, totalAmount, 1); //last parameter is warmup period: ve holders should have time for voting

    (await fangToken.balanceOf(owner.address)).should.be.equal(
      "3960000000000000000000000"
    );
    (await fangToken.totalSupply()).should.be.equal(
      utils.parseEther("19750000")
    );
    const blockTimestamp = await helper.getTimestamp();
    const week = 86400 * 7;
    const activePeriodExpected =
      Math.floor(blockTimestamp / week) * week + week; //next Thursday 00:00 UTC
    expect(activePeriodExpected).to.be.equal(
      await draculaMinter.activePeriod()
    );
  });
  it("Initialize voter contract", async () => {
    await draculaVoter.initialize(
      [
        weth.address,
        fangToken.address,
        usdc.address,
        mute.address,
        zkdoge.address,
        zkinu.address,
      ],
      draculaMinter.address
    );
  });
  it("Add pools to gauge", async () => {
    //FANG_USDC
    let tx = await (await draculaVoter.createGauge(poolFang.address)).wait();
    let events = tx.events.find((event) => event.event === "GaugeCreated");
    gauge_usdc_fang = await ethers.getContractAt("Gauge", events.args.gauge);
    bribe_usdc_fang = await ethers.getContractAt("Bribe", events.args.bribe);
    //MUTE_USDC
    tx = await (await draculaVoter.createGauge(pool_usdc_mute.address)).wait();
    events = tx.events.find((event) => event.event === "GaugeCreated");
    gauge_usdc_mute = await ethers.getContractAt("Gauge", events.args.gauge);
    bribe_usdc_mute = await ethers.getContractAt("Bribe", events.args.bribe);
    //MUTE_ETH
    tx = await (await draculaVoter.createGauge(pool_weth_mute.address)).wait();
    events = tx.events.find((event) => event.event === "GaugeCreated");
    gauge_weth_mute = await ethers.getContractAt("Gauge", events.args.gauge);
    bribe_weth_mute = await ethers.getContractAt("Bribe", events.args.bribe);
    //ZKDOGE_USDC
    tx = await (
      await draculaVoter.createGauge(pool_usdc_zkdoge.address)
    ).wait();
    events = tx.events.find((event) => event.event === "GaugeCreated");
    gauge_usdc_zkdoge = await ethers.getContractAt("Gauge", events.args.gauge);
    bribe_usdc_zkdoge = await ethers.getContractAt("Bribe", events.args.bribe);
    //ZKINU_USDC
    tx = await (await draculaVoter.createGauge(pool_usdc_zkinu.address)).wait();
    events = tx.events.find((event) => event.event === "GaugeCreated");
    gauge_usdc_zkinu = await ethers.getContractAt("Gauge", events.args.gauge);
    bribe_usdc_zkinu = await ethers.getContractAt("Bribe", events.args.bribe);
    //////////////////////
    const numberOfPool = await draculaVoter.poolsLength();
    expect(numberOfPool).to.be.equal(5);
    expect(await gauge_usdc_fang.underlying()).to.be.equal(poolFang.address);
    expect(await gauge_usdc_mute.underlying()).to.be.equal(
      pool_usdc_mute.address
    );
    expect(await gauge_weth_mute.underlying()).to.be.equal(
      pool_weth_mute.address
    );
    expect(await gauge_usdc_zkdoge.underlying()).to.be.equal(
      pool_usdc_zkdoge.address
    );
    expect(await gauge_usdc_zkinu.underlying()).to.be.equal(
      pool_usdc_zkinu.address
    );
  });

  it("Vote for gauge at EPOCH 0", async () => {
    await draculaVoter.vote(
      3,
      [poolFang.address, pool_usdc_mute.address],
      [1, 2]
    );
  });
  it("Bribe Bond at epoch 0", async () => {
    await usdc.approve(bribeBond.address, ethers.constants.MaxUint256);
    // console.log(await bribeBond.limitPerDay());
    await bribeBond.depositBond(ethers.utils.parseUnits("5000", "6"));
    //get svg from veLogo
    // const tokenURI = await ve.tokenURI(6);
    // helper.render_svg(tokenURI, "ve-logo", path);
  });
  it("snapshot epoch 0", async () => {
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
    await draculaVoter.snapshot();
  });
  it("try to deposit/claim bond between snapshot and update should revert", async () => {
    await usdc.approve(bribeBond.address, ethers.constants.MaxUint256);
    await bribeBond
      .depositBond(ethers.utils.parseUnits("1000", "6"))
      .should.be.revertedWith("period not updated yet");
    await bribeBond
      .claimBondRewards([poolFang.address], 3)
      .should.be.revertedWith("period not updated yet");
  });
  it("Update period epoch to 1", async () => {
    await helper.timeHoursTraveller(126);
    await draculaVoter.distributeAll();
    // console.log(await bribeBond.depositedFangForDay(4));
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
  });
  it("Claim rewards for epoch 0", async () => {
    // console.log("last vote", await draculaVoter.lastVote(3));
    const balanceBefore = await usdc.balanceOf(owner.address);
    const claimableBondRewards = await draculaVoter.getAllClaimableBondRewards(
      3
    );
    await bribeBond.claimBondRewards([poolFang.address], 3);
    await bribeBond.claimBondRewards([pool_usdc_mute.address], 3);
    const balanceAfter = await usdc.balanceOf(owner.address);
    expect(claimableBondRewards[0].gauge).to.be.equal(poolFang.address);
    expect(claimableBondRewards[0].reward).to.be.equal("1666666665");
    expect(claimableBondRewards[1].gauge).to.be.equal(pool_usdc_mute.address);
    expect(claimableBondRewards[1].reward).to.be.equal("3333333330");
    expect(balanceAfter.sub(balanceBefore)).to.be.equal("4999999995");
  });
  it("snapshot epoch 1 and update epoch to 2", async () => {
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
    await helper.timeTraveller(7);
    await draculaVoter.snapshot();
    await draculaVoter.distributeAll();
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
  });
  it("Bribe Bond at epoch 1", async () => {
    await usdc.approve(bribeBond.address, ethers.constants.MaxUint256);
    // console.log(await bribeBond.limitPerDay());
    await bribeBond.depositBond(ethers.utils.parseUnits("1000", "6"));
    // console.log(await bribeBond.depositedFangForDay(4));
  });
  it("No claimable rewards at epoch 2 because user didn't vote at epoch 1", async () => {
    const claimableBondRewards = await draculaVoter.getAllClaimableBondRewards(
      3
    );
    expect(claimableBondRewards).to.be.empty;
  });
  it("Vote for gauge at EPOCH 2", async () => {
    await draculaVoter.poke(3); //re-vote with same percentage as previous vote
  });
  it("snapshot epoch 2 and update epoch to 3", async () => {
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
    await helper.timeTraveller(7);
    await draculaVoter.snapshot();
    await draculaVoter.distributeAll();
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
  });
  it("claimable rewards at epoch 3 because user has voted at epoch 2", async () => {
    const claimableBondRewards = await draculaVoter.getAllClaimableBondRewards(
      3
    );
    expect(claimableBondRewards[0].gauge).to.be.equal(poolFang.address);
    expect(claimableBondRewards[0].reward).to.be.equal("333333334");
    expect(claimableBondRewards[1].gauge).to.be.equal(pool_usdc_mute.address);
    expect(claimableBondRewards[1].reward).to.be.equal("666666669");
  });

  it("Vote for gauge at EPOCH 3", async () => {
    await draculaVoter.poke(3); //re-vote with same percentage as previous vote
  });
  it("No claimable rewards at epoch 3 because user has voted at epoch 3 (without claiming)", async () => {
    const claimableBondRewards = await draculaVoter.getAllClaimableBondRewards(
      3
    );
    expect(claimableBondRewards).to.be.empty;
  });
  it("snapshot epoch 3 and update epoch to 4", async () => {
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
    await helper.timeTraveller(7);
    await draculaVoter.snapshot();
    await draculaVoter.distributeAll();
    // console.log("timestamp", await helper.getTimestamp());
    // console.log("active period", await draculaMinter.activePeriod());
  });
  it("Claim rewards for epoch 3 (with usdc non claimed at epoch 2)", async () => {
    const balanceBefore = await usdc.balanceOf(owner.address);
    const claimableBondRewards = await draculaVoter.getAllClaimableBondRewards(
      3
    );
    await bribeBond.claimBondRewards([poolFang.address], 3);
    await bribeBond.claimBondRewards([pool_usdc_mute.address], 3);
    const balanceAfter = await usdc.balanceOf(owner.address);
    expect(claimableBondRewards[0].gauge).to.be.equal(poolFang.address);
    expect(claimableBondRewards[0].reward).to.be.equal("333333334");
    expect(claimableBondRewards[1].gauge).to.be.equal(pool_usdc_mute.address);
    expect(claimableBondRewards[1].reward).to.be.equal("666666669");
    expect(balanceAfter.sub(balanceBefore)).to.be.equal("1000000003");
  });
});
