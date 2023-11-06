const {expect} = require("chai");
const {retrieveAccounts, expect_number} = require("./utils");
const {AdminRole} = require("./adminable.test");


describe("FeeProvider", function(){
    let accounts;
    let Treasury;
    let Token;
    let FeeProvider;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const TokenMaster = await hre.ethers.getContractFactory("Token");
        Token = await TokenMaster.deploy("USDT", "USDT");
        await Token.deployed();
        const TreasuryMaster = await hre.ethers.getContractFactory("Treasury");
        Treasury = await TreasuryMaster.deploy(accounts[0].address);
        await Treasury.deployed();
        const FeeProviderTest = await hre.ethers.getContractFactory("FeeProviderTest");
        FeeProvider = await FeeProviderTest.deploy(Token.address, Treasury.address, accounts[0].address, 1000);
        await FeeProvider.deployed();
        await Treasury.setOperator(FeeProvider.address);
    });

    it("Must be deployed", async function() {
        expect(await FeeProvider.platformWallet()).to.equal(accounts[0].address);
        expect(await FeeProvider.treasury()).to.equal(Treasury.address);
        expect(await FeeProvider.token()).to.equal(Token.address);
        expect(await Treasury.operator()).to.equal(FeeProvider.address);
        expect(await FeeProvider.baseFee()).to.equal(1000);
    });

    it("Must take tokens", async function() {
        await Token.connect(accounts[0]).mint(accounts[1].address, 1000);
        await Token.connect(accounts[1]).approve(FeeProvider.address, 999);
        await FeeProvider.takeToken(accounts[1].address, 999);
        expect_number(await Token.balanceOf(Treasury.address)).to.equal(999);
        expect_number(await Token.balanceOf(accounts[1].address)).to.equal(1);
    });

    it("Must give tokens", async function() {
        await Token.connect(accounts[0]).mint(Treasury.address, 1000);
        await FeeProvider.giveToken(accounts[1].address, 999);
        expect_number(await Token.balanceOf(Treasury.address)).to.equal(1);
        expect_number(await Token.balanceOf(accounts[1].address)).to.equal(999);
    });

    it("Platform wallet must be updated by owner or developer", async function() {
        await FeeProvider.connect(accounts[0]).setPlatformWallet(accounts[3].address);
        expect(await FeeProvider.platformWallet()).to.equal(accounts[3].address);
        await FeeProvider.approveAdmin(accounts[1].address, AdminRole['Developer']);
        await FeeProvider.connect(accounts[1]).setPlatformWallet(accounts[4].address);
        expect(await FeeProvider.platformWallet()).to.equal(accounts[4].address);
        await expect(FeeProvider.connect(accounts[2]).setPlatformWallet(accounts[5].address))
            .to.be.revertedWith("Adminable: caller is not an admin");
    });

    it("Treasury must be updated by owner or developer", async function() {
        await FeeProvider.connect(accounts[0]).setTreasury(Token.address);
        expect(await FeeProvider.treasury()).to.equal(Token.address);
        await FeeProvider.approveAdmin(accounts[1].address, AdminRole['Developer']);
        await FeeProvider.connect(accounts[1]).setTreasury(Treasury.address);
        expect(await FeeProvider.treasury()).to.equal(Treasury.address);
        await expect(FeeProvider.connect(accounts[2]).setTreasury(Token.address))
            .to.be.revertedWith("Adminable: caller is not an admin");
    });

    it("Must give base fees", async function() {
        expect(await FeeProvider.getFees(0)).to.equal(1000);
    });

    it("Base Fees must be updated by owner or developer", async function() {
        await FeeProvider.connect(accounts[0]).setBaseFees(120);
        expect(await FeeProvider.baseFee()).to.equal(120);
        await FeeProvider.approveAdmin(accounts[1].address, AdminRole['Developer']);
        await FeeProvider.connect(accounts[1]).setBaseFees(99);
        expect(await FeeProvider.baseFee()).to.equal(99);
        await expect(FeeProvider.connect(accounts[2]).setBaseFees(1000))
            .to.be.revertedWith("Adminable: caller is not an admin");
    });

    it("Can not set baseFee more than 25%", async function() {
        await expect(FeeProvider.connect(accounts[0]).setBaseFees(2501))
            .to.be.revertedWith("FeeProvider: baseFee must be no more than 25%");
    });

    it("Can not set zero type", async function() {
        await expect(FeeProvider.connect(accounts[0]).setFeeType(0, [1500, [accounts[11].address, accounts[12].address], [700, 1300]]))
            .to.be.revertedWith("FeeProvider: zero feeType is immutable");
    });

    it("Must set feeMeta by owner or developer", async function() {
        await FeeProvider.connect(accounts[0]).setFeeType(1, [3000, [accounts[11].address, accounts[12].address], [700, 1300]]);
        const meta = await FeeProvider.getMeta(1);
        expect(meta.baseFee).to.equal(3000);
        expect(JSON.stringify(meta.fractions)).to.equal(JSON.stringify([700, 1300]));
        expect(JSON.stringify(meta.beneficiaries)).to.equal(JSON.stringify([accounts[11].address, accounts[12].address]));
        await FeeProvider.approveAdmin(accounts[1].address, AdminRole['Developer']);
        await FeeProvider.connect(accounts[1]).setFeeType(1, [3000, [accounts[11].address, accounts[12].address], [700, 1300]]);
        await expect(FeeProvider.connect(accounts[2]).setFeeType(1, [3000, [accounts[11].address, accounts[12].address], [700, 1300]]))
            .to.be.revertedWith("Adminable: caller is not an admin");
    });

    it("Can not set baseFee more than 100%", async function() {
        await expect(FeeProvider.connect(accounts[0]).setFeeType(1, [10001, [accounts[11].address, accounts[12].address], [700, 1300]]))
            .to.be.revertedWith("FeeProvider: baseFee must be no more than 100%");
    });

    it("Can not set fractions more than baseFee", async function() {
        await expect(FeeProvider.connect(accounts[0]).setFeeType(1, [1500, [accounts[11].address, accounts[12].address], [700, 1300]]))
            .to.be.revertedWith("FeeProvider: fraction fee sum more than baseFee");
    });

    it("Must send baseFees", async function() {
        await Token.mint(Treasury.address, 999);
        await FeeProvider.sendFees(0, 999);
        expect_number(await Token.balanceOf(Treasury.address)).to.equal(900);
        expect_number(await Token.balanceOf(accounts[0].address)).to.equal(99);
    });

    it("Must distribute fees across beneficiaries", async function() {
        await Token.mint(Treasury.address, 999);
        await FeeProvider.connect(accounts[0]).setFeeType(1, [3000, [accounts[11].address, accounts[12].address], [700, 1300]]);
        await FeeProvider.sendFees(1, 999);
        expect_number(await Token.balanceOf(Treasury.address)).to.equal(700);
        expect_number(await Token.balanceOf(accounts[0].address)).to.equal(101);
        expect_number(await Token.balanceOf(accounts[11].address)).to.equal(69);
        expect_number(await Token.balanceOf(accounts[12].address)).to.equal(129);
    });
});

