const {expect} = require("chai");
const {retrieveAccounts, expect_number, expect_array} = require("./utils");
const {ethers} = require("hardhat");


describe("TournamentProviderV2 Core", function(){
    let accounts;
    let Token;
    let Treasury;
    let TP;
    const hash1 = "18569430475105882587588266137607568536673111973893317399460219858819262702947";

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
        const TournamentProviderMaster = await hre.ethers.getContractFactory("TournamentProviderV2");
        TP = await TournamentProviderMaster.deploy();
        await TP.deployed();
        const ProxyMaster = await hre.ethers.getContractFactory("Proxy");
        const Proxy = await ProxyMaster.deploy(TP.address, []);
        await Proxy.deployed();
        await Treasury.setOperator(Proxy.address);
        TP = TournamentProviderMaster.attach(Proxy.address);
        await TP.construct(Token.address, Treasury.address, accounts[0].address, ethers.constants.AddressZero, 0);
    });

    it("Must be constructed", async function() {
        expect(await TP.platformWallet()).to.equal(accounts[0].address);
        expect(await TP.treasury()).to.equal(Treasury.address);
        expect(await TP.token()).to.equal(Token.address);
        expect(await Treasury.operator()).to.equal(TP.address);
        expect(await TP.baseFee()).to.equal(1000);
        expect(await TP.minimalAdmissionFee()).to.equal(1000000);
        expect(await TP.minimalSponsorPool()).to.equal(1000000);
        expect(await TP.hash()).to.equal(0);
    });

    it("Cannot be constructed twice", async function() {
        await expect(TP.construct(Token.address, Treasury.address, accounts[0].address, ethers.constants.AddressZero, 0))
            .to.be.revertedWith("Initializable: already initialized");
    });

// ++++++++++ Tournament Creation ++++++++++
    it("Must create tournament with one player", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50))
            .to.emit(TP, "TournamentCreated")
            .withArgs(hash1, accounts[1].address, 1000000, 16987654321, 50, 0, 1);
    });

    it("Must create tournament with multiple", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 0, 3, 2, 4, 0))
            .to.emit(TP, "TournamentCreated")
            .withArgs(hash1, accounts[1].address, 1000000, 0, 0, 0, 3);
    });

    it("Must create tournament with prizePool only", async function() {
        await mint(accounts[1], 1000000, TP);
        await expect(TP.connect(accounts[1]).createTournament(0, 1000000, 0, 3, 2, 4, 0))
            .to.emit(TP, "TournamentCreated")
            .withArgs(hash1, accounts[1].address, 0, 0, 0, 1000000, 3);
        await expectBalance(accounts[1], 0);
    });

    it("Must create tournament with admissionFee only", async function() {
        await mint(accounts[1], 1000000, TP);
        await expect(TP.connect(accounts[1]).createTournament(1000000, 1000000, 0, 3, 2, 4, 0))
            .to.emit(TP, "TournamentCreated")
            .withArgs(hash1, accounts[1].address, 1000000, 0, 0, 1000000, 3);
        await expectBalance(accounts[1], 0);
    });

    it("Cannot create tournament with zero fees or zero admission fees", async function() {
        await expect(TP.connect(accounts[1]).createTournament(50, 0, 0, 1, 2, 2, 0))
            .to.be.revertedWith("TournamentProviderV2: Invalid admission fee or sponsor pool");
        await expect(TP.connect(accounts[1]).createTournament(0, 50, 0, 1, 2, 2, 0))
            .to.be.revertedWith("TournamentProviderV2: Invalid admission fee or sponsor pool");
    });

    it("Cannot create tournament with invalid number of players", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 0, 1, 1, 2, 0))
            .to.be.revertedWith("TournamentProviderV2: Invalid team count restrictions");
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 0, 1, 3, 2, 0))
            .to.be.revertedWith("TournamentProviderV2: Invalid team count restrictions");
    });

    it("Cannot create tournament with zero players in Team", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 0, 0, 2, 2, 0))
            .to.be.revertedWith("TournamentProviderV2: Invalid player in team count");
    });

    it("Cannot create tournament without paying", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 1000000, 0, 1, 2, 2, 0))
            .to.be.revertedWith("TransferHelper::transferFrom: transferFrom failed");
    });

    it("Cannot create tournament without too big organizer royalty", async function() {
        await expect(TP.connect(accounts[1]).createTournament(1000000, 0, 0, 1, 2, 2, 1001))
            .to.be.revertedWith("TournamentProviderV2: Invalid organizer royalty");
        await TP.connect(accounts[1]).createTournament(1000000, 0, 0, 1, 2, 2, 1000)
    });
