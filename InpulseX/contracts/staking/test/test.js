const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const tx = async (tx) => await (await tx).wait();

const TRANSFER721 = "safeTransferFrom(address,address,uint256)";

const later = async (days) => (await time.latest()) + days * 60 * 60 * 24;

const deployAll = async () => {
  const Dummy20 = await ethers.getContractFactory("Dummy20");
  const dummy20 = await Dummy20.deploy();
  await dummy20.deployed();

  const Dummy721 = await ethers.getContractFactory("Dummy721");
  const dummy721 = await Dummy721.deploy();
  await dummy721.deployed();

  const Dummy1155 = await ethers.getContractFactory("Dummy1155");
  const dummy1155 = await Dummy1155.deploy();
  await dummy1155.deployed();

  const Dummy1363 = await ethers.getContractFactory("Dummy1363");
  const dummy1363 = await Dummy1363.deploy();
  await dummy1363.deployed();

  const ERC20StakerERC20Rewarder = await ethers.getContractFactory(
    "ERC20StakerERC20Rewarder"
  );
  const erc20StakerERC20Rewarder = await ERC20StakerERC20Rewarder.deploy();
  await erc20StakerERC20Rewarder.deployed();

  const ERC20StakerERC1155Rewarder = await ethers.getContractFactory(
    "ERC20StakerERC1155Rewarder"
  );
  const erc20StakerERC1155Rewarder = await ERC20StakerERC1155Rewarder.deploy();
  await erc20StakerERC1155Rewarder.deployed();

  const ERC721StakerERC20Rewarder = await ethers.getContractFactory(
    "ERC721StakerERC20Rewarder"
  );
  const erc721StakerERC20Rewarder = await ERC721StakerERC20Rewarder.deploy();
  await erc721StakerERC20Rewarder.deployed();

  const ERC721StakerERC1155Rewarder = await ethers.getContractFactory(
    "ERC721StakerERC1155Rewarder"
  );
  const erc721StakerERC1155Rewarder =
    await ERC721StakerERC1155Rewarder.deploy();
  await erc721StakerERC1155Rewarder.deployed();

  const ERC1155StakerERC20Rewarder = await ethers.getContractFactory(
    "ERC1155StakerERC20Rewarder"
  );
  const erc1155StakerERC20Rewarder = await ERC1155StakerERC20Rewarder.deploy();
  await erc1155StakerERC20Rewarder.deployed();

  const ERC1155StakerERC1155Rewarder = await ethers.getContractFactory(
    "ERC1155StakerERC1155Rewarder"
  );
  const erc1155StakerERC1155Rewarder =
    await ERC1155StakerERC1155Rewarder.deploy();
  await erc1155StakerERC1155Rewarder.deployed();

  const ERC1363StakerERC20Rewarder = await ethers.getContractFactory(
    "ERC1363StakerERC20Rewarder"
  );
  const erc1363StakerERC20Rewarder = await ERC1363StakerERC20Rewarder.deploy();
  await erc1363StakerERC20Rewarder.deployed();

  const ERC1363StakerERC1155Rewarder = await ethers.getContractFactory(
    "ERC1363StakerERC1155Rewarder"
  );
  const erc1363StakerERC1155Rewarder =
    await ERC1363StakerERC1155Rewarder.deploy();
  await erc1363StakerERC1155Rewarder.deployed();

  return {
    dummy20,
    dummy721,
    dummy1155,
    dummy1363,
    erc20StakerERC20Rewarder,
    erc20StakerERC1155Rewarder,
    erc721StakerERC20Rewarder,
    erc721StakerERC1155Rewarder,
    erc1155StakerERC20Rewarder,
    erc1155StakerERC1155Rewarder,
    erc1363StakerERC20Rewarder,
    erc1363StakerERC1155Rewarder,
  };
};

