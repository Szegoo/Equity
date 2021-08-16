const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EquityContract", () => {
   let EquityContract, equityContract, owner, addr1, addr2;
   
   beforeEach(async()=> {
       EquityContract = await ethers.getContractFactory('Equity');
       equityContract = await EquityContract.deploy("0xF47f6888d1072D865C5Bf379bae0A90Ce2b77AdE", 1);
       [owner, addr1, addr2, _] = await ethers.getSigners();
   });

   describe('Depositing', () => {
       it('Should set up the timer', async() => {
           await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
           expect(await equityContract.unlockTime()).to.not.equal(0);
       })
       it("Should not be able to call deposit function twice", async() => {
           await equityContract.deposit({value: ethers.utils.parseEther("1.0")});
            await expect(equityContract.deposit({
               value: ethers.utils.parseEther("1.0")
            })).to.be.revertedWith("The fund function can only be called once");
       })
   })
});
