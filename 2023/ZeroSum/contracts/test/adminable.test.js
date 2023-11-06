const {expect} = require("chai");
const {retrieveAccounts} = require("./utils");


const AdminRole = {
    None: 0,
    Backend: 1,
    Developer: 2,
    Owner: 3,
}

describe("Ownable", function(){
    let accounts;
    let A;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const AdminableTest = await hre.ethers.getContractFactory("AdminableTest");
        A = await AdminableTest.deploy();
        await A.deployed();
    });

    it("Owner must be a deployer", async function() {
        expect(await A.showOwner()).to.equal(accounts[0].address);
    });

    it("Allow to transfer ownership", async function() {
        await expect(A.connect(accounts[0]).transferOwnership(accounts[1].address))
            .to.emit(A, "OwnershipTransferred")
            .withArgs(accounts[0].address, accounts[1].address);
        expect(await A.showOwner()).to.equal(accounts[1].address);
    });

    it("Only owner can transfer ownership", async function() {
        await expect(A.connect(accounts[1]).transferOwnership(accounts[2].address)).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it("'onlyOwner' can be called only by owner", async function() {
        await A.connect(accounts[0]).doOwnerStuff();
        await expect(A.connect(accounts[1]).doOwnerStuff()).to.be.revertedWith('Ownable: caller is not the owner');
    });

    it("Owner can do every stuff as admins", async function() {
        for(let roleName in AdminRole) {
            await A.connect(accounts[0]).doAdminStuff(AdminRole[roleName]);
            await A.connect(accounts[0]).doAdminHierarchyStuff(AdminRole[roleName]);
        }
    })
});


describe("Adminable", function(){
    let accounts;
    let A;

    beforeEach(async function() {
        accounts = await retrieveAccounts();
        const AdminableTest = await hre.ethers.getContractFactory("AdminableTest");
        A = await AdminableTest.deploy();
        await A.deployed();
    });

    it("Owner can approve admin for any role", async function() {
        for(let roleName in AdminRole) {
            if(roleName === 'Owner') continue;
            await expect(A.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole[roleName]))
                .to.emit(A, "AdminApproved")
                .withArgs(accounts[0].address, accounts[1].address, AdminRole[roleName]);
            expect(await A.showRole(accounts[1].address)).to.equal(AdminRole[roleName]);
        }
    });

    it("Owner Role can not be granted to admin", async function() {
        await expect(A.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole['Owner'])).to.be.revertedWith('Owner role can not be granted to admin');
    });

    it("Admin can grant the same or less role that he has", async function() {
        for(let adminRole in AdminRole) {
            if(adminRole === 'Owner') continue;
            await A.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole[adminRole]);
            for(let roleName in AdminRole) {
                if(roleName === 'Owner') continue;
                if(AdminRole[roleName] > AdminRole[adminRole]) {
                    await expect(A.connect(accounts[1]).approveAdmin(accounts[2].address, AdminRole[roleName])).to.be.revertedWith("Adminable: caller is not an admin");
                }
                else {
                    await A.connect(accounts[1]).approveAdmin(accounts[2].address, AdminRole[roleName])
                }
            }
        }
    });

    it("Admin can only do Admin stuff", async function() {
        for(let adminRole in AdminRole) {
            if(adminRole === 'Owner') continue;
            await A.connect(accounts[0]).approveAdmin(accounts[1].address, AdminRole[adminRole]);
            for(let roleName in AdminRole) {
                if(AdminRole[roleName] === AdminRole[adminRole]) {
                    await A.connect(accounts[1]).doAdminStuff(AdminRole[roleName]);
                    await A.connect(accounts[1]).doAdminHierarchyStuff(AdminRole[roleName]);
                    continue;
                }
                if(AdminRole[roleName] < AdminRole[adminRole]) {
                    await expect(A.connect(accounts[1]).doAdminStuff(AdminRole[roleName])).to.be.revertedWith("Adminable: caller is not an admin");
                    await A.connect(accounts[1]).doAdminHierarchyStuff(AdminRole[roleName]);
                }
                else {
                    await expect(A.connect(accounts[1]).doAdminStuff(AdminRole[roleName])).to.be.revertedWith("Adminable: caller is not an admin");
                    await expect(A.connect(accounts[1]).doAdminHierarchyStuff(AdminRole[roleName])).to.be.revertedWith("Adminable: caller is not an admin");
                }
            }
        }
    });

});


module.exports = {AdminRole};