// ++++++++++ Team Creation ++++++++++
    it("Must create team with no teammates", async function() {
        await mint(accounts[2], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50);
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, []))
            .to.emit(TP, "ParticipantRegistered")
            .withArgs(hash1, accounts[2].address, accounts[2].address, []);
        await expectBalance(accounts[2], 0);
    });

    it("Must create team with teammates", async function() {
        await mint(accounts[2], 3000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address, accounts[4].address]))
            .to.emit(TP, "ParticipantRegistered")
            .withArgs(hash1, accounts[2].address, accounts[2].address, []);
        await expectBalance(accounts[2], 0);
    });

    it("Cannot create team for non-self name", async function() {
        await mint(accounts[2], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await expect(TP.connect(accounts[2]).register(hash1, accounts[3].address, []))
            .to.be.revertedWith("TournamentProviderV2: Team not exists yet");
    });

    it("Cannot create team if already registered", async function() {
        await mint(accounts[2], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [])
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TournamentProviderV2: Already registered");
    });

    it("Cannot create team if already registered", async function() {
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [])
        await expect(TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[2].address]))
            .to.be.revertedWith("TournamentProviderV2: Already registered");
    });

    it("Cannot create team without paying", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TransferHelper::transferFrom: transferFrom failed");
    });

    it("Cannot create team with more players that in team limit", async function() {
        await mint(accounts[2], 4000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address, accounts[4].address, accounts[5].address]))
            .to.be.revertedWith("TournamentProviderV2: Too fee places in team");
    });

    it("Cannot register to non-exist tournament", async function() {
        await expect(TP.connect(accounts[2]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot register to filled tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 2, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await expect(TP.connect(accounts[6]).register(hash1, accounts[6].address, []))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot register to started tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 2, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[6]).register(hash1, accounts[6].address, []))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot register to finished tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 2, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]);
        await expect(TP.connect(accounts[6]).register(hash1, accounts[6].address, []))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot register to canceled tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 2, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).cancelTournament(hash1);
        await expect(TP.connect(accounts[6]).register(hash1, accounts[6].address, []))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });
// ++++++++++ Joining Team ++++++++++
    it("Must join the team itself", async function() {
        await mint(accounts[2], 1000000, TP);
        await mint(accounts[3], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [])
        await expect(TP.connect(accounts[3]).register(hash1, accounts[2].address, []))
            .to.emit(TP, "ParticipantRegistered")
            .withArgs(hash1, accounts[2].address, accounts[3].address, []);
        await expectBalance(accounts[3], 0);
    });

    it("Must join the team with teammates", async function() {
        await mint(accounts[2], 1000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [])
        await expect(TP.connect(accounts[3]).register(hash1, accounts[2].address, [accounts[4].address]))
            .to.emit(TP, "ParticipantRegistered")
            .withArgs(hash1, accounts[2].address, accounts[3].address, [accounts[4].address]);
        await expectBalance(accounts[3], 0);
    });

    it("Cannot join if not enough places", async function() {
        await mint(accounts[2], 3000000, TP);
        await mint(accounts[5], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address, accounts[4].address])
        await expect(TP.connect(accounts[5]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TournamentProviderV2: Too fee places in team");
    });

    it("Cannot join if not enough places for teammates", async function() {
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[5], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address])
        await expect(TP.connect(accounts[5]).register(hash1, accounts[2].address, [accounts[4].address]))
            .to.be.revertedWith("TournamentProviderV2: Too fee places in team");
    });

    it("Cannot join without paying", async function() {
        await mint(accounts[2], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address])
        await expect(TP.connect(accounts[5]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TransferHelper::transferFrom: transferFrom failed");
    });

    it("Cannot join if already joined", async function() {
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[5], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address]);
        await TP.connect(accounts[5]).register(hash1, accounts[2].address, [])
        await expect(TP.connect(accounts[5]).register(hash1, accounts[2].address, []))
            .to.be.revertedWith("TournamentProviderV2: Already registered");
    });

    it("Cannot join if teammate already joined", async function() {
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[5], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 4, 2, 4, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address]);
        await expect(TP.connect(accounts[5]).register(hash1, accounts[2].address, [accounts[3].address]))
            .to.be.revertedWith("TournamentProviderV2: Already registered");
    });
