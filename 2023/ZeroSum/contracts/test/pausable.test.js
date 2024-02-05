const {expect} = require("chai");
const {retrieveAccounts} = require("./utils");
const {AdminRole} = require("./adminable.test");


describe("Pausable", function(){
    let accounts;
    let P;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const PausableTest = await hre.ethers.getContractFactory("PausableTest");
        P = await PausableTest.deploy();
        await P.deployed();
    });

    it("Must be unpaused at the start", async function() {
        expect(await P.paused()).to.equal(false);
    });

    it("Must be pausable and unpausable", async function() {
       await expect(P.connect(accounts[0]).pause())
           .to.emit(P, "Paused")
           .withArgs(accounts[0].address);
       expect(await P.paused()).to.equal(true);
        await expect(P.connect(accounts[0]).unpause())
            .to.emit(P, "Unpaused")
            .withArgs(accounts[0].address);
        expect(await P.paused()).to.equal(false);
    });

    it("Must do unpaused stuff and not paused stuff", async function() {
        await P.doWhenNotPaused();
        await expect(P.doWhenPaused()).to.be.revertedWith("Pausable: not paused");
    });

    it("Must do paused stuff and not unpaused stuff", async function() {
        await P.connect(accounts[0]).pause()
        await P.doWhenPaused();
        await expect(P.doWhenNotPaused()).to.be.revertedWith("Pausable: paused");
    });

    it("Only owner or Developer can pause and unpause", async function() {
        await P.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Developer']);
        await expect(P.connect(accounts[2]).pause()).to.be.revertedWith("Adminable: caller is not an admin");
        P.connect(accounts[1]).pause();
        await expect(P.connect(accounts[2]).unpause()).to.be.revertedWith("Adminable: caller is not an admin");
        P.connect(accounts[1]).unpause();
    });
});



