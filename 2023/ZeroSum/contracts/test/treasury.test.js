const {expect} = require("chai");
const {retrieveAccounts, expect_number} = require("./utils");


describe("Treasury", function(){
    let accounts;
    let Token;
    let Treasury;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const TreasuryMaster = await hre.ethers.getContractFactory("Treasury");
        Treasury = await TreasuryMaster.deploy(accounts[1].address);
        await Treasury.deployed();
        const TokenMaster = await hre.ethers.getContractFactory("Token");
        Token = await TokenMaster.deploy("MyToken", "MT");
        await Token.deployed();
    });

    it("Operator must be set", async function() {
        expect(await Treasury.operator()).to.equal(accounts[1].address);
    });

    it("Operator must be upgraded by owner", async function() {
        await expect(Treasury.connect(accounts[0]).setOperator(accounts[2].address))
            .to.emit(Treasury, "OperatorUpgraded")
            .withArgs(accounts[2].address);
        expect(await Treasury.operator()).to.equal(accounts[2].address);
        await expect(Treasury.connect(accounts[2]).setOperator(accounts[3].address))
            .to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Must withdraw on call", async function() {
        await Token.mint(Treasury.address, 1000);
        await Treasury.connect(accounts[1]).withdraw(Token.address, accounts[2].address, 300);
        expect_number(await Token.balanceOf(accounts[2].address)).to.equal(300);
        expect_number(await Token.balanceOf(Treasury.address)).to.equal(700);
    });

    it("Must withdraw only by operator", async function() {
        await Token.mint(Treasury.address, 1000);
        await expect(Treasury.connect(accounts[2]).withdraw(Token.address, accounts[2].address, 300))
            .to.be.revertedWith("Treasury: caller is not the operator");
    });
});