// ++++++++++ Start Tournament ++++++++++
    it("Must start with filled", async function() {
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[4], 2000000, TP);
        await mint(accounts[8], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await TP.connect(accounts[8]).register(hash1, accounts[8].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[5].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[6].address]);
        await TP.connect(accounts[4]).register(hash1, accounts[4].address, [accounts[7].address]);
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.emit(TP, "TournamentStarted")
            .withArgs(hash1);
        await expectBalance(accounts[2], 0);
        await expectBalance(accounts[3], 0);
        await expectBalance(accounts[4], 0);
        await expectBalance(accounts[8], 1000000);
    });

    it("Must start with minimal players", async function() {
        await mint(accounts[2], 3000000, TP);
        await mint(accounts[6], 3000000, TP);
        await mint(accounts[4], 1000000, TP);
        await mint(accounts[9], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 3, 50);
        await TP.connect(accounts[4]).register(hash1, accounts[4].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address, accounts[5].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, [accounts[7].address, accounts[8].address]);
        await TP.connect(accounts[9]).register(hash1, accounts[9].address, [accounts[10].address]);
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.emit(TP, "TournamentStarted")
            .withArgs(hash1);
        await expectBalance(accounts[2], 0);
        await expectBalance(accounts[6], 0);
        await expectBalance(accounts[4], 1000000);
        await expectBalance(accounts[9], 1000000);
        await expectBalance(accounts[10], 1000000);
    });

    it("Cannot start if lobby on filled", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50);
        await mint(accounts[2], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Too few teams filled");
    });

    it("Cannot start non exist tournament", async function() {
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot start finished tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, []);
        await TP.connect(accounts[0]).startTournament(hash1);
        await TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]);
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot start canceled tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 4, 2, 4, 50);
        await TP.connect(accounts[0]).cancelTournament(hash1);
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot start started tourmanent", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, []);
        await TP.connect(accounts[0]).startTournament(hash1)
        await expect(TP.connect(accounts[0]).startTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });
// ++++++++++ Cancel Tournament ++++++++++
    it("Must cancel on registration", async function() {
        await mint(accounts[2], 3000000, TP);
        await mint(accounts[6], 3000000, TP);
        await mint(accounts[4], 1000000, TP);
        await mint(accounts[9], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 3, 2, 3, 50);
        await TP.connect(accounts[4]).register(hash1, accounts[4].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[3].address, accounts[5].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, [accounts[7].address, accounts[8].address]);
        await TP.connect(accounts[9]).register(hash1, accounts[9].address, [accounts[10].address]);
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.emit(TP, "TournamentCanceled")
            .withArgs(hash1);
        await expectBalance(accounts[1], 0);
        await expectBalance(accounts[2], 1000000);
        await expectBalance(accounts[3], 1000000);
        await expectBalance(accounts[4], 1000000);
        await expectBalance(accounts[5], 1000000);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 1000000);
        await expectBalance(accounts[8], 1000000);
        await expectBalance(accounts[9], 1000000);
        await expectBalance(accounts[10], 1000000);
    });

    it("Must cancel on filled", async function() {
        await mint(accounts[1], 1000000, TP);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[4], 2000000, TP);
        await mint(accounts[8], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 1000000, 16987654321, 2, 2, 3, 50);
        await TP.connect(accounts[8]).register(hash1, accounts[8].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[5].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[6].address]);
        await TP.connect(accounts[4]).register(hash1, accounts[4].address, [accounts[7].address]);
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.emit(TP, "TournamentCanceled")
            .withArgs(hash1);
        await expectBalance(accounts[1], 1000000);
        await expectBalance(accounts[2], 1000000);
        await expectBalance(accounts[3], 1000000);
        await expectBalance(accounts[4], 1000000);
        await expectBalance(accounts[5], 1000000);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 1000000);
        await expectBalance(accounts[8], 1000000);
    });

    it("Must cancel on started", async function() {
        await mint(accounts[1], 1000000, TP);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[4], 2000000, TP);
        await mint(accounts[8], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 1000000, 16987654321, 2, 2, 3, 50);
        await TP.connect(accounts[8]).register(hash1, accounts[8].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[5].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[6].address]);
        await TP.connect(accounts[4]).register(hash1, accounts[4].address, [accounts[7].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.emit(TP, "TournamentCanceled")
            .withArgs(hash1);
        await expectBalance(accounts[1], 1000000);
        await expectBalance(accounts[2], 1000000);
        await expectBalance(accounts[3], 1000000);
        await expectBalance(accounts[4], 1000000);
        await expectBalance(accounts[5], 1000000);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 1000000);
        await expectBalance(accounts[8], 1000000);
    });

    it("Cannot cancel non-existing tournament", async function() {
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot cancel finished tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 1, 2, 4, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, []);
        await TP.connect(accounts[0]).startTournament(hash1);
        await TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]);
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot cancel canceled tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await TP.connect(accounts[0]).cancelTournament(hash1)
        await expect(TP.connect(accounts[0]).cancelTournament(hash1))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });
