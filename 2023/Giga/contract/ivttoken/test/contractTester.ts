const { expect } = require("chai");
const { randomBytes } = require("crypto");
const { ethers } = require("hardhat");
const { TypedDataUtils } = require('ethers-eip712');

import { signMessage, signMessages, getEthBalance, EIP712 } from '../util/signing-util'
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";

dotenvConfig({ path: resolve(__dirname, "../.env") });

const number = 10 ** 18
const tokensToOperate = ethers.BigNumber.from(number.toString())

describe("GigaToken", function () {
    let hardhatToken, multisig
    let owner, second, third, fourth, fifth, sixth, seventh, eighth, ninth
    let ownerAddress, secondAddress, thirdAddress, fourthAddress, fifthAddress, sixthAddress, seventhAddress, eighthAddress, ninthAddress

    this.beforeAll(async () => {
        [ owner, second, third, fourth, fifth, sixth, seventh, eighth, ninth ] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        secondAddress = await second.getAddress();
        thirdAddress = await third.getAddress();
        fourthAddress = await fourth.getAddress();
        fifthAddress = await fifth.getAddress();
        sixthAddress = await sixth.getAddress();
        seventhAddress = await seventh.getAddress();
        eighthAddress = await eighth.getAddress();
        ninthAddress = await ninth.getAddress();
    });
    this.beforeEach(async () => {
        const GigaToken = await ethers.getContractFactory("GigaToken")
        hardhatToken = await GigaToken.deploy()

        const MultiSig = await ethers.getContractFactory("MultiSig")
        multisig = await MultiSig.deploy(thirdAddress, fourthAddress)
    })

    it("Should test increase and decrease unlocked tokens", async function () {
        const [addr1, addr2] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()
        const walletAddress2 = await addr2.getAddress()
        let unlockedTokens

        const approve = await hardhatToken.approve(walletAddress1, tokensToOperate)
        await approve.wait()
    
        const mintTokens = await hardhatToken.mint(walletAddress1, tokensToOperate)
        await mintTokens.wait()

        unlockedTokens = await hardhatToken.getUnlockedTokens(walletAddress1)
        expect(unlockedTokens).to.equal(0)

        expect(hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.be.revertedWith("Not enough unlocked tokens")

        const increaseUnlockedTokens = await hardhatToken.increaseUnlockedTokens(walletAddress1, tokensToOperate)
        await increaseUnlockedTokens.wait()

        unlockedTokens = await hardhatToken.getUnlockedTokens(walletAddress1)
        expect(unlockedTokens).to.equal(tokensToOperate)
        
        expect(await hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate.div(2))).to.changeTokenBalance(hardhatToken, walletAddress1, tokensToOperate.div(2))

        const decreaseUnlockedTokens = await hardhatToken.decreaseUnlockedTokens(walletAddress1, tokensToOperate.div(2))
        await decreaseUnlockedTokens.wait()

        unlockedTokens = await hardhatToken.getUnlockedTokens(walletAddress1)
        expect(unlockedTokens).to.equal(0)

        expect(hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.be.revertedWith("Not enough unlocked tokens")
    })

    it("Should mint a token", async function () {
        const [addr1] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()

        expect(await hardhatToken.mint(walletAddress1, tokensToOperate)).to.changeTokenBalance(hardhatToken, walletAddress1, tokensToOperate)
    })

    it("Should pause and unpause contract", async function () {
        const [addr1] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()

        const pauseContract = await hardhatToken.pause() 
        await pauseContract.wait()
        
        const unpauseContract = await hardhatToken.unpause()
        await unpauseContract.wait()
        
        expect(await hardhatToken.mint(walletAddress1, tokensToOperate)).to.changeTokenBalance(hardhatToken, walletAddress1, tokensToOperate)
    })

    it("Should transfer tokens from wallet to wallet", async function () {
        const [addr1, addr2] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()
        const walletAddress2 = await addr2.getAddress()

        const approve = await hardhatToken.approve(walletAddress1, tokensToOperate)
        await approve.wait()
    
        const mintTokens = await hardhatToken.mint(walletAddress1, tokensToOperate)
        await mintTokens.wait()

        expect(hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.be.revertedWith("Not enough unlocked tokens")

        const increaseUnlockedTokens = await hardhatToken.increaseUnlockedTokens(walletAddress1, tokensToOperate)
        await increaseUnlockedTokens.wait()
        
        expect(await hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.changeTokenBalance(hardhatToken, walletAddress1, 0)
    })

    it("Should transfer tokens by event", async function () {
        const [addr2, addr1] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()
        const walletAddress2 = await addr2.getAddress()

        const mintTokens = await hardhatToken.mint(walletAddress2, tokensToOperate)
        await mintTokens.wait()

        const increaseUnlockedTokens = await hardhatToken.increaseUnlockedTokens(walletAddress2, tokensToOperate)
        await increaseUnlockedTokens.wait()

        expect(await hardhatToken.transfer(walletAddress1, 1)).to.changeTokenBalance(hardhatToken, walletAddress1, 1)
    })

    it("Should burn tokens", async function () {
        const [owner] = await ethers.getSigners()
        const ownerAddress = await owner.getAddress()

        const mintTokens = await hardhatToken.mint(ownerAddress, 2)
        await mintTokens.wait()

        expect(await hardhatToken.burn(2)).to.changeTokenBalance(hardhatToken, ownerAddress, 0)
    })

    it("Should return the amount of token that a spender is allowed to spend", async function () {
        const [owner, addr1] = await ethers.getSigners()
        const ownerAddress = await owner.getAddress()
        const walletAddress1 = await addr1.getAddress()

        expect(await hardhatToken.allowance(ownerAddress, walletAddress1)).to.equal(0)
    })

    it("Should return the amount of token's total supply in the past", async function () {
        const [owner] = await ethers.getSigners()
        const ownerAddress = await owner.getAddress()

        const mintTokens = await hardhatToken.mint(ownerAddress, 100)
        await mintTokens.wait()

        expect(await hardhatToken.totalSupply()).to.equal(100)

        const snapshot = await hardhatToken.snapshot()
        const snapshotWait = await snapshot.wait()
        const snapshotId = snapshotWait.events[0].args.id

        expect(await hardhatToken.burn(51)).to.changeTokenBalance(hardhatToken, ownerAddress, 49)

        expect(await hardhatToken.balanceOfAt(ownerAddress, snapshotId)).to.equal(100)
    })

    it("Should return the amount of an user's tokens in the past", async function () {
        const [owner, addr1] = await ethers.getSigners()
        const ownerAddress = await owner.getAddress()
        const walletAddress1 = await addr1.getAddress()

        const mintTokens = await hardhatToken.mint(ownerAddress, 150)
        await mintTokens.wait()

        expect(await hardhatToken.balanceOf(ownerAddress)).to.equal(150)

        const snapshot = await hardhatToken.snapshot()
        const snapshotWait = await snapshot.wait()
        const snapshotId = snapshotWait.events[0].args.id

        const approve = await hardhatToken.approve(ownerAddress, 150)
        await approve.wait()

        const increaseUnlockedTokens = await hardhatToken.increaseUnlockedTokens(ownerAddress, 150)
        await increaseUnlockedTokens.wait()

        const transferTokens = await hardhatToken.transferFrom(ownerAddress, walletAddress1, 150)
        await transferTokens.wait()

        expect(await hardhatToken.balanceOf(ownerAddress)).to.equal(0)

        expect(await hardhatToken.balanceOfAt(ownerAddress, snapshotId)).to.equal(150)
    })

    it("Should update the amount of token that a spender is allowed to spend", async function () {
        const [owner, addr1] = await ethers.getSigners()
        const ownerAddress = await owner.getAddress()
        const walletAddress1 = await addr1.getAddress()

        const approve = await hardhatToken.approve(walletAddress1, 2)
        await approve.wait()

        expect(await hardhatToken.allowance(ownerAddress, walletAddress1)).to.equal(2)
    })

    it("Should fail to transfer before allowance and succeed after it", async function () {
        const [addr1, addr2] = await ethers.getSigners()
        const walletAddress1 = await addr1.getAddress()
        const walletAddress2 = await addr2.getAddress()

        const mintTokens = await hardhatToken.mint(walletAddress1, tokensToOperate)
        await mintTokens.wait() 

        await expect(hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.be.revertedWith("ERC20: insufficient allowance")

        const approve = await hardhatToken.approve(walletAddress1, tokensToOperate)
        await approve.wait()

        const increaseUnlockedTokens = await hardhatToken.increaseUnlockedTokens(walletAddress1, tokensToOperate)
        await increaseUnlockedTokens.wait()
    
        expect(await hardhatToken.transferFrom(walletAddress1, walletAddress2, tokensToOperate)).to.changeTokenBalance(hardhatToken, walletAddress1, 0)
        expect(await hardhatToken.balanceOf(walletAddress2)).to.equal(tokensToOperate)
    })
})

describe("Multisig", function () {
    let hardhatGigaToken, multisig
    let owner, second, third, fourth, fifth, sixth, seventh, eighth, ninth
    let ownerAddress, secondAddress, thirdAddress, fourthAddress, fifthAddress, sixthAddress, seventhAddress, eighthAddress, ninthAddress

    this.beforeAll(async () => {
        [ owner, second, third, fourth, fifth, sixth, seventh, eighth, ninth ] = await ethers.getSigners();
        ownerAddress = await owner.getAddress();
        secondAddress = await second.getAddress();
        thirdAddress = await third.getAddress();
        fourthAddress = await fourth.getAddress();
        fifthAddress = await fifth.getAddress();
        sixthAddress = await sixth.getAddress();
        seventhAddress = await seventh.getAddress();
        eighthAddress = await eighth.getAddress();
        ninthAddress = await ninth.getAddress();
    });

    this.beforeEach(async () => {
        const MultiSig = await ethers.getContractFactory("MultiSig")
        multisig = await MultiSig.deploy(thirdAddress, fourthAddress)
        await multisig.deployed()

        const GigaToken = await ethers.getContractFactory("GigaToken")
        hardhatGigaToken = await GigaToken.deploy()
        await hardhatGigaToken.deployed()

        const minterRole = await hardhatGigaToken.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes("MINTER_ROLE")), multisig.address)
        await minterRole.wait()
    })

    it("Should mint a token through GigaToken's contract", async function () {

        // get the mint function signature
        const abi = ["function mint(address _to, uint256 _amount)"];
        const iface = new ethers.utils.Interface(abi);
        const calldata = iface.encodeFunctionData('mint', [ownerAddress, tokensToOperate]);

        // construct txn params to call a contract function
        const nonce = ethers.utils.hexlify(ethers.utils.randomBytes(32));
        const params = {
            to: hardhatGigaToken.address,
            value: '0',
            data: ethers.utils.hexlify(calldata),
            nonce: nonce
        };

        // create the array of signatures
        const signatures = await signMessages([third, fourth], multisig.address, params);

        expect(await multisig.connect(owner).executeTransaction(signatures, params.to, params.value, params.data, params.nonce)).to.changeTokenBalance(hardhatGigaToken, ownerAddress, tokensToOperate)
        expect(multisig.connect(owner).executeTransaction(signatures, params.to, params.value, params.data, params.nonce)).to.be.revertedWith("Transaction has already been executed")
    })
})