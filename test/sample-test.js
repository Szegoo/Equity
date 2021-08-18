const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EquityContract", () => {
   let EquityContract, equityContract, owner, addr1, addr2;

   beforeEach(async()=> {
       EquityContract = await ethers.getContractFactory('Equity');
       [owner, addr1, addr2, _] = await ethers.getSigners();
       equityContract = await EquityContract.deploy(owner.address, "0x0000000000000000000000000000000000000000");
   });

   describe('Depositing', () => {
       it('Should set up the timer and currentRoundTotal', async() => {
           await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
           expect(await equityContract.unlockTime()).to.not.equal(0);
           expect(await equityContract.currentRoundTotal()).to.equal(ethers.utils.parseEther("1.0"));
       })
       it("Should not be able to call deposit function twice", async() => {
           await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
            await expect(equityContract.deposit({
               value: ethers.utils.parseEther("1.0")
            })).to.be.revertedWith("The fund function can only be called once");
       })
   })
   describe("Adding a list", () => {
        it("Should add the list", async() => {
            await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
            expect(await equityContract.unlockTime()).to.not.equal(0);
            expect(await equityContract.currentRoundTotal()).to.equal(ethers.utils.parseEther("1.0"));
            let address = addr1.address;
            await equityContract.setList(
                [[address, 1000000]]
            );
            expect(await equityContract.currentRoundTotal()).to.not.equal(ethers.utils.parseEther("1.0"))
            expect(await equityContract.employees(0)).to.equal(address);
        })
   })
   describe("Withdrawing as an employee", () => {
        it("Should be able to withdraw", async() => {
            await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
            expect(await equityContract.unlockTime()).to.not.equal(0);
            expect(await equityContract.currentRoundTotal()).to.equal(ethers.utils.parseEther("1.0"));
            let address = addr1.address;
            await equityContract.setList(
                [[address, 1000000]]
            );
            let balanceBefore = await equityContract.currentRoundTotal();
            expect(await equityContract.connect(addr1).withdraw());
            expect(await equityContract.currentRoundTotal()).to.be.equal(
                balanceBefore - 1000000
            )
        })
    })
    describe("Withdraw as the owner", () => {
        it("Shouldn't be able to withdraw", async() => {
            await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
            expect(await equityContract.unlockTime()).to.not.equal(0);
            expect(await equityContract.currentRoundTotal()).to.equal(ethers.utils.parseEther("1.0"));
            let address = addr1.address;
            await equityContract.setList(
                [[address, 1000000]]
            );
            let balanceBefore = await equityContract.currentRoundTotal();
            await equityContract.ownerWithdraw() 
            expect(await equityContract.currentRoundTotal()).to.be.equal(
                balanceBefore
            )
        })
    })
});