// ++++++++++ Finishing Tournament ++++++++++
    it("Can finish tournament with single winner", async function() {
        await mint(accounts[1], 111111, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 111111, 16987654321, 3, 2, 3, 500);
        await mint(accounts[2], 3000000, TP);
        await mint(accounts[3], 3000000, TP);
        await mint(accounts[6], 1000000, TP);
        await mint(accounts[7], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address, accounts[9].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address, accounts[10].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, []);
        await TP.connect(accounts[7]).register(hash1, accounts[7].address, [accounts[8].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.emit(TP, "TournamentFinished", hash1, [accounts[2].address])
        await expectBalance(accounts[0], 611111);
        await expectBalance(accounts[1], 275002);
        await expectBalance(accounts[2], 1741666);
        await expectBalance(accounts[4], 1741666);
        await expectBalance(accounts[9], 1741666);
        await expectBalance(accounts[3], 0);
        await expectBalance(accounts[5], 0);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 1000000);
        await expectBalance(accounts[8], 1000000);
        await expectBalance(accounts[10], 0);
    });

    it("Can finish tournament with places", async function() {
        await mint(accounts[1], 3000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 3000000, 16987654321, 2, 2, 3, 500);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await mint(accounts[7], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, []);
        await TP.connect(accounts[7]).register(hash1, accounts[7].address, [accounts[8].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address, accounts[3].address, accounts[7].address], [7000, 2000, 1000]))
            .to.emit(TP, "TournamentFinished", hash1, [accounts[2].address, accounts[3].address, accounts[7].address])
        await expectBalance(accounts[0], 900000);
        await expectBalance(accounts[1], 405000);
        await expectBalance(accounts[2], 2693250);
        await expectBalance(accounts[4], 2693250);
        await expectBalance(accounts[3], 769500);
        await expectBalance(accounts[5], 769500);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 384750);
        await expectBalance(accounts[8], 384750);
    });

    it("Сan finish with doubled fractions for one team", async function() {
        await mint(accounts[1], 3000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 3000000, 16987654321, 2, 2, 3, 500);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await mint(accounts[7], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, []);
        await TP.connect(accounts[7]).register(hash1, accounts[7].address, [accounts[8].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address, accounts[3].address, accounts[2].address], [7000, 2000, 1000]))
            .to.emit(TP, "TournamentFinished", hash1, [accounts[2].address, accounts[3].address, accounts[2].address])
        await expectBalance(accounts[0], 900000);
        await expectBalance(accounts[1], 405000);
        await expectBalance(accounts[2], 3078000);
        await expectBalance(accounts[4], 3078000);
        await expectBalance(accounts[3], 769500);
        await expectBalance(accounts[5], 769500);
        await expectBalance(accounts[6], 1000000);
        await expectBalance(accounts[7], 0);
        await expectBalance(accounts[8], 0);
    });

    it("Cannot finish non-existing tournament", async function() {
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("finish non started tournament on registration", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot finish non started tournament on filled", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 2, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot finish finished tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot finish canceled tournament", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).cancelTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Invalid tournament status");
    });

    it("Cannot finish with captain not in list", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[6].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Winner team not participated in the tournament");
    });

    it("Cannot finish with captain of unfilled team", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[6], 1000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[6]).register(hash1, accounts[6].address, []);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[6].address], [10000]))
            .to.be.revertedWith("TournamentProviderV2: Winner team not participated in the tournament");
    });

    it("Cannot finish with invalid fractions for single winner", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10001]))
            .to.be.revertedWith("TournamentProviderV2: prizeFractions not result into 1");
    });

    it("Cannot finish with invalid fraction for multiple winners", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address, accounts[3].address], [9000, 999]))
            .to.be.revertedWith("TournamentProviderV2: prizeFractions not result into 1");
    });

    it("Cannot finish with invalid fraction for multiple winners", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address, accounts[3].address], [9000, 999, 1]))
            .to.be.revertedWith("TournamentProviderV2: Winners length not matches prizeFractionLength");
    });

    it("Cannot finish with empty winners", async function() {
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[5].address]);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expect(TP.connect(accounts[0]).finishTournament(hash1, 0, [], []))
            .to.be.revertedWith("TournamentProviderV2: prizeFractions not result into 1");
    });
});


