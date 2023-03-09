const { expect } = require("chai");
const { ethers } = require("hardhat");

const tx = async (tx) => await (await tx).wait();

describe("Migrate", function () {
  it("Migration should work", async function () {
    const Migrate = await ethers.getContractFactory("Migrate");
    const migrate = await Migrate.deploy();
    await migrate.deployed();

    const Dummy = await ethers.getContractFactory("Dummy");
    const dummy = await Dummy.deploy();
    await dummy.deployed();

    const [_owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    migrate.setToken(dummy.address);
    migrate.setSender(_owner.address);
    migrate.setIsAdmin(_owner.address, true);

    await tx(
      migrate.bulkAirdrop(
        [addr1.address, addr2.address, addr3.address, addr4.address],
        [100, 100, 100, 100]
      )
    );

    expect(await dummy.balanceOf(addr1.address)).to.equal(100);
    expect(await dummy.balanceOf(addr2.address)).to.equal(100);
    expect(await dummy.balanceOf(addr3.address)).to.equal(100);
    expect(await dummy.balanceOf(addr4.address)).to.equal(100);
    expect(await dummy.balanceOf(_owner.address)).to.equal(600);
  });

  it("Airdrop should not work twice", async function () {
    const Migrate = await ethers.getContractFactory("Migrate");
    const migrate = await Migrate.deploy();
    await migrate.deployed();

    const Dummy = await ethers.getContractFactory("Dummy");
    const dummy = await Dummy.deploy();
    await dummy.deployed();

    const [_owner, addr1] = await ethers.getSigners();

    migrate.setToken(dummy.address);
    migrate.setSender(_owner.address);
    migrate.setIsAdmin(_owner.address, true);

    await tx(migrate.bulkAirdrop([addr1.address], [100]));
    expect(await dummy.balanceOf(addr1.address)).to.equal(100);

    await tx(migrate.bulkAirdrop([addr1.address], [100]));
    expect(await dummy.balanceOf(addr1.address)).to.equal(100);
  });

  it("Migration should not work if sent by non-admin", async function () {
    const Migrate = await ethers.getContractFactory("Migrate");
    const migrate = await Migrate.deploy();
    await migrate.deployed();

    const Dummy = await ethers.getContractFactory("Dummy");
    const dummy = await Dummy.deploy();
    await dummy.deployed();

    const [_owner, addr1] = await ethers.getSigners();

    migrate.setToken(dummy.address);
    migrate.setSender(_owner.address);
    migrate.setIsAdmin(_owner.address, true);

    await expect(
      tx(migrate.connect(addr1.address).bulkAirdrop([addr1.address], [100]))
    ).to.be.reverted;
  });
});
