const {expect} = require("chai");
const {retrieveAccounts, expect_number} = require("./utils");
const {AdminRole} = require("./adminable.test");
const {min} = require("hardhat/internal/util/bigint");
const {ethers} = require("hardhat");


describe("GameProvider Core", function(){
    let accounts;
    let Token;
    let Treasury;
    let GP;
    const hash1 = "1634671349841667997392702300237853842083701627437768556355788310218539008";
    const hash2 = "1766847064778384329583297500742918515827483896875618958121606201292619777";

    async function mint(to, amount, approvedTo=undefined) {
        await Token.connect(accounts[0]).mint(to.address, amount);
        if(approvedTo){
            await Token.connect(to).approve(approvedTo.address, amount);
        }
    }

    async function expectBalance(account, amount) {
        expect_number(await Token.balanceOf(account.address)).to.equal(amount);
    }

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const TokenMaster = await hre.ethers.getContractFactory("Token");
        Token = await TokenMaster.deploy("MyToken", "MT");
        await Token.deployed();
        const TreasuryMaster = await hre.ethers.getContractFactory("Treasury");
        Treasury = await TreasuryMaster.deploy(accounts[1].address);
        await Treasury.deployed();
        const MatchProviderMaster = await hre.ethers.getContractFactory("GameProvider");
        GP = await MatchProviderMaster.deploy();
        await GP.deployed();
        const ProxyMaster = await hre.ethers.getContractFactory("Proxy");
        const Proxy = await ProxyMaster.deploy(GP.address, []);
        await Proxy.deployed();
        await Treasury.setOperator(Proxy.address);
        GP = MatchProviderMaster.attach(Proxy.address);
        await GP.construct(Token.address, Treasury.address, accounts[10].address, 1000, 100);
    });

    it("Must be constructed", async function() {
        expect(await GP.platformWallet()).to.equal(accounts[10].address);
        expect(await GP.treasury()).to.equal(Treasury.address);
        expect(await GP.token()).to.equal(Token.address);
        expect(await Treasury.operator()).to.equal(GP.address);
        expect(await GP.baseFee()).to.equal(1000);
    });

    it("Cannot be constructed twice", async function() {
        await expect(GP.construct(Token.address, Treasury.address, accounts[10].address, 1000, 100))
            .to.be.revertedWith("Initializable: already initialized");
    });

    it("Must create match", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await mint(accounts[3], 250, GP);
        await mint(accounts[4], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]);
        await expectBalance(accounts[1], 0);
        await expectBalance(accounts[2], 0);
        await expectBalance(accounts[3], 0);
        await expectBalance(accounts[4], 0);
    });

    it("Must start only from Server Account", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await mint(accounts[3], 250, GP);
        await mint(accounts[4], 250, GP);
        await expect(GP.connect(accounts[1]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]))
            .to.be.revertedWith("Adminable: caller is not an admin");
        await GP.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Backend']);
        await GP.connect(accounts[1]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]);
    });


    it("Must finish match with one winner", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await GP.connect(accounts[0]).finishGame(hash1, 0, accounts[1].address);
        await expectBalance(accounts[1], 450);
        await expectBalance(accounts[2], 0);
        await expectBalance(accounts[10], 50);
    });

    it("Must finish only from Server Account", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await expect(GP.connect(accounts[1]).finishGame(hash1, 0, accounts[1].address))
            .to.be.revertedWith("Adminable: caller is not an admin");
        await GP.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Backend']);
        await GP.connect(accounts[1]).finishGame(hash1, 0, accounts[1].address);
    });

    it("Must finish match with multiple winners", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await mint(accounts[3], 250, GP);
        await mint(accounts[4], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]);
        await GP.connect(accounts[0]).finishGameWithPlaces(hash1, 0, [accounts[1].address, accounts[2].address], [9000, 1000]);
        await expectBalance(accounts[1], 810);
        await expectBalance(accounts[2], 90);
        await expectBalance(accounts[3], 0);
        await expectBalance(accounts[4], 0);
        await expectBalance(accounts[10], 100);
    });

    it("Must finish with multiple winners only from Server Account", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await expect(GP.connect(accounts[1]).finishGameWithPlaces(hash1, 0, [accounts[1].address, accounts[2].address], [9000, 1000]))
            .to.be.revertedWith("Adminable: caller is not an admin");
        await GP.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Backend']);
        await GP.connect(accounts[1]).finishGameWithPlaces(hash1, 0, [accounts[1].address, accounts[2].address], [9000, 1000]);
    });

    it("Must cancel match", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await mint(accounts[3], 250, GP);
        await mint(accounts[4], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]);
        await GP.connect(accounts[0]).cancelGame(hash1);
        await expectBalance(accounts[1], 250);
        await expectBalance(accounts[2], 250);
        await expectBalance(accounts[3], 250);
        await expectBalance(accounts[4], 250);
    });

    it("Must cancel only from Server Account", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await expect(GP.connect(accounts[1]).cancelGame(hash1))
            .to.be.revertedWith("Adminable: caller is not an admin");
        await GP.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Backend']);
        await GP.connect(accounts[1]).cancelGame(hash1);
    });

    it("Cannot start already started", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 250, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await expect(GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]))
            .to.be.revertedWith("GameProvider: game already exists");
    });

    it("Can started finished game", async function() {
        await mint(accounts[1], 750, GP);
        await mint(accounts[2], 750, GP);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await GP.connect(accounts[0]).finishGame(hash1, 0, accounts[1].address)
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
        await GP.connect(accounts[0]).finishGameWithPlaces(hash1, 0, [accounts[1].address, accounts[2].address], [9000, 1000]);
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
    });

    it("Cannot start with zero wager", async function() {
        await mint(accounts[1], 750, GP);
        await mint(accounts[2], 750, GP);
        await GP.connect(accounts[0]).setMinimalFees(250);
        expect(await GP.minimalWager()).equal(250);
        await expect(GP.connect(accounts[0]).startGame(hash1, 0, [accounts[1].address, accounts[2].address]))
            .to.be.revertedWith("GameProvider: wager amount is too small");
        await GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address]);
    });

    it("Not less than two participants", async function() {
        await mint(accounts[1], 750, GP);
        await expect(GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address]))
            .to.be.revertedWith("GameProvider: too few participants");
    });

    it("Not more than 31 participant", async function() {
        await mint(accounts[1], 750, GP);
        await expect(GP.connect(accounts[0]).startGame(hash1, 250, Array(32).fill(accounts[1].address)))
            .to.be.revertedWith("GameProvider: too many participants");
    });

    it("Must throw unpayed players", async function() {
        await mint(accounts[1], 250, GP);
        await mint(accounts[2], 0, GP);
        await mint(accounts[3], 0, GP);
        await mint(accounts[4], 250, GP);
        const error = Buffer.from(Array(30).fill(0).concat(Array.from(Buffer.from('12')))).toString();
        await expect(GP.connect(accounts[0]).startGame(hash1, 250, [accounts[1].address, accounts[2].address, accounts[3].address, accounts[4].address]))
            .to.be.revertedWith(error);
    });
});