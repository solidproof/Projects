const {expect} = require("chai");
const {BigNumber} = require("ethers");
const {ethers} = require("hardhat");


function expect_number(value) {
    return {
        to: {
            equal: function (answer) {
                expect(value.toString()).to.equal(answer.toString())
                //expect(value.eq(BigNumber.from(answer))).to.equal(true);
            },
            more: function(answer) {
                expect(value.gt(BigNumber.from(answer))).to.equal(true);
            }
        }
    }
}

function expect_array(a) {
    return {
        to: {
            equal: function (b) {
                expect(a.length).to.equal(b.length);
                for(let i = 0; i < a.length; i++) {
                    expect(a[i]).to.equal(b[i]);
                }
            }
        }
    }
}

async function retrieveAccounts() {
    const [account1, account2, account3, account4, account5,
        account6, account7, account8, account9, account10,
        account11, account12, account13, account14, account15,
        account16, account17, account18, account19, account20] = await ethers.getSigners();
    return [account1, account2, account3, account4, account5,
        account6, account7, account8, account9, account10,
        account11, account12, account13, account14, account15,
        account16, account17, account18, account19, account20];
}


module.exports = {expect_number, retrieveAccounts, expect_array};