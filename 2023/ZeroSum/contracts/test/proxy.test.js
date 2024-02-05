const {expect} = require("chai");
const {retrieveAccounts, expect_number} = require("./utils");
const {AdminRole} = require("./adminable.test");


describe("Proxy", function(){
    let accounts;
    let Proxy;
    let Logic;
    let logicAddress;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const ProxyLogic = await hre.ethers.getContractFactory("ProxyLogic");
        Logic = await ProxyLogic.deploy();
        await Logic.deployed();
        const ProxyMaster = await hre.ethers.getContractFactory("Proxy");
        Proxy = await ProxyMaster.deploy(Logic.address, []);
        await Proxy.deployed();
        logicAddress = Logic.address;
        Logic = ProxyLogic.attach(Proxy.address);
    });

    it("Must be deployed with implementation", async function() {
        expect(await Proxy.getImplementation()).to.equal(logicAddress);
    });

    it("Must be inited with empty values", async function() {
        expect(JSON.stringify((await Logic.displaySlots()).map(v => v.toString()))).to.equal(JSON.stringify(Array(10).fill("0")));
    });

    it("Must share the same owners", async function() {
        await expect(Logic.connect(accounts[1]).construct(9)).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Must be manually constructed", async function() {
        Logic.connect(accounts[0]).construct(8);
        expect(JSON.stringify((await Logic.displaySlots()).map(v => v.toString())))
            .to.equal(JSON.stringify(["8"].concat(Array(9).fill("0"))));
    });

    it("Must be upgraded by owner", async function() {
        await expect(Proxy.connect(accounts[1]).upgradeTo(Proxy.address)).to.be.revertedWith("Adminable: caller is not an admin");
        await expect(Proxy.connect(accounts[0]).upgradeTo(Proxy.address))
            .to.emit(Proxy, "Upgraded")
            .withArgs(Proxy.address);
        expect(await Proxy.getImplementation()).to.equal(Proxy.address);
    });

    it("Must be upgraded and call by owner", async function() {
        const ProxyLogic = await hre.ethers.getContractFactory("ProxyLogic");
        const Logic2 = await ProxyLogic.deploy();
        await Logic2.deployed();
        await expect(Proxy.connect(accounts[1]).upgradeToAndCall(Logic2.address, [], false)).to.be.revertedWith("Adminable: caller is not an admin");
        await expect(Proxy.connect(accounts[0]).upgradeToAndCall(Logic2.address,
            "0x168d7c4700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008", false))
            .to.emit(Proxy, "Upgraded")
            .withArgs(Logic2.address);
        expect(await Proxy.getImplementation()).to.equal(Logic2.address);
        expect(JSON.stringify((await Logic.displaySlots()).map(v => v.toString())))
            .to.equal(JSON.stringify(["8"].concat(Array(9).fill("0"))));
    });

    it("Must be also upgraded by developers", async function() {
        Proxy.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Developer']);
        Proxy.connect(accounts[1]).upgradeTo(logicAddress);
        Proxy.connect(accounts[1]).upgradeToAndCall(logicAddress,
            "0x168d7c4700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008", false)
    });

    it("Must use implementation logic", async function() {
        Logic.setSlot(2, 13);
        expect(JSON.stringify((await Logic.displaySlots()).map(v => v.toString())))
            .to.equal(JSON.stringify(["0", "0", "13"].concat(Array(7).fill("0"))));
    });

    it("Must use payable methods", async function() {
        Logic.payme(1000000000, { value: ethers.utils.formatUnits(1, "gwei") });
    });

    it("Must be synchronize admins", async function() {
        await Logic.connect(accounts[0]).doAdminStuff();
        await Logic.approveAdmin(accounts[1].address, AdminRole['Backend']);
        await Logic.approveAdmin(accounts[2].address, AdminRole['Developer']);
        await Logic.connect(accounts[1]).doAdminStuff();
        await expect(Logic.connect(accounts[2]).doAdminStuff()).to.be.revertedWith("Adminable: caller is not an admin");
        await expect(Logic.connect(accounts[3]).doAdminStuff()).to.be.revertedWith("Adminable: caller is not an admin");
    });
});