describe("TournamentProviderV2 States", function(){
    let accounts;
    let Token;
    let Treasury;
    let TP;
    const hash1 = "18569430475105882587588266137607568536673111973893317399460219858819262702947";

    async function mint(to, amount, approvedTo=undefined) {
        await Token.connect(accounts[0]).mint(to.address, amount);
        if(approvedTo){
            await Token.connect(to).approve(approvedTo.address, amount);
        }
    }

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const TokenMaster = await hre.ethers.getContractFactory("Token");
        Token = await TokenMaster.deploy("MyToken", "MT");
        await Token.deployed();
        const TreasuryMaster = await hre.ethers.getContractFactory("Treasury");
        Treasury = await TreasuryMaster.deploy(accounts[1].address);
        await Treasury.deployed();
        const TournamentProviderMaster = await hre.ethers.getContractFactory("ProxyTournamentProviderV2");
        TP = await TournamentProviderMaster.deploy();
        await TP.deployed();
        const ProxyMaster = await hre.ethers.getContractFactory("Proxy");
        const Proxy = await ProxyMaster.deploy(TP.address, []);
        await Proxy.deployed();
        await Treasury.setOperator(Proxy.address);
        TP = TournamentProviderMaster.attach(Proxy.address);
        await TP.construct(Token.address, Treasury.address, accounts[0].address, ethers.constants.AddressZero, 0);
    });

    it("Must be constructed", async function() {
        expect(await TP.platformWallet()).to.equal(accounts[0].address);
        expect(await TP.treasury()).to.equal(Treasury.address);
        expect(await TP.token()).to.equal(Token.address);
        expect(await Treasury.operator()).to.equal(TP.address);
        expect(await TP.baseFee()).to.equal(1000);
        expect(await TP.minimalAdmissionFee()).to.equal(1000000);
        expect(await TP.minimalSponsorPool()).to.equal(1000000);
        expect(await TP.hash()).to.equal(0);
    });
// +++++++++++ Constants ++++++++++
    it("Must set Minimal Fees", async function() {
        await TP.setMinimalFees(888, 999);
        expect(await TP.minimalAdmissionFee()).to.equal(888);
        expect(await TP.minimalSponsorPool()).to.equal(999);
    });

    it("Must set Bookmaker", async function() {
        await TP.setBookmaker(accounts[1].address);
        expect(await TP.BM()).to.equal(accounts[1].address);
    });

    it("Must set Hash", async function() {
        await TP.setHash(accounts[1].address);
        expect(await TP.hash()).to.equal(accounts[1].address);
    });
