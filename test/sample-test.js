const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("EquityContract", () => {
   let EquityContract, equityContract, owner, addr1, addr2;
   
   beforeEach(async()=> {
       EquityContract = await ethers.getContractFactory('Equity');
       equityContract = await EquityContract.deploy("0xF47f6888d1072D865C5Bf379bae0A90Ce2b77AdE", 1);
       [owner, addr1, addr2, _] = await ethers.getSigners();
   });
});
