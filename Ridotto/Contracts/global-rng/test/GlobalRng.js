const { expect, assert } = require('chai');
const { upgrades, ethers } = require('hardhat');
const {
  globalRngSettings,
  chainlinkProviderSettings,
  customProviderSettings,
} = require('./shared/globalRngSettings.js');

describe('Global RNG tests', function () {
  let owner,
    operator,
    consumers = [];
  let globalRng, deployGlobalRng;

  before('Deploy Global RNG', async function () {
    // Set vars
    [owner, operator, consumers[0], consumers[1], consumers[2]] = await ethers.getSigners();

    // Deploy Global RNG
    globalRng = await ethers.getContractFactory('GlobalRng');
    deployGlobalRng = await upgrades.deployProxy(globalRng, [], { initializer: 'init' });

    // Set Global RNG consumers
    let CONSUMER_ROLE = deployGlobalRng.CONSUMER_ROLE();
    await deployGlobalRng.grantRole(CONSUMER_ROLE, consumers[0].address);

    // Set  Global RNG operator
    let OPERATOR_ROLE = deployGlobalRng.OPERATOR_ROLE();
    await deployGlobalRng.grantRole(OPERATOR_ROLE, operator.address);
  });
  /**
   * Testing the addition of a new provider
   */
  it(`Should register new provider when inputs are corrects`, async () => {
    const providerId = await deployGlobalRng
      .connect(operator)
      .callStatic.addProvider([
        customProviderSettings.setup.name,
        customProviderSettings.setup.isActive,
        customProviderSettings.setup.providerAddress,
        customProviderSettings.setup.callbackGasLimit,
        customProviderSettings.setup.paramData,
      ]);
    await deployGlobalRng
      .connect(operator)
      .addProvider([
        customProviderSettings.setup.name,
        customProviderSettings.setup.isActive,
        customProviderSettings.setup.providerAddress,
        customProviderSettings.setup.callbackGasLimit,
        customProviderSettings.setup.paramData,
      ]);

    const provider = await deployGlobalRng.providers(providerId);
    assert.equal(provider.name, customProviderSettings.setup.name, "Wrong provider's name");
    assert.equal(provider.isActive, customProviderSettings.setup.isActive, "Wrong provider's status");
    assert.equal(provider.providerAddress, customProviderSettings.setup.providerAddress, "Wrong provider's address");
    assert.equal(provider.gasLimit, customProviderSettings.setup.callbackGasLimit, "Wrong provider's gas limit");
  });

  /**
   * Testing unauthorized game consumer request a random number
   */
  it(`Should raise exception when game consumer isn't authorized`, async () => {
    let pId = 1;
    let functionData = '0x00';
    await expect(deployGlobalRng.connect(consumers[1]).requestRandomWords(pId, functionData)).to.be.reverted;
  });

  /**
   * Testing generating random number using inexistent provider
   */
  it(`Should raise exception when provider don't exist`, async () => {
    let pId = await deployGlobalRng.providerCounter();
    pId++;
    let functionData = '0x00';
    await expect(deployGlobalRng.connect(consumers[0]).requestRandomWords(pId, functionData)).to.be.revertedWith(
      globalRngSettings.error.providerDontExist,
    );
  });

  /**
   * Testing gerarating random number with inactive provider
   */
  it(`Should raise exception when provider is inactive`, async () => {
    await deployGlobalRng
      .connect(operator)
      .addProvider([
        customProviderSettings.setup.name,
        false,
        customProviderSettings.setup.providerAddress,
        customProviderSettings.setup.callbackGasLimit,
        customProviderSettings.setup.paramData,
      ]);
    let pId = deployGlobalRng.providerCounter();
    await expect(
      deployGlobalRng.connect(consumers[0]).requestRandomWords(pId, customProviderSettings.setup.functionData),
    ).to.be.revertedWith(globalRngSettings.error.providerIsDisable);
  });

  describe('Chainlink provider', function () {
    let VRFCoordinatorV2Mock, deployVRFCoordinatorV2Mock;
    let chainlinkProviderSettingsId;
    before('Add Chainlink provider', async function () {
      //Deploy Chainlink VRF Coordinator Mock & provider
      VRFCoordinatorV2Mock = await ethers.getContractFactory('VRFCoordinatorV2Mock');
      deployVRFCoordinatorV2Mock = await VRFCoordinatorV2Mock.deploy(
        chainlinkProviderSettings.setup.baseFee,
        chainlinkProviderSettings.setup.gasPriceLink,
      );
      // Create chainlink subscription
      vrfSubscriptionId = await deployVRFCoordinatorV2Mock.callStatic.createSubscription();
      await deployVRFCoordinatorV2Mock.createSubscription();
      await deployVRFCoordinatorV2Mock.fundSubscription(vrfSubscriptionId, ethers.utils.parseUnits('1', 'ether'));
      // Add Ridotto deployGlobalRng to chainlink consumer list
      await deployVRFCoordinatorV2Mock.addConsumer(vrfSubscriptionId, deployGlobalRng.address);
      // Add  chainlink provider to the Global RNG
      await deployGlobalRng
        .connect(operator)
        .addProvider([
          chainlinkProviderSettings.setup.name,
          chainlinkProviderSettings.setup.isActive,
          deployVRFCoordinatorV2Mock.address,
          chainlinkProviderSettings.setup.callbackGasLimit,
          chainlinkProviderSettings.setup.paramData,
        ]);
      chainlinkProviderSettingsId = await deployGlobalRng.providerCounter();
    });

    /**
     * Testing adding an extra chainlink provider
     */
    it(`Should raise exception when adding multiple chainlink providers`, async () => {
      await expect(
        deployGlobalRng
          .connect(operator)
          .addProvider([
            chainlinkProviderSettings.setup.name,
            chainlinkProviderSettings.setup.isActive,
            deployVRFCoordinatorV2Mock.address,
            chainlinkProviderSettings.setup.callbackGasLimit,
            chainlinkProviderSettings.setup.paramData,
          ]),
      ).to.be.revertedWith(globalRngSettings.error.multipleChainlinkProvider);
    });

    /**
     * Testing request random words using chainlink provider
     */
    it(`Should return a random word using chainlink provider`, async () => {
      const randomNumber = Math.floor(Math.random() * 10 ** 10);
      const reqId = await deployGlobalRng
        .connect(consumers[0])
        .callStatic.requestRandomWords(chainlinkProviderSettingsId, chainlinkProviderSettings.setup.functionData);
      await deployGlobalRng
        .connect(consumers[0])
        .requestRandomWords(chainlinkProviderSettingsId, chainlinkProviderSettings.setup.functionData);

      await deployVRFCoordinatorV2Mock.fulfillRandomWordsWithOverride(
        await deployGlobalRng.reqIds(reqId),
        deployGlobalRng.address,
        [randomNumber],
      );
      const resultChainlink = await deployGlobalRng.viewRandomResult(chainlinkProviderSettingsId, reqId);
      assert.equal(resultChainlink.toNumber(), randomNumber, 'Wrong random number');
    });

    /**
     * Testing only chainlink can fulfill random words
     */
    it(`Should raise exception when callback sender is unauthorized`, async () => {
      const randomNumber = Math.floor(Math.random() * 10 ** 10);
      const reqId = 1;
      await expect(deployGlobalRng.rawFulfillRandomWords(reqId, [randomNumber])).to.be.revertedWith(
        globalRngSettings.error.unauthorizedVrfCoordinator,
      );
    });
  });

  describe('Custom provider', function () {
    let CustomCoordinatorV2Mock, deployCustomCoordinatorV2Mock;
    let customPId;
    before('Add Custom provider', async function () {
      CustomCoordinatorV2Mock = await ethers.getContractFactory('CustomRng');
      deployCustomCoordinatorV2Mock = await CustomCoordinatorV2Mock.deploy();

      await deployGlobalRng
        .connect(operator)
        .addProvider([
          customProviderSettings.setup.name,
          customProviderSettings.setup.isActive,
          deployCustomCoordinatorV2Mock.address,
          customProviderSettings.setup.callbackGasLimit,
          customProviderSettings.setup.paramData,
        ]);

      customPId = await deployGlobalRng.providerCounter();
    });
    /**
     * Testing generating random number using custom provider
     */
    it(`Should return a random word`, async () => {
      const randomNumber = Math.floor(Math.random() * 10 ** 10);
      const reqId = await deployGlobalRng
        .connect(consumers[0])
        .callStatic.requestRandomWords(customPId, customProviderSettings.setup.functionData);
      await deployGlobalRng
        .connect(consumers[0])
        .requestRandomWords(customPId, customProviderSettings.setup.functionData);
      await deployCustomCoordinatorV2Mock.rng(
        deployGlobalRng.address,
        await deployGlobalRng.reqIds(reqId),
        randomNumber,
      );
      const resultCustom = await deployGlobalRng.viewRandomResult(customPId, reqId);
      assert.equal(resultCustom.toNumber(), randomNumber);
    });
    /**
     * Testing reconfigure custom provider
     */
    it(`Should configure a provider when exist`, async () => {
      await deployGlobalRng
        .connect(operator)
        .configureProvider(customPId, [
          customProviderSettings.secondSetup.name,
          customProviderSettings.secondSetup.isActive,
          customProviderSettings.secondSetup.providerAddress,
          customProviderSettings.secondSetup.callbackGasLimit,
          customProviderSettings.secondSetup.paramData,
        ]);
      const provider = await deployGlobalRng.providers(customPId);
      assert.equal(provider.name, customProviderSettings.secondSetup.name);
      assert.equal(provider.isActive, customProviderSettings.secondSetup.isActive);
      assert.equal(provider.providerAddress, customProviderSettings.secondSetup.providerAddress);
      assert.equal(provider.gasLimit, customProviderSettings.secondSetup.callbackGasLimit);
    });
  });
});