// ++++++++++ Tournaments ++++++++++
    const Status  = {
        NotExist: 0,
        Registration: 1,
        Filled: 2,
        Started: 3,
        Finished: 4,
        Canceled: 5
    }
    async function expectTournament(
        organizer,
        fee,
        sponsorPool,
        startTime,
        captains,
        filledTeamCaptains,
        status,
        minTeams,
        maxTeams,
        playersInTeam,
        organizerRoyalty) {
        const data = await TP.getTournament(hash1);
        expect(data.organizer).to.equal(organizer);
        expect_number(data.fee).to.equal(fee);
        expect_number(data.sponsorPool).to.equal(sponsorPool);
        expect_number(data.startTime).to.equal(startTime);
        expect_array(data.captains).to.equal(captains);
        expect_array(data.filledTeamCaptains).to.equal(filledTeamCaptains);
        expect(data.status).to.equal(status);
        expect(data.minTeams).to.equal(minTeams);
        expect(data.maxTeams).to.equal(maxTeams);
        expect(data.playersInTeam).to.equal(playersInTeam);
        expect_number(data.organizerRoyalty).to.equal(organizerRoyalty);
    }

    it("Must keep Tournament", async function() {
        await mint(accounts[1], 2000000, TP);
        await mint(accounts[2], 1000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[5], 3000000, TP);
        await mint(accounts[8], 3000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 2000000, 16987654321, 3, 2, 3, 50);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [], [], Status.Registration, 2, 3, 3, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address], [], Status.Registration, 2, 3, 3, 50);
        await TP.connect(accounts[3]).register(hash1, accounts[2].address, [accounts[4].address]);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address], [accounts[2].address], Status.Registration, 2, 3, 3, 50);
        await TP.connect(accounts[5]).register(hash1, accounts[5].address, [accounts[6].address, accounts[7].address]);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address, accounts[5].address], [accounts[2].address, accounts[5].address], Status.Registration, 2, 3, 3, 50);
        await TP.connect(accounts[8]).register(hash1, accounts[8].address, [accounts[9].address, accounts[10].address]);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address, accounts[5].address, accounts[8].address], [accounts[2].address, accounts[5].address, accounts[8].address], Status.Filled, 2, 3, 3, 50);
        await TP.connect(accounts[0]).startTournament(hash1);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address, accounts[5].address, accounts[8].address], [accounts[2].address, accounts[5].address, accounts[8].address], Status.Started, 2, 3, 3, 50);
        await TP.connect(accounts[0]).finishTournament(hash1, 0, [accounts[2].address], [10000]);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address, accounts[5].address, accounts[8].address], [accounts[2].address, accounts[5].address, accounts[8].address], Status.Finished, 2, 3, 3, 50);
    });

    it("Must keep Tournament 2", async function() {
        await expectTournament(ethers.constants.AddressZero, 0, 0, 0, [], [], Status.NotExist, 0, 0, 0, 0);
        await mint(accounts[1], 2000000, TP);
        await mint(accounts[2], 1000000, TP);
        await mint(accounts[3], 2000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 2000000, 16987654321, 3, 2, 3, 50);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.connect(accounts[3]).register(hash1, accounts[2].address, [accounts[4].address]);
        await TP.connect(accounts[0]).cancelTournament(hash1);
        await expectTournament(accounts[1].address, 1000000, 2000000, 16987654321,
            [accounts[2].address], [accounts[2].address], Status.Canceled, 2, 3, 3, 50);
    });

    it("Must keep team", async function() {
        await TP.compareUnfilledTeam(hash1, accounts[2].address, []);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[5], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await TP.compareUnfilledTeam(hash1, accounts[2].address, []);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.compareUnfilledTeam(hash1, accounts[2].address, [accounts[2].address]);
        await TP.connect(accounts[5]).register(hash1, accounts[2].address, []);
        await TP.compareUnfilledTeam(hash1, accounts[2].address, [accounts[2].address, accounts[5].address]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[4].address]);
        await TP.compareUnfilledTeam(hash1, accounts[3].address, [accounts[3].address, accounts[4].address]);
    });

    it("Must keep all registered players", async function() {
        await TP.compareRegisteredPlayers(hash1, [accounts[2].address, accounts[3].address, accounts[4].address, accounts[5].address], [false, false, false, false]);
        await mint(accounts[2], 2000000, TP);
        await mint(accounts[3], 2000000, TP);
        await mint(accounts[5], 1000000, TP);
        await TP.connect(accounts[1]).createTournament(1000000, 0, 16987654321, 2, 2, 3, 50);
        await TP.compareRegisteredPlayers(hash1, [accounts[2].address, accounts[3].address, accounts[4].address, accounts[5].address], [false, false, false, false]);
        await TP.connect(accounts[2]).register(hash1, accounts[2].address, []);
        await TP.compareRegisteredPlayers(hash1, [accounts[2].address, accounts[3].address, accounts[4].address, accounts[5].address], [true, false, false, false]);
        await TP.connect(accounts[5]).register(hash1, accounts[2].address, []);
        await TP.compareRegisteredPlayers(hash1, [accounts[2].address, accounts[3].address, accounts[4].address, accounts[5].address], [true, false, false, true]);
        await TP.connect(accounts[3]).register(hash1, accounts[3].address, [accounts[4].address]);
        await TP.compareRegisteredPlayers(hash1, [accounts[2].address, accounts[3].address, accounts[4].address, accounts[5].address], [true, true, true, true]);
    });
});
