const web3 = require("web3");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { utils } = require("ethers");
const fs = require("fs");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");
const WETH = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2";

const tokens = {
  USDC: { decimals: "6" },
  MUTE: { decimals: "18" },
  WISP: { decimals: "18" },
  ZKDOGE: { decimals: "18" },
  ZKINU: { decimals: "18" },
  ZIN: { decimals: "18" },
};

class TestHelper {
  users = {};
  contracts = {};

  static largeApproval = web3.utils
    .toWei("10000000000000000000000000000")
    .toString();
  static largeApproval2 = web3.utils
    .toWei("10000000000000000000000000000")
    .toString();

  //CONTEXTS

  deployDex = async () => {
    await this._configureAccounts();
    await this.deployFakeAssets(this.users);
    await this.deployGovernanceTreasury();
    await this.deployFactory();
    await this.deployRouter();
    await this.deploySwapLibrary();
  };

  deployFakeAssets = async (users) => {
    const mockERC20Factory = await ethers.getContractFactory("MockERC20");
    let tokenContracts = {};
    for (const token in tokens) {
      let _token = tokens[token];
      const tokenContract = await mockERC20Factory.deploy(
        token,
        token,
        ethers.utils.parseEther("5000000"),
        users.owner.address,
        _token.decimals
      );
      //Distribute current token to users (1 to 8)
      for (let i = 1; i <= 8; i++) {
        const user = users["user" + i];
        let amount = ethers.utils.parseUnits("200000", _token.decimals);
        await tokenContract.connect(user).faucet(amount);
      }
      tokenContracts[token] = tokenContract;
    }
    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ tokenContracts },
    };
  };

  deployFangToken = async () => {
    //deploy
    const FangToken = await ethers.getContractFactory("Dracula");
    const fangToken = await FangToken.deploy();
    await fangToken.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ fangToken },
    };
  };

  deployVotes = async () => {
    await this.deployController();
    await this.deployBribeFactory();
    await this.deployGaugeFactory();
    await this.deployVe();
    await this.deployVeLogo();
    await this.deployDraculaVoter();
    await this.deployVeDist();
    await this.deployDraculaMinter();
  };

  deployMulticall = async () => {
    //deploy
    const Multicall = await ethers.getContractFactory("Multicall");
    const multicall = await Multicall.deploy();
    await multicall.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ multicall },
    };
  };

  ////////////
  getTimestamp = async () => {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    return block.timestamp;
  };
  getDeadline = async () => {
    const blockTimestamp = await this.getTimestamp();
    const deadline = blockTimestamp + 60 * 20;
    return deadline;
  };

  getTokens = async () => {
    const daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const dai = await ethers.getContractAt(
      "contracts/interface/IERC20.sol:IERC20",
      daiAddress
    );
    const weth = await ethers.getContractAt(
      "contracts/interface/IERC20.sol:IERC20",
      wethAddress
    );
    const beneficiaries = [this.users.owner.address];

    //Impersonate to get WETH
    const holder_weth = "0x8EB8a3b98659Cce290402893d0123abb75E3ab28"; //Avax Bridge : 100_000 Weth on this address
    const fiftyThousand = ethers.utils.parseEther("50000");

    await this.giveTokenByImpersonating(
      wethAddress,
      holder_weth,
      beneficiaries,
      fiftyThousand
    );

    //Impersonate to get DAI
    const holder_dai = "0x075e72a5eDf65F0A5f44699c7654C1a76941Ddc8"; //Avax Bridge : 250 M Dai on this address
    const oneMillion = ethers.utils.parseEther("1000000");
    await this.giveTokenByImpersonating(
      daiAddress,
      holder_dai,
      beneficiaries,
      oneMillion
    );
    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ weth, dai },
    };
  };

  deployGovernanceTreasury = async () => {
    //deploy
    const GovernanceTreasury = await ethers.getContractFactory(
      "GovernanceTreasury"
    );
    const governanceTreasury = await GovernanceTreasury.deploy();
    await governanceTreasury.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ governanceTreasury },
    };
  };

  deployFactory = async () => {
    //params
    const governanceTreasuryAddress = this.contracts.governanceTreasury.address;
    //deploy
    const DraculaFactory = await ethers.getContractFactory("DraculaFactory");
    const draculaFactory = await DraculaFactory.deploy(
      governanceTreasuryAddress
    );
    await draculaFactory.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ draculaFactory },
    };
  };

  deployRouter = async () => {
    //params
    const factoryAddress = this.contracts.draculaFactory.address;
    const wethAddress = WETH;
    //deploy
    const DraculaRouter = await ethers.getContractFactory("DraculaRouter01");
    const draculaRouter = await DraculaRouter.deploy(
      factoryAddress,
      wethAddress
    );
    await draculaRouter.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ draculaRouter },
    };
  };

  deploySwapLibrary = async () => {
    //params
    const router = this.contracts.draculaRouter.address;
    //deploy
    const SwapLibrary = await ethers.getContractFactory("SwapLibrary");
    const swapLibrary = await SwapLibrary.deploy(router);
    await swapLibrary.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ swapLibrary },
    };
  };

  deployController = async () => {
    //deploy
    const Controller = await ethers.getContractFactory("Controller");
    const controller = await Controller.deploy();
    await controller.deployed();

    //set veDist

    //set draculaVoter

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ controller },
    };
  };
  deployBribeFactory = async () => {
    //deploy
    const BribeFactory = await ethers.getContractFactory("BribeFactory");
    const bribeFactory = await BribeFactory.deploy();
    await bribeFactory.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ bribeFactory },
    };
  };

  deployGaugeFactory = async () => {
    //deploy
    const GaugeFactory = await ethers.getContractFactory("GaugeFactory");
    const gaugeFactory = await GaugeFactory.deploy();
    await gaugeFactory.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ gaugeFactory },
    };
  };

  deployVe = async () => {
    //params
    const fangTokenAddress = this.contracts.fangToken.address;
    const controllerAddress = this.contracts.controller.address;
    //deploy
    const Ve = await ethers.getContractFactory("Ve");
    const ve = await Ve.deploy(fangTokenAddress, controllerAddress);
    await ve.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ ve },
    };
  };
  deployVeLogo = async () => {
    //deploy
    const VeLogo = await ethers.getContractFactory("VeLogo");
    const veLogo = await VeLogo.deploy();
    await veLogo.deployed();

    //set veLogo in ve
    await this.contracts.ve.setVeLogo(veLogo.address);

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ veLogo },
    };
  };

  deployDraculaVoter = async () => {
    //params
    const veAddress = this.contracts.ve.address;
    const factoryAddress = this.contracts.draculaFactory.address;
    const gaugeFactoryAddress = this.contracts.gaugeFactory.address;
    const bribeFactoryAddress = this.contracts.bribeFactory.address;
    //deploy
    const DraculaVoter = await ethers.getContractFactory("DraculaVoter");
    const draculaVoter = await DraculaVoter.deploy(
      veAddress,
      factoryAddress,
      gaugeFactoryAddress,
      bribeFactoryAddress
    );
    await draculaVoter.deployed();

    // TODO: initialize()

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ draculaVoter },
    };
  };

  deployVeDist = async () => {
    //params
    const veAddress = this.contracts.ve.address;
    //deploy
    const VeDist = await ethers.getContractFactory("VeDist");
    const veDist = await VeDist.deploy(veAddress);
    await veDist.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ veDist },
    };
  };

  deployDraculaMinter = async () => {
    //params
    const veAddress = this.contracts.ve.address;
    const controllerAddress = this.contracts.controller.address;
    //deploy
    const DraculaMinter = await ethers.getContractFactory("DraculaMinter");
    const draculaMinter = await DraculaMinter.deploy(
      veAddress,
      controllerAddress
    );
    await draculaMinter.deployed();

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ draculaMinter },
    };
  };
  deployPoolFang = async () => {
    const amountUsdc = ethers.utils.parseUnits("20000", 6);
    const amountFang = ethers.utils.parseUnits("40000", 18);
    //price => 0.5$
    //1 USDC = 2 FANG
    const poolFang = this.deployPool(
      this.contracts.tokenContracts.USDC,
      this.contracts.fangToken,
      amountUsdc,
      amountFang,
      false
    );

    return poolFang;
  };
  deployPoolEth = async (token, amountToken, amountEth, isStable) => {
    const owner = this.users.owner;
    const router = this.contracts.draculaRouter;
    const factory = this.contracts.draculaFactory;

    await token.approve(router.address, amountToken);

    const tx = await router.addLiquidityETH(
      token.address,
      isStable, //isStable
      amountToken,
      amountToken,
      amountEth,
      owner.address,
      await this.getDeadline(),
      { value: amountEth }
    );
    const pairAddress = await factory.getPair(token.address, WETH, isStable);
    const pairContract = await ethers.getContractAt("DraculaPair", pairAddress);
    return pairContract;
  };
  deployPool = async (tokenOne, tokenTwo, amountOne, amountTwo, isStable) => {
    const owner = this.users.owner;
    const router = this.contracts.draculaRouter;
    const factory = this.contracts.draculaFactory;

    await tokenOne.approve(router.address, amountOne);
    await tokenTwo.approve(router.address, amountTwo);

    await router.addLiquidity(
      tokenOne.address,
      tokenTwo.address,
      isStable,
      amountOne,
      amountTwo,
      amountOne,
      amountTwo,
      owner.address,
      await this.getDeadline()
    );
    const pairAddress = await factory.getPair(
      tokenOne.address,
      tokenTwo.address,
      isStable
    );
    const pairContract = await ethers.getContractAt("DraculaPair", pairAddress);
    return pairContract;
  };

  deployBribeBond = async () => {
    // console.log(this.contracts.draculaVoter.address);
    // console.log(this.contracts.tokenContracts.USDC.address);
    const BribeBondFactory = await ethers.getContractFactory("BribeBond");
    const bribeBond = await BribeBondFactory.deploy(
      this.contracts.draculaVoter.address,
      this.contracts.draculaMinter.address,
      this.contracts.tokenContracts.USDC.address
    );
    await bribeBond.deployed();

    // // await bribeBond.setPoolFang(this.contracts.poolFang.address);

    const currentContracts = this.contracts || {};
    this.contracts = {
      ...currentContracts,
      ...{ bribeBond },
    };
  };

  _configureAccounts = async () => {
    const signers = await ethers.getSigners();
    const owner = signers[0];
    const user1 = signers[1];
    const user2 = signers[2];
    const user3 = signers[3];
    const user4 = signers[4];
    const user5 = signers[5];
    const user6 = signers[6];
    const user7 = signers[7];
    const user8 = signers[9];
    const multisigGov = signers[9];
    const veReserve = signers[10];
    const user11 = signers[11];
    const user12 = signers[12];
    const team = signers[13];
    const grant = signers[14];
    const marketing = signers[15];

    // Make users available for tests
    const currentUsers = this.users;
    this.users = {
      currentUsers,
      ...{
        owner,
        user1,
        user2,
        user3,
        user4,
        user5,
        user6,
        user7,
        user8,
        multisigGov,
        veReserve,
        user11,
        user12,
        team,
        grant,
        marketing,
      },
    };
  };

  giveTokenByImpersonating = async (
    tokenAddress,
    owner,
    beneficiaries,
    amountEach
  ) => {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [owner],
    });
    const signer = await ethers.getSigner(owner);

    const impersonate = await ethers.getContractAt(
      "contracts/interface/IERC20.sol:IERC20",
      tokenAddress,
      signer
    );
    if (beneficiaries instanceof String) {
      beneficiaries = [beneficiaries];
    }

    for (const beneficiary of beneficiaries) {
      await impersonate.transfer(beneficiary, amountEach);
    }

    await hre.network.provider.request({
      method: "hardhat_stopImpersonatingAccount",
      params: [owner],
    });
  };

  async giveToken(tokenContract, recipient, amount, decimals, addressApproval) {
    tokenContract
      .connect(this.users.owner)
      .approve(addressApproval, this.largeApproval2);
    tokenContract
      .connect(this.users.owner)
      .transfer(recipient, this.bigNumberFactory(amount, decimals));
  }

  async timeTraveller(daysNumber) {
    await hre.network.provider.request({
      method: "evm_increaseTime",
      params: [daysNumber * 86400],
    });
    await hre.network.provider.send("evm_mine");
  }
  async timeHoursTraveller(hoursNumber) {
    await hre.network.provider.request({
      method: "evm_increaseTime",
      params: [hoursNumber * 3600],
    });
    await hre.network.provider.send("evm_mine");
  }
  async getTimestamp() {
    const blockNumber = await ethers.provider.getBlockNumber();
    const block = await ethers.provider.getBlock(blockNumber);
    const blockTimestamp = block.timestamp;
    // console.log(blockTimestamp);
    return blockTimestamp;
  }
  render_svg(output, name, pathRender) {
    const raw_slice = output.slice(29);
    const decoded_json = atob(raw_slice);
    const json = JSON.parse(decoded_json);
    const image_base64 = json.image;
    let url = image_base64.replace("data:image/svg+xml;base64,", "");
    var svg = decodeURIComponent(escape(atob(url)));
    fs.writeFile(pathRender + `logo_${name}.svg`, svg, function (err) {
      if (err) throw err;
      // console.log("File is created successfully.");
    });
  }
  async getProofMerkle(arrayAddress, addressWallet) {
    const leafNodes = arrayAddress.map((addr) => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
      sortPairs: true,
    });
    const rootHash = merkleTree.getRoot();
    const hexString = rootHash.toString("hex");
    const claimingAddress = keccak256(addressWallet);
    return merkleTree.getHexProof(claimingAddress);
  }

  getRoot = (arrayAddress) => {
    const leafNodes = arrayAddress.map((addr) => keccak256(addr));
    const merkleTree = new MerkleTree(leafNodes, keccak256, {
      sortPairs: true,
    });
    const rootHash = merkleTree.getRoot();
    const hexString = rootHash.toString("hex");
    return "0x" + hexString;
  };

  bigNumberFactory = async (number, decimals) => {
    return BigNumber.from(number).mul(BigNumber.from(10).pow(decimals));
  };
}

module.exports = TestHelper;