describe("Staking", function () {
  it("All contracts should be deployable", async function () {
    const contracts = await deployAll();
    expect(
      Object.values(contracts)
        .map((contract) => contract.address)
        .map((address) => address.match(/0x[a-f0-9]{40}/i))
        .every(Boolean)
    ).to.be.true;
  });

  it("ERC20Staker should not allow unstaking before unlock", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));
    await tx(staker.setUnlockTime(await later(1)));
    await tx(token.connect(user).approve(staker.address, 100));
    await tx(staker.connect(user).stake(100));

    await expect(staker.connect(user).unstake()).to.be.revertedWith(
      "Cannot unstake yet"
    );
  });

  it("ERC1363Staker should not allow unstaking before unlock", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));
    await tx(staker.setUnlockTime(await later(1)));
    await tx(token.connect(user).transferAndCall(staker.address, 100, 0x0));

    await expect(staker.connect(user).unstake()).to.be.revertedWith(
      "Cannot unstake yet"
    );
  });

  it("ERC721Staker should not allow unstaking before unlock", async function () {
    const { dummy721: token, erc721StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(token[TRANSFER721](owner.address, user.address, 0));
    await tx(staker.setStakingToken(token.address));
    await tx(staker.setUnlockTime(await later(1)));
    await tx(token.connect(user).approve(staker.address, 0));
    await tx(staker.connect(user).stake(0));

    await expect(staker.connect(user).unstake()).to.be.revertedWith(
      "Cannot unstake yet"
    );
  });

  it("ERC1155Staker should not allow unstaking before unlock", async function () {
    const { dummy1155: token, erc1155StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(token.safeTransferFrom(owner.address, user.address, 0, 100, 0x0));
    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setUnlockTime(await later(1)));
    await tx(token.connect(user).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user).stake(100));

    await expect(staker.connect(user).unstake()).to.be.revertedWith(
      "Cannot unstake yet"
    );
  });

  it("ERC20Staker should not allow staking after staking window", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(-1)));
    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));
    await tx(token.connect(user).approve(staker.address, 100));

    await expect(staker.connect(user).stake(100)).to.be.revertedWith(
      "Cannot stake anymore"
    );
  });

  it("ERC1363Staker should not allow staking after staking window", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(-1)));
    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));

    await expect(
      tx(token.connect(user).transferAndCall(staker.address, 100, 0x0))
    ).to.be.revertedWith("Cannot stake anymore");
  });

  it("ERC721Staker should not allow staking after staking window", async function () {
    const { dummy721: token, erc721StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(-1)));
    await tx(token[TRANSFER721](owner.address, user.address, 0));
    await tx(staker.setStakingToken(token.address));
    await tx(token.connect(user).approve(staker.address, 0));

    await expect(tx(staker.connect(user).stake(0))).to.be.revertedWith(
      "Cannot stake anymore"
    );
  });

  it("ERC1155Staker should not allow staking after staking window", async function () {
    const { dummy1155: token, erc1155StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(-1)));
    await tx(token.safeTransferFrom(owner.address, user.address, 0, 100, 0x0));
    await tx(staker.setStakingToken(token.address, 0));
    await tx(token.connect(user).setApprovalForAll(staker.address, true));

    await expect(tx(staker.connect(user).stake(100))).to.be.revertedWith(
      "Cannot stake anymore"
    );
  });

  it("ERC20Staker return full amount to user on unstake", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(1)));
    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));
    await tx(token.connect(user).approve(staker.address, 100));

    await tx(staker.connect(user).stake(100));
    expect(await token.balanceOf(user.address)).to.be.equal("0");
    expect(await token.balanceOf(staker.address)).to.be.equal("100");

    await time.increaseTo(await later(1));
    await tx(staker.connect(user).unstake());

    expect(await token.balanceOf(user.address)).to.be.equal("100");
    expect(await token.balanceOf(staker.address)).to.be.equal("0");
  });

  it("ERC1363Staker return full amount to user on unstake", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(token.transfer(user.address, 100));
    await tx(staker.setStakingToken(token.address));

    await tx(staker.setUnlockTime(await later(5)));
    await tx(token.connect(user).transferAndCall(staker.address, 100, 0x0));

    expect(await token.balanceOf(user.address)).to.be.equal("0");
    expect(await token.balanceOf(staker.address)).to.be.equal("100");

    await time.increaseTo(await later(5));
    await tx(staker.connect(user).unstake());

    expect(await token.balanceOf(user.address)).to.be.equal("100");
    expect(await token.balanceOf(staker.address)).to.be.equal("0");
  });

  it("ERC721Staker return full amount to user on unstake", async function () {
    const { dummy721: token, erc721StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(token[TRANSFER721](owner.address, user.address, 0));
    await tx(staker.setStakingToken(token.address));
    await tx(token.connect(user).approve(staker.address, 0));

    await tx(staker.setUnlockTime(await later(10)));
    await tx(staker.connect(user).stake(0));
    expect(await token.ownerOf(0)).to.be.equal(staker.address);

    await time.increaseTo(await later(10));
    await tx(staker.connect(user).unstake());
    expect(await token.ownerOf(0)).to.be.equal(user.address);
  });

  it("ERC1155Staker return full amount to user on unstake", async function () {
    const { dummy1155: token, erc1155StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(token.safeTransferFrom(owner.address, user.address, 0, 100, 0x0));
    await tx(staker.setStakingToken(token.address, 0));
    await tx(token.connect(user).setApprovalForAll(staker.address, true));

    await tx(staker.setUnlockTime(await later(15)));
    await tx(staker.connect(user).stake(100));
    expect(await token.balanceOf(user.address, 0)).to.be.equal("0");
    expect(await token.balanceOf(staker.address, 0)).to.be.equal("100");

    await time.increaseTo(await later(15));
    await tx(staker.connect(user).unstake());
    expect(await token.balanceOf(user.address, 0)).to.be.equal("100");
    expect(await token.balanceOf(staker.address, 0)).to.be.equal("0");
  });

  it("ERC20Staker ERC20Rewarder should distribute rewards correctly", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(20)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(token.connect(user1).approve(staker.address, 100));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).approve(staker.address, 300));
    await tx(staker.connect(user2).stake(300));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(20));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await token.balanceOf(user1.address)).to.be.equal("103");
    expect(await token.balanceOf(user2.address)).to.be.equal("308");
  });

  it("ERC1363Staker ERC20Rewarder should distribute rewards correctly", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(25)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(token.connect(user1).transferAndCall(staker.address, 100, 0x0));
    await tx(token.connect(user2).transferAndCall(staker.address, 300, 0x0));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(25));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await token.balanceOf(user1.address)).to.be.equal("103");
    expect(await token.balanceOf(user2.address)).to.be.equal("308");
  });

  it("ERC721Staker ERC20Rewarder should distribute rewards correctly", async function () {
    const {
      dummy20: reward,
      dummy721: token,
      erc721StakerERC20Rewarder: staker,
    } = await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address));

    await tx(token[TRANSFER721](owner.address, user1.address, 0));
    await tx(token[TRANSFER721](owner.address, user2.address, 1));
    await tx(token[TRANSFER721](owner.address, user2.address, 2));
    await tx(token[TRANSFER721](owner.address, user2.address, 3));

    await tx(token.connect(user1).approve(staker.address, 0));
    await tx(staker.connect(user1).stake(0));

    await tx(token.connect(user2).approve(staker.address, 1));
    await tx(staker.connect(user2).stake(1));

    await tx(token.connect(user2).approve(staker.address, 2));
    await tx(staker.connect(user2).stake(2));

    await tx(token.connect(user2).approve(staker.address, 3));
    await tx(staker.connect(user2).stake(3));

    await tx(reward.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address)).to.be.equal("3");
    expect(await reward.balanceOf(user2.address)).to.be.equal("8");
  });

  it("ERC1155Staker ERC20Rewarder should distribute rewards correctly", async function () {
    const {
      dummy20: reward,
      dummy1155: token,
      erc1155StakerERC20Rewarder: staker,
    } = await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setRewardToken(reward.address));

    await tx(token.safeTransferFrom(owner.address, user1.address, 0, 100, 0x0));
    await tx(token.safeTransferFrom(owner.address, user2.address, 0, 300, 0x0));

    await tx(token.connect(user1).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user2).stake(300));

    await tx(reward.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address)).to.be.equal("3");
    expect(await reward.balanceOf(user2.address)).to.be.equal("8");
  });

  it("ERC20Staker ERC1155Rewarder should distribute rewards correctly", async function () {
    const {
      dummy1155: reward,
      dummy20: token,
      erc20StakerERC1155Rewarder: staker,
    } = await deployAll();

    const [_owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address, 0));

    await tx(reward.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(token.connect(user1).approve(staker.address, 100));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).approve(staker.address, 300));
    await tx(staker.connect(user2).stake(300));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address, 0)).to.be.equal("3");
    expect(await reward.balanceOf(user2.address, 0)).to.be.equal("8");
  });

  it("ERC1363Staker ERC1155Rewarder should distribute rewards correctly", async function () {
    const {
      dummy1155: reward,
      dummy1363: token,
      erc1363StakerERC1155Rewarder: staker,
    } = await deployAll();

    const [_owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address, 0));

    await tx(reward.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(token.connect(user1).transferAndCall(staker.address, 100, 0x0));
    await tx(token.connect(user2).transferAndCall(staker.address, 300, 0x0));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address, 0)).to.be.equal("3");
    expect(await reward.balanceOf(user2.address, 0)).to.be.equal("8");
  });

  it("ER721Staker ERC1155Rewarder should distribute rewards correctly", async function () {
    const {
      dummy1155: reward,
      dummy721: token,
      erc721StakerERC1155Rewarder: staker,
    } = await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address, 0));

    await tx(reward.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token[TRANSFER721](owner.address, user1.address, 0));
    await tx(token[TRANSFER721](owner.address, user2.address, 1));
    await tx(token[TRANSFER721](owner.address, user2.address, 2));
    await tx(token[TRANSFER721](owner.address, user2.address, 3));

    await tx(token.connect(user1).approve(staker.address, 0));
    await tx(staker.connect(user1).stake(0));

    await tx(token.connect(user2).approve(staker.address, 1));
    await tx(staker.connect(user2).stake(1));

    await tx(token.connect(user2).approve(staker.address, 2));
    await tx(staker.connect(user2).stake(2));

    await tx(token.connect(user2).approve(staker.address, 3));
    await tx(staker.connect(user2).stake(3));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address, 0)).to.be.equal("3");
    expect(await reward.balanceOf(user2.address, 0)).to.be.equal("8");
  });

  it("ER1155Staker ERC1155Rewarder should distribute rewards correctly", async function () {
    const { dummy1155: token, erc1155StakerERC1155Rewarder: staker } =
      await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setRewardToken(token.address, 0));

    await tx(token.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token.safeTransferFrom(owner.address, user1.address, 0, 100, 0x0));
    await tx(token.safeTransferFrom(owner.address, user2.address, 0, 300, 0x0));

    await tx(token.connect(user1).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user2).stake(300));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user1).unstake());
    await tx(staker.connect(user2).unstake());

    expect(await token.balanceOf(user1.address, 0)).to.be.equal("103");
    expect(await token.balanceOf(user2.address, 0)).to.be.equal("308");
  });

  it("ERC20Staker should not allow unstaking twice", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));

    await tx(token.transfer(user.address, 100));
    await tx(token.connect(user).approve(staker.address, 100));
    await tx(staker.connect(user).stake(100));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user).unstake());

    expect(tx(staker.connect(user).unstake())).to.be.revertedWith(
      "Cannot unstake 0 tokens"
    );
  });

  it("ERC1363Staker should not allow unstaking twice", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [_owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));

    await tx(token.transfer(user.address, 100));
    await tx(token.connect(user).transferAndCall(staker.address, 100, 0x0));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await time.increaseTo(await later(5));

    await tx(staker.connect(user).unstake());

    expect(tx(staker.connect(user).unstake())).to.be.revertedWith(
      "Cannot unstake 0 tokens"
    );
  });

  it("ERC721Staker should not allow unstaking twice", async function () {
    const {
      dummy1155: reward,
      dummy721: token,
      erc721StakerERC1155Rewarder: staker,
    } = await deployAll();

    const [owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address, 0));

    await tx(reward.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token[TRANSFER721](owner.address, user.address, 0));

    await tx(token.connect(user).approve(staker.address, 0));
    await tx(staker.connect(user).stake(0));

    await time.increaseTo(await later(5));

    expect(tx(staker.connect(user).unstake())).to.be.revertedWith(
      "Cannot unstake 0 tokens"
    );
  });

  it("ERC1155Staker should not allow unstaking twice", async function () {
    const { dummy1155: token, erc1155StakerERC1155Rewarder: staker } =
      await deployAll();

    const [owner, user] = await ethers.getSigners();

    await tx(staker.setUnlockTime(await later(5)));

    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setRewardToken(token.address, 0));

    await tx(token.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));

    await tx(token.safeTransferFrom(owner.address, user.address, 0, 100, 0x0));
    await tx(token.connect(user).setApprovalForAll(staker.address, true));

    await tx(staker.connect(user).stake(100));
    await time.increaseTo(await later(5));
    await tx(staker.connect(user).unstake());

    expect(tx(staker.connect(user).unstake())).to.be.revertedWith(
      "Cannot unstake 0 tokens"
    );
  });

  it("ERC20Staker should allow early unstakes", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));
    await tx(staker.setPenaltyAddress(owner.address));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(staker.setUnlockTime(await later(5)));

    await tx(token.connect(user1).approve(staker.address, 100));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).approve(staker.address, 300));
    await tx(staker.connect(user2).stake(300));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await tx(staker.allowUnstakeWithPenalty(user1.address, 5));
    await tx(staker.connect(user1).unstake());
    await time.increaseTo(await later(5));
    await tx(staker.connect(user2).unstake());

    expect(await token.balanceOf(user1.address)).to.be.equal("95");
    expect(await token.balanceOf(user2.address)).to.be.equal("312");
  });

  it("ERC1363Staker should allow early unstakes", async function () {
    const { dummy1363: token, erc1363StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));
    await tx(staker.setPenaltyAddress(owner.address));

    await tx(staker.setUnlockTime(await later(5)));

    await tx(token.transfer(user1.address, 100));
    await tx(token.transfer(user2.address, 300));

    await tx(token.connect(user1).transferAndCall(staker.address, 100, 0x0));
    await tx(token.connect(user2).transferAndCall(staker.address, 300, 0x0));

    await tx(token.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await tx(staker.allowUnstakeWithPenalty(user1.address, 5));
    await tx(staker.connect(user1).unstake());
    await time.increaseTo(await later(5));
    await tx(staker.connect(user2).unstake());

    expect(await token.balanceOf(user1.address)).to.be.equal("95");
    expect(await token.balanceOf(user2.address)).to.be.equal("312");
  });

  it("ERC721Staker should allow early unstakes", async function () {
    const {
      dummy20: reward,
      dummy721: token,
      erc721StakerERC20Rewarder: staker,
    } = await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(reward.address));
    await tx(staker.setPenaltyAddress(owner.address));

    await tx(staker.setUnlockTime(await later(5)));

    await tx(token[TRANSFER721](owner.address, user1.address, 0));
    await tx(token[TRANSFER721](owner.address, user2.address, 1));
    await tx(token[TRANSFER721](owner.address, user2.address, 2));
    await tx(token[TRANSFER721](owner.address, user2.address, 3));

    await tx(token.connect(user1).approve(staker.address, 0));
    await tx(staker.connect(user1).stake(0));

    await tx(token.connect(user2).approve(staker.address, 1));
    await tx(staker.connect(user2).stake(1));

    await tx(token.connect(user2).approve(staker.address, 2));
    await tx(staker.connect(user2).stake(2));

    await tx(token.connect(user2).approve(staker.address, 3));
    await tx(staker.connect(user2).stake(3));

    await tx(reward.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await tx(staker.allowUnstakeWithPenalty(user1.address, 0));
    await tx(staker.connect(user1).unstake());
    await time.increaseTo(await later(5));
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address)).to.be.equal("0");
    expect(await reward.balanceOf(user2.address)).to.be.equal("12");
  });

  it("ERC1155Staker should allow early unstakes", async function () {
    const {
      dummy20: reward,
      dummy1155: token,
      erc1155StakerERC20Rewarder: staker,
    } = await deployAll();

    const [owner, user1, user2] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setRewardToken(reward.address));
    await tx(staker.setPenaltyAddress(owner.address));

    await tx(staker.setUnlockTime(await later(5)));

    await tx(token.safeTransferFrom(owner.address, user1.address, 0, 100, 0x0));
    await tx(token.safeTransferFrom(owner.address, user2.address, 0, 300, 0x0));

    await tx(token.connect(user1).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user1).stake(100));

    await tx(token.connect(user2).setApprovalForAll(staker.address, true));
    await tx(staker.connect(user2).stake(300));

    await tx(reward.approve(staker.address, 12));
    await tx(staker.addReward(12));

    await tx(staker.allowUnstakeWithPenalty(user1.address, 5));
    await tx(staker.connect(user1).unstake());
    await time.increaseTo(await later(5));
    await tx(staker.connect(user2).unstake());

    expect(await reward.balanceOf(user1.address)).to.be.equal("0");
    expect(await reward.balanceOf(user2.address)).to.be.equal("12");
    expect(await token.balanceOf(user1.address, 0)).to.be.equal("95");
    expect(await token.balanceOf(user2.address, 0)).to.be.equal("300");
  });

  it("ERC20Rewarder should allow reward removals by admin only", async function () {
    const { dummy20: token, erc20StakerERC20Rewarder: staker } =
      await deployAll();
    const [owner, user] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address));
    await tx(staker.setRewardToken(token.address));
    await tx(staker.setUnlockTime(await later(1)));

    const balance = await token.balanceOf(owner.address);

    await tx(token.approve(staker.address, 24));

    await tx(staker.addReward(12));
    expect(await token.balanceOf(owner.address)).to.be.equal(
      ethers.BigNumber.from(balance).sub(12)
    );

    await tx(staker.recoverRewards(12));
    expect(await token.balanceOf(owner.address)).to.be.equal(balance);

    await tx(staker.addReward(12));
    await expect(
      tx(staker.connect(user).recoverRewards(12))
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("ERC1155Rewarder should allow reward removals by admin only", async function () {
    const { dummy1155: token, erc1155StakerERC1155Rewarder: staker } =
      await deployAll();

    const [owner, user] = await ethers.getSigners();

    await tx(staker.setStakingToken(token.address, 0));
    await tx(staker.setRewardToken(token.address, 0));
    await tx(staker.setUnlockTime(await later(1)));

    const balance = await token.balanceOf(owner.address, 0);

    await tx(token.setApprovalForAll(staker.address, true));
    await tx(staker.addReward(12));
    expect(await token.balanceOf(owner.address, 0)).to.be.equal(
      ethers.BigNumber.from(balance).sub(12)
    );

    await tx(staker.recoverRewards(12));
    expect(await token.balanceOf(owner.address, 0)).to.be.equal(balance);

    await tx(staker.addReward(12));
    await expect(
      tx(staker.connect(user).recoverRewards(12))
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });
});
