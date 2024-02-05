const {expect} = require("chai");
const {retrieveAccounts, expect_number} = require("./utils");
const {AdminRole} = require("./adminable.test");


describe("Initializable", function(){
    let accounts;
    let Proxy;
    let Logic;
    let logicAddress;
    let LogicMaster;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        LogicMaster = await hre.ethers.getContractFactory("ProxyLogic");
        Logic = await LogicMaster.deploy();
        await Logic.deployed();
        const ProxyMaster = await hre.ethers.getContractFactory("Proxy");
        Proxy = await ProxyMaster.deploy(Logic.address, []);
        await Proxy.deployed();
        logicAddress = Logic.address;
        Logic = LogicMaster.attach(Proxy.address);
    });

    it("Must be deployed with implementation", async function() {
        expect(await Proxy.getImplementation()).to.equal(logicAddress);
    });

    it("Must be initialized once", async function() {
        await expect(Logic.construct(11))
            .to.emit(Logic, "Initialized");
    });

    it("Cannot be initialized twice", async function() {
        await Logic.construct(11);
        await expect(Logic.construct(22))
            .to.be.revertedWith("Initializable: already initialized");
    });

    it("Can be upgraded and initialized", async function() {
        await Logic.construct(11);
        const Logic2 = await LogicMaster.deploy();
        await Logic2.deployed();
        await expect(Proxy.upgradeTo(Logic2.address))
            .to.emit(Logic, "InitializationRefreshed");
        await expect(Logic.construct(33))
            .to.emit(Logic, "Initialized");
    });

    it("Can be upgraded and called and initialized", async function() {
        await Logic.construct(11);
        const Logic2 = await LogicMaster.deploy();
        await Logic2.deployed();
        await expect(Proxy.upgradeToAndCall(Logic2.address, "0x919784af", false))
            .to.emit(Logic, "InitializationRefreshed");
        await expect(Logic.construct(44))
            .to.emit(Logic, "Initialized");
    });
});